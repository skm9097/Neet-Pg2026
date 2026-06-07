import { useState, CSSProperties } from 'react'
import type { DashboardStats } from '../types'
import { SR_STATUS_LABELS, ICONS } from '../data'
import { Svg, StatCard, ErrorPill, StatusBadge } from './ui'

export function Dashboard({ stats, lastSync }: { stats: DashboardStats; lastSync: string }): JSX.Element {
  const [hoveredBar, setHoveredBar] = useState<number | null>(null)

  return (
    <div style={styles.container}>
      <div style={styles.header}>
        <div>
          <h1 style={styles.title}>Dashboard</h1>
          <p style={styles.subtitle}>
            {stats.due} cards due today · {stats.total} total mistakes tracked
          </p>
        </div>
        <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
          <Svg markup={ICONS.sync} style={{ color: 'var(--text-tertiary)' }} />
          <span style={{ fontSize: 12, color: 'var(--text-tertiary)' }}>{lastSync}</span>
        </div>
      </div>

      <div style={styles.statsRow}>
        <StatCard label="Due Today" value={stats.due} sub="cards to review" accent="var(--accent)" />
        <StatCard label="Reviewed" value={stats.reviewed} sub="completed today" accent="var(--correct)" />
        <StatCard
          label="Remaining"
          value={Math.max(stats.due - stats.reviewed, 0)}
          sub="still pending"
          accent="var(--warning)"
        />
        <StatCard label="Streak" value={`${stats.streakDays}d`} sub="consecutive days" accent="var(--correct)" />
      </div>

      <div style={styles.chartsRow}>
        <div style={styles.chartCard}>
          <div style={styles.cardLabel}>Score Trend</div>
          {stats.sessions.length >= 2 ? (
            <ScoreTrendChart sessions={stats.sessions} />
          ) : (
            <EmptyHint text="Score trend appears after a couple of synced mock-test sessions." />
          )}
        </div>

        <div style={{ ...styles.chartCard, flex: '0 0 280px' }}>
          <div style={styles.cardLabel}>Review Queue</div>
          <SRQueueChart byStatus={stats.byStatus} />
        </div>
      </div>

      <div style={styles.chartsRow}>
        <div style={styles.chartCard}>
          <div style={styles.cardLabel}>Topic Weakness</div>
          {stats.topics.length ? (
            <div style={{ display: 'flex', flexDirection: 'column', gap: 14, marginTop: 8 }}>
              {stats.topics.map((t, i) => (
                <div key={t.name} onMouseEnter={() => setHoveredBar(i)} onMouseLeave={() => setHoveredBar(null)}>
                  <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: 6 }}>
                    <span style={{ fontSize: 13, color: 'var(--text-primary)', fontWeight: 500 }}>{t.name}</span>
                    <span
                      style={{
                        fontSize: 12,
                        fontFamily: "'JetBrains Mono', monospace",
                        color: t.pct > 60 ? 'var(--wrong)' : t.pct > 40 ? 'var(--warning)' : 'var(--text-secondary)',
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
                        background: t.pct > 60 ? 'var(--wrong)' : t.pct > 40 ? 'var(--warning)' : 'var(--accent)',
                        opacity: hoveredBar === i ? 1 : 0.7,
                        transition: 'all 0.4s cubic-bezier(0.4,0,0.2,1)'
                      }}
                    />
                  </div>
                </div>
              ))}
            </div>
          ) : (
            <EmptyHint text="No topic data yet." />
          )}
        </div>

        <div style={styles.chartCard}>
          <div style={styles.cardLabel}>Most Stubborn Questions</div>
          {stats.stubborn.length ? (
            <div style={{ display: 'flex', flexDirection: 'column', gap: 2, marginTop: 4 }}>
              {stats.stubborn.map((c) => (
                <div key={c.id} style={styles.stubbornRow}>
                  <span
                    style={{
                      fontSize: 13,
                      fontFamily: "'JetBrains Mono', monospace",
                      color: 'var(--text-tertiary)',
                      fontWeight: 500,
                      minWidth: 64
                    }}
                  >
                    {c.id}
                  </span>
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
                    {c.topic.split('—').pop()?.trim() || c.subject}
                  </span>
                  <span
                    style={{
                      fontSize: 12,
                      color: 'var(--wrong)',
                      fontWeight: 600,
                      fontFamily: "'JetBrains Mono', monospace"
                    }}
                  >
                    ✕{c.timesWrong}
                  </span>
                  <ErrorPill type={c.errorType} />
                  <StatusBadge status={c.srStatus} />
                </div>
              ))}
            </div>
          ) : (
            <EmptyHint text="Nothing stubborn yet — keep practising on your phone." />
          )}
        </div>
      </div>
    </div>
  )
}

function EmptyHint({ text }: { text: string }): JSX.Element {
  return <div style={{ fontSize: 13, color: 'var(--text-tertiary)', padding: '24px 0', lineHeight: 1.6 }}>{text}</div>
}

function ScoreTrendChart({ sessions }: { sessions: { date: string; score: number }[] }): JSX.Element {
  const w = 520
  const h = 160
  const padL = 36
  const padR = 12
  const padT = 12
  const padB = 28
  const cw = w - padL - padR
  const ch = h - padT - padB
  const scores = sessions.map((s) => s.score)
  const minS = Math.min(...scores) - 5
  const maxS = Math.max(...scores) + 5
  const range = maxS - minS || 1

  const points = sessions.map((s, i) => ({
    x: padL + (i / Math.max(sessions.length - 1, 1)) * cw,
    y: padT + ch - ((s.score - minS) / range) * ch,
    ...s
  }))

  const line = points.map((p, i) => `${i === 0 ? 'M' : 'L'}${p.x},${p.y}`).join(' ')
  const area = line + ` L${points[points.length - 1].x},${padT + ch} L${points[0].x},${padT + ch} Z`
  const gridLines = [minS, minS + range * 0.33, minS + range * 0.67, maxS].map((v) => ({
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
      <path d={line} fill="none" stroke="var(--accent)" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" />
      {points.map((p, i) => (
        <g key={i}>
          <circle cx={p.x} cy={p.y} r="3.5" fill="var(--bg-base)" stroke="var(--accent)" strokeWidth="2" />
          <text x={p.x} y={h - 6} textAnchor="middle" fill="var(--text-tertiary)" fontSize="9">
            {p.date.split(' ')[1] || p.date}
          </text>
        </g>
      ))}
    </svg>
  )
}

function SRQueueChart({ byStatus }: { byStatus: Record<string, number> }): JSX.Element {
  const statuses = ['new', 'learning', 'relearning', 'review', 'mature']
  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: 14, marginTop: 8 }}>
      <div style={{ display: 'flex', height: 10, borderRadius: 5, overflow: 'hidden', gap: 2 }}>
        {statuses.map((s) => {
          const count = byStatus[s] || 0
          const info = SR_STATUS_LABELS[s]
          return count > 0 ? (
            <div key={s} style={{ flex: count, background: info.color, opacity: 0.7, transition: 'flex 0.6s ease' }} />
          ) : null
        })}
      </div>
      <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
        {statuses.map((s) => {
          const count = byStatus[s] || 0
          const info = SR_STATUS_LABELS[s]
          return (
            <div key={s} style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
              <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                <span style={{ width: 8, height: 8, borderRadius: '50%', background: info.color, opacity: 0.7 }} />
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
  header: { display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start' },
  title: { fontSize: 26, fontWeight: 700, color: 'var(--text-primary)', margin: 0, lineHeight: 1 },
  subtitle: { fontSize: 14, color: 'var(--text-secondary)', marginTop: 8 },
  statsRow: { display: 'flex', gap: 16, flexWrap: 'wrap' },
  chartsRow: { display: 'flex', gap: 16, flexWrap: 'wrap' },
  chartCard: {
    background: 'var(--bg-card)',
    borderRadius: 14,
    padding: '24px',
    border: '1px solid var(--border-subtle)',
    flex: 1,
    minWidth: 300
  },
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
