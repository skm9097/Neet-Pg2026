import { useState, useEffect, useRef, useCallback, CSSProperties } from 'react'
import type { MistakeCard, SyncStatus } from '../types'
import { subjectInfo, ICONS, ANIM_MS } from '../data'
import { Svg, SubjectBadge, StatusBadge, ErrorPill, IconBtn, Clock, Crossfade } from './ui'
import { CardVisual, prefetchCardImage } from './CardVisual'

interface Tweaks {
  fontSize: number
  animSpeed: 'slow' | 'normal' | 'fast'
  cardDuration: number
}

/**
 * Ambient screensaver — an editorial, full-screen review slide:
 *   • top bar: subject · topic · id  /  sync · clock
 *   • left column (42%): bold heading, scannable bullets, "what went wrong"
 *   • right column: the AI-generated infographic visual (hero), card stats below
 *   • bottom bar: transport controls, progress, position
 */
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

  // Warm the next card's visual so it's ready by the time it rotates in.
  useEffect(() => {
    if (cards.length < 2) return
    prefetchCardImage(cards[(idx + 1) % cards.length])
  }, [idx, cards])

  if (!card) {
    return (
      <div style={styles.shell}>
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
  const fs = tweaks.fontSize || 26
  const fadeMs = ANIM_MS[tweaks.animSpeed] || ANIM_MS.normal
  const heading = card.factHeading || card.question || stripLetter(card.correctAnswer)
  const points = card.factPoints.length ? card.factPoints : card.keyFact ? splitFact(card.keyFact) : []

  return (
    <div style={styles.shell}>
      {/* ── Row 1: top bar ── */}
      <div style={styles.topBar}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 16, minWidth: 0 }}>
          <SubjectBadge subject={card.subject} size="lg" />
          {topicLabel(card) && (
            <span style={{ fontSize: 13, color: 'var(--text-secondary)', fontWeight: 500 }}>{topicLabel(card)}</span>
          )}
          <span style={{ fontSize: 11, color: 'var(--text-tertiary)', fontFamily: "'JetBrains Mono', monospace" }}>
            {card.id}
          </span>
        </div>
        <div style={{ display: 'flex', alignItems: 'center', gap: 16, flexShrink: 0 }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
            <Svg markup={ICONS.sync} style={{ color: 'var(--text-tertiary)' }} />
            <span style={{ fontSize: 12, color: 'var(--text-tertiary)' }}>{syncLabel(sync)}</span>
          </div>
          <Clock />
        </div>
      </div>

      {/* ── Row 2: main content ── */}
      <div style={styles.mainArea}>
        <Crossfade keyProp={fadeKey} duration={fadeMs}>
          <div style={styles.mainGrid}>
            {/* Left: heading + bullets + mistake */}
            <div style={styles.leftCol}>
              <div
                style={{
                  fontSize: Math.round(fs * 1.3),
                  fontWeight: 800,
                  lineHeight: 1.18,
                  letterSpacing: '-0.02em',
                  color: 'var(--text-primary)',
                  marginBottom: 28
                }}
              >
                {heading}
              </div>

              <div style={{ display: 'flex', flexDirection: 'column', gap: 14, flex: 1, justifyContent: 'center' }}>
                {points.map((point, i) => (
                  <div
                    key={i}
                    style={{
                      display: 'flex',
                      alignItems: 'baseline',
                      gap: 14,
                      fontSize: Math.max(Math.round(fs * 0.62), 15),
                      lineHeight: 1.55,
                      color: 'var(--text-primary)',
                      fontWeight: 500
                    }}
                  >
                    <span
                      style={{
                        width: 6,
                        height: 6,
                        borderRadius: '50%',
                        flexShrink: 0,
                        background: info.color,
                        opacity: 0.65,
                        position: 'relative',
                        top: -2
                      }}
                    />
                    <span>{point}</span>
                  </div>
                ))}
              </div>

              {card.whyWrong && (
                <div style={{ marginTop: 'auto', paddingTop: 20, display: 'flex', flexDirection: 'column', gap: 6 }}>
                  <div
                    style={{
                      fontSize: 9,
                      fontWeight: 700,
                      letterSpacing: '0.11em',
                      textTransform: 'uppercase',
                      color: 'var(--wrong)',
                      opacity: 0.65
                    }}
                  >
                    Your mistake
                  </div>
                  <div
                    style={{
                      fontSize: Math.max(Math.round(fs * 0.5), 13),
                      color: 'var(--text-secondary)',
                      lineHeight: 1.55,
                      paddingLeft: 12,
                      borderLeft: `2px solid ${info.color}30`
                    }}
                  >
                    {shorten(card.whyWrong)}
                  </div>
                </div>
              )}
            </div>

            {/* Right: hero AI visual + stats */}
            <div style={styles.rightCol}>
              <CardVisual card={card} accent={info.color} />
              <div
                style={{
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'flex-end',
                  gap: 10,
                  paddingTop: 12
                }}
              >
                <span style={{ fontSize: 12, color: 'var(--wrong)', fontWeight: 600 }}>✕ {card.timesWrong}</span>
                {card.timesCorrect > 0 && (
                  <span style={{ fontSize: 12, color: 'var(--correct)', fontWeight: 600 }}>✓ {card.timesCorrect}</span>
                )}
                <ErrorPill type={card.errorType} />
                <StatusBadge status={card.srStatus} />
              </div>
            </div>
          </div>
        </Crossfade>
      </div>

      {/* ── Row 3: bottom controls ── */}
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

/** Strip a leading "A) " / "B) " option letter and the answer tick. */
function stripLetter(s: string): string {
  return (s || '')
    .replace(/^[A-D][.)]\s*/, '')
    .replace(/\s*✅\s*$/, '')
    .trim()
}

/** Split a flowing key-fact into a few bullet-sized clauses for the fallback. */
function splitFact(text: string): string[] {
  return text
    .split(/(?<=[.!?])\s+/)
    .map((s) => s.trim())
    .filter(Boolean)
    .slice(0, 5)
}

/** Only show the topic label when it adds information beyond the subject. */
function topicLabel(card: MistakeCard): string {
  const t = (card.topic || '').trim()
  if (!t) return ''
  if (t.toLowerCase() === card.subject.toLowerCase()) return ''
  return t.replace(/[-_]/g, ' ')
}

/** Trim a "why wrong" note to its first sentence or two so the slide stays light. */
function shorten(text: string, maxSentences = 2, maxChars = 220): string {
  if (!text) return ''
  const joined = text
    .split(/(?<=[.!?])\s+/)
    .slice(0, maxSentences)
    .join(' ')
    .trim()
  return joined.length > maxChars ? joined.slice(0, maxChars).replace(/\s+\S*$/, '') + '…' : joined
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
  shell: {
    width: '100%',
    height: '100%',
    display: 'flex',
    flexDirection: 'column',
    background: 'var(--bg-deep)',
    overflow: 'hidden'
  },
  topBar: {
    flexShrink: 0,
    display: 'flex',
    justifyContent: 'space-between',
    alignItems: 'center',
    padding: '12px 32px',
    borderBottom: '1px solid var(--border-subtle)'
  },
  mainArea: {
    flex: 1,
    minHeight: 0,
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'center',
    padding: '0 32px'
  },
  mainGrid: {
    display: 'flex',
    gap: 44,
    alignItems: 'stretch',
    width: '100%',
    height: '100%',
    maxWidth: 1500,
    padding: '28px 0'
  },
  leftCol: {
    flex: '0 0 42%',
    display: 'flex',
    flexDirection: 'column',
    justifyContent: 'flex-start',
    minWidth: 0
  },
  rightCol: {
    flex: 1,
    display: 'flex',
    flexDirection: 'column',
    justifyContent: 'center',
    minWidth: 0
  },
  bottomBar: {
    flexShrink: 0,
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'space-between',
    padding: '10px 32px',
    borderTop: '1px solid var(--border-subtle)',
    gap: 24
  }
}
