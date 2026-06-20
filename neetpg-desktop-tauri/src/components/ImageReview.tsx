import { useState, useEffect, useCallback, CSSProperties } from 'react'
import type { ImageReport, ImageReportEntry } from '../types'
import { Button, Surface, Spinner, EmptyState, SubjectBadge, showToast } from './ui'

type Filter = 'all' | 'error' | 'queued' | 'ready'

const STATUS_TINT: Record<ImageReportEntry['status'], { label: string; color: string }> = {
  ready: { label: 'Ready', color: 'var(--correct)' },
  queued: { label: 'Queued', color: 'var(--accent)' },
  blocked: { label: 'Waiting', color: '#e0a84c' },
  error: { label: 'Error', color: 'var(--wrong)' }
}

/**
 * Image review screen: shows every card's generated visual (or why it failed),
 * today's generation budget, and lets the user batch-generate or redo a single
 * image. Thumbnails are fetched lazily and only for images that already exist,
 * so opening this screen never spends generation quota.
 */
export function ImageReview(): JSX.Element {
  const [report, setReport] = useState<ImageReport | null>(null)
  const [filter, setFilter] = useState<Filter>('all')
  const [generating, setGenerating] = useState(false)

  const refresh = useCallback(() => {
    window.api.getImageReport().then(setReport)
  }, [])

  useEffect(() => {
    refresh()
    const iv = setInterval(refresh, 20000)
    return () => clearInterval(iv)
  }, [refresh])

  const generateNow = async (): Promise<void> => {
    setGenerating(true)
    try {
      const r = await window.api.generateImagesNow()
      showToast(r.message, r.made > 0 ? 'success' : 'info')
    } finally {
      setGenerating(false)
      refresh()
    }
  }

  if (!report) {
    return (
      <div style={{ ...styles.container, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
        <Spinner size="lg" color="var(--accent)" />
      </div>
    )
  }

  const { quota } = report
  const blocked = !!quota.blockedUntil
  const remaining = Math.max(0, quota.limit - quota.used)
  const entries = report.entries.filter((e) => {
    if (filter === 'all') return true
    if (filter === 'queued') return e.status === 'queued' || e.status === 'blocked'
    return e.status === filter
  })

  return (
    <div style={styles.container}>
      <div style={styles.inner}>
        <h1 style={styles.title}>Card Images</h1>
        <p style={styles.subtitle}>
          Every flashcard's generated visual — check results, spot failures, regenerate the bad ones
        </p>

        {/* Quota + batch controls */}
        <div style={{ marginTop: 24 }}>
          <Surface padding={18} radius="var(--radius-lg)">
            <div style={{ display: 'flex', alignItems: 'center', gap: 20, flexWrap: 'wrap' }}>
              <div style={{ flex: 1, minWidth: 220 }}>
                <div style={{ fontSize: 15, fontWeight: 600, color: 'var(--text-primary)' }}>
                  Today's budget: {quota.used} / {quota.limit} used
                </div>
                <div style={{ fontSize: 13, color: blocked ? '#e0a84c' : 'var(--text-secondary)', marginTop: 4 }}>
                  {blocked
                    ? `Provider limit hit — automatically resumes ${new Date(quota.blockedUntil!).toLocaleString()}`
                    : remaining > 0
                      ? `${remaining} generation${remaining === 1 ? '' : 's'} left today (resets at midnight)`
                      : 'Budget used — generation resumes tomorrow'}
                </div>
                {/* budget bar */}
                <div style={styles.barTrack}>
                  <div
                    style={{
                      ...styles.barFill,
                      width: `${Math.min(100, (quota.used / quota.limit) * 100)}%`,
                      background: blocked ? '#e0a84c' : 'var(--accent)'
                    }}
                  />
                </div>
              </div>
              <Button
                variant="filled"
                loading={generating}
                disabled={blocked || remaining === 0 || report.queued === 0}
                onClick={generateNow}
              >
                Generate now ({Math.min(remaining, report.queued)})
              </Button>
            </div>
          </Surface>
        </div>

        {/* Counters as filters */}
        <div style={{ display: 'flex', gap: 10, marginTop: 18, flexWrap: 'wrap' }}>
          <FilterChip label={`All ${report.total}`} active={filter === 'all'} onClick={() => setFilter('all')} />
          <FilterChip
            label={`Ready ${report.ready}`}
            color="var(--correct)"
            active={filter === 'ready'}
            onClick={() => setFilter('ready')}
          />
          <FilterChip
            label={`Queued ${report.queued}`}
            color="var(--accent)"
            active={filter === 'queued'}
            onClick={() => setFilter('queued')}
          />
          <FilterChip
            label={`Errors ${report.errors}`}
            color="var(--wrong)"
            active={filter === 'error'}
            onClick={() => setFilter('error')}
          />
        </div>

        {entries.length === 0 ? (
          <div style={{ marginTop: 40 }}>
            <EmptyState
              title={report.total === 0 ? 'No cards yet' : 'Nothing here'}
              subtitle={
                report.total === 0
                  ? 'Images appear once mistakes sync in from your phone.'
                  : 'No cards match this filter.'
              }
            />
          </div>
        ) : (
          <div style={styles.grid}>
            {entries.slice(0, 120).map((e) => (
              <ImageCell key={e.cardId} entry={e} onChanged={refresh} />
            ))}
          </div>
        )}
        {entries.length > 120 && (
          <div style={{ fontSize: 12, color: 'var(--text-tertiary)', marginTop: 14, textAlign: 'center' }}>
            Showing the first 120 of {entries.length} — use the filters to narrow down
          </div>
        )}

        <div style={{ height: 40 }} />
      </div>
    </div>
  )
}

function FilterChip({
  label,
  color = 'var(--text-secondary)',
  active,
  onClick
}: {
  label: string
  color?: string
  active: boolean
  onClick: () => void
}): JSX.Element {
  return (
    <button
      onClick={onClick}
      className="no-drag"
      style={{
        padding: '7px 14px',
        borderRadius: 20,
        border: active ? `1.5px solid ${color}` : '1.5px solid var(--border-subtle)',
        background: active ? 'var(--bg-active)' : 'transparent',
        color: active ? color : 'var(--text-secondary)',
        fontSize: 13,
        fontWeight: 600,
        cursor: 'pointer',
        transition: 'all 0.2s var(--ease-out)'
      }}
    >
      {label}
    </button>
  )
}

/**
 * One card's tile. Fetches its thumbnail lazily — only when the image already
 * exists on disk (status 'ready'), so rendering the grid never triggers
 * generation.
 */
function ImageCell({ entry, onChanged }: { entry: ImageReportEntry; onChanged: () => void }): JSX.Element {
  const [thumb, setThumb] = useState<string | null>(null)
  const [busy, setBusy] = useState(false)
  const tint = STATUS_TINT[entry.status]

  useEffect(() => {
    let alive = true
    if (entry.status === 'ready') {
      window.api.getCardImage(entry.cardId).then((r) => {
        if (alive && r.dataUrl) setThumb(r.dataUrl)
      })
    } else {
      setThumb(null)
    }
    return () => {
      alive = false
    }
  }, [entry.cardId, entry.status])

  const regenerate = async (): Promise<void> => {
    setBusy(true)
    try {
      const r = await window.api.regenerateImage(entry.cardId)
      if (r.status === 'ready' && r.dataUrl) {
        setThumb(r.dataUrl)
        showToast(`Regenerated ${entry.cardId}`, 'success')
      } else {
        showToast(r.message || 'Regeneration failed', 'error')
      }
    } finally {
      setBusy(false)
      onChanged()
    }
  }

  return (
    <Surface padding={0} radius="var(--radius-lg)" style={{ overflow: 'hidden' }}>
      <div style={styles.thumbBox}>
        {thumb ? (
          <img src={thumb} alt={entry.heading} style={styles.thumbImg} />
        ) : (
          <div style={styles.thumbEmpty}>
            {busy ? (
              <Spinner color="var(--accent)" />
            ) : (
              <span style={{ fontSize: 26, fontWeight: 800, color: tint.color, opacity: 0.5 }}>
                {entry.status === 'error' ? '!' : '…'}
              </span>
            )}
          </div>
        )}
        <span style={{ ...styles.statusChip, color: tint.color, background: 'rgba(10,12,20,0.78)' }}>
          {entry.fromRepo ? 'From repo' : tint.label}
        </span>
      </div>
      <div style={{ padding: '12px 14px' }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginBottom: 6 }}>
          <SubjectBadge subject={entry.subject} size="sm" />
          <span style={{ fontSize: 11, color: 'var(--text-tertiary)', fontFamily: "'JetBrains Mono', monospace" }}>
            {entry.cardId}
          </span>
        </div>
        <div style={styles.cellHeading}>{entry.heading}</div>
        {entry.error && <div style={styles.cellError}>{entry.error}</div>}
        <div style={{ marginTop: 10 }}>
          <Button variant="tinted" size="sm" loading={busy} onClick={regenerate}>
            {entry.status === 'ready' ? 'Redo' : 'Generate'}
          </Button>
        </div>
      </div>
    </Surface>
  )
}

const styles: Record<string, CSSProperties> = {
  container: { width: '100%', height: '100%', overflow: 'auto', padding: '32px 40px 32px 88px' },
  inner: { maxWidth: 1060, margin: '0 auto' },
  title: { fontSize: 28, fontWeight: 800, color: 'var(--text-primary)', margin: 0, lineHeight: 1, letterSpacing: '-0.02em' },
  subtitle: { fontSize: 14, color: 'var(--text-secondary)', marginTop: 8, marginBottom: 8 },
  barTrack: {
    marginTop: 10,
    height: 6,
    borderRadius: 3,
    background: 'var(--bg-active)',
    overflow: 'hidden'
  },
  barFill: { height: '100%', borderRadius: 3, transition: 'width 0.4s var(--ease-out)' },
  grid: {
    marginTop: 18,
    display: 'grid',
    gridTemplateColumns: 'repeat(auto-fill, minmax(230px, 1fr))',
    gap: 14
  },
  thumbBox: {
    position: 'relative',
    width: '100%',
    aspectRatio: '4 / 3',
    background: 'var(--bg-deep)'
  },
  thumbImg: { width: '100%', height: '100%', objectFit: 'cover', display: 'block' },
  thumbEmpty: {
    width: '100%',
    height: '100%',
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'center'
  },
  statusChip: {
    position: 'absolute',
    top: 8,
    right: 8,
    fontSize: 10,
    fontWeight: 700,
    letterSpacing: '0.05em',
    textTransform: 'uppercase',
    padding: '4px 9px',
    borderRadius: 12,
    backdropFilter: 'blur(6px)'
  },
  cellHeading: {
    fontSize: 13,
    fontWeight: 600,
    color: 'var(--text-primary)',
    lineHeight: 1.35,
    display: '-webkit-box',
    WebkitLineClamp: 2,
    WebkitBoxOrient: 'vertical',
    overflow: 'hidden'
  },
  cellError: {
    marginTop: 6,
    fontSize: 11,
    color: 'var(--wrong)',
    lineHeight: 1.4
  }
}
