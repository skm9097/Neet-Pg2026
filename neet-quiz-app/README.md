# NEET-PG Quiz App

AI-powered Android quiz app that fetches questions from this GitHub repo, reads them aloud, and gives Gemini-powered feedback on your answers.

## Features

- **Voice questions** — question + options spoken on load (Android TTS), with a **toggle to turn voice on/off** (persisted) and a re-read button
- **4-button quiz** — tap A / B / C / D to answer
- **AI feedback** — Gemini 2.0 Flash explains why you're right or wrong, spoken aloud
- **AI detailed explanation** — tap *"Explain in detail with AI"* on any question (or *"Explain with AI"* in review) for a structured breakdown: why the answer is correct, why each distractor is wrong, and a high-yield exam pearl
- **4 study modes** — By Year (2018–2025), By Subject (19 NBE), Mixed, Custom count
- **NEET marking** — result screen shows +4/−1 net score
- **Progress tracking** — home screen shows your accuracy and net score per year/subject across sessions
- **Full review** — see every question with your answer, correct answer, and explanation
- **Image-question filtering** — image-only questions (no image in the text bank) are skipped automatically

## Setup

### Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) ≥ 3.16
- Android device or emulator (**API 24+** — required by the TTS plugin)
- [Gemini API key](https://aistudio.google.com/app/apikey) (free, optional — app works without it using built-in feedback)

### Build (the `android/` folder is committed, so no scaffolding needed)

```bash
cd neet-quiz-app
flutter pub get
flutter build apk --release      # → build/app/outputs/flutter-apk/app-release.apk
# or run on a connected device:
flutter run
```

A prebuilt APK is available in [`../releases/`](../releases/) (`neet-pg-quiz-v1.2.0.apk`).

The Android manifest already declares the required permissions
(`INTERNET` for fetching questions + Gemini, `RECORD_AUDIO` for the voice
tutor) and `minSdk` is set to 24.

### Gemini API Key

Enter your key in the app via the **⚙ Settings** icon (top-right on home screen).  
The key is stored locally on your device using SharedPreferences — never sent anywhere except the Gemini API.

## App Flow

```
Home
 ├─ By Year → pick year + count → Quiz
 ├─ By Subject → pick subject + count → Quiz
 ├─ Mixed → pick count → Quiz (fetches from multiple years)
 └─ Custom → pick type + count → Quiz

Quiz
 ├─ Auto-reads question aloud on load (if voice on)
 ├─ Tap 🔊 to toggle voice on/off · ↻ to re-read
 ├─ Tap A/B/C/D → buttons turn green/red → AI speaks feedback
 ├─ Tap "Explain in detail with AI" → structured Gemini explanation
 └─ Tap "Next Question" → repeat

Result
 ├─ Score circle + accuracy %
 ├─ NEET marking breakdown (+4/−1)
 ├─ Saves progress (per year/subject) → shown on Home
 └─ "Review All" → per-question review + "Explain with AI" on each
```

## Project Structure

```
lib/
├── main.dart                    # App entry point, singleton setup
├── models/
│   ├── question.dart            # Question data class
│   └── quiz_config.dart         # Module type + count config
├── services/
│   ├── github_service.dart      # Fetches .md files from GitHub raw
│   ├── markdown_parser.dart     # Parses NEET-PG markdown format → Question objects
│   ├── gemini_service.dart      # Gemini 1.5 Flash API calls
│   └── tts_service.dart         # Android TTS wrapper
└── screens/
    ├── home_screen.dart         # Module selector + API key settings
    ├── quiz_screen.dart         # Main quiz UI + answer logic
    └── result_screen.dart       # Score + review
```

## Troubleshooting

| Problem | Fix |
|---------|-----|
| "Could not load questions" | Check internet connection; GitHub raw URLs require network |
| No voice / TTS not working | Ensure device TTS engine is installed (Settings → Accessibility → TTS) |
| Gemini returns error | Verify API key is correct and has quota; app falls back to built-in feedback |
| Questions not parsing | Some questions in raw-dump/staging may lack all 4 options — they are silently skipped |
