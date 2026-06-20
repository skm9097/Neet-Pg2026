import { useState, useEffect, CSSProperties, ReactNode } from 'react'
import type { AppConfig, AppInfo, SyncStatus } from '../types'
import { Button, Toggle, SegmentedControl, Surface, SyncButton, Spinner } from './ui'

export function Settings({
  config,
  onChange,
  sync,
  onSync
}: {
  config: AppConfig
  onChange: (patch: Partial<AppConfig>) => void
  sync: SyncStatus
  onSync: () => void
}): JSX.Element {
  const [local, setLocal] = useState<AppConfig>(config)
  const [ghResult, setGhResult] = useState<{ ok: boolean; message: string } | null>(null)
  const [groqResult, setGroqResult] = useState<{ ok: boolean; message: string } | null>(null)
  const [geminiResult, setGeminiResult] = useState<{ ok: boolean; message: string } | null>(null)
  const [testing, setTesting] = useState<'gh' | 'groq' | 'gemini' | null>(null)

  // Keep local state in sync if the config changes externally.
  useEffect(() => setLocal(config), [config])

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

        {/* Sync — large control at the top with live status. */}
        <div style={{ marginTop: 24 }}>
          <Surface padding={18} radius="var(--radius-lg)">
            <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', gap: 16 }}>
              <div>
                <div style={{ fontSize: 15, fontWeight: 600, color: 'var(--text-primary)' }}>Question bank</div>
                <div style={{ fontSize: 13, color: 'var(--text-secondary)', marginTop: 4 }}>
                  {sync.totalCards} cards cached locally
                  {(sync.parseErrors?.length ?? 0) > 0 && (
                    <span style={{ color: 'var(--wrong)' }}>
                      {' '}· {sync.parseErrors!.length} file{sync.parseErrors!.length === 1 ? '' : 's'} failed to parse
                    </span>
                  )}
                </div>
                {(sync.parseErrors?.length ?? 0) > 0 && (
                  <div style={{ fontSize: 11, color: 'var(--text-tertiary)', marginTop: 4, fontFamily: "'JetBrains Mono', monospace" }}>
                    {sync.parseErrors!.slice(0, 3).map((p) => (
                      <div key={p.path}>{p.path} — {p.reason}</div>
                    ))}
                  </div>
                )}
              </div>
              <SyncButton status={sync} onSync={onSync} size="lg" />
            </div>
          </Surface>
        </div>

        <Section title="GitHub Sync">
          <TextInput label="Repository owner" value={local.repoOwner} placeholder="skm9097" onChange={(v) => update('repoOwner', v)} />
          <TextInput label="Repository name" value={local.repoName} placeholder="Neet-Pg2026" onChange={(v) => update('repoName', v)} />
          <TextInput label="Branch" value={local.repoBranch} placeholder="main" onChange={(v) => update('repoBranch', v)} />
          <TextInput
            label="Personal Access Token"
            value={local.githubPat}
            placeholder="ghp_xxxxxxxxxxxx"
            type="password"
            onChange={(v) => update('githubPat', v)}
          />
          <Range label="Sync interval" value={local.syncIntervalMinutes} min={1} max={30} unit="min" onChange={(v) => update('syncIntervalMinutes', v)} />
          <TestRow label="Test connection" running={testing === 'gh'} disabled={testing !== null} onClick={testGithub} result={ghResult} />
        </Section>

        <Section title="AI Features (Groq)">
          <TextInput label="Groq API key" value={local.groqApiKey} placeholder="gsk_xxxxxxxxxxxx" type="password" onChange={(v) => update('groqApiKey', v)} />
          <Toggle label="Generate mnemonics for repeated mistakes" checked={local.enableMnemonics} onChange={(v) => update('enableMnemonics', v)} />
          <Toggle label="Rephrase questions as clinical scenarios" checked={local.enableRephrase} onChange={(v) => update('enableRephrase', v)} />
          <TestRow label="Test Groq key" running={testing === 'groq'} disabled={testing !== null} onClick={testGroq} result={groqResult} />
        </Section>

        <Section title="AI Visuals (Card Images)">
          <Toggle label="Generate an infographic image for each card" checked={local.enableCardImages} onChange={(v) => update('enableCardImages', v)} />
          <Field label="Image source">
            <SegmentedControl
              options={[
                { value: 'cloudflare', label: 'Cloudflare' },
                { value: 'gemini-web', label: 'Gemini (sign in)' },
                { value: 'gemini', label: 'Gemini key' },
                { value: 'pollinations', label: 'Free' }
              ]}
              value={local.imageProvider}
              onChange={(v) => update('imageProvider', v as AppConfig['imageProvider'])}
            />
          </Field>

          {local.imageProvider === 'cloudflare' && (
            <>
              <TextInput label="Cloudflare account ID" value={local.cfAccountId} placeholder="023e105f4ecef8ad9ca31a8372d0c353" onChange={(v) => update('cfAccountId', v.trim())} />
              <TextInput label="Cloudflare API token" value={local.cfApiToken} placeholder="Workers AI token" type="password" onChange={(v) => update('cfApiToken', v.trim())} />
              <TextInput label="Model" value={local.cfImageModel} placeholder="@cf/black-forest-labs/flux-1-schnell" onChange={(v) => update('cfImageModel', v.trim())} />
              <div style={styles.hint}>
                Dashboard → Workers AI: the account ID is on the right of the overview page; create an API token with
                the <b>Workers AI → Read + Edit</b> permission. The default FLUX model is fast and included in the free
                daily allocation.
              </div>
            </>
          )}

          {local.imageProvider === 'gemini-web' && <GeminiWebAuth />}

          {local.imageProvider === 'gemini' && (
            <>
              <TextInput label="Gemini API key" value={local.geminiApiKey} placeholder="AIza…" type="password" onChange={(v) => update('geminiApiKey', v)} />
              <TextInput label="Gemini image model" value={local.geminiImageModel} placeholder="gemini-2.5-flash-image" onChange={(v) => update('geminiImageModel', v)} />
            </>
          )}

          <Range label="Images per day" value={local.imagesPerDay} min={5} max={100} unit="imgs" onChange={(v) => update('imagesPerDay', v)} />
          <Toggle label="Store generated images in the GitHub repo" checked={local.pushImagesToRepo} onChange={(v) => update('pushImagesToRepo', v)} />

          <TestRow label="Test image source" running={testing === 'gemini'} disabled={testing !== null} onClick={testGemini} result={geminiResult} />
          <div style={styles.hint}>
            Each card’s visual is generated once and cached on disk — never re-created for the same card. With repo
            storage on, images are also pushed to <b>card-images/</b> in your repo so a reinstall (or another PC)
            downloads them instead of regenerating. Generation stops at the daily budget and resumes automatically the
            next day — same if the provider reports its own limit. Check results in the <b>Card Images</b> screen.
          </div>
        </Section>

        <Section title="Display">
          <Range label="Font size" value={local.fontSize} min={16} max={40} unit="px" onChange={(v) => update('fontSize', v)} />
          <Field label="Animation speed">
            <SegmentedControl
              options={[
                { value: 'slow', label: 'Slow' },
                { value: 'normal', label: 'Normal' },
                { value: 'fast', label: 'Fast' }
              ]}
              value={local.animSpeed}
              onChange={(v) => update('animSpeed', v as AppConfig['animSpeed'])}
            />
          </Field>
          <ColorPick label="Accent colour" value={local.accentHue} options={['blue', 'teal', 'violet', 'amber']} onChange={(v) => update('accentHue', v as AppConfig['accentHue'])} />
          <Field label="Background">
            <SegmentedControl
              options={[
                { value: 'midnight', label: 'Midnight' },
                { value: 'charcoal', label: 'Charcoal' },
                { value: 'navy', label: 'Navy' }
              ]}
              value={local.themeVariant}
              onChange={(v) => update('themeVariant', v as AppConfig['themeVariant'])}
            />
          </Field>
        </Section>

        <Section title="Timing">
          <Range label="Card duration" value={local.ambientCardSeconds} min={5} max={120} unit="sec" onChange={(v) => update('ambientCardSeconds', v)} />
          <Range label="Quiz interval" value={local.quizIntervalMinutes} min={5} max={120} unit="min" onChange={(v) => update('quizIntervalMinutes', v)} />
          <Range label="Daily card target" value={local.cardsPerDayTarget} min={10} max={200} unit="cards" onChange={(v) => update('cardsPerDayTarget', v)} />
          <Range label="Idle threshold" value={local.idleThresholdMinutes} min={1} max={30} unit="min" onChange={(v) => update('idleThresholdMinutes', v)} />
        </Section>

        <Section title="System & Permissions">
          <Toggle label="Start automatically when Windows boots" checked={local.startOnBoot} onChange={(v) => update('startOnBoot', v)} />
          <Toggle label="Keep running in the tray when window is closed" checked={local.minimizeToTray} onChange={(v) => update('minimizeToTray', v)} />
          <Toggle label="Show ambient mode automatically when idle" checked={local.autoAmbientOnIdle} onChange={(v) => update('autoAmbientOnIdle', v)} />
          <Toggle label="Keep the screen awake during ambient mode" checked={local.keepAwakeInAmbient} onChange={(v) => update('keepAwakeInAmbient', v)} />
          <div style={styles.hint}>
            “Start on boot” registers a Windows login item. “Keep screen awake” uses a power-save blocker so your review
            stays visible all day — turn it off if you’d rather let the monitor sleep.
          </div>
        </Section>

        <Section title="About">
          <AboutPanel />
        </Section>

        <div style={{ height: 40 }} />
      </div>
    </div>
  )
}

function AboutPanel(): JSX.Element {
  const [info, setInfo] = useState<AppInfo | null>(null)
  useEffect(() => {
    window.api
      .getAppInfo()
      .then(setInfo)
      .catch(() => {})
  }, [])

  const rows: { label: string; value: string }[] = info
    ? [
        { label: 'Version', value: info.version },
        { label: 'Electron', value: info.electron },
        { label: 'Platform', value: info.platform }
      ]
    : []

  return (
    <Surface padding={4} radius="var(--radius-md)">
      {!info ? (
        <div style={{ padding: 16, color: 'var(--text-tertiary)', fontSize: 13 }}>Loading…</div>
      ) : (
        rows.map((r, i) => (
          <div
            key={r.label}
            style={{
              display: 'flex',
              justifyContent: 'space-between',
              alignItems: 'center',
              padding: '12px 16px',
              borderTop: i === 0 ? 'none' : '1px solid var(--border-subtle)'
            }}
          >
            <span style={{ fontSize: 14, color: 'var(--text-secondary)' }}>{r.label}</span>
            <span style={{ fontSize: 13, fontFamily: "'JetBrains Mono', monospace", color: 'var(--text-primary)', fontWeight: 600 }}>
              {r.value}
            </span>
          </div>
        ))
      )}
    </Surface>
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
        <Button variant="tinted" loading={busy} onClick={signIn}>
          {status?.signedIn ? 'Re-sign in to Gemini' : 'Sign in to Gemini'}
        </Button>
        {status?.signedIn && (
          <Button variant="plain" disabled={busy} onClick={signOut}>
            Sign out
          </Button>
        )}
        <Button variant="plain" onClick={refresh}>
          Refresh
        </Button>
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
      <div style={{ ...styles.hint, marginTop: 8 }}>
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
      <Surface padding={20} radius="var(--radius-lg)">
        <div style={styles.sectionContent}>{children}</div>
      </Surface>
    </div>
  )
}

function Field({ label, children }: { label: string; children: ReactNode }): JSX.Element {
  return (
    <div style={styles.field}>
      <label style={styles.label}>{label}</label>
      {children}
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
      <input type={type} value={value || ''} placeholder={placeholder} onChange={(e) => onChange(e.target.value)} style={styles.input} />
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
      <input type="range" min={min} max={max} value={value} onChange={(e) => onChange(Number(e.target.value))} style={{ width: '100%', accentColor: 'var(--accent)', cursor: 'pointer' }} />
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
            className="no-drag"
            style={{
              width: 32,
              height: 32,
              borderRadius: 8,
              border: value === opt ? '2px solid var(--text-primary)' : '2px solid transparent',
              background: ACCENT_SWATCH[opt],
              cursor: 'pointer',
              boxShadow: value === opt ? '0 0 0 3px var(--accent-dim)' : 'none',
              transition: 'box-shadow 0.2s var(--ease-out)'
            }}
          />
        ))}
      </div>
    </div>
  )
}

function TestRow({
  label,
  onClick,
  running,
  disabled,
  result
}: {
  label: string
  onClick: () => void
  running: boolean
  disabled: boolean
  result: { ok: boolean; message: string } | null
}): JSX.Element {
  return (
    <div style={{ display: 'flex', alignItems: 'center', gap: 14, flexWrap: 'wrap' }}>
      <Button variant="tinted" loading={running} disabled={disabled} onClick={onClick}>
        {label}
      </Button>
      {result && (
        <span style={{ display: 'inline-flex', alignItems: 'center', gap: 6, fontSize: 13, color: result.ok ? 'var(--correct)' : 'var(--wrong)', fontWeight: 500 }}>
          {result.ok ? '✓ ' : '✕ '}
          {result.message}
        </span>
      )}
      {running && !result && <Spinner size="sm" color="var(--accent)" />}
    </div>
  )
}

const styles: Record<string, CSSProperties> = {
  container: { width: '100%', height: '100%', overflow: 'auto', padding: '32px 40px' },
  inner: { maxWidth: 660 },
  title: { fontSize: 28, fontWeight: 800, color: 'var(--text-primary)', margin: 0, lineHeight: 1, letterSpacing: '-0.02em' },
  subtitle: { fontSize: 14, color: 'var(--text-secondary)', marginTop: 8, marginBottom: 8 },
  section: { marginTop: 28 },
  sectionTitle: {
    fontSize: 12,
    fontWeight: 600,
    letterSpacing: '0.08em',
    textTransform: 'uppercase',
    color: 'var(--text-tertiary)',
    marginBottom: 12,
    paddingLeft: 4
  },
  sectionContent: { display: 'flex', flexDirection: 'column', gap: 20 },
  field: { display: 'flex', flexDirection: 'column', gap: 8 },
  label: { fontSize: 14, color: 'var(--text-primary)', fontWeight: 500 },
  hint: { fontSize: 12, color: 'var(--text-tertiary)', lineHeight: 1.6, marginTop: 4 },
  input: {
    padding: '11px 14px',
    borderRadius: 'var(--radius-md)',
    border: '1.5px solid var(--border)',
    background: 'var(--material-thin)',
    color: 'var(--text-primary)',
    fontSize: 14,
    outline: 'none',
    fontFamily: 'inherit'
  }
}
