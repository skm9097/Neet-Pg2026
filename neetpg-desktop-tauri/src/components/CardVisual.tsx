import { useState, useEffect, useCallback, CSSProperties } from 'react'
import type { MistakeCard, CardImage } from '../types'
import { subjectInfo } from '../data'

// Module-level memo so flipping back to a card never re-requests its image,
// and prefetched images are available instantly when their card comes up.
const memo = new Map<string, CardImage>()

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
 * Hero visual on the right of an ambient slide.  Click the image to expand
 * it in a full-screen lightbox with pinch / wheel zoom support.
 */
export function CardVisual({ card, accent }: { card: MistakeCard; accent: string }): JSX.Element {
  const [img, setImg] = useState<CardImage | null>(() => memo.get(card.id) ?? null)
  const [zoomed, setZoomed] = useState(false)

  useEffect(() => {
    let cancelled = false
    const have = memo.get(card.id)
    setImg(have ?? null)
    if (have && (have.status === 'ready' || have.status === 'disabled')) return
    window.api
      .getCardImage(card.id)
      .then((r) => {
        if (cancelled) return
        memo.set(card.id, r)
        setImg(r)
      })
      .catch(() => {})
    return () => { cancelled = true }
  }, [card.id])

  // Close lightbox on Escape
  useEffect(() => {
    if (!zoomed) return
    const handler = (e: KeyboardEvent): void => { if (e.key === 'Escape') setZoomed(false) }
    window.addEventListener('keydown', handler)
    return () => window.removeEventListener('keydown', handler)
  }, [zoomed])

  const info = subjectInfo(card.subject)

  if (img?.status === 'ready' && img.dataUrl) {
    return (
      <>
        <div
          style={{ ...frame(accent), padding: 10, cursor: 'zoom-in' }}
          onClick={() => setZoomed(true)}
          title="Click to zoom"
        >
          <img
            src={img.dataUrl}
            alt={card.factHeading || card.topic}
            style={{ width: '100%', height: '100%', objectFit: 'contain', borderRadius: 10 }}
            draggable={false}
          />
        </div>
        {zoomed && (
          <Lightbox src={img.dataUrl} alt={card.factHeading || card.topic} onClose={() => setZoomed(false)} />
        )}
      </>
    )
  }

  const pending = !img || img.status === 'pending'
  const message =
    img?.message ||
    (img?.status === 'disabled'
      ? 'Card visuals are off'
      : img?.status === 'error'
        ? "Couldn't generate a visual — open Settings → AI Visuals"
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
      <div style={{ fontSize: 13, color: 'var(--text-tertiary)', textAlign: 'center', maxWidth: 300, lineHeight: 1.5 }}>
        {message}
      </div>
      <style>{'@keyframes visualpulse{0%,100%{opacity:.45}50%{opacity:.95}}'}</style>
    </div>
  )
}

// ── Lightbox ─────────────────────────────────────────────────────────────────

function Lightbox({ src, alt, onClose }: { src: string; alt: string; onClose: () => void }): JSX.Element {
  const [scale, setScale] = useState(1)
  const [offset, setOffset] = useState({ x: 0, y: 0 })
  const [dragging, setDragging] = useState(false)
  const [dragStart, setDragStart] = useState({ mx: 0, ox: 0, oy: 0 })

  const zoom = useCallback((delta: number, cx: number, cy: number): void => {
    setScale((prev) => {
      const next = Math.min(8, Math.max(0.5, prev * (1 + delta)))
      // Adjust offset so we zoom toward the cursor position
      const ratio = next / prev - 1
      setOffset((o) => ({ x: o.x - cx * ratio, y: o.y - cy * ratio }))
      return next
    })
  }, [])

  const onWheel = useCallback(
    (e: React.WheelEvent<HTMLDivElement>): void => {
      e.preventDefault()
      const rect = (e.currentTarget as HTMLElement).getBoundingClientRect()
      zoom(-e.deltaY * 0.001, e.clientX - rect.width / 2, e.clientY - rect.height / 2)
    },
    [zoom]
  )

  const onMouseDown = useCallback((e: React.MouseEvent): void => {
    if (e.button !== 0) return
    setDragging(true)
    setDragStart({ mx: e.clientX, ox: offset.x, oy: offset.y })
  }, [offset])

  const onMouseMove = useCallback(
    (e: React.MouseEvent): void => {
      if (!dragging) return
      setOffset({ x: dragStart.ox + e.clientX - dragStart.mx, y: dragStart.oy + e.clientY })
    },
    [dragging, dragStart]
  )

  const onMouseUp = useCallback((): void => setDragging(false), [])

  const resetZoom = useCallback((): void => {
    setScale(1)
    setOffset({ x: 0, y: 0 })
  }, [])

  return (
    <div
      style={lb.overlay}
      onClick={onClose}
    >
      <div
        style={lb.stage}
        onClick={(e) => e.stopPropagation()}
        onWheel={onWheel}
        onMouseDown={onMouseDown}
        onMouseMove={onMouseMove}
        onMouseUp={onMouseUp}
        onMouseLeave={onMouseUp}
      >
        <img
          src={src}
          alt={alt}
          draggable={false}
          style={{
            ...lb.img,
            transform: `translate(${offset.x}px, ${offset.y}px) scale(${scale})`,
            cursor: dragging ? 'grabbing' : scale > 1 ? 'grab' : 'zoom-out'
          }}
        />
      </div>

      {/* Controls */}
      <div style={lb.controls} onClick={(e) => e.stopPropagation()}>
        <LbBtn label="Zoom in  (+)" onClick={() => zoom(0.3, 0, 0)}>＋</LbBtn>
        <LbBtn label="Reset zoom" onClick={resetZoom}>{Math.round(scale * 100)}%</LbBtn>
        <LbBtn label="Zoom out (−)" onClick={() => zoom(-0.3, 0, 0)}>−</LbBtn>
        <div style={{ width: 1, height: 20, background: 'rgba(255,255,255,0.15)', margin: '0 4px' }} />
        <LbBtn label="Close (Esc)" onClick={onClose}>✕</LbBtn>
      </div>

      <div style={lb.hint}>Scroll to zoom · drag to pan · click outside to close</div>
    </div>
  )
}

function LbBtn({ label, onClick, children }: { label: string; onClick: () => void; children: React.ReactNode }): JSX.Element {
  return (
    <button
      title={label}
      onClick={onClick}
      style={{
        background: 'rgba(255,255,255,0.1)',
        border: '1px solid rgba(255,255,255,0.15)',
        color: '#fff',
        borderRadius: 8,
        padding: '4px 12px',
        fontSize: 14,
        fontWeight: 600,
        cursor: 'pointer',
        backdropFilter: 'blur(8px)',
        transition: 'background 0.15s'
      }}
    >
      {children}
    </button>
  )
}

// ── styles ────────────────────────────────────────────────────────────────────

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

const lb: Record<string, CSSProperties> = {
  overlay: {
    position: 'fixed',
    inset: 0,
    zIndex: 9000,
    background: 'rgba(0,0,0,0.88)',
    display: 'flex',
    flexDirection: 'column',
    alignItems: 'center',
    justifyContent: 'center',
    backdropFilter: 'blur(6px)',
    cursor: 'zoom-out'
  },
  stage: {
    position: 'relative',
    flex: 1,
    width: '100%',
    overflow: 'hidden',
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'center',
    cursor: 'auto'
  },
  img: {
    maxWidth: '90vw',
    maxHeight: '80vh',
    objectFit: 'contain',
    borderRadius: 12,
    boxShadow: '0 24px 80px rgba(0,0,0,0.6)',
    transformOrigin: 'center center',
    userSelect: 'none',
    transition: 'transform 0.05s'
  },
  controls: {
    flexShrink: 0,
    display: 'flex',
    alignItems: 'center',
    gap: 8,
    padding: '14px 24px',
    borderTop: '1px solid rgba(255,255,255,0.08)'
  },
  hint: {
    flexShrink: 0,
    fontSize: 11,
    color: 'rgba(255,255,255,0.3)',
    paddingBottom: 10,
    letterSpacing: '0.04em'
  }
}
