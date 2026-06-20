import { BrowserWindow, session } from 'electron'

// A dedicated, persistent session so the Google login survives restarts and is
// shared between the visible sign-in window and the hidden generation window.
const PARTITION = 'persist:gemini-web'
const GEMINI_URL = 'https://gemini.google.com/app'
// Present as a normal desktop Chrome so Google serves the standard UI rather
// than the "Electron" client (which it may block or downgrade).
const UA =
  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 ' +
  '(KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36'

// sec-ch-ua client hints to send alongside the spoofed UA.
// The default Electron value includes "Electron" as a brand, which triggers
// Google's "browser is not secure" block even when the UA header is overridden.
const CH_UA = '"Google Chrome";v="126", "Chromium";v="126", "Not-A.Brand";v="99"'

/**
 * Drives the Gemini *website* (not the API) to generate images using the user's
 * own signed-in Google account. The user authenticates once in a normal browser
 * window; thereafter a hidden window loads gemini.google.com, types the prompt,
 * submits it, waits for the generated image, and returns its bytes.
 *
 * This is browser automation of a third-party site for personal use, so it is
 * inherently best-effort: selectors can change and every path fails soft to a
 * placeholder. It's offered as one image-source option alongside the API key
 * and the keyless Pollinations source.
 */
export class GeminiWebService {
  private signInWin: BrowserWindow | null = null
  /** The single in-flight hidden generation window. Tracked so an orphan from a
   *  previous (hung/crashed) cycle is always destroyed before a new one opens. */
  private genWin: BrowserWindow | null = null
  private busy = false
  private sessionReady = false

  private sess(): Electron.Session {
    return session.fromPartition(PARTITION)
  }

  /**
   * Configures the persistent session once: sets the session-level UA and
   * installs a request-header interceptor that replaces sec-ch-ua client hints
   * with real Chrome values. This is the core fix for Google's
   * "browser is not secure" sign-in block — the per-window setUserAgent() call
   * alone doesn't cover client hints, which still expose "Electron" as the
   * browser brand.
   */
  private setupSession(): void {
    if (this.sessionReady) return
    this.sessionReady = true
    const ses = this.sess()
    ses.setUserAgent(UA)
    ses.webRequest.onBeforeSendHeaders(
      { urls: ['https://*.google.com/*', 'https://gemini.google.com/*'] },
      (details, callback) => {
        const headers = { ...details.requestHeaders }
        headers['User-Agent'] = UA
        headers['sec-ch-ua'] = CH_UA
        headers['sec-ch-ua-mobile'] = '?0'
        headers['sec-ch-ua-platform'] = '"Windows"'
        callback({ requestHeaders: headers })
      }
    )
  }

  /** Whether a Google login cookie is present in the dedicated session. */
  async status(): Promise<{ signedIn: boolean; message: string }> {
    this.setupSession()
    try {
      const cookies = await this.sess().cookies.get({ domain: '.google.com' })
      const signed = cookies.some((c) => /^(__Secure-1PSID|__Secure-3PSID|SID)$/.test(c.name))
      return {
        signedIn: signed,
        message: signed ? 'Signed in to your Google account' : 'Not signed in yet'
      }
    } catch (e) {
      return { signedIn: false, message: (e as Error).message }
    }
  }

  /** Open a visible window for the user to log into Gemini. */
  async signIn(): Promise<{ ok: boolean; message: string }> {
    this.setupSession()
    if (this.signInWin && !this.signInWin.isDestroyed()) {
      this.signInWin.focus()
      return { ok: true, message: 'Sign-in window is already open' }
    }
    const win = new BrowserWindow({
      width: 960,
      height: 760,
      show: true,
      title: 'Sign in to Gemini',
      autoHideMenuBar: true,
      webPreferences: {
        partition: PARTITION,
        contextIsolation: true,
        nodeIntegration: false,
        // sandbox: false lets Electron inject the preload that patches
        // navigator properties; combined with the session-level UA and
        // header interceptor this gives the window a clean Chrome fingerprint.
        sandbox: false
      }
    })
    this.signInWin = win
    // Belt-and-suspenders: set UA on the window's webContents as well
    // (the session setUserAgent covers requests; this covers JS navigator.userAgent).
    win.webContents.setUserAgent(UA)
    win.on('closed', () => {
      this.signInWin = null
    })
    try {
      await win.loadURL(GEMINI_URL)
    } catch {
      // ignore navigation hiccups — the user can still complete login
    }
    return {
      ok: true,
      message: 'Sign-in window opened — log in to your Google account, then close the window.'
    }
  }

  /** Forget the stored Google session. */
  async signOut(): Promise<{ ok: boolean; message: string }> {
    try {
      await this.sess().clearStorageData()
      return { ok: true, message: 'Signed out of Gemini' }
    } catch (e) {
      return { ok: false, message: (e as Error).message }
    }
  }

  /** Destroy the tracked generation window (if any) and null the reference. */
  private destroyGenWin(): void {
    try {
      if (this.genWin && !this.genWin.isDestroyed()) this.genWin.destroy()
    } catch {
      // ignore — a window already being torn down can throw
    }
    this.genWin = null
  }

  /** Generate one image for the prompt via a hidden Gemini window. */
  async generate(prompt: string): Promise<Buffer | null> {
    this.setupSession()
    // Serialise generations — one hidden window at a time.
    const start = Date.now()
    while (this.busy) {
      if (Date.now() - start > 180000) return null
      await delay(500)
    }
    this.busy = true

    // Kill any orphan from a previous cycle (e.g. a hung page that escaped the
    // finally below) before we ever create another window.
    this.destroyGenWin()

    try {
      if (!(await this.status()).signedIn) return null

      const win = new BrowserWindow({
        // Far offscreen + hidden + skip-taskbar so this generation window is
        // bulletproof-invisible and can never flash or pile up on the user's
        // screen. backgroundThrottling:false keeps the Gemini SPA executing
        // JS and producing the image even though the window is never shown.
        x: -32000,
        y: -32000,
        width: 1180,
        height: 900,
        show: false,
        skipTaskbar: true,
        minimizable: false,
        fullscreenable: false,
        webPreferences: {
          partition: PARTITION,
          contextIsolation: true,
          nodeIntegration: false,
          sandbox: false,
          backgroundThrottling: false
        }
      })
      this.genWin = win
      // Session-level UA covers HTTP requests; this covers navigator.userAgent in JS.
      win.webContents.setUserAgent(UA)
      await win.loadURL(GEMINI_URL)
      // Let the single-page app boot before we touch the DOM.
      await delay(3500)
      if (win.isDestroyed()) return null

      const webPrompt = `Generate a single illustrative image (no text or letters inside the image). ${prompt}`
      const script = driverScript(webPrompt)
      // Hard timeout around the in-page driver so a hung page can never leak a
      // window: on timeout we return null and the finally below destroys it.
      const result = await withTimeout(
        win.webContents.executeJavaScript(script, true) as Promise<DriverResult>,
        100000
      )

      if (result?.dataUrl && result.dataUrl.startsWith('data:image')) {
        const b64 = result.dataUrl.split(',')[1] || ''
        const buf = Buffer.from(b64, 'base64')
        return buf.length > 256 ? buf : null
      }
      if (result?.src) {
        const buf = await fetchBytes(result.src)
        if (buf && buf.length > 256) return buf
      }
      return null
    } catch {
      return null
    } finally {
      // Always tear the hidden window down and drop the reference.
      this.destroyGenWin()
      this.busy = false
    }
  }
}

/**
 * Resolve with the promise's value, or with null if it doesn't settle within
 * `ms`. Never rejects — a timed-out generation is just a soft miss.
 */
function withTimeout<T>(p: Promise<T>, ms: number): Promise<T | null> {
  return new Promise<T | null>((resolve) => {
    let settled = false
    const t = setTimeout(() => {
      if (settled) return
      settled = true
      resolve(null)
    }, ms)
    p.then(
      (v) => {
        if (settled) return
        settled = true
        clearTimeout(t)
        resolve(v)
      },
      () => {
        if (settled) return
        settled = true
        clearTimeout(t)
        resolve(null)
      }
    )
  })
}

interface DriverResult {
  dataUrl?: string
  src?: string
  error?: string
}

async function fetchBytes(url: string): Promise<Buffer | null> {
  try {
    const res = await fetch(url)
    if (!res.ok) return null
    return Buffer.from(await res.arrayBuffer())
  } catch {
    return null
  }
}

function delay(ms: number): Promise<void> {
  return new Promise((r) => setTimeout(r, ms))
}

/**
 * The in-page automation, returned as a self-contained async IIFE string.
 * Finds the composer, types the prompt, submits, then waits for a generated
 * image and returns it as a data URL (fetched in-page so cookies/origin apply).
 */
function driverScript(prompt: string): string {
  const P = JSON.stringify(prompt)
  return `(async () => {
    const sleep = (ms) => new Promise(r => setTimeout(r, ms));
    const findEditor = () =>
      document.querySelector('rich-textarea .ql-editor[contenteditable="true"]') ||
      document.querySelector('div.ql-editor[contenteditable="true"]') ||
      document.querySelector('[contenteditable="true"][role="textbox"]') ||
      document.querySelector('textarea');

    let editor = null;
    for (let i = 0; i < 40 && !editor; i++) { editor = findEditor(); if (!editor) await sleep(500); }
    if (!editor) return { error: 'no-input' };

    editor.focus();
    if (editor.tagName === 'TEXTAREA') {
      editor.value = ${P};
      editor.dispatchEvent(new Event('input', { bubbles: true }));
    } else {
      editor.textContent = '';
      try { document.execCommand('insertText', false, ${P}); } catch (e) {}
      if (!editor.textContent) editor.textContent = ${P};
      editor.dispatchEvent(new InputEvent('input', { bubbles: true }));
    }
    await sleep(600);

    const findSend = () =>
      document.querySelector('button[aria-label*="Send" i]:not([disabled])') ||
      document.querySelector('button.send-button:not([disabled])') ||
      Array.from(document.querySelectorAll('button')).find(b =>
        /send/i.test((b.getAttribute('aria-label') || '') + ' ' + (b.textContent || '')) && !b.disabled);

    let sent = false;
    for (let i = 0; i < 12 && !sent; i++) {
      const b = findSend();
      if (b) { b.click(); sent = true; break; }
      await sleep(400);
    }
    if (!sent) {
      editor.dispatchEvent(new KeyboardEvent('keydown', { key: 'Enter', code: 'Enter', keyCode: 13, bubbles: true }));
    }

    const good = (s) => /googleusercontent|lh3\\.google|generativelanguage|blob:|data:image/i.test(s || '');
    const bad = (s) => /avatar|icon|logo|sprite|emoji/i.test(s || '');
    const big = (img) => (img.naturalWidth || img.width || 0) > 200 && (img.naturalHeight || img.height || 0) > 200;
    const candidates = () => {
      const out = [];
      const scopes = document.querySelectorAll(
        '[class*="response"],[class*="message"],[class*="conversation"],[class*="model"]'
      );
      scopes.forEach(c => c.querySelectorAll('img').forEach(img => {
        const s = img.currentSrc || img.src || '';
        if (good(s) && !bad(s) && big(img)) out.push(img);
      }));
      if (!out.length) {
        document.querySelectorAll('img').forEach(img => {
          const s = img.currentSrc || img.src || '';
          if (good(s) && !bad(s) && big(img)) out.push(img);
        });
      }
      return out;
    };

    const deadline = Date.now() + 90000;
    let imgEl = null;
    while (Date.now() < deadline && !imgEl) {
      const c = candidates();
      if (c.length) { imgEl = c[c.length - 1]; break; }
      await sleep(1500);
    }
    if (!imgEl) return { error: 'no-image' };

    const src = imgEl.currentSrc || imgEl.src;
    try {
      const resp = await fetch(src);
      const blob = await resp.blob();
      const dataUrl = await new Promise((res, rej) => {
        const fr = new FileReader();
        fr.onload = () => res(fr.result);
        fr.onerror = rej;
        fr.readAsDataURL(blob);
      });
      return { dataUrl };
    } catch (e) {
      return { src, error: 'fetch-failed' };
    }
  })()`
}
