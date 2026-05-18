# NEET-PG Quiz App

AI-powered Android quiz app that fetches questions from this GitHub repo, reads them aloud, and gives Gemini-powered feedback on your answers.

## Features

- **Voice questions** — question + options spoken automatically on load (Android TTS)
- **4-button quiz** — tap A / B / C / D to answer
- **AI feedback** — Gemini 1.5 Flash explains why you're right or wrong, spoken aloud
- **4 study modes** — By Year (2018–2025), By Subject (19 NBE), Mixed, Custom count
- **NEET marking** — result screen shows +4/−1 net score
- **Full review** — see every question with your answer, correct answer, and explanation

## Setup

### Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) ≥ 3.16
- Android device or emulator (API 21+)
- [Gemini API key](https://aistudio.google.com/app/apikey) (free, optional — app works without it using built-in feedback)

### Steps

```bash
# 1. Create a new Flutter project
flutter create neet_quiz_app
cd neet_quiz_app

# 2. Replace the lib/ folder with this one
cp -r /path/to/this/neet-quiz-app/lib/* lib/

# 3. Replace pubspec.yaml
cp /path/to/this/neet-quiz-app/pubspec.yaml .

# 4. Add internet permission to android/app/src/main/AndroidManifest.xml
#    Inside the <manifest> tag, add:
#    <uses-permission android:name="android.permission.INTERNET"/>

# 5. Install dependencies
flutter pub get

# 6. Run
flutter run
```

### AndroidManifest.xml patch

Open `android/app/src/main/AndroidManifest.xml` and add this line inside `<manifest>`:

```xml
<uses-permission android:name="android.permission.INTERNET"/>
```

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
 ├─ Auto-reads question aloud on load
 ├─ Tap 🔊 to re-read
 ├─ Tap A/B/C/D → buttons turn green/red → AI speaks feedback
 └─ Tap "Next Question" → repeat

Result
 ├─ Score circle + accuracy %
 ├─ NEET marking breakdown (+4/−1)
 └─ "Review All" → full question-by-question review with explanations
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
