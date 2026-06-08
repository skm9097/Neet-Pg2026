import { useState, CSSProperties } from 'react'
import type { AppConfig } from '../types'

export function Setup({
  config,
  onComplete
}: {
  config: AppConfig
  onComplete: (cfg: Partial<AppConfig>) => void
}): JSX.Element {
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

  const testAndContinue = async (): Promise<void> => {
    // Persist first so the main process tests against the entered values.
    save(false)
    setTesting(true)
    setResult(null)
    const r = await window.api.testGithub()
    setResult(r)
    setTesting(false)
    if (r.ok) save(true)
  }

  return (
    <div style={styles.container}>
      <div style={styles.card}>
        <div style={styles.logo}>N</div>
        <h1 style={styles.title}>Welcome to NEET PG Desktop</h1>
        <p style={styles.subtitle}>
          Connect your question-bank repository. Your phone pushes mistakes there; this app pulls them and shows them
          to you all day.
        </p>

        <Field label="Repository owner">
          <input style={styles.input} value={owner} placeholder="skm9097" onChange={(e) => setOwner(e.target.value)} />
        </Field>
        <Field label="Repository name">
          <input style={styles.input} value={name} placeholder="Neet-Pg2026" onChange={(e) => setName(e.target.value)} />
        </Field>
        <Field label="Branch">
          <input style={styles.input} value={branch} placeholder="main" onChange={(e) => setBranch(e.target.value)} />
        </Field>
        <Field label="GitHub Personal Access Token" hint="Needs contents:read (and contents:write to sync progress back). For a public repo you can leave this blank for reads.">
          <input
            style={styles.input}
            type="password"
            value={pat}
            placeholder="ghp_xxxxxxxxxxxx"
            onChange={(e) => setPat(e.target.value)}
          />
        </Field>
        <Field label="Groq API key (optional)" hint="Powers mnemonics & rephrased questions. You can add it later in Settings.">
          <input
            style={styles.input}
            type="password"
            value={groq}
            placeholder="gsk_xxxxxxxxxxxx"
            onChange={(e) => setGroq(e.target.value)}
          />
        </Field>
        <Field label="Gemini API key (optional)" hint="Generates a cached infographic image for each card. Leave blank to use the free image source or plain placeholders — you can change this in Settings.">
          <input
            style={styles.input}
            type="password"
            value={gemini}
            placeholder="AIza…"
            onChange={(e) => setGemini(e.target.value)}
          />
        </Field>

        {result && (
          <div style={{ fontSize: 13, marginTop: 4, color: result.ok ? 'var(--correct)' : 'var(--wrong)' }}>
            {result.ok ? '✓ ' : '✕ '}
            {result.message}
          </div>
        )}

        <div style={{ display: 'flex', gap: 12, marginTop: 24 }}>
          <button onClick={testAndContinue} disabled={testing || !owner || !name} style={styles.primaryBtn}>
            {testing ? 'Connecting…' : 'Test & Continue'}
          </button>
          <button onClick={() => save(true)} style={styles.ghostBtn}>
            Skip for now
          </button>
        </div>
      </div>
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
    overflow: 'auto'
  },
  card: {
    width: '100%',
    maxWidth: 480,
    background: 'var(--bg-base)',
    border: '1px solid var(--border-subtle)',
    borderRadius: 18,
    padding: '36px 36px 32px'
  },
  logo: {
    width: 44,
    height: 44,
    borderRadius: 12,
    background: 'var(--accent-dim)',
    color: 'var(--accent)',
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'center',
    fontWeight: 800,
    fontSize: 20,
    marginBottom: 20
  },
  title: { fontSize: 22, fontWeight: 700, color: 'var(--text-primary)', margin: 0 },
  subtitle: { fontSize: 14, color: 'var(--text-secondary)', lineHeight: 1.6, margin: '10px 0 24px' },
  input: {
    padding: '10px 14px',
    borderRadius: 10,
    border: '1.5px solid var(--border)',
    background: 'var(--bg-card)',
    color: 'var(--text-primary)',
    fontSize: 14,
    outline: 'none',
    fontFamily: "'Plus Jakarta Sans', sans-serif"
  },
  primaryBtn: {
    padding: '11px 24px',
    borderRadius: 10,
    border: 'none',
    background: 'var(--accent)',
    color: '#fff',
    fontSize: 14,
    fontWeight: 600,
    cursor: 'pointer'
  },
  ghostBtn: {
    padding: '11px 20px',
    borderRadius: 10,
    border: '1.5px solid var(--border)',
    background: 'transparent',
    color: 'var(--text-secondary)',
    fontSize: 14,
    fontWeight: 500,
    cursor: 'pointer'
  }
}
