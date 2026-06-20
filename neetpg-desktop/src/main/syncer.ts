import { join } from 'path'
import type { AppConfig, SyncStatus, SessionLog, SRState, TopicScores } from '../shared/types'
import { RepoSync } from './repo-sync'
import { CardCache } from './cache'
import { SREngine } from './sr-engine'
import { LLMService } from './llm-service'
import { parseMistakeFile, deriveHeading, deriveBullets } from './file-parser'
import { buildMistakeMarkdown } from './md-builder'

const SR_STATE_PATH = 'progress/sr-state.json'

export class Syncer {
  private status: SyncStatus = {
    lastSync: null,
    lastError: null,
    inProgress: false,
    totalCards: 0,
    phase: 'idle',
    parseErrors: []
  }
  private sink: ((s: SyncStatus) => void) | null = null

  constructor(
    private cfg: () => AppConfig,
    private repo: RepoSync,
    private cache: CardCache,
    private sr: SREngine,
    private llm: LLMService
  ) {}

  /** Attach a callback that receives every status transition — used by index.ts
   *  to push live updates to the renderer via IPC. */
  setStatusSink(fn: (s: SyncStatus) => void): void {
    this.sink = fn
  }

  private emit(patch: Partial<SyncStatus>): void {
    Object.assign(this.status, patch)
    this.sink?.({ ...this.status, totalCards: this.cache.allCards().length })
  }

  getStatus(): SyncStatus {
    return { ...this.status, totalCards: this.cache.allCards().length }
  }

  async sync(): Promise<{ changed: number; error: string | null }> {
    if (this.status.inProgress) return { changed: 0, error: null }
    this.emit({ inProgress: true, lastError: null, phase: 'listing' })
    let changed = 0
    const parseErrors: { path: string; reason: string }[] = []

    try {
      const tree = await this.repo.listTree()

      const mistakeFiles = tree.filter(
        (e) => e.path.startsWith('mistakes/') && e.path.endsWith('.md')
      )
      const sessionFiles = tree.filter(
        (e) => e.path.startsWith('sessions/') && e.path.endsWith('.json')
      )

      this.emit({ phase: 'fetching' })

      // Pull-merge remote SR state BEFORE anything else. Another device (or a
      // previous install) may have graded cards; per-card newest-wins merge
      // means progress survives reinstalls and multi-device use.
      const srEntry = tree.find((e) => e.path === SR_STATE_PATH)
      if (srEntry && this.cache.getBlobSha(SR_STATE_PATH) !== srEntry.sha) {
        try {
          const raw = await this.repo.fetchFile(SR_STATE_PATH)
          const remote = JSON.parse(raw) as SRState
          if (remote && remote.cards) this.sr.mergeRemote(remote)
          this.cache.setBlobSha(SR_STATE_PATH, srEntry.sha)
        } catch {
          // Bad/unreachable remote SR state — local store stays authoritative.
        }
      }

      for (const f of mistakeFiles) {
        if (this.cache.getBlobSha(f.path) === f.sha) continue
        try {
          const raw = await this.repo.fetchFile(f.path)
          const { card, error } = parseMistakeFile(raw, f.path, f.sha)
          if (card) {
            this.cache.upsertCard(card)
            changed++
          } else if (error) {
            // Record the sha so we don't refetch a permanently-broken file
            // every cycle, but surface it in the UI instead of dropping it.
            this.cache.setBlobSha(f.path, f.sha)
            parseErrors.push({ path: f.path, reason: error })
          }
        } catch {
          // Network hiccup on this file; try again next cycle.
        }
      }

      for (const f of sessionFiles) {
        if (this.cache.getBlobSha(f.path) === f.sha) continue
        try {
          const raw = await this.repo.fetchFile(f.path)
          const s = JSON.parse(raw) as Partial<SessionLog>
          if (s.sessionId) {
            this.cache.upsertSession(normalizeSession(s))
            this.cache.setBlobSha(f.path, f.sha)
            changed++
          }
        } catch {
          // ignore malformed session file
        }
      }

      this.joinSRState()
      this.cache.save()

      const c = this.cfg()
      if (this.llm.configured && c.enableMnemonics) {
        this.emit({ phase: 'enriching' })
        await this.enrichMissing()
      }

      if (c.githubPat) {
        this.emit({ phase: 'pushing' })
        await this.pushProgress()
      }

      this.emit({
        inProgress: false,
        lastSync: new Date().toISOString(),
        phase: 'done',
        parseErrors
      })
      return { changed, error: null }
    } catch (e) {
      // Sync failed (offline, rate-limited, …) — the local cache stays intact
      // and the renderer keeps serving cards from it; only the status changes.
      const msg = (e as Error).message
      this.emit({ inProgress: false, lastError: msg, phase: 'error', parseErrors })
      return { changed, error: msg }
    }
  }

  private joinSRState(): void {
    const sr = this.cache.allSR()
    for (const card of this.cache.allCards()) {
      const s = sr[card.id]
      if (s) {
        card.srStatus = s.status
        card.nextReview = s.nextReview
      }
      this.cache.upsertCard(card)
    }
  }

  private async enrichMissing(): Promise<void> {
    const missing = this.cache
      .allCards()
      .filter((c) => c.question && c.options.length > 0 && (!c.keyFact || !c.whyWrong))
      .slice(0, 5)
    const canPush = !!this.cfg().githubPat
    for (const card of missing) {
      const enriched = await this.llm.enrichCard(card)
      if (!enriched) continue
      card.keyFact = enriched.keyFact || card.keyFact
      card.whyWrong = enriched.whyWrong || card.whyWrong
      if (enriched.errorType) card.errorType = enriched.errorType as never
      if (enriched.tags.length) card.tags = enriched.tags
      card.factHeading = deriveHeading(card.topic, card.keyFact)
      card.factPoints = deriveBullets(card.keyFact)

      // Write the enrichment back to the repo so it reaches every device and
      // survives cache clears (the Android placeholder promises exactly this).
      if (canPush && card.filePath) {
        try {
          const sha = await this.repo.putFile(
            card.filePath,
            buildMistakeMarkdown(card),
            `enrich: ${card.id} key fact + analysis`
          )
          if (sha) card.lastModified = sha
        } catch {
          // Enrichment stays local this cycle; write-back retries next time
          // the card is still missing remote enrichment.
        }
      }
      this.cache.upsertCard(card)
    }
    this.cache.save()
  }

  private async pushProgress(): Promise<void> {
    try {
      const srState = this.sr.exportState()
      const srSha = await this.repo.putFile(
        SR_STATE_PATH,
        JSON.stringify(srState, null, 2),
        'sr: desktop review update'
      )
      // Record what we just wrote so next cycle's pull-merge skips it.
      if (srSha) this.cache.setBlobSha(SR_STATE_PATH, srSha)
      const topicScores = this.computeTopicScores()
      await this.repo.putFile(
        'progress/topic-scores.json',
        JSON.stringify(topicScores, null, 2),
        'progress: desktop topic scores'
      )
    } catch (e) {
      this.status.lastError = `push: ${(e as Error).message}`
    }
  }

  private computeTopicScores(): TopicScores {
    const map: Record<string, { unresolved: number; total: number }> = {}
    for (const c of this.cache.allCards()) {
      const key = c.subject
      if (!map[key]) map[key] = { unresolved: 0, total: 0 }
      map[key].total += 1
      if (!c.isResolved) map[key].unresolved += 1
    }
    const scores: Record<string, number> = {}
    for (const [k, v] of Object.entries(map)) {
      scores[k] = v.total > 0 ? Number((v.unresolved / v.total).toFixed(3)) : 0
    }
    return { lastUpdated: new Date().toISOString(), scores }
  }
}

function normalizeSession(s: Partial<SessionLog>): SessionLog {
  return {
    sessionId: s.sessionId || '',
    type: s.type || 'practice',
    startedAt: s.startedAt || '',
    endedAt: s.endedAt || '',
    totalQuestions: s.totalQuestions || 0,
    correct: s.correct || 0,
    wrong: s.wrong || 0,
    skipped: s.skipped || 0,
    scorePercent: s.scorePercent || 0,
    subjectBreakdown: s.subjectBreakdown || []
  }
}

export const progressPath = (root: string): string => join(root, 'progress')
