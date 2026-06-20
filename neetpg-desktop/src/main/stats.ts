import type { DashboardStats, MistakeCard } from '../shared/types'
import type { CardCache } from './cache'
import type { SREngine } from './sr-engine'

const todayKey = (): string => new Date().toISOString().split('T')[0]

/** Builds the dashboard payload from cached cards, SR state, and sessions. */
export function buildStats(cache: CardCache, sr: SREngine): DashboardStats {
  const cards = cache.allCards()
  const srState = cache.allSR()

  const byStatus: Record<string, number> = {}
  for (const c of cards) {
    const status = srState[c.id]?.status || 'new'
    byStatus[status] = (byStatus[status] || 0) + 1
  }

  // Topic weakness — group by the leading segment of the topic label.
  const topicMap: Record<string, { total: number; wrong: number }> = {}
  for (const c of cards) {
    const t = (c.topic.split('—')[0] || c.subject).trim() || c.subject
    if (!topicMap[t]) topicMap[t] = { total: 0, wrong: 0 }
    topicMap[t].total += c.timesWrong + c.timesCorrect
    topicMap[t].wrong += c.timesWrong
  }
  const topics = Object.entries(topicMap)
    .map(([name, d]) => ({
      name,
      total: d.total,
      wrong: d.wrong,
      pct: d.total > 0 ? Math.round((d.wrong / d.total) * 100) : 0
    }))
    .sort((a, b) => b.pct - a.pct)
    .slice(0, 8)

  const sessions = cache
    .allSessions()
    .map((s) => ({ date: shortDate(s.endedAt || s.startedAt), score: s.scorePercent }))
    .filter((s) => s.date)
    .slice(-12)

  const stubborn = [...cards]
    .filter((c) => !c.isResolved)
    .sort((a, b) => b.timesWrong - a.timesWrong)
    .slice(0, 5)

  const resolved = cards.filter((c) => c.isResolved).length

  return {
    due: sr.dueCount(),
    reviewed: cache.reviewedOn(todayKey()),
    total: cards.length,
    unresolved: cards.length - resolved,
    resolved,
    streakDays: sr.streakDays(),
    byStatus,
    topics,
    sessions,
    stubborn
  }
}

function shortDate(iso: string): string {
  if (!iso) return ''
  const d = new Date(iso)
  if (isNaN(d.getTime())) return ''
  return d.toLocaleDateString('en-US', { month: 'short', day: '2-digit' })
}

/** Attach live SR status onto a card before sending to the renderer. */
export function withSR(card: MistakeCard, cache: CardCache): MistakeCard {
  const s = cache.getSR(card.id)
  return s ? { ...card, srStatus: s.status, nextReview: s.nextReview } : card
}

/**
 * Smart-review ordering for the ambient/quiz feed. Builds a de-duped list in
 * this priority, then the caller slices to the desired limit:
 *
 *   1. Due cards — have SR state with nextReview <= today; most overdue first.
 *   2. Weakest-topic unresolved cards — subjects ranked by unresolved ratio
 *      (same notion as the repo's topic-scores); within a subject, most-recently
 *      wrong first.
 *   3. Recent mistakes — remaining unresolved cards by lastWrong desc.
 *   4. Fill — any remaining cards (resolved ones land here, last).
 *
 * Never returns an empty list when any cards exist: every card ends up in the
 * fill tier if nothing else claimed it.
 */
export function buildReviewFeed(cache: CardCache): MistakeCard[] {
  const today = todayKey()
  const cards = cache.allCards()
  const srState = cache.allSR()

  const ordered: MistakeCard[] = []
  const seen = new Set<string>()
  const push = (c: MistakeCard): void => {
    if (seen.has(c.id)) return
    seen.add(c.id)
    ordered.push(c)
  }

  const byLastWrongDesc = (a: MistakeCard, b: MistakeCard): number =>
    (b.lastWrong || '').localeCompare(a.lastWrong || '')

  // ── Tier 1: due cards (have SR state, nextReview <= today), most overdue first.
  const due = cards
    .filter((c) => {
      const s = srState[c.id]
      return !!s && !!s.nextReview && s.nextReview <= today
    })
    .sort((a, b) => srState[a.id].nextReview.localeCompare(srState[b.id].nextReview))
  due.forEach(push)

  // ── Tier 2: weakest-topic unresolved cards.
  // Rank subjects by unresolved ratio (unresolved / total), highest first; ties
  // broken by absolute unresolved count so a subject with more open cards wins.
  const subjectAgg: Record<string, { unresolved: number; total: number }> = {}
  for (const c of cards) {
    const key = c.subject || 'unknown'
    if (!subjectAgg[key]) subjectAgg[key] = { unresolved: 0, total: 0 }
    subjectAgg[key].total += 1
    if (!c.isResolved) subjectAgg[key].unresolved += 1
  }
  const weakSubjects = Object.entries(subjectAgg)
    .map(([subject, v]) => ({
      subject,
      ratio: v.total > 0 ? v.unresolved / v.total : 0,
      unresolved: v.unresolved
    }))
    .filter((s) => s.unresolved > 0)
    .sort((a, b) => b.ratio - a.ratio || b.unresolved - a.unresolved)

  const unresolved = cards.filter((c) => !c.isResolved)
  for (const ws of weakSubjects) {
    unresolved
      .filter((c) => (c.subject || 'unknown') === ws.subject)
      .sort(byLastWrongDesc)
      .forEach(push)
  }

  // ── Tier 3: any remaining unresolved cards (most recently wrong first).
  ;[...unresolved].sort(byLastWrongDesc).forEach(push)

  // ── Tier 4: fill — everything else (resolved cards land here, last).
  ;[...cards].sort(byLastWrongDesc).forEach(push)

  return ordered
}
