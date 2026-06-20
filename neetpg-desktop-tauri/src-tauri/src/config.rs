//! App configuration, persisted as JSON in the app config dir. Unknown keys in
//! an existing file are ignored and missing keys take defaults, so upgrades
//! never lose or corrupt settings.

use serde::{Deserialize, Serialize};
use std::fs;
use std::path::Path;

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase", default)]
pub struct Config {
    pub repo_owner: String,
    pub repo_name: String,
    pub repo_branch: String,
    pub github_pat: String,

    pub groq_api_key: String,
    pub enable_mnemonics: bool,
    pub enable_rephrase: bool,

    pub enable_card_images: bool,
    pub show_card_images: bool,
    pub image_provider: String, // cloudflare | gemini | pollinations
    pub gemini_api_key: String,
    pub gemini_image_model: String,
    pub cf_account_id: String,
    pub cf_api_token: String,
    pub cf_image_model: String,
    pub images_per_day: i64,
    pub push_images_to_repo: bool,

    pub sync_interval_minutes: i64,
    pub quiz_interval_minutes: i64,
    pub idle_threshold_minutes: i64,
    pub ambient_card_seconds: i64,
    pub cards_per_day_target: i64,

    pub font_size: i64,
    pub anim_speed: String,
    pub accent_hue: String,
    pub theme_variant: String,

    pub start_on_boot: bool,
    pub minimize_to_tray: bool,
    pub auto_ambient_on_idle: bool,
    pub keep_awake_in_ambient: bool,

    pub configured: bool,
}

impl Default for Config {
    fn default() -> Self {
        Self {
            repo_owner: "skm9097".into(),
            repo_name: "Neet-Pg2026".into(),
            repo_branch: "main".into(),
            github_pat: String::new(),

            groq_api_key: String::new(),
            enable_mnemonics: true,
            enable_rephrase: true,

            enable_card_images: true,
            show_card_images: true,
            image_provider: "cloudflare".into(),
            gemini_api_key: String::new(),
            gemini_image_model: "gemini-2.5-flash-image".into(),
            cf_account_id: String::new(),
            cf_api_token: String::new(),
            cf_image_model: "@cf/black-forest-labs/flux-1-schnell".into(),
            images_per_day: 20,
            push_images_to_repo: true,

            sync_interval_minutes: 5,
            quiz_interval_minutes: 30,
            idle_threshold_minutes: 5,
            ambient_card_seconds: 20,
            cards_per_day_target: 50,

            font_size: 26,
            anim_speed: "normal".into(),
            accent_hue: "blue".into(),
            theme_variant: "midnight".into(),

            start_on_boot: false,
            minimize_to_tray: false,
            auto_ambient_on_idle: true,
            keep_awake_in_ambient: false,

            configured: false,
        }
    }
}

pub fn load(path: &Path) -> Config {
    match fs::read_to_string(path) {
        Ok(raw) => serde_json::from_str(&raw).unwrap_or_default(),
        Err(_) => Config::default(),
    }
}

pub fn save(path: &Path, cfg: &Config) -> Result<(), String> {
    if let Some(dir) = path.parent() {
        fs::create_dir_all(dir).map_err(|e| e.to_string())?;
    }
    let tmp = path.with_extension("json.tmp");
    let body = serde_json::to_string_pretty(cfg).map_err(|e| e.to_string())?;
    fs::write(&tmp, body).map_err(|e| e.to_string())?;
    fs::rename(&tmp, path).map_err(|e| e.to_string())?;
    Ok(())
}
