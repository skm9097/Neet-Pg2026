import { ipcMain, BrowserWindow, app } from 'electron'
import type { AppConfig, AppInfo, AppMode } from '../shared/types'
import { getConfig, saveConfig } from './store'
import { CardCache } from './cache'
import { SREngine } from './sr-engine'
import { LLMService } from './llm-service'
import { ImageGenService } from './image-gen'
import { GeminiWebService } from './gemini-web'
import { RepoSync } from './repo-sync'
import { Syncer } from './syncer'
import { buildReviewFeed, buildStats, withSR } from './stats'

const todayKey = (): string => new Date().toISOString().split('T')[0]

export interface Services {
  cache: CardCache
  sr: SREngine
  llm: LLMService
  imageGen: ImageGenService
  geminiWeb: GeminiWebService
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

  // Smart-review feed: due → weakest-topic unresolved → recent mistakes → fill.
  // De-duped by id and sliced to `limit` (default 20); never empty if any cards.
  ipcMain.handle('get-review-feed', (_e, limit: number) => {
    const feed = buildReviewFeed(s.cache).slice(0, limit || 20)
    return feed.map((c) => withSR(c, s.cache))
  })

  // Build/runtime info for the renderer's About panel + Sync button.
  ipcMain.handle('get-app-info', (): AppInfo => ({
    version: app.getVersion(),
    electron: process.versions.electron,
    platform: process.platform
  }))

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
    // Warm a few images for light HTTP sources only. The 'gemini-web' source
    // drives a hidden browser per image and must never be spawned in the
    // background — its images are generated lazily, only when a card is shown.
    if (getConfig().imageProvider !== 'gemini-web') {
      const pending = s.cache.allCards().filter((c) => !s.imageGen.hasImage(c))
      if (pending.length) s.imageGen.pregenerate(pending, 3).catch(() => {})
    }
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
    return { cardId, status: r.status, dataUrl: r.dataUrl, message: r.message }
  })

  // Image review screen: per-card status + daily quota.
  ipcMain.handle('get-image-report', () => s.imageGen.report(s.cache.allCards()))

  // Throw away one card's cached image and produce a fresh one (counts quota).
  ipcMain.handle('regenerate-image', async (_e, cardId: string) => {
    const card = s.cache.getCard(cardId)
    if (!card) return { cardId, status: 'error', dataUrl: null, message: 'Card not found' }
    await s.imageGen.regenerate(card)
    const r = await s.imageGen.getDataUrl(card)
    return { cardId, status: r.status, dataUrl: r.dataUrl, message: r.message }
  })

  // Batch-generate now, up to today's remaining budget.
  ipcMain.handle('generate-images-now', async () => {
    const pending = s.cache.allCards().filter((c) => !s.imageGen.hasImage(c))
    if (!pending.length) return { made: 0, message: 'All cards already have images' }
    const q = s.imageGen.quota()
    if (q.blockedUntil) {
      return {
        made: 0,
        message: `Provider limit hit — resumes ${new Date(q.blockedUntil).toLocaleString()}`
      }
    }
    const remaining = Math.max(0, q.limit - q.used)
    if (!remaining) return { made: 0, message: 'Daily budget used — resumes tomorrow' }
    const made = await s.imageGen.pregenerate(pending, remaining)
    return {
      made,
      message: made
        ? `Generated ${made} image${made === 1 ? '' : 's'}`
        : 'Nothing generated — check the errors below'
    }
  })

  ipcMain.handle('test-github', () => s.repo.test())
  ipcMain.handle('test-groq', () => s.llm.test())
  ipcMain.handle('test-gemini', () => s.imageGen.test())

  // Gemini website sign-in (used by the 'gemini-web' image source).
  ipcMain.handle('gemini-web-signin', () => s.geminiWeb.signIn())
  ipcMain.handle('gemini-web-status', () => s.geminiWeb.status())
  ipcMain.handle('gemini-web-signout', () => s.geminiWeb.signOut())

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
