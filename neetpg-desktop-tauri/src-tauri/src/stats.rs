//! Dashboard aggregations and the smart-review feed ordering.

use crate::cache::Cache;
use crate::models::{today_key, DashboardStats, MistakeCard, SessionPoint, TopicRow};
use crate::sr;
use std::collections::{HashMap, HashSet};

/// Attach live SR status onto a card before sending to the frontend.
pub fn with_sr(mut card: MistakeCard, cache: &Cache) -> MistakeCard {
    if let Some(s) = cache.data.sr.get(&card.id) {
        card.sr_status = s.status.clone();
        card.next_review = s.next_review.clone();
    }
    card
}

pub fn build_stats(cache: &Cache) -> DashboardStats {
    let cards = cache.all_cards();

    let mut by_status: HashMap<String, i64> = HashMap::new();
    for c in &cards {
        let status = cache
            .data
            .sr
            .get(&c.id)
            .map(|s| s.status.clone())
            .unwrap_or_else(|| "new".into());
        *by_status.entry(status).or_insert(0) += 1;
    }

    // Topic weakness — group by the leading segment of the topic label.
    let mut topic_map: HashMap<String, (i64, i64)> = HashMap::new();
    for c in &cards {
        let t = c
            .topic
            .split('—')
            .next()
            .map(str::trim)
            .filter(|s| !s.is_empty())
            .unwrap_or(&c.subject)
            .to_string();
        let e = topic_map.entry(t).or_insert((0, 0));
        e.0 += c.times_wrong + c.times_correct;
        e.1 += c.times_wrong;
    }
    let mut topics: Vec<TopicRow> = topic_map
        .into_iter()
        .map(|(name, (total, wrong))| TopicRow {
            name,
            total,
            wrong,
            pct: if total > 0 { (wrong * 100 + total / 2) / total } else { 0 },
        })
        .collect();
    topics.sort_by(|a, b| b.pct.cmp(&a.pct));
    topics.truncate(8);

    let mut sessions: Vec<SessionPoint> = cache
        .data
        .sessions
        .values()
        .map(|s| SessionPoint {
            date: short_date(if s.ended_at.is_empty() { &s.started_at } else { &s.ended_at }),
            score: s.score_percent,
        })
        .filter(|p| !p.date.is_empty())
        .collect();
    let len = sessions.len();
    if len > 12 {
        sessions.drain(0..len - 12);
    }

    let mut stubborn: Vec<MistakeCard> = cards.iter().filter(|c| !c.is_resolved).cloned().collect();
    stubborn.sort_by(|a, b| b.times_wrong.cmp(&a.times_wrong));
    stubborn.truncate(5);

    let resolved = cards.iter().filter(|c| c.is_resolved).count();

    DashboardStats {
        due: sr::due_count(cache),
        reviewed: cache.reviewed_on(&today_key()),
        total: cards.len(),
        unresolved: cards.len() - resolved,
        resolved,
        streak_days: sr::streak_days(cache),
        by_status,
        topics,
        sessions,
        stubborn,
    }
}

fn short_date(iso: &str) -> String {
    chrono::DateTime::parse_from_rfc3339(iso)
        .map(|d| d.format("%b %d").to_string())
        .unwrap_or_default()
}

/// Smart-review ordering: due (most overdue first) → weakest-subject
/// unresolved → remaining unresolved by recency → fill with everything else.
pub fn build_review_feed(cache: &Cache) -> Vec<MistakeCard> {
    let today = today_key();
    let cards = cache.all_cards();

    let mut ordered: Vec<MistakeCard> = Vec::new();
    let mut seen: HashSet<String> = HashSet::new();
    let push = |c: &MistakeCard, ordered: &mut Vec<MistakeCard>, seen: &mut HashSet<String>| {
        if seen.insert(c.id.clone()) {
            ordered.push(c.clone());
        }
    };

    // Tier 1: due cards, most overdue first.
    let mut due: Vec<&MistakeCard> = cards
        .iter()
        .filter(|c| {
            cache
                .data
                .sr
                .get(&c.id)
                .map(|s| !s.next_review.is_empty() && s.next_review <= today)
                .unwrap_or(false)
        })
        .collect();
    due.sort_by(|a, b| cache.data.sr[&a.id].next_review.cmp(&cache.data.sr[&b.id].next_review));
    for c in due {
        push(c, &mut ordered, &mut seen);
    }

    // Tier 2: weakest-subject unresolved (ratio desc, then count desc).
    let mut agg: HashMap<String, (usize, usize)> = HashMap::new();
    for c in &cards {
        let key = if c.subject.is_empty() { "unknown" } else { &c.subject };
        let e = agg.entry(key.to_string()).or_insert((0, 0));
        e.1 += 1;
        if !c.is_resolved {
            e.0 += 1;
        }
    }
    let mut weak: Vec<(String, f64, usize)> = agg
        .into_iter()
        .filter(|(_, (unresolved, _))| *unresolved > 0)
        .map(|(s, (u, t))| (s, u as f64 / t.max(1) as f64, u))
        .collect();
    weak.sort_by(|a, b| b.1.partial_cmp(&a.1).unwrap_or(std::cmp::Ordering::Equal).then(b.2.cmp(&a.2)));

    let unresolved: Vec<&MistakeCard> = cards.iter().filter(|c| !c.is_resolved).collect();
    for (subject, _, _) in &weak {
        let mut group: Vec<&&MistakeCard> = unresolved
            .iter()
            .filter(|c| {
                let s = if c.subject.is_empty() { "unknown" } else { &c.subject };
                s == subject
            })
            .collect();
        group.sort_by(|a, b| b.last_wrong.cmp(&a.last_wrong));
        for c in group {
            push(c, &mut ordered, &mut seen);
        }
    }

    // Tier 3: remaining unresolved by recency.
    let mut rest = unresolved.clone();
    rest.sort_by(|a, b| b.last_wrong.cmp(&a.last_wrong));
    for c in rest {
        push(c, &mut ordered, &mut seen);
    }

    // Tier 4: everything else (resolved last).
    let mut all: Vec<&MistakeCard> = cards.iter().collect();
    all.sort_by(|a, b| b.last_wrong.cmp(&a.last_wrong));
    for c in all {
        push(c, &mut ordered, &mut seen);
    }

    ordered
}
