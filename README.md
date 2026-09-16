# Don't Let Your AI Feature Wreck Your Frame Rate — Demo

A tiny, self-contained Flutter app built as a live-demo companion for a talk
about keeping AI features from janking your app's UI.

## What it shows

- A spinning box + live FPS counter on screen at all times.
- **"Run AI (Blocking Main Thread) — BAD"**: runs a CPU-heavy fake "AI"
  workload synchronously, directly on the UI isolate. Watch the spinner
  freeze and the FPS counter stall — because the same thread that renders
  frames is busy crunching numbers.
- **"Run AI (Background Isolate) — GOOD"**: runs the *exact same* workload,
  but via `compute()`, which ships it off to a background isolate. The
  spinner and FPS counter keep humming along.

All the "why" explanations live as comments directly in `lib/main.dart`,
including a talking-points block at the bottom you can use as speaker notes.

## How to run

```bash
flutter pub get
flutter run
```

For the most dramatic (and honest) frame-rate numbers on stage, run in
profile mode rather than debug mode:

```bash
flutter run --profile
```

## Tuning for your machine

The fake workload size lives near the top of `_DemoHomePageState` in
`lib/main.dart`:

```dart
static const int _workload = 20000000; // 20 million
```

This is calibrated to take roughly 2–3 seconds in debug mode on a typical
dev machine — enough time for an audience to clearly notice the freeze.
Faster/slower hardware may need this number adjusted up or down. Test it
once before your talk!

## Project structure

```
ai_frame_rate_demo/
├── pubspec.yaml        # Dependencies (just Flutter + cupertino_icons)
└── lib/
    └── main.dart        # The entire demo, heavily commented
```

No native platform folders (android/ios) are included to keep the download
small — run `flutter create .` inside the project folder once to generate
them if you want to build for a physical device or emulator, or just run
`flutter run` and let Flutter regenerate what it needs.
# ai_frame_rate_demo
