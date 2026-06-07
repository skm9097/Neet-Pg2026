import { useState, useEffect, useRef, useCallback, CSSProperties } from 'react'
import type { MistakeCard } from '../types'
import { subjectInfo, ICONS } from '../data'
import { Svg, SubjectBadge, ErrorPill } from './ui'

interface Tweaks {
  animSpeed: 'slow' | 'normal' | 'fast'
  enableRephrase?: boolean
}

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
  const [countdown, setCountdown] = useState(15)
  const [mnemonic, setMnemonic] = useState<string | null>(null)
  const startTime = useRef(Date.now())

  useEffect(() => {
    const t = setTimeout(() => setEntering(false), 50)
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
      }, 350)
    },
    [card.id, onGrade, onDismiss]
  )

  const handleSubmit = (): void => {
    if (!selected) return
    const timeTaken = (Date.now() - startTime.current) / 1000
    const grade = isCorrect ? (timeTaken < 10 ? 5 : 4) : 1
    setPhase('result')
    if (isCorrect) {
      setTimeout(() => handleClose(grade), 2500)
    } else if (card.timesWrong >= 1) {
      // Repeated mistake → fetch a mnemonic in the background (non-blocking).
      window.api
        .llmGenerate('mnemonic', card.id)
        .then((m) => m && setMnemonic(m))
        .catch(() => {})
    }
  }

  useEffect(() => {
    if (phase !== 'result' || isCorrect || countdown <= 0) return
    const t = setTimeout(() => setCountdown((c) => c - 1), 1000)
    return () => clearTimeout(t)
  }, [phase, isCorrect, countdown])

  const animSpeed = tweaks.animSpeed === 'fast' ? 0.2 : tweaks.animSpeed === 'slow' ? 0.6 : 0.35

  return (
    <div
      style={{
        ...styles.overlay,
        opacity: exiting ? 0 : 1,
        transition: `opacity ${animSpeed}s ease`
      }}
    >
      <div
        style={{
          ...styles.card,
          transform: entering
            ? 'translateY(40px) scale(0.97)'
            : exiting
              ? 'translateY(20px) scale(0.98)'
              : 'translateY(0) scale(1)',
          opacity: entering ? 0 : 1,
          transition: `all ${animSpeed}s cubic-bezier(0.22, 1, 0.36, 1)`,
          borderColor: phase === 'result' ? (isCorrect ? 'var(--correct)' : 'var(--wrong)') : 'var(--border)',
          boxShadow:
            phase === 'result'
              ? `0 0 60px ${isCorrect ? 'var(--correct-dim)' : 'var(--wrong-dim)'}, 0 25px 60px rgba(0,0,0,0.4)`
              : '0 25px 60px rgba(0,0,0,0.4)'
        }}
      >
        <div style={styles.header}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
            <SubjectBadge subject={card.subject} />
            <span
              style={{ fontSize: 13, color: 'var(--text-tertiary)', fontFamily: "'JetBrains Mono', monospace" }}
            >
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
            onClose={() => handleClose(isCorrect ? 4 : 1)}
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
  const options = card.options.length
    ? card.options
    : ['A) ' + card.correctAnswer.replace(/^[A-D]\)\s*/, '')]
  return (
    <div>
      <div style={styles.question}>{card.question || card.factHeading}</div>
      <div style={{ display: 'flex', flexDirection: 'column', gap: 10, marginBottom: 28 }}>
        {options.map((opt, i) => {
          const letter = opt.charAt(0)
          const isSelected = selected === opt
          const clean = opt.replace(' ✅', '')
          return (
            <button
              key={i}
              onClick={() => onSelect(opt)}
              style={{
                ...styles.option,
                borderColor: isSelected ? 'var(--accent)' : 'var(--border)',
                background: isSelected ? 'var(--accent-dim)' : 'var(--bg-card)'
              }}
            >
              <span
                style={{
                  ...styles.optionLetter,
                  background: isSelected ? 'var(--accent)' : 'var(--bg-hover)',
                  color: isSelected ? '#fff' : 'var(--text-secondary)'
                }}
              >
                {letter}
              </span>
              <span style={{ color: 'var(--text-primary)', fontSize: 15 }}>{clean.replace(/^[A-D]\)\s*/, '')}</span>
            </button>
          )
        })}
      </div>
      <div style={{ display: 'flex', justifyContent: 'center' }}>
        <button
          onClick={onSubmit}
          disabled={!selected}
          style={{ ...styles.submitBtn, opacity: selected ? 1 : 0.4, cursor: selected ? 'pointer' : 'not-allowed' }}
        >
          Submit Answer
        </button>
      </div>
    </div>
  )
}

function ResultView({
  card,
  isCorrect,
  countdown,
  mnemonic,
  onClose
}: {
  card: MistakeCard
  isCorrect: boolean
  countdown: number
  mnemonic: string | null
  onClose: () => void
}): JSX.Element {
  const correctClean = card.correctAnswer.replace(' ✅', '')
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
        <span style={{ fontWeight: 600 }}>
          {isCorrect ? 'Correct!' : `Wrong — Correct: ${correctClean}`}
        </span>
      </div>

      {!isCorrect && (
        <div>
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
          <div style={{ display: 'flex', justifyContent: 'center' }}>
            <button
              onClick={countdown <= 0 ? onClose : undefined}
              style={{ ...styles.gotItBtn, opacity: countdown <= 0 ? 1 : 0.5, cursor: countdown <= 0 ? 'pointer' : 'default' }}
            >
              {countdown > 0 ? `Read carefully… (${countdown}s)` : 'Got it'}
            </button>
          </div>
        </div>
      )}

      {isCorrect && (
        <div style={{ textAlign: 'center', padding: '24px 0 8px' }}>
          <div style={{ fontSize: 15, color: 'var(--text-secondary)' }}>Dismissing automatically…</div>
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
    background: 'rgba(8, 10, 20, 0.85)',
    backdropFilter: 'blur(8px)',
    WebkitBackdropFilter: 'blur(8px)'
  },
  card: {
    width: '100%',
    maxWidth: 600,
    maxHeight: '90vh',
    overflowY: 'auto',
    background: 'var(--bg-base)',
    borderRadius: 20,
    border: '1.5px solid var(--border)',
    padding: '28px 32px'
  },
  header: { display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 24 },
  question: { fontSize: 18, lineHeight: 1.65, color: 'var(--text-primary)', fontWeight: 500, marginBottom: 24 },
  option: {
    display: 'flex',
    alignItems: 'center',
    gap: 14,
    padding: '14px 18px',
    borderRadius: 12,
    border: '1.5px solid var(--border)',
    cursor: 'pointer',
    textAlign: 'left',
    width: '100%',
    transition: 'all 0.15s ease'
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
    transition: 'all 0.15s ease'
  },
  submitBtn: {
    padding: '12px 36px',
    borderRadius: 12,
    border: 'none',
    background: 'var(--accent)',
    color: '#fff',
    fontSize: 15,
    fontWeight: 600,
    transition: 'all 0.2s ease'
  },
  resultBanner: {
    display: 'flex',
    alignItems: 'center',
    gap: 10,
    padding: '14px 20px',
    borderRadius: 12,
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
  factText: { fontSize: 15, lineHeight: 1.65, color: 'var(--text-primary)' },
  gotItBtn: {
    padding: '12px 32px',
    borderRadius: 12,
    border: '1.5px solid var(--border)',
    background: 'var(--bg-card)',
    color: 'var(--text-primary)',
    fontSize: 14,
    fontWeight: 500,
    transition: 'all 0.2s ease'
  }
}
