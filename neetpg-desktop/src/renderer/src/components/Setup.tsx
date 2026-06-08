import { useState, CSSProperties, ReactNode } from 'react'
import type { AppConfig } from '../types'
import { Button } from './ui'

const STEPS = ['Welcome', 'Repository', 'Access', 'AI keys'] as const

export function Setup({
  config,
  onComplete
}: {
  config: AppConfig
  onComplete: (cfg: Partial<AppConfig>) => void
}): JSX.Element {
  const [step, setStep] = useState(0)
  const [dir, setDir] = useState<1 | -1>(1)
  const [owner, setOwner] = useState(config.repoOwner)
  const [name, setName] = useState(config.repoName)
  const [branch, setBranch] = useState(config.repoBranch || 'main')
  const [pat, setPat] = useState(config.githubPat)
  const [groq, setGroq] = useState(config.groqApiKey)
  const [gemini, setGemini] = useState(config.geminiApiKey)
  const [testing, setTesting] = useState(false)
  const [result, setResult] = useState<{ ok: boolean; message: string } | null>(null)

  const save = (configured: boolean): void => {
    onComplete({
      repoOwner: owner.trim(),
      repoName: name.trim(),
      repoBranch: branch.trim() || 'main',
      githubPat: pat.trim(),
      groqApiKey: groq.trim(),
      geminiApiKey: gemini.trim(),
      configured
    })
  }

  const go = (next: number): void => {
    setDir(next > step ? 1 : -1)
    setResult(null)
    setStep(next)
  }

  const finish = async (): Promise<void> => {
    // Persist first so the main process tests against the entered values.
    save(false)
    setTesting(true)
    setResult(null)
    const r = await window.api.testGithub()
    setResult(r)
    setTesting(false)
    if (r.ok) save(true)
  }

  const anim = dir === 1 ? 'slideInRight' : 'slideInLeft'

  return (
    <div style={styles.container}>
      <div style={styles.card}>
        <StepDots count={STEPS.length} active={step} />

        <div key={step} style={{ animation: `${anim} 0.4s var(--spring) both`, marginTop: 28 }}>
          {step === 0 && (
            <Panel
              icon="N"
              title="Welcome to NEET PG Desktop"
              subtitle="An always-on study companion. Your phone pushes the mistakes you make; this app pulls them and keeps them in front of you all day — as an ambient review and timed quizzes."
            />
          )}

          {step === 1 && (
            <Panel icon="N" title="Connect your question bank" subtitle="Point the app at the GitHub repository that stores your mistakes.">
              <Field label="Repository owner">
                <input style={styles.input} value={owner} placeholder="skm9097" onChange={(e) => setOwner(e.target.value)} />
              </Field>
              <Field label="Repository name">
                <input style={styles.input} value={name} placeholder="Neet-Pg2026" onChange={(e) => setName(e.target.value)} />
              </Field>
              <Field label="Branch">
                <input style={styles.input} value={branch} placeholder="main" onChange={(e) => setBranch(e.target.value)} />
              </Field>
            </Panel>
          )}

          {step === 2 && (
            <Panel icon="N" title="Access token" subtitle="A GitHub Personal Access Token lets the app read your repo and sync your progress back.">
              <Field label="GitHub Personal Access Token" hint="Needs contents:read (and contents:write to sync progress back). For a public repo you can leave this blank for reads.">
                <input style={styles.input} type="password" value={pat} placeholder="ghp_xxxxxxxxxxxx" onChange={(e) => setPat(e.target.value)} />
              </Field>
            </Panel>
          )}

          {step === 3 && (
            <Panel icon="N" title="AI keys (optional)" subtitle="Add these now or later in Settings. They power mnemonics, rephrased questions and per-card visuals.">
              <Field label="Groq API key" hint="Powers mnemonics & rephrased questions.">
                <input style={styles.input} type="password" value={groq} placeholder="gsk_xxxxxxxxxxxx" onChange={(e) => setGroq(e.target.value)} />
              </Field>
              <Field label="Gemini API key" hint="Generates a cached infographic image for each card. Leave blank to use the free image source or plain placeholders.">
                <input style={styles.input} type="password" value={gemini} placeholder="AIza…" onChange={(e) => setGemini(e.target.value)} />
              </Field>
            </Panel>
          )}
        </div>

        {result && (
          <div style={{ fontSize: 13, marginTop: 16, color: result.ok ? 'var(--correct)' : 'var(--wrong)' }}>
            {result.ok ? '✓ ' : '✕ '}
            {result.message}
          </div>
        )}

        <div style={{ display: 'flex', gap: 12, marginTop: 28, alignItems: 'center' }}>
          {step > 0 && (
            <Button variant="plain" onClick={() => go(step - 1)}>
              Back
            </Button>
          )}
          <div style={{ flex: 1 }} />
          {step < STEPS.length - 1 ? (
            <>
              <Button variant="plain" onClick={() => save(true)}>
                Skip setup
              </Button>
              <Button variant="filled" disabled={step === 1 && (!owner.trim() || !name.trim())} onClick={() => go(step + 1)}>
                Continue
              </Button>
            </>
          ) : (
            <>
              <Button variant="plain" onClick={() => save(true)}>
                Finish without testing
              </Button>
              <Button variant="filled" loading={testing} disabled={!owner.trim() || !name.trim()} onClick={finish}>
                Test &amp; Finish
              </Button>
            </>
          )}
        </div>
      </div>
    </div>
  )
}

function StepDots({ count, active }: { count: number; active: number }): JSX.Element {
  return (
    <div style={{ display: 'flex', gap: 8 }}>
      {Array.from({ length: count }, (_, i) => (
        <span
          key={i}
          style={{
            height: 6,
            borderRadius: 3,
            width: i === active ? 24 : 6,
            background: i <= active ? 'var(--accent)' : 'var(--bg-active)',
            opacity: i <= active ? 1 : 0.6,
            transition: 'width 0.35s var(--spring), background 0.35s var(--ease-out)'
          }}
        />
      ))}
    </div>
  )
}

function Panel({
  icon,
  title,
  subtitle,
  children
}: {
  icon: string
  title: string
  subtitle: string
  children?: ReactNode
}): JSX.Element {
  return (
    <div>
      <div style={styles.logo}>{icon}</div>
      <h1 style={styles.title}>{title}</h1>
      <p style={styles.subtitle}>{subtitle}</p>
      {children && <div style={{ marginTop: 24 }}>{children}</div>}
    </div>
  )
}

function Field({ label, hint, children }: { label: string; hint?: string; children: JSX.Element }): JSX.Element {
  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: 6, marginBottom: 16 }}>
      <label style={{ fontSize: 14, color: 'var(--text-primary)', fontWeight: 500 }}>{label}</label>
      {children}
      {hint && <span style={{ fontSize: 11.5, color: 'var(--text-tertiary)', lineHeight: 1.5 }}>{hint}</span>}
    </div>
  )
}

const styles: Record<string, CSSProperties> = {
  container: {
    width: '100%',
    height: '100%',
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'center',
    background: 'var(--bg-deep)',
    overflow: 'auto',
    padding: 24
  },
  card: {
    width: '100%',
    maxWidth: 480,
    background: 'var(--bg-base)',
    border: '1px solid var(--border-subtle)',
    borderRadius: 'var(--radius-xl)',
    padding: '32px 36px 28px',
    boxShadow: 'var(--shadow-lg)'
  },
  logo: {
    width: 52,
    height: 52,
    borderRadius: 16,
    background: 'var(--accent-dim)',
    color: 'var(--accent)',
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'center',
    fontWeight: 800,
    fontSize: 24,
    marginBottom: 22,
    border: '1px solid color-mix(in srgb, var(--accent) 30%, transparent)'
  },
  title: { fontSize: 23, fontWeight: 800, color: 'var(--text-primary)', margin: 0, letterSpacing: '-0.02em' },
  subtitle: { fontSize: 14, color: 'var(--text-secondary)', lineHeight: 1.6, margin: '12px 0 0' },
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
