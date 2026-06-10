import { useState, useEffect, useRef, useCallback, useMemo, CSSProperties } from 'react'
import type { AppConfig, AppMode, MistakeCard, DashboardStats, SyncStatus } from './types'
import { ICONS } from './data'
import { Svg, Toast } from './components/ui'
import { AmbientMode } from './components/AmbientMode'
import { Dashboard } from './components/Dashboard'
import { ImageReview } from './components/ImageReview'
import { Settings } from './components/Settings'
import { QuizInterrupt } from './components/QuizInterrupt'
import { Setup } from './components/Setup'

const ACCENT_MAP: Record<string, { accent: string; dim: string; hover: string }> = {
  blue: { accent: '#6b8cef', dim: 'rgba(107,140,239,0.15)', hover: '#8ba5f5' },
  teal: { accent: '#5bb8c4', dim: 'rgba(91,184,196,0.15)', hover: '#7dd0da' },
  violet: { accent: '#9b7ce8', dim: 'rgba(155,124,232,0.15)', hover: '#b49af0' },
  amber: { accent: '#e0a84c', dim: 'rgba(224,168,76,0.15)', hover: '#e8bc70' }
}
type ThemeEntry = {
  deep: string; base: string; card: string;
  textPrimary?: string; textSecondary?: string; textTertiary?: string;
  hairline?: string; hairlineStrong?: string;
  border?: string; borderSubtle?: string;
  bgHover?: string; bgActive?: string; bgElevated?: string; bgGlass?: string;
  materialThin?: string; material?: string; materialThick?: string; materialChrome?: string;
  topHighlight?: string;
  shadowSm?: string; shadowMd?: string; shadowLg?: string;
}
const THEME_MAP: Record<string, ThemeEntry> = {
  midnight: { deep: '#0b0e18', base: '#111525', card: '#181d30' },
  charcoal: { deep: '#101014', base: '#18181c', card: '#222226' },
  navy:     { deep: '#0a1020', base: '#0f1730', card: '#162040' },
  light: {
    deep: '#e8eaf2', base: '#f0f2f8', card: '#ffffff',
    textPrimary: '#0f1117', textSecondary: '#3c4152', textTertiary: '#6b7280',
    hairline: 'rgba(0,0,0,0.1)', hairlineStrong: 'rgba(0,0,0,0.18)',
    border: 'rgba(0,0,0,0.1)', borderSubtle: 'rgba(0,0,0,0.06)',
    bgHover: 'rgba(0,0,0,0.04)', bgActive: 'rgba(0,0,0,0.08)',
    bgElevated: '#ffffff', bgGlass: 'rgba(248,249,252,0.9)',
    materialThin: 'rgba(0,0,0,0.02)', material: 'rgba(0,0,0,0.04)',
    materialThick: 'rgba(240,242,248,0.92)', materialChrome: 'rgba(0,0,0,0.06)',
    topHighlight: 'inset 0 1px 0 rgba(255,255,255,0.8)',
    shadowSm: '0 1px 2px rgba(0,0,0,0.08),0 2px 8px rgba(0,0,0,0.06)',
    shadowMd: '0 4px 16px rgba(0,0,0,0.1),0 1px 3px rgba(0,0,0,0.08)',
    shadowLg: '0 20px 50px rgba(0,0,0,0.15),0 4px 14px rgba(0,0,0,0.1)',
  }
}

const EMPTY_STATS: DashboardStats = {
  due: 0,
  reviewed: 0,
  total: 0,
  unresolved: 0,
  resolved: 0,
  streakDays: 0,
  byStatus: {},
  topics: [],
  sessions: [],
  stubborn: []
}

export function App(): JSX.Element {
  const [config, setConfig] = useState<AppConfig | null>(null)
  const [mode, setMode] = useState<AppMode>('ambient')
  // `cards` powers the dashboard's totals; `reviewFeed` is the ordered
  // smart-review queue (due → weak topics → recent) shown in ambient mode.
  const [cards, setCards] = useState<MistakeCard[]>([])
  const [reviewFeed, setReviewFeed] = useState<MistakeCard[]>([])
  const [stats, setStats] = useState<DashboardStats>(EMPTY_STATS)
  const [sync, setSync] = useState<SyncStatus>({ lastSync: null, lastError: null, inProgress: false, totalCards: 0 })
  const [quizCard, setQuizCard] = useState<MistakeCard | null>(null)
  // navOpen = rail expanded; uiVisible = rail + toggle button currently shown
  // (both fade after a few seconds of no input, on every screen).
  const [navOpen, setNavOpen] = useState(false)
  const [uiVisible, setUiVisible] = useState(true)

  // ── Initial load ──
  useEffect(() => {
    window.api.getConfig().then(setConfig)
  }, [])

  const refreshData = useCallback(async () => {
    const [c, feed, s, ss] = await Promise.all([
      window.api.getCards(),
      window.api.getReviewFeed(40),
      window.api.getStats(),
      window.api.getSyncStatus()
    ])
    setCards(c)
    setReviewFeed(feed)
    setStats(s)
    setSync(ss)
  }, [])

  useEffect(() => {
    if (config?.configured) refreshData()
  }, [config?.configured, refreshData])

  // ── Apply accent + theme CSS vars live ──
  useEffect(() => {
    if (!config) return
    const a = ACCENT_MAP[config.accentHue] || ACCENT_MAP.blue
    const th = THEME_MAP[config.themeVariant] || THEME_MAP.midnight
    const r = document.documentElement.style
    r.setProperty('--accent', a.accent)
    r.setProperty('--accent-dim', a.dim)
    r.setProperty('--accent-hover', a.hover)
    r.setProperty('--bg-deep', th.deep)
    r.setProperty('--bg-base', th.base)
    r.setProperty('--bg-card', th.card)
    r.setProperty('--text-primary',    th.textPrimary    ?? '#f1f3f9')
    r.setProperty('--text-secondary',  th.textSecondary  ?? '#9aa0bc')
    r.setProperty('--text-tertiary',   th.textTertiary   ?? '#646a8a')
    r.setProperty('--hairline',        th.hairline        ?? 'rgba(255,255,255,0.08)')
    r.setProperty('--hairline-strong', th.hairlineStrong  ?? 'rgba(255,255,255,0.14)')
    r.setProperty('--border',          th.border          ?? 'rgba(255,255,255,0.1)')
    r.setProperty('--border-subtle',   th.borderSubtle    ?? 'rgba(255,255,255,0.05)')
    r.setProperty('--bg-hover',        th.bgHover         ?? 'rgba(255,255,255,0.06)')
    r.setProperty('--bg-active',       th.bgActive        ?? 'rgba(255,255,255,0.1)')
    r.setProperty('--bg-elevated',     th.bgElevated      ?? '#1f2540')
    r.setProperty('--bg-glass',        th.bgGlass         ?? 'rgba(24,29,48,0.72)')
    r.setProperty('--material-thin',   th.materialThin    ?? 'rgba(255,255,255,0.04)')
    r.setProperty('--material',        th.material        ?? 'rgba(255,255,255,0.055)')
    r.setProperty('--material-thick',  th.materialThick   ?? 'rgba(20,24,40,0.72)')
    r.setProperty('--material-chrome', th.materialChrome  ?? 'rgba(255,255,255,0.08)')
    r.setProperty('--top-highlight',   th.topHighlight    ?? 'inset 0 1px 0 rgba(255,255,255,0.06)')
    r.setProperty('--shadow-sm',       th.shadowSm        ?? '0 1px 2px rgba(0,0,0,0.25),0 2px 8px rgba(0,0,0,0.18)')
    r.setProperty('--shadow-md',       th.shadowMd        ?? '0 4px 16px rgba(0,0,0,0.3),0 1px 3px rgba(0,0,0,0.2)')
    r.setProperty('--shadow-lg',       th.shadowLg        ?? '0 20px 50px rgba(0,0,0,0.45),0 4px 14px rgba(0,0,0,0.3)')
  }, [config?.accentHue, config?.themeVariant])

  const triggerQuiz = useCallback(async () => {
    const card = await window.api.getNextQuizCard()
    if (card) setQuizCard(card)
  }, [])

  // ── Main-process events ──
  useEffect(() => {
    const off1 = window.api.onModeChange((m) => {
      // 'active' from idle detection maps to dashboard here.
      const next: AppMode =
        m === 'ambient' ? 'ambient' : m === 'settings' ? 'settings' : m === 'images' ? 'images' : 'dashboard'
      setMode(next)
      window.api.setFullscreen(next === 'ambient')
    })
    const off2 = window.api.onCardsUpdated(() => refreshData())
    const off3 = window.api.onTriggerQuiz(() => triggerQuiz())
    const off4 = window.api.onSyncStatus((s) => setSync(s))
    return () => {
      off1()
      off2()
      off3()
      off4()
    }
  }, [refreshData, triggerQuiz])

  // ── Periodic stats/sync refresh so the dashboard & ambient header stay live ──
  useEffect(() => {
    if (!config?.configured) return
    const iv = setInterval(() => {
      window.api.getSyncStatus().then(setSync)
      if (mode === 'dashboard') window.api.getStats().then(setStats)
    }, 30000)
    return () => clearInterval(iv)
  }, [config?.configured, mode])

  // ── Auto-hide the nav rail + toggle button on every screen ──
  // The rail floats over the content (never pushes it), and both the rail and
  // its toggle button fade after a few seconds of no mouse/keyboard activity,
  // reappearing on the next interaction.
  useEffect(() => {
    let timeout: ReturnType<typeof setTimeout>
    const reveal = (): void => {
      setUiVisible(true)
      clearTimeout(timeout)
      timeout = setTimeout(() => setUiVisible(false), 3500)
    }
    reveal()
    window.addEventListener('mousemove', reveal)
    window.addEventListener('keydown', reveal)
    return () => {
      window.removeEventListener('mousemove', reveal)
      window.removeEventListener('keydown', reveal)
      clearTimeout(timeout)
    }
  }, [mode])

  const handleGrade = useCallback(
    (cardId: string, grade: number) => {
      window.api.gradeCard(cardId, grade).then(() => refreshData())
    },
    [refreshData]
  )

  const saveConfig = useCallback((patch: Partial<AppConfig>) => {
    window.api.saveConfig(patch).then(setConfig)
  }, [])

  const onSync = useCallback(() => {
    // Optimistic: flip to in-progress immediately so the SyncButton spins.
    setSync((s) => ({ ...s, inProgress: true, lastError: null, phase: 'listing' }))
    window.api.syncNow().then(() => refreshData())
  }, [refreshData])

  const changeMode = useCallback((m: AppMode) => {
    setMode(m)
    window.api.setFullscreen(m === 'ambient')
  }, [])

  // ── Background schedulers ──
  // The Tauri core is event-driven; the webview owns all timing: periodic
  // sync, quiz nudges, idle → ambient, and display keep-awake.
  useEffect(() => {
    if (!config?.configured) return
    // First sync shortly after launch (don't block first paint).
    const first = setTimeout(() => onSync(), 1500)
    const minutes = Math.max(1, config.syncIntervalMinutes || 5)
    const iv = setInterval(() => onSync(), minutes * 60000)
    return () => {
      clearTimeout(first)
      clearInterval(iv)
    }
  }, [config?.configured, config?.syncIntervalMinutes, onSync])

  // Quiz nudge — only outside ambient and only when there are cards to quiz.
  useEffect(() => {
    if (!config?.configured) return
    const minutes = Math.max(5, config.quizIntervalMinutes || 30)
    const iv = setInterval(() => {
      if (mode !== 'ambient' && cards.length > 0) triggerQuiz()
    }, minutes * 60000)
    return () => clearInterval(iv)
  }, [config?.configured, config?.quizIntervalMinutes, mode, cards.length, triggerQuiz])

  // Idle watcher: auto-enter ambient after the threshold, return on activity.
  const autoEntered = useRef(false)
  useEffect(() => {
    if (!config?.configured || !config.autoAmbientOnIdle) return
    const iv = setInterval(async () => {
      const idle = await window.api.getIdleSeconds().catch(() => 0)
      const threshold = Math.max(1, config.idleThresholdMinutes || 5) * 60
      if (idle >= threshold && mode !== 'ambient' && cards.length > 0) {
        autoEntered.current = true
        changeMode('ambient')
      } else if (idle < 5 && autoEntered.current && mode === 'ambient') {
        autoEntered.current = false
        changeMode('dashboard')
      }
    }, 30000)
    return () => clearInterval(iv)
  }, [config?.configured, config?.autoAmbientOnIdle, config?.idleThresholdMinutes, mode, cards.length, changeMode])

  // Keep the display awake during ambient review (when enabled).
  useEffect(() => {
    window.api.setKeepAwake(mode === 'ambient' && !!config?.keepAwakeInAmbient)
    return () => window.api.setKeepAwake(false)
  }, [mode, config?.keepAwakeInAmbient])

  // Tray "Sync Now" clicks.
  useEffect(() => window.api.onTraySync(() => onSync()), [onSync])

  const tweaks = useMemo(
    () => ({
      fontSize: config?.fontSize ?? 26,
      animSpeed: config?.animSpeed ?? 'normal',
      cardDuration: config?.ambientCardSeconds ?? 20,
      enableRephrase: config?.enableRephrase ?? true
    }),
    [config?.fontSize, config?.animSpeed, config?.ambientCardSeconds, config?.enableRephrase]
  )

  if (!config) {
    return <div style={appStyles.root} />
  }

  if (!config.configured) {
    return <Setup config={config} onComplete={(patch) => saveConfig(patch)} />
  }

  // The rail always floats over the content (no layout shift); it's visible only
  // when opened *and* the UI hasn't faded out.
  const railVisible = navOpen && uiVisible

  return (
    <div style={appStyles.root}>
      <div style={appStyles.main}>
        {mode === 'ambient' && (
          <AmbientMode feed={reviewFeed} tweaks={tweaks} sync={sync} onSync={onSync} onTriggerQuiz={triggerQuiz} />
        )}
        {mode === 'dashboard' && <Dashboard stats={stats} sync={sync} onSync={onSync} />}
        {mode === 'images' && <ImageReview />}
        {mode === 'settings' && <Settings config={config} onChange={saveConfig} sync={sync} onSync={onSync} />}
      </div>

      {/* Invisible top strip that lets the frameless window be dragged. */}
      {mode !== 'ambient' && (
        <div data-tauri-drag-region style={{ position: 'fixed', top: 0, left: 0, right: 0, height: 26, zIndex: 40 }} />
      )}

      {/* Frameless window controls — fade with the rest of the UI. */}
      {mode !== 'ambient' && (
        <div
          style={{
            ...appStyles.winControls,
            opacity: uiVisible ? 1 : 0,
            pointerEvents: uiVisible ? 'auto' : 'none',
            transition: 'opacity 0.3s var(--ease-out)'
          }}
          className="no-drag"
        >
          <WinBtn icon={ICONS.minimize} label="Minimize" onClick={() => window.api.minimizeWindow()} />
          <WinBtn icon={ICONS.x} label="Close to tray" onClick={() => window.api.hideWindow()} />
        </div>
      )}

      {/* Floating toggle — available on every screen, auto-hides after a few
          seconds, reappears on mouse/keyboard activity. Opens/closes the rail. */}
      <button
        onClick={() => setNavOpen((o) => !o)}
        title={navOpen ? 'Hide menu' : 'Show menu'}
        className="no-drag glass"
        style={{
          ...appStyles.expandHandle,
          opacity: uiVisible && !navOpen ? 1 : 0,
          pointerEvents: uiVisible && !navOpen ? 'auto' : 'none',
          transition: 'opacity 0.3s var(--ease-out)'
        }}
      >
        <Svg markup={ICONS.menu} />
      </button>

      {/* Side navigation */}
      <div
        className="glass"
        style={{
          ...appStyles.nav,
          opacity: railVisible ? 1 : 0,
          pointerEvents: railVisible ? 'auto' : 'none',
          transform: railVisible ? 'translateX(0)' : 'translateX(-16px)'
        }}
      >
        <div style={appStyles.navLogo}>
          <span style={{ fontSize: 16, fontWeight: 800, color: 'var(--accent)' }}>N</span>
        </div>
        <div style={{ display: 'flex', flexDirection: 'column', gap: 8, flex: 1 }}>
          <NavButton icon={ICONS.ambient} label="Ambient" active={mode === 'ambient'} onClick={() => changeMode('ambient')} />
          <NavButton icon={ICONS.dashboard} label="Dashboard" active={mode === 'dashboard'} onClick={() => changeMode('dashboard')} />
          <NavButton icon={ICONS.image} label="Card Images" active={mode === 'images'} onClick={() => changeMode('images')} />
          <NavButton icon={ICONS.settings} label="Settings" active={mode === 'settings'} onClick={() => changeMode('settings')} />
        </div>
        <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
          <NavButton icon={ICONS.quiz} label="Quick Quiz" active={false} onClick={triggerQuiz} />
          <NavButton icon={ICONS.collapse} label="Hide menu" active={false} onClick={() => setNavOpen(false)} />
        </div>
      </div>

      {quizCard && (
        <QuizInterrupt card={quizCard} onGrade={handleGrade} onDismiss={() => setQuizCard(null)} tweaks={tweaks} />
      )}

      <Toast />
    </div>
  )
}

function NavButton({
  icon,
  label,
  active,
  onClick
}: {
  icon: string
  label: string
  active: boolean
  onClick: () => void
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
        position: 'relative',
        width: 40,
        height: 40,
        borderRadius: 12,
        border: 'none',
        cursor: 'pointer',
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        background: active ? 'var(--accent-dim)' : hov ? 'var(--bg-hover)' : 'transparent',
        color: active ? 'var(--accent)' : hov ? 'var(--text-primary)' : 'var(--text-tertiary)',
        transition: 'background 0.2s var(--ease-out), color 0.2s var(--ease-out)'
      }}
    >
      <Svg markup={icon} />
      {active && (
        <span
          style={{
            position: 'absolute',
            left: -4,
            top: '50%',
            transform: 'translateY(-50%)',
            width: 3,
            height: 16,
            borderRadius: 2,
            background: 'var(--accent)'
          }}
        />
      )}
    </button>
  )
}

function WinBtn({ icon, label, onClick }: { icon: string; label: string; onClick: () => void }): JSX.Element {
  const [hov, setHov] = useState(false)
  return (
    <button
      onClick={onClick}
      onMouseEnter={() => setHov(true)}
      onMouseLeave={() => setHov(false)}
      title={label}
      style={{
        width: 32,
        height: 32,
        borderRadius: 8,
        border: 'none',
        cursor: 'pointer',
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        background: hov ? 'var(--bg-hover)' : 'transparent',
        color: hov ? 'var(--text-primary)' : 'var(--text-tertiary)',
        transition: 'background 0.15s var(--ease-out), color 0.15s var(--ease-out)'
      }}
    >
      <Svg markup={icon} />
    </button>
  )
}

const appStyles: Record<string, CSSProperties> = {
  root: {
    width: '100vw',
    height: '100vh',
    overflow: 'hidden',
    background: 'var(--bg-deep)',
    color: 'var(--text-primary)',
    display: 'flex',
    position: 'relative'
  },
  main: { flex: 1, height: '100vh' },
  nav: {
    position: 'fixed',
    left: 12,
    top: 12,
    bottom: 12,
    width: 60,
    display: 'flex',
    flexDirection: 'column',
    alignItems: 'center',
    padding: '16px 0',
    zIndex: 50,
    borderRadius: 'var(--radius-xl)',
    boxShadow: 'var(--shadow-lg)',
    transition: 'opacity 0.32s var(--spring), transform 0.32s var(--spring)'
  },
  navLogo: {
    width: 36,
    height: 36,
    borderRadius: 10,
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'center',
    background: 'var(--accent-dim)',
    marginBottom: 24
  },
  winControls: {
    position: 'fixed',
    top: 10,
    right: 12,
    display: 'flex',
    gap: 4,
    zIndex: 60
  },
  expandHandle: {
    position: 'fixed',
    top: 12,
    left: 12,
    width: 38,
    height: 38,
    borderRadius: 'var(--radius-md)',
    color: 'var(--text-secondary)',
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'center',
    cursor: 'pointer',
    boxShadow: 'var(--shadow-sm)',
    zIndex: 60
  }
}
