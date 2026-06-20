import { Tray, Menu, app, nativeImage, BrowserWindow } from 'electron'
import { join } from 'path'

/** System tray icon + right-click menu. Lets the app live in the background. */
export function createTray(
  getWindow: () => BrowserWindow | null,
  send: (channel: string, ...args: unknown[]) => void,
  syncNow: () => void
): Tray {
  const iconPath = join(__dirname, '../../resources/icon.png')
  let image = nativeImage.createFromPath(iconPath)
  if (image.isEmpty()) {
    // Fallback 1x1 so the tray never crashes if the asset is missing.
    image = nativeImage.createEmpty()
  } else {
    image = image.resize({ width: 18, height: 18 })
  }

  const tray = new Tray(image)

  const showAmbient = (): void => {
    const win = getWindow()
    if (!win) return
    win.show()
    win.setFullScreen(true)
    send('mode-change', 'ambient')
  }

  const openDashboard = (): void => {
    const win = getWindow()
    if (!win) return
    win.show()
    win.setFullScreen(false)
    win.setSize(1280, 820)
    win.center()
    send('mode-change', 'dashboard')
  }

  const openSettings = (): void => {
    const win = getWindow()
    if (!win) return
    win.show()
    win.setFullScreen(false)
    win.setSize(1100, 800)
    win.center()
    send('mode-change', 'settings')
  }

  const menu = Menu.buildFromTemplate([
    { label: 'Show Ambient Mode', click: showAmbient },
    { label: 'Open Dashboard', click: openDashboard },
    { label: 'Settings', click: openSettings },
    { type: 'separator' },
    { label: 'Sync Now', click: syncNow },
    { type: 'separator' },
    {
      label: 'Quit',
      click: () => {
        ;(app as unknown as { isQuitting: boolean }).isQuitting = true
        app.quit()
      }
    }
  ])

  tray.setToolTip('NEET PG Desktop')
  tray.setContextMenu(menu)
  tray.on('click', () => {
    const win = getWindow()
    if (!win) return
    if (win.isVisible()) win.hide()
    else win.show()
  })

  return tray
}
