import { contextBridge, ipcRenderer } from 'electron'
import type { AppConfig, AppMode, DesktopApi, SyncStatus } from '../shared/types'

const api: DesktopApi = {
  getConfig: () => ipcRenderer.invoke('get-config'),
  saveConfig: (patch: Partial<AppConfig>) => ipcRenderer.invoke('save-config', patch),
  getCards: () => ipcRenderer.invoke('get-cards'),
  getDueCards: (limit: number) => ipcRenderer.invoke('get-due-cards', limit),
  getReviewFeed: (limit: number) => ipcRenderer.invoke('get-review-feed', limit),
  getNextQuizCard: () => ipcRenderer.invoke('get-next-quiz-card'),
  gradeCard: (cardId: string, grade: number) => ipcRenderer.invoke('grade-card', cardId, grade),
  getStats: () => ipcRenderer.invoke('get-stats'),
  getAppInfo: () => ipcRenderer.invoke('get-app-info'),
  syncNow: () => ipcRenderer.invoke('sync-now'),
  getSyncStatus: () => ipcRenderer.invoke('get-sync-status'),
  llmGenerate: (type, cardId: string) => ipcRenderer.invoke('llm-generate', type, cardId),
  getCardImage: (cardId: string) => ipcRenderer.invoke('get-card-image', cardId),
  getImageReport: () => ipcRenderer.invoke('get-image-report'),
  regenerateImage: (cardId: string) => ipcRenderer.invoke('regenerate-image', cardId),
  generateImagesNow: () => ipcRenderer.invoke('generate-images-now'),
  testGithub: () => ipcRenderer.invoke('test-github'),
  testGroq: () => ipcRenderer.invoke('test-groq'),
  testGemini: () => ipcRenderer.invoke('test-gemini'),
  geminiWebSignIn: () => ipcRenderer.invoke('gemini-web-signin'),
  geminiWebStatus: () => ipcRenderer.invoke('gemini-web-status'),
  geminiWebSignOut: () => ipcRenderer.invoke('gemini-web-signout'),

  setMode: (mode: AppMode) => ipcRenderer.send('set-mode', mode),
  minimizeWindow: () => ipcRenderer.send('window-minimize'),
  hideWindow: () => ipcRenderer.send('window-hide'),
  setFullscreen: (on: boolean) => ipcRenderer.send('window-fullscreen', on),

  onModeChange: (cb: (mode: AppMode) => void) => {
    const listener = (_e: unknown, mode: AppMode): void => cb(mode)
    ipcRenderer.on('mode-change', listener)
    return () => ipcRenderer.removeListener('mode-change', listener)
  },
  onCardsUpdated: (cb: (count: number) => void) => {
    const listener = (_e: unknown, count: number): void => cb(count)
    ipcRenderer.on('cards-updated', listener)
    return () => ipcRenderer.removeListener('cards-updated', listener)
  },
  onTriggerQuiz: (cb: () => void) => {
    const listener = (): void => cb()
    ipcRenderer.on('trigger-quiz', listener)
    return () => ipcRenderer.removeListener('trigger-quiz', listener)
  },
  onSyncStatus: (cb: (status: SyncStatus) => void) => {
    const listener = (_e: unknown, status: SyncStatus): void => cb(status)
    ipcRenderer.on('sync-status', listener)
    return () => ipcRenderer.removeListener('sync-status', listener)
  }
}

contextBridge.exposeInMainWorld('api', api)
