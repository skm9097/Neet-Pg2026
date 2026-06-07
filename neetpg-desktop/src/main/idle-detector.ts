import { powerMonitor } from 'electron'

/**
 * Polls the OS idle timer and fires a callback when the user crosses the idle
 * threshold in either direction. Used to auto-switch into ambient (screensaver)
 * mode when the desk is unattended, and back to active when they return.
 */
export class IdleDetector {
  private timer: NodeJS.Timeout | null = null
  private wasIdle = false

  constructor(
    private thresholdMinutes: () => number,
    private onChange: (isIdle: boolean) => void
  ) {}

  start(): void {
    this.stop()
    this.timer = setInterval(() => {
      const idleSeconds = powerMonitor.getSystemIdleTime()
      const isIdle = idleSeconds >= this.thresholdMinutes() * 60
      if (isIdle !== this.wasIdle) {
        this.wasIdle = isIdle
        this.onChange(isIdle)
      }
    }, 15_000)
  }

  stop(): void {
    if (this.timer) clearInterval(this.timer)
    this.timer = null
  }
}
