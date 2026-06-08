import { ipcMain, BrowserWindow } from 'electron'
import type { AppConfig, AppMode } from '../shared/types'
import { getConfig, saveConfig } from './store'
import { CardCache } from './cache'
import { SREngine } from './sr-engine'
import { LLMService } from './llm-service'
import { ImageGenService } from './image-gen'
import { RepoSync } from './repo-sync'
import { Syncer } from './syncer'
import { buildStats, withSR } from './stats'

const todayKey = (): string => new Date().toISOString().split('T')[0]

export interface Services {
  cache: CardCache
  sr: SREngine
  llm: LLMService
  imageGen: ImageGenService
  repo: RepoSync
  syncer: Syncer
  getWindow: () => BrowserWindow | null
  onConfigChanged: (cfg: AppConfig) => void
}

export function registerIpc(s: Services): void {
  ipcMain.handle('get-config', () => getConfig())

  ipcMain.handle('save-config', (_e, patch: Partial<AppConfig>) => {
    const next = saveConfig(patch)
    s.onConfigChanged(next)
    return next
  })

  ipcMain.handle('get-cards', () => s.cache.allCards().map((c) => withSR(c, s.cache)))

  ipcMain.handle('get-due-cards', (_e, limit: number) => {
    const today = todayKey()
    const sr = s.cache.allSR()
    const cards = s.cache.allCards().filter((c) => !c.isResolved)
    const due = cards.filter((c) => sr[c.id] && sr[c.id].nextReview <= today)
    const fresh = cards.filter((c) => !sr[c.id])
    const ordered = [...due, ...fresh, ...cards]
    const seen = new Set<string>()
    const out = ordered
      .filter((c) => (seen.has(c.id) ? false : (seen.add(c.id), true)))
      .slice(0, limit || 20)
    return out.map((c) => withSR(c, s.cache))
  })

  ipcMain.handle('get-next-quiz-card', () => {
    const id = s.sr.getNextCardId()
    if (!id) return null
    const card = s.cache.getCard(id)
    return card ? withSR(card, s.cache) : null
  })

  ipcMain.handle('grade-card', async (_e, cardId: string, grade: number) => {
    s.sr.gradeCard(cardId, grade)
    // Push SR progress in the background — never block the UI.
    const cfg = getConfig()
    if (cfg.githubPat) {
      s.syncer.sync().catch(() => {})
    }
  })

  ipcMain.handle('get-stats', () => buildStats(s.cache, s.sr))

  ipcMain.handle('sync-now', async () => {
    const result = await s.syncer.sync()
    const win = s.getWindow()
    if (win && result.changed > 0) win.webContents.send('cards-updated', result.changed)
    // Warm a few images so freshly-synced cards have a visual ready.
    const pending = s.cache.allCards().filter((c) => !s.imageGen.hasImage(c))
    if (pending.length) s.imageGen.pregenerate(pending, 3).catch(() => {})
    return result
  })

  ipcMain.handle('get-sync-status', () => s.syncer.getStatus())

  ipcMain.handle('llm-generate', async (_e, type: string, cardId: string) => {
    const cached = s.cache.getLLM(cardId, type)
    if (cached) return cached
    const card = s.cache.getCard(cardId)
    if (!card || !s.llm.configured) return null

    try {
      let result = ''
      if (type === 'mnemonic') {
        result = await s.llm.generateMnemonic(card)
      } else if (type === 'quiz_variant') {
        result = await s.llm.rephraseQuestion(card)
      } else if (type === 'comparison') {
        const related = s.cache
          .allCards()
          .find(
            (c) =>
              c.id !== cardId && c.subject === card.subject && c.errorType === 'conceptual'
          )
        if (!related) return null
        result = await s.llm.generateComparison(card, related)
      } else {
        return null
      }
      if (result) s.cache.setLLM(cardId, type, result)
      s.cache.save()
      return result || null
    } catch {
      return null
    }
  })

  // Per-card infographic image (generated on first request, cached thereafter).
  ipcMain.handle('get-card-image', async (_e, cardId: string) => {
    const card = s.cache.getCard(cardId)
    if (!card) return { cardId, status: 'error', dataUrl: null }
    const r = await s.imageGen.getDataUrl(card)
    return { cardId, status: r.status, dataUrl: r.dataUrl }
  })

  ipcMain.handle('test-github', () => s.repo.test())
  ipcMain.handle('test-groq', () => s.llm.test())
  ipcMain.handle('test-gemini', () => s.imageGen.test())

  // Renderer → main: user picked a mode via the sidebar.
  ipcMain.on('set-mode', (_e, mode: AppMode) => {
    const win = s.getWindow()
    if (win) win.webContents.send('mode-change', mode)
  })

  // Frameless window controls.
  ipcMain.on('window-minimize', () => s.getWindow()?.minimize())
  ipcMain.on('window-hide', () => s.getWindow()?.hide())
  ipcMain.on('window-fullscreen', (_e, on: boolean) => s.getWindow()?.setFullScreen(!!on))
}
