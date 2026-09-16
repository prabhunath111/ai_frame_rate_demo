// =============================================================================
// gemini_service.dart
// =============================================================================
// A small wrapper around a REAL call to Google's Gemini API. No mocking, no
// canned responses — this hits https://generativelanguage.googleapis.com
// and returns whatever Gemini actually says.
//
// WHY GEMINI FOR THIS DEMO:
// Google AI Studio (https://aistudio.google.com/apikey) gives you a free
// API key with a real free tier — no credit card required to get started.
// As of writing, the free tier for gemini-2.5-flash is roughly 10-15
// requests/minute and several hundred requests/day, which is more than
// enough for a conference demo. (Free-tier limits change over time — check
// your key's dashboard in AI Studio if you hit a quota error.)
//
// SECURITY NOTE FOR THIS DEMO:
// The API key is entered live in the app's UI and kept only in memory for
// the session — never hardcoded, logged, or written to disk. That's fine
// for a demo. In a real production app you would NOT ship a raw Gemini key
// inside a client app (anyone could extract it) — you'd call Gemini from
// your own backend and have the Flutter app talk to *that* instead.
//
// PLATFORM NOTE:
// This works as-is on iOS, Android, macOS, Windows, and Linux builds.
// Flutter WEB builds may hit a CORS error depending on Google's current
// policy for direct browser calls — for Web, routing through your own
// backend is the safe bet regardless.
// =============================================================================

import 'dart:convert';
import 'package:http/http.dart' as http;

class GeminiService {
  static const String _baseUrl =
      'https://generativelanguage.googleapis.com/v1beta/models';

  /// Sends [prompt] to the given [model] using [apiKey] and returns the
  /// model's real text response. Throws an [Exception] with a readable
  /// message on any failure (bad key, quota exceeded, network error, etc.).
  static Future<String> sendPrompt({
    required String apiKey,
    required String model,
    required String prompt,
  }) async {
    if (apiKey.trim().isEmpty) {
      throw Exception('Please enter your Gemini API key first.');
    }

    final uri = Uri.parse(
      '$_baseUrl/${model.trim()}:generateContent',
    );

    final response = await http.post(
      uri,
      headers: {
        'content-type': 'application/json',
        // Gemini accepts the key either as a query param (?key=...) or as
        // this header — the header keeps it out of logs/URLs a bit better.
        'x-goog-api-key': apiKey.trim(),
      },
      body: jsonEncode({
        'contents': [
          {
            'role': 'user',
            'parts': [
              {'text': prompt},
            ],
          },
        ],
      }),
    );

    if (response.statusCode != 200) {
      String detail = response.body;
      try {
        final decoded = jsonDecode(response.body);
        detail = decoded['error']?['message']?.toString() ?? response.body;
      } catch (_) {
        // Body wasn't JSON — just use the raw text above.
      }
      if (response.statusCode == 429) {
        throw Exception(
          'Rate limit / free-tier quota hit (429). Wait a bit and try '
          'again, or check your quota at aistudio.google.com. Detail: $detail',
        );
      }
      throw Exception('Gemini API error (${response.statusCode}): $detail');
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final candidates = decoded['candidates'] as List<dynamic>?;

    if (candidates == null || candidates.isEmpty) {
      throw Exception(
        'Gemini API returned no candidates (possibly blocked by safety '
        'filters — try a different prompt).',
      );
    }

    final content = candidates.first['content'] as Map<String, dynamic>?;
    final parts = content?['parts'] as List<dynamic>?;

    if (parts == null || parts.isEmpty) {
      throw Exception('Gemini API returned an empty response.');
    }

    final buffer = StringBuffer();
    for (final part in parts) {
      if (part is Map<String, dynamic> && part['text'] != null) {
        buffer.write(part['text']);
      }
    }

    final text = buffer.toString();
    if (text.isEmpty) {
      throw Exception('Gemini API returned an empty text response.');
    }

    return text;
  }
}
