import Store from 'electron-store'
import type { AppConfig } from '../shared/types'

export const DEFAULT_CONFIG: AppConfig = {
  // Defaults point at the user's own NEET-PG question bank.
  repoOwner: 'skm9097',
  repoName: 'Neet-Pg2026',
  repoBranch: 'main',
  githubPat: '',

  groqApiKey: '',
  enableMnemonics: true,
  enableRephrase: true,

  enableCardImages: true,
  imageProvider: 'cloudflare',
  geminiApiKey: '',
  geminiImageModel: 'gemini-2.5-flash-image',
  cfAccountId: '',
  cfApiToken: '',
  cfImageModel: '@cf/black-forest-labs/flux-1-schnell',
  imagesPerDay: 20,
  pushImagesToRepo: true,

  syncIntervalMinutes: 5,
  quizIntervalMinutes: 30,
  idleThresholdMinutes: 5,
  ambientCardSeconds: 20,
  cardsPerDayTarget: 50,

  fontSize: 26,
  animSpeed: 'normal',
  accentHue: 'blue',
  themeVariant: 'midnight',

  startOnBoot: false,
  // Off by default: closing the window quits the app cleanly. Users can opt into
  // a persistent tray process, but the default never leaves a stubborn
  // background task that an installer/uninstaller can't close.
  minimizeToTray: false,
  autoAmbientOnIdle: true,
  keepAwakeInAmbient: false,

  configured: false
}

// Bump when a one-time config migration is needed.
const SCHEMA_VERSION = 3

// electron-store persists to %APPDATA%/neetpg-desktop/config.json on Windows.
export const store = new Store<AppConfig>({
  name: 'config',
  defaults: DEFAULT_CONFIG
})

// One-time migrations for users upgrading from an older build.
;(function migrate(): void {
  const s = store as unknown as {
    get: (k: string) => unknown
    set: (k: string, v: unknown) => void
  }
  const schema = (s.get('_schema') as number) || 1
  if (schema < 2) {
    // 1.2.0 shipped minimizeToTray=true, which left a sticky background process
    // the installer couldn't close. Flip upgraders to the clean default once.
    s.set('minimizeToTray', false)
  }
  if (schema < 3) {
    // 1.5.0 moves image generation to Cloudflare Workers AI.
    s.set('imageProvider', 'cloudflare')
  }
  if (schema < SCHEMA_VERSION) s.set('_schema', SCHEMA_VERSION)
})()

export function getConfig(): AppConfig {
  // Merge persisted values over defaults so new keys always resolve.
  return { ...DEFAULT_CONFIG, ...(store.store as Partial<AppConfig>) }
}

export function saveConfig(patch: Partial<AppConfig>): AppConfig {
  const next = { ...getConfig(), ...patch }
  store.set(next as unknown as Record<string, unknown>)
  return next
}
