// =============================================================================
// text_analysis.dart
// =============================================================================
// This is the REAL, useful work our demo does on a REAL AI response — not a
// dummy sleep() or a busy-loop with no purpose. Specifically:
//
//   1. Tokenize the actual response text into words.
//   2. For every unique word that ISN'T in our common-word dictionary
//      (common_words.dart), find the closest dictionary word using
//      Levenshtein (edit) distance. This is the same core technique real
//      spell-checkers use, and it's genuinely handy for an AI chat app —
//      e.g. flagging possibly-misspelled or unusual/unexpected terms in a
//      model's output for a human reviewer to double check.
//   3. Return which words were flagged and what the closest "known" word is.
//
// WHY THIS IS CPU-HEAVY (for real, not artificially):
// Levenshtein distance between two words of length m and n costs O(m*n).
// We run that against every word in our dictionary for every unusual word
// in the response. A longer/more technical AI response has more unique,
// uncommon words, so the cost scales naturally with the REAL content the
// model actually returned — exactly like a real feature would behave.
//
// IMPORTANT for compute()/isolates:
// The function below (`analyzeResponseText`) is a top-level function that
// takes a single String and returns a plain AnalysisResult object built
// only from primitive/collection types (String, int, double, List). That
// makes it safe to send across the isolate boundary, whether it's called
// directly (main isolate) or via `compute()` (background isolate).
// =============================================================================

import 'common_words.dart';

/// Result of analyzing an AI response. Only simple/primitive fields — this
/// needs to survive being copied across an isolate boundary by compute().
class AnalysisResult {
  final int totalWords;
  final int uniqueWordsChecked;
  final int flaggedCount;
  final List<FlaggedWord> flaggedWords;
  final int elapsedMs;

  AnalysisResult({
    required this.totalWords,
    required this.uniqueWordsChecked,
    required this.flaggedCount,
    required this.flaggedWords,
    required this.elapsedMs,
  });
}

/// A single word from the AI response that wasn't found in our common-word
/// dictionary, plus the closest dictionary word we found via edit distance.
class FlaggedWord {
  final String word;
  final String closestMatch;
  final int editDistance;

  FlaggedWord({
    required this.word,
    required this.closestMatch,
    required this.editDistance,
  });
}

/// The real, heavy-lifting entry point. Safe to call directly (blocks the
/// calling isolate until done) OR via `compute(analyzeResponseText, text)`
/// (runs on a background isolate instead).
AnalysisResult analyzeResponseText(String text) {
  final stopwatch = Stopwatch()..start();

  // --- Step 1: real tokenization of the real response text -----------------
  final wordPattern = RegExp(r"[A-Za-z']+");
  final rawWords = wordPattern
      .allMatches(text)
      .map((m) => m.group(0)!.toLowerCase())
      .where((w) => w.length >= 4) // skip very short words, mirrors real spellcheckers
      .toList();

  final totalWords = rawWords.length;

  // Dedup so we don't redundantly re-check the same word many times — but
  // note this still leaves plenty of real work: long, detailed AI answers
  // commonly contain hundreds of distinct words.
  final uniqueWords = rawWords.toSet().toList();

  // Precompute a lowercase Set for fast "is this a known common word?" checks.
  final dictionarySet = commonEnglishWords.toSet();

  final flagged = <FlaggedWord>[];

  // --- Step 2: the actual heavy work ----------------------------------------
  // For every word from the REAL response that isn't a common word, scan the
  // REAL dictionary and compute REAL edit distances to find the closest
  // match. No sleeps, no fake delays — this is just what the algorithm
  // actually costs.
  for (final word in uniqueWords) {
    if (dictionarySet.contains(word)) {
      continue; // it's a common word, nothing to flag
    }

    String? bestMatch;
    int bestDistance = 999;

    for (final dictWord in commonEnglishWords) {
      final distance = _levenshteinDistance(word, dictWord);
      if (distance < bestDistance) {
        bestDistance = distance;
        bestMatch = dictWord;
        if (bestDistance == 0) break; // exact match, can't do better
      }
    }

    // Only report it as "flagged" if it's reasonably close to a known word
    // (otherwise it's probably a legitimate technical term / proper noun,
    // not a typo — same heuristic real spell-checkers use).
    if (bestMatch != null && bestDistance <= 3) {
      flagged.add(FlaggedWord(
        word: word,
        closestMatch: bestMatch,
        editDistance: bestDistance,
      ));
    }
  }

  stopwatch.stop();

  return AnalysisResult(
    totalWords: totalWords,
    uniqueWordsChecked: uniqueWords.length,
    flaggedCount: flagged.length,
    flaggedWords: flagged,
    elapsedMs: stopwatch.elapsedMilliseconds,
  );
}

/// Classic dynamic-programming Levenshtein (edit) distance between two
/// strings — the number of single-character insertions, deletions, or
/// substitutions needed to turn [a] into [b]. O(a.length * b.length).
///
/// This is a real, standard algorithm (not a placeholder) — it's exactly
/// what production spell-checkers and fuzzy-search features use.
int _levenshteinDistance(String a, String b) {
  if (a == b) return 0;
  if (a.isEmpty) return b.length;
  if (b.isEmpty) return a.length;

  final la = a.length;
  final lb = b.length;

  // Two-row rolling DP table instead of a full matrix — real optimization,
  // still O(la*lb) time but O(min(la,lb)) space.
  List<int> previousRow = List<int>.generate(lb + 1, (j) => j);
  List<int> currentRow = List<int>.filled(lb + 1, 0);

  for (int i = 1; i <= la; i++) {
    currentRow[0] = i;
    final aChar = a.codeUnitAt(i - 1);

    for (int j = 1; j <= lb; j++) {
      final bChar = b.codeUnitAt(j - 1);
      final cost = aChar == bChar ? 0 : 1;

      final deletion = previousRow[j] + 1;
      final insertion = currentRow[j - 1] + 1;
      final substitution = previousRow[j - 1] + cost;

      currentRow[j] = [deletion, insertion, substitution].reduce(
        (value, element) => value < element ? value : element,
      );
    }

    final temp = previousRow;
    previousRow = currentRow;
    currentRow = temp;
  }

  return previousRow[lb];
}
