import { readFileSync, writeFileSync, existsSync, renameSync, copyFileSync } from 'fs'
import { join } from 'path'
import type { MistakeCard, SRCard, SessionLog } from '../shared/types'

// Bump when the parser/card shape changes so cached cards are re-fetched and
// re-parsed with the new logic (progress + sessions are preserved).
const CACHE_VERSION = 2

interface CacheShape {
  version: number
  cards: Record<string, MistakeCard>
  blobShas: Record<string, string> // filePath -> blob sha, for change detection
  sr: Record<string, SRCard>
  sessions: Record<string, SessionLog>
  llm: Record<string, string> // `${cardId}:${type}` -> content
  reviewedDates: Record<string, number> // "YYYY-MM-DD" -> count reviewed that day
}

const EMPTY: CacheShape = {
  version: CACHE_VERSION,
  cards: {},
  blobShas: {},
  sr: {},
  sessions: {},
  llm: {},
  reviewedDates: {}
}

/**
 * A small JSON-file backed store. Replaces SQLite — the data volume here is a
 * few hundred cards, so an in-memory map persisted to disk is more than enough
 * and keeps the build free of native modules (clean `npm install` on Windows).
 */
export class CardCache {
  private path: string
  private data: CacheShape

  constructor(userDataDir: string) {
    this.path = join(userDataDir, 'cache.json')
    this.data = this.load()
  }

  private load(): CacheShape {
    try {
      if (existsSync(this.path)) {
        const raw = JSON.parse(readFileSync(this.path, 'utf-8'))
        const merged: CacheShape = { ...EMPTY, ...raw }
        if (raw.version !== CACHE_VERSION) {
          // Parser/schema upgrade: drop parsed cards + their change-detection
          // shas + any stale LLM text so everything re-fetches and re-parses
          // cleanly. Keep SR progress, sessions, and review history.
          merged.cards = {}
          merged.blobShas = {}
          merged.llm = {}
          merged.version = CACHE_VERSION
        }
        return merged
      }
    } catch {
      // Corrupt cache — keep a backup so SR progress is recoverable, then
      // start fresh rather than crash. (A truncated write used to silently
      // wipe all progress; now the bad file sits next to cache.json.)
      try {
        copyFileSync(this.path, `${this.path}.corrupt.bak`)
      } catch {
        // best-effort backup only
      }
    }
    return { ...EMPTY }
  }

  /** Atomic write: temp file then rename. */
  save(): void {
    try {
      const tmp = this.path + '.tmp'
      writeFileSync(tmp, JSON.stringify(this.data), 'utf-8')
      renameSync(tmp, this.path)
    } catch {
      // Ignore write failures — the in-memory copy stays authoritative.
    }
  }

  // ── Cards ─────────────────────────────────────────────────────────────────
  getBlobSha(filePath: string): string | undefined {
    return this.data.blobShas[filePath]
  }

  setBlobSha(filePath: string, sha: string): void {
    this.data.blobShas[filePath] = sha
  }

  upsertCard(card: MistakeCard): void {
    this.data.cards[card.id] = card
    this.data.blobShas[card.filePath] = card.lastModified
  }

  allCards(): MistakeCard[] {
    return Object.values(this.data.cards)
  }

  getCard(id: string): MistakeCard | undefined {
    return this.data.cards[id]
  }

  // ── SR state ──────────────────────────────────────────────────────────────
  getSR(cardId: string): SRCard | undefined {
    return this.data.sr[cardId]
  }

  setSR(cardId: string, state: SRCard): void {
    this.data.sr[cardId] = state
  }

  allSR(): Record<string, SRCard> {
    return this.data.sr
  }

  // ── Sessions ──────────────────────────────────────────────────────────────
  upsertSession(s: SessionLog): void {
    this.data.sessions[s.sessionId] = s
  }

  allSessions(): SessionLog[] {
    return Object.values(this.data.sessions)
  }

  // ── LLM cache ─────────────────────────────────────────────────────────────
  getLLM(cardId: string, type: string): string | undefined {
    return this.data.llm[`${cardId}:${type}`]
  }

  setLLM(cardId: string, type: string, content: string): void {
    this.data.llm[`${cardId}:${type}`] = content
  }

  // ── Daily review counter (for "reviewed today" / streak) ──────────────────
  bumpReviewed(dateKey: string): void {
    this.data.reviewedDates[dateKey] = (this.data.reviewedDates[dateKey] || 0) + 1
  }

  reviewedOn(dateKey: string): number {
    return this.data.reviewedDates[dateKey] || 0
  }

  reviewedDates(): Record<string, number> {
    return this.data.reviewedDates
  }
}
