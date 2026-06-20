//! Groq API wrapper for on-demand content generation. Optional everywhere —
//! the app works fully with no key. A 3-second minimum gap stays under 30 RPM.

use crate::models::MistakeCard;
use std::time::Duration;
use tokio::sync::Mutex;
use tokio::time::Instant;

const URL: &str = "https://api.groq.com/openai/v1/chat/completions";
const MODEL: &str = "llama-3.3-70b-versatile";

pub static LAST_CALL: Mutex<Option<Instant>> = Mutex::const_new(None);

async fn throttle() {
    let mut last = LAST_CALL.lock().await;
    if let Some(t) = *last {
        let elapsed = t.elapsed();
        if elapsed < Duration::from_secs(3) {
            tokio::time::sleep(Duration::from_secs(3) - elapsed).await;
        }
    }
    *last = Some(Instant::now());
}

pub async fn call(
    http: &reqwest::Client,
    api_key: &str,
    prompt: &str,
    max_tokens: u32,
) -> Result<String, String> {
    if api_key.is_empty() {
        return Err("No Groq API key".into());
    }
    throttle().await;

    let res = http
        .post(URL)
        .bearer_auth(api_key)
        .json(&serde_json::json!({
            "model": MODEL,
            "messages": [{ "role": "user", "content": prompt }],
            "temperature": 0.7,
            "max_tokens": max_tokens,
        }))
        .send()
        .await
        .map_err(|e| e.to_string())?;
    if !res.status().is_success() {
        return Err(format!("Groq {}", res.status()));
    }
    let j: serde_json::Value = res.json().await.map_err(|e| e.to_string())?;
    Ok(j.pointer("/choices/0/message/content")
        .and_then(|c| c.as_str())
        .unwrap_or("")
        .trim()
        .to_string())
}

pub async fn test(http: &reqwest::Client, api_key: &str) -> (bool, String) {
    match call(http, api_key, "Reply with the single word: ok", 5).await {
        Ok(out) if !out.is_empty() => (true, format!("Groq reachable ({MODEL})")),
        Ok(_) => (true, "Empty response".into()),
        Err(e) => (false, e),
    }
}

pub async fn generate_mnemonic(http: &reqwest::Client, key: &str, card: &MistakeCard) -> Result<String, String> {
    call(
        http,
        key,
        &format!(
            "A medical student keeps getting this wrong:\nCorrect answer: {}\nKey fact: {}\nWhy they get it wrong: {}\n\nCreate ONE short, memorable mnemonic to help remember this. Just the mnemonic, nothing else.",
            card.correct_answer, card.key_fact, card.why_wrong
        ),
        120,
    )
    .await
}

pub async fn rephrase_question(http: &reqwest::Client, key: &str, card: &MistakeCard) -> Result<String, String> {
    call(
        http,
        key,
        &format!(
            "Rephrase this NEET PG question as a short clinical scenario:\nOriginal: {}\nCorrect answer: {}\n\nGive the new question with 4 options, mark correct with ✅. Nothing else.",
            card.question, card.correct_answer
        ),
        400,
    )
    .await
}

pub async fn generate_comparison(
    http: &reqwest::Client,
    key: &str,
    a: &MistakeCard,
    b: &MistakeCard,
) -> Result<String, String> {
    call(
        http,
        key,
        &format!(
            "A medical student confuses these two concepts:\n1. {}: {}\n2. {}: {}\n\nCreate a brief comparison table (markdown) showing 4-5 key differences. Nothing else.",
            a.correct_answer, a.key_fact, b.correct_answer, b.key_fact
        ),
        400,
    )
    .await
}

pub struct Enrichment {
    pub key_fact: String,
    pub why_wrong: String,
    pub error_type: String,
    pub tags: Vec<String>,
}

/// Fill key_fact/why_wrong/error_type/tags for an un-enriched card.
pub async fn enrich_card(http: &reqwest::Client, key: &str, card: &MistakeCard) -> Option<Enrichment> {
    let raw = call(
        http,
        key,
        &format!(
            "A NEET PG student answered this question wrong.\nQuestion: {}\nOptions: {}\nTheir answer: {}\nCorrect answer: {}\n\nRespond in JSON only, no backticks:\n{{\"key_fact\":\"2-3 sentence explanation\",\"why_wrong\":\"1-2 sentence error analysis\",\"error_type\":\"conceptual | recall | silly\",\"tags\":[\"k1\",\"k2\"]}}",
            card.question,
            card.options.join(", "),
            card.user_answer,
            card.correct_answer
        ),
        400,
    )
    .await
    .ok()?;

    let start = raw.find('{')?;
    let end = raw.rfind('}')?;
    let j: serde_json::Value = serde_json::from_str(&raw[start..=end]).ok()?;
    Some(Enrichment {
        key_fact: j.get("key_fact").and_then(|v| v.as_str()).unwrap_or("").into(),
        why_wrong: j.get("why_wrong").and_then(|v| v.as_str()).unwrap_or("").into(),
        error_type: j.get("error_type").and_then(|v| v.as_str()).unwrap_or("").into(),
        tags: j
            .get("tags")
            .and_then(|v| v.as_array())
            .map(|a| a.iter().filter_map(|t| t.as_str().map(String::from)).collect())
            .unwrap_or_default(),
    })
}
