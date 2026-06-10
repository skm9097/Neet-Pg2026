// Bridges the UI to the Rust core. Implements the same `window.api` surface
// the components were written against, over Tauri's typed invoke/event system.

import { invoke } from '@tauri-apps/api/core'
import { listen } from '@tauri-apps/api/event'
import { getCurrentWindow } from '@tauri-apps/api/window'
import type { AppConfig, AppMode, DesktopApi, SyncStatus } from './types'

function on<T>(event: string, cb: (payload: T) => void): () => void {
  let dead = false
  let unsub: (() => void) | null = null
  listen<T>(event, (e) => cb(e.payload)).then((fn) => {
    if (dead) fn()
    else unsub = fn
  })
  return () => {
    dead = true
    unsub?.()
  }
}

export const api: DesktopApi = {
  getConfig: () => invoke('get_config'),
  saveConfig: (patch: Partial<AppConfig>) => invoke('save_config', { patch }),
  getCards: () => invoke('get_cards'),
  getDueCards: (limit: number) => invoke('get_due_cards', { limit }),
  getReviewFeed: (limit: number) => invoke('get_review_feed', { limit }),
  getNextQuizCard: () => invoke('get_next_quiz_card'),
  gradeCard: (cardId: string, grade: number) => invoke('grade_card', { cardId, grade }),
  getStats: () => invoke('get_stats'),
  getAppInfo: () => invoke('get_app_info'),
  syncNow: () => invoke('sync_now'),
  getSyncStatus: () => invoke('get_sync_status'),
  llmGenerate: (type, cardId: string) => invoke('llm_generate', { genType: type, cardId }),
  getCardImage: (cardId: string) => invoke('get_card_image', { cardId }),
  getImageReport: () => invoke('get_image_report'),
  regenerateImage: (cardId: string) => invoke('regenerate_image', { cardId }),
  generateImagesNow: () => invoke('generate_images_now'),
  testGithub: () => invoke('test_github'),
  testGroq: () => invoke('test_groq'),
  testGemini: () => invoke('test_image_source'),
  getIdleSeconds: () => invoke('get_idle_seconds'),
  setKeepAwake: (onAwake: boolean) => {
    invoke('set_keep_awake', { on: onAwake }).catch(() => {})
  },

  setMode: () => {
    /* mode is fully renderer-owned in the Tauri build */
  },
  minimizeWindow: () => {
    getCurrentWindow().minimize().catch(() => {})
  },
  hideWindow: () => {
    getCurrentWindow().hide().catch(() => {})
  },
  setFullscreen: (onFs: boolean) => {
    getCurrentWindow().setFullscreen(onFs).catch(() => {})
  },

  onModeChange: (cb: (mode: AppMode) => void) => on<AppMode>('mode-change', cb),
  onCardsUpdated: (cb: (count: number) => void) => on<number>('cards-updated', cb),
  onTriggerQuiz: (cb: () => void) => on<unknown>('trigger-quiz', () => cb()),
  onSyncStatus: (cb: (status: SyncStatus) => void) => on<SyncStatus>('sync-status', cb),
  onTraySync: (cb: () => void) => on<unknown>('tray-sync', () => cb())
}

declare global {
  interface Window {
    api: DesktopApi
  }
}
window.api = api
