// =============================================================================
// "Don't Let Your AI Feature Wreck Your Frame Rate" — demo app
// =============================================================================
//
// THE PROBLEM THIS DEMO ILLUSTRATES
// ----------------------------------
// Flutter runs your Dart app code and the UI (layout/paint/compositing) on
// the SAME isolate — the "UI thread" / main isolate. An isolate is
// single-threaded: it can only do one thing at a time.
//
// If you drop a CPU-heavy "AI" task on that thread — running a TFLite model,
// doing image pre/post-processing, tokenizing text for an LLM, parsing a huge
// JSON response, running an embedding/similarity search — you block the event
// loop. Flutter can't produce new frames while your code is busy, so the app
// freezes for however long that work takes. That's the classic "AI feature
// wrecked my frame rate" bug.
//
// THE FIX
// -------
// Move the heavy work OFF the UI isolate:
//   • compute() — spins up a background isolate, runs a top-level/static
//     function there, and returns the result via a Future. This is what
//     we use below because it works on all supported Flutter/Dart versions.
//   • Isolate.run() (Dart 3.3+) — a newer, slightly more ergonomic version
//     of the same idea.
//   • For real ML inference: many packages (tflite_flutter, google_ml_kit,
//     onnxruntime, etc.) already do their heavy native work off the UI
//     thread via platform channels — but YOUR pre/post-processing code
//     around the inference call can still block the UI if you're not
//     careful, so the same rule applies.
//
// WHAT'S IN THIS DEMO
// --------------------
// 1. A spinning box + a live FPS counter, so the audience can SEE and READ
//    the frame rate in real time.
// 2. A "Run AI (Blocking Main Thread)" button that runs a fake but genuinely
//    CPU-heavy computation directly on the UI isolate — watch the spinner
//    freeze and the FPS counter stall.
// 3. A "Run AI (Background Isolate)" button that runs the EXACT SAME
//    computation via compute() — the spinner keeps spinning at ~60fps while
//    the "AI" work happens in the background.
//
// HOW TO RUN
// ----------
//   flutter pub get
//   flutter run
//
// Run in RELEASE or PROFILE mode for the most convincing frame-rate numbers
// (debug mode has extra overhead that can make the blocking case look even
// worse, which is arguably a fun bonus for the talk):
//   flutter run --profile
// =============================================================================

import 'dart:math';
import 'package:flutter/foundation.dart'; // for compute()
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart'; // for frame timing callbacks

void main() {
  runApp(const AIFrameRateDemoApp());
}

class AIFrameRateDemoApp extends StatelessWidget {
  const AIFrameRateDemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "Don't Wreck Your Frame Rate",
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: Colors.deepPurple,
        useMaterial3: true,
      ),
      home: const DemoHomePage(),
    );
  }
}

// =============================================================================
// THE "AI" WORKLOAD
// =============================================================================
// This stands in for whatever heavy work your real AI feature does:
// running a model, decoding a big response, doing image processing, etc.
//
// IMPORTANT for compute()/Isolate.run(): this must be a TOP-LEVEL function
// (or a static method) — it cannot be a closure that captures state from a
// widget, because it needs to be sent to a completely separate isolate that
// doesn't share memory with the UI isolate.
//
// Here we simulate "AI-like" CPU work by counting prime numbers up to
// [workload]. It's not literally machine learning, but it stresses the CPU
// in the same synchronous, single-threaded way a naive on-device inference
// or heavy post-processing loop would.
int runFakeAIInference(int workload) {
  int primeCount = 0;

  for (int n = 2; n < workload; n++) {
    if (_isPrime(n)) {
      primeCount++;
    }
  }

  return primeCount;
}

bool _isPrime(int n) {
  if (n < 2) return false;
  if (n % 2 == 0) return n == 2;
  for (int i = 3; i * i <= n; i += 2) {
    if (n % i == 0) return false;
  }
  return true;
}

// =============================================================================
// HOME PAGE
// =============================================================================
class DemoHomePage extends StatefulWidget {
  const DemoHomePage({super.key});

  @override
  State<DemoHomePage> createState() => _DemoHomePageState();
}

class _DemoHomePageState extends State<DemoHomePage>
    with SingleTickerProviderStateMixin {
  // ---------------------------------------------------------------------
  // Spinner animation — our visual "is the UI thread alive?" indicator.
  // If the UI isolate is blocked, this stops rotating, no matter what the
  // AnimationController says it "should" be doing — because nothing can
  // execute, including the frame callbacks that drive the animation.
  // ---------------------------------------------------------------------
  late final AnimationController _spinController;

  // ---------------------------------------------------------------------
  // FPS tracking.
  // We use WidgetsBinding's persistent frame callback, which fires once
  // per rendered frame with a timestamp. By measuring the time between
  // consecutive callbacks we get a live, real "how smooth is this app
  // right now" number. When the UI isolate is busy running our fake AI
  // workload synchronously, this callback simply doesn't fire — which is
  // exactly the point: the FPS counter itself will freeze along with the
  // animation, making the jank undeniable in a live demo.
  // ---------------------------------------------------------------------
  Duration? _lastFrameTimestamp;
  double _currentFps = 60;
  final List<double> _fpsSamples = [];

  // Workload size for the fake AI task. Tuned so it takes roughly 2-3
  // seconds on a typical dev machine/emulator in debug mode — plenty of
  // time to visibly notice the freeze during a talk. Tweak this for your
  // hardware before presenting!
  static const int _workload = 20000000; // 20 million

  bool _isBusy = false;
  String _statusText = 'Idle — tap a button to run the "AI" workload.';

  @override
  void initState() {
    super.initState();

    _spinController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(); // spin forever

    // Register our FPS-measuring callback. This runs on every frame that
    // Flutter actually manages to render.
    SchedulerBinding.instance.addPersistentFrameCallback(_onFrame);
  }

  void _onFrame(Duration timestamp) {
    if (_lastFrameTimestamp != null) {
      final deltaMicros =
          (timestamp - _lastFrameTimestamp!).inMicroseconds;
      if (deltaMicros > 0) {
        final instantFps = 1000000 / deltaMicros;

        // Smooth the reading over a small rolling window so the number
        // doesn't jitter too wildly, while still reacting quickly.
        _fpsSamples.add(instantFps);
        if (_fpsSamples.length > 10) {
          _fpsSamples.removeAt(0);
        }
        final avgFps =
            _fpsSamples.reduce((a, b) => a + b) / _fpsSamples.length;

        // Only update state if we're not mid-way through a synchronous
        // blocking call — see note in _runOnMainThread below about why
        // that call prevents setState from having any visible effect
        // anyway until it returns.
        if (mounted) {
          setState(() {
            _currentFps = avgFps.clamp(0, 60);
          });
        }
      }
    }
    _lastFrameTimestamp = timestamp;
  }

  @override
  void dispose() {
    _spinController.dispose();
    super.dispose();
  }

  // ===========================================================================
  // OPTION A (BAD): run the heavy "AI" work directly on the UI isolate.
  // ===========================================================================
  // This is what happens when you call a heavy synchronous function straight
  // from a button handler — e.g. calling a naive on-device inference function,
  // decoding a huge image, or crunching a big JSON payload right in your
  // widget code. Because it's synchronous, Dart cannot go do anything else
  // (including render frames) until this function returns.
  Future<void> _runOnMainThread() async {
    setState(() {
      _isBusy = true;
      _statusText = 'Running AI on the MAIN thread... (watch it freeze!)';
    });

    // Give Flutter one frame to actually show the "busy" status text above
    // before we block everything.
    await Future.delayed(const Duration(milliseconds: 16));

    final stopwatch = Stopwatch()..start();

    // 🔴 THE PROBLEM LINE 🔴
    // This is a plain, synchronous function call. It runs entirely on the
    // UI isolate. Every frame callback, gesture handler, and animation
    // tick has to wait in line behind it.
    final result = runFakeAIInference(_workload);

    stopwatch.stop();

    setState(() {
      _isBusy = false;
      _statusText =
          'MAIN THREAD result: found $result primes in '
          '${stopwatch.elapsedMilliseconds}ms — did you see the freeze?';
    });
  }

  // ===========================================================================
  // OPTION B (GOOD): run the exact same work on a background isolate.
  // ===========================================================================
  // compute() does three things for you:
  //   1. Spawns a new background isolate (or reuses a pooled one).
  //   2. Sends the top-level function + argument to it (this uses message
  //      passing / serialization, so arguments and results must be simple,
  //      "sendable" values — ints, strings, lists, maps, etc.).
  //   3. Returns a Future that completes with the result once the
  //      background isolate finishes, WITHOUT ever blocking the UI isolate.
  //
  // The UI isolate stays free the entire time, so animations, gestures, and
  // frame rendering keep working normally.
  Future<void> _runOnBackgroundIsolate() async {
    setState(() {
      _isBusy = true;
      _statusText =
          'Running AI on a BACKGROUND isolate... (UI should stay smooth!)';
    });

    final stopwatch = Stopwatch()..start();

    // ✅ THE FIX ✅
    // Same function, same workload — but compute() ships the work off to
    // another isolate and awaits the result. The UI isolate is free to keep
    // rendering frames (and running our FPS counter) the whole time.
    //
    // Note: on Dart 3.3+, `await Isolate.run(() => runFakeAIInference(_workload))`
    // is an equally valid, slightly more modern alternative to compute().
    final result = await compute(runFakeAIInference, _workload);

    stopwatch.stop();

    setState(() {
      _isBusy = false;
      _statusText =
          'BACKGROUND ISOLATE result: found $result primes in '
          '${stopwatch.elapsedMilliseconds}ms — UI stayed responsive!';
    });
  }

  @override
  Widget build(BuildContext context) {
    final fpsColor = _currentFps > 50
        ? Colors.green
        : (_currentFps > 30 ? Colors.orange : Colors.red);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Don't Let Your AI Feature Wreck Your Frame Rate"),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              // ---------------------------------------------------------
              // Live FPS readout
              // ---------------------------------------------------------
              Card(
                color: fpsColor.withValues(alpha: 0.12),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.speed, color: fpsColor),
                      const SizedBox(width: 8),
                      Text(
                        '${_currentFps.toStringAsFixed(1)} FPS',
                        style: Theme.of(context)
                            .textTheme
                            .headlineMedium
                            ?.copyWith(color: fpsColor, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // ---------------------------------------------------------
              // The spinning box — the visual "is this UI alive?" check.
              // ---------------------------------------------------------
              RotationTransition(
                turns: _spinController,
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.auto_awesome,
                      color: Colors.white, size: 40),
                ),
              ),

              const SizedBox(height: 16),
              Text(
                'This box should spin smoothly forever.\n'
                'If the "AI" work blocks the UI thread, it will visibly freeze.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),

              const SizedBox(height: 32),

              // ---------------------------------------------------------
              // Status text
              // ---------------------------------------------------------
              Text(
                _statusText,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),

              const Spacer(),

              // ---------------------------------------------------------
              // The two buttons: bad vs. good
              // ---------------------------------------------------------
              FilledButton.tonalIcon(
                onPressed: _isBusy ? null : _runOnMainThread,
                icon: const Icon(Icons.warning_amber_rounded),
                label: const Text('Run AI (Blocking Main Thread) — BAD'),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.red.withValues(alpha: 0.15),
                  foregroundColor: Colors.red.shade700,
                  minimumSize: const Size.fromHeight(52),
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _isBusy ? null : _runOnBackgroundIsolate,
                icon: const Icon(Icons.check_circle_outline),
                label: const Text('Run AI (Background Isolate) — GOOD'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                ),
              ),

              const SizedBox(height: 8),
              Text(
                'Workload: counting primes below $_workload '
                '(stand-in for a heavy AI/ML task)',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// TALK TALKING POINTS (feel free to delete this comment block, it's just
// speaker notes bundled with the code for convenience):
//
// • Flutter's UI isolate = your Dart code + layout + paint + compositing.
//   It's single-threaded. Anything synchronous and slow blocks EVERYTHING,
//   not just your feature — scrolling, animations, gesture response, all of it.
//
// • "Async" alone doesn't save you. `Future`/`async`/`await` give you
//   cooperative concurrency on the SAME isolate. If the work inside your
//   async function is CPU-bound and doesn't `await` anything, it still runs
//   to completion in one go and blocks the UI isolate the whole time. You
//   need a genuinely separate isolate (compute/Isolate.run) for CPU-heavy
//   work, not just an `async` keyword.
//
// • Real-world equivalents of `runFakeAIInference`:
//     - Running a TFLite/ONNX model's pre/post-processing in Dart
//     - Tokenizing/detokenizing text for an on-device or streamed LLM
//     - Decoding/resizing large images before feeding a vision model
//     - Parsing a huge JSON/protobuf response from an AI API
//     - Vector similarity search over a large local embedding index
//
// • Many ML plugins already run the actual model inference off the UI
//   thread via platform channels/native threads — but the Dart-side glue
//   code around them (marshalling data, post-processing results) is still
//   your responsibility to keep off the UI isolate if it's heavy.
//
// • Quick mental checklist for any new AI feature:
//     1. Is this call synchronous and CPU-heavy?
//     2. Could it take more than ~16ms (one frame at 60fps)?
//     3. If yes to either — move it to compute()/Isolate.run(), or confirm
//        the underlying plugin already runs off the UI thread.
// =============================================================================
