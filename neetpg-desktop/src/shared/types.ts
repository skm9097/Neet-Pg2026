// Shared types — imported by both the Electron main process and the React renderer.

// === Parsed from a mistake .md file (YAML frontmatter + markdown body) ===
export interface MistakeCard {
  id: string // "Q0247"
  subject: string // "pharmacology"
  topic: string // "autonomic-nervous-system"
  sourceFile: string // "question-bank/subject-wise/pharmacology.md"
  tags: string[] // ["cholinergic", "muscarinic", "pilocarpine"]
  errorType: 'conceptual' | 'recall' | 'silly' | ''
  firstWrong: string // ISO 8601
  lastWrong: string // ISO 8601
  timesWrong: number
  timesCorrect: number
  isResolved: boolean

  // Parsed from the markdown body
  question: string
  options: string[] // ["A) Atropine", "B) Pilocarpine ✅", ...]
  userAnswer: string // "A) Atropine"
  correctAnswer: string // "B) Pilocarpine"
  keyFact: string // LLM-generated explanation
  whyWrong: string // LLM-generated error analysis
  attempts: Attempt[]

  // Derived for nicer ambient display (computed at parse time)
  factHeading: string // a short title for the card
  factPoints: string[] // keyFact broken into scannable bullets

  // File metadata
  filePath: string // "mistakes/pharmacology/2026-06-05_Q0247.md"
  lastModified: string // blob sha or mtime for change detection

  // Spaced-repetition state (joined from the SR store at read time)
  srStatus: SRCard['status']
  nextReview: string
}

export interface Attempt {
  date: string
  answer: string
  correct: boolean
  timeTaken: string
  context: string
}

// === Spaced repetition (SM-2) ===
export interface SRCard {
  easinessFactor: number // starts at 2.5
  intervalDays: number
  repetitions: number
  nextReview: string // "2026-06-07"
  lastGrade: number // 0-5
  status: 'new' | 'learning' | 'review' | 'relearning' | 'mature'
  // ISO timestamp of the last grade — drives the per-card newest-wins merge
  // when the same SR store is updated from more than one device.
  updatedAt?: string
}

export interface SRState {
  lastUpdated: string
  cards: Record<string, SRCard>
}

export interface TopicScores {
  lastUpdated: string
  scores: Record<string, number>
}

// === Session logs (pushed by the Android app) ===
export interface SessionLog {
  sessionId: string
  type: string
  startedAt: string
  endedAt: string
  totalQuestions: number
  correct: number
  wrong: number
  skipped: number
  scorePercent: number
  subjectBreakdown: SubjectScore[]
}

export interface SubjectScore {
  subject: string
  total: number
  correct: number
  wrong: number
  skipped: number
}

// === App config / settings ===
export interface AppConfig {
  // GitHub sync
  repoOwner: string
  repoName: string
  repoBranch: string
  githubPat: string

  // AI (Groq)
  groqApiKey: string
  enableMnemonics: boolean
  enableRephrase: boolean

  // AI visuals (per-card infographic image generation)
  enableCardImages: boolean
  imageProvider: 'cloudflare' | 'gemini-web' | 'gemini' | 'pollinations'
  geminiApiKey: string
  geminiImageModel: string
  // Cloudflare Workers AI (default image source)
  cfAccountId: string
  cfApiToken: string
  cfImageModel: string
  // Daily generation budget + repo-backed image store
  imagesPerDay: number
  pushImagesToRepo: boolean

  // Timing
  syncIntervalMinutes: number
  quizIntervalMinutes: number
  idleThresholdMinutes: number
  ambientCardSeconds: number
  cardsPerDayTarget: number

  // Display
  fontSize: number
  animSpeed: 'slow' | 'normal' | 'fast'
  accentHue: 'blue' | 'teal' | 'violet' | 'amber'
  themeVariant: 'midnight' | 'charcoal' | 'navy'

  // System & permissions
  startOnBoot: boolean
  minimizeToTray: boolean
  autoAmbientOnIdle: boolean
  keepAwakeInAmbient: boolean

  // Internal — set once setup is complete
  configured: boolean
}

// === Dashboard stats payload ===
export interface DashboardStats {
  due: number
  reviewed: number
  total: number
  unresolved: number
  resolved: number
  streakDays: number
  byStatus: Record<string, number>
  topics: { name: string; total: number; wrong: number; pct: number }[]
  sessions: { date: string; score: number }[]
  stubborn: MistakeCard[]
}

// === Sync status surfaced to the UI ===
export interface SyncStatus {
  lastSync: string | null
  lastError: string | null
  inProgress: boolean
  totalCards: number
  // High-level phase for the live sync indicator in the header.
  phase?: 'idle' | 'listing' | 'fetching' | 'enriching' | 'pushing' | 'done' | 'error'
  // Mistake files that fetched but failed to parse last cycle — surfaced in
  // Settings so malformed pushes are never silently dropped.
  parseErrors?: { path: string; reason: string }[]
}

// === App / build info for the About panel ===
export interface AppInfo {
  version: string
  electron: string
  platform: string
}

// === Per-card generated infographic image (returned over IPC as a data URL) ===
export interface CardImage {
  cardId: string
  // ready = image available; pending = still generating; error = generation
  // failed (e.g. not signed in / no key / quota); disabled = card images off.
  status: 'ready' | 'pending' | 'error' | 'disabled'
  dataUrl: string | null
  // Optional human-readable reason shown on the placeholder (e.g. "sign in").
  message?: string
}

// === Daily image-generation quota (persisted; resets at local midnight) ===
export interface ImageQuota {
  date: string // local YYYY-MM-DD the counter applies to
  used: number // API calls made today
  limit: number // from config (imagesPerDay)
  blockedUntil: string | null // ISO — set when the provider rate-limits us
}

// === Per-card entry in the image review screen ===
export interface ImageReportEntry {
  cardId: string
  subject: string
  topic: string
  heading: string
  status: 'ready' | 'queued' | 'error' | 'blocked'
  error?: string // last failure reason, if any
  generatedAt?: string
  fromRepo?: boolean // true if the image was fetched from the repo, not generated
}

export interface ImageReport {
  quota: ImageQuota
  total: number
  ready: number
  queued: number
  errors: number
  entries: ImageReportEntry[]
}

export type AppMode = 'ambient' | 'dashboard' | 'images' | 'settings'

// === The typed bridge exposed on window.api by the preload script ===
export interface DesktopApi {
  getConfig(): Promise<AppConfig>
  saveConfig(patch: Partial<AppConfig>): Promise<AppConfig>
  getCards(): Promise<MistakeCard[]>
  getDueCards(limit: number): Promise<MistakeCard[]>
  // Smart-review ordered feed for ambient/quiz: due cards first, then weakest
  // topics, then most-recent mistakes, then fill. Never empty if any card exists.
  getReviewFeed(limit: number): Promise<MistakeCard[]>
  getNextQuizCard(): Promise<MistakeCard | null>
  gradeCard(cardId: string, grade: number): Promise<void>
  getStats(): Promise<DashboardStats>
  getAppInfo(): Promise<AppInfo>
  syncNow(): Promise<{ changed: number; error: string | null }>
  getSyncStatus(): Promise<SyncStatus>
  llmGenerate(type: 'mnemonic' | 'quiz_variant' | 'comparison', cardId: string): Promise<string | null>
  getCardImage(cardId: string): Promise<CardImage>
  // Image review screen: per-card status + quota; force-regenerate one card;
  // batch-generate up to the remaining daily budget right now.
  getImageReport(): Promise<ImageReport>
  regenerateImage(cardId: string): Promise<CardImage>
  generateImagesNow(): Promise<{ made: number; message: string }>
  testGithub(): Promise<{ ok: boolean; message: string }>
  testGroq(): Promise<{ ok: boolean; message: string }>
  testGemini(): Promise<{ ok: boolean; message: string }>
  geminiWebSignIn(): Promise<{ ok: boolean; message: string }>
  geminiWebStatus(): Promise<{ signedIn: boolean; message: string }>
  geminiWebSignOut(): Promise<{ ok: boolean; message: string }>
  setMode(mode: AppMode): void
  minimizeWindow(): void
  hideWindow(): void
  setFullscreen(on: boolean): void
  onModeChange(cb: (mode: AppMode) => void): () => void
  onCardsUpdated(cb: (count: number) => void): () => void
  onTriggerQuiz(cb: () => void): () => void
  // Live sync status pushes so the header indicator updates without polling.
  onSyncStatus(cb: (status: SyncStatus) => void): () => void
}
