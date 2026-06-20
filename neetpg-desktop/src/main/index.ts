import { app, BrowserWindow, globalShortcut, Tray } from 'electron'

// Must be set before app is ready. Removes the "AutomationControlled" Blink
// feature flag that signals to sites (including Google) that the browser is
// being driven programmatically.
app.commandLine.appendSwitch('disable-blink-features', 'AutomationControlled')
import { join } from 'path'
import type { AppConfig, AppMode } from '../shared/types'
import { getConfig } from './store'
import { CardCache } from './cache'
import { SREngine } from './sr-engine'
import { LLMService } from './llm-service'
import { ImageGenService } from './image-gen'
import { GeminiWebService } from './gemini-web'
import { RepoSync } from './repo-sync'
import { Syncer } from './syncer'
import { IdleDetector } from './idle-detector'
import { PowerControl } from './power'
import { createTray } from './tray'
import { registerIpc } from './ipc-handlers'

let mainWindow: BrowserWindow | null = null
let tray: Tray | null = null
let syncTimer: NodeJS.Timeout | null = null
let quizTimer: NodeJS.Timeout | null = null
let currentMode: AppMode = 'ambient'

const getWindow = (): BrowserWindow | null => mainWindow
const send = (channel: string, ...args: unknown[]): void => {
  mainWindow?.webContents.send(channel, ...args)
}

// Single-instance lock: never let a second copy of the app start. Without this,
// re-launches (and the installer relaunching) pile up multiple background
// processes — a major cause of the app feeling heavy and "taking over" the PC.
const gotLock = app.requestSingleInstanceLock()
if (!gotLock) {
  app.quit()
} else {
  app.on('second-instance', () => {
    // A second launch just focuses the existing window instead of starting anew.
    if (mainWindow) {
      if (mainWindow.isMinimized()) mainWindow.restore()
      mainWindow.show()
      mainWindow.focus()
    }
  })
}

// ── Services (config-bound via getters so live setting changes take effect) ──
let cache: CardCache
let sr: SREngine
let llm: LLMService
let imageGen: ImageGenService
let geminiWeb: GeminiWebService
let repo: RepoSync
let syncer: Syncer
let idle: IdleDetector
const power = new PowerControl()

/** Warm a few upcoming card images so the ambient hero is ready before display. */
function warmImages(): void {
  const cfg = getConfig()
  if (!cfg.enableCardImages) return
  // Nothing to warm (and nothing to show) until cards have actually synced in.
  if (cache.allCards().length === 0) return
  // The 'gemini-web' source drives a real (hidden) Chromium window per image —
  // far too heavy to run on every background sync cycle (this was the app
  // "taking over" the PC). For that source we never pre-warm; images are
  // generated lazily, only while a card is actually on screen. Light HTTP
  // sources (Cloudflare / API / Pollinations) warm a few upcoming cards per
  // cycle; the per-day budget inside ImageGenService caps the total.
  if (cfg.imageProvider === 'gemini-web') return
  const pending = cache.allCards().filter((c) => !imageGen.hasImage(c))
  if (!pending.length) return
  imageGen.pregenerate(pending, 3).catch(() => {})
}

function createWindow(): void {
  // Never create a second main window — reuse the existing one if it's alive.
  if (mainWindow && !mainWindow.isDestroyed()) {
    mainWindow.show()
    return
  }
  const cfg = getConfig()
  mainWindow = new BrowserWindow({
    width: 1280,
    height: 820,
    show: false,
    frame: false,
    backgroundColor: '#0b0e18',
    fullscreen: cfg.configured,
    autoHideMenuBar: true,
    webPreferences: {
      preload: join(__dirname, '../preload/index.js'),
      contextIsolation: true,
      nodeIntegration: false,
      sandbox: false
    }
  })

  mainWindow.on('ready-to-show', () => mainWindow?.show())

  // Drop the reference once the window is truly gone so any later recreate
  // (e.g. macOS 'activate') makes exactly one fresh window, never a duplicate.
  mainWindow.on('closed', () => {
    mainWindow = null
  })

  // Minimize-to-tray: closing hides the window instead of quitting.
  mainWindow.on('close', (e) => {
    const isQuitting = (app as unknown as { isQuitting?: boolean }).isQuitting
    if (!isQuitting && getConfig().minimizeToTray) {
      e.preventDefault()
      mainWindow?.hide()
    }
  })

  if (process.env['ELECTRON_RENDERER_URL']) {
    mainWindow.loadURL(process.env['ELECTRON_RENDERER_URL'])
  } else {
    mainWindow.loadFile(join(__dirname, '../renderer/index.html'))
  }
}

function applyConfig(cfg: AppConfig): void {
  power.setLoginItem(cfg.startOnBoot)
  power.keepAwake(cfg.keepAwakeInAmbient && currentMode === 'ambient')
  restartSyncTimer(cfg)
}

function restartSyncTimer(cfg: AppConfig): void {
  if (syncTimer) clearInterval(syncTimer)
  const minutes = Math.max(1, cfg.syncIntervalMinutes)
  syncTimer = setInterval(() => {
    syncer
      .sync()
      .then((r) => {
        if (r.changed > 0) send('cards-updated', r.changed)
        warmImages()
      })
      .catch(() => {})
  }, minutes * 60 * 1000)
}

function startQuizTimer(): void {
  clearQuizTimer()
  const minutes = Math.max(5, getConfig().quizIntervalMinutes)
  quizTimer = setTimeout(() => {
    // Only nudge a quiz when there's actually something to quiz on; a popup with
    // no card data is exactly the "blank window" bug. The renderer guards too.
    if (currentMode !== 'ambient' && cache.allCards().length > 0) send('trigger-quiz')
    startQuizTimer()
  }, minutes * 60 * 1000)
}

function clearQuizTimer(): void {
  if (quizTimer) clearTimeout(quizTimer)
  quizTimer = null
}

function handleIdleChange(isIdle: boolean): void {
  const cfg = getConfig()
  if (!cfg.autoAmbientOnIdle) return
  if (isIdle) {
    // Never force a blank fullscreen ambient window when there's nothing to
    // show. With zero cards the ambient view has no question data, which is the
    // "blank window pops up" the user reported — so stay idle / no-op instead.
    if (cache.allCards().length === 0) return
    currentMode = 'ambient'
    clearQuizTimer()
    power.keepAwake(cfg.keepAwakeInAmbient)
    mainWindow?.show()
    mainWindow?.setFullScreen(true)
    send('mode-change', 'ambient')
  } else {
    currentMode = 'dashboard'
    power.keepAwake(false)
    startQuizTimer()
    send('mode-change', 'active')
  }
}

function registerShortcuts(): void {
  globalShortcut.register('CommandOrControl+Shift+N', () => {
    currentMode = 'dashboard'
    mainWindow?.show()
    mainWindow?.setFullScreen(false)
    mainWindow?.setSize(1280, 820)
    mainWindow?.center()
    send('mode-change', 'dashboard')
  })
  globalShortcut.register('CommandOrControl+Shift+M', () => {
    currentMode = 'ambient'
    mainWindow?.show()
    mainWindow?.setFullScreen(true)
    send('mode-change', 'ambient')
  })
}

app.whenReady().then(async () => {
  const userData = app.getPath('userData')

  cache = new CardCache(userData)
  sr = new SREngine(cache)
  llm = new LLMService(() => getConfig().groqApiKey)
  geminiWeb = new GeminiWebService()
  repo = new RepoSync(() => getConfig())
  imageGen = new ImageGenService(() => getConfig(), userData, geminiWeb, repo)
  syncer = new Syncer(() => getConfig(), repo, cache, sr, llm)
  // Push every sync-status transition to the renderer so the live Sync button
  // updates without the renderer having to poll getSyncStatus().
  syncer.setStatusSink((st) => send('sync-status', st))

  registerIpc({
    cache,
    sr,
    llm,
    imageGen,
    geminiWeb,
    repo,
    syncer,
    getWindow,
    onConfigChanged: (cfg) => applyConfig(cfg)
  })

  createWindow()
  tray = createTray(getWindow, send, () => {
    syncer.sync().then((r) => {
      if (r.changed > 0) send('cards-updated', r.changed)
      warmImages()
    })
  })

  registerShortcuts()

  const cfg = getConfig()
  applyConfig(cfg)

  // Idle detection drives ambient/active switching.
  idle = new IdleDetector(() => getConfig().idleThresholdMinutes, handleIdleChange)
  idle.start()

  // First sync shortly after launch (don't block window paint on the network).
  if (cfg.configured && cfg.githubPat) {
    setTimeout(() => {
      syncer.sync().then((r) => {
        if (r.changed > 0) send('cards-updated', r.changed)
        warmImages()
      })
    }, 1500)
  } else if (cfg.configured) {
    // Public-repo reads need no token — still warm images once cards land.
    setTimeout(warmImages, 4000)
  }

  app.on('activate', () => {
    if (BrowserWindow.getAllWindows().length === 0) createWindow()
  })
})

app.on('window-all-closed', () => {
  if (process.platform === 'darwin') return
  // Only linger in the tray if the user explicitly opted into it. By default,
  // closing the window quits the process cleanly — so the app never becomes a
  // stubborn background task the installer/uninstaller can't close.
  if (!getConfig().minimizeToTray) app.quit()
})

// Mark an intentional quit so the window 'close' handler stops sending the
// window to the tray (lets the installer, uninstaller, and tray-Quit all close
// the app for real).
app.on('before-quit', () => {
  ;(app as unknown as { isQuitting: boolean }).isQuitting = true
})

app.on('will-quit', () => {
  globalShortcut.unregisterAll()
  if (syncTimer) clearInterval(syncTimer)
  clearQuizTimer()
  idle?.stop()
  power.release()
  cache?.save()
})

// keep a reference so the tray isn't GC'd
void tray
