import { contextBridge, ipcRenderer } from 'electron'
import type { AppConfig, AppMode, DesktopApi } from '../shared/types'

const api: DesktopApi = {
  getConfig: () => ipcRenderer.invoke('get-config'),
  saveConfig: (patch: Partial<AppConfig>) => ipcRenderer.invoke('save-config', patch),
  getCards: () => ipcRenderer.invoke('get-cards'),
  getDueCards: (limit: number) => ipcRenderer.invoke('get-due-cards', limit),
  getNextQuizCard: () => ipcRenderer.invoke('get-next-quiz-card'),
  gradeCard: (cardId: string, grade: number) => ipcRenderer.invoke('grade-card', cardId, grade),
  getStats: () => ipcRenderer.invoke('get-stats'),
  syncNow: () => ipcRenderer.invoke('sync-now'),
  getSyncStatus: () => ipcRenderer.invoke('get-sync-status'),
  llmGenerate: (type, cardId: string) => ipcRenderer.invoke('llm-generate', type, cardId),
  testGithub: () => ipcRenderer.invoke('test-github'),
  testGroq: () => ipcRenderer.invoke('test-groq'),

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
  }
}

contextBridge.exposeInMainWorld('api', api)
