import { useState, useEffect, useRef, CSSProperties, ReactNode } from 'react'
import { subjectInfo, SR_STATUS_LABELS, ICONS } from '../data'

export function Svg({ markup, style }: { markup: string; style?: CSSProperties }): JSX.Element {
  return <span style={style} dangerouslySetInnerHTML={{ __html: markup }} />
}

export function SubjectBadge({
  subject,
  size = 'md'
}: {
  subject: string
  size?: 'sm' | 'md' | 'lg'
}): JSX.Element {
  const info = subjectInfo(subject)
  const sizes = {
    sm: { fs: 10, px: 8, py: 3 },
    md: { fs: 11, px: 12, py: 5 },
    lg: { fs: 13, px: 16, py: 6 }
  }
  const s = sizes[size]
  return (
    <span
      style={{
        display: 'inline-flex',
        alignItems: 'center',
        gap: 6,
        fontSize: s.fs,
        fontWeight: 600,
        letterSpacing: '0.06em',
        textTransform: 'uppercase',
        color: info.color,
        background: info.dim,
        borderRadius: 20,
        padding: `${s.py}px ${s.px}px`,
        lineHeight: 1
      }}
    >
      <span style={{ width: 6, height: 6, borderRadius: '50%', background: info.color, opacity: 0.8 }} />
      {info.label}
    </span>
  )
}

export function StatusBadge({ status }: { status: string }): JSX.Element {
  const info = SR_STATUS_LABELS[status] || SR_STATUS_LABELS.new
  return (
    <span
      style={{
        fontSize: 10,
        fontWeight: 600,
        letterSpacing: '0.05em',
        textTransform: 'uppercase',
        color: info.color,
        background: `${info.color}18`,
        borderRadius: 20,
        padding: '3px 10px',
        lineHeight: 1
      }}
    >
      {info.label}
    </span>
  )
}

export function ErrorPill({ type }: { type: string }): JSX.Element | null {
  if (!type) return null
  const colors: Record<string, string> = {
    conceptual: '#ef6b6b',
    recall: '#f0b449',
    silly: '#7a80a0'
  }
  const c = colors[type] || colors.silly
  return (
    <span
      style={{
        fontSize: 10,
        fontWeight: 500,
        color: c,
        background: `${c}15`,
        borderRadius: 20,
        padding: '3px 8px',
        lineHeight: 1
      }}
    >
      {type}
    </span>
  )
}

export function IconBtn({
  icon,
  label,
  active,
  onClick,
  size = 36
}: {
  icon: string
  label: string
  active?: boolean
  onClick: () => void
  size?: number
}): JSX.Element {
  const [hov, setHov] = useState(false)
  return (
    <button
      onClick={onClick}
      onMouseEnter={() => setHov(true)}
      onMouseLeave={() => setHov(false)}
      title={label}
      className="no-drag"
      style={{
        width: size,
        height: size,
        borderRadius: 10,
        border: 'none',
        cursor: 'pointer',
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        background: active ? 'var(--accent-dim)' : hov ? 'var(--bg-hover)' : 'transparent',
        color: active ? 'var(--accent)' : hov ? 'var(--text-primary)' : 'var(--text-tertiary)',
        transition: 'all 0.2s ease'
      }}
    >
      <Svg markup={icon} />
    </button>
  )
}

export function Clock(): JSX.Element {
  const [time, setTime] = useState(new Date())
  useEffect(() => {
    const iv = setInterval(() => setTime(new Date()), 30000)
    return () => clearInterval(iv)
  }, [])
  return (
    <span
      style={{
        display: 'inline-flex',
        alignItems: 'center',
        gap: 6,
        fontSize: 13,
        color: 'var(--text-tertiary)',
        fontWeight: 500,
        fontVariantNumeric: 'tabular-nums'
      }}
    >
      <Svg markup={ICONS.clock} />
      {time.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}
    </span>
  )
}

export function StatCard({
  label,
  value,
  sub,
  accent
}: {
  label: string
  value: ReactNode
  sub?: string
  accent?: string
}): JSX.Element {
  return (
    <div
      style={{
        background: 'var(--bg-card)',
        borderRadius: 14,
        padding: '20px 24px',
        border: '1px solid var(--border-subtle)',
        flex: 1,
        minWidth: 140
      }}
    >
      <div
        style={{
          fontSize: 12,
          color: 'var(--text-tertiary)',
          fontWeight: 500,
          letterSpacing: '0.04em',
          textTransform: 'uppercase',
          marginBottom: 8
        }}
      >
        {label}
      </div>
      <div
        style={{
          fontSize: 32,
          fontWeight: 700,
          color: accent || 'var(--text-primary)',
          fontVariantNumeric: 'tabular-nums',
          lineHeight: 1
        }}
      >
        {value}
      </div>
      {sub && <div style={{ fontSize: 12, color: 'var(--text-secondary)', marginTop: 6 }}>{sub}</div>}
    </div>
  )
}

/** Crossfade wrapper — fades old content out then new in (skips on first mount). */
export function Crossfade({
  keyProp,
  children,
  duration = 600
}: {
  keyProp: number | string
  children: ReactNode
  duration?: number
}): JSX.Element {
  const [display, setDisplay] = useState<ReactNode>(children)
  const [opacity, setOpacity] = useState(1)
  const timeoutRef = useRef<ReturnType<typeof setTimeout> | null>(null)
  const isFirst = useRef(true)

  useEffect(() => {
    if (isFirst.current) {
      isFirst.current = false
      setDisplay(children)
      setOpacity(1)
      return
    }
    setOpacity(0)
    if (timeoutRef.current) clearTimeout(timeoutRef.current)
    timeoutRef.current = setTimeout(() => {
      setDisplay(children)
      setTimeout(() => setOpacity(1), 30)
    }, duration / 2)
    return () => {
      if (timeoutRef.current) clearTimeout(timeoutRef.current)
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [keyProp])

  return <div style={{ opacity, transition: `opacity ${duration / 2}ms ease` }}>{display}</div>
}
