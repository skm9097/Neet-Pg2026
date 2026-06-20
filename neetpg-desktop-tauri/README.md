# NEET PG Desktop v2 — Tauri edition

Full rewrite of the desktop study companion on **Tauri 2** (Rust core + Windows
WebView2), replacing the Electron app in `../neetpg-desktop/`. Same features,
different engine:

| | Electron (v1.x) | Tauri (v2.x) |
|---|---|---|
| Installer size | ~76 MB | ~10 MB |
| Memory | bundled Chromium (~300 MB+) | system WebView2 (~80 MB) |
| Backend | Node.js (TypeScript) | Rust |
| Secrets (PAT / API tokens) | Node main process | Rust core, never enters the webview |
| Webview rights | Node off, but full IPC surface | capability-scoped: own commands + own window only, strict CSP |
| Error handling | try/catch, some silent paths | `Result` end-to-end; failures recorded and surfaced |

## Features (parity with v1.5)

- GitHub sync of `mistakes/` + `sessions/` (blob-sha change detection, backoff
  retry, truncation detection, offline-tolerant: cache keeps serving)
- SM-2 spaced repetition with cross-device merge via `progress/sr-state.json`
- Smart review feed (due → weakest topics → recent → fill)
- Ambient fullscreen review, dashboard analytics, timed quiz interrupts
- Groq enrichment (key fact / why wrong / mnemonics) with repo write-back
- Card images via **Cloudflare Workers AI** (or Gemini API / Pollinations) with
  the 20-per-day budget, 24-hour rate-limit back-off, image review screen, and
  the `card-images/` repo store (generate once, fetch anywhere)
- Tray, single-instance, autostart, global shortcuts (Ctrl+Shift+N / M),
  idle → ambient, keep-awake
- **Dropped:** the Electron-only "Gemini website sign-in" image source (it
  drove a hidden Chromium window, which Tauri's webview model deliberately
  doesn't allow). Cloudflare / Gemini API / Pollinations remain.

## Layout

```
src/            React UI (same components as v1, talking to Rust via src/api.ts)
src-tauri/src/  Rust core
  config.rs     settings store          repo.rs    GitHub REST client
  cache.rs      local card/SR store     llm.rs     Groq enrichment
  parser.rs     mistake .md parser      images.rs  generation + budget + repo store
  md_builder.rs enrichment write-back   syncer.rs  sync orchestration
  sr.rs         SM-2 + device merge     stats.rs   dashboard + review feed
  platform.rs   idle / keep-awake       lib.rs     commands, tray, shortcuts
```

## Building

Windows installer, cross-compiled from Linux:

```bash
./build-windows.sh     # needs: rustup msvc target, cargo-xwin, clang/lld, nsis
```

Native dev (Linux, needs webkit2gtk): `npx tauri dev`
