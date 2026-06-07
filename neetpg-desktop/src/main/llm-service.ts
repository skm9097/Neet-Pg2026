import type { MistakeCard } from '../shared/types'

/**
 * Groq API wrapper for on-demand content generation. Every call is optional —
 * the app works fully with no API key. Callers must wrap usage in try/catch and
 * fall back gracefully. A 3-second minimum spacing keeps us under 30 RPM.
 */
export class LLMService {
  private lastCall = 0
  private readonly minGapMs = 3000
  private readonly url = 'https://api.groq.com/openai/v1/chat/completions'
  private readonly model = 'llama-3.3-70b-versatile'

  constructor(private apiKey: () => string) {}

  get configured(): boolean {
    return !!this.apiKey()
  }

  private async throttle(): Promise<void> {
    const wait = this.minGapMs - (Date.now() - this.lastCall)
    if (wait > 0) await new Promise((r) => setTimeout(r, wait))
    this.lastCall = Date.now()
  }

  private async call(prompt: string, maxTokens = 500): Promise<string> {
    const key = this.apiKey()
    if (!key) throw new Error('No Groq API key')
    await this.throttle()

    const res = await fetch(this.url, {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${key}`,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({
        model: this.model,
        messages: [{ role: 'user', content: prompt }],
        temperature: 0.7,
        max_tokens: maxTokens
      })
    })
    if (!res.ok) throw new Error(`Groq ${res.status}`)
    const data = (await res.json()) as {
      choices?: { message?: { content?: string } }[]
    }
    return data.choices?.[0]?.message?.content?.trim() || ''
  }

  async test(): Promise<{ ok: boolean; message: string }> {
    try {
      const out = await this.call('Reply with the single word: ok', 5)
      return { ok: true, message: out ? `Groq reachable (${this.model})` : 'Empty response' }
    } catch (e) {
      return { ok: false, message: (e as Error).message }
    }
  }

  async generateMnemonic(card: MistakeCard): Promise<string> {
    return this.call(
      `A medical student keeps getting this wrong:\n` +
        `Correct answer: ${card.correctAnswer}\n` +
        `Key fact: ${card.keyFact}\n` +
        `Why they get it wrong: ${card.whyWrong}\n\n` +
        `Create ONE short, memorable mnemonic to help remember this. Just the mnemonic, nothing else.`,
      120
    )
  }

  async rephraseQuestion(card: MistakeCard): Promise<string> {
    return this.call(
      `Rephrase this NEET PG question as a short clinical scenario:\n` +
        `Original: ${card.question}\n` +
        `Correct answer: ${card.correctAnswer}\n\n` +
        `Give the new question with 4 options, mark correct with ✅. Nothing else.`,
      400
    )
  }

  async generateComparison(a: MistakeCard, b: MistakeCard): Promise<string> {
    return this.call(
      `A medical student confuses these two concepts:\n` +
        `1. ${a.correctAnswer}: ${a.keyFact}\n` +
        `2. ${b.correctAnswer}: ${b.keyFact}\n\n` +
        `Create a brief comparison table (markdown) showing 4-5 key differences. Nothing else.`,
      400
    )
  }

  /** Fill key_fact/why_wrong/error_type/tags for an un-enriched (offline-pushed) file. */
  async enrichCard(
    card: MistakeCard
  ): Promise<{ keyFact: string; whyWrong: string; errorType: string; tags: string[] } | null> {
    try {
      const raw = await this.call(
        `A NEET PG student answered this question wrong.\n` +
          `Question: ${card.question}\n` +
          `Options: ${card.options.join(', ')}\n` +
          `Their answer: ${card.userAnswer}\n` +
          `Correct answer: ${card.correctAnswer}\n\n` +
          `Respond in JSON only, no backticks:\n` +
          `{"key_fact":"2-3 sentence explanation","why_wrong":"1-2 sentence error analysis","error_type":"conceptual | recall | silly","tags":["k1","k2"]}`,
        400
      )
      const s = raw.indexOf('{')
      const e = raw.lastIndexOf('}')
      if (s < 0 || e < 0) return null
      const j = JSON.parse(raw.slice(s, e + 1))
      return {
        keyFact: j.key_fact || '',
        whyWrong: j.why_wrong || '',
        errorType: j.error_type || '',
        tags: Array.isArray(j.tags) ? j.tags.map(String) : []
      }
    } catch {
      return null
    }
  }
}
