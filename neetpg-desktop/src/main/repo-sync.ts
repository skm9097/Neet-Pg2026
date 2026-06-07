import type { AppConfig } from '../shared/types'

interface TreeEntry {
  path: string
  type: 'blob' | 'tree'
  sha: string
}

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

  /** Full recursive tree of the branch. Used to find mistake/session files. */
  async listTree(): Promise<TreeEntry[]> {
    const c = this.cfg()
    const url = `${this.base()}/git/trees/${encodeURIComponent(c.repoBranch)}?recursive=1`
    const res = await fetch(url, { headers: this.headers(false) })
    if (!res.ok) {
      throw new Error(`Tree fetch failed (${res.status}): ${await safeText(res)}`)
    }
    const data = (await res.json()) as { tree?: TreeEntry[]; truncated?: boolean }
    return (data.tree || []).filter((e) => e.type === 'blob')
  }

  /** Raw text content of a file at the given repo path. */
  async fetchFile(path: string): Promise<string> {
    const c = this.cfg()
    const url = `${this.base()}/contents/${encodeURIComponent(path).replace(/%2F/g, '/')}?ref=${encodeURIComponent(c.repoBranch)}`
    const res = await fetch(url, {
      headers: { ...this.headers(false), Accept: 'application/vnd.github.raw' }
    })
    if (!res.ok) {
      throw new Error(`File fetch failed for ${path} (${res.status})`)
    }
    return res.text()
  }

  /**
   * Write (create or update) a file at `path` with last-write-wins semantics.
   * Re-reads the current sha immediately before PUT to minimise conflicts.
   */
  async putFile(path: string, content: string, message: string): Promise<void> {
    const c = this.cfg()
    if (!c.githubPat) throw new Error('No GitHub token configured')

    const url = `${this.base()}/contents/${encodeURIComponent(path).replace(/%2F/g, '/')}`

    // Look up existing sha (required for updates).
    let sha: string | undefined
    const getRes = await fetch(`${url}?ref=${encodeURIComponent(c.repoBranch)}`, {
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

    const putRes = await fetch(url, {
      method: 'PUT',
      headers: this.headers(true),
      body: JSON.stringify(body)
    })
    if (!putRes.ok && putRes.status !== 201 && putRes.status !== 200) {
      throw new Error(`Push failed for ${path} (${putRes.status}): ${await safeText(putRes)}`)
    }
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
