// =============================================================================
// "Don't Let Your AI Feature Wreck Your Frame Rate" — demo app (REAL AI edition)
// =============================================================================
//
// FLOW
// ----
// 1. You paste a real Gemini API key (free, no credit card needed — see
//    https://aistudio.google.com/apikey) and type a real prompt.
// 2. The app makes a REAL network call to Gemini and gets back a REAL
//    response. (Network calls are naturally async in Dart — they don't
//    block the UI isolate by themselves. That's not where the jank comes
//    from in this demo.)
// 3. THIS is where the jank comes from: once we have the real response
//    text, we run a REAL, useful analysis on it — a Levenshtein-distance
//    based "unusual/possibly-misspelled term" detector (see
//    text_analysis.dart) — comparing every uncommon word in the response
//    against a real dictionary. That's genuinely CPU-heavy work, and its
//    cost scales with how long/technical the real response actually is.
// 4. You can run that analysis two ways:
//      • "Analyze (Main Thread) — BAD": calls analyzeResponseText(text)
//        directly. It blocks the UI isolate until it's done — watch the
//        spinner freeze and the FPS counter stall.
//      • "Analyze (Background Isolate) — GOOD": calls
//        compute(analyzeResponseText, text) — the exact same function,
//        same real data, but running on a separate isolate. The UI stays
//        smooth the whole time.
//
// Nothing in this file uses Future.delayed/Timer/sleep to fake work. The
// only "slow" thing here is a real algorithm running on real AI output.
// =============================================================================

import 'package:flutter/foundation.dart'; // for compute()
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'gemini_service.dart';
import 'text_analysis.dart';

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

class DemoHomePage extends StatefulWidget {
  const DemoHomePage({super.key});

  @override
  State<DemoHomePage> createState() => _DemoHomePageState();
}

class _DemoHomePageState extends State<DemoHomePage>
    with SingleTickerProviderStateMixin {
  // ---------------------------------------------------------------------
  // Spinner animation — our visual "is the UI thread alive?" indicator.
  // If the UI isolate is blocked, this stops rotating no matter what the
  // AnimationController "should" be doing, because nothing can execute,
  // including the frame callbacks that drive the animation.
  // ---------------------------------------------------------------------
  late final AnimationController _spinController;

  // ---------------------------------------------------------------------
  // Live FPS tracking via a persistent frame callback. When the UI isolate
  // is busy (e.g. running analysis synchronously), this callback simply
  // doesn't fire, so the FPS readout freezes right along with the spinner.
  // ---------------------------------------------------------------------
  Duration? _lastFrameTimestamp;
  double _currentFps = 60;
  final List<double> _fpsSamples = [];

  // ---------------------------------------------------------------------
  // Form state
  // ---------------------------------------------------------------------
  final _apiKeyController = TextEditingController();
  // final _modelController = TextEditingController(text: 'gemini-2.5-flash');
  final _modelController = TextEditingController(text: 'gemini-3.6-flash');
  final _promptController = TextEditingController(
    text: 'Write a detailed, in-depth explanation (at least 800-1000 words) '
        'of how neural networks learn via backpropagation, aimed at a '
        'technical audience. Use plenty of specific terminology.',
  );

  bool _isFetchingResponse = false;
  bool _isAnalyzing = false;
  String? _aiResponseText;
  String _statusText = 'Enter your API key and a prompt, then fetch a real '
      'AI response.';
  AnalysisResult? _lastResult;

  @override
  void initState() {
    super.initState();

    _spinController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    SchedulerBinding.instance.addPersistentFrameCallback(_onFrame);
  }

  void _onFrame(Duration timestamp) {
    if (_lastFrameTimestamp != null) {
      final deltaMicros = (timestamp - _lastFrameTimestamp!).inMicroseconds;
      if (deltaMicros > 0) {
        final instantFps = 1000000 / deltaMicros;
        _fpsSamples.add(instantFps);
        if (_fpsSamples.length > 10) {
          _fpsSamples.removeAt(0);
        }
        final avgFps =
            _fpsSamples.reduce((a, b) => a + b) / _fpsSamples.length;
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
    _apiKeyController.dispose();
    _modelController.dispose();
    _promptController.dispose();
    super.dispose();
  }

  // ===========================================================================
  // STEP 1: real network call to Gemini.
  // ===========================================================================
  Future<void> _fetchRealAiResponse() async {
    setState(() {
      _isFetchingResponse = true;
      _statusText = 'Calling the real Gemini API...';
      _aiResponseText = null;
      _lastResult = null;
    });

    try {
      final text = await GeminiService.sendPrompt(
        apiKey: _apiKeyController.text,
        model: _modelController.text.trim(),
        prompt: _promptController.text,
      );

      setState(() {
        _aiResponseText = text;
        _statusText =
            'Got a real response (${text.split(RegExp(r"\s+")).length} words). '
            'Now try analyzing it both ways below.';
      });
    } catch (e) {
      setState(() {
        _statusText = 'Error: $e';
      });
    } finally {
      setState(() {
        _isFetchingResponse = false;
      });
    }
  }

  // ===========================================================================
  // STEP 2A (BAD): run the real analysis directly on the UI isolate.
  // ===========================================================================
  Future<void> _analyzeOnMainThread() async {
    final text = _aiResponseText;
    if (text == null) return;

    setState(() {
      _isAnalyzing = true;
      _statusText =
          'Analyzing on the MAIN thread... (watch the spinner + FPS freeze!)';
    });

    // Let Flutter actually paint the "busy" status above before we block.
    await Future.delayed(const Duration(milliseconds: 16));

    // 🔴 THE PROBLEM LINE 🔴
    // A plain, synchronous call. Runs entirely on the UI isolate — every
    // frame callback and gesture handler waits behind it. This is real
    // work on the real response text, not a fake delay.
    final result = analyzeResponseText(text);

    setState(() {
      _isAnalyzing = false;
      _lastResult = result;
      _statusText = 'MAIN THREAD analysis finished in ${result.elapsedMs}ms — '
          'did you see the freeze?';
    });
  }

  // ===========================================================================
  // STEP 2B (GOOD): run the exact same real analysis on a background isolate.
  // ===========================================================================
  Future<void> _analyzeOnBackgroundIsolate() async {
    final text = _aiResponseText;
    if (text == null) return;

    setState(() {
      _isAnalyzing = true;
      _statusText = 'Analyzing on a BACKGROUND isolate... '
          '(UI should stay smooth!)';
    });

    // ✅ THE FIX ✅
    // Same function (analyzeResponseText), same real response text — but
    // compute() runs it on a separate isolate and awaits the result. The UI
    // isolate stays free to keep rendering frames the whole time.
    final result = await compute(analyzeResponseText, text);

    setState(() {
      _isAnalyzing = false;
      _lastResult = result;
      _statusText =
          'BACKGROUND ISOLATE analysis finished in ${result.elapsedMs}ms — '
          'UI stayed responsive!';
    });
  }

  @override
  Widget build(BuildContext context) {
    final fpsColor = _currentFps > 50
        ? Colors.green
        : (_currentFps > 30 ? Colors.orange : Colors.red);
    final busy = _isFetchingResponse || _isAnalyzing;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Don't Let Your AI Feature Wreck Your Frame Rate"),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ---------------------------------------------------------
              // Live FPS readout + spinner — always visible up top.
              // ---------------------------------------------------------
              Row(
                children: [
                  Expanded(
                    child: Card(
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
                                  .titleLarge
                                  ?.copyWith(
                                      color: fpsColor,
                                      fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  RotationTransition(
                    turns: _spinController,
                    child: Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.auto_awesome,
                          color: Colors.white, size: 28),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // ---------------------------------------------------------
              // Step 1: real API call inputs
              // ---------------------------------------------------------
              Text('1. Get a real AI response',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              TextField(
                controller: _apiKeyController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Gemini API key',
                  border: OutlineInputBorder(),
                  helperText: 'Free from aistudio.google.com/apikey. '
                      'Kept in memory only, never stored or logged.',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _modelController,
                decoration: const InputDecoration(
                  labelText: 'Model',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _promptController,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Prompt',
                  border: OutlineInputBorder(),
                  helperText: 'Tip: asking for a long, detailed answer gives '
                      'the analysis step more real text to work with.',
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: busy ? null : _fetchRealAiResponse,
                icon: _isFetchingResponse
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send),
                label: const Text('Send prompt to Gemini (real API call)'),
              ),

              const SizedBox(height: 24),
              Text(
                _statusText,
                style: Theme.of(context).textTheme.bodyMedium,
              ),

              if (_aiResponseText != null) ...[
                const SizedBox(height: 20),
                Text('2. Analyze the real response',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(
                  'Flags words not found in a common-word dictionary using '
                  'real Levenshtein-distance fuzzy matching — a genuine '
                  '"possible typo / unusual term" detector.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 12),

                FilledButton.tonalIcon(
                  onPressed: busy ? null : _analyzeOnMainThread,
                  icon: const Icon(Icons.warning_amber_rounded),
                  label: const Text('Analyze (Main Thread) — BAD'),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.red.withValues(alpha: 0.15),
                    foregroundColor: Colors.red.shade700,
                  ),
                ),
                const SizedBox(height: 10),
                FilledButton.icon(
                  onPressed: busy ? null : _analyzeOnBackgroundIsolate,
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text('Analyze (Background Isolate) — GOOD'),
                ),

                const SizedBox(height: 20),

                // -----------------------------------------------------
                // Real response text, shown in full.
                // -----------------------------------------------------
                ExpansionTile(
                  title: const Text('Show raw AI response'),
                  initiallyExpanded: false,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Text(_aiResponseText!),
                    ),
                  ],
                ),
              ],

              if (_lastResult != null) ...[
                const SizedBox(height: 20),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Analysis results',
                            style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 8),
                        Text('Total words scanned: ${_lastResult!.totalWords}'),
                        Text(
                            'Unique words checked against dictionary: ${_lastResult!.uniqueWordsChecked}'),
                        Text('Flagged as unusual/possible typo: '
                            '${_lastResult!.flaggedCount}'),
                        Text('Computation time: ${_lastResult!.elapsedMs}ms'),
                        if (_lastResult!.flaggedWords.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          const Text('Examples:',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          ..._lastResult!.flaggedWords.take(10).map(
                                (f) => Text(
                                  '  "${f.word}" → closest known word: '
                                  '"${f.closestMatch}" (distance ${f.editDistance})',
                                ),
                              ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// TALK TALKING POINTS (speaker notes bundled with the code):
//
// • The network call to Gemini does NOT block the UI — Dart's http package
//   does async I/O, so `await`-ing it just suspends this function; the event
//   loop (and thus frame rendering) keeps running. That's why the demo's
//   jank doesn't come from "calling AI" itself.
//
// • The jank comes from what you do with the response afterward — parsing,
//   validating, rendering, scoring, searching. Any of that can be just as
//   synchronous and heavy as a local ML model, even though no model is
//   involved. "AI feature" jank isn't only about running a model on-device;
//   it's about anything CPU-heavy hanging off the AI pipeline.
//
// • `async`/`await` alone doesn't save you here either. Our
//   analyzeResponseText() function has no `await` inside it — it's a plain
//   synchronous function. Wrapping ITS CALL SITE in `async` doesn't change
//   that; it still runs to completion in one go on whichever isolate calls
//   it. Genuine concurrency requires a genuinely separate isolate.
//
// • compute() is the fix: same function, same real data, different isolate.
//   Nothing about the algorithm changes — only where it runs.
//
// • Real-world equivalents of this exact pattern:
//     - Rendering/syntax-highlighting a long markdown or code response
//     - Running moderation/profanity/PII checks over model output
//     - Local re-ranking or similarity search over retrieved documents (RAG)
//     - Client-side validation or JSON schema checks on structured output
//     - Tokenization/detokenization for local pre/post-processing
// =============================================================================
