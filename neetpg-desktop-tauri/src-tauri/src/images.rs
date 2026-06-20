//! Per-card infographic generation. Uses an interior std::sync::Mutex for
//! state so no lock is ever held across an await — callers can run
//! get_image_report concurrently with a background pregenerate without
//! blocking.

use crate::config::Config;
use crate::models::{now_iso, ImageQuota, ImageReport, ImageReportEntry, MistakeCard};
use crate::repo::Repo;
use base64::Engine;
use chrono::{Duration as ChronoDuration, Local};
use md5::{Digest, Md5};
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::fs;
use std::path::PathBuf;
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::Mutex;
use std::time::{Duration, Instant};

const PROMPT_VERSION: u32 = 1;
const DEFAULT_CF_MODEL: &str = "@cf/black-forest-labs/flux-1-schnell";
const REPO_IMAGE_DIR: &str = "card-images";
const MANIFEST_TTL: Duration = Duration::from_secs(600);

fn local_day() -> String {
    Local::now().format("%Y-%m-%d").to_string()
}

#[derive(Debug, Clone, Serialize, Deserialize, Default)]
struct QuotaFile {
    date: String,
    used: i64,
    blocked_until: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
struct IndexEntry {
    file: String,
    prompt: String,
    at: String,
    subject: String,
    topic: String,
    #[serde(default)]
    from_repo: bool,
    #[serde(default)]
    provider: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
struct ManifestEntry {
    key: String,
    file: String,
    subject: String,
    topic: String,
    model: String,
    prompt: String,
    at: String,
    bytes: u64,
}

#[derive(Debug, Clone, Serialize, Deserialize, Default)]
struct ErrEntry {
    at: String,
    message: String,
}

// All mutable state — protected by std::sync::Mutex, NEVER held across await.
struct St {
    index: HashMap<String, IndexEntry>,
    quota: QuotaFile,
    errors: HashMap<String, ErrEntry>,
    manifest: Option<HashMap<String, ManifestEntry>>,
    manifest_at: Option<Instant>,
    last_call: Option<Instant>,
}

pub struct Images {
    dir: PathBuf,
    st: Mutex<St>,
    /// Prevents concurrent batch-pregenerate runs.
    batch_running: AtomicBool,
}

// ── helpers ──────────────────────────────────────────────────────────────────

fn read_json<T: serde::de::DeserializeOwned>(path: &PathBuf) -> Option<T> {
    serde_json::from_str(&fs::read_to_string(path).ok()?).ok()
}
fn write_json<T: Serialize>(path: &PathBuf, value: &T) {
    if let Ok(b) = serde_json::to_string_pretty(value) {
        let _ = fs::write(path, b);
    }
}

impl Images {
    pub fn new(data_dir: &PathBuf) -> Self {
        let dir = data_dir.join("card-images");
        let _ = fs::create_dir_all(&dir);
        let index: HashMap<String, IndexEntry> =
            read_json(&dir.join("cache-index.json")).unwrap_or_default();
        let errors = read_json(&dir.join("errors.json")).unwrap_or_default();
        let mut quota: QuotaFile = read_json(&dir.join("quota.json")).unwrap_or_default();
        if quota.date.is_empty() {
            quota.date = local_day();
        }
        // A fresh launch re-probes the provider instead of trusting an old
        // block — if it's still limited it re-blocks after one call.
        quota.blocked_until = None;
        // Recalculate from the index so failed calls don't burn today's budget.
        let today = local_day();
        if quota.date == today {
            quota.used = index
                .values()
                .filter(|e| {
                    !e.from_repo
                        && chrono::DateTime::parse_from_rfc3339(&e.at)
                            .map(|t| {
                                t.with_timezone(&Local).format("%Y-%m-%d").to_string() == today
                            })
                            .unwrap_or(false)
                })
                .count() as i64;
        }
        Self {
            dir,
            st: Mutex::new(St {
                index,
                quota,
                errors,
                manifest: None,
                manifest_at: None,
                last_call: None,
            }),
            batch_running: AtomicBool::new(false),
        }
    }

    // ── quota ─────────────────────────────────────────────────────────────

    fn roll(st: &mut St, dir: &PathBuf) {
        let today = local_day();
        if st.quota.date != today {
            st.quota.date = today;
            st.quota.used = 0;
        }
        if let Some(until) = &st.quota.blocked_until {
            if chrono::DateTime::parse_from_rfc3339(until)
                .map(|t| t <= chrono::Utc::now())
                .unwrap_or(true)
            {
                st.quota.blocked_until = None;
            }
        }
        write_json(&dir.join("quota.json"), &st.quota);
    }

    pub fn quota(&self, cfg: &Config) -> ImageQuota {
        let mut st = self.st.lock().unwrap();
        Self::roll(&mut st, &self.dir);
        ImageQuota {
            date: st.quota.date.clone(),
            used: st.quota.used,
            limit: cfg.images_per_day.max(1),
            blocked_until: st.quota.blocked_until.clone(),
        }
    }

    fn gate(st: &St, cfg: &Config) -> Option<String> {
        if let Some(until) = &st.quota.blocked_until {
            let when = chrono::DateTime::parse_from_rfc3339(until)
                .map(|t| t.with_timezone(&Local).format("%Y-%m-%d %H:%M").to_string())
                .unwrap_or_else(|_| until.clone());
            return Some(format!("Provider limit hit — generation resumes {when}"));
        }
        if st.quota.used >= cfg.images_per_day.max(1) {
            return Some(format!(
                "Daily budget of {} images used — resumes tomorrow",
                cfg.images_per_day.max(1)
            ));
        }
        None
    }

    fn quota_gate(&self, cfg: &Config) -> Option<String> {
        let mut st = self.st.lock().unwrap();
        Self::roll(&mut st, &self.dir);
        Self::gate(&st, cfg)
    }

    fn note_call(&self) {
        let mut st = self.st.lock().unwrap();
        Self::roll(&mut st, &self.dir);
        st.quota.used += 1;
        write_json(&self.dir.join("quota.json"), &st.quota);
    }

    /// Daily-allowance errors park generation until just past local midnight;
    /// transient errors (HTTP 429, "capacity temporarily exceeded") only block
    /// for 15 minutes — they recover on their own and shouldn't cost a day.
    fn note_rate_limited(&self, msg: &str) {
        let lower = msg.to_lowercase();
        let daily =
            lower.contains("daily") || lower.contains("quota") || lower.contains("allocation");
        let next = if daily {
            (Local::now() + ChronoDuration::days(1))
                .date_naive()
                .and_hms_opt(0, 5, 0)
                .and_then(|t| t.and_local_timezone(Local).single())
                .map(|t| t.to_utc().to_rfc3339())
                .unwrap_or_else(|| {
                    (chrono::Utc::now() + ChronoDuration::hours(24)).to_rfc3339()
                })
        } else {
            (chrono::Utc::now() + ChronoDuration::minutes(15)).to_rfc3339()
        };
        let mut st = self.st.lock().unwrap();
        st.quota.blocked_until = Some(next);
        write_json(&self.dir.join("quota.json"), &st.quota);
    }

    // ── errors ────────────────────────────────────────────────────────────

    fn record_error(&self, card_id: &str, message: String) {
        let mut st = self.st.lock().unwrap();
        st.errors.insert(card_id.into(), ErrEntry { at: now_iso(), message });
        write_json(&self.dir.join("errors.json"), &st.errors);
    }

    fn clear_error(&self, card_id: &str) {
        let mut st = self.st.lock().unwrap();
        if st.errors.remove(card_id).is_some() {
            write_json(&self.dir.join("errors.json"), &st.errors);
        }
    }

    // ── cache keys / paths ────────────────────────────────────────────────

    fn key_for(card: &MistakeCard) -> String {
        let basis = format!(
            "{}|{}|{}|{}|{}|{}",
            PROMPT_VERSION,
            card.subject,
            card.topic,
            card.fact_heading,
            card.correct_answer,
            card.tags.join(",")
        );
        let mut h = Md5::new();
        h.update(basis.as_bytes());
        format!("{:x}", h.finalize())
    }

    fn path_for(&self, card: &MistakeCard) -> PathBuf {
        self.dir.join(format!("{}.png", Self::key_for(card)))
    }

    pub fn has_image(&self, card: &MistakeCard) -> bool {
        self.path_for(card).exists()
    }

    pub fn data_url(&self, card: &MistakeCard) -> Option<String> {
        let bytes = fs::read(self.path_for(card)).ok()?;
        Some(format!(
            "data:image/png;base64,{}",
            base64::engine::general_purpose::STANDARD.encode(bytes)
        ))
    }

    pub fn build_prompt(card: &MistakeCard) -> String {
        let topic = card.topic.replace(['-', '_'], " ").trim().to_string();
        let subject = card.subject.replace(['-', '_'], " ").trim().to_string();
        let concept = strip_letter(&card.correct_answer);
        let concept = if concept.is_empty() { card.fact_heading.clone() } else { concept };
        let heading =
            if card.fact_heading.is_empty() { concept.clone() } else { card.fact_heading.clone() };
        let cues = card.tags.iter().take(4).cloned().collect::<Vec<_>>().join(", ");
        let mut parts =
            vec![format!("Medical educational infographic illustration of {heading}.")];
        if !concept.is_empty() && concept.to_lowercase() != heading.to_lowercase() {
            parts.push(format!("Key concept: {concept}."));
        }
        if !topic.is_empty() {
            parts.push(format!("Topic: {subject} — {topic}."));
        } else if !subject.is_empty() {
            parts.push(format!("Subject: {subject}."));
        }
        if !cues.is_empty() {
            parts.push(format!("Show: {cues}."));
        }
        parts.push("Clean labelled anatomical / clinical diagram, flat vector style, clear shapes and arrows, muted palette on a dark navy background, soft teal and slate accents, centred composition, high clarity, textbook quality. No words, no letters, no captions, no watermark, no real patient photographs.".into());
        parts.join(" ")
    }

    pub fn error_hint(&self, cfg: &Config, card: &MistakeCard) -> String {
        {
            let st = self.st.lock().unwrap();
            if let Some(e) = st.errors.get(&card.id) {
                return e.message.clone();
            }
        }
        if let Some(gate) = self.quota_gate(cfg) {
            return gate;
        }
        match cfg.image_provider.as_str() {
            "cloudflare" => {
                if cfg.cf_account_id.is_empty() || cfg.cf_api_token.is_empty() {
                    "Add your Cloudflare account ID + API token in Settings → AI Visuals".into()
                } else {
                    "Cloudflare returned no image — check credentials or try Test in Settings".into()
                }
            }
            "gemini-web" => {
                "Sign in to Gemini in Settings → AI Visuals, then retry from the Card Images screen"
                    .into()
            }
            "gemini" => {
                if cfg.gemini_api_key.is_empty() {
                    "Add a Gemini API key in Settings (or switch the image source)".into()
                } else {
                    "Gemini API returned no image — check the model id or quota".into()
                }
            }
            _ => "Image source unavailable — it will retry later".into(),
        }
    }

    // ── generation ────────────────────────────────────────────────────────

    /// Generate (or fetch from the repo store) and cache. The std Mutex is
    /// never held across any await, so this can run alongside report() and
    /// has_image() without blocking.
    pub async fn generate(
        &self,
        handle: &tauri::AppHandle,
        http: &reqwest::Client,
        cfg: &Config,
        card: &MistakeCard,
        force: bool,
    ) -> bool {
        if !cfg.enable_card_images {
            return false;
        }
        let out = self.path_for(card);
        if !force && out.exists() {
            return true;
        }
        let prompt = Self::build_prompt(card);

        // 1. Repo store (free).
        if !force {
            if let Ok(Some(bytes)) = self.fetch_from_repo(http, cfg, card).await {
                if fs::write(&out, &bytes).is_ok() {
                    self.record_index(card, &prompt, true, "repo");
                    self.clear_error(&card.id);
                    return true;
                }
            }
        }

        // 2. Quota check + compute throttle — brief lock, released before I/O.
        let (gate_msg, throttle) = {
            let mut st = self.st.lock().unwrap();
            Self::roll(&mut st, &self.dir);
            let gate = Self::gate(&st, cfg);
            let sleep = st.last_call.and_then(|t| {
                let e = t.elapsed();
                if e < Duration::from_secs(4) { Some(Duration::from_secs(4) - e) } else { None }
            });
            (gate, sleep)
        }; // ← lock dropped here

        if let Some(msg) = gate_msg {
            self.record_error(&card.id, msg);
            return false;
        }

        // 3. Throttle sleep — no lock held.
        if let Some(d) = throttle {
            tokio::time::sleep(d).await;
        }

        // 4. Mark call time — brief lock.
        { self.st.lock().unwrap().last_call = Some(Instant::now()); }

        // 5. Provider call — no lock held.
        let primary = match cfg.image_provider.as_str() {
            "cloudflare" => {
                if cfg.cf_account_id.is_empty() || cfg.cf_api_token.is_empty() {
                    Err(GenError::Other("Cloudflare account ID / API token not set".into()))
                } else {
                    gen_cloudflare(http, cfg, &prompt).await
                }
            }
            "gemini-web" => crate::gemini_web::generate(handle, &prompt)
                .await
                .map_err(GenError::Other),
            "pollinations" => gen_pollinations(http, &prompt).await,
            _ => {
                if cfg.gemini_api_key.is_empty() {
                    Err(GenError::Other("Gemini API key not set".into()))
                } else {
                    gen_gemini(http, cfg, &prompt).await
                }
            }
        };

        // 6. Any primary failure (hard error OR rate limit) falls back to the
        //    free Pollinations endpoint so the card still gets a visual.
        let (result, fallback_from) = match primary {
            Err(e) if cfg.image_provider != "pollinations" => {
                let why = match &e {
                    GenError::RateLimit(m) | GenError::Other(m) => m.clone(),
                };
                match gen_pollinations(http, &prompt).await {
                    Ok(b) if b.len() >= 128 => (Ok(b), Some(why)),
                    _ => (Err(e), None),
                }
            }
            r => (r, None),
        };

        // 7. Persist — brief lock for state writes, file I/O outside.
        match result {
            Ok(bytes) if bytes.len() >= 128 => {
                if fs::write(&out, &bytes).is_err() {
                    self.record_error(&card.id, "Could not save image to disk".into());
                    return false;
                }
                self.note_call(); // only on success
                let provider = match &fallback_from {
                    Some(w) => format!(
                        "free fallback — {} failed: {}",
                        cfg.image_provider,
                        &w[..w.len().min(90)]
                    ),
                    None => cfg.image_provider.clone(),
                };
                self.record_index(card, &prompt, false, &provider);
                self.clear_error(&card.id);
                self.cleanup(600);
                let _ = self.push_to_repo(http, cfg, card, &bytes, &prompt).await;
                true
            }
            Ok(_) => {
                self.record_error(&card.id, "Provider returned no image".into());
                false
            }
            Err(GenError::RateLimit(msg)) => {
                self.note_rate_limited(&msg);
                self.record_error(&card.id, format!("{msg} — generation paused, resumes automatically"));
                false
            }
            Err(GenError::Other(msg)) => {
                self.record_error(&card.id, msg);
                false
            }
        }
    }

    pub async fn pregenerate(
        &self,
        handle: &tauri::AppHandle,
        http: &reqwest::Client,
        cfg: &Config,
        cards: &[MistakeCard],
        max: usize,
    ) -> usize {
        if !cfg.enable_card_images {
            return 0;
        }
        if self
            .batch_running
            .compare_exchange(false, true, Ordering::SeqCst, Ordering::SeqCst)
            .is_err()
        {
            return 0; // another batch is already running
        }
        let mut made = 0;
        let mut consecutive_failures = 0;
        for card in cards {
            if made >= max {
                break;
            }
            if self.quota_gate(cfg).is_some() {
                break;
            }
            if self.has_image(card) {
                continue;
            }
            if self.generate(handle, http, cfg, card, false).await {
                made += 1;
                consecutive_failures = 0;
            } else {
                consecutive_failures += 1;
                // A systemic failure (bad token, dead endpoint) fails every
                // card the same way — stop the pass instead of burning calls.
                if consecutive_failures >= 3 {
                    break;
                }
            }
        }
        self.batch_running.store(false, Ordering::SeqCst);
        made
    }

    pub async fn regenerate(
        &self,
        handle: &tauri::AppHandle,
        http: &reqwest::Client,
        cfg: &Config,
        card: &MistakeCard,
    ) -> bool {
        let _ = fs::remove_file(self.path_for(card));
        self.clear_error(&card.id);
        self.generate(handle, http, cfg, card, true).await
    }

    fn record_index(&self, card: &MistakeCard, prompt: &str, from_repo: bool, provider: &str) {
        let mut st = self.st.lock().unwrap();
        st.index.insert(
            card.id.clone(),
            IndexEntry {
                file: format!("{}.png", Self::key_for(card)),
                prompt: prompt.into(),
                at: now_iso(),
                subject: card.subject.clone(),
                topic: card.topic.clone(),
                from_repo,
                provider: provider.to_string(),
            },
        );
        write_json(&self.dir.join("cache-index.json"), &st.index);
    }

    // ── repo image store ──────────────────────────────────────────────────

    async fn load_manifest(
        &self,
        http: &reqwest::Client,
        cfg: &Config,
        force: bool,
    ) -> HashMap<String, ManifestEntry> {
        // Brief lock: check cache.
        let (cached, fallback) = {
            let st = self.st.lock().unwrap();
            if !force {
                if let (Some(m), Some(at)) = (&st.manifest, st.manifest_at) {
                    if at.elapsed() < MANIFEST_TTL {
                        return m.clone();
                    }
                }
            }
            (None::<()>, st.manifest.clone().unwrap_or_default())
        };
        let _ = cached;
        // Fetch without lock.
        let repo = Repo { http, cfg };
        let fetched = match repo.fetch_file(&format!("{REPO_IMAGE_DIR}/manifest.json")).await {
            Ok(raw) => serde_json::from_str(&raw).unwrap_or(fallback),
            Err(_) => fallback,
        };
        // Store.
        {
            let mut st = self.st.lock().unwrap();
            st.manifest = Some(fetched.clone());
            st.manifest_at = Some(Instant::now());
        }
        fetched
    }

    async fn fetch_from_repo(
        &self,
        http: &reqwest::Client,
        cfg: &Config,
        card: &MistakeCard,
    ) -> Result<Option<Vec<u8>>, String> {
        let manifest = self.load_manifest(http, cfg, false).await;
        let Some(entry) = manifest.get(&card.id) else { return Ok(None) };
        if entry.key != Self::key_for(card) {
            return Ok(None);
        }
        let repo = Repo { http, cfg };
        repo.fetch_binary(&format!("{REPO_IMAGE_DIR}/{}", entry.file)).await
    }

    async fn push_to_repo(
        &self,
        http: &reqwest::Client,
        cfg: &Config,
        card: &MistakeCard,
        bytes: &[u8],
        prompt: &str,
    ) -> Result<(), String> {
        if cfg.github_pat.is_empty() || !cfg.push_images_to_repo {
            return Ok(());
        }
        let safe_id: String = card
            .id
            .chars()
            .map(|c| if c.is_ascii_alphanumeric() || c == '_' || c == '-' { c } else { '_' })
            .collect();
        let file = format!("{safe_id}.png");
        let repo = Repo { http, cfg };
        repo.put_file(
            &format!("{REPO_IMAGE_DIR}/{file}"),
            bytes,
            &format!("image: {} ({})", card.id, card.subject),
        )
        .await?;
        let mut manifest = self.load_manifest(http, cfg, true).await;
        manifest.insert(
            card.id.clone(),
            ManifestEntry {
                key: Self::key_for(card),
                file,
                subject: card.subject.clone(),
                topic: card.topic.clone(),
                model: if cfg.image_provider == "cloudflare" {
                    if cfg.cf_image_model.is_empty() {
                        DEFAULT_CF_MODEL.into()
                    } else {
                        cfg.cf_image_model.clone()
                    }
                } else {
                    cfg.image_provider.clone()
                },
                prompt: prompt.into(),
                at: now_iso(),
                bytes: bytes.len() as u64,
            },
        );
        let body = serde_json::to_vec_pretty(&manifest).map_err(|e| e.to_string())?;
        repo.put_file(
            &format!("{REPO_IMAGE_DIR}/manifest.json"),
            &body,
            &format!("image: manifest {}", card.id),
        )
        .await?;
        {
            let mut st = self.st.lock().unwrap();
            st.manifest = Some(manifest);
            st.manifest_at = Some(Instant::now());
        }
        Ok(())
    }

    // ── report ────────────────────────────────────────────────────────────

    pub fn report(&self, cfg: &Config, cards: &[MistakeCard]) -> ImageReport {
        let quota = self.quota(cfg);
        let blocked = self.quota_gate(cfg).is_some();
        let st = self.st.lock().unwrap();
        let mut entries: Vec<ImageReportEntry> = cards
            .iter()
            .map(|card| {
                let ready = self.path_for(card).exists();
                let err = st.errors.get(&card.id);
                let idx = st.index.get(&card.id);
                let status = if ready {
                    "ready"
                } else if err.is_some() {
                    "error"
                } else if blocked {
                    "blocked"
                } else {
                    "queued"
                };
                ImageReportEntry {
                    card_id: card.id.clone(),
                    subject: card.subject.clone(),
                    topic: card.topic.clone(),
                    heading: if !card.fact_heading.is_empty() {
                        card.fact_heading.clone()
                    } else if !card.topic.is_empty() {
                        card.topic.clone()
                    } else {
                        card.subject.clone()
                    },
                    status: status.into(),
                    error: if !ready { err.map(|e| e.message.clone()) } else { None },
                    generated_at: if ready { idx.map(|i| i.at.clone()) } else { None },
                    from_repo: if ready { idx.map(|i| i.from_repo) } else { None },
                }
            })
            .collect();
        drop(st);
        let rank = |s: &str| match s {
            "error" => 0,
            "blocked" => 1,
            "queued" => 2,
            _ => 3,
        };
        entries.sort_by(|a, b| {
            rank(&a.status).cmp(&rank(&b.status)).then(a.card_id.cmp(&b.card_id))
        });
        ImageReport {
            quota,
            total: entries.len(),
            ready: entries.iter().filter(|e| e.status == "ready").count(),
            queued: entries
                .iter()
                .filter(|e| e.status == "queued" || e.status == "blocked")
                .count(),
            errors: entries.iter().filter(|e| e.status == "error").count(),
            entries,
        }
    }

    pub async fn test(
        &self,
        handle: &tauri::AppHandle,
        http: &reqwest::Client,
        cfg: &Config,
    ) -> (bool, String) {
        match cfg.image_provider.as_str() {
            "gemini-web" => crate::gemini_web::probe(handle).await,
            "cloudflare" => {
                if cfg.cf_account_id.is_empty() || cfg.cf_api_token.is_empty() {
                    return (false, "Enter your Cloudflare account ID and API token".into());
                }
                let url = format!(
                    "https://api.cloudflare.com/client/v4/accounts/{}/ai/models/search?per_page=1",
                    cfg.cf_account_id
                );
                match http.get(&url).bearer_auth(&cfg.cf_api_token).send().await {
                    Ok(res) => match res.status().as_u16() {
                        200..=299 => {
                            let model = if cfg.cf_image_model.is_empty() {
                                DEFAULT_CF_MODEL
                            } else {
                                &cfg.cf_image_model
                            };
                            (true, format!("Cloudflare OK ({model})"))
                        }
                        401 | 403 => (
                            false,
                            "Token rejected — check the API token and its Workers AI permission"
                                .into(),
                        ),
                        404 => (false, "Account not found — check the account ID".into()),
                        s => (false, format!("Cloudflare returned {s}")),
                    },
                    Err(e) => (false, format!("Network error: {e}")),
                }
            }
            "pollinations" => {
                match gen_pollinations(
                    http,
                    "simple flat vector medical icon, dark background, no text",
                )
                .await
                {
                    Ok(b) if !b.is_empty() => {
                        (true, "Pollinations reachable (free, no key needed)".into())
                    }
                    _ => (false, "Pollinations did not return an image".into()),
                }
            }
            _ => {
                if cfg.gemini_api_key.is_empty() {
                    return (false, "No Gemini API key set".into());
                }
                match gen_gemini(
                    http,
                    cfg,
                    "Simple flat vector illustration of a human heart, dark background, no text",
                )
                .await
                {
                    Ok(b) if b.len() > 128 => {
                        (true, format!("Gemini image OK ({})", cfg.gemini_image_model))
                    }
                    _ => (
                        false,
                        "No image returned — check the model id, key, or quota".into(),
                    ),
                }
            }
        }
    }

    fn cleanup(&self, max_images: usize) {
        let Ok(read) = fs::read_dir(&self.dir) else { return };
        let mut files: Vec<(PathBuf, std::time::SystemTime)> = read
            .flatten()
            .filter(|e| e.path().extension().map(|x| x == "png").unwrap_or(false))
            .filter_map(|e| {
                let m = e.metadata().ok()?.modified().ok()?;
                Some((e.path(), m))
            })
            .collect();
        files.sort_by(|a, b| b.1.cmp(&a.1));
        for (path, _) in files.into_iter().skip(max_images) {
            let _ = fs::remove_file(path);
        }
    }
}

// ── providers ─────────────────────────────────────────────────────────────────

enum GenError {
    RateLimit(String),
    Other(String),
}

enum CfFormat {
    Json,
    Multipart,
}

async fn gen_cloudflare(
    http: &reqwest::Client,
    cfg: &Config,
    prompt: &str,
) -> Result<Vec<u8>, GenError> {
    let configured = cfg.cf_image_model.trim();
    let model = if configured.is_empty() { DEFAULT_CF_MODEL } else { configured };
    let lower = model.to_lowercase();
    let first = if lower.contains("flux-2") || lower.contains("flux.2") || lower.contains("flux2")
    {
        CfFormat::Multipart
    } else {
        CfFormat::Json
    };
    let json_first = matches!(first, CfFormat::Json);

    match cf_run(http, cfg, model, prompt, &first).await {
        Err(GenError::Other(msg))
            if json_first && msg.to_lowercase().contains("multipart") =>
        {
            cf_run(http, cfg, model, prompt, &CfFormat::Multipart).await
        }
        Err(GenError::Other(msg))
            if msg.to_lowercase().contains("no route") && model != DEFAULT_CF_MODEL =>
        {
            cf_run(http, cfg, DEFAULT_CF_MODEL, prompt, &CfFormat::Json)
                .await
                .map_err(|e| match e {
                    GenError::Other(m) => {
                        GenError::Other(format!("{msg}; tried {DEFAULT_CF_MODEL}: {m}"))
                    }
                    other => other,
                })
        }
        r => r,
    }
}

async fn cf_run(
    http: &reqwest::Client,
    cfg: &Config,
    model: &str,
    prompt: &str,
    format: &CfFormat,
) -> Result<Vec<u8>, GenError> {
    let url = format!(
        "https://api.cloudflare.com/client/v4/accounts/{}/ai/run/{}",
        cfg.cf_account_id.trim(),
        model
    );
    let req = http.post(&url).bearer_auth(cfg.cf_api_token.trim());
    let req = match format {
        CfFormat::Json => {
            let body = if model.to_lowercase().contains("flux") {
                serde_json::json!({ "prompt": prompt, "steps": 8 })
            } else {
                serde_json::json!({ "prompt": prompt })
            };
            req.json(&body)
        }
        CfFormat::Multipart => {
            let form = reqwest::multipart::Form::new()
                .text("prompt", prompt.to_string())
                .text("width", "1024")
                .text("height", "1024");
            req.multipart(form)
        }
    };
    let res = req.send().await.map_err(|e| GenError::Other(format!("{model}: {e}")))?;

    if res.status().as_u16() == 429 {
        return Err(GenError::RateLimit(format!("{model}: rate limit (429)")));
    }
    if !res.status().is_success() {
        let status = res.status().as_u16();
        let msg = res
            .json::<serde_json::Value>()
            .await
            .ok()
            .and_then(|j| {
                j.pointer("/errors/0/message")
                    .and_then(|m| m.as_str())
                    .map(String::from)
            })
            .unwrap_or_else(|| format!("HTTP {status}"));
        let lower = msg.to_lowercase();
        if lower.contains("limit")
            || lower.contains("quota")
            || lower.contains("capacity")
            || lower.contains("allocation")
        {
            return Err(GenError::RateLimit(msg));
        }
        return Err(GenError::Other(format!("{model}: {msg}")));
    }

    let ct = res
        .headers()
        .get("content-type")
        .and_then(|v| v.to_str().ok())
        .unwrap_or("")
        .to_string();

    if ct.contains("application/json") {
        let j: serde_json::Value =
            res.json().await.map_err(|e| GenError::Other(e.to_string()))?;
        if j.get("success").and_then(|s| s.as_bool()) == Some(false) {
            let msg = j
                .pointer("/errors/0/message")
                .and_then(|m| m.as_str())
                .unwrap_or("Cloudflare reported failure");
            return Err(GenError::Other(format!("{model}: {msg}")));
        }
        let b64 = j
            .pointer("/result/image")
            .or_else(|| j.pointer("/image"))
            .and_then(|v| v.as_str())
            .ok_or_else(|| GenError::Other(format!("{model}: no image in response")))?;
        decode_b64(b64).map_err(|e| GenError::Other(format!("{model}: bad image data: {e}")))
    } else {
        Ok(res.bytes().await.map_err(|e| GenError::Other(e.to_string()))?.to_vec())
    }
}

fn decode_b64(s: &str) -> Result<Vec<u8>, String> {
    use base64::engine::general_purpose::{STANDARD, STANDARD_NO_PAD};
    STANDARD
        .decode(s)
        .or_else(|_| STANDARD_NO_PAD.decode(s.trim_end_matches('=')))
        .map_err(|e| e.to_string())
}

async fn gen_gemini(
    http: &reqwest::Client,
    cfg: &Config,
    prompt: &str,
) -> Result<Vec<u8>, GenError> {
    let model =
        if cfg.gemini_image_model.is_empty() { "gemini-2.5-flash-image" } else { &cfg.gemini_image_model };
    let url = format!(
        "https://generativelanguage.googleapis.com/v1beta/models/{}:generateContent?key={}",
        model, cfg.gemini_api_key
    );
    for modalities in [vec!["IMAGE"], vec!["TEXT", "IMAGE"]] {
        let body = serde_json::json!({
            "contents": [{ "role": "user", "parts": [{ "text": prompt }] }],
            "generationConfig": { "responseModalities": modalities }
        });
        let Ok(res) = http.post(&url).json(&body).send().await else { continue };
        if res.status().as_u16() == 429 {
            return Err(GenError::RateLimit("Gemini rate limit (429)".into()));
        }
        if !res.status().is_success() {
            continue;
        }
        let Ok(j) = res.json::<serde_json::Value>().await else { continue };
        let parts = j
            .pointer("/candidates/0/content/parts")
            .and_then(|p| p.as_array())
            .cloned()
            .unwrap_or_default();
        for part in parts {
            let b64 = part
                .pointer("/inlineData/data")
                .or_else(|| part.pointer("/inline_data/data"))
                .and_then(|d| d.as_str());
            if let Some(b64) = b64 {
                return base64::engine::general_purpose::STANDARD
                    .decode(b64)
                    .map_err(|e| GenError::Other(e.to_string()));
            }
        }
    }
    Err(GenError::Other("Gemini returned no image".into()))
}

async fn gen_pollinations(http: &reqwest::Client, prompt: &str) -> Result<Vec<u8>, GenError> {
    let url = format!(
        "https://image.pollinations.ai/prompt/{}?width=864&height=624&nologo=true",
        urlencode(prompt)
    );
    let res = http.get(&url).send().await.map_err(|e| GenError::Other(e.to_string()))?;
    if res.status().as_u16() == 429 {
        return Err(GenError::RateLimit("Pollinations rate limit (429)".into()));
    }
    if !res.status().is_success() {
        return Err(GenError::Other(format!("Pollinations {}", res.status())));
    }
    Ok(res.bytes().await.map_err(|e| GenError::Other(e.to_string()))?.to_vec())
}

fn urlencode(s: &str) -> String {
    s.bytes()
        .map(|b| match b {
            b'A'..=b'Z' | b'a'..=b'z' | b'0'..=b'9' | b'-' | b'_' | b'.' | b'~' => {
                (b as char).to_string()
            }
            b' ' => "%20".into(),
            _ => format!("%{b:02X}"),
        })
        .collect()
}

fn strip_letter(s: &str) -> String {
    let s = s.trim();
    static RE: std::sync::OnceLock<regex::Regex> = std::sync::OnceLock::new();
    let re = RE.get_or_init(|| regex::Regex::new(r"^[A-D][.)]\s*").unwrap());
    re.replace(s, "").trim_end_matches('✅').trim().to_string()
}
