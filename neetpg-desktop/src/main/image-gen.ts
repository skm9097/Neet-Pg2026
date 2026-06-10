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
import type { AppConfig, MistakeCard, ImageQuota, ImageReport, ImageReportEntry } from '../shared/types'
import type { GeminiWebService } from './gemini-web'
import type { RepoSync } from './repo-sync'

// Bump to invalidate every cached image when the prompt logic changes
// (the version is folded into the cache key, so old PNGs are simply ignored).
const PROMPT_VERSION = 1

const DEFAULT_CF_MODEL = '@cf/black-forest-labs/flux-1-schnell'
const REPO_IMAGE_DIR = 'card-images'
const REPO_MANIFEST = `${REPO_IMAGE_DIR}/manifest.json`
// Re-read the repo manifest at most this often (it changes rarely).
const MANIFEST_TTL_MS = 10 * 60 * 1000

type ImgStatus = 'ready' | 'pending' | 'error' | 'disabled'

const localDay = (): string => {
  const d = new Date()
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`
}

/** Thrown when the provider says we've hit its generation limit. */
class RateLimitError extends Error {}

interface IndexEntry {
  file: string
  prompt: string
  at: string
  subject: string
  topic: string
  fromRepo?: boolean
}

interface QuotaFile {
  date: string
  used: number
  blockedUntil: string | null
}

interface ManifestEntry {
  key: string // cache key the image was generated for (invalidates on card change)
  file: string // filename inside card-images/
  subject: string
  topic: string
  model: string
  prompt: string
  at: string
  bytes: number
}

/**
 * Generates a per-card medical-illustration image and caches it on disk, so
 * each card's visual is produced once and reused. Default provider is
 * Cloudflare Workers AI (user's own account ID + API token); Gemini and
 * Pollinations remain selectable.
 *
 * Budgeting: at most `imagesPerDay` provider calls per local day (default 20),
 * persisted across restarts. A provider rate-limit blocks further calls until
 * the next local midnight. Generated images are also pushed to the repo under
 * `card-images/` with a manifest, so a reinstall (or another machine) fetches
 * instead of regenerating.
 */
export class ImageGenService {
  private dir: string
  private indexPath: string
  private index: Record<string, IndexEntry> = {}
  private quotaPath: string
  private quotaData: QuotaFile = { date: localDay(), used: 0, blockedUntil: null }
  private errorsPath: string
  private errors: Record<string, { at: string; message: string }> = {}
  private manifest: Record<string, ManifestEntry> | null = null
  private manifestAt = 0
  private lastCall = 0
  private readonly minGapMs = 4000
  // De-dupe concurrent requests for the same card (ambient + prefetch can race).
  private inflight = new Map<string, Promise<string | null>>()

  constructor(
    private cfg: () => AppConfig,
    userDataDir: string,
    private web: GeminiWebService,
    private repo: RepoSync
  ) {
    this.dir = join(userDataDir, 'card-images')
    if (!existsSync(this.dir)) mkdirSync(this.dir, { recursive: true })
    this.indexPath = join(this.dir, 'cache-index.json')
    this.quotaPath = join(this.dir, 'quota.json')
    this.errorsPath = join(this.dir, 'errors.json')
    this.loadIndex()
    this.loadQuota()
    this.loadErrors()
  }

  // ── Persistence ─────────────────────────────────────────────────────────────

  private loadIndex(): void {
    try {
      if (existsSync(this.indexPath)) {
        this.index = JSON.parse(readFileSync(this.indexPath, 'utf-8')) as Record<string, IndexEntry>
      }
    } catch {
      this.index = {}
    }
  }

  /** Map a card id → its cached image file + prompt, so images are tagged by question. */
  private recordIndex(card: MistakeCard, file: string, prompt: string, fromRepo = false): void {
    this.index[card.id] = {
      file: file.split(/[/\\]/).pop() || file,
      prompt,
      at: new Date().toISOString(),
      subject: card.subject,
      topic: card.topic,
      fromRepo
    }
    try {
      writeFileSync(this.indexPath, JSON.stringify(this.index, null, 2), 'utf-8')
    } catch {
      /* best-effort */
    }
  }

  private loadQuota(): void {
    try {
      if (existsSync(this.quotaPath)) {
        this.quotaData = JSON.parse(readFileSync(this.quotaPath, 'utf-8')) as QuotaFile
      }
    } catch {
      /* defaults stand */
    }
    this.rollQuotaDay()
  }

  private saveQuota(): void {
    try {
      writeFileSync(this.quotaPath, JSON.stringify(this.quotaData), 'utf-8')
    } catch {
      /* best-effort */
    }
  }

  /** New local day → reset the counter and clear any rate-limit block that expired. */
  private rollQuotaDay(): void {
    const today = localDay()
    if (this.quotaData.date !== today) {
      this.quotaData = { date: today, used: 0, blockedUntil: this.quotaData.blockedUntil }
    }
    if (this.quotaData.blockedUntil && new Date(this.quotaData.blockedUntil) <= new Date()) {
      this.quotaData.blockedUntil = null
    }
  }

  quota(): ImageQuota {
    this.rollQuotaDay()
    return {
      date: this.quotaData.date,
      used: this.quotaData.used,
      limit: Math.max(1, this.cfg().imagesPerDay || 20),
      blockedUntil: this.quotaData.blockedUntil
    }
  }

  /** null = OK to call the provider; otherwise a human-readable refusal. */
  private quotaGate(): string | null {
    const q = this.quota()
    if (q.blockedUntil) {
      return `Provider limit hit — generation resumes ${new Date(q.blockedUntil).toLocaleString()}`
    }
    if (q.used >= q.limit) {
      return `Daily budget of ${q.limit} images used — resumes tomorrow`
    }
    return null
  }

  private noteCall(): void {
    this.rollQuotaDay()
    this.quotaData.used += 1
    this.saveQuota()
  }

  /** Provider said stop: block until the next local midnight (when quota resets). */
  private noteRateLimited(): void {
    const next = new Date()
    next.setDate(next.getDate() + 1)
    next.setHours(0, 5, 0, 0)
    this.quotaData.blockedUntil = next.toISOString()
    this.saveQuota()
  }

  private loadErrors(): void {
    try {
      if (existsSync(this.errorsPath)) {
        this.errors = JSON.parse(readFileSync(this.errorsPath, 'utf-8')) as Record<
          string,
          { at: string; message: string }
        >
      }
    } catch {
      this.errors = {}
    }
  }

  private recordError(cardId: string, message: string): void {
    this.errors[cardId] = { at: new Date().toISOString(), message }
    try {
      writeFileSync(this.errorsPath, JSON.stringify(this.errors, null, 2), 'utf-8')
    } catch {
      /* best-effort */
    }
  }

  private clearError(cardId: string): void {
    if (!this.errors[cardId]) return
    delete this.errors[cardId]
    try {
      writeFileSync(this.errorsPath, JSON.stringify(this.errors, null, 2), 'utf-8')
    } catch {
      /* best-effort */
    }
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
  async getDataUrl(
    card: MistakeCard
  ): Promise<{ status: ImgStatus; dataUrl: string | null; message?: string }> {
    if (!this.on) return { status: 'disabled', dataUrl: null, message: 'Card visuals are off' }

    const cached = this.pathFor(card)
    if (existsSync(cached)) {
      const url = this.toDataUrl(cached)
      if (url) return { status: 'ready', dataUrl: url }
    }

    const path = await this.generate(card)
    if (!path) return { status: 'error', dataUrl: null, message: await this.errorHint(card) }
    const url = this.toDataUrl(path)
    return url
      ? { status: 'ready', dataUrl: url }
      : { status: 'error', dataUrl: null, message: 'Saved image could not be read' }
  }

  /** A short, provider-aware reason for a failed generation (for the placeholder). */
  private async errorHint(card?: MistakeCard): Promise<string> {
    const recorded = card && this.errors[card.id]?.message
    if (recorded) return recorded
    const gate = this.quotaGate()
    if (gate) return gate
    const c = this.cfg()
    if (c.imageProvider === 'cloudflare') {
      return c.cfAccountId && c.cfApiToken
        ? 'Cloudflare returned no image — it will retry on the next pass'
        : 'Add your Cloudflare account ID + API token in Settings → AI Visuals'
    }
    if (c.imageProvider === 'gemini-web') {
      const s = await this.web.status()
      return s.signedIn
        ? 'Gemini didn’t return an image — it will retry on the next pass'
        : 'Sign in to Gemini in Settings → AI Visuals to generate visuals'
    }
    if (c.imageProvider === 'gemini') {
      return c.geminiApiKey
        ? 'Gemini API returned no image — check the model id or quota'
        : 'Add a Gemini API key in Settings (or switch the image source)'
    }
    return 'Image source unavailable — it will retry later'
  }

  private toDataUrl(path: string): string | null {
    try {
      return `data:image/png;base64,${readFileSync(path).toString('base64')}`
    } catch {
      return null
    }
  }

  /** Generate + cache the image; returns the file path or null. De-dupes races. */
  async generate(card: MistakeCard, force = false): Promise<string | null> {
    if (!this.on) return null
    const out = this.pathFor(card)
    if (!force && existsSync(out)) return out

    const key = this.keyFor(card)
    const existing = this.inflight.get(key)
    if (existing) return existing

    const job = this._generate(card, out, force).finally(() => this.inflight.delete(key))
    this.inflight.set(key, job)
    return job
  }

  private async _generate(card: MistakeCard, outPath: string, force: boolean): Promise<string | null> {
    const c = this.cfg()
    const prompt = this.buildPrompt(card)

    // 1. Repo store first (free — no provider call): another machine or a
    //    previous install may already have generated this exact image.
    if (!force) {
      try {
        const fetched = await this.fetchFromRepo(card)
        if (fetched) {
          writeFileSync(outPath, fetched)
          this.recordIndex(card, outPath, prompt, true)
          this.clearError(card.id)
          return outPath
        }
      } catch {
        // Repo unreachable — fall through to generation.
      }
    }

    // 2. Daily budget / rate-limit gate (applies to provider calls only).
    const gate = this.quotaGate()
    if (gate) {
      this.recordError(card.id, gate)
      return null
    }

    await this.throttle()
    try {
      let buf: Buffer | null = null
      if (c.imageProvider === 'cloudflare') {
        if (!c.cfAccountId || !c.cfApiToken) {
          this.recordError(card.id, 'Cloudflare account ID / API token not set')
          return null
        }
        this.noteCall()
        buf = await this.genCloudflare(prompt, c)
      } else if (c.imageProvider === 'gemini-web') {
        // Drive the signed-in Gemini website to generate the image.
        this.noteCall()
        buf = await this.web.generate(prompt)
      } else if (c.imageProvider === 'pollinations') {
        this.noteCall()
        buf = await this.genPollinations(prompt)
      } else {
        // Gemini API. Needs a key — if missing, leave it to the UI to prompt the
        // user (placeholder), rather than silently switching source.
        if (!c.geminiApiKey) {
          this.recordError(card.id, 'Gemini API key not set')
          return null
        }
        this.noteCall()
        buf = await this.genGemini(prompt, c)
      }
      if (!buf || buf.length < 128) {
        this.recordError(card.id, 'Provider returned no image')
        return null
      }
      writeFileSync(outPath, buf)
      this.recordIndex(card, outPath, prompt)
      this.clearError(card.id)
      this.cleanup(600)
      // 3. Push to the repo store so it never has to be generated again.
      this.pushToRepo(card, buf, prompt).catch(() => {})
      return outPath
    } catch (e) {
      if (e instanceof RateLimitError) {
        this.noteRateLimited()
        this.recordError(card.id, 'Provider rate limit hit — retrying after the daily reset')
      } else {
        this.recordError(card.id, (e as Error).message || 'Generation failed')
      }
      return null
    }
  }

  // ── Cloudflare Workers AI ────────────────────────────────────────────────────
  private async genCloudflare(prompt: string, c: AppConfig): Promise<Buffer | null> {
    const model = c.cfImageModel || DEFAULT_CF_MODEL
    const url = `https://api.cloudflare.com/client/v4/accounts/${encodeURIComponent(c.cfAccountId)}/ai/run/${model}`
    // flux-1-schnell takes a steps count (max 8); SD-style models accept extras
    // but plain { prompt } works for all of them.
    const body = model.includes('flux') ? { prompt, steps: 8 } : { prompt }
    const res = await fetch(url, {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${c.cfApiToken}`,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify(body)
    })

    if (res.status === 429) throw new RateLimitError('Cloudflare rate limit (429)')
    if (!res.ok) {
      let msg = `Cloudflare ${res.status}`
      try {
        const j = (await res.json()) as { errors?: { message?: string }[] }
        msg = j?.errors?.[0]?.message || msg
      } catch {
        /* keep the status message */
      }
      // Neuron/quota exhaustion comes back as a normal error payload.
      if (/limit|quota|capacity|allocation/i.test(msg)) throw new RateLimitError(msg)
      throw new Error(msg)
    }

    const ct = res.headers.get('content-type') || ''
    if (ct.includes('application/json')) {
      // flux-1-schnell: { result: { image: "<base64>" }, success: true }
      const j = (await res.json()) as { result?: { image?: string } }
      const b64 = j?.result?.image
      return b64 ? Buffer.from(b64, 'base64') : null
    }
    // stable-diffusion models stream the PNG directly.
    return Buffer.from(await res.arrayBuffer())
  }

  // ── Repo image store (card-images/ + manifest.json) ─────────────────────────

  private async loadManifest(forceFresh = false): Promise<Record<string, ManifestEntry>> {
    if (!forceFresh && this.manifest && Date.now() - this.manifestAt < MANIFEST_TTL_MS) {
      return this.manifest
    }
    try {
      const raw = await this.repo.fetchFile(REPO_MANIFEST)
      this.manifest = JSON.parse(raw) as Record<string, ManifestEntry>
    } catch {
      // 404 (no images pushed yet) or offline — treat as empty but don't cache
      // a miss for long.
      this.manifest = this.manifest || {}
    }
    this.manifestAt = Date.now()
    return this.manifest
  }

  /** Image for this exact card content already in the repo? Fetch it. */
  private async fetchFromRepo(card: MistakeCard): Promise<Buffer | null> {
    const manifest = await this.loadManifest()
    const entry = manifest[card.id]
    if (!entry || entry.key !== this.keyFor(card)) return null
    return this.repo.fetchBinary(`${REPO_IMAGE_DIR}/${entry.file}`)
  }

  /** Push the generated PNG + updated manifest to the repo (needs a PAT). */
  private async pushToRepo(card: MistakeCard, buf: Buffer, prompt: string): Promise<void> {
    const c = this.cfg()
    if (!c.githubPat || c.pushImagesToRepo === false) return
    const safeId = card.id.replace(/[^a-zA-Z0-9_-]/g, '_')
    const file = `${safeId}.png`
    await this.repo.putFile(`${REPO_IMAGE_DIR}/${file}`, buf, `image: ${card.id} (${card.subject})`)

    const manifest = await this.loadManifest(true)
    manifest[card.id] = {
      key: this.keyFor(card),
      file,
      subject: card.subject,
      topic: card.topic,
      model: c.imageProvider === 'cloudflare' ? c.cfImageModel || DEFAULT_CF_MODEL : c.imageProvider,
      prompt,
      at: new Date().toISOString(),
      bytes: buf.length
    }
    await this.repo.putFile(REPO_MANIFEST, JSON.stringify(manifest, null, 2), `image: manifest ${card.id}`)
    this.manifest = manifest
    this.manifestAt = Date.now()
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
      if (this.quotaGate()) break // budget exhausted — stop the batch early
      if (this.hasImage(card)) continue
      const path = await this.generate(card)
      if (path) made++
    }
    return made
  }

  /** Per-card status + quota for the image review screen. */
  report(cards: MistakeCard[]): ImageReport {
    const quota = this.quota()
    const blocked = !!this.quotaGate()
    const entries: ImageReportEntry[] = cards.map((card) => {
      const ready = this.hasImage(card)
      const err = this.errors[card.id]
      const idx = this.index[card.id]
      let status: ImageReportEntry['status']
      if (ready) status = 'ready'
      else if (err) status = 'error'
      else if (blocked) status = 'blocked'
      else status = 'queued'
      return {
        cardId: card.id,
        subject: card.subject,
        topic: card.topic,
        heading: card.factHeading || card.topic || card.subject,
        status,
        error: !ready && err ? err.message : undefined,
        generatedAt: ready ? idx?.at : undefined,
        fromRepo: ready ? idx?.fromRepo : undefined
      }
    })
    const order: Record<ImageReportEntry['status'], number> = { error: 0, blocked: 1, queued: 2, ready: 3 }
    entries.sort((a, b) => order[a.status] - order[b.status] || a.cardId.localeCompare(b.cardId))
    return {
      quota,
      total: entries.length,
      ready: entries.filter((e) => e.status === 'ready').length,
      queued: entries.filter((e) => e.status === 'queued' || e.status === 'blocked').length,
      errors: entries.filter((e) => e.status === 'error').length,
      entries
    }
  }

  /** Throw away the cached image (and its error) and produce a fresh one. */
  async regenerate(card: MistakeCard): Promise<string | null> {
    const out = this.pathFor(card)
    try {
      if (existsSync(out)) unlinkSync(out)
    } catch {
      /* ignore */
    }
    this.clearError(card.id)
    return this.generate(card, true)
  }

  private async throttle(): Promise<void> {
    const wait = this.minGapMs - (Date.now() - this.lastCall)
    if (wait > 0) await new Promise((r) => setTimeout(r, wait))
    this.lastCall = Date.now()
  }

  /** Connectivity / key check surfaced in Settings. */
  async test(): Promise<{ ok: boolean; message: string }> {
    const c = this.cfg()
    if (c.imageProvider === 'cloudflare') {
      if (!c.cfAccountId || !c.cfApiToken) {
        return { ok: false, message: 'Enter your Cloudflare account ID and API token' }
      }
      try {
        // Model search validates both the token and the account without
        // spending image-generation quota.
        const res = await fetch(
          `https://api.cloudflare.com/client/v4/accounts/${encodeURIComponent(c.cfAccountId)}/ai/models/search?per_page=1`,
          { headers: { Authorization: `Bearer ${c.cfApiToken}` } }
        )
        if (res.ok) {
          return { ok: true, message: `Cloudflare OK (${c.cfImageModel || DEFAULT_CF_MODEL})` }
        }
        if (res.status === 401 || res.status === 403) {
          return { ok: false, message: 'Token rejected — check the API token and its Workers AI permission' }
        }
        if (res.status === 404) {
          return { ok: false, message: 'Account not found — check the account ID' }
        }
        return { ok: false, message: `Cloudflare returned ${res.status}` }
      } catch (e) {
        return { ok: false, message: `Network error: ${(e as Error).message}` }
      }
    }
    if (c.imageProvider === 'gemini-web') {
      const s = await this.web.status()
      return s.signedIn
        ? { ok: true, message: 'Signed in — visuals generate on the Gemini website' }
        : { ok: false, message: 'Not signed in — click “Sign in to Gemini” above' }
    }
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
