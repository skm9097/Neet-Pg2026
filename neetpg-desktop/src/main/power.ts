import { powerSaveBlocker, app } from 'electron'

/**
 * Wake / power controls.
 *  - keepAwake(): prevents the display from sleeping while ambient mode is on
 *    (so the "screensaver" review actually stays visible all day).
 *  - setLoginItem(): the Windows "start on boot" permission.
 */
export class PowerControl {
  private blockerId: number | null = null

  keepAwake(enabled: boolean): void {
    if (enabled) {
      if (this.blockerId === null || !powerSaveBlocker.isStarted(this.blockerId)) {
        this.blockerId = powerSaveBlocker.start('prevent-display-sleep')
      }
    } else {
      this.release()
    }
  }

  release(): void {
    if (this.blockerId !== null && powerSaveBlocker.isStarted(this.blockerId)) {
      powerSaveBlocker.stop(this.blockerId)
    }
    this.blockerId = null
  }

  setLoginItem(openAtLogin: boolean): void {
    try {
      app.setLoginItemSettings({
        openAtLogin,
        path: app.getPath('exe'),
        args: ['--hidden']
      })
    } catch {
      // Not fatal — login-item registration can fail in dev / unpackaged runs.
    }
  }
}
