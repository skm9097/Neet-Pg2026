import { useState, useEffect, useRef, useCallback, CSSProperties } from 'react'
import type { MistakeCard, SyncStatus } from '../types'
import { subjectInfo, ICONS, ANIM_MS } from '../data'
import { SubjectBadge, StatusBadge, ErrorPill, IconBtn, Clock, Crossfade, SyncButton, EmptyState } from './ui'
import { CardVisual, prefetchCardImage } from './CardVisual'

interface Tweaks {
  fontSize: number
  adaptiveFontSize: boolean
  animSpeed: 'slow' | 'normal' | 'fast'
  cardDuration: number
  showImages: boolean
}

/**
 * Ambient screensaver — an editorial, full-screen review slide:
 *   • top bar: subject · topic · id  /  progress dots · sync · clock
 *   • left column (42%): bold heading, scannable bullets, "what went wrong"
 *   • right column: the AI-generated infographic visual (hero), card stats below
 *   • bottom bar: transport controls, progress, keyboard hints
 */
export function AmbientMode({
  feed,
  tweaks,
  sync,
  onSync,
  onTriggerQuiz
}: {
  feed: MistakeCard[]
  tweaks: Tweaks
  sync: SyncStatus
  onSync: () => void
  onTriggerQuiz: () => void
}): JSX.Element {
  const [idx, setIdx] = useState(0)
  const [paused, setPaused] = useState(false)
  const [fadeKey, setFadeKey] = useState(0)
  const [progress, setProgress] = useState(0)
  const timerRef = useRef<ReturnType<typeof setInterval> | null>(null)
  const duration = (tweaks.cardDuration || 20) * 1000
  const count = feed.length
  const card = count ? feed[idx % count] : null

  const goNext = useCallback(() => {
    setIdx((i) => (count ? (i + 1) % count : 0))
    setFadeKey((k) => k + 1)
  }, [count])

  const goPrev = useCallback(() => {
    setIdx((i) => (count ? (i - 1 + count) % count : 0))
    setFadeKey((k) => k + 1)
  }, [count])

  useEffect(() => {
    if (paused || count === 0) return
    timerRef.current = setInterval(goNext, duration)
    return () => {
      if (timerRef.current) clearInterval(timerRef.current)
    }
  }, [paused, duration, goNext, count])

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

  const showImages = tweaks.showImages !== false

  useEffect(() => {
    if (!showImages || count < 2) return
    prefetchCardImage(feed[(idx + 1) % count])
  }, [idx, feed, count, showImages])

  if (!card) {
    return (
      <div style={styles.shell}>
        <EmptyState
          title="No mistakes yet"
          subtitle="Sync your question bank to start reviewing. Mistakes you make on your phone will appear here automatically."
          action={{ label: 'Sync now', onClick: onSync }}
        />
      </div>
    )
  }

  const info = subjectInfo(card.subject)
  const fs = tweaks.fontSize || 26
  const fadeMs = ANIM_MS[tweaks.animSpeed] || ANIM_MS.normal
  const answer = stripLetter(card.correctAnswer)
  const topicText = card.factHeading || topicLabel(card) || card.subject
  const hasInsight = !!(card.displayHook || card.displayCompare)
  const answerFs = tweaks.adaptiveFontSize
    ? adaptiveHeroFs(answer.length)
    : Math.min(Math.round(fs * 3), 120)

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
          <ProgressDots idx={idx} total={count} color={info.color} />
          <SyncButton status={sync} onSync={onSync} size="sm" compact />
          <Clock />
        </div>
      </div>

      {/* ── Row 2: main content ── */}
      <div style={styles.mainArea}>
        <Crossfade keyProp={fadeKey} duration={fadeMs}>
          <div style={styles.mainGrid}>
            <div style={showImages ? styles.leftCol : styles.leftColFull}>
              {/* Topic label — small, muted */}
              <div style={{
                fontSize: Math.max(Math.round(fs * 0.38), 12),
                fontWeight: 600,
                letterSpacing: '0.1em',
                textTransform: 'uppercase',
                color: info.color,
                opacity: 0.7,
                marginBottom: 10,
              }}>
                {topicText}
              </div>

              {/* Hero: the correct answer */}
              <div style={{
                fontSize: answerFs,
                fontWeight: 800,
                lineHeight: 1.12,
                letterSpacing: '-0.025em',
                color: 'var(--text-primary)',
                marginBottom: 28,
              }}>
                {answer}
              </div>

              {/* ── Insight Card (AI-generated) or fallback ── */}
              {hasInsight ? (
                <InsightCard card={card} accent={info.color} fs={fs} />
              ) : (
                <FallbackBullets card={card} accent={info.color} fs={fs} />
              )}

              {/* Stats row */}
              <div style={{ display: 'flex', alignItems: 'center', gap: 10, paddingTop: 16 }}>
                <span style={{ fontSize: 12, color: 'var(--wrong)', fontWeight: 600 }}>✕ {card.timesWrong}</span>
                {card.timesCorrect > 0 && (
                  <span style={{ fontSize: 12, color: 'var(--correct)', fontWeight: 600 }}>✓ {card.timesCorrect}</span>
                )}
                <ErrorPill type={card.errorType} />
                <StatusBadge status={card.srStatus} />
              </div>
            </div>

            {showImages && (
              <div style={styles.rightCol}>
                <CardVisual card={card} accent={info.color} />
              </div>
            )}
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

        <div style={{ display: 'flex', alignItems: 'center', gap: 8, color: 'var(--text-tertiary)', fontSize: 12 }}>
          <span className="kbd">Space</span>
          <span>pause</span>
          <span style={{ opacity: 0.5 }}>·</span>
          <span className="kbd">←</span>
          <span className="kbd">→</span>
          <span>navigate</span>
        </div>

        <div
          style={{ display: 'flex', alignItems: 'center', gap: 12, flex: 1, maxWidth: 360, justifyContent: 'flex-end' }}
        >
          <div style={{ flex: 1, maxWidth: 240 }}>
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
            {(idx % count) + 1}/{count}
          </span>
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
    </div>
  )
}

/**
 * AI-powered insight card — replaces verbose text bullets with a structured
 * visual layout: key hook, wrong→right comparison, and optional mnemonic.
 */
function InsightCard({ card, accent, fs }: { card: MistakeCard; accent: string; fs: number }): JSX.Element {
  const wrongAnswer = stripLetter(card.userAnswer)
  const correctAnswer = stripLetter(card.correctAnswer)
  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: 20 }}>
      {/* Key hook — the ONE thing to remember */}
      {card.displayHook && (
        <div style={{
          fontSize: Math.max(Math.round(fs * 0.85), 20),
          fontWeight: 600,
          color: accent,
          lineHeight: 1.3,
        }}>
          {card.displayHook}
        </div>
      )}

      {/* Visual comparison: wrong → right */}
      <div style={{
        display: 'flex',
        alignItems: 'center',
        gap: 24,
        padding: '18px 24px',
        borderRadius: 14,
        background: 'var(--material-thin)',
        border: '1px solid var(--border-subtle)',
      }}>
        <div style={{ display: 'flex', flexDirection: 'column', gap: 6, flex: 1 }}>
          <span style={{ fontSize: Math.max(Math.round(fs * 0.35), 11), fontWeight: 700, color: 'var(--wrong)', letterSpacing: '0.08em', textTransform: 'uppercase' as const }}>
            You said
          </span>
          <span style={{ fontSize: Math.max(Math.round(fs * 0.7), 18), fontWeight: 600, color: 'var(--text-secondary)' }}>
            {wrongAnswer}
          </span>
        </div>
        <span style={{ fontSize: Math.max(Math.round(fs * 0.6), 20), color: 'var(--text-tertiary)', flexShrink: 0 }}>→</span>
        <div style={{ display: 'flex', flexDirection: 'column', gap: 6, flex: 1 }}>
          <span style={{ fontSize: Math.max(Math.round(fs * 0.35), 11), fontWeight: 700, color: 'var(--correct)', letterSpacing: '0.08em', textTransform: 'uppercase' as const }}>
            Correct
          </span>
          <span style={{ fontSize: Math.max(Math.round(fs * 0.7), 18), fontWeight: 600, color: 'var(--text-primary)' }}>
            {correctAnswer}
          </span>
        </div>
      </div>

      {/* Why — short comparison sentence */}
      {card.displayCompare && (
        <div style={{
          fontSize: Math.max(Math.round(fs * 0.65), 17),
          color: 'var(--text-secondary)',
          lineHeight: 1.45,
          fontWeight: 450,
          paddingLeft: 2,
        }}>
          {card.displayCompare}
        </div>
      )}

      {/* Mnemonic — memory aid */}
      {card.displayMnemonic && (
        <div style={{
          display: 'flex',
          alignItems: 'center',
          gap: 14,
          padding: '14px 20px',
          borderRadius: 12,
          background: `${accent}12`,
          border: `1px solid ${accent}25`,
        }}>
          <span style={{ fontSize: Math.max(Math.round(fs * 0.55), 18), flexShrink: 0 }}>💡</span>
          <span style={{
            fontSize: Math.max(Math.round(fs * 0.6), 16),
            color: accent,
            fontWeight: 500,
            fontStyle: 'italic',
            lineHeight: 1.4,
          }}>
            {card.displayMnemonic}
          </span>
        </div>
      )}
    </div>
  )
}

/** Fallback for cards not yet AI-enriched — shows clipped bullets + mistake line. */
function FallbackBullets({ card, accent, fs }: { card: MistakeCard; accent: string; fs: number }): JSX.Element {
  const points = card.factPoints?.length ? card.factPoints.slice(0, 3) : card.keyFact ? splitFact(card.keyFact).slice(0, 3) : []
  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: 14 }}>
      {points.length > 0 && points.map((point, i) => (
        <div key={i} style={{ display: 'flex', alignItems: 'baseline', gap: 14, fontSize: Math.max(Math.round(fs * 0.75), 18), lineHeight: 1.45, color: 'var(--text-secondary)', fontWeight: 450 }}>
          <span style={{ width: 7, height: 7, borderRadius: '50%', flexShrink: 0, background: accent, opacity: 0.45 }} />
          <span>{clipBullet(point)}</span>
        </div>
      ))}
      {card.whyWrong && (
        <div style={{ paddingTop: 16, display: 'flex', alignItems: 'baseline', gap: 12 }}>
          <span style={{ fontSize: Math.max(Math.round(fs * 0.35), 12), fontWeight: 700, color: 'var(--wrong)', opacity: 0.55, flexShrink: 0 }}>YOU PICKED</span>
          <span style={{ fontSize: Math.max(Math.round(fs * 0.6), 16), color: 'var(--text-tertiary)', lineHeight: 1.45 }}>
            {stripLetter(card.userAnswer)}
            <span style={{ opacity: 0.4 }}> — </span>
            {shorten(card.whyWrong)}
          </span>
        </div>
      )}
    </div>
  )
}

/** Subtle position dots (max 5 visible) — active uses the subject accent. */
function ProgressDots({ idx, total, color }: { idx: number; total: number; color: string }): JSX.Element {
  const max = Math.min(total, 5)
  const active = total ? idx % total : 0
  // Map the active card index onto the visible window of dots.
  const start = total <= max ? 0 : Math.max(0, Math.min(active - 2, total - max))
  return (
    <div style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
      {Array.from({ length: max }, (_, i) => {
        const cardIdx = start + i
        const isActive = cardIdx === active
        return (
          <span
            key={i}
            style={{
              width: 6,
              height: 6,
              borderRadius: '50%',
              background: isActive ? color : 'var(--text-tertiary)',
              opacity: isActive ? 1 : 0.3,
              transition: 'background 0.3s var(--ease-out), opacity 0.3s var(--ease-out)'
            }}
          />
        )
      })}
    </div>
  )
}

/**
 * Clip a verbose bullet to its first 8 words — no trailing ellipsis, no
 * mid-sentence cut. Old cards enriched with the verbose prompt get clean
 * display while they await re-enrichment by the short-phrase Groq prompt.
 */
function clipBullet(text: string): string {
  if (!text) return ''
  const words = text.trim().replace(/[.,;]$/, '').split(/\s+/)
  return words.length <= 8 ? words.join(' ') : words.slice(0, 8).join(' ')
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
    .slice(0, 4)
}

/** Only show the topic label when it adds information beyond the subject. */
function topicLabel(card: MistakeCard): string {
  const t = (card.topic || '').trim()
  if (!t) return ''
  if (t.toLowerCase() === card.subject.toLowerCase()) return ''
  return t.replace(/[-_]/g, ' ')
}

/** Condense a verbose "why wrong" note into max 8 words for ambient display. */
function shorten(text: string): string {
  if (!text) return ''
  let s = text
    .replace(/the\s+student'?s?\s+answer[,\s]+[^,]+,\s*(is\s+)?/i, '')
    .replace(/^(is\s+)?(incorrect|wrong)\s+(because\s+)?/i, '')
    .replace(/\b(the\s+)?(correct\s+)?answer\s+(is|was)\s*[:\-]?\s*(option\s*)?([A-Da-d][).:]\s*)?/i, '')
    .replace(/\b(this is because|it is|they are|which is|which are)\s+/i, '')
    .trim()
  if (!s) return ''
  s = s.charAt(0).toUpperCase() + s.slice(1)
  const words = s.replace(/[.,;:]+$/, '').split(/\s+/)
  return words.length <= 8 ? words.join(' ') : words.slice(0, 8).join(' ')
}

/**
 * Adaptive hero font size — fills the column for short answers, scales down
 * gracefully so longer answers never overflow the left panel.
 */
function adaptiveHeroFs(charLen: number): number {
  if (charLen <= 6)  return 128
  if (charLen <= 10) return 108
  if (charLen <= 16) return 88
  if (charLen <= 25) return 72
  if (charLen <= 38) return 56
  if (charLen <= 55) return 44
  return 34
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
    padding: '0 64px'
  },
  mainGrid: {
    display: 'flex',
    gap: 48,
    alignItems: 'stretch',
    width: '100%',
    height: '100%',
    padding: '28px 0'
  },
  leftCol: {
    flex: '0 0 52%',
    display: 'flex',
    flexDirection: 'column',
    justifyContent: 'center',
    minWidth: 0
  },
  leftColFull: {
    flex: 1,
    display: 'flex',
    flexDirection: 'column',
    justifyContent: 'center',
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
