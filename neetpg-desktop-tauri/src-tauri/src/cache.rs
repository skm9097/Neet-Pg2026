//! JSON-file-backed local store: parsed cards, blob shas for change detection,
//! SM-2 state, sessions, LLM text cache, and the daily reviewed counter.
//! A corrupt file is backed up (never silently discarded) before resetting.

use crate::models::{MistakeCard, SRCard, SessionLog};
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::fs;
use std::path::{Path, PathBuf};

const CACHE_VERSION: i64 = 2;

#[derive(Debug, Clone, Serialize, Deserialize, Default)]
pub struct CacheData {
    #[serde(default)]
    pub version: i64,
    #[serde(default)]
    pub cards: HashMap<String, MistakeCard>,
    #[serde(default)]
    pub blob_shas: HashMap<String, String>,
    #[serde(default)]
    pub sr: HashMap<String, SRCard>,
    #[serde(default)]
    pub sessions: HashMap<String, SessionLog>,
    #[serde(default)]
    pub llm: HashMap<String, String>,
    #[serde(default)]
    pub reviewed_dates: HashMap<String, i64>,
}

pub struct Cache {
    path: PathBuf,
    pub data: CacheData,
}

impl Cache {
    pub fn load(path: &Path) -> Self {
        let data = match fs::read_to_string(path) {
            Ok(raw) => match serde_json::from_str::<CacheData>(&raw) {
                Ok(mut d) => {
                    if d.version != CACHE_VERSION {
                        // Parser/schema upgrade: re-fetch and re-parse everything,
                        // but keep SR progress, sessions, and review history.
                        d.cards.clear();
                        d.blob_shas.clear();
                        d.llm.clear();
                        d.version = CACHE_VERSION;
                    }
                    d
                }
                Err(_) => {
                    // Corrupt — keep a backup so progress is recoverable.
                    let _ = fs::copy(path, path.with_extension("json.corrupt.bak"));
                    CacheData {
                        version: CACHE_VERSION,
                        ..Default::default()
                    }
                }
            },
            Err(_) => CacheData {
                version: CACHE_VERSION,
                ..Default::default()
            },
        };
        Self {
            path: path.to_path_buf(),
            data,
        }
    }

    /// Atomic write: temp file then rename. Failure leaves memory authoritative.
    pub fn save(&self) {
        if let Some(dir) = self.path.parent() {
            let _ = fs::create_dir_all(dir);
        }
        let tmp = self.path.with_extension("json.tmp");
        if let Ok(body) = serde_json::to_string(&self.data) {
            if fs::write(&tmp, body).is_ok() {
                let _ = fs::rename(&tmp, &self.path);
            }
        }
    }

    pub fn upsert_card(&mut self, card: MistakeCard) {
        self.data
            .blob_shas
            .insert(card.file_path.clone(), card.last_modified.clone());
        self.data.cards.insert(card.id.clone(), card);
    }

    pub fn all_cards(&self) -> Vec<MistakeCard> {
        self.data.cards.values().cloned().collect()
    }

    pub fn bump_reviewed(&mut self, date_key: &str) {
        *self.data.reviewed_dates.entry(date_key.into()).or_insert(0) += 1;
    }

    pub fn reviewed_on(&self, date_key: &str) -> i64 {
        *self.data.reviewed_dates.get(date_key).unwrap_or(&0)
    }
}
