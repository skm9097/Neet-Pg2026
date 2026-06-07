import { useState, useEffect, useRef, useCallback, CSSProperties } from 'react'
import type { MistakeCard, SyncStatus } from '../types'
import { subjectInfo, ICONS, ANIM_MS } from '../data'
import { Svg, SubjectBadge, StatusBadge, ErrorPill, IconBtn, Clock, Crossfade } from './ui'

interface Tweaks {
  fontSize: number
  animSpeed: 'slow' | 'normal' | 'fast'
  cardDuration: number
}

export function AmbientMode({
  cards,
  tweaks,
  sync,
  onTriggerQuiz
}: {
  cards: MistakeCard[]
  tweaks: Tweaks
  sync: SyncStatus
  onTriggerQuiz: () => void
}): JSX.Element {
  const [idx, setIdx] = useState(0)
  const [paused, setPaused] = useState(false)
  const [fadeKey, setFadeKey] = useState(0)
  const [progress, setProgress] = useState(0)
  const timerRef = useRef<ReturnType<typeof setInterval> | null>(null)
  const duration = (tweaks.cardDuration || 20) * 1000
  const card = cards[idx] || null

  const goNext = useCallback(() => {
    setIdx((i) => (cards.length ? (i + 1) % cards.length : 0))
    setFadeKey((k) => k + 1)
  }, [cards.length])

  const goPrev = useCallback(() => {
    setIdx((i) => (cards.length ? (i - 1 + cards.length) % cards.length : 0))
    setFadeKey((k) => k + 1)
  }, [cards.length])

  useEffect(() => {
    if (paused || cards.length === 0) return
    timerRef.current = setInterval(goNext, duration)
    return () => {
      if (timerRef.current) clearInterval(timerRef.current)
    }
  }, [paused, duration, goNext, cards.length])

  useEffect(() => {
    const handler = (e: KeyboardEvent): void => {
      const tag = (e.target as HTMLElement)?.tagName
      if (tag === 'INPUT' || tag === 'TEXTAREA') return
      if (e.key === ' ' || e.code === 'Space') {
        e.preventDefault()
        setPaused((p) => !p)
      }
      if (e.key === 'ArrowRight') {
        e.preventDefault()
        goNext()
      }
      if (e.key === 'ArrowLeft') {
        e.preventDefault()
        goPrev()
      }
    }
    window.addEventListener('keydown', handler)
    return () => window.removeEventListener('keydown', handler)
  }, [goNext, goPrev])

  useEffect(() => {
    if (paused) return
    setProgress(0)
    const start = Date.now()
    let raf = 0
    const frame = (): void => {
      const elapsed = Date.now() - start
      setProgress(Math.min(elapsed / duration, 1))
      if (elapsed < duration) raf = requestAnimationFrame(frame)
    }
    raf = requestAnimationFrame(frame)
    return () => cancelAnimationFrame(raf)
  }, [fadeKey, paused, duration])

  if (!card) {
    return (
      <div style={styles.container}>
        <div style={{ textAlign: 'center', padding: 40 }}>
          <div style={{ fontSize: 48, marginBottom: 16, opacity: 0.4 }}>📱</div>
          <div style={{ fontSize: 22, fontWeight: 600, marginBottom: 8, color: 'var(--text-primary)' }}>
            No mistakes synced yet
          </div>
          <div style={{ fontSize: 15, color: 'var(--text-secondary)' }}>
            Go study on your phone — your mistakes will appear here automatically
          </div>
        </div>
      </div>
    )
  }

  const info = subjectInfo(card.subject)
  const fontSize = tweaks.fontSize || 26
  const fadeMs = ANIM_MS[tweaks.animSpeed] || ANIM_MS.normal
  const points = card.factPoints.length ? card.factPoints : card.keyFact ? [card.keyFact] : []

  return (
    <div style={styles.container}>
      <div style={styles.vignette} />

      <div style={styles.topBar}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
          <Svg markup={ICONS.sync} style={{ color: 'var(--text-tertiary)' }} />
          <span style={{ fontSize: 12, color: 'var(--text-tertiary)' }}>{syncLabel(sync)}</span>
        </div>
        <Clock />
      </div>

      <Crossfade keyProp={fadeKey} duration={fadeMs}>
        <div style={styles.content}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 12, marginBottom: 24 }}>
            <SubjectBadge subject={card.subject} size="lg" />
            <span style={{ fontSize: 14, color: 'var(--text-secondary)', fontWeight: 500 }}>{card.topic}</span>
          </div>

          <div
            style={{
              fontSize: Math.round(fontSize * 1.15),
              fontWeight: 700,
              color: 'var(--text-primary)',
              marginBottom: 20,
              lineHeight: 1.3
            }}
          >
            {card.factHeading}
          </div>

          <div
            style={{
              display: 'flex',
              flexDirection: 'column',
              gap: 10,
              maxWidth: 800,
              marginBottom: 32,
              paddingLeft: 4
            }}
          >
            {points.map((point, i) => (
              <div
                key={i}
                style={{
                  display: 'flex',
                  alignItems: 'flex-start',
                  gap: 14,
                  fontSize: Math.round(fontSize * 0.85),
                  lineHeight: 1.65,
                  color: 'var(--text-primary)'
                }}
              >
                <span
                  style={{
                    width: 5,
                    height: 5,
                    borderRadius: '50%',
                    flexShrink: 0,
                    background: info.color,
                    opacity: 0.6,
                    marginTop: '0.55em'
                  }}
                />
                <span>{point}</span>
              </div>
            ))}
          </div>

          {card.whyWrong && (
            <div style={{ display: 'flex', flexDirection: 'column', gap: 6, maxWidth: 700, marginBottom: 32 }}>
              <div
                style={{
                  fontSize: 11,
                  fontWeight: 600,
                  letterSpacing: '0.07em',
                  textTransform: 'uppercase',
                  color: 'var(--wrong)',
                  opacity: 0.7
                }}
              >
                What went wrong
              </div>
              <div
                style={{
                  fontSize: Math.max(fontSize - 6, 14),
                  color: 'var(--text-secondary)',
                  lineHeight: 1.65,
                  paddingLeft: 14,
                  borderLeft: `2px solid ${info.color}25`
                }}
              >
                {card.whyWrong}
              </div>
            </div>
          )}

          <div style={{ display: 'flex', alignItems: 'center', gap: 16 }}>
            <span
              style={{
                fontSize: 13,
                color: 'var(--text-tertiary)',
                fontFamily: "'JetBrains Mono', monospace",
                fontWeight: 500
              }}
            >
              {card.id}
            </span>
            <span style={{ fontSize: 13, color: 'var(--wrong)', fontWeight: 500 }}>✕ {card.timesWrong}</span>
            {card.timesCorrect > 0 && (
              <span style={{ fontSize: 13, color: 'var(--correct)', fontWeight: 500 }}>✓ {card.timesCorrect}</span>
            )}
            <ErrorPill type={card.errorType} />
            <StatusBadge status={card.srStatus} />
          </div>
        </div>
      </Crossfade>

      <div style={styles.bottomBar}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 4 }}>
          <IconBtn icon={ICONS.prev} label="Previous (←)" onClick={goPrev} size={32} />
          <IconBtn
            icon={paused ? ICONS.play : ICONS.pause}
            label={paused ? 'Resume (Space)' : 'Pause (Space)'}
            onClick={() => setPaused((p) => !p)}
            size={32}
          />
          <IconBtn icon={ICONS.next} label="Next (→)" onClick={goNext} size={32} />
          <div style={{ width: 1, height: 16, background: 'var(--border)', margin: '0 4px' }} />
          <IconBtn icon={ICONS.quiz} label="Start Quiz" onClick={onTriggerQuiz} size={32} />
        </div>

        <div style={{ display: 'flex', alignItems: 'center', gap: 12, flex: 1, maxWidth: 400 }}>
          <div style={{ flex: 1 }}>
            <div style={{ width: '100%', height: 3, background: 'var(--bg-hover)', borderRadius: 3, overflow: 'hidden' }}>
              <div
                style={{
                  width: `${progress * 100}%`,
                  height: '100%',
                  background: `linear-gradient(90deg, ${info.color}60, ${info.color})`,
                  borderRadius: 3,
                  transition: 'none'
                }}
              />
            </div>
          </div>
          <span
            style={{
              fontSize: 12,
              color: 'var(--text-tertiary)',
              fontVariantNumeric: 'tabular-nums',
              fontFamily: "'JetBrains Mono', monospace",
              minWidth: 50,
              textAlign: 'right'
            }}
          >
            {idx + 1}/{cards.length}
          </span>
        </div>

        {paused && (
          <span
            style={{
              fontSize: 11,
              color: 'var(--warning)',
              fontWeight: 600,
              letterSpacing: '0.08em',
              textTransform: 'uppercase'
            }}
          >
            Paused
          </span>
        )}
      </div>
    </div>
  )
}

function syncLabel(sync: SyncStatus): string {
  if (sync.inProgress) return 'Syncing…'
  if (sync.lastError) return 'Sync error'
  if (!sync.lastSync) return 'Not synced yet'
  const mins = Math.round((Date.now() - new Date(sync.lastSync).getTime()) / 60000)
  if (mins <= 0) return 'Synced just now'
  if (mins === 1) return 'Synced 1m ago'
  if (mins < 60) return `Synced ${mins}m ago`
  return `Synced ${Math.round(mins / 60)}h ago`
}

const styles: Record<string, CSSProperties> = {
  container: {
    position: 'relative',
    width: '100%',
    height: '100%',
    display: 'flex',
    flexDirection: 'column',
    alignItems: 'center',
    justifyContent: 'center',
    background: 'var(--bg-deep)',
    overflow: 'hidden'
  },
  vignette: {
    position: 'absolute',
    inset: 0,
    pointerEvents: 'none',
    background: 'radial-gradient(ellipse at center, transparent 40%, var(--bg-deep) 100%)',
    opacity: 0.5
  },
  topBar: {
    position: 'absolute',
    top: 0,
    left: 0,
    right: 0,
    display: 'flex',
    justifyContent: 'space-between',
    alignItems: 'center',
    padding: '16px 24px',
    zIndex: 2
  },
  content: {
    position: 'relative',
    zIndex: 1,
    maxWidth: 900,
    width: '100%',
    padding: '0 48px',
    display: 'flex',
    flexDirection: 'column'
  },
  bottomBar: {
    position: 'absolute',
    bottom: 0,
    left: 0,
    right: 0,
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'space-between',
    padding: '16px 24px',
    gap: 24,
    zIndex: 2
  }
}
