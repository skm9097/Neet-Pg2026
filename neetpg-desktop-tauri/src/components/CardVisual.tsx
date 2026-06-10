import { useState, useEffect, CSSProperties } from 'react'
import type { MistakeCard, CardImage } from '../types'
import { subjectInfo } from '../data'

// Module-level memo so flipping back to a card never re-requests its image, and
// so prefetched images are instantly available when the card comes up.
const memo = new Map<string, CardImage>()

/** Kick off (and cache) image generation for a card without rendering it. */
export function prefetchCardImage(card: MistakeCard | null | undefined): void {
  if (!card) return
  const have = memo.get(card.id)
  if (have && (have.status === 'ready' || have.status === 'disabled')) return
  window.api
    .getCardImage(card.id)
    .then((r) => memo.set(card.id, r))
    .catch(() => {})
}

/**
 * The hero visual on the right of an ambient slide. Shows the AI-generated
 * infographic image once it's ready; until then (or if disabled / unavailable)
 * it shows a calm subject-tinted placeholder — never a blank box or a spinner
 * that disrupts the screensaver feel.
 */
export function CardVisual({ card, accent }: { card: MistakeCard; accent: string }): JSX.Element {
  const [img, setImg] = useState<CardImage | null>(() => memo.get(card.id) || null)

  useEffect(() => {
    let cancelled = false
    const have = memo.get(card.id)
    setImg(have || null)
    if (have && (have.status === 'ready' || have.status === 'disabled')) return
    window.api
      .getCardImage(card.id)
      .then((r) => {
        if (cancelled) return
        memo.set(card.id, r)
        setImg(r)
      })
      .catch(() => {})
    return () => {
      cancelled = true
    }
  }, [card.id])

  const info = subjectInfo(card.subject)

  if (img?.status === 'ready' && img.dataUrl) {
    return (
      <div style={{ ...frame(accent), padding: 10 }}>
        <img
          src={img.dataUrl}
          alt={card.factHeading || card.topic}
          style={{ width: '100%', height: '100%', objectFit: 'contain', borderRadius: 10 }}
        />
      </div>
    )
  }

  // Placeholder states: pending (generating), disabled (turned off), or
  // error (no key / quota / network). Keep it quiet and on-brand.
  const pending = !img || img.status === 'pending'
  const message =
    img?.message ||
    (img?.status === 'disabled'
      ? 'Card visuals are off'
      : img?.status === 'error'
        ? 'Couldn’t generate a visual — open Settings → AI Visuals'
        : 'Generating a visual…')

  return (
    <div style={{ ...frame(accent), ...center }}>
      <div
        style={{
          width: 72,
          height: 72,
          borderRadius: 20,
          background: info.dim,
          border: `1px solid ${info.color}40`,
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          marginBottom: 16
        }}
      >
        <span
          style={{
            fontSize: 30,
            fontWeight: 800,
            color: info.color,
            opacity: pending ? 0.9 : 0.7,
            animation: pending ? 'visualpulse 1.6s ease-in-out infinite' : undefined
          }}
        >
          {info.label.charAt(0)}
        </span>
      </div>
      <div
        style={{
          fontSize: 13,
          color: 'var(--text-tertiary)',
          textAlign: 'center',
          maxWidth: 300,
          lineHeight: 1.5
        }}
      >
        {message}
      </div>
      <style>{'@keyframes visualpulse{0%,100%{opacity:.45}50%{opacity:.95}}'}</style>
    </div>
  )
}

function frame(accent: string): CSSProperties {
  return {
    flex: 1,
    minHeight: 0,
    display: 'flex',
    background: 'var(--bg-elevated)',
    borderRadius: 18,
    border: '1px solid var(--border-subtle)',
    boxShadow: `inset 0 0 0 1px ${accent}10`,
    overflow: 'hidden'
  }
}

const center: CSSProperties = {
  flexDirection: 'column',
  alignItems: 'center',
  justifyContent: 'center',
  padding: 24
}
