import { app, BrowserWindow, globalShortcut, Tray } from 'electron'
import { join } from 'path'
import type { AppConfig, AppMode } from '../shared/types'
import { getConfig } from './store'
import { CardCache } from './cache'
import { SREngine } from './sr-engine'
import { LLMService } from './llm-service'
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

// ── Services (config-bound via getters so live setting changes take effect) ──
let cache: CardCache
let sr: SREngine
let llm: LLMService
let repo: RepoSync
let syncer: Syncer
let idle: IdleDetector
const power = new PowerControl()

function createWindow(): void {
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
      })
      .catch(() => {})
  }, minutes * 60 * 1000)
}

function startQuizTimer(): void {
  clearQuizTimer()
  const minutes = Math.max(5, getConfig().quizIntervalMinutes)
  quizTimer = setTimeout(() => {
    if (currentMode !== 'ambient') send('trigger-quiz')
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
  repo = new RepoSync(() => getConfig())
  syncer = new Syncer(() => getConfig(), repo, cache, sr, llm)

  registerIpc({
    cache,
    sr,
    llm,
    repo,
    syncer,
    getWindow,
    onConfigChanged: (cfg) => applyConfig(cfg)
  })

  createWindow()
  tray = createTray(getWindow, send, () => {
    syncer.sync().then((r) => {
      if (r.changed > 0) send('cards-updated', r.changed)
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
      })
    }, 1500)
  }

  app.on('activate', () => {
    if (BrowserWindow.getAllWindows().length === 0) createWindow()
  })
})

app.on('window-all-closed', () => {
  // Stay alive in the tray on Windows/Linux; only quit explicitly.
  if (process.platform === 'darwin') app.quit()
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
