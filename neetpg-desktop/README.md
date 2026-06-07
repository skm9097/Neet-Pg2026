# NEET PG Desktop — Study Companion

A calm, always-on Windows desktop app that turns the mistakes you make on your
phone into an ambient, spaced-repetition study loop on your 27" monitor.

It is the third part of the NEET PG Learning Loop:

```
Android app (study + capture)  →  GitHub repo (sync)  →  Desktop app (review)
        you get a Q wrong              mistakes/*.md           this app
```

When you answer a question wrong on the [Android app](../neet-study-suite), it
enriches the mistake with an LLM and pushes a markdown file to this repo. This
desktop app pulls those files and shows them to you all day — as a screensaver,
as quiz pop-ups, and as an analytics dashboard.

---

## The four screens

| Screen | What it does |
|---|---|
| **Ambient** | Full-screen screensaver that cycles your mistake cards — bold heading, scannable bullet points, and a "what went wrong" note. Auto-advances; `←` `→` navigate, `Space` pauses. Appears automatically when you're idle. |
| **Quiz Interrupt** | A modal that quizzes you on a due card. Wrong answers force a 15-second read-through of the key fact (plus an LLM mnemonic if you've missed it before). Correct answers flash green and dismiss. |
| **Dashboard** | Score trend, spaced-repetition queue breakdown, topic-weakness bars, and your most stubborn questions. `Ctrl+Shift+N`. |
| **Settings** | GitHub sync, Groq AI, display tweaks, review timing, and system/permission controls. |

A slim nav rail on the left switches screens; it auto-hides in ambient mode and
reappears on mouse movement. The app lives in the system tray and keeps syncing
in the background.

---

## How it integrates with the repo

This app talks to GitHub over the **REST API** — it does **not** clone the repo
(the repo carries 600 MB+ of APK releases the desktop never needs, and this way
you don't need `git` installed on Windows).

**Reads** (every `syncIntervalMinutes`, default 5):
- `mistakes/{subject}/*.md` — parsed into cards (YAML frontmatter + body).
- `sessions/*.json` — feed the dashboard score trend.

**Writes** (after each quiz grade, if a token with write scope is set):
- `progress/sr-state.json` — SM-2 spaced-repetition state.
- `progress/topic-scores.json` — per-subject weakness scores.

Change detection uses each file's git blob SHA, so only new/changed files are
fetched. A public repo can be read with no token at all; a token is only needed
for private repos or to push progress back.

---

## Build & install on Windows 11

> Requires [Node.js 18+](https://nodejs.org) (LTS). No C++ build tools or `git`
> required — the app uses no native modules.

```powershell
cd neetpg-desktop
npm install
npm run build:win
```

The installer is written to `dist/NEET PG Desktop Setup <version>.exe`. Run it,
pick an install folder, and launch. On first run you'll be asked for:

1. **Repository owner / name / branch** (defaults to `skm9097 / Neet-Pg2026 / main`)
2. **GitHub Personal Access Token** — optional for a public repo; needs
   `contents: write` if you want progress synced back.
3. **Groq API key** — optional, enables mnemonics & rephrased questions.

You can change all of these later in **Settings**.

### Run in development

```powershell
npm install
npm run dev
```

---

## Settings & permissions

The **System & Permissions** section in Settings controls how the app behaves on
your machine:

| Setting | Effect |
|---|---|
| **Start automatically when Windows boots** | Registers a Windows login item (`app.setLoginItemSettings`), launched hidden to the tray. |
| **Keep running in the tray when window is closed** | Closing the window hides it instead of quitting, so syncing continues. |
| **Show ambient mode automatically when idle** | Uses the OS idle timer (`powerMonitor`) to switch into the screensaver after `idleThreshold` minutes. |
| **Keep the screen awake during ambient mode** | Uses a power-save blocker (`powerSaveBlocker: prevent-display-sleep`) so your review stays visible all day. Turn off to let the monitor sleep normally. |

Other settings: sync interval, quiz interval, daily card target, ambient card
duration, font size, animation speed, accent colour, and background theme.

---

## Keyboard shortcuts

| Shortcut | Action |
|---|---|
| `Ctrl+Shift+M` | Show ambient mode (fullscreen) |
| `Ctrl+Shift+N` | Open the dashboard |
| `←` / `→` | Previous / next card (ambient) |
| `Space` | Pause / resume cycling (ambient) |

---

## Architecture

```
src/
├── main/                  Electron main process (Node)
│   ├── index.ts           App entry — window, tray, timers, idle/quiz loop
│   ├── repo-sync.ts       GitHub REST API: list tree, fetch files, push progress
│   ├── syncer.ts          One sync cycle: fetch → parse → cache → enrich → push
│   ├── file-parser.ts     Mistake .md (YAML + markdown) → MistakeCard
│   ├── cache.ts           JSON-file card/SR/session/LLM cache (no native deps)
│   ├── sr-engine.ts       SM-2 spaced repetition + streak
│   ├── llm-service.ts     Groq API (mnemonics, rephrase, enrich) — all optional
│   ├── idle-detector.ts   OS idle → ambient/active switching
│   ├── power.ts           Wake control + login item
│   ├── tray.ts            System tray menu
│   ├── stats.ts           Dashboard aggregation
│   └── ipc-handlers.ts    Typed IPC bridge
├── preload/index.ts       contextBridge → window.api
├── renderer/              React UI (matches the Claude Design handoff)
│   └── src/components/     AmbientMode · QuizInterrupt · Dashboard · Settings · Setup
└── shared/types.ts        Types shared across main + renderer
```

The data formats (markdown mistakes, JSON sessions, JSON progress) are exactly
those defined in [`NEETPGLEARNINGLOOPSPEC`](../neet-study-suite) and produced by
the Android app, so the two halves stay in lock-step.

---

## Notes

- **Offline-first.** Sync, LLM, and push all fail silently and retry on the next
  cycle. The local cache is the source of truth for the UI.
- **The app never edits your mistake files** — it only writes to `progress/`
  (and fills in LLM fields for files the phone pushed un-enriched while offline).
- **AI is always optional.** With no Groq key the app works fully; you just don't
  get on-demand mnemonics or rephrased questions.
