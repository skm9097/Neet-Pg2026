import { useState, useEffect, useRef, CSSProperties, ReactNode } from 'react'
import type { SyncStatus } from '../types'
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

// ─────────────────────────────────────────────────────────────────────────────
// Refined SwiftUI-style primitives
// ─────────────────────────────────────────────────────────────────────────────

/** Thin spinning ring. */
export function Spinner({
  size = 'md',
  color = 'currentColor'
}: {
  size?: 'sm' | 'md' | 'lg'
  color?: string
}): JSX.Element {
  const px = size === 'sm' ? 16 : size === 'lg' ? 32 : 24
  return (
    <span
      aria-label="loading"
      style={{
        display: 'inline-block',
        width: px,
        height: px,
        borderRadius: '50%',
        border: `${Math.max(2, Math.round(px / 11))}px solid rgba(255,255,255,0.15)`,
        borderTopColor: color,
        animation: 'spin 0.7s linear infinite',
        flexShrink: 0
      }}
    />
  )
}

/** SwiftUI-style filled / tinted / plain button with press feedback + loading. */
export function Button({
  children,
  variant = 'filled',
  size = 'md',
  loading = false,
  icon,
  disabled,
  onClick,
  style,
  title,
  fullWidth
}: {
  children: ReactNode
  variant?: 'filled' | 'tinted' | 'plain'
  size?: 'sm' | 'md' | 'lg'
  loading?: boolean
  icon?: string
  disabled?: boolean
  onClick?: () => void
  style?: CSSProperties
  title?: string
  fullWidth?: boolean
}): JSX.Element {
  const [hov, setHov] = useState(false)
  const pad = size === 'sm' ? '7px 14px' : size === 'lg' ? '13px 28px' : '10px 20px'
  const fs = size === 'sm' ? 13 : size === 'lg' ? 15 : 14
  const isOff = disabled || loading

  const variants: Record<string, CSSProperties> = {
    filled: {
      background: hov && !isOff ? 'var(--accent-hover)' : 'var(--accent)',
      color: '#fff',
      boxShadow: isOff ? 'none' : '0 2px 10px var(--accent-dim), inset 0 1px 0 rgba(255,255,255,0.12)'
    },
    tinted: {
      background: hov && !isOff ? 'color-mix(in srgb, var(--accent) 22%, transparent)' : 'var(--accent-dim)',
      color: 'var(--accent)'
    },
    plain: {
      background: hov && !isOff ? 'var(--bg-hover)' : 'transparent',
      color: 'var(--text-secondary)'
    }
  }

  return (
    <button
      onClick={isOff ? undefined : onClick}
      onMouseEnter={() => setHov(true)}
      onMouseLeave={() => setHov(false)}
      disabled={isOff}
      title={title}
      className="no-drag"
      style={{
        display: 'inline-flex',
        alignItems: 'center',
        justifyContent: 'center',
        gap: 8,
        width: fullWidth ? '100%' : undefined,
        padding: pad,
        fontSize: fs,
        fontWeight: 600,
        border: 'none',
        borderRadius: 'var(--radius-md)',
        cursor: isOff ? 'not-allowed' : 'pointer',
        opacity: isOff ? 0.55 : 1,
        whiteSpace: 'nowrap',
        transition: 'background 0.18s var(--ease-out), opacity 0.18s var(--ease-out), box-shadow 0.18s var(--ease-out)',
        ...variants[variant],
        ...style
      }}
    >
      {loading ? (
        <Spinner size="sm" />
      ) : icon ? (
        <Svg markup={icon} style={{ display: 'inline-flex' }} />
      ) : null}
      {children}
    </button>
  )
}

function relSync(iso: string): string {
  const mins = Math.round((Date.now() - new Date(iso).getTime()) / 60000)
  if (mins <= 0) return 'just now'
  if (mins === 1) return '1m ago'
  if (mins < 60) return `${mins}m ago`
  return `${Math.round(mins / 60)}h ago`
}

const PHASE_LABEL: Record<string, string> = {
  listing: 'Listing…',
  fetching: 'Fetching…',
  enriching: 'Enriching…',
  pushing: 'Pushing…',
  done: 'Synced',
  error: 'Sync error',
  idle: 'Syncing…'
}

/** Reusable sync control reflecting live SyncStatus. */
export function SyncButton({
  status,
  onSync,
  size = 'md',
  compact = false
}: {
  status: SyncStatus
  onSync: () => void
  size?: 'sm' | 'md' | 'lg'
  compact?: boolean
}): JSX.Element {
  const inProgress = status.inProgress
  const phaseLabel = status.phase && PHASE_LABEL[status.phase] ? PHASE_LABEL[status.phase] : 'Syncing…'

  let label: string
  let tone: string | undefined
  if (inProgress) {
    label = compact ? phaseLabel : phaseLabel
  } else if (status.lastError) {
    label = 'Sync error'
    tone = 'var(--wrong)'
  } else if (status.lastSync) {
    label = `Synced ${relSync(status.lastSync)}`
  } else {
    label = 'Not synced'
  }

  return (
    <Button
      variant="tinted"
      size={size}
      onClick={onSync}
      loading={inProgress}
      icon={inProgress ? undefined : ICONS.sync}
      title="Sync now"
      style={tone ? { color: tone, background: 'var(--wrong-dim)' } : undefined}
    >
      {label}
    </Button>
  )
}

/** iOS-style pill toggle. */
export function Toggle({
  checked,
  onChange,
  label,
  disabled
}: {
  checked: boolean
  onChange: (v: boolean) => void
  label?: string
  disabled?: boolean
}): JSX.Element {
  const sw = (
    <button
      role="switch"
      aria-checked={checked}
      disabled={disabled}
      onClick={() => !disabled && onChange(!checked)}
      className="no-drag"
      style={{
        width: 46,
        height: 28,
        borderRadius: 14,
        border: 'none',
        padding: 0,
        cursor: disabled ? 'not-allowed' : 'pointer',
        opacity: disabled ? 0.5 : 1,
        background: checked ? 'var(--accent)' : 'var(--bg-active)',
        position: 'relative',
        transition: 'background 0.25s var(--ease-out)',
        flexShrink: 0
      }}
    >
      <span
        style={{
          position: 'absolute',
          top: 3,
          left: checked ? 21 : 3,
          width: 22,
          height: 22,
          borderRadius: '50%',
          background: '#fff',
          boxShadow: '0 1px 4px rgba(0,0,0,0.35)',
          transition: 'left 0.25s var(--spring-bounce)'
        }}
      />
    </button>
  )
  if (!label) return sw
  return (
    <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', gap: 16 }}>
      <label style={{ fontSize: 14, color: 'var(--text-primary)', fontWeight: 500, lineHeight: 1.4 }}>{label}</label>
      {sw}
    </div>
  )
}

/** Pill segmented control with sliding active indicator. */
export function SegmentedControl<T extends string>({
  options,
  value,
  onChange
}: {
  options: { value: T; label: string }[]
  value: T
  onChange: (v: T) => void
}): JSX.Element {
  const idx = Math.max(0, options.findIndex((o) => o.value === value))
  return (
    <div
      style={{
        position: 'relative',
        display: 'flex',
        padding: 3,
        borderRadius: 'var(--radius-md)',
        background: 'var(--bg-active)',
        gap: 0
      }}
    >
      <span
        style={{
          position: 'absolute',
          top: 3,
          bottom: 3,
          left: `calc(${(idx / options.length) * 100}% + 3px)`,
          width: `calc(${100 / options.length}% - 6px)`,
          borderRadius: 'calc(var(--radius-md) - 3px)',
          background: 'var(--accent)',
          boxShadow: '0 2px 8px var(--accent-dim)',
          transition: 'left 0.3s var(--spring)',
          zIndex: 0
        }}
      />
      {options.map((opt) => {
        const active = opt.value === value
        return (
          <button
            key={opt.value}
            onClick={() => onChange(opt.value)}
            className="no-drag"
            style={{
              position: 'relative',
              zIndex: 1,
              flex: 1,
              padding: '7px 12px',
              border: 'none',
              background: 'transparent',
              borderRadius: 'calc(var(--radius-md) - 3px)',
              fontSize: 13,
              fontWeight: 600,
              cursor: 'pointer',
              color: active ? '#fff' : 'var(--text-secondary)',
              transition: 'color 0.25s var(--ease-out)',
              whiteSpace: 'nowrap'
            }}
          >
            {opt.label}
          </button>
        )
      })}
    </div>
  )
}

/** Consistent panel/card surface. */
export function Surface({
  children,
  padding = 20,
  radius = 'var(--radius-lg)',
  glass = false,
  elevated = false,
  style
}: {
  children: ReactNode
  padding?: number | string
  radius?: number | string
  glass?: boolean
  elevated?: boolean
  style?: CSSProperties
}): JSX.Element {
  return (
    <div
      className={glass ? 'glass' : undefined}
      style={{
        padding,
        borderRadius: radius,
        background: glass ? undefined : elevated ? 'var(--bg-elevated)' : 'var(--bg-card)',
        border: glass ? undefined : '1px solid var(--border-subtle)',
        boxShadow: elevated ? 'var(--shadow-md)' : undefined,
        ...style
      }}
    >
      {children}
    </div>
  )
}

/** Beautiful no-data state with a subject-tinted monogram. */
export function EmptyState({
  title,
  subtitle,
  action
}: {
  title: string
  subtitle?: string
  action?: { label: string; onClick: () => void }
}): JSX.Element {
  return (
    <div
      className="rise"
      style={{
        display: 'flex',
        flexDirection: 'column',
        alignItems: 'center',
        justifyContent: 'center',
        textAlign: 'center',
        padding: 48,
        gap: 8,
        width: '100%',
        height: '100%'
      }}
    >
      <div
        style={{
          width: 92,
          height: 92,
          borderRadius: 26,
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          background: 'var(--accent-dim)',
          border: '1px solid color-mix(in srgb, var(--accent) 30%, transparent)',
          marginBottom: 14,
          boxShadow: 'var(--shadow-md)'
        }}
      >
        <span style={{ fontSize: 44, fontWeight: 800, color: 'var(--accent)', opacity: 0.85 }}>N</span>
      </div>
      <div style={{ fontSize: 20, fontWeight: 700, color: 'var(--text-primary)' }}>{title}</div>
      {subtitle && (
        <div style={{ fontSize: 14, color: 'var(--text-secondary)', maxWidth: 360, lineHeight: 1.55 }}>{subtitle}</div>
      )}
      {action && (
        <div style={{ marginTop: 12 }}>
          <Button variant="filled" icon={ICONS.sync} onClick={action.onClick}>
            {action.label}
          </Button>
        </div>
      )}
    </div>
  )
}

/** Circular progress indicator (0..1). */
export function ProgressRing({
  value,
  size = 64,
  strokeWidth = 5,
  color = 'var(--accent)',
  children
}: {
  value: number
  size?: number
  strokeWidth?: number
  color?: string
  children?: ReactNode
}): JSX.Element {
  const v = Math.max(0, Math.min(1, value))
  const r = (size - strokeWidth) / 2
  const c = 2 * Math.PI * r
  return (
    <div style={{ position: 'relative', width: size, height: size, flexShrink: 0 }}>
      <svg width={size} height={size} style={{ transform: 'rotate(-90deg)' }}>
        <circle cx={size / 2} cy={size / 2} r={r} fill="none" stroke="var(--bg-active)" strokeWidth={strokeWidth} />
        <circle
          cx={size / 2}
          cy={size / 2}
          r={r}
          fill="none"
          stroke={color}
          strokeWidth={strokeWidth}
          strokeLinecap="round"
          strokeDasharray={c}
          strokeDashoffset={c * (1 - v)}
          style={{ transition: 'stroke-dashoffset 0.95s linear' }}
        />
      </svg>
      {children !== undefined && (
        <div
          style={{
            position: 'absolute',
            inset: 0,
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            fontVariantNumeric: 'tabular-nums'
          }}
        >
          {children}
        </div>
      )}
    </div>
  )
}

// ── Toast: ephemeral notification singleton ──
type ToastItem = { id: number; message: string; type: 'info' | 'success' | 'error' }
let toastSeq = 0
const toastListeners = new Set<(items: ToastItem[]) => void>()
let toastItems: ToastItem[] = []

export function showToast(message: string, type: 'info' | 'success' | 'error' = 'info'): void {
  const item: ToastItem = { id: ++toastSeq, message, type }
  toastItems = [...toastItems, item]
  toastListeners.forEach((l) => l(toastItems))
  setTimeout(() => {
    toastItems = toastItems.filter((t) => t.id !== item.id)
    toastListeners.forEach((l) => l(toastItems))
  }, 3200)
}

export function Toast(): JSX.Element {
  const [items, setItems] = useState<ToastItem[]>(toastItems)
  useEffect(() => {
    toastListeners.add(setItems)
    return () => {
      toastListeners.delete(setItems)
    }
  }, [])
  const toneColor = (t: ToastItem['type']): string =>
    t === 'success' ? 'var(--correct)' : t === 'error' ? 'var(--wrong)' : 'var(--accent)'
  return (
    <div
      style={{
        position: 'fixed',
        bottom: 24,
        left: '50%',
        transform: 'translateX(-50%)',
        display: 'flex',
        flexDirection: 'column',
        gap: 8,
        zIndex: 200,
        pointerEvents: 'none'
      }}
    >
      {items.map((t) => (
        <div
          key={t.id}
          className="glass"
          style={{
            animation: 'popIn 0.3s var(--spring-bounce) both',
            display: 'flex',
            alignItems: 'center',
            gap: 10,
            padding: '11px 18px',
            borderRadius: 'var(--radius-md)',
            boxShadow: 'var(--shadow-lg)',
            fontSize: 13,
            fontWeight: 500,
            color: 'var(--text-primary)'
          }}
        >
          <span style={{ width: 8, height: 8, borderRadius: '50%', background: toneColor(t.type), flexShrink: 0 }} />
          {t.message}
        </div>
      ))}
    </div>
  )
}
