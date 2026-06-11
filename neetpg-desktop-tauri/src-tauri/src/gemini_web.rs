//! Drives the Gemini *website* (not the API) through a hidden WebView window
//! using the user's own signed-in Google account — no API key, no paid quota.
//! Port of the Electron v1.5 GeminiWebService.
//!
//! Flow: the user signs in once in a visible window (cookies persist in the
//! WebView2 profile). Generation opens an off-screen window on gemini.google.com,
//! injects a driver script that types the prompt, submits it, waits for the
//! generated image, and reports back either through the Tauri event bridge
//! (remote-domain capability + withGlobalTauri) or, as a fallback channel,
//! through `document.title`.
//!
//! This is best-effort automation of a third-party page: selectors can change
//! and every path fails soft with a readable error so the caller can fall back
//! to another provider.

use base64::Engine;
use std::sync::atomic::{AtomicBool, Ordering};
use std::time::Duration;
use tauri::{AppHandle, Listener, Manager, WebviewUrl, WebviewWindowBuilder};

const GEMINI_URL: &str = "https://gemini.google.com/app";
// Present as desktop Chrome so Google serves the standard UI instead of
// blocking the embedded-webview fingerprint.
const UA: &str = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 \
                  (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36";
const LOGIN_LABEL: &str = "gemini-login";
const WORKER_LABEL: &str = "gemini-worker";
const TITLE_MARK: &str = "NEETPG_RESULT:";

static BUSY: AtomicBool = AtomicBool::new(false);

/// Open a visible window for the user to log into Gemini. Cookies persist in
/// the app's WebView2 profile, shared with the hidden worker window.
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

/// Quick signed-in probe: loads the page hidden and checks for the composer.
pub async fn probe(handle: &AppHandle) -> (bool, String) {
    match run_in_page(handle, &probe_script(), 25).await {
        Ok(v) => {
            if v.get("ok").and_then(|b| b.as_bool()).unwrap_or(false) {
                (true, "Gemini web is ready — signed in".into())
            } else {
                let e = v.get("error").and_then(|e| e.as_str()).unwrap_or("unknown");
                (false, friendly_error(e))
            }
        }
        Err(e) => (false, e),
    }
}

/// Generate one image for the prompt via the hidden Gemini window.
pub async fn generate(handle: &AppHandle, prompt: &str) -> Result<Vec<u8>, String> {
    let web_prompt = format!(
        "Generate a single illustrative image (no text or letters inside the image). {prompt}"
    );
    let v = run_in_page(handle, &driver_script(&web_prompt), 115).await?;

    if let Some(data_url) = v.get("dataUrl").and_then(|d| d.as_str()) {
        let b64 = data_url.split(',').nth(1).unwrap_or("");
        if let Ok(bytes) = base64::engine::general_purpose::STANDARD.decode(b64) {
            if bytes.len() > 256 {
                return Ok(bytes);
            }
        }
    }
    if let Some(src) = v.get("src").and_then(|s| s.as_str()) {
        // CORS blocked the in-page fetch — googleusercontent URLs are signed,
        // so a plain GET from Rust works.
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

/// Create the hidden worker window, eval `script` in it, and wait for the
/// result via Tauri event or the document.title fallback channel.
async fn run_in_page(
    handle: &AppHandle,
    script: &str,
    timeout_secs: u64,
) -> Result<serde_json::Value, String> {
    if BUSY
        .compare_exchange(false, true, Ordering::SeqCst, Ordering::SeqCst)
        .is_err()
    {
        return Err("Gemini web is already generating — try again shortly".into());
    }
    let out = run_in_page_inner(handle, script, timeout_secs).await;
    BUSY.store(false, Ordering::SeqCst);
    out
}

async fn run_in_page_inner(
    handle: &AppHandle,
    script: &str,
    timeout_secs: u64,
) -> Result<serde_json::Value, String> {
    // Kill any orphan worker from a previous (hung) cycle.
    if let Some(w) = handle.get_webview_window(WORKER_LABEL) {
        let _ = w.destroy();
        tokio::time::sleep(Duration::from_millis(300)).await;
    }

    // Off-screen but "visible" so WebView2 doesn't throttle the SPA's timers,
    // and skip-taskbar so it never shows up anywhere the user can see.
    let win = WebviewWindowBuilder::new(
        handle,
        WORKER_LABEL,
        WebviewUrl::External(GEMINI_URL.parse().map_err(|e| format!("{e}"))?),
    )
    .title("Gemini image worker")
    .inner_size(1180.0, 900.0)
    .position(-32000.0, -32000.0)
    .skip_taskbar(true)
    .focused(false)
    .user_agent(UA)
    .build()
    .map_err(|e| e.to_string())?;

    // Let the single-page app boot before touching the DOM.
    tokio::time::sleep(Duration::from_secs(4)).await;

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
            // Wait on the event channel, polling document.title as the
            // fallback for when the remote page can't reach the event bridge.
            let deadline = tokio::time::Instant::now() + Duration::from_secs(timeout_secs);
            loop {
                match tokio::time::timeout(Duration::from_secs(2), &mut rx).await {
                    Ok(Ok(v)) => break Ok(v),
                    Ok(Err(_)) => break Err("Gemini web: internal channel closed".into()),
                    Err(_) => {} // tick — check title + deadline below
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
    let _ = win.destroy();
    result
}

/// In-page result reporter: Tauri event bridge when available, otherwise the
/// title channel (which only carries src/error — data URLs are too large).
const SEND_FN: &str = r#"
    const send = (p) => {
      try {
        if (window.__TAURI__ && window.__TAURI__.event) {
          window.__TAURI__.event.emit('gemini-web-result', p);
          return;
        }
      } catch (e) {}
      try {
        const slim = { src: p.src || '', error: p.error || (p.dataUrl ? '' : 'no result') };
        document.title = 'NEETPG_RESULT:' + JSON.stringify(slim);
      } catch (e) {}
    };
    const sleep = (ms) => new Promise(r => setTimeout(r, ms));
    const findEditor = () =>
      document.querySelector('rich-textarea .ql-editor[contenteditable="true"]') ||
      document.querySelector('div.ql-editor[contenteditable="true"]') ||
      document.querySelector('[contenteditable="true"][role="textbox"]') ||
      document.querySelector('textarea');
"#;

fn probe_script() -> String {
    format!(
        r#"(async () => {{
    {SEND_FN}
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
    {SEND_FN}
    try {{
      let editor = null;
      for (let i = 0; i < 40 && !editor; i++) {{ editor = findEditor(); if (!editor) await sleep(500); }}
      if (!editor) {{ send({{ error: location.hostname.includes('accounts.google') ? 'not-signed-in' : 'no-input' }}); return; }}

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
        editor.dispatchEvent(new KeyboardEvent('keydown', {{ key: 'Enter', code: 'Enter', keyCode: 13, bubbles: true }}));
      }}

      const good = (s) => /googleusercontent|lh3\.google|generativelanguage|blob:|data:image/i.test(s || '');
      const bad = (s) => /avatar|icon|logo|sprite|emoji/i.test(s || '');
      const big = (img) => (img.naturalWidth || img.width || 0) > 200 && (img.naturalHeight || img.height || 0) > 200;
      const candidates = () => {{
        const out = [];
        const scopes = document.querySelectorAll('[class*="response"],[class*="message"],[class*="conversation"],[class*="model"]');
        scopes.forEach(c => c.querySelectorAll('img').forEach(img => {{
          const s = img.currentSrc || img.src || '';
          if (good(s) && !bad(s) && big(img)) out.push(img);
        }}));
        if (!out.length) {{
          document.querySelectorAll('img').forEach(img => {{
            const s = img.currentSrc || img.src || '';
            if (good(s) && !bad(s) && big(img)) out.push(img);
          }});
        }}
        return out;
      }};

      const deadline = Date.now() + 90000;
      let imgEl = null;
      while (Date.now() < deadline && !imgEl) {{
        const c = candidates();
        if (c.length) {{ imgEl = c[c.length - 1]; break; }}
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
