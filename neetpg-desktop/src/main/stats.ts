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
