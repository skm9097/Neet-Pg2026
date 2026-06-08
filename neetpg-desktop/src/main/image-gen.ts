import {
  existsSync,
  mkdirSync,
  readFileSync,
  writeFileSync,
  readdirSync,
  statSync,
  unlinkSync
} from 'fs'
import { join } from 'path'
import { createHash } from 'crypto'
import type { AppConfig, MistakeCard } from '../shared/types'

// Bump to invalidate every cached image when the prompt logic changes
// (the version is folded into the cache key, so old PNGs are simply ignored).
const PROMPT_VERSION = 1

type ImgStatus = 'ready' | 'pending' | 'error' | 'disabled'

/**
 * Generates a per-card medical-illustration image from the card's deck data and
 * caches it on disk, so each card's visual is produced once and reused. Default
 * provider is the Gemini image model (the user's own key); a free, keyless
 * Pollinations fallback is selectable in Settings.
 *
 * Everything here is best-effort: every path fails soft and the UI falls back to
 * a tasteful placeholder. Images live in `userData/card-images/` (never in the
 * repo, never in the app bundle).
 */
export class ImageGenService {
  private dir: string
  private lastCall = 0
  private readonly minGapMs = 4000
  // De-dupe concurrent requests for the same card (ambient + prefetch can race).
  private inflight = new Map<string, Promise<string | null>>()

  constructor(
    private cfg: () => AppConfig,
    userDataDir: string
  ) {
    this.dir = join(userDataDir, 'card-images')
    if (!existsSync(this.dir)) mkdirSync(this.dir, { recursive: true })
  }

  private get on(): boolean {
    return this.cfg().enableCardImages !== false
  }

  /** A deterministic cache key from the card content that drives the visual. */
  private keyFor(card: MistakeCard): string {
    const basis = [
      PROMPT_VERSION,
      card.subject,
      card.topic,
      card.factHeading,
      card.correctAnswer,
      (card.tags || []).join(',')
    ].join('|')
    return createHash('md5').update(basis).digest('hex')
  }

  private pathFor(card: MistakeCard): string {
    return join(this.dir, `${this.keyFor(card)}.png`)
  }

  hasImage(card: MistakeCard): boolean {
    return existsSync(this.pathFor(card))
  }

  /**
   * Build a medical-illustration prompt from the card's deck data. Follows the
   * "useful medical visual" rules: name the structure, ask for a clean labelled
   * educational diagram, dark background, and explicitly no text (AI renders
   * garbled words otherwise).
   */
  buildPrompt(card: MistakeCard): string {
    const topic = (card.topic || '').replace(/[-_]/g, ' ').trim()
    const subject = (card.subject || '').replace(/[-_]/g, ' ').trim()
    const concept = stripLetter(card.correctAnswer) || card.factHeading || topic
    const heading = card.factHeading || concept || topic
    const cues = (card.tags || []).slice(0, 4).join(', ')
    return [
      `Medical educational infographic illustration of ${heading}.`,
      concept && concept.toLowerCase() !== heading.toLowerCase() ? `Key concept: ${concept}.` : '',
      topic ? `Topic: ${subject} — ${topic}.` : subject ? `Subject: ${subject}.` : '',
      cues ? `Show: ${cues}.` : '',
      'Clean labelled anatomical / clinical diagram, flat vector style, clear shapes and arrows,',
      'muted palette on a dark navy background, soft teal and slate accents, centred composition,',
      'high clarity, textbook quality.',
      'No words, no letters, no captions, no watermark, no real patient photographs.'
    ]
      .filter(Boolean)
      .join(' ')
  }

  /** Return a data URL for the card image, generating + caching on first use. */
  async getDataUrl(card: MistakeCard): Promise<{ status: ImgStatus; dataUrl: string | null }> {
    if (!this.on) return { status: 'disabled', dataUrl: null }

    const cached = this.pathFor(card)
    if (existsSync(cached)) {
      const url = this.toDataUrl(cached)
      if (url) return { status: 'ready', dataUrl: url }
    }

    const path = await this.generate(card)
    if (!path) return { status: 'error', dataUrl: null }
    const url = this.toDataUrl(path)
    return url ? { status: 'ready', dataUrl: url } : { status: 'error', dataUrl: null }
  }

  private toDataUrl(path: string): string | null {
    try {
      return `data:image/png;base64,${readFileSync(path).toString('base64')}`
    } catch {
      return null
    }
  }

  /** Generate + cache the image; returns the file path or null. De-dupes races. */
  async generate(card: MistakeCard): Promise<string | null> {
    if (!this.on) return null
    const out = this.pathFor(card)
    if (existsSync(out)) return out

    const key = this.keyFor(card)
    const existing = this.inflight.get(key)
    if (existing) return existing

    const job = this._generate(card, out).finally(() => this.inflight.delete(key))
    this.inflight.set(key, job)
    return job
  }

  private async _generate(card: MistakeCard, outPath: string): Promise<string | null> {
    const c = this.cfg()
    const prompt = this.buildPrompt(card)
    await this.throttle()
    try {
      let buf: Buffer | null = null
      if (c.imageProvider === 'pollinations') {
        buf = await this.genPollinations(prompt)
      } else {
        // Gemini (default). Needs a key — if missing, leave it to the UI to
        // prompt the user (placeholder), rather than silently switching source.
        if (!c.geminiApiKey) return null
        buf = await this.genGemini(prompt, c)
      }
      if (!buf || buf.length < 128) return null
      writeFileSync(outPath, buf)
      this.cleanup(600)
      return outPath
    } catch {
      return null
    }
  }

  // ── Gemini image models (generateContent → inline image data) ──────────────
  private async genGemini(prompt: string, c: AppConfig): Promise<Buffer | null> {
    const model = c.geminiImageModel || 'gemini-2.5-flash-image'
    if (model.startsWith('imagen')) return this.genImagen(prompt, c, model)

    const url =
      `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent` +
      `?key=${encodeURIComponent(c.geminiApiKey)}`

    // Image-capable Gemini models disagree on the required modalities: the
    // dedicated image model accepts ['IMAGE']; the *-image-generation preview
    // requires ['TEXT','IMAGE']. Try the strict one first, then the permissive.
    for (const responseModalities of [['IMAGE'], ['TEXT', 'IMAGE']]) {
      try {
        const res = await fetch(url, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            contents: [{ role: 'user', parts: [{ text: prompt }] }],
            generationConfig: { responseModalities }
          })
        })
        if (!res.ok) continue
        const data = (await res.json()) as GeminiResponse
        const parts = data?.candidates?.[0]?.content?.parts || []
        for (const part of parts) {
          const inline = part.inlineData || part.inline_data
          if (inline?.data) return Buffer.from(inline.data, 'base64')
        }
      } catch {
        // try the next modality combination
      }
    }
    return null
  }

  // ── Imagen models (predict → bytesBase64Encoded) ───────────────────────────
  private async genImagen(prompt: string, c: AppConfig, model: string): Promise<Buffer | null> {
    const url =
      `https://generativelanguage.googleapis.com/v1beta/models/${model}:predict` +
      `?key=${encodeURIComponent(c.geminiApiKey)}`
    const res = await fetch(url, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        instances: [{ prompt }],
        parameters: { sampleCount: 1, aspectRatio: '4:3' }
      })
    })
    if (!res.ok) return null
    const data = (await res.json()) as ImagenResponse
    const b64 = data?.predictions?.[0]?.bytesBase64Encoded
    return b64 ? Buffer.from(b64, 'base64') : null
  }

  // ── Pollinations (free, no key) ────────────────────────────────────────────
  private async genPollinations(prompt: string): Promise<Buffer | null> {
    const url =
      `https://image.pollinations.ai/prompt/${encodeURIComponent(prompt)}` +
      `?width=864&height=624&nologo=true`
    const res = await fetch(url)
    if (!res.ok) return null
    return Buffer.from(await res.arrayBuffer())
  }

  /** Warm the cache for upcoming cards (bounded per call to respect quotas). */
  async pregenerate(cards: MistakeCard[], max = 3): Promise<number> {
    if (!this.on) return 0
    let made = 0
    for (const card of cards) {
      if (made >= max) break
      if (this.hasImage(card)) continue
      const path = await this.generate(card)
      if (path) made++
    }
    return made
  }

  private async throttle(): Promise<void> {
    const wait = this.minGapMs - (Date.now() - this.lastCall)
    if (wait > 0) await new Promise((r) => setTimeout(r, wait))
    this.lastCall = Date.now()
  }

  /** Connectivity / key check surfaced in Settings. */
  async test(): Promise<{ ok: boolean; message: string }> {
    const c = this.cfg()
    if (c.imageProvider === 'pollinations') {
      try {
        const buf = await this.genPollinations('simple flat vector medical icon, dark background, no text')
        return buf
          ? { ok: true, message: 'Pollinations reachable (free, no key needed)' }
          : { ok: false, message: 'Pollinations did not return an image' }
      } catch (e) {
        return { ok: false, message: (e as Error).message }
      }
    }
    if (!c.geminiApiKey) return { ok: false, message: 'No Gemini API key set' }
    try {
      const buf = await this.genGemini(
        'Simple flat vector illustration of a human heart, dark background, no text',
        c
      )
      return buf && buf.length > 128
        ? { ok: true, message: `Gemini image OK (${c.geminiImageModel || 'gemini-2.5-flash-image'})` }
        : { ok: false, message: 'No image returned — check the model id, key, or quota' }
    } catch (e) {
      return { ok: false, message: (e as Error).message }
    }
  }

  /** Cap the on-disk cache, dropping the oldest images first. */
  cleanup(maxImages = 600): void {
    try {
      const files = readdirSync(this.dir)
        .filter((f) => f.endsWith('.png'))
        .map((f) => ({ path: join(this.dir, f), mtime: statSync(join(this.dir, f)).mtimeMs }))
        .sort((a, b) => b.mtime - a.mtime)
      for (const f of files.slice(maxImages)) {
        try {
          unlinkSync(f.path)
        } catch {
          /* ignore */
        }
      }
    } catch {
      /* ignore */
    }
  }
}

interface GeminiInline {
  data?: string
}
interface GeminiPart {
  inlineData?: GeminiInline
  inline_data?: GeminiInline
}
interface GeminiResponse {
  candidates?: { content?: { parts?: GeminiPart[] } }[]
}
interface ImagenResponse {
  predictions?: { bytesBase64Encoded?: string }[]
}

function stripLetter(s: string): string {
  return (s || '')
    .replace(/^[A-D][.)]\s*/, '')
    .replace(/\s*✅\s*$/, '')
    .trim()
}
