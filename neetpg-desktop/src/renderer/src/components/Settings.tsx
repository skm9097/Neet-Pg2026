import { useState, useEffect, CSSProperties, ReactNode } from 'react'
import type { AppConfig, SyncStatus } from '../types'
import { SyncButton } from './ui'

export function Settings({
  config,
  onChange,
  sync,
  onSync
}: {
  config: AppConfig
  onChange: (patch: Partial<AppConfig>) => void
  sync?: SyncStatus
  onSync?: () => void
}): JSX.Element {
  const [local, setLocal] = useState<AppConfig>(config)
  const [ghResult, setGhResult] = useState<{ ok: boolean; message: string } | null>(null)
  const [groqResult, setGroqResult] = useState<{ ok: boolean; message: string } | null>(null)
  const [geminiResult, setGeminiResult] = useState<{ ok: boolean; message: string } | null>(null)
  const [testing, setTesting] = useState<'gh' | 'groq' | 'gemini' | null>(null)

  const update = <K extends keyof AppConfig>(key: K, val: AppConfig[K]): void => {
    setLocal((s) => ({ ...s, [key]: val }))
    onChange({ [key]: val } as Partial<AppConfig>)
  }

  const testGithub = async (): Promise<void> => {
    setTesting('gh')
    setGhResult(null)
    const r = await window.api.testGithub()
    setGhResult(r)
    setTesting(null)
  }

  const testGroq = async (): Promise<void> => {
    setTesting('groq')
    setGroqResult(null)
    const r = await window.api.testGroq()
    setGroqResult(r)
    setTesting(null)
  }

  const testGemini = async (): Promise<void> => {
    setTesting('gemini')
    setGeminiResult(null)
    const r = await window.api.testGemini()
    setGeminiResult(r)
    setTesting(null)
  }

  return (
    <div style={styles.container}>
      <div style={styles.inner}>
        <h1 style={styles.title}>Settings</h1>
        <p style={styles.subtitle}>Configure sync, display, review, AI, and system behaviour</p>

        <Section title="GitHub Sync">
          <TextInput label="Repository owner" value={local.repoOwner} placeholder="skm9097"
            onChange={(v) => update('repoOwner', v)} />
          <TextInput label="Repository name" value={local.repoName} placeholder="Neet-Pg2026"
            onChange={(v) => update('repoName', v)} />
          <TextInput label="Branch" value={local.repoBranch} placeholder="main"
            onChange={(v) => update('repoBranch', v)} />
          <TextInput label="Personal Access Token" value={local.githubPat} placeholder="ghp_xxxxxxxxxxxx" type="password"
            onChange={(v) => update('githubPat', v)} />
          <Range label="Sync interval" value={local.syncIntervalMinutes} min={1} max={30} unit="min"
            onChange={(v) => update('syncIntervalMinutes', v)} />
          <TestRow label={testing === 'gh' ? 'Testing…' : 'Test connection'} onClick={testGithub}
            disabled={testing !== null} result={ghResult} />
        </Section>

        <Section title="Ambient Display">
          <Range label="Card duration" value={local.ambientCardSeconds} min={5} max={120} unit="sec"
            onChange={(v) => update('ambientCardSeconds', v)} />
          <Range label="Font size" value={local.fontSize} min={16} max={40} unit="px"
            onChange={(v) => update('fontSize', v)} />
          <Segmented label="Animation speed" value={local.animSpeed}
            options={[{ value: 'slow', label: 'Slow' }, { value: 'normal', label: 'Normal' }, { value: 'fast', label: 'Fast' }]}
            onChange={(v) => update('animSpeed', v as AppConfig['animSpeed'])} />
          <ColorPick label="Accent colour" value={local.accentHue}
            options={['blue', 'teal', 'violet', 'amber']}
            onChange={(v) => update('accentHue', v as AppConfig['accentHue'])} />
          <Segmented label="Background" value={local.themeVariant}
            options={[{ value: 'midnight', label: 'Midnight' }, { value: 'charcoal', label: 'Charcoal' }, { value: 'navy', label: 'Navy' }]}
            onChange={(v) => update('themeVariant', v as AppConfig['themeVariant'])} />
        </Section>

        <Section title="AI Visuals (Card Images)">
          <Toggle label="Generate an infographic image for each card" value={local.enableCardImages}
            onChange={(v) => update('enableCardImages', v)} />
          <Segmented label="Image source" value={local.imageProvider}
            options={[
              { value: 'gemini-web', label: 'Gemini (sign in)' },
              { value: 'gemini', label: 'API key' },
              { value: 'pollinations', label: 'Free (no key)' }
            ]}
            onChange={(v) => update('imageProvider', v as AppConfig['imageProvider'])} />

          {local.imageProvider === 'gemini-web' && <GeminiWebAuth />}

          {local.imageProvider === 'gemini' && (
            <>
              <TextInput label="Gemini API key" value={local.geminiApiKey} placeholder="AIza…" type="password"
                onChange={(v) => update('geminiApiKey', v)} />
              <TextInput label="Gemini image model" value={local.geminiImageModel} placeholder="gemini-2.5-flash-image"
                onChange={(v) => update('geminiImageModel', v)} />
            </>
          )}

          <TestRow label={testing === 'gemini' ? 'Testing…' : 'Test image source'} onClick={testGemini}
            disabled={testing !== null} result={geminiResult} />
          <div style={{ fontSize: 12, color: 'var(--text-tertiary)', lineHeight: 1.6, marginTop: 4 }}>
            Each card’s visual is generated once from its deck data and cached on disk (tagged by question), so it isn’t
            re-created every time. <b>Gemini (sign in)</b> drives the Gemini website with your own Google account — no
            API key or billing. <b>API key</b> uses the Gemini image API directly. <b>Free</b> uses Pollinations with no
            key. Turn the toggle off to show a plain placeholder instead.
          </div>
        </Section>

        <Section title="Quiz & Review">
          <Range label="Quiz interval" value={local.quizIntervalMinutes} min={5} max={120} unit="min"
            onChange={(v) => update('quizIntervalMinutes', v)} />
          <Range label="Daily card target" value={local.cardsPerDayTarget} min={10} max={200} unit="cards"
            onChange={(v) => update('cardsPerDayTarget', v)} />
          <Range label="Idle threshold" value={local.idleThresholdMinutes} min={1} max={30} unit="min"
            onChange={(v) => update('idleThresholdMinutes', v)} />
        </Section>

        <Section title="AI Features (Groq)">
          <TextInput label="Groq API Key" value={local.groqApiKey} placeholder="gsk_xxxxxxxxxxxx" type="password"
            onChange={(v) => update('groqApiKey', v)} />
          <Toggle label="Generate mnemonics for repeated mistakes" value={local.enableMnemonics}
            onChange={(v) => update('enableMnemonics', v)} />
          <Toggle label="Rephrase questions as clinical scenarios" value={local.enableRephrase}
            onChange={(v) => update('enableRephrase', v)} />
          <TestRow label={testing === 'groq' ? 'Testing…' : 'Test Groq key'} onClick={testGroq}
            disabled={testing !== null} result={groqResult} />
        </Section>

        <Section title="System & Permissions">
          <Toggle label="Start automatically when Windows boots" value={local.startOnBoot}
            onChange={(v) => update('startOnBoot', v)} />
          <Toggle label="Keep running in the tray when window is closed" value={local.minimizeToTray}
            onChange={(v) => update('minimizeToTray', v)} />
          <Toggle label="Show ambient mode automatically when idle" value={local.autoAmbientOnIdle}
            onChange={(v) => update('autoAmbientOnIdle', v)} />
          <Toggle label="Keep the screen awake during ambient mode" value={local.keepAwakeInAmbient}
            onChange={(v) => update('keepAwakeInAmbient', v)} />
          <div style={{ fontSize: 12, color: 'var(--text-tertiary)', lineHeight: 1.6, marginTop: 4 }}>
            “Start on boot” registers a Windows login item. “Keep screen awake” uses a power-save blocker so your
            review stays visible all day — turn it off if you’d rather let the monitor sleep.
          </div>
        </Section>

        <div style={{ height: 40 }} />
      </div>
    </div>
  )
}

function GeminiWebAuth(): JSX.Element {
  const [status, setStatus] = useState<{ signedIn: boolean; message: string } | null>(null)
  const [busy, setBusy] = useState(false)

  const refresh = async (): Promise<void> => setStatus(await window.api.geminiWebStatus())
  useEffect(() => {
    refresh()
  }, [])

  const signIn = async (): Promise<void> => {
    setBusy(true)
    await window.api.geminiWebSignIn()
    setBusy(false)
    // Poll a couple of times while the user completes login.
    setTimeout(refresh, 1500)
    setTimeout(refresh, 6000)
    setTimeout(refresh, 15000)
  }
  const signOut = async (): Promise<void> => {
    setBusy(true)
    await window.api.geminiWebSignOut()
    setBusy(false)
    refresh()
  }

  return (
    <div style={styles.field}>
      <div style={{ display: 'flex', alignItems: 'center', gap: 10, flexWrap: 'wrap' }}>
        <button onClick={signIn} disabled={busy} style={{ ...styles.testBtn, opacity: busy ? 0.6 : 1 }}>
          {busy ? 'Opening…' : status?.signedIn ? 'Re-sign in to Gemini' : 'Sign in to Gemini'}
        </button>
        {status?.signedIn && (
          <button onClick={signOut} disabled={busy} style={styles.testBtn}>
            Sign out
          </button>
        )}
        <button onClick={refresh} style={styles.testBtn}>
          Refresh
        </button>
        {status && (
          <span
            style={{
              fontSize: 13,
              fontWeight: 500,
              color: status.signedIn ? 'var(--correct)' : 'var(--text-secondary)'
            }}
          >
            {status.signedIn ? '✓ ' : ''}
            {status.message}
          </span>
        )}
      </div>
      <div style={{ fontSize: 12, color: 'var(--text-tertiary)', lineHeight: 1.6, marginTop: 8 }}>
        Opens a window to log into your Google account. The app then quietly drives the Gemini website to create each
        card’s image — generation takes a little while per card and runs in the background. Sign in once; the session is
        remembered.
      </div>
    </div>
  )
}

function Section({ title, children }: { title: string; children: ReactNode }): JSX.Element {
  return (
    <div style={styles.section}>
      <div style={styles.sectionTitle}>{title}</div>
      <div style={styles.sectionContent}>{children}</div>
    </div>
  )
}

function TextInput({
  label,
  value,
  onChange,
  placeholder,
  type = 'text'
}: {
  label: string
  value: string
  onChange: (v: string) => void
  placeholder?: string
  type?: string
}): JSX.Element {
  return (
    <div style={styles.field}>
      <label style={styles.label}>{label}</label>
      <input
        type={type}
        value={value || ''}
        placeholder={placeholder}
        onChange={(e) => onChange(e.target.value)}
        style={styles.input}
      />
    </div>
  )
}

function Range({
  label,
  value,
  min,
  max,
  unit,
  onChange
}: {
  label: string
  value: number
  min: number
  max: number
  unit: string
  onChange: (v: number) => void
}): JSX.Element {
  return (
    <div style={styles.field}>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
        <label style={styles.label}>{label}</label>
        <span style={{ fontSize: 13, fontFamily: "'JetBrains Mono', monospace", color: 'var(--accent)', fontWeight: 600 }}>
          {value} {unit}
        </span>
      </div>
      <input
        type="range"
        min={min}
        max={max}
        value={value}
        onChange={(e) => onChange(Number(e.target.value))}
        style={{ width: '100%', accentColor: 'var(--accent)', cursor: 'pointer' }}
      />
    </div>
  )
}

function Segmented({
  label,
  value,
  options,
  onChange
}: {
  label: string
  value: string
  options: { value: string; label: string }[]
  onChange: (v: string) => void
}): JSX.Element {
  return (
    <div style={styles.field}>
      <label style={styles.label}>{label}</label>
      <div style={{ display: 'flex', gap: 8 }}>
        {options.map((opt) => (
          <button
            key={opt.value}
            onClick={() => onChange(opt.value)}
            style={{
              ...styles.segBtn,
              background: value === opt.value ? 'var(--accent-dim)' : 'var(--bg-hover)',
              color: value === opt.value ? 'var(--accent)' : 'var(--text-secondary)',
              borderColor: value === opt.value ? 'var(--accent)' : 'transparent'
            }}
          >
            {opt.label}
          </button>
        ))}
      </div>
    </div>
  )
}

const ACCENT_SWATCH: Record<string, string> = {
  blue: '#6b8cef',
  teal: '#5bb8c4',
  violet: '#9b7ce8',
  amber: '#e0a84c'
}

function ColorPick({
  label,
  value,
  options,
  onChange
}: {
  label: string
  value: string
  options: string[]
  onChange: (v: string) => void
}): JSX.Element {
  return (
    <div style={styles.field}>
      <label style={styles.label}>{label}</label>
      <div style={{ display: 'flex', gap: 10 }}>
        {options.map((opt) => (
          <button
            key={opt}
            onClick={() => onChange(opt)}
            title={opt}
            style={{
              width: 32,
              height: 32,
              borderRadius: 8,
              border: value === opt ? '2px solid var(--text-primary)' : '2px solid transparent',
              background: ACCENT_SWATCH[opt],
              cursor: 'pointer'
            }}
          />
        ))}
      </div>
    </div>
  )
}

function Toggle({
  label,
  value,
  onChange
}: {
  label: string
  value: boolean
  onChange: (v: boolean) => void
}): JSX.Element {
  return (
    <div style={{ ...styles.field, flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center' }}>
      <label style={{ ...styles.label, marginBottom: 0 }}>{label}</label>
      <button
        onClick={() => onChange(!value)}
        style={{
          width: 44,
          height: 24,
          borderRadius: 12,
          border: 'none',
          cursor: 'pointer',
          background: value ? 'var(--accent)' : 'var(--bg-active)',
          position: 'relative',
          transition: 'background 0.2s ease',
          flexShrink: 0
        }}
      >
        <span
          style={{
            position: 'absolute',
            top: 3,
            left: value ? 23 : 3,
            width: 18,
            height: 18,
            borderRadius: '50%',
            background: '#fff',
            transition: 'left 0.2s ease',
            boxShadow: '0 1px 3px rgba(0,0,0,0.3)'
          }}
        />
      </button>
    </div>
  )
}

function TestRow({
  label,
  onClick,
  disabled,
  result
}: {
  label: string
  onClick: () => void
  disabled: boolean
  result: { ok: boolean; message: string } | null
}): JSX.Element {
  return (
    <div style={{ display: 'flex', alignItems: 'center', gap: 14, flexWrap: 'wrap' }}>
      <button onClick={onClick} disabled={disabled} style={{ ...styles.testBtn, opacity: disabled ? 0.6 : 1 }}>
        {label}
      </button>
      {result && (
        <span style={{ fontSize: 13, color: result.ok ? 'var(--correct)' : 'var(--wrong)', fontWeight: 500 }}>
          {result.ok ? '✓ ' : '✕ '}
          {result.message}
        </span>
      )}
    </div>
  )
}

const styles: Record<string, CSSProperties> = {
  container: { width: '100%', height: '100%', overflow: 'auto', padding: '32px 40px' },
  inner: { maxWidth: 660 },
  title: { fontSize: 26, fontWeight: 700, color: 'var(--text-primary)', margin: 0, lineHeight: 1 },
  subtitle: { fontSize: 14, color: 'var(--text-secondary)', marginTop: 8, marginBottom: 8 },
  section: { marginTop: 32 },
  sectionTitle: {
    fontSize: 13,
    fontWeight: 600,
    letterSpacing: '0.05em',
    textTransform: 'uppercase',
    color: 'var(--text-tertiary)',
    marginBottom: 16,
    paddingBottom: 8,
    borderBottom: '1px solid var(--border-subtle)'
  },
  sectionContent: { display: 'flex', flexDirection: 'column', gap: 20 },
  field: { display: 'flex', flexDirection: 'column', gap: 6 },
  label: { fontSize: 14, color: 'var(--text-primary)', fontWeight: 500, marginBottom: 2 },
  input: {
    padding: '10px 14px',
    borderRadius: 10,
    border: '1.5px solid var(--border)',
    background: 'var(--bg-card)',
    color: 'var(--text-primary)',
    fontSize: 14,
    outline: 'none',
    fontFamily: "'Plus Jakarta Sans', sans-serif",
    transition: 'border-color 0.2s'
  },
  segBtn: {
    padding: '8px 16px',
    borderRadius: 8,
    border: '1.5px solid transparent',
    fontSize: 13,
    fontWeight: 600,
    cursor: 'pointer',
    transition: 'all 0.15s ease'
  },
  testBtn: {
    padding: '9px 20px',
    borderRadius: 10,
    border: '1.5px solid var(--border)',
    background: 'var(--bg-card)',
    color: 'var(--text-primary)',
    fontSize: 13,
    fontWeight: 600,
    cursor: 'pointer'
  }
}
