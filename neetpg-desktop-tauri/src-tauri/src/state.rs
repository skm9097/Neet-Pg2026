//! Process-wide state managed by Tauri. Config and sync status use std
//! mutexes (never held across await); the cache and image service use tokio
//! mutexes because sync/generation hold them across awaits.

use crate::cache::Cache;
use crate::config::Config;
use crate::images::Images;
use crate::models::SyncStatus;
use std::path::PathBuf;
use std::sync::atomic::AtomicBool;
use std::sync::Mutex;

pub struct App {
    pub config_path: PathBuf,
    pub config: Mutex<Config>,
    pub cache: tokio::sync::Mutex<Cache>,
    /// Images manages its own interior std::sync::Mutex so no lock is ever
    /// held across an await — concurrent commands (report + generate) don't
    /// block each other.
    pub images: Images,
    pub status: Mutex<SyncStatus>,
    pub sync_running: AtomicBool,
    pub http: reqwest::Client,
}

impl App {
    pub fn new(config_dir: PathBuf, data_dir: PathBuf) -> Self {
        let config_path = config_dir.join("config.json");
        let config = crate::config::load(&config_path);
        let cache = Cache::load(&data_dir.join("cache.json"));
        let images = Images::new(&data_dir);
        Self {
            config_path,
            config: Mutex::new(config),
            cache: tokio::sync::Mutex::new(cache),
            images,
            status: Mutex::new(SyncStatus {
                phase: "idle".into(),
                ..Default::default()
            }),
            sync_running: AtomicBool::new(false),
            http: reqwest::Client::builder()
                .timeout(std::time::Duration::from_secs(120))
                .build()
                .expect("http client"),
        }
    }
}
