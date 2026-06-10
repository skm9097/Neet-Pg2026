import { useState, CSSProperties } from 'react'
import type { DashboardStats, SyncStatus } from '../types'
import { SR_STATUS_LABELS } from '../data'
import { StatCard, ErrorPill, StatusBadge, SyncButton, Surface, EmptyState, SubjectBadge } from './ui'

export function Dashboard({
  stats,
  sync,
  onSync
}: {
  stats: DashboardStats
  sync: SyncStatus
  onSync: () => void
}): JSX.Element {
  const [hoveredBar, setHoveredBar] = useState<number | null>(null)

  if (stats.total === 0) {
    return (
      <div style={{ width: '100%', height: '100%', display: 'flex' }}>
        <EmptyState
          title="Your dashboard is waiting"
          subtitle="Once you sync your question bank and start making (and fixing) mistakes, your progress, weak topics and score trends will appear here."
          action={{ label: 'Sync now', onClick: onSync }}
        />
      </div>
    )
  }

  return (
    <div style={styles.container}>
      <div style={styles.header} className="rise">
        <div>
          <h1 style={styles.title}>Dashboard</h1>
          <p style={styles.subtitle}>{stats.total} mistakes tracked · {stats.due} due today</p>
        </div>
        <SyncButton status={sync} onSync={onSync} />
      </div>

      <div style={styles.statsRow} className="rise">
        <StatCard
          label="Due Today"
          value={stats.due}
          sub="cards to review"
          accent={stats.due > 0 ? 'var(--accent)' : undefined}
        />
        <StatCard label="Reviewed Today" value={stats.reviewed} sub="completed" accent="var(--correct)" />
        <StatCard label="Streak" value={`${stats.streakDays}d`} sub="consecutive days" accent="var(--correct)" />
        <StatCard label="Total Cards" value={stats.total} sub="in your bank" />
      </div>

      <div style={styles.chartsRow}>
        <Surface style={{ flex: 1, minWidth: 300 }} radius="var(--radius-lg)" padding={24}>
          <div style={styles.cardLabel}>Score Trend</div>
          {stats.sessions.length >= 2 ? (
            <ScoreTrendChart sessions={stats.sessions} />
          ) : (
            <EmptyHint text="No sessions yet — your score trend appears after a couple of synced mock tests." />
          )}
        </Surface>

        <Surface style={{ flex: '0 0 280px', minWidth: 240 }} radius="var(--radius-lg)" padding={24}>
          <div style={styles.cardLabel}>Review Queue</div>
          <SRQueueChart byStatus={stats.byStatus} />
        </Surface>
      </div>

      <div style={styles.chartsRow}>
        <Surface style={{ flex: 1, minWidth: 300 }} radius="var(--radius-lg)" padding={24}>
          <div style={styles.cardLabel}>Topic Weakness</div>
          {stats.topics.length ? (
            <div style={{ display: 'flex', flexDirection: 'column', gap: 14, marginTop: 8 }}>
              {stats.topics.map((t, i) => {
                const barColor = t.pct > 60 ? 'var(--wrong)' : t.pct > 40 ? 'var(--warning)' : 'var(--correct)'
                return (
                  <div key={t.name} onMouseEnter={() => setHoveredBar(i)} onMouseLeave={() => setHoveredBar(null)}>
                    <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: 6 }}>
                      <span style={{ fontSize: 13, color: 'var(--text-primary)', fontWeight: 500 }}>{t.name}</span>
                      <span
                        style={{
                          fontSize: 12,
                          fontFamily: "'JetBrains Mono', monospace",
                          color: barColor,
                          fontWeight: 600
                        }}
                      >
                        {t.pct}% error
                      </span>
                    </div>
                    <div style={{ height: 6, background: 'var(--bg-hover)', borderRadius: 3, overflow: 'hidden' }}>
                      <div
                        style={{
                          width: `${t.pct}%`,
                          height: '100%',
                          borderRadius: 3,
                          background: barColor,
                          opacity: hoveredBar === i ? 1 : 0.78,
                          transition: 'width 0.5s var(--ease-out), opacity 0.25s var(--ease-out)'
                        }}
                      />
                    </div>
                  </div>
                )
              })}
            </div>
          ) : (
            <EmptyHint text="No topic data yet." />
          )}
        </Surface>

        <Surface style={{ flex: 1, minWidth: 300 }} radius="var(--radius-lg)" padding={24}>
          <div style={styles.cardLabel}>Most Stubborn Questions</div>
          {stats.stubborn.length ? (
            <div style={{ display: 'flex', flexDirection: 'column', gap: 2, marginTop: 4 }}>
              {stats.stubborn.slice(0, 5).map((c) => (
                <div key={c.id} style={styles.stubbornRow}>
                  <SubjectBadge subject={c.subject} size="sm" />
                  <span
                    style={{
                      fontSize: 13,
                      color: 'var(--text-primary)',
                      flex: 1,
                      overflow: 'hidden',
                      textOverflow: 'ellipsis',
                      whiteSpace: 'nowrap'
                    }}
                  >
                    {c.question || c.factHeading || c.topic.split('—').pop()?.trim() || c.subject}
                  </span>
                  <span style={{ fontSize: 12, color: 'var(--wrong)', fontWeight: 600, whiteSpace: 'nowrap' }}>
                    × {c.timesWrong} wrong
                  </span>
                  <ErrorPill type={c.errorType} />
                  <StatusBadge status={c.srStatus} />
                </div>
              ))}
            </div>
          ) : (
            <EmptyHint text="Nothing stubborn yet — keep practising." />
          )}
        </Surface>
      </div>

      <div style={{ height: 20 }} />
    </div>
  )
}

function EmptyHint({ text }: { text: string }): JSX.Element {
  return <div style={{ fontSize: 13, color: 'var(--text-tertiary)', padding: '24px 0', lineHeight: 1.6 }}>{text}</div>
}

function ScoreTrendChart({ sessions }: { sessions: { date: string; score: number }[] }): JSX.Element {
  const recent = sessions.slice(-12)
  const w = 520
  const h = 160
  const padL = 36
  const padR = 16
  const padT = 12
  const padB = 28
  const cw = w - padL - padR
  const ch = h - padT - padB
  const scores = recent.map((s) => s.score)
  const minS = Math.min(...scores) - 5
  const maxS = Math.max(...scores) + 5
  const range = maxS - minS || 1

  const points = recent.map((s, i) => ({
    x: padL + (i / Math.max(recent.length - 1, 1)) * cw,
    y: padT + ch - ((s.score - minS) / range) * ch,
    ...s
  }))

  // Smooth curve through the points (midpoint cubic segments).
  const line = points
    .map((p, i) => {
      if (i === 0) return `M${p.x},${p.y}`
      const prev = points[i - 1]
      const cx = (prev.x + p.x) / 2
      return `C${cx},${prev.y} ${cx},${p.y} ${p.x},${p.y}`
    })
    .join(' ')
  const last = points[points.length - 1]
  const area = line + ` L${last.x},${padT + ch} L${points[0].x},${padT + ch} Z`
  const gridLines = [minS, minS + range * 0.5, maxS].map((v) => ({
    y: padT + ch - ((v - minS) / range) * ch,
    label: Math.round(v) + '%'
  }))

  return (
    <svg viewBox={`0 0 ${w} ${h}`} style={{ width: '100%', maxWidth: w }}>
      {gridLines.map((g, i) => (
        <g key={i}>
          <line x1={padL} y1={g.y} x2={w - padR} y2={g.y} stroke="var(--border-subtle)" strokeWidth="1" />
          <text
            x={padL - 6}
            y={g.y + 4}
            textAnchor="end"
            fill="var(--text-tertiary)"
            fontSize="10"
            fontFamily="'JetBrains Mono', monospace"
          >
            {g.label}
          </text>
        </g>
      ))}
      <defs>
        <linearGradient id="trendGrad" x1="0" y1="0" x2="0" y2="1">
          <stop offset="0%" stopColor="var(--accent)" />
          <stop offset="100%" stopColor="var(--accent)" stopOpacity="0" />
        </linearGradient>
      </defs>
      <path d={area} fill="url(#trendGrad)" opacity="0.3" />
      <path d={line} fill="none" stroke="var(--accent)" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round" />
      {points.map((p, i) => (
        <circle
          key={i}
          cx={p.x}
          cy={p.y}
          r={i === points.length - 1 ? 4.5 : 3}
          fill="var(--bg-base)"
          stroke="var(--accent)"
          strokeWidth="2"
        />
      ))}
      {/* Label the last point. */}
      <text
        x={last.x}
        y={last.y - 12}
        textAnchor={last.x > w - 60 ? 'end' : 'middle'}
        fill="var(--accent)"
        fontSize="12"
        fontWeight="700"
        fontFamily="'JetBrains Mono', monospace"
      >
        {Math.round(last.score)}%
      </text>
    </svg>
  )
}

function SRQueueChart({ byStatus }: { byStatus: Record<string, number> }): JSX.Element {
  const statuses = ['new', 'learning', 'relearning', 'review', 'mature']
  const hasAny = statuses.some((s) => (byStatus[s] || 0) > 0)
  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: 14, marginTop: 8 }}>
      {hasAny && (
        <div style={{ display: 'flex', height: 10, borderRadius: 5, overflow: 'hidden', gap: 2 }}>
          {statuses.map((s) => {
            const count = byStatus[s] || 0
            const info = SR_STATUS_LABELS[s]
            return count > 0 ? (
              <div
                key={s}
                style={{ flex: count, background: info.color, opacity: 0.75, transition: 'flex 0.6s var(--ease-out)' }}
              />
            ) : null
          })}
        </div>
      )}
      <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
        {statuses.map((s) => {
          const count = byStatus[s] || 0
          const info = SR_STATUS_LABELS[s]
          return (
            <div key={s} style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
              <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                <span style={{ width: 8, height: 8, borderRadius: '50%', background: info.color, opacity: 0.75 }} />
                <span style={{ fontSize: 13, color: 'var(--text-secondary)' }}>{info.label}</span>
              </div>
              <span
                style={{
                  fontSize: 13,
                  fontFamily: "'JetBrains Mono', monospace",
                  color: 'var(--text-primary)',
                  fontWeight: 600
                }}
              >
                {count}
              </span>
            </div>
          )
        })}
      </div>
    </div>
  )
}

const styles: Record<string, CSSProperties> = {
  container: {
    width: '100%',
    height: '100%',
    overflow: 'auto',
    padding: '32px 40px',
    display: 'flex',
    flexDirection: 'column',
    gap: 24
  },
  header: { display: 'flex', justifyContent: 'space-between', alignItems: 'center' },
  title: {
    fontSize: 28,
    fontWeight: 800,
    color: 'var(--text-primary)',
    margin: 0,
    lineHeight: 1,
    letterSpacing: '-0.02em'
  },
  subtitle: { fontSize: 14, color: 'var(--text-secondary)', marginTop: 8 },
  statsRow: { display: 'flex', gap: 16, flexWrap: 'wrap' },
  chartsRow: { display: 'flex', gap: 16, flexWrap: 'wrap' },
  cardLabel: {
    fontSize: 12,
    fontWeight: 600,
    letterSpacing: '0.05em',
    textTransform: 'uppercase',
    color: 'var(--text-tertiary)',
    marginBottom: 16
  },
  stubbornRow: {
    display: 'flex',
    alignItems: 'center',
    gap: 12,
    padding: '10px 0',
    borderBottom: '1px solid var(--border-subtle)'
  }
}
