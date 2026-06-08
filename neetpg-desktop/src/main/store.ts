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
  imageProvider: 'gemini-web',
  geminiApiKey: '',
  geminiImageModel: 'gemini-2.5-flash-image',

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
  minimizeToTray: true,
  autoAmbientOnIdle: true,
  keepAwakeInAmbient: false,

  configured: false
}

// electron-store persists to %APPDATA%/neetpg-desktop/config.json on Windows.
export const store = new Store<AppConfig>({
  name: 'config',
  defaults: DEFAULT_CONFIG
})

export function getConfig(): AppConfig {
  // Merge persisted values over defaults so new keys always resolve.
  return { ...DEFAULT_CONFIG, ...(store.store as Partial<AppConfig>) }
}

export function saveConfig(patch: Partial<AppConfig>): AppConfig {
  const next = { ...getConfig(), ...patch }
  store.set(next as unknown as Record<string, unknown>)
  return next
}
