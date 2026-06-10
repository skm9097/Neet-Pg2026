import type { AppConfig } from '../shared/types'

interface TreeEntry {
  path: string
  type: 'blob' | 'tree'
  sha: string
}

const sleep = (ms: number): Promise<void> => new Promise((r) => setTimeout(r, ms))

/**
 * Reads mistake/session/progress files from the GitHub repo via the REST API,
 * and writes progress files back via the Contents API. This avoids a full
 * `git clone` (the repo carries 600 MB+ of APK releases the desktop never
 * needs) and means the user does NOT need git installed on Windows.
 */
export class RepoSync {
  constructor(private cfg: () => AppConfig) {}

  private base(): string {
    const c = this.cfg()
    return `https://api.github.com/repos/${c.repoOwner}/${c.repoName}`
  }

  private headers(json = true): Record<string, string> {
    const c = this.cfg()
    const h: Record<string, string> = {
      Accept: 'application/vnd.github+json',
      'X-GitHub-Api-Version': '2022-11-28',
      'User-Agent': 'neetpg-desktop'
    }
    if (c.githubPat) h.Authorization = `Bearer ${c.githubPat}`
    if (json) h['Content-Type'] = 'application/json'
    return h
  }

  /**
   * fetch() with retry: 429 / rate-limited 403 / 5xx / network errors back off
   * 1s → 3s → 9s before giving up. Other statuses return immediately so
   * callers can handle them (e.g. 404 means "file doesn't exist yet").
   */
  private async request(url: string, init: RequestInit): Promise<Response> {
    let lastErr: Error | null = null
    for (let attempt = 0; attempt < 3; attempt++) {
      if (attempt > 0) await sleep(1000 * Math.pow(3, attempt - 1))
      try {
        const res = await fetch(url, init)
        const rateLimited =
          res.status === 429 ||
          (res.status === 403 && res.headers.get('x-ratelimit-remaining') === '0')
        if (rateLimited || res.status >= 500) {
          lastErr = new Error(`GitHub ${res.status} for ${url}`)
          continue
        }
        return res
      } catch (e) {
        lastErr = e as Error
      }
    }
    throw lastErr || new Error(`Request failed: ${url}`)
  }

  /** Full recursive tree of the branch. Used to find mistake/session files. */
  async listTree(): Promise<TreeEntry[]> {
    const c = this.cfg()
    const url = `${this.base()}/git/trees/${encodeURIComponent(c.repoBranch)}?recursive=1`
    const res = await this.request(url, { headers: this.headers(false) })
    if (!res.ok) {
      throw new Error(`Tree fetch failed (${res.status}): ${await safeText(res)}`)
    }
    const data = (await res.json()) as { tree?: TreeEntry[]; truncated?: boolean }
    if (data.truncated) {
      // GitHub silently caps recursive trees (~100k entries). Failing loudly
      // beats silently never syncing files past the cap.
      throw new Error('Repository tree too large — GitHub truncated the listing')
    }
    return (data.tree || []).filter((e) => e.type === 'blob')
  }

  /** Raw text content of a file at the given repo path. */
  async fetchFile(path: string): Promise<string> {
    const c = this.cfg()
    const url = `${this.base()}/contents/${encodeURIComponent(path).replace(/%2F/g, '/')}?ref=${encodeURIComponent(c.repoBranch)}`
    const res = await this.request(url, {
      headers: { ...this.headers(false), Accept: 'application/vnd.github.raw' }
    })
    if (!res.ok) {
      throw new Error(`File fetch failed for ${path} (${res.status})`)
    }
    return res.text()
  }

  /**
   * Write (create or update) a file at `path`. Re-reads the current sha
   * immediately before PUT; on a 409/422 sha conflict (another device wrote in
   * between) it re-fetches the sha once and retries. Returns the new blob sha
   * so callers can record it and skip re-fetching the file they just wrote.
   */
  async putFile(path: string, content: string, message: string): Promise<string | null> {
    const c = this.cfg()
    if (!c.githubPat) throw new Error('No GitHub token configured')

    const url = `${this.base()}/contents/${encodeURIComponent(path).replace(/%2F/g, '/')}`

    for (let attempt = 0; attempt < 2; attempt++) {
      // Look up existing sha (required for updates).
      let sha: string | undefined
      const getRes = await this.request(`${url}?ref=${encodeURIComponent(c.repoBranch)}`, {
        headers: this.headers(false)
      })
      if (getRes.ok) {
        const j = (await getRes.json()) as { sha?: string }
        sha = j.sha
      }

      const body: Record<string, unknown> = {
        message,
        content: Buffer.from(content, 'utf-8').toString('base64'),
        branch: c.repoBranch
      }
      if (sha) body.sha = sha

      const putRes = await this.request(url, {
        method: 'PUT',
        headers: this.headers(true),
        body: JSON.stringify(body)
      })
      if (putRes.ok) {
        const j = (await putRes.json()) as { content?: { sha?: string } }
        return j.content?.sha || null
      }
      // Sha conflict — someone else wrote between our GET and PUT. Loop once
      // to pick up the fresh sha; our content overwrites (last-write-wins,
      // but the caller merges remote state before writing).
      if ((putRes.status === 409 || putRes.status === 422) && attempt === 0) continue
      throw new Error(`Push failed for ${path} (${putRes.status}): ${await safeText(putRes)}`)
    }
    throw new Error(`Push failed for ${path}: sha conflict persisted`)
  }

  /** Lightweight connectivity / auth check. */
  async test(): Promise<{ ok: boolean; message: string }> {
    try {
      const c = this.cfg()
      const res = await fetch(this.base(), { headers: this.headers(false) })
      if (res.ok) {
        return { ok: true, message: `Connected to ${c.repoOwner}/${c.repoName}` }
      }
      if (res.status === 404) {
        return { ok: false, message: 'Repository not found (check owner/name, or token scope if private)' }
      }
      if (res.status === 401) {
        return { ok: false, message: 'Unauthorized — check your Personal Access Token' }
      }
      return { ok: false, message: `GitHub returned ${res.status}` }
    } catch (e) {
      return { ok: false, message: `Network error: ${(e as Error).message}` }
    }
  }
}

async function safeText(res: Response): Promise<string> {
  try {
    const t = await res.text()
    return t.length > 200 ? t.slice(0, 200) : t
  } catch {
    return ''
  }
}
