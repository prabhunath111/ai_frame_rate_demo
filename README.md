# Don't Let Your AI Feature Wreck Your Frame Rate — Demo (Real AI, Gemini free tier)

A Flutter app built as a live-demo companion for a talk about keeping AI
features from janking your app's UI. This version uses a **real Google
Gemini API call and a real response** — no timers, no dummy sleeps, no fake
loops. Gemini's free tier needs no credit card, which makes it a good fit
for a conference demo.

## Get a free API key

1. Go to https://aistudio.google.com/apikey
2. Sign in with a Google account and click "Create API key".
3. No credit card required for the free tier.
4. Free-tier limits for `gemini-2.5-flash` are roughly 10-15 requests/minute
   and several hundred requests/day as of writing — plenty for a demo. If
   you ever hit a 429 error, just wait a minute and try again, or check your
   exact current limits on the AI Studio dashboard (Google adjusts these
   over time). If `gemini-2.5-flash` is ever retired, swap the model field
   in the app for whatever current free-tier flash model AI Studio lists.

## What it actually does

1. You paste your free Gemini API key and a prompt, and tap **"Send prompt
   to Gemini (real API call)"**. This is a genuine network request to
   `https://generativelanguage.googleapis.com` and returns Gemini's real
   answer. (Network I/O is async in Dart, so this step alone never blocks
   the UI.)

2. Once you have a real response, you analyze it — for real. The app runs a
   **Levenshtein-distance fuzzy word checker** (`lib/text_analysis.dart`)
   that scans every uncommon word in the actual response against a real
   dictionary of common English words (`lib/common_words.dart`) and flags
   likely typos / unusual terms — the same core technique real spell-checkers
   use. This is genuinely CPU-heavy — the cost scales with how long and
   technical the real response is, not with any artificial delay.

3. You can run that analysis two ways:
   - **"Analyze (Main Thread) — BAD"**: calls the analysis function directly
     on the UI isolate. Watch the spinner freeze and the FPS counter stall
     while it churns through the real text.
   - **"Analyze (Background Isolate) — GOOD"**: calls the exact same
     function via `compute()`, which runs it on a background isolate. Same
     real data, same real algorithm — the UI just stays smooth.

A live FPS counter (driven by `SchedulerBinding`'s persistent frame
callback) and a spinning box make the freeze/no-freeze contrast obvious on
stage.

## How to run

```bash
flutter pub get
flutter run
```

Run in profile mode for the most honest frame-rate numbers on stage:

```bash
flutter run --profile
```

Paste your free Gemini API key into the app at runtime — it's kept in
memory only for the session, never hardcoded or logged. Do **not** ship a
real client app with a raw API key baked in; in production, call Gemini
from your own backend instead.

## Tuning for a good demo

- **For a bigger jank effect:** ask for a longer, more technical response
  (the default prompt already asks for 800-1000 words). Longer/more
  technical responses contain more uncommon words, which means more
  Levenshtein comparisons against the dictionary — more real work, more
  visible freeze.
- **Platform note:** this works on iOS/Android/macOS/Windows/Linux builds.
  Flutter **Web** builds may hit a CORS error calling the Gemini API
  directly — that's a good talking point about why you'd proxy AI calls
  through your own backend anyway.

## Project structure

```
ai_frame_rate_demo/
├── pubspec.yaml
└── lib/
    ├── main.dart           # UI, FPS counter, spinner, main-thread vs isolate buttons
    ├── gemini_service.dart # Real HTTP call to the Gemini API (free tier)
    ├── text_analysis.dart  # Real Levenshtein-based analysis (the heavy work)
    └── common_words.dart   # Real dictionary used for the fuzzy matching
```

No native platform folders (android/ios) are included to keep the download
small. Run `flutter create .` inside the project folder once to generate
them if you need to build for a physical device or emulator.
