import { readFileSync, writeFileSync, existsSync, renameSync } from 'fs'
import { join } from 'path'
import type { MistakeCard, SRCard, SessionLog } from '../shared/types'

interface CacheShape {
  cards: Record<string, MistakeCard>
  blobShas: Record<string, string> // filePath -> blob sha, for change detection
  sr: Record<string, SRCard>
  sessions: Record<string, SessionLog>
  llm: Record<string, string> // `${cardId}:${type}` -> content
  reviewedDates: Record<string, number> // "YYYY-MM-DD" -> count reviewed that day
}

const EMPTY: CacheShape = {
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
        return { ...EMPTY, ...raw }
      }
    } catch {
      // Corrupt cache — start fresh rather than crash.
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
