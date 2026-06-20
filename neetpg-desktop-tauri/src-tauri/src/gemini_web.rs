//! Drives the Gemini *website* (not the API) through a persistent hidden WebView window.
//!
//! Batch strategy: one WebView window is kept alive across BATCH_SIZE image generations
//! (each submitted as a follow-up message in the same Gemini conversation). After the
//! batch the window is destroyed and a BATCH_COOLDOWN_SECS cooldown is imposed before
//! the next batch starts. This is much more efficient than opening a new window per
//! image, which burns per-session limits faster.
//!
//! If the worker window disappears or errors mid-batch it is automatically recreated on
//! the next call; the batch counter is preserved so the cooldown fires at the right time.

use base64::Engine;
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::{Mutex, OnceLock};
use std::time::{Duration, Instant};
use tauri::{AppHandle, Listener, Manager, WebviewUrl, WebviewWindowBuilder};

const GEMINI_URL: &str = "https://gemini.google.com/app";
const UA: &str = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 \
                  (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36";
const LOGIN_LABEL: &str = "gemini-login";
const WORKER_LABEL: &str = "gemini-worker";
const PROBE_LABEL: &str = "gemini-probe";
const TITLE_MARK: &str = "NEETPG_RESULT:";
/// Images per Gemini conversation session before closing the window.
const BATCH_SIZE: usize = 30;
/// Cooldown between batches (1 hour) to stay well within Gemini's per-session limits.
const BATCH_COOLDOWN_SECS: u64 = 3600;
/// Consecutive page-level failures (no-image / refusal) before the conversation
/// window is recycled — a stuck or rate-limited chat won't recover on its own.
const FAILS_BEFORE_RECYCLE: usize = 2;

// ── session state (lives for the whole app lifetime) ─────────────────────────

struct GeminiSession {
    busy: AtomicBool,
    /// True while the batch worker window exists and the SPA has fully booted.
    window_ready: AtomicBool,
    /// Successful images generated in the currently-open conversation window.
    batch_count: Mutex<usize>,
    /// When the next batch is allowed to start (None = no cooldown active).
    cooldown_until: Mutex<Option<Instant>>,
    /// Consecutive page-level failures since the last success.
    consecutive_fails: Mutex<usize>,
}

static SESSION: OnceLock<GeminiSession> = OnceLock::new();

fn session() -> &'static GeminiSession {
    SESSION.get_or_init(|| GeminiSession {
        busy: AtomicBool::new(false),
        window_ready: AtomicBool::new(false),
        batch_count: Mutex::new(0),
        cooldown_until: Mutex::new(None),
        consecutive_fails: Mutex::new(0),
    })
}

// ── public API ────────────────────────────────────────────────────────────────

/// Open a visible window for the user to log into Gemini. Cookies persist in
/// the app's WebView2 profile and are shared with the hidden worker window.
pub fn sign_in(handle: &AppHandle) -> Result<String, String> {
    if let Some(w) = handle.get_webview_window(LOGIN_LABEL) {
        let _ = w.show();
        let _ = w.set_focus();
        return Ok("Sign-in window is already open".into());
    }
    WebviewWindowBuilder::new(
        handle,
        LOGIN_LABEL,
        WebviewUrl::External(GEMINI_URL.parse().map_err(|e| format!("{e}"))?),
    )
    .title("Sign in to Gemini — close this window when done")
    .inner_size(980.0, 760.0)
    .user_agent(UA)
    .build()
    .map_err(|e| e.to_string())?;
    Ok("Sign-in window opened — log into your Google account, then close it.".into())
}

/// Check sign-in status and current batch state.
/// Uses a short-lived probe window (title fallback channel — no event capability needed).
pub async fn probe(handle: &AppHandle) -> (bool, String) {
    let sess = session();

    // Cooldown active → report without opening a window
    {
        let until = sess.cooldown_until.lock().unwrap();
        if let Some(u) = *until {
            let now = Instant::now();
            if u > now {
                let mins = u.duration_since(now).as_secs().saturating_add(59) / 60;
                return (
                    false,
                    format!(
                        "Gemini web: batch of {BATCH_SIZE} complete — \
                         next batch in ~{mins} min"
                    ),
                );
            }
        }
    }

    // Actively generating → we know it's signed in; just report batch progress
    if sess.busy.load(Ordering::SeqCst) {
        let count = *sess.batch_count.lock().unwrap();
        return (
            true,
            format!("Gemini web active — {count}/{BATCH_SIZE} in current batch"),
        );
    }

    if sess.busy.compare_exchange(false, true, Ordering::SeqCst, Ordering::SeqCst).is_err() {
        return (true, "Gemini web is active — signed in".into());
    }
    let out = probe_inner(handle).await;
    sess.busy.store(false, Ordering::SeqCst);
    out
}

async fn probe_inner(handle: &AppHandle) -> (bool, String) {
    if let Some(w) = handle.get_webview_window(PROBE_LABEL) {
        let _ = w.destroy();
        tokio::time::sleep(Duration::from_millis(200)).await;
    }
    let win = match WebviewWindowBuilder::new(
        handle,
        PROBE_LABEL,
        WebviewUrl::External(GEMINI_URL.parse().unwrap()),
    )
    .title("Gemini probe")
    .inner_size(800.0, 600.0)
    .position(-32000.0, -32000.0)
    .decorations(false)
    .always_on_bottom(true)
    .skip_taskbar(true)
    .focused(false)
    .user_agent(UA)
    .build()
    {
        Ok(w) => w,
        Err(e) => return (false, e.to_string()),
    };
    let _ = win.set_always_on_bottom(true);
    let _ = win.set_position(tauri::LogicalPosition::new(-32000.0, -32000.0));
    if let Some(main) = handle.get_webview_window("main") {
        let _ = main.set_focus();
    }
    tokio::time::sleep(Duration::from_secs(4)).await;
    let v = eval_in_win(handle, &win, &probe_script(), 25).await;
    let _ = win.destroy();
    match v {
        Ok(v) if v.get("ok").and_then(|b| b.as_bool()).unwrap_or(false) => {
            (true, "Gemini web is ready — signed in".into())
        }
        Ok(v) => {
            let e = v.get("error").and_then(|e| e.as_str()).unwrap_or("unknown");
            (false, friendly_error(e))
        }
        Err(e) => (false, e),
    }
}

/// Generate one image by submitting a follow-up prompt in the persistent batch window.
/// Returns a cooldown error once BATCH_SIZE images have been generated; the window
/// reopens automatically after BATCH_COOLDOWN_SECS.
pub async fn generate(handle: &AppHandle, prompt: &str) -> Result<Vec<u8>, String> {
    let sess = session();

    // Check (and expire) cooldown
    {
        let mut until = sess.cooldown_until.lock().unwrap();
        if let Some(u) = *until {
            let now = Instant::now();
            if u > now {
                let mins = u.duration_since(now).as_secs().saturating_add(59) / 60;
                return Err(format!(
                    "Gemini web: batch of {BATCH_SIZE} images complete — \
                     next batch starts in ~{mins} min. \
                     Switch to another image source in Settings → AI Visuals \
                     to keep generating in the meantime."
                ));
            }
            *until = None; // cooldown expired
        }
    }

    if sess.busy.compare_exchange(false, true, Ordering::SeqCst, Ordering::SeqCst).is_err() {
        return Err("Gemini web is already generating — try again shortly".into());
    }
    let out = generate_inner(handle, prompt, sess).await;
    sess.busy.store(false, Ordering::SeqCst);
    out
}

async fn generate_inner(
    handle: &AppHandle,
    prompt: &str,
    sess: &GeminiSession,
) -> Result<Vec<u8>, String> {
    let web_prompt = format!(
        "Generate a single illustrative image (no text or letters inside the image). {prompt}"
    );

    // Ensure the persistent batch window is alive and the SPA has booted.
    let need_new = !sess.window_ready.load(Ordering::SeqCst)
        || handle.get_webview_window(WORKER_LABEL).is_none();

    if need_new {
        if let Some(w) = handle.get_webview_window(WORKER_LABEL) {
            let _ = w.destroy();
            tokio::time::sleep(Duration::from_millis(300)).await;
        }
        WebviewWindowBuilder::new(
            handle,
            WORKER_LABEL,
            WebviewUrl::External(GEMINI_URL.parse().map_err(|e| format!("{e}"))?),
        )
        .title("Gemini image worker")
        .inner_size(800.0, 600.0)
        .position(-32000.0, -32000.0)
        // .visible(false) is NOT usable — it stops WebView2 executing JS on
        // Windows.  Instead: decorations off, off-screen, bottom z-order, no
        // taskbar entry, no focus steal.
        .decorations(false)
        .always_on_bottom(true)
        .skip_taskbar(true)
        .focused(false)
        .user_agent(UA)
        .build()
        .map_err(|e| e.to_string())?;
        // Immediately return focus to the main window so the user never sees
        // the worker flash over the slides.
        if let Some(main) = handle.get_webview_window("main") {
            let _ = main.set_focus();
        }
        tokio::time::sleep(Duration::from_secs(4)).await;
        sess.window_ready.store(true, Ordering::SeqCst);
    }

    let win = match handle.get_webview_window(WORKER_LABEL) {
        Some(w) => w,
        None => {
            sess.window_ready.store(false, Ordering::SeqCst);
            return Err("Gemini web: worker window unexpectedly closed".into());
        }
    };
    let _ = win.set_always_on_bottom(true);
    let _ = win.set_position(tauri::LogicalPosition::new(-32000.0, -32000.0));
    if let Some(main) = handle.get_webview_window("main") {
        let _ = main.set_focus();
    }

    // driver_script counts images that exist BEFORE we submit the new prompt,
    // then waits for the count to increase — this correctly identifies the new
    // image even when previous images are visible in the conversation.
    let v = eval_in_win(handle, &win, &driver_script(&web_prompt), 115).await;

    let v = match v {
        Err(e) => {
            sess.window_ready.store(false, Ordering::SeqCst);
            if let Some(w) = handle.get_webview_window(WORKER_LABEL) {
                let _ = w.destroy();
            }
            return Err(e);
        }
        Ok(v) => v,
    };

    let result = extract_image(v).await;

    match &result {
        Ok(_) => {
            // Reset consecutive fail counter on success
            *sess.consecutive_fails.lock().unwrap() = 0;
            let new_count = {
                let mut c = sess.batch_count.lock().unwrap();
                *c += 1;
                *c
            };
            if new_count >= BATCH_SIZE {
                // Batch complete — destroy window and impose cooldown
                if let Some(w) = handle.get_webview_window(WORKER_LABEL) {
                    let _ = w.destroy();
                }
                sess.window_ready.store(false, Ordering::SeqCst);
                *sess.batch_count.lock().unwrap() = 0;
                *sess.cooldown_until.lock().unwrap() =
                    Some(Instant::now() + Duration::from_secs(BATCH_COOLDOWN_SECS));
            }
        }
        Err(_) => {
            let fails = {
                let mut f = sess.consecutive_fails.lock().unwrap();
                *f += 1;
                *f
            };
            if fails >= FAILS_BEFORE_RECYCLE {
                // Too many consecutive failures — recycle the window so the next
                // call gets a fresh conversation (handles stuck/rate-limited chats)
                if let Some(w) = handle.get_webview_window(WORKER_LABEL) {
                    let _ = w.destroy();
                }
                sess.window_ready.store(false, Ordering::SeqCst);
                *sess.consecutive_fails.lock().unwrap() = 0;
            } else if handle.get_webview_window(WORKER_LABEL).is_none() {
                sess.window_ready.store(false, Ordering::SeqCst);
            }
        }
    }

    result
}

async fn extract_image(v: serde_json::Value) -> Result<Vec<u8>, String> {
    if let Some(data_url) = v.get("dataUrl").and_then(|d| d.as_str()) {
        let b64 = data_url.split(',').nth(1).unwrap_or("");
        if let Ok(bytes) = base64::engine::general_purpose::STANDARD.decode(b64) {
            if bytes.len() > 256 {
                return Ok(bytes);
            }
        }
    }
    if let Some(src) = v.get("src").and_then(|s| s.as_str()) {
        if let Ok(res) = reqwest::get(src).await {
            if res.status().is_success() {
                if let Ok(b) = res.bytes().await {
                    if b.len() > 256 {
                        return Ok(b.to_vec());
                    }
                }
            }
        }
        return Err("Gemini web: could not download the generated image".into());
    }
    let e = v.get("error").and_then(|e| e.as_str()).unwrap_or("no result");
    Err(friendly_error(e))
}

fn friendly_error(code: &str) -> String {
    match code {
        "not-signed-in" | "no-input" => {
            "Gemini web: not signed in — open Settings → AI Visuals → Sign in to Gemini".into()
        }
        "no-image" => "Gemini web: no image was produced for this prompt".into(),
        "no-send" => "Gemini web: could not find the send button (page layout changed?)".into(),
        e => format!("Gemini web: {e}"),
    }
}

// ── eval helper ───────────────────────────────────────────────────────────────

/// Eval `script` in `win`, then wait for a result via the Tauri event bridge
/// (primary) or the document.title fallback channel (probe/fallback).
async fn eval_in_win(
    handle: &AppHandle,
    win: &tauri::WebviewWindow,
    script: &str,
    timeout_secs: u64,
) -> Result<serde_json::Value, String> {
    let (tx, mut rx) = tokio::sync::oneshot::channel::<serde_json::Value>();
    let tx = std::sync::Mutex::new(Some(tx));
    let listener = handle.listen_any("gemini-web-result", move |ev| {
        if let Some(tx) = tx.lock().unwrap().take() {
            let v: serde_json::Value =
                serde_json::from_str(ev.payload()).unwrap_or(serde_json::Value::Null);
            let _ = tx.send(v);
        }
    });

    let result = match win.eval(script) {
        Err(e) => Err(format!("Could not run the page driver: {e}")),
        Ok(()) => {
            let deadline = tokio::time::Instant::now() + Duration::from_secs(timeout_secs);
            loop {
                match tokio::time::timeout(Duration::from_secs(2), &mut rx).await {
                    Ok(Ok(v)) => break Ok(v),
                    Ok(Err(_)) => break Err("Gemini web: internal channel closed".into()),
                    Err(_) => {}
                }
                if let Ok(title) = win.title() {
                    if let Some(json) = title.strip_prefix(TITLE_MARK) {
                        if let Ok(v) = serde_json::from_str::<serde_json::Value>(json) {
                            break Ok(v);
                        }
                    }
                }
                if tokio::time::Instant::now() >= deadline {
                    break Err(
                        "Gemini web timed out — check the sign-in in Settings → AI Visuals".into(),
                    );
                }
            }
        }
    };

    handle.unlisten(listener);
    result
}

// ── in-page scripts ───────────────────────────────────────────────────────────

/// Shared JS helpers included at the top of every injected script.
const HELPERS: &str = r#"
    const send = (p) => {
      try {
        if (window.__TAURI__ && window.__TAURI__.event) {
          window.__TAURI__.event.emit('gemini-web-result', p);
          return;
        }
      } catch (e) {}
      try {
        // Title fallback: preserve ok/error fields for probe results;
        // src is enough for images (Rust fetches the URL directly).
        const slim = {
          src: p.src || '',
          error: p.error || (p.dataUrl ? '' : (p.ok !== undefined ? '' : 'no result')),
          ok: p.ok
        };
        document.title = 'NEETPG_RESULT:' + JSON.stringify(slim);
      } catch (e) {}
    };
    const sleep = (ms) => new Promise(r => setTimeout(r, ms));
    const findEditor = () =>
      document.querySelector('rich-textarea .ql-editor[contenteditable="true"]') ||
      document.querySelector('div.ql-editor[contenteditable="true"]') ||
      document.querySelector('[contenteditable="true"][role="textbox"]') ||
      document.querySelector('textarea');
    const goodSrc = (s) => /googleusercontent|lh3\.google|generativelanguage|blob:|data:image/i.test(s || '');
    const badSrc  = (s) => /avatar|icon|logo|sprite|emoji/i.test(s || '');
    const bigImg  = (img) => (img.naturalWidth || img.width || 0) > 200 && (img.naturalHeight || img.height || 0) > 200;
    const candidates = () => {
      const out = [];
      const scopes = document.querySelectorAll('[class*="response"],[class*="message"],[class*="conversation"],[class*="model"]');
      scopes.forEach(c => c.querySelectorAll('img').forEach(img => {
        const s = img.currentSrc || img.src || '';
        if (goodSrc(s) && !badSrc(s) && bigImg(img)) out.push(img);
      }));
      if (!out.length) {
        document.querySelectorAll('img').forEach(img => {
          const s = img.currentSrc || img.src || '';
          if (goodSrc(s) && !badSrc(s) && bigImg(img)) out.push(img);
        });
      }
      return out;
    };
"#;

fn probe_script() -> String {
    format!(
        r#"(async () => {{
    {HELPERS}
    let editor = null;
    for (let i = 0; i < 24 && !editor; i++) {{ editor = findEditor(); if (!editor) await sleep(500); }}
    if (editor) send({{ ok: true }});
    else send({{ ok: false, error: location.hostname.includes('accounts.google') ? 'not-signed-in' : 'no-input' }});
  }})();"#
    )
}

fn driver_script(prompt: &str) -> String {
    let p = serde_json::to_string(prompt).unwrap_or_else(|_| "\"\"".into());
    format!(
        r#"(async () => {{
    {HELPERS}
    try {{
      // URL guard — bail immediately if not on gemini.google.com
      if (!location.hostname.includes('gemini.google.com')) {{
        send({{ error: 'not-signed-in' }});
        return;
      }}

      // Snapshot how many generated images are already in this conversation
      // so we can identify only the NEW one after we submit our prompt.
      const beforeCount = candidates().length;

      // Scroll to bottom — needed for follow-up messages in a multi-turn conversation
      try {{
        const conv = document.querySelector('[class*="conversation"],[class*="messages"],[class*="chat"]');
        if (conv) conv.scrollTop = conv.scrollHeight;
        window.scrollTo(0, document.body.scrollHeight);
      }} catch (e) {{}}

      let editor = null;
      for (let i = 0; i < 30 && !editor; i++) {{ editor = findEditor(); if (!editor) await sleep(500); }}
      if (!editor) {{
        send({{ error: location.hostname.includes('accounts.google') ? 'not-signed-in' : 'no-input' }});
        return;
      }}

      editor.focus();
      if (editor.tagName === 'TEXTAREA') {{
        editor.value = {p};
        editor.dispatchEvent(new Event('input', {{ bubbles: true }}));
      }} else {{
        editor.textContent = '';
        try {{ document.execCommand('insertText', false, {p}); }} catch (e) {{}}
        if (!editor.textContent) editor.textContent = {p};
        editor.dispatchEvent(new InputEvent('input', {{ bubbles: true }}));
      }}
      await sleep(600);

      const findSend = () =>
        document.querySelector('button[aria-label*="Send" i]:not([disabled])') ||
        document.querySelector('button.send-button:not([disabled])') ||
        Array.from(document.querySelectorAll('button')).find(b =>
          /send/i.test((b.getAttribute('aria-label') || '') + ' ' + (b.textContent || '')) && !b.disabled);

      let sent = false;
      for (let i = 0; i < 12 && !sent; i++) {{
        const b = findSend();
        if (b) {{ b.click(); sent = true; break; }}
        await sleep(400);
      }}
      if (!sent) {{
        editor.dispatchEvent(new KeyboardEvent('keydown', {{
          key: 'Enter', code: 'Enter', keyCode: 13, bubbles: true
        }}));
      }}

      // Wait for a NEW image to appear (image count increases beyond beforeCount)
      const deadline = Date.now() + 75000;
      let imgEl = null;
      while (Date.now() < deadline && !imgEl) {{
        const c = candidates();
        if (c.length > beforeCount) {{
          imgEl = c[c.length - 1]; // the most recently appended image
          break;
        }}
        await sleep(1500);
      }}
      if (!imgEl) {{ send({{ error: 'no-image' }}); return; }}

      const src = imgEl.currentSrc || imgEl.src;
      try {{
        const resp = await fetch(src);
        const blob = await resp.blob();
        const dataUrl = await new Promise((res, rej) => {{
          const fr = new FileReader();
          fr.onload = () => res(fr.result);
          fr.onerror = rej;
          fr.readAsDataURL(blob);
        }});
        send({{ dataUrl, src }});
      }} catch (e) {{
        send({{ src, error: 'fetch-failed' }});
      }}
    }} catch (e) {{ send({{ error: String(e) }}); }}
  }})();"#
    )
}
