mod cache;
mod config;
mod images;
mod llm;
mod md_builder;
mod models;
mod parser;
mod platform;
mod repo;
mod sr;
mod state;
mod stats;
mod syncer;

use models::{AppInfo, CardImage, DashboardStats, ImageReport, MistakeCard, SyncStatus, TestResult};
use state::App;
use tauri::menu::{Menu, MenuItem};
use tauri::tray::TrayIconBuilder;
use tauri::{AppHandle, Emitter, Manager, State};
use tauri_plugin_autostart::ManagerExt;

type S<'a> = State<'a, App>;

// ── Config ───────────────────────────────────────────────────────────────────

#[tauri::command]
fn get_config(app: S) -> config::Config {
    app.config.lock().unwrap().clone()
}

#[tauri::command]
fn save_config(app: S, handle: AppHandle, patch: serde_json::Value) -> Result<config::Config, String> {
    let next = {
        let mut cfg = app.config.lock().unwrap();
        // Merge the patch over the current config through JSON so partial
        // updates can't zero out unrelated fields.
        let mut current = serde_json::to_value(&*cfg).map_err(|e| e.to_string())?;
        if let (Some(obj), Some(p)) = (current.as_object_mut(), patch.as_object()) {
            for (k, v) in p {
                obj.insert(k.clone(), v.clone());
            }
        }
        *cfg = serde_json::from_value(current).map_err(|e| e.to_string())?;
        cfg.clone()
    };
    config::save(&app.config_path, &next)?;

    // Apply start-on-boot via the autostart plugin.
    let auto = handle.autolaunch();
    if next.start_on_boot {
        let _ = auto.enable();
    } else {
        let _ = auto.disable();
    }
    Ok(next)
}

// ── Cards / SR / stats ───────────────────────────────────────────────────────

#[tauri::command]
async fn get_cards(app: S<'_>) -> Result<Vec<MistakeCard>, String> {
    let cache = app.cache.lock().await;
    Ok(cache.all_cards().into_iter().map(|c| stats::with_sr(c, &cache)).collect())
}

#[tauri::command]
async fn get_review_feed(app: S<'_>, limit: usize) -> Result<Vec<MistakeCard>, String> {
    let cache = app.cache.lock().await;
    let limit = if limit == 0 { 20 } else { limit };
    Ok(stats::build_review_feed(&cache)
        .into_iter()
        .take(limit)
        .map(|c| stats::with_sr(c, &cache))
        .collect())
}

#[tauri::command]
async fn get_due_cards(app: S<'_>, limit: usize) -> Result<Vec<MistakeCard>, String> {
    get_review_feed(app, limit).await
}

#[tauri::command]
async fn get_next_quiz_card(app: S<'_>) -> Result<Option<MistakeCard>, String> {
    let cache = app.cache.lock().await;
    Ok(sr::next_card_id(&cache)
        .and_then(|id| cache.data.cards.get(&id).cloned())
        .map(|c| stats::with_sr(c, &cache)))
}

#[tauri::command]
async fn grade_card(app: S<'_>, handle: AppHandle, card_id: String, grade: i64) -> Result<(), String> {
    {
        let mut cache = app.cache.lock().await;
        sr::grade_card(&mut cache, &card_id, grade);
    }
    // Push SR progress in the background — never block the UI.
    let has_pat = !app.config.lock().unwrap().github_pat.is_empty();
    if has_pat {
        let h = handle.clone();
        tauri::async_runtime::spawn(async move {
            let st = h.state::<App>();
            let r = syncer::sync(&st, &h).await;
            if r.changed > 0 {
                let _ = h.emit("cards-updated", r.changed);
            }
        });
    }
    Ok(())
}

#[tauri::command]
async fn get_stats(app: S<'_>) -> Result<DashboardStats, String> {
    Ok(stats::build_stats(&*app.cache.lock().await))
}

#[tauri::command]
fn get_app_info(handle: AppHandle) -> AppInfo {
    AppInfo {
        version: handle.package_info().version.to_string(),
        runtime: format!("Tauri {} (WebView2)", tauri::VERSION),
        platform: std::env::consts::OS.into(),
    }
}

// ── Sync ─────────────────────────────────────────────────────────────────────

#[derive(serde::Serialize)]
#[serde(rename_all = "camelCase")]
struct SyncOutcome {
    changed: usize,
    error: Option<String>,
}

#[tauri::command]
async fn sync_now(app: S<'_>, handle: AppHandle) -> Result<SyncOutcome, String> {
    let r = syncer::sync(&app, &handle).await;
    if r.changed > 0 {
        let _ = handle.emit("cards-updated", r.changed);
    }
    // Warm a few images in the background — images has interior locking so
    // this never blocks get_image_report or other commands.
    let cfg = app.config.lock().unwrap().clone();
    if cfg.enable_card_images {
        let h = handle.clone();
        tauri::async_runtime::spawn(async move {
            let st = h.state::<App>();
            let pending: Vec<MistakeCard> = {
                let cache = st.cache.lock().await;
                cache.all_cards().into_iter().filter(|c| !st.images.has_image(c)).collect()
            };
            if !pending.is_empty() {
                let cfg2 = st.config.lock().unwrap().clone();
                st.images.pregenerate(&st.http, &cfg2, &pending, 3).await;
            }
        });
    }
    Ok(SyncOutcome { changed: r.changed, error: r.error })
}

#[tauri::command]
async fn get_sync_status(app: S<'_>) -> Result<SyncStatus, String> {
    let mut st = app.status.lock().unwrap().clone();
    st.total_cards = app.cache.lock().await.data.cards.len();
    Ok(st)
}

// ── LLM ──────────────────────────────────────────────────────────────────────

#[tauri::command]
async fn llm_generate(app: S<'_>, gen_type: String, card_id: String) -> Result<Option<String>, String> {
    let key = format!("{card_id}:{gen_type}");
    let (cached, card, api_key) = {
        let cache = app.cache.lock().await;
        (
            cache.data.llm.get(&key).cloned(),
            cache.data.cards.get(&card_id).cloned(),
            app.config.lock().unwrap().groq_api_key.clone(),
        )
    };
    if let Some(c) = cached {
        return Ok(Some(c));
    }
    let Some(card) = card else { return Ok(None) };
    if api_key.is_empty() {
        return Ok(None);
    }

    let result = match gen_type.as_str() {
        "mnemonic" => llm::generate_mnemonic(&app.http, &api_key, &card).await.ok(),
        "quiz_variant" => llm::rephrase_question(&app.http, &api_key, &card).await.ok(),
        "comparison" => {
            let related = {
                let cache = app.cache.lock().await;
                cache
                    .data
                    .cards
                    .values()
                    .find(|c| c.id != card_id && c.subject == card.subject && c.error_type == "conceptual")
                    .cloned()
            };
            match related {
                Some(b) => llm::generate_comparison(&app.http, &api_key, &card, &b).await.ok(),
                None => None,
            }
        }
        _ => None,
    };

    if let Some(text) = &result {
        if !text.is_empty() {
            let mut cache = app.cache.lock().await;
            cache.data.llm.insert(key, text.clone());
            cache.save();
        }
    }
    Ok(result.filter(|t| !t.is_empty()))
}

// ── Images ───────────────────────────────────────────────────────────────────

#[tauri::command]
async fn get_card_image(app: S<'_>, card_id: String) -> Result<CardImage, String> {
    let cfg = app.config.lock().unwrap().clone();
    let card = app.cache.lock().await.data.cards.get(&card_id).cloned();
    let Some(card) = card else {
        return Ok(CardImage { card_id, status: "error".into(), data_url: None, message: Some("Card not found".into()) });
    };
    if !cfg.enable_card_images {
        return Ok(CardImage { card_id, status: "disabled".into(), data_url: None, message: Some("Card visuals are off".into()) });
    }
    if app.images.has_image(&card) {
        if let Some(url) = app.images.data_url(&card) {
            return Ok(CardImage { card_id, status: "ready".into(), data_url: Some(url), message: None });
        }
    }
    if app.images.generate(&app.http, &cfg, &card, false).await {
        if let Some(url) = app.images.data_url(&card) {
            return Ok(CardImage { card_id, status: "ready".into(), data_url: Some(url), message: None });
        }
    }
    let hint = app.images.error_hint(&cfg, &card);
    Ok(CardImage { card_id, status: "error".into(), data_url: None, message: Some(hint) })
}

#[tauri::command]
async fn get_image_report(app: S<'_>) -> Result<ImageReport, String> {
    let cfg = app.config.lock().unwrap().clone();
    let cards = app.cache.lock().await.all_cards();
    Ok(app.images.report(&cfg, &cards))
}

#[tauri::command]
async fn regenerate_image(app: S<'_>, card_id: String) -> Result<CardImage, String> {
    let cfg = app.config.lock().unwrap().clone();
    let card = app.cache.lock().await.data.cards.get(&card_id).cloned();
    let Some(card) = card else {
        return Ok(CardImage { card_id, status: "error".into(), data_url: None, message: Some("Card not found".into()) });
    };
    if app.images.regenerate(&app.http, &cfg, &card).await {
        if let Some(url) = app.images.data_url(&card) {
            return Ok(CardImage { card_id, status: "ready".into(), data_url: Some(url), message: None });
        }
    }
    let hint = app.images.error_hint(&cfg, &card);
    Ok(CardImage { card_id, status: "error".into(), data_url: None, message: Some(hint) })
}

#[derive(serde::Serialize)]
#[serde(rename_all = "camelCase")]
struct BatchOutcome {
    made: usize,
    message: String,
}

#[tauri::command]
async fn generate_images_now(app: S<'_>) -> Result<BatchOutcome, String> {
    let cfg = app.config.lock().unwrap().clone();
    let pending: Vec<MistakeCard> = {
        let cache = app.cache.lock().await;
        cache.all_cards().into_iter().filter(|c| !app.images.has_image(c)).collect()
    };
    if pending.is_empty() {
        return Ok(BatchOutcome { made: 0, message: "All cards already have images".into() });
    }
    let q = app.images.quota(&cfg);
    if let Some(until) = &q.blocked_until {
        return Ok(BatchOutcome { made: 0, message: format!("Provider limit hit — resumes {until}") });
    }
    let remaining = (q.limit - q.used).max(0) as usize;
    if remaining == 0 {
        return Ok(BatchOutcome { made: 0, message: "Daily budget used — resumes tomorrow".into() });
    }
    let made = app.images.pregenerate(&app.http, &cfg, &pending, remaining).await;
    Ok(BatchOutcome {
        made,
        message: if made > 0 {
            format!("Generated {made} image{}", if made == 1 { "" } else { "s" })
        } else {
            "Nothing generated — check the errors below".into()
        },
    })
}

// ── Connectivity tests ───────────────────────────────────────────────────────

#[tauri::command]
async fn test_github(app: S<'_>) -> Result<TestResult, String> {
    let cfg = app.config.lock().unwrap().clone();
    let (ok, message) = repo::Repo { http: &app.http, cfg: &cfg }.test().await;
    Ok(TestResult { ok, message })
}

#[tauri::command]
async fn test_groq(app: S<'_>) -> Result<TestResult, String> {
    let key = app.config.lock().unwrap().groq_api_key.clone();
    let (ok, message) = llm::test(&app.http, &key).await;
    Ok(TestResult { ok, message })
}

#[tauri::command]
async fn test_image_source(app: S<'_>) -> Result<TestResult, String> {
    let cfg = app.config.lock().unwrap().clone();
    let (ok, message) = app.images.test(&app.http, &cfg).await;
    Ok(TestResult { ok, message })
}

// ── Platform ─────────────────────────────────────────────────────────────────

#[tauri::command]
fn get_idle_seconds() -> u64 {
    platform::idle_seconds()
}

#[tauri::command]
fn set_keep_awake(on: bool) {
    platform::keep_awake(on);
}

// ── App bootstrap ────────────────────────────────────────────────────────────

fn show_main(handle: &AppHandle) {
    if let Some(win) = handle.get_webview_window("main") {
        let _ = win.show();
        let _ = win.set_focus();
    }
}

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    tauri::Builder::default()
        .plugin(tauri_plugin_single_instance::init(|handle, _argv, _cwd| {
            // A second launch focuses the existing window instead of piling up
            // background processes.
            show_main(handle);
        }))
        .plugin(tauri_plugin_autostart::init(
            tauri_plugin_autostart::MacosLauncher::LaunchAgent,
            None,
        ))
        .plugin(tauri_plugin_global_shortcut::Builder::new().build())
        .setup(|app| {
            let config_dir = app.path().app_config_dir()?;
            let data_dir = app.path().app_data_dir()?;
            std::fs::create_dir_all(&config_dir).ok();
            std::fs::create_dir_all(&data_dir).ok();
            app.manage(App::new(config_dir, data_dir));

            // ── Tray ──
            let show_ambient = MenuItem::with_id(app, "ambient", "Show Ambient Mode", true, None::<&str>)?;
            let dashboard = MenuItem::with_id(app, "dashboard", "Open Dashboard", true, None::<&str>)?;
            let settings = MenuItem::with_id(app, "settings", "Settings", true, None::<&str>)?;
            let sync = MenuItem::with_id(app, "sync", "Sync Now", true, None::<&str>)?;
            let quit = MenuItem::with_id(app, "quit", "Quit", true, None::<&str>)?;
            let menu = Menu::with_items(app, &[&show_ambient, &dashboard, &settings, &sync, &quit])?;
            TrayIconBuilder::with_id("main-tray")
                .icon(app.default_window_icon().unwrap().clone())
                .tooltip("NEET PG Desktop")
                .menu(&menu)
                .on_menu_event(|handle, event| match event.id.as_ref() {
                    "ambient" => {
                        show_main(handle);
                        let _ = handle.emit("mode-change", "ambient");
                    }
                    "dashboard" => {
                        show_main(handle);
                        let _ = handle.emit("mode-change", "dashboard");
                    }
                    "settings" => {
                        show_main(handle);
                        let _ = handle.emit("mode-change", "settings");
                    }
                    "sync" => {
                        let _ = handle.emit("tray-sync", ());
                    }
                    "quit" => handle.exit(0),
                    _ => {}
                })
                .build(app)?;

            // ── Global shortcuts ──
            use tauri_plugin_global_shortcut::{Code, GlobalShortcutExt, Modifiers, Shortcut};
            let n = Shortcut::new(Some(Modifiers::CONTROL | Modifiers::SHIFT), Code::KeyN);
            let m = Shortcut::new(Some(Modifiers::CONTROL | Modifiers::SHIFT), Code::KeyM);
            let gs = app.handle().global_shortcut();
            let _ = gs.on_shortcut(n, |handle, _s, event| {
                if event.state == tauri_plugin_global_shortcut::ShortcutState::Pressed {
                    show_main(handle);
                    let _ = handle.emit("mode-change", "dashboard");
                }
            });
            let _ = gs.on_shortcut(m, |handle, _s, event| {
                if event.state == tauri_plugin_global_shortcut::ShortcutState::Pressed {
                    show_main(handle);
                    let _ = handle.emit("mode-change", "ambient");
                }
            });

            Ok(())
        })
        .on_window_event(|window, event| {
            // Close-to-tray only if the user opted in; default is a clean exit
            // that installers/uninstallers can always complete.
            if let tauri::WindowEvent::CloseRequested { api, .. } = event {
                let app = window.app_handle().state::<App>();
                let to_tray = app.config.lock().unwrap().minimize_to_tray;
                if to_tray {
                    api.prevent_close();
                    let _ = window.hide();
                }
            }
        })
        .invoke_handler(tauri::generate_handler![
            get_config,
            save_config,
            get_cards,
            get_due_cards,
            get_review_feed,
            get_next_quiz_card,
            grade_card,
            get_stats,
            get_app_info,
            sync_now,
            get_sync_status,
            llm_generate,
            get_card_image,
            get_image_report,
            regenerate_image,
            generate_images_now,
            test_github,
            test_groq,
            test_image_source,
            get_idle_seconds,
            set_keep_awake
        ])
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}
