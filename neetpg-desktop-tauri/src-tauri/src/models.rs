//! Shared data shapes. Serialized camelCase to match the React frontend's
//! `types.ts` one-for-one; `sessions/*.json` files written by the Android app
//! use snake_case, covered by serde aliases.

use serde::{Deserialize, Serialize};
use std::collections::HashMap;

#[derive(Debug, Clone, Serialize, Deserialize, Default)]
#[serde(rename_all = "camelCase")]
pub struct Attempt {
    #[serde(default)]
    pub date: String,
    #[serde(default)]
    pub answer: String,
    #[serde(default)]
    pub correct: bool,
    #[serde(default)]
    pub time_taken: String,
    #[serde(default)]
    pub context: String,
}

#[derive(Debug, Clone, Serialize, Deserialize, Default)]
#[serde(rename_all = "camelCase")]
pub struct MistakeCard {
    pub id: String,
    #[serde(default)]
    pub subject: String,
    #[serde(default)]
    pub topic: String,
    #[serde(default)]
    pub source_file: String,
    #[serde(default)]
    pub tags: Vec<String>,
    #[serde(default)]
    pub error_type: String,
    #[serde(default)]
    pub first_wrong: String,
    #[serde(default)]
    pub last_wrong: String,
    #[serde(default)]
    pub times_wrong: i64,
    #[serde(default)]
    pub times_correct: i64,
    #[serde(default)]
    pub is_resolved: bool,
    #[serde(default)]
    pub question: String,
    #[serde(default)]
    pub options: Vec<String>,
    #[serde(default)]
    pub user_answer: String,
    #[serde(default)]
    pub correct_answer: String,
    #[serde(default)]
    pub key_fact: String,
    #[serde(default)]
    pub why_wrong: String,
    #[serde(default)]
    pub attempts: Vec<Attempt>,
    #[serde(default)]
    pub fact_heading: String,
    #[serde(default)]
    pub fact_points: Vec<String>,
    /// AI-generated display fields for the ambient insight card.
    #[serde(default)]
    pub display_hook: String,
    #[serde(default)]
    pub display_compare: String,
    #[serde(default)]
    pub display_mnemonic: String,
    #[serde(default)]
    pub file_path: String,
    #[serde(default)]
    pub last_modified: String,
    #[serde(default = "default_sr_status")]
    pub sr_status: String,
    #[serde(default)]
    pub next_review: String,
}

fn default_sr_status() -> String {
    "new".into()
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct SRCard {
    pub easiness_factor: f64,
    pub interval_days: i64,
    pub repetitions: i64,
    #[serde(default)]
    pub next_review: String,
    #[serde(default)]
    pub last_grade: i64,
    #[serde(default = "default_sr_status")]
    pub status: String,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub updated_at: Option<String>,
}

impl Default for SRCard {
    fn default() -> Self {
        Self {
            easiness_factor: 2.5,
            interval_days: 0,
            repetitions: 0,
            next_review: String::new(),
            last_grade: 0,
            status: "new".into(),
            updated_at: None,
        }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize, Default)]
#[serde(rename_all = "camelCase")]
pub struct SRState {
    #[serde(default)]
    pub last_updated: String,
    #[serde(default)]
    pub cards: HashMap<String, SRCard>,
}

#[derive(Debug, Clone, Serialize, Deserialize, Default)]
#[serde(rename_all = "camelCase")]
pub struct TopicScores {
    #[serde(default)]
    pub last_updated: String,
    #[serde(default)]
    pub scores: HashMap<String, f64>,
}

/// Session logs are written snake_case by the Android app; accept both.
#[derive(Debug, Clone, Serialize, Deserialize, Default)]
#[serde(rename_all = "camelCase")]
pub struct SessionLog {
    #[serde(alias = "session_id")]
    pub session_id: String,
    #[serde(default, rename = "type")]
    pub session_type: String,
    #[serde(default, alias = "started_at")]
    pub started_at: String,
    #[serde(default, alias = "ended_at")]
    pub ended_at: String,
    #[serde(default, alias = "total_questions")]
    pub total_questions: i64,
    #[serde(default)]
    pub correct: i64,
    #[serde(default)]
    pub wrong: i64,
    #[serde(default)]
    pub skipped: i64,
    #[serde(default, alias = "score_percent")]
    pub score_percent: f64,
    #[serde(default, alias = "subject_breakdown")]
    pub subject_breakdown: Vec<SubjectScore>,
}

#[derive(Debug, Clone, Serialize, Deserialize, Default)]
#[serde(rename_all = "camelCase")]
pub struct SubjectScore {
    #[serde(default)]
    pub subject: String,
    #[serde(default)]
    pub total: i64,
    #[serde(default)]
    pub correct: i64,
    #[serde(default)]
    pub wrong: i64,
    #[serde(default)]
    pub skipped: i64,
}

#[derive(Debug, Clone, Serialize, Deserialize, Default)]
#[serde(rename_all = "camelCase")]
pub struct ParseError {
    pub path: String,
    pub reason: String,
}

#[derive(Debug, Clone, Serialize, Deserialize, Default)]
#[serde(rename_all = "camelCase")]
pub struct SyncStatus {
    pub last_sync: Option<String>,
    pub last_error: Option<String>,
    pub in_progress: bool,
    pub total_cards: usize,
    #[serde(default)]
    pub phase: String,
    #[serde(default)]
    pub parse_errors: Vec<ParseError>,
}

#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct TopicRow {
    pub name: String,
    pub total: i64,
    pub wrong: i64,
    pub pct: i64,
}

#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct SessionPoint {
    pub date: String,
    pub score: f64,
}

#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct DashboardStats {
    pub due: usize,
    pub reviewed: i64,
    pub total: usize,
    pub unresolved: usize,
    pub resolved: usize,
    pub streak_days: i64,
    pub by_status: HashMap<String, i64>,
    pub topics: Vec<TopicRow>,
    pub sessions: Vec<SessionPoint>,
    pub stubborn: Vec<MistakeCard>,
}

#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct CardImage {
    pub card_id: String,
    pub status: String, // ready | pending | error | disabled
    pub data_url: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub message: Option<String>,
}

#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct ImageQuota {
    pub date: String,
    pub used: i64,
    pub limit: i64,
    pub blocked_until: Option<String>,
}

#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct ImageReportEntry {
    pub card_id: String,
    pub subject: String,
    pub topic: String,
    pub heading: String,
    pub status: String, // ready | queued | error | blocked
    #[serde(skip_serializing_if = "Option::is_none")]
    pub error: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub generated_at: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub from_repo: Option<bool>,
}

#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct ImageReport {
    pub quota: ImageQuota,
    pub total: usize,
    pub ready: usize,
    pub queued: usize,
    pub errors: usize,
    pub entries: Vec<ImageReportEntry>,
}

#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct AppInfo {
    pub version: String,
    pub runtime: String,
    pub platform: String,
}

#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct TestResult {
    pub ok: bool,
    pub message: String,
}

pub fn today_key() -> String {
    chrono::Local::now().format("%Y-%m-%d").to_string()
}

pub fn now_iso() -> String {
    chrono::Utc::now().to_rfc3339_opts(chrono::SecondsFormat::Millis, true)
}
