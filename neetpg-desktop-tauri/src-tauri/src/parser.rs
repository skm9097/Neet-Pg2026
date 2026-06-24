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
    let fact_heading = derive_heading(&topic, &key_fact);
    let fact_points = derive_bullets(&key_fact, &fact_heading);

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
        fact_heading,
        fact_points,
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
        return title_case(&t.replace(['-', '_'], " "));
    }
    let first = clean_fact(&first_sentence(key_fact));
    if first.is_empty() {
        "Key Fact".into()
    } else {
        truncate_words(&first, 50)
    }
}

pub fn derive_bullets(key_fact: &str, heading: &str) -> Vec<String> {
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
    let heading_key: String = heading.to_lowercase().chars().take(40).collect();
    let mut out: Vec<String> = Vec::new();
    for p in parts {
        let c = condense_bullet(&clean_fact(&p));
        if c.chars().count() < 8 {
            continue;
        }
        let key: String = c.to_lowercase().chars().take(40).collect();
        if !heading_key.is_empty() && (key.starts_with(&heading_key) || heading_key.starts_with(&key)) {
            continue;
        }
        if out.iter().any(|o: &String| {
            let ok: String = o.to_lowercase().chars().take(40).collect();
            ok == key
        }) {
            continue;
        }
        out.push(c);
        if out.len() >= 3 {
            break;
        }
    }
    out
}

fn title_case(s: &str) -> String {
    s.split_whitespace()
        .map(|w| {
            let mut c = w.chars();
            match c.next() {
                Some(f) => f.to_uppercase().collect::<String>() + c.as_str(),
                None => String::new(),
            }
        })
        .collect::<Vec<_>>()
        .join(" ")
}

/// Condense a verbose sentence into a short, scannable bullet (max ~90 chars).
fn condense_bullet(s: &str) -> String {
    static FILLER_RE: OnceLock<Regex> = OnceLock::new();
    let re = FILLER_RE.get_or_init(|| {
        Regex::new(r"(?i)\b(this is because|this concept is|this is crucial|which (is|are) (a |an |the )?|it is (a |an |the )?(important|crucial|essential|key|notable|significant) (concept |fact )?(that |in |for )?|due to (the fact that|its)|allowing for|which together)\b").unwrap()
    });
    let cleaned = re.replace_all(s.trim(), " ");
    let cleaned = cleaned
        .split_whitespace()
        .collect::<Vec<_>>()
        .join(" ");
    let trimmed = cleaned.trim().trim_end_matches(['.', ',', ';']);
    if trimmed.chars().count() <= 90 {
        capitalize_first(trimmed)
    } else {
        truncate_words(trimmed, 90)
    }
}

fn capitalize_first(s: &str) -> String {
    let s = s.trim();
    let mut c = s.chars();
    match c.next() {
        Some(f) => f.to_uppercase().collect::<String>() + c.as_str(),
        None => String::new(),
    }
}

/// Strip "The correct answer is D) …" style boilerplate so headings and
/// bullets lead with the actual medical fact instead of quiz mechanics.
fn clean_fact(s: &str) -> String {
    static BOILER_RE: OnceLock<Regex> = OnceLock::new();
    let re = BOILER_RE.get_or_init(|| {
        Regex::new(r"(?i)^\s*(the\s+)?(correct\s+)?answer\s+(is|was)\s*[:\-]?\s*(option\s*)?([A-Da-d][).:]\s*)?")
            .unwrap()
    });
    let cleaned = re.replace(s.trim(), "").trim().to_string();
    let mut c = cleaned.chars();
    match c.next() {
        Some(f) => f.to_uppercase().collect::<String>() + c.as_str(),
        None => cleaned,
    }
}

/// Truncate to ~max chars on a word boundary, dropping trailing punctuation.
fn truncate_words(s: &str, max: usize) -> String {
    let s = s.trim().trim_end_matches(['.', ',', ';']);
    if s.chars().count() <= max {
        return s.to_string();
    }
    let mut out = String::new();
    for w in s.split_whitespace() {
        if !out.is_empty() && out.chars().count() + w.chars().count() + 1 > max {
            break;
        }
        if !out.is_empty() {
            out.push(' ');
        }
        out.push_str(w);
    }
    if out.is_empty() {
        s.chars().take(max).collect()
    } else {
        out + "…"
    }
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
