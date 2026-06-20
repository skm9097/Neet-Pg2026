import { useState, useEffect, useCallback, CSSProperties } from 'react'
import type { MistakeCard } from '../types'
import { subjectInfo, ICONS } from '../data'
import { Svg, SubjectBadge, ErrorPill, Button, ProgressRing } from './ui'
import { CardVisual } from './CardVisual'

interface Tweaks {
  animSpeed: 'slow' | 'normal' | 'fast'
  enableRephrase?: boolean
}

const READ_SECONDS = 15

export function QuizInterrupt({
  card,
  onGrade,
  onDismiss,
  tweaks
}: {
  card: MistakeCard
  onGrade: (cardId: string, grade: number) => void
  onDismiss: () => void
  tweaks: Tweaks
}): JSX.Element {
  const [phase, setPhase] = useState<'question' | 'result'>('question')
  const [selected, setSelected] = useState<string | null>(null)
  const [entering, setEntering] = useState(true)
  const [exiting, setExiting] = useState(false)
  const [countdown, setCountdown] = useState(READ_SECONDS)
  const [mnemonic, setMnemonic] = useState<string | null>(null)


  useEffect(() => {
    const t = setTimeout(() => setEntering(false), 30)
    return () => clearTimeout(t)
  }, [])

  const correctLetter = card.correctAnswer.charAt(0)
  const isCorrect = !!selected && selected.charAt(0) === correctLetter

  const handleClose = useCallback(
    (grade: number) => {
      setExiting(true)
      setTimeout(() => {
        onGrade(card.id, grade)
        onDismiss()
      }, 320)
    },
    [card.id, onGrade, onDismiss]
  )

  const handleSubmit = (): void => {
    if (!selected) return
    setPhase('result')
    if (!isCorrect && card.timesWrong >= 1) {
      // Repeated mistake → fetch a mnemonic in the background (non-blocking).
      window.api
        .llmGenerate('mnemonic', card.id)
        .then((m) => m && setMnemonic(m))
        .catch(() => {})
    }
  }

  // Forced read-through countdown for wrong answers.
  useEffect(() => {
    if (phase !== 'result' || isCorrect || countdown <= 0) return
    const t = setTimeout(() => setCountdown((c) => c - 1), 1000)
    return () => clearTimeout(t)
  }, [phase, isCorrect, countdown])

  const animSpeed = tweaks.animSpeed === 'fast' ? 0.2 : tweaks.animSpeed === 'slow' ? 0.6 : 0.36

  return (
    <div
      style={{
        ...styles.overlay,
        opacity: exiting ? 0 : 1,
        transition: `opacity ${animSpeed}s var(--ease-out)`
      }}
    >
      <div
        className="glass"
        style={{
          ...styles.card,
          transform: entering ? 'scale(0.92)' : exiting ? 'scale(0.97)' : 'scale(1)',
          opacity: entering ? 0 : 1,
          transition: `transform ${animSpeed}s var(--spring-bounce), opacity ${animSpeed}s var(--ease-out), border-color 0.3s var(--ease-out), box-shadow 0.3s var(--ease-out)`,
          borderColor:
            phase === 'result' ? (isCorrect ? 'var(--correct)' : 'var(--wrong)') : 'rgba(255,255,255,0.1)',
          boxShadow:
            phase === 'result'
              ? `0 0 60px ${isCorrect ? 'var(--correct-dim)' : 'var(--wrong-dim)'}, var(--shadow-lg)`
              : 'var(--shadow-lg)'
        }}
      >
        <div style={styles.header}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
            <SubjectBadge subject={card.subject} />
            <span style={{ fontSize: 13, color: 'var(--text-tertiary)', fontFamily: "'JetBrains Mono', monospace" }}>
              {card.id}
            </span>
          </div>
          <ErrorPill type={card.errorType} />
        </div>

        {phase === 'question' ? (
          <QuestionView card={card} selected={selected} onSelect={setSelected} onSubmit={handleSubmit} />
        ) : (
          <ResultView
            card={card}
            isCorrect={isCorrect}
            countdown={countdown}
            mnemonic={mnemonic}
            onGrade={handleClose}
          />
        )}
      </div>
    </div>
  )
}

function QuestionView({
  card,
  selected,
  onSelect,
  onSubmit
}: {
  card: MistakeCard
  selected: string | null
  onSelect: (o: string) => void
  onSubmit: () => void
}): JSX.Element {
  const options = card.options.length ? card.options : ['A) ' + card.correctAnswer.replace(/^[A-D]\)\s*/, '')]
  return (
    <div>
      <div style={styles.question}>{card.question || card.factHeading}</div>
      <div style={{ display: 'flex', flexDirection: 'column', gap: 10, marginBottom: 28 }}>
        {options.map((opt, i) => {
          const letter = opt.charAt(0)
          const isSelected = selected === opt
          const clean = opt.replace(' ✅', '')
          return (
            <OptionButton
              key={i}
              letter={letter}
              text={clean.replace(/^[A-D]\)\s*/, '')}
              selected={isSelected}
              onClick={() => onSelect(opt)}
            />
          )
        })}
      </div>
      <div style={{ display: 'flex', justifyContent: 'center' }}>
        <Button variant="filled" size="lg" disabled={!selected} onClick={onSubmit}>
          Submit Answer
        </Button>
      </div>
    </div>
  )
}

function OptionButton({
  letter,
  text,
  selected,
  onClick
}: {
  letter: string
  text: string
  selected: boolean
  onClick: () => void
}): JSX.Element {
  const [hov, setHov] = useState(false)
  return (
    <button
      onClick={onClick}
      onMouseEnter={() => setHov(true)}
      onMouseLeave={() => setHov(false)}
      style={{
        ...styles.option,
        borderColor: selected ? 'var(--accent)' : hov ? 'var(--hairline-strong)' : 'var(--border)',
        background: selected ? 'var(--accent-dim)' : hov ? 'var(--bg-hover)' : 'var(--bg-card)'
      }}
    >
      <span
        style={{
          ...styles.optionLetter,
          background: selected ? 'var(--accent)' : 'var(--bg-hover)',
          color: selected ? '#fff' : 'var(--text-secondary)'
        }}
      >
        {letter}
      </span>
      <span style={{ color: 'var(--text-primary)', fontSize: 15 }}>{text}</span>
    </button>
  )
}

function ResultView({
  card,
  isCorrect,
  countdown,
  mnemonic,
  onGrade
}: {
  card: MistakeCard
  isCorrect: boolean
  countdown: number
  mnemonic: string | null
  onGrade: (grade: number) => void
}): JSX.Element {
  const correctClean = card.correctAnswer.replace(' ✅', '')
  const info = subjectInfo(card.subject)

  return (
    <div>
      <div
        style={{
          ...styles.resultBanner,
          background: isCorrect ? 'var(--correct-dim)' : 'var(--wrong-dim)',
          color: isCorrect ? 'var(--correct)' : 'var(--wrong)'
        }}
      >
        <Svg markup={isCorrect ? ICONS.check : ICONS.x} />
        <span style={{ fontWeight: 600 }}>{isCorrect ? 'Correct!' : `Wrong — Correct: ${correctClean}`}</span>
      </div>

      {isCorrect ? (
        <>
          <div style={{ fontSize: 14, color: 'var(--text-secondary)', textAlign: 'center', marginBottom: 24 }}>
            How well did you know it?
          </div>
          <div style={{ display: 'flex', gap: 10, justifyContent: 'center' }}>
            <Button variant="tinted" onClick={() => onGrade(3)} style={{ color: 'var(--warning)', background: 'rgba(240,180,73,0.14)' }}>
              Hard
            </Button>
            <Button variant="tinted" onClick={() => onGrade(4)}>
              Good
            </Button>
            <Button variant="filled" onClick={() => onGrade(5)}>
              Easy
            </Button>
          </div>
        </>
      ) : (
        <div>
          {/* Reinforce with the card's generated visual while they read. */}
          <div style={{ height: 200, display: 'flex', marginBottom: 20 }}>
            <CardVisual card={card} accent={info.color} />
          </div>
          {card.keyFact && (
            <div style={{ marginBottom: 20 }}>
              <div style={styles.factLabel}>Key Fact</div>
              <div style={styles.factText}>{card.keyFact}</div>
            </div>
          )}
          {card.whyWrong && (
            <div style={{ marginBottom: 20 }}>
              <div style={styles.factLabel}>Why You Got It Wrong</div>
              <div style={{ ...styles.factText, color: 'var(--text-secondary)' }}>{card.whyWrong}</div>
            </div>
          )}
          {mnemonic && (
            <div style={{ marginBottom: 20 }}>
              <div style={{ ...styles.factLabel, color: 'var(--accent)' }}>Memory Hook</div>
              <div style={{ ...styles.factText, fontStyle: 'italic' }}>{mnemonic}</div>
            </div>
          )}
          <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 16 }}>
            {countdown > 0 ? (
              <div style={{ display: 'flex', alignItems: 'center', gap: 14 }}>
                <ProgressRing value={(READ_SECONDS - countdown) / READ_SECONDS} size={52} strokeWidth={4}>
                  <span style={{ fontSize: 15, fontWeight: 700, color: 'var(--text-secondary)' }}>{countdown}</span>
                </ProgressRing>
                <span style={{ fontSize: 14, color: 'var(--text-tertiary)' }}>Read carefully…</span>
              </div>
            ) : (
              <Button variant="filled" size="lg" onClick={() => onGrade(2)}>
                Understood
              </Button>
            )}
          </div>
        </div>
      )}
    </div>
  )
}

const styles: Record<string, CSSProperties> = {
  overlay: {
    position: 'fixed',
    inset: 0,
    zIndex: 100,
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'center',
    background: 'rgba(8, 10, 20, 0.78)',
    backdropFilter: 'blur(14px) saturate(1.2)',
    WebkitBackdropFilter: 'blur(14px) saturate(1.2)'
  },
  card: {
    width: '100%',
    maxWidth: 600,
    maxHeight: '90vh',
    overflowY: 'auto',
    background: 'var(--bg-glass)',
    borderRadius: 'var(--radius-xl)',
    border: '1.5px solid rgba(255,255,255,0.1)',
    padding: '28px 32px'
  },
  header: { display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 24 },
  question: { fontSize: 18, lineHeight: 1.65, color: 'var(--text-primary)', fontWeight: 500, marginBottom: 24 },
  option: {
    display: 'flex',
    alignItems: 'center',
    gap: 14,
    padding: '14px 18px',
    borderRadius: 'var(--radius-md)',
    border: '1.5px solid var(--border)',
    cursor: 'pointer',
    textAlign: 'left',
    width: '100%',
    transition: 'background 0.15s var(--ease-out), border-color 0.15s var(--ease-out)'
  },
  optionLetter: {
    width: 30,
    height: 30,
    borderRadius: 8,
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'center',
    fontSize: 13,
    fontWeight: 700,
    flexShrink: 0,
    transition: 'all 0.15s var(--ease-out)'
  },
  resultBanner: {
    display: 'flex',
    alignItems: 'center',
    gap: 10,
    padding: '14px 20px',
    borderRadius: 'var(--radius-md)',
    marginBottom: 24,
    fontSize: 15
  },
  factLabel: {
    fontSize: 11,
    fontWeight: 600,
    letterSpacing: '0.06em',
    textTransform: 'uppercase',
    color: 'var(--text-tertiary)',
    marginBottom: 8
  },
  factText: { fontSize: 15, lineHeight: 1.65, color: 'var(--text-primary)' }
}
