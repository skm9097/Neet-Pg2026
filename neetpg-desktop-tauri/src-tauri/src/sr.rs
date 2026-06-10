//! SM-2 spaced repetition over the cache's SR map, plus the per-card
//! newest-wins merge that keeps multiple devices consistent.

use crate::cache::Cache;
use crate::models::{now_iso, today_key, SRCard, SRState};
use chrono::{Duration, Local};

pub fn grade_card(cache: &mut Cache, card_id: &str, grade: i64) -> SRCard {
    let current = cache.data.sr.get(card_id).cloned().unwrap_or_default();
    let mut ef = current.easiness_factor;
    let mut interval = current.interval_days;
    let mut reps = current.repetitions;

    if grade >= 3 {
        interval = match reps {
            0 => 1,
            1 => 6,
            _ => ((interval as f64) * ef).round() as i64,
        };
        reps += 1;
    } else {
        reps = 0;
        interval = 1;
    }

    let g = grade as f64;
    ef = (ef + (0.1 - (5.0 - g) * (0.08 + (5.0 - g) * 0.02))).max(1.3);

    let status = if grade < 3 && current.status == "review" {
        "relearning"
    } else if interval > 30 && reps >= 5 {
        "mature"
    } else if reps >= 3 && interval > 7 {
        "review"
    } else {
        "learning"
    };

    let next = (Local::now() + Duration::days(interval)).format("%Y-%m-%d").to_string();
    let updated = SRCard {
        easiness_factor: ef,
        interval_days: interval,
        repetitions: reps,
        next_review: next,
        last_grade: grade,
        status: status.into(),
        updated_at: Some(now_iso()),
    };

    cache.data.sr.insert(card_id.into(), updated.clone());
    cache.bump_reviewed(&today_key());
    cache.save();
    updated
}

/// Merge a remote progress/sr-state.json per card, newest-wins. Returns the
/// number of cards adopted from remote.
pub fn merge_remote(cache: &mut Cache, remote: &SRState) -> usize {
    let mut adopted = 0;
    for (card_id, remote_card) in &remote.cards {
        let take = match cache.data.sr.get(card_id) {
            None => true,
            Some(local) => match (&remote_card.updated_at, &local.updated_at) {
                (Some(r), Some(l)) => r > l,
                (Some(_), None) => true,
                _ => remote_card.repetitions > local.repetitions,
            },
        };
        if take {
            cache.data.sr.insert(card_id.clone(), remote_card.clone());
            adopted += 1;
        }
    }
    adopted
}

pub fn export_state(cache: &Cache) -> SRState {
    SRState {
        last_updated: now_iso(),
        cards: cache.data.sr.clone(),
    }
}

/// Next card to quiz on: overdue → new → random unresolved.
pub fn next_card_id(cache: &Cache) -> Option<String> {
    let today = today_key();
    let cards: Vec<_> = cache.data.cards.values().filter(|c| !c.is_resolved).collect();

    let mut due: Vec<_> = cards
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
    due.sort_by(|a, b| {
        let na = &cache.data.sr[&a.id].next_review;
        let nb = &cache.data.sr[&b.id].next_review;
        na.cmp(nb)
    });
    if let Some(c) = due.first() {
        return Some(c.id.clone());
    }

    if let Some(c) = cards.iter().find(|c| !cache.data.sr.contains_key(&c.id)) {
        return Some(c.id.clone());
    }

    if cards.is_empty() {
        None
    } else {
        // Cheap deterministic-ish pick without a rand dependency.
        let idx = (chrono::Utc::now().timestamp_millis() as usize) % cards.len();
        Some(cards[idx].id.clone())
    }
}

pub fn due_count(cache: &Cache) -> usize {
    let today = today_key();
    cache
        .data
        .cards
        .values()
        .filter(|c| !c.is_resolved)
        .filter(|c| match cache.data.sr.get(&c.id) {
            Some(s) => !s.next_review.is_empty() && s.next_review <= today,
            None => true, // new cards count as due
        })
        .count()
}

pub fn streak_days(cache: &Cache) -> i64 {
    let mut streak = 0;
    let mut day = Local::now();
    loop {
        let key = day.format("%Y-%m-%d").to_string();
        if cache.reviewed_on(&key) > 0 {
            streak += 1;
            day -= Duration::days(1);
        } else if streak == 0 && key == today_key() {
            // Allow today to be empty without breaking an existing streak.
            day -= Duration::days(1);
        } else {
            break;
        }
    }
    streak
}
