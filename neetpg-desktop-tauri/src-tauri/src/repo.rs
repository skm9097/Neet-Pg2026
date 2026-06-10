//! GitHub REST client: recursive tree listing, raw file/binary fetch, and
//! conflict-safe writes. Backoff retry on 429 / rate-limited 403 / 5xx /
//! network errors. No git clone, no git binary needed.

use crate::config::Config;
use base64::Engine;
use serde::Deserialize;
use std::time::Duration;

#[derive(Debug, Clone, Deserialize)]
pub struct TreeEntry {
    pub path: String,
    #[serde(rename = "type")]
    pub kind: String,
    pub sha: String,
}

#[derive(Debug, Deserialize)]
struct TreeResponse {
    #[serde(default)]
    tree: Vec<TreeEntry>,
    #[serde(default)]
    truncated: bool,
}

pub struct Repo<'a> {
    pub http: &'a reqwest::Client,
    pub cfg: &'a Config,
}

impl<'a> Repo<'a> {
    fn base(&self) -> String {
        format!(
            "https://api.github.com/repos/{}/{}",
            self.cfg.repo_owner, self.cfg.repo_name
        )
    }

    fn auth(&self, rb: reqwest::RequestBuilder) -> reqwest::RequestBuilder {
        let rb = rb
            .header("X-GitHub-Api-Version", "2022-11-28")
            .header("User-Agent", "neetpg-desktop");
        if self.cfg.github_pat.is_empty() {
            rb
        } else {
            rb.bearer_auth(&self.cfg.github_pat)
        }
    }

    /// Send with up to 3 attempts; backs off 1s → 3s on retryable failures.
    async fn send_retry(
        &self,
        build: impl Fn() -> reqwest::RequestBuilder,
    ) -> Result<reqwest::Response, String> {
        let mut last_err = String::new();
        for attempt in 0..3u32 {
            if attempt > 0 {
                tokio::time::sleep(Duration::from_millis(1000 * 3u64.pow(attempt - 1))).await;
            }
            match self.auth(build()).send().await {
                Ok(res) => {
                    let status = res.status().as_u16();
                    let rate_limited = status == 429
                        || (status == 403
                            && res
                                .headers()
                                .get("x-ratelimit-remaining")
                                .and_then(|v| v.to_str().ok())
                                == Some("0"));
                    if rate_limited || status >= 500 {
                        last_err = format!("GitHub {status}");
                        continue;
                    }
                    return Ok(res);
                }
                Err(e) => last_err = e.to_string(),
            }
        }
        Err(last_err)
    }

    pub async fn list_tree(&self) -> Result<Vec<TreeEntry>, String> {
        let url = format!("{}/git/trees/{}?recursive=1", self.base(), self.cfg.repo_branch);
        let res = self
            .send_retry(|| self.http.get(&url).header("Accept", "application/vnd.github+json"))
            .await?;
        if !res.status().is_success() {
            return Err(format!("Tree fetch failed ({})", res.status()));
        }
        let data: TreeResponse = res.json().await.map_err(|e| e.to_string())?;
        if data.truncated {
            return Err("Repository tree too large — GitHub truncated the listing".into());
        }
        Ok(data.tree.into_iter().filter(|e| e.kind == "blob").collect())
    }

    fn contents_url(&self, path: &str) -> String {
        format!("{}/contents/{}", self.base(), path)
    }

    pub async fn fetch_file(&self, path: &str) -> Result<String, String> {
        let url = format!("{}?ref={}", self.contents_url(path), self.cfg.repo_branch);
        let res = self
            .send_retry(|| self.http.get(&url).header("Accept", "application/vnd.github.raw"))
            .await?;
        if !res.status().is_success() {
            return Err(format!("File fetch failed for {path} ({})", res.status()));
        }
        res.text().await.map_err(|e| e.to_string())
    }

    /// Raw bytes of a binary file; Ok(None) when the file doesn't exist.
    pub async fn fetch_binary(&self, path: &str) -> Result<Option<Vec<u8>>, String> {
        let url = format!("{}?ref={}", self.contents_url(path), self.cfg.repo_branch);
        let res = self
            .send_retry(|| self.http.get(&url).header("Accept", "application/vnd.github.raw"))
            .await?;
        if res.status().as_u16() == 404 {
            return Ok(None);
        }
        if !res.status().is_success() {
            return Err(format!("Binary fetch failed for {path} ({})", res.status()));
        }
        Ok(Some(res.bytes().await.map_err(|e| e.to_string())?.to_vec()))
    }

    /// Create/update a file. Re-reads the sha before each PUT; one retry on a
    /// 409/422 sha conflict. Returns the new blob sha.
    pub async fn put_file(
        &self,
        path: &str,
        content: &[u8],
        message: &str,
    ) -> Result<Option<String>, String> {
        if self.cfg.github_pat.is_empty() {
            return Err("No GitHub token configured".into());
        }
        let url = self.contents_url(path);

        for attempt in 0..2 {
            let get_url = format!("{url}?ref={}", self.cfg.repo_branch);
            let mut sha: Option<String> = None;
            if let Ok(res) = self
                .send_retry(|| self.http.get(&get_url).header("Accept", "application/vnd.github+json"))
                .await
            {
                if res.status().is_success() {
                    if let Ok(j) = res.json::<serde_json::Value>().await {
                        sha = j.get("sha").and_then(|s| s.as_str()).map(String::from);
                    }
                }
            }

            let mut body = serde_json::json!({
                "message": message,
                "content": base64::engine::general_purpose::STANDARD.encode(content),
                "branch": self.cfg.repo_branch,
            });
            if let Some(s) = &sha {
                body["sha"] = serde_json::Value::String(s.clone());
            }

            let res = self
                .send_retry(|| {
                    self.http
                        .put(&url)
                        .header("Accept", "application/vnd.github+json")
                        .json(&body)
                })
                .await?;
            let status = res.status().as_u16();
            if res.status().is_success() {
                let j: serde_json::Value = res.json().await.map_err(|e| e.to_string())?;
                return Ok(j
                    .pointer("/content/sha")
                    .and_then(|s| s.as_str())
                    .map(String::from));
            }
            if (status == 409 || status == 422) && attempt == 0 {
                continue; // sha conflict — re-read and retry once
            }
            let text = res.text().await.unwrap_or_default();
            return Err(format!(
                "Push failed for {path} ({status}): {}",
                text.chars().take(200).collect::<String>()
            ));
        }
        Err(format!("Push failed for {path}: sha conflict persisted"))
    }

    pub async fn test(&self) -> (bool, String) {
        let url = self.base();
        match self.auth(self.http.get(&url)).send().await {
            Ok(res) => match res.status().as_u16() {
                200..=299 => (
                    true,
                    format!("Connected to {}/{}", self.cfg.repo_owner, self.cfg.repo_name),
                ),
                404 => (false, "Repository not found (check owner/name, or token scope if private)".into()),
                401 => (false, "Unauthorized — check your Personal Access Token".into()),
                s => (false, format!("GitHub returned {s}")),
            },
            Err(e) => (false, format!("Network error: {e}")),
        }
    }
}
