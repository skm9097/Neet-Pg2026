import { join } from 'path'
import type { AppConfig, SyncStatus, SessionLog, TopicScores } from '../shared/types'
import { RepoSync } from './repo-sync'
import { CardCache } from './cache'
import { SREngine } from './sr-engine'
import { LLMService } from './llm-service'
import { parseMistakeFile } from './file-parser'

/**
 * Orchestrates a sync cycle:
 *   1. List the repo tree (GitHub API).
 *   2. Fetch + parse changed mistake files into the cache.
 *   3. Ingest session logs.
 *   4. Optionally enrich un-enriched cards via the LLM.
 *   5. Push progress/sr-state.json + progress/topic-scores.json back.
 */
export class Syncer {
  private status: SyncStatus = {
    lastSync: null,
    lastError: null,
    inProgress: false,
    totalCards: 0
  }

  constructor(
    private cfg: () => AppConfig,
    private repo: RepoSync,
    private cache: CardCache,
    private sr: SREngine,
    private llm: LLMService
  ) {}

  getStatus(): SyncStatus {
    return { ...this.status, totalCards: this.cache.allCards().length }
  }

  /** One full sync pass. Returns the number of changed files ingested. */
  async sync(): Promise<{ changed: number; error: string | null }> {
    if (this.status.inProgress) return { changed: 0, error: null }
    this.status.inProgress = true
    let changed = 0

    try {
      const tree = await this.repo.listTree()

      const mistakeFiles = tree.filter(
        (e) => e.path.startsWith('mistakes/') && e.path.endsWith('.md')
      )
      const sessionFiles = tree.filter(
        (e) => e.path.startsWith('sessions/') && e.path.endsWith('.json')
      )

      // ── Mistake files (only fetch ones whose blob sha changed) ──
      for (const f of mistakeFiles) {
        if (this.cache.getBlobSha(f.path) === f.sha) continue
        try {
          const raw = await this.repo.fetchFile(f.path)
          const card = parseMistakeFile(raw, f.path, f.sha)
          if (card) {
            this.cache.upsertCard(card)
            changed++
          }
        } catch {
          // Skip this file; try again next cycle.
        }
      }

      // ── Session logs ──
      for (const f of sessionFiles) {
        if (this.cache.getBlobSha(f.path) === f.sha) continue
        try {
          const raw = await this.repo.fetchFile(f.path)
          const s = JSON.parse(raw) as Partial<SessionLog>
          if (s.sessionId) {
            this.cache.upsertSession(normalizeSession(s))
            // reuse blob-sha map for change detection on sessions too
            this.cache.setBlobSha(f.path, f.sha)
            changed++
          }
        } catch {
          // ignore malformed session file
        }
      }

      // Join SR state onto the cards so the renderer gets srStatus/nextReview.
      this.joinSRState()
      this.cache.save()

      // ── Enrich un-enriched cards (offline pushes) if AI is on ──
      const c = this.cfg()
      if (this.llm.configured && c.enableMnemonics) {
        await this.enrichMissing()
      }

      // ── Push progress back to the repo ──
      if (c.githubPat) {
        await this.pushProgress()
      }

      this.status.lastSync = new Date().toISOString()
      this.status.lastError = null
      return { changed, error: null }
    } catch (e) {
      this.status.lastError = (e as Error).message
      return { changed, error: this.status.lastError }
    } finally {
      this.status.inProgress = false
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
      .filter((c) => !c.keyFact || !c.whyWrong)
      .slice(0, 5) // bound LLM work per cycle
    for (const card of missing) {
      const enriched = await this.llm.enrichCard(card)
      if (enriched) {
        card.keyFact = enriched.keyFact || card.keyFact
        card.whyWrong = enriched.whyWrong || card.whyWrong
        if (enriched.errorType) card.errorType = enriched.errorType as never
        if (enriched.tags.length) card.tags = enriched.tags
        this.cache.upsertCard(card)
      }
    }
    this.cache.save()
  }

  private async pushProgress(): Promise<void> {
    try {
      const srState = this.sr.exportState()
      await this.repo.putFile(
        'progress/sr-state.json',
        JSON.stringify(srState, null, 2),
        'sr: desktop review update'
      )

      const topicScores = this.computeTopicScores()
      await this.repo.putFile(
        'progress/topic-scores.json',
        JSON.stringify(topicScores, null, 2),
        'progress: desktop topic scores'
      )
    } catch (e) {
      // Network/conflict — keep the local state, retry next cycle.
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

// re-export the repo path helper for symmetry with the spec layout
export const progressPath = (root: string): string => join(root, 'progress')
