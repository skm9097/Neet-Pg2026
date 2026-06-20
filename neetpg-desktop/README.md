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
| **Ambient** | Full-screen screensaver in an editorial layout — bold heading and scannable bullets on the left, an **AI-generated infographic image** on the right, and a "what went wrong" note below. Auto-advances; `←` `→` navigate, `Space` pauses. Appears automatically when you're idle. |
| **Quiz Interrupt** | A modal that quizzes you on a due card. Wrong answers force a 15-second read-through of the key fact (with the card's generated visual and an LLM mnemonic if you've missed it before). Correct answers flash green and dismiss. |
| **Dashboard** | Score trend, spaced-repetition queue breakdown, topic-weakness bars, and your most stubborn questions. `Ctrl+Shift+N`. |
| **Settings** | GitHub sync, Groq AI, AI card visuals (Gemini), display tweaks, review timing, and system/permission controls. |

A slim nav rail floats over the content (it never pushes the layout). On **every**
screen a small menu button toggles the rail; both the button and the rail fade
after a few seconds of no activity and reappear on mouse/keyboard movement. The
app lives in the system tray and keeps syncing in the background.

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

## AI infographic visuals

Instead of a wall of text, every card carries a **visual** on the right of the
ambient slide. The image is generated from the card's own deck data (subject,
topic, key fact, correct answer) and **cached on disk** in
`…/AppData/Roaming/neetpg-desktop/card-images/` — keyed by a content hash and
indexed by question id in `cache-index.json` — so each card's picture is created
**once** and reused forever, never re-generated on every loop.

Three image sources, picked in **Settings → AI Visuals**:

- **Gemini (sign in)** — *default*. You log into your own Google account once
  (a normal browser window opens); the app then quietly drives the **Gemini
  website** to generate each image, using your existing Gemini access — no API
  key and no billing. This is browser automation of a third-party site for
  personal use: it's best-effort (Google can change the page or rate-limit), so
  it fails soft to a placeholder and retries later.
- **API key** — the Gemini image API directly (`gemini-2.5-flash-image` by
  default, model id editable). Needs an `AIza…` key and image quota.
- **Free (no key)** — Pollinations, a keyless HTTP image service.

Other behaviour:

- **Prompting** — a clean, labelled, text-free medical illustration on a dark
  background (AI renders garbled words, so text is deliberately excluded).
- **Pre-generation** — upcoming cards are warmed each sync cycle (gently for the
  web source), so the visual is ready before the card rotates in.
- **Graceful fallback** — while generating, or if visuals are off / you're not
  signed in / no key is set, a calm subject-tinted placeholder with a short hint
  is shown — never a blank box or a spinner that breaks the screensaver feel.
- **Storage cap** — the cache is trimmed to the most recent 600 images.

Turn the whole feature off (plain placeholders) with one toggle in **Settings →
AI Visuals**.

---

## Install (prebuilt)

A ready-to-run installer is in the repo at
[`releases/NEET-PG-Desktop-Setup-1.2.0.exe`](../releases). Download it, run it,
pick an install folder, and launch. (Windows SmartScreen may warn because the
installer isn't code-signed — choose **More info → Run anyway**.)

## Build it yourself on Windows 11

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
4. **Gemini API key** — optional, only for the *API key* image source. The
   default image source is **Gemini (sign in)** — set that up in **Settings →
   AI Visuals** by signing into your Google account once.

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
│   ├── image-gen.ts       Per-card infographic images (provider router) + disk cache + index
│   ├── gemini-web.ts      Drives the signed-in Gemini website to generate images
│   ├── idle-detector.ts   OS idle → ambient/active switching
│   ├── power.ts           Wake control + login item
│   ├── tray.ts            System tray menu
│   ├── stats.ts           Dashboard aggregation
│   └── ipc-handlers.ts    Typed IPC bridge
├── preload/index.ts       contextBridge → window.api
├── renderer/              React UI (matches the Claude Design handoff)
│   └── src/components/     AmbientMode · CardVisual · QuizInterrupt · Dashboard · Settings · Setup
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
