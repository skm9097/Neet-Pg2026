//! Mistake `.md` parser (YAML frontmatter + markdown body) — the format the
//! Android app writes, defined in SYNC-PROTOCOL.md. Section extraction is
//! procedural (line-based) rather than regex-lookahead, which the regex crate
//! doesn't support; the semantics mirror the previous battle-tested parser.

use crate::models::{Attempt, MistakeCard};
use regex::Regex;
use std::collections::{HashMap, HashSet};
use std::sync::OnceLock;

/// Android writes this placeholder when it pushed without Gemini configured.
/// Treated as empty so desktop enrichment fills it (as the text promises).
fn is_placeholder(text: &str) -> bool {
    text.to_lowercase().contains("not yet analyzed")
}

fn scrub(text: String) -> String {
    if is_placeholder(&text) {
        String::new()
    } else {
        text
    }
}

pub fn parse_mistake_file(raw: &str, file_path: &str, blob_sha: &str) -> Result<MistakeCard, String> {
    let (fm, body) = split_frontmatter(raw);

    let id = fm
        .get("id")
        .map(|s| s.trim().to_string())
        .filter(|s| !s.is_empty())
        .or_else(|| id_from_path(file_path))
        .ok_or("no id in frontmatter or filename")?;

    let subject = fm
        .get("subject")
        .map(|s| s.trim().to_string())
        .filter(|s| !s.is_empty())
        .or_else(|| subject_from_path(file_path))
        .unwrap_or_else(|| "general".into());

    let question = extract_section(&body, "Question");
    if question.is_empty() {
        return Err("missing ## Question section".into());
    }
    let options = extract_options(&body);
    if options.len() < 2 {
        return Err("missing or malformed ## Options".into());
    }

    let key_fact = scrub(extract_section(&body, "Key Fact"));
    let why_wrong = scrub(extract_section(&body, "Why You Got It Wrong"));
    let topic = fm
        .get("topic")
        .map(|s| s.trim().to_string())
        .filter(|s| !s.is_empty())
        .unwrap_or_else(|| subject.clone());

    Ok(MistakeCard {
        id,
        subject: subject.clone(),
        topic: topic.clone(),
        source_file: fm.get("source_file").cloned().unwrap_or_default(),
        tags: parse_array(fm.get("tags").map(String::as_str).unwrap_or("")),
        error_type: normalize_error_type(fm.get("error_type").map(String::as_str).unwrap_or("")),
        first_wrong: fm.get("first_wrong").cloned().unwrap_or_default(),
        last_wrong: fm.get("last_wrong").cloned().unwrap_or_default(),
        times_wrong: to_int(fm.get("times_wrong").map(String::as_str).unwrap_or("")),
        times_correct: to_int(fm.get("times_correct").map(String::as_str).unwrap_or("")),
        is_resolved: fm
            .get("is_resolved")
            .map(|v| v.trim().eq_ignore_ascii_case("true"))
            .unwrap_or(false),
        question,
        options,
        user_answer: extract_section(&body, "Your Answer"),
        correct_answer: extract_section(&body, "Correct Answer"),
        fact_heading: derive_heading(&topic, &key_fact),
        fact_points: derive_bullets(&key_fact),
        key_fact,
        why_wrong,
        attempts: extract_attempts(&body),
        file_path: file_path.into(),
        last_modified: blob_sha.into(),
        sr_status: "new".into(),
        next_review: String::new(),
    })
}

fn split_frontmatter(raw: &str) -> (HashMap<String, String>, String) {
    let text = raw.trim_start_matches('\u{feff}');
    static FM_RE: OnceLock<Regex> = OnceLock::new();
    let re = FM_RE.get_or_init(|| Regex::new(r"(?s)\A---\s*\n(.*?)\n---\s*\n?(.*)\z").unwrap());

    let mut fm = HashMap::new();
    let Some(caps) = re.captures(text) else {
        return (fm, text.to_string());
    };
    static LINE_RE: OnceLock<Regex> = OnceLock::new();
    let line_re = LINE_RE.get_or_init(|| Regex::new(r"^([A-Za-z0-9_]+):\s*(.*)$").unwrap());
    for line in caps[1].lines() {
        if let Some(m) = line_re.captures(line) {
            fm.insert(m[1].to_string(), m[2].trim().to_string());
        }
    }
    (fm, caps[2].to_string())
}

/// Text between `## Name ...` and the next `## ` heading (or end of file).
pub fn extract_section(body: &str, name: &str) -> String {
    let mut out: Vec<&str> = Vec::new();
    let mut capturing = false;
    for line in body.lines() {
        let trimmed = line.trim_start();
        if let Some(rest) = trimmed.strip_prefix("## ") {
            if capturing {
                break;
            }
            if rest.trim_start().starts_with(name) {
                capturing = true;
            }
            continue;
        }
        if capturing {
            out.push(line);
        }
    }
    out.join("\n").trim().to_string()
}

fn extract_options(body: &str) -> Vec<String> {
    static OPT_RE: OnceLock<Regex> = OnceLock::new();
    let re = OPT_RE.get_or_init(|| Regex::new(r"^-\s*[A-D][.)]").unwrap());
    extract_section(body, "Options")
        .lines()
        .map(str::trim)
        .filter(|l| re.is_match(l))
        .map(|l| l.trim_start_matches('-').trim().to_string())
        .collect()
}

fn extract_attempts(body: &str) -> Vec<Attempt> {
    let section = extract_section(body, "Attempts");
    let mut out: Vec<Attempt> = Vec::new();
    let mut seen: HashSet<String> = HashSet::new();
    static SEP_RE: OnceLock<Regex> = OnceLock::new();
    let sep_re = SEP_RE.get_or_init(|| Regex::new(r"^[-:]+$").unwrap());

    for row in section.lines().map(str::trim) {
        if !row.starts_with('|') {
            continue;
        }
        let cells: Vec<&str> = row.split('|').map(str::trim).collect();
        // split('|') yields a leading + trailing empty cell for "| a | b |".
        if cells.len() < 8 {
            continue;
        }
        let first = cells[1];
        if first == "#" || sep_re.is_match(first) {
            continue;
        }
        let result = cells[4].to_lowercase();
        let attempt = Attempt {
            date: cells[2].to_string(),
            answer: cells[3].to_string(),
            correct: cells[4].contains('✅') || result.contains("correct"),
            time_taken: cells[5].to_string(),
            context: cells[6].to_string(),
        };
        let key = format!("{}|{}|{}", attempt.date, attempt.answer, attempt.correct);
        if seen.insert(key) {
            out.push(attempt);
        }
    }
    out
}

pub fn derive_heading(topic: &str, key_fact: &str) -> String {
    let t = topic.trim();
    if !t.is_empty() && !t.eq_ignore_ascii_case("general") {
        // "autonomic-nervous-system" -> "Autonomic Nervous System"
        return t
            .replace(['-', '_'], " ")
            .split_whitespace()
            .map(|w| {
                let mut c = w.chars();
                match c.next() {
                    Some(f) => f.to_uppercase().collect::<String>() + c.as_str(),
                    None => String::new(),
                }
            })
            .collect::<Vec<_>>()
            .join(" ");
    }
    let first = first_sentence(key_fact);
    if first.is_empty() {
        "Key Fact".into()
    } else {
        first.chars().take(70).collect()
    }
}

pub fn derive_bullets(key_fact: &str) -> Vec<String> {
    if key_fact.is_empty() {
        return vec![];
    }
    let mut parts: Vec<String> = key_fact
        .lines()
        .map(|l| l.trim_start_matches(['-', '*', '•']).trim().to_string())
        .filter(|l| !l.is_empty())
        .collect();
    if parts.len() <= 1 {
        parts = split_sentences(key_fact)
            .into_iter()
            .filter(|s| s.len() > 2)
            .collect();
    }
    parts.truncate(4);
    parts
}

fn first_sentence(text: &str) -> String {
    split_sentences(text).into_iter().next().unwrap_or_default()
}

fn split_sentences(text: &str) -> Vec<String> {
    static SENT_RE: OnceLock<Regex> = OnceLock::new();
    let re = SENT_RE.get_or_init(|| Regex::new(r"[^.!?]*[.!?]?\s*").unwrap());
    re.find_iter(text)
        .map(|m| m.as_str().trim().to_string())
        .filter(|s| !s.is_empty())
        .collect()
}

fn parse_array(val: &str) -> Vec<String> {
    let inner = val.trim().trim_start_matches('[').trim_end_matches(']').trim();
    if inner.is_empty() {
        return vec![];
    }
    inner
        .split(',')
        .map(|s| s.trim().trim_matches(|c| c == '"' || c == '\'').to_string())
        .filter(|s| !s.is_empty())
        .collect()
}

fn normalize_error_type(val: &str) -> String {
    match val.trim().to_lowercase().as_str() {
        v @ ("conceptual" | "recall" | "silly") => v.into(),
        _ => String::new(),
    }
}

fn to_int(val: &str) -> i64 {
    val.trim().parse().unwrap_or(0)
}

fn id_from_path(file_path: &str) -> Option<String> {
    static DATED: OnceLock<Regex> = OnceLock::new();
    static BASE: OnceLock<Regex> = OnceLock::new();
    let dated = DATED.get_or_init(|| Regex::new(r"\d{4}-\d{2}-\d{2}_([A-Za-z0-9_-]+)\.md$").unwrap());
    if let Some(c) = dated.captures(file_path) {
        return Some(c[1].to_string());
    }
    let base = BASE.get_or_init(|| Regex::new(r"([A-Za-z0-9_-]+)\.md$").unwrap());
    base.captures(file_path).map(|c| c[1].to_string())
}

fn subject_from_path(file_path: &str) -> Option<String> {
    static RE: OnceLock<Regex> = OnceLock::new();
    let re = RE.get_or_init(|| Regex::new(r"mistakes/([^/]+)/").unwrap());
    re.captures(file_path).map(|c| c[1].to_string())
}
