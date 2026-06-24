//! One full sync cycle: list tree → pull-merge SR state → fetch & parse new
//! mistake/session files → LLM-enrich + write back → push progress. Every
//! status transition is emitted to the frontend as a `sync-status` event.

use crate::config::Config;
use crate::llm;
use crate::md_builder::build_mistake_markdown;
use crate::models::{now_iso, ParseError, SRState, SessionLog, SyncStatus, TopicScores};
use crate::parser::{derive_bullets, derive_heading, parse_mistake_file};
use crate::repo::Repo;
use crate::sr;
use crate::state::App;
use tauri::{AppHandle, Emitter};

const SR_STATE_PATH: &str = "progress/sr-state.json";

pub struct SyncResult {
    pub changed: usize,
    pub error: Option<String>,
}

async fn emit_status(app: &App, handle: &AppHandle, patch: impl FnOnce(&mut SyncStatus)) {
    let status = {
        let mut st = app.status.lock().unwrap();
        patch(&mut st);
        st.clone()
    };
    let mut status = status;
    status.total_cards = app.cache.lock().await.data.cards.len();
    let _ = handle.emit("sync-status", &status);
}

pub async fn sync(app: &App, handle: &AppHandle) -> SyncResult {
    if app
        .sync_running
        .swap(true, std::sync::atomic::Ordering::SeqCst)
    {
        return SyncResult { changed: 0, error: None };
    }
    let result = run(app, handle).await;
    app.sync_running.store(false, std::sync::atomic::Ordering::SeqCst);
    result
}

async fn run(app: &App, handle: &AppHandle) -> SyncResult {
    let cfg = app.config.lock().unwrap().clone();
    emit_status(app, handle, |st| {
        st.in_progress = true;
        st.last_error = None;
        st.phase = "listing".into();
    })
    .await;

    let mut changed = 0usize;
    let mut parse_errors: Vec<ParseError> = Vec::new();

    let outcome: Result<(), String> = async {
        let repo = Repo { http: &app.http, cfg: &cfg };
        let tree = repo.list_tree().await?;

        emit_status(app, handle, |st| st.phase = "fetching".into()).await;

        // Pull-merge remote SR state before anything else.
        if let Some(entry) = tree.iter().find(|e| e.path == SR_STATE_PATH) {
            let known = app.cache.lock().await.data.blob_shas.get(SR_STATE_PATH).cloned();
            if known.as_deref() != Some(&entry.sha) {
                if let Ok(raw) = repo.fetch_file(SR_STATE_PATH).await {
                    if let Ok(remote) = serde_json::from_str::<SRState>(&raw) {
                        let mut cache = app.cache.lock().await;
                        sr::merge_remote(&mut cache, &remote);
                        cache.data.blob_shas.insert(SR_STATE_PATH.into(), entry.sha.clone());
                    }
                }
            }
        }

        // Mistake files.
        for f in tree.iter().filter(|e| e.path.starts_with("mistakes/") && e.path.ends_with(".md")) {
            let known = app.cache.lock().await.data.blob_shas.get(&f.path).cloned();
            if known.as_deref() == Some(&f.sha) {
                continue;
            }
            let Ok(raw) = repo.fetch_file(&f.path).await else { continue };
            match parse_mistake_file(&raw, &f.path, &f.sha) {
                Ok(card) => {
                    app.cache.lock().await.upsert_card(card);
                    changed += 1;
                }
                Err(reason) => {
                    // Record the sha so a permanently-broken file isn't
                    // refetched every cycle — but surface it, never drop it.
                    let mut cache = app.cache.lock().await;
                    cache.data.blob_shas.insert(f.path.clone(), f.sha.clone());
                    parse_errors.push(ParseError { path: f.path.clone(), reason });
                }
            }
        }

        // Session logs.
        for f in tree.iter().filter(|e| e.path.starts_with("sessions/") && e.path.ends_with(".json")) {
            let known = app.cache.lock().await.data.blob_shas.get(&f.path).cloned();
            if known.as_deref() == Some(&f.sha) {
                continue;
            }
            let Ok(raw) = repo.fetch_file(&f.path).await else { continue };
            if let Ok(s) = serde_json::from_str::<SessionLog>(&raw) {
                if !s.session_id.is_empty() {
                    let mut cache = app.cache.lock().await;
                    cache.data.sessions.insert(s.session_id.clone(), s);
                    cache.data.blob_shas.insert(f.path.clone(), f.sha.clone());
                    changed += 1;
                }
            }
        }

        // Join SR fields onto cards, then persist.
        {
            let mut cache = app.cache.lock().await;
            let ids: Vec<String> = cache.data.cards.keys().cloned().collect();
            for id in ids {
                if let Some(s) = cache.data.sr.get(&id).cloned() {
                    if let Some(card) = cache.data.cards.get_mut(&id) {
                        card.sr_status = s.status;
                        card.next_review = s.next_review;
                    }
                }
            }
            cache.save();
        }

        // LLM enrichment + write-back.
        if !cfg.groq_api_key.is_empty() && cfg.enable_mnemonics {
            emit_status(app, handle, |st| st.phase = "enriching".into()).await;
            enrich_missing(app, &cfg).await;
        }

        // Push progress.
        if !cfg.github_pat.is_empty() {
            emit_status(app, handle, |st| st.phase = "pushing".into()).await;
            push_progress(app, &cfg).await;
        }

        Ok(())
    }
    .await;

    match outcome {
        Ok(()) => {
            emit_status(app, handle, |st| {
                st.in_progress = false;
                st.last_sync = Some(now_iso());
                st.phase = "done".into();
                st.parse_errors = parse_errors.clone();
            })
            .await;
            SyncResult { changed, error: None }
        }
        Err(msg) => {
            // Sync failed (offline, rate-limited, …) — the local cache stays
            // intact and the UI keeps serving cards from it.
            emit_status(app, handle, |st| {
                st.in_progress = false;
                st.last_error = Some(msg.clone());
                st.phase = "error".into();
                st.parse_errors = parse_errors.clone();
            })
            .await;
            SyncResult { changed, error: Some(msg) }
        }
    }
}

async fn enrich_missing(app: &App, cfg: &Config) {
    let missing: Vec<_> = {
        let cache = app.cache.lock().await;
        cache
            .data
            .cards
            .values()
            .filter(|c| {
                if c.question.is_empty() || c.options.is_empty() {
                    return false;
                }
                // Missing enrichment — always queue.
                if c.key_fact.is_empty() || c.why_wrong.is_empty() {
                    return true;
                }
                // Old verbose bullets (>50 chars each) — re-enrich with the
                // short-phrase prompt so the ambient slide gets crisp bullets.
                c.fact_points.is_empty() || c.fact_points.iter().any(|p| p.len() > 50)
            })
            .take(5)
            .cloned()
            .collect()
    };
    let can_push = !cfg.github_pat.is_empty();

    for mut card in missing {
        let Some(enriched) = llm::enrich_card(&app.http, &cfg.groq_api_key, &card).await else {
            continue;
        };
        if !enriched.key_fact.is_empty() {
            card.key_fact = enriched.key_fact;
        }
        if !enriched.why_wrong.is_empty() {
            card.why_wrong = enriched.why_wrong;
        }
        if matches!(enriched.error_type.as_str(), "conceptual" | "recall" | "silly") {
            card.error_type = enriched.error_type;
        }
        if !enriched.tags.is_empty() {
            card.tags = enriched.tags;
        }
        card.fact_heading = derive_heading(&card.topic, &card.key_fact);
        card.fact_points = if !enriched.fact_points.is_empty() {
            enriched.fact_points
        } else {
            derive_bullets(&card.key_fact, &card.fact_heading)
        };

        // Write the enrichment back to the repo so it reaches every device
        // and survives cache clears.
        if can_push && !card.file_path.is_empty() {
            let repo = Repo { http: &app.http, cfg };
            if let Ok(Some(sha)) = repo
                .put_file(
                    &card.file_path,
                    build_mistake_markdown(&card).as_bytes(),
                    &format!("enrich: {} key fact + analysis", card.id),
                )
                .await
            {
                card.last_modified = sha;
            }
        }
        app.cache.lock().await.upsert_card(card);
    }
    app.cache.lock().await.save();
}

async fn push_progress(app: &App, cfg: &Config) {
    let repo = Repo { http: &app.http, cfg };
    let (sr_state, topic_scores) = {
        let cache = app.cache.lock().await;
        (sr::export_state(&cache), compute_topic_scores(&cache))
    };

    if let Ok(body) = serde_json::to_vec_pretty(&sr_state) {
        if let Ok(Some(sha)) = repo.put_file(SR_STATE_PATH, &body, "sr: desktop review update").await {
            // Record what we just wrote so next cycle's pull-merge skips it.
            app.cache.lock().await.data.blob_shas.insert(SR_STATE_PATH.into(), sha);
        }
    }
    if let Ok(body) = serde_json::to_vec_pretty(&topic_scores) {
        let _ = repo
            .put_file("progress/topic-scores.json", &body, "progress: desktop topic scores")
            .await;
    }
}

fn compute_topic_scores(cache: &crate::cache::Cache) -> TopicScores {
    let mut map: std::collections::HashMap<String, (i64, i64)> = std::collections::HashMap::new();
    for c in cache.data.cards.values() {
        let e = map.entry(c.subject.clone()).or_insert((0, 0));
        e.1 += 1;
        if !c.is_resolved {
            e.0 += 1;
        }
    }
    TopicScores {
        last_updated: now_iso(),
        scores: map
            .into_iter()
            .map(|(k, (u, t))| (k, if t > 0 { (u as f64 / t as f64 * 1000.0).round() / 1000.0 } else { 0.0 }))
            .collect(),
    }
}
