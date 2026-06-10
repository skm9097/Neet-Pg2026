import type { SRCard, SRState } from '../shared/types'
import type { CardCache } from './cache'

const todayKey = (): string => new Date().toISOString().split('T')[0]

/** SM-2 spaced repetition. Writes through to the cache; export to JSON on demand. */
export class SREngine {
  constructor(private cache: CardCache) {}

  /** Apply a 0-5 grade to a card and return the updated SR state. */
  gradeCard(cardId: string, grade: number): SRCard {
    const current: SRCard =
      this.cache.getSR(cardId) || {
        easinessFactor: 2.5,
        intervalDays: 0,
        repetitions: 0,
        nextReview: '',
        lastGrade: 0,
        status: 'new'
      }

    let { easinessFactor, intervalDays, repetitions } = current

    if (grade >= 3) {
      if (repetitions === 0) intervalDays = 1
      else if (repetitions === 1) intervalDays = 6
      else intervalDays = Math.round(intervalDays * easinessFactor)
      repetitions += 1
    } else {
      repetitions = 0
      intervalDays = 1
    }

    easinessFactor = Math.max(
      1.3,
      easinessFactor + (0.1 - (5 - grade) * (0.08 + (5 - grade) * 0.02))
    )

    let status: SRCard['status'] = 'learning'
    if (grade < 3 && current.status === 'review') status = 'relearning'
    else if (intervalDays > 30 && repetitions >= 5) status = 'mature'
    else if (repetitions >= 3 && intervalDays > 7) status = 'review'

    const nr = new Date()
    nr.setDate(nr.getDate() + intervalDays)

    const updated: SRCard = {
      easinessFactor,
      intervalDays,
      repetitions,
      nextReview: nr.toISOString().split('T')[0],
      lastGrade: grade,
      status,
      updatedAt: new Date().toISOString()
    }

    this.cache.setSR(cardId, updated)
    this.cache.bumpReviewed(todayKey())
    this.cache.save()
    return updated
  }

  /**
   * Merge a remote progress/sr-state.json into the local store, per card,
   * newest-wins. Cards whose remote `updatedAt` is newer (or that don't exist
   * locally) are adopted; for legacy entries without timestamps the entry with
   * more repetitions wins. Returns the number of cards adopted from remote —
   * this is what makes SR progress survive reinstalls and stay consistent
   * across devices.
   */
  mergeRemote(remote: SRState): number {
    let adopted = 0
    for (const [cardId, remoteCard] of Object.entries(remote.cards || {})) {
      const local = this.cache.getSR(cardId)
      if (!local) {
        this.cache.setSR(cardId, remoteCard)
        adopted++
        continue
      }
      const rT = remoteCard.updatedAt || ''
      const lT = local.updatedAt || ''
      const remoteNewer =
        rT && lT ? rT > lT : rT && !lT ? true : remoteCard.repetitions > local.repetitions
      if (remoteNewer) {
        this.cache.setSR(cardId, remoteCard)
        adopted++
      }
    }
    return adopted
  }

  /** Next card to quiz on: overdue → new → random unresolved. */
  getNextCardId(): string | null {
    const today = todayKey()
    const sr = this.cache.allSR()
    const cards = this.cache.allCards().filter((c) => !c.isResolved)

    // 1. Due cards (have SR state, next review <= today), most overdue first.
    const due = cards
      .filter((c) => sr[c.id] && sr[c.id].nextReview && sr[c.id].nextReview <= today)
      .sort((a, b) => sr[a.id].nextReview.localeCompare(sr[b.id].nextReview))
    if (due.length > 0) return due[0].id

    // 2. New cards (no SR state yet).
    const fresh = cards.filter((c) => !sr[c.id])
    if (fresh.length > 0) return fresh[0].id

    // 3. Anything unresolved, random, for ambient/quiz variety.
    if (cards.length > 0) return cards[Math.floor(Math.random() * cards.length)].id

    return null
  }

  /** Number of cards due for review today. */
  dueCount(): number {
    const today = todayKey()
    const sr = this.cache.allSR()
    const cards = this.cache.allCards().filter((c) => !c.isResolved)
    const dueWithState = cards.filter(
      (c) => sr[c.id] && sr[c.id].nextReview && sr[c.id].nextReview <= today
    ).length
    const newCards = cards.filter((c) => !sr[c.id]).length
    return dueWithState + newCards
  }

  /** Serialize SR state to the repo's progress/sr-state.json shape. */
  exportState(): SRState {
    return {
      lastUpdated: new Date().toISOString(),
      cards: { ...this.cache.allSR() }
    }
  }

  /** Consecutive-day streak from the daily reviewed counter. */
  streakDays(): number {
    const dates = this.cache.reviewedDates()
    let streak = 0
    const d = new Date()
    for (;;) {
      const key = d.toISOString().split('T')[0]
      if ((dates[key] || 0) > 0) {
        streak += 1
        d.setDate(d.getDate() - 1)
      } else {
        // Allow today to be empty without breaking an existing streak.
        if (streak === 0 && key === todayKey()) {
          d.setDate(d.getDate() - 1)
          continue
        }
        break
      }
    }
    return streak
  }
}
