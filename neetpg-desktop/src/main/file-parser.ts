import type { MistakeCard, Attempt } from '../shared/types'

/**
 * Parses a mistake `.md` file (YAML frontmatter + markdown body) into a
 * MistakeCard. The file format is the one the Android app writes — see
 * NEETPGLEARNINGLOOPSPEC. We deliberately avoid gray-matter/js-yaml and parse
 * the known, simple frontmatter shape directly to keep the dependency tree tiny.
 */
export function parseMistakeFile(
  raw: string,
  filePath: string,
  blobSha: string
): MistakeCard | null {
  try {
    const { frontmatter, body } = splitFrontmatter(raw)

    const id = (frontmatter.id || idFromPath(filePath) || '').trim()
    if (!id) return null

    const subject = (frontmatter.subject || subjectFromPath(filePath) || 'general').trim()
    const keyFact = extractSection(body, 'Key Fact')
    const whyWrong = extractSection(body, 'Why You Got It Wrong')

    return {
      id,
      subject,
      topic: (frontmatter.topic || subject).trim(),
      sourceFile: (frontmatter.source_file || '').trim(),
      tags: parseArray(frontmatter.tags),
      errorType: normalizeErrorType(frontmatter.error_type),
      firstWrong: (frontmatter.first_wrong || '').trim(),
      lastWrong: (frontmatter.last_wrong || '').trim(),
      timesWrong: toInt(frontmatter.times_wrong),
      timesCorrect: toInt(frontmatter.times_correct),
      isResolved: toBool(frontmatter.is_resolved),

      question: extractSection(body, 'Question'),
      options: extractOptions(body),
      userAnswer: extractSection(body, 'Your Answer'),
      correctAnswer: extractSection(body, 'Correct Answer'),
      keyFact,
      whyWrong,
      attempts: extractAttempts(body),

      factHeading: deriveHeading(frontmatter.topic || subject, keyFact),
      factPoints: deriveBullets(keyFact),

      filePath,
      lastModified: blobSha,

      // SR fields are joined in later from the SR store; defaults here.
      srStatus: 'new',
      nextReview: ''
    }
  } catch {
    return null
  }
}

// ── Frontmatter ──────────────────────────────────────────────────────────────

function splitFrontmatter(raw: string): { frontmatter: Record<string, string>; body: string } {
  const fm: Record<string, string> = {}
  const text = raw.replace(/^﻿/, '') // strip BOM
  const match = text.match(/^---\s*\n([\s\S]*?)\n---\s*\n?([\s\S]*)$/)
  if (!match) return { frontmatter: fm, body: text }

  const [, yaml, body] = match
  for (const line of yaml.split('\n')) {
    const m = line.match(/^([a-zA-Z0-9_]+):\s*(.*)$/)
    if (m) fm[m[1]] = m[2].trim()
  }
  return { frontmatter: fm, body }
}

function parseArray(val: string | undefined): string[] {
  if (!val) return []
  const inner = val.replace(/^\[/, '').replace(/\]$/, '').trim()
  if (!inner) return []
  return inner
    .split(',')
    .map((s) => s.trim().replace(/^["']|["']$/g, ''))
    .filter(Boolean)
}

function normalizeErrorType(val: string | undefined): MistakeCard['errorType'] {
  const v = (val || '').trim().toLowerCase()
  if (v === 'conceptual' || v === 'recall' || v === 'silly') return v
  return ''
}

function toInt(val: string | undefined): number {
  const n = parseInt((val || '').trim(), 10)
  return Number.isFinite(n) ? n : 0
}

function toBool(val: string | undefined): boolean {
  return (val || '').trim().toLowerCase() === 'true'
}

// ── Body sections ──────────────────────────────────────────────────────────

/** Text between `## SectionName ...` and the next `## ` heading. */
export function extractSection(body: string, name: string): string {
  // IMPORTANT: no `m` flag. With multiline, `$` matches at the first blank
  // line and the lazy capture returns empty — which silently blanked every
  // section. `(?:^|\n)` lets the heading match at the start of any line, while
  // `$` (no `m`) only matches the true end of the string for the last section.
  const re = new RegExp(`(?:^|\\n)##\\s+${escapeRe(name)}[^\\n]*\\n([\\s\\S]*?)(?=\\n##\\s|$)`)
  const m = body.match(re)
  if (!m) return ''
  return m[1].trim()
}

function extractOptions(body: string): string[] {
  const section = extractSection(body, 'Options')
  if (!section) return []
  return section
    .split('\n')
    .map((l) => l.trim())
    .filter((l) => /^-\s*[A-D][.)]/.test(l))
    .map((l) => l.replace(/^-\s*/, '').trim())
}

function extractAttempts(body: string): Attempt[] {
  const section = extractSection(body, 'Attempts')
  if (!section) return []
  const rows = section.split('\n').map((l) => l.trim())
  const out: Attempt[] = []
  for (const row of rows) {
    if (!row.startsWith('|')) continue
    const cells = row
      .split('|')
      .slice(1, -1)
      .map((c) => c.trim())
    // header row / separator row guards
    if (cells.length < 6) continue
    if (cells[0] === '#' || /^[-:]+$/.test(cells[0])) continue
    out.push({
      date: cells[1] || '',
      answer: cells[2] || '',
      correct: cells[3]?.includes('✅') || cells[3]?.toLowerCase().includes('correct') || false,
      timeTaken: cells[4] || '',
      context: cells[5] || ''
    })
  }
  return out
}

// ── Derived display helpers ─────────────────────────────────────────────────

function deriveHeading(topic: string | undefined, keyFact: string): string {
  const t = (topic || '').trim()
  if (t && t.toLowerCase() !== 'general') {
    // "autonomic-nervous-system" -> "Autonomic Nervous System"
    return t
      .replace(/[-_]/g, ' ')
      .replace(/\s+/g, ' ')
      .replace(/\b\w/g, (c) => c.toUpperCase())
  }
  // Fall back to the first sentence of the key fact.
  const first = keyFact.split(/(?<=[.!?])\s/)[0]
  return first ? first.slice(0, 70) : 'Key Fact'
}

/**
 * Break a key-fact paragraph into a few short, scannable bullets. Respects
 * explicit markdown bullets/newlines; otherwise splits on sentences. Capped at
 * 4 to keep the ambient slide light on text (per the user's request).
 */
function deriveBullets(keyFact: string): string[] {
  if (!keyFact) return []
  let parts = keyFact
    .split('\n')
    .map((l) => l.replace(/^[-*•]\s*/, '').trim())
    .filter(Boolean)
  if (parts.length <= 1) {
    parts = keyFact
      .split(/(?<=[.!?])\s+/)
      .map((s) => s.trim())
      .filter((s) => s.length > 2)
  }
  return parts.slice(0, 4)
}

// ── Path fallbacks ───────────────────────────────────────────────────────────

function idFromPath(filePath: string): string {
  const m = filePath.match(/_([A-Za-z0-9_-]+)\.md$/)
  return m ? m[1] : ''
}

function subjectFromPath(filePath: string): string {
  const m = filePath.match(/mistakes\/([^/]+)\//)
  return m ? m[1] : ''
}

function escapeRe(s: string): string {
  return s.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')
}
