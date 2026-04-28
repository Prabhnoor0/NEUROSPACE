import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_tts/flutter_tts.dart';

import '../models/assistant_content_payload.dart';

enum AssistantActionType {
  readAloud,
  simplify,
  summarize,
  easyRead,
}

class AssistantActionResult {
  final AssistantActionType action;
  final bool success;
  final String primaryText;
  final String? audioError;
  final int? statusCode;
  final Map<String, dynamic> raw;

  const AssistantActionResult({
    required this.action,
    required this.success,
    required this.primaryText,
    this.audioError,
    this.statusCode,
    this.raw = const {},
  });
}

class AssistantActionEngine {
  const AssistantActionEngine();

  List<String> _baseUrls() {
    return const [
      'http://10.0.2.2:8000',
      'http://10.0.2.2:8001',
      'http://localhost:8000',
      'http://127.0.0.1:8000',
      'http://localhost:8001',
      'http://127.0.0.1:8001',
    ];
  }

  Future<http.Response> _post(String path, Map<String, dynamic> body) async {
    Object? lastError;
    for (final base in _baseUrls()) {
      try {
        final resp = await http
            .post(
              Uri.parse('$base$path'),
              headers: {'Content-Type': 'application/json'},
              body: json.encode(body),
            )
            .timeout(const Duration(seconds: 30));
        return resp;
      } catch (e) {
        lastError = e;
      }
    }
    throw lastError ?? Exception('Unable to reach backend');
  }

  // ── Simplify ──────────────────────────────────────
  Future<AssistantActionResult> simplify(
    AssistantContentPayload payload, {
    String profile = 'ADHD',
  }) async {
    final response = await _post('/api/assistant/simplify', {
      'text': payload.text,
      'user_profile': profile,
    });

    if (response.statusCode != 200) {
      return AssistantActionResult(
        action: AssistantActionType.simplify,
        success: false,
        primaryText: 'Backend error (${response.statusCode}).',
        statusCode: response.statusCode,
      );
    }

    final data = json.decode(response.body) as Map<String, dynamic>;
    final modules = (data['modules'] as List?) ?? [];
    String display = (data['simplified_text'] ?? '').toString();

    if (modules.isNotEmpty) {
      final buffer = StringBuffer();
      for (final raw in modules) {
        if (raw is Map<String, dynamic>) {
          final content = (raw['content'] ?? '').toString().trim();
          if (content.isNotEmpty) {
            buffer.writeln(content);
            buffer.writeln();
          }
        }
      }
      final parsed = buffer.toString().trim();
      if (parsed.isNotEmpty) display = parsed;
    }

    return AssistantActionResult(
      action: AssistantActionType.simplify,
      success: true,
      primaryText: display,
      statusCode: response.statusCode,
      raw: data,
    );
  }

  // ── Summarize ─────────────────────────────────────
  /// Calls the dedicated /api/assistant/summarize endpoint which returns
  /// a structured SummaryResponse (title, summary, key_points, highlights, etc.)
  Future<AssistantActionResult> summarize(
    AssistantContentPayload payload, {
    String profile = 'ADHD',
  }) async {
    final response = await _post('/api/assistant/summarize', {
      'text': payload.text,
      'user_profile': profile,
    });

    if (response.statusCode != 200) {
      return AssistantActionResult(
        action: AssistantActionType.summarize,
        success: false,
        primaryText: 'Backend error (${response.statusCode}).',
        statusCode: response.statusCode,
      );
    }

    final data = json.decode(response.body) as Map<String, dynamic>;

    // Build a rich display from structured summary
    final title = (data['title'] ?? 'Summary').toString();
    final summary = (data['summary'] ?? '').toString();
    final keyPoints = (data['key_points'] as List?)
            ?.map((e) => e.toString())
            .toList() ??
        [];
    final highlights = (data['highlights'] as List?)
            ?.map((e) => e.toString())
            .toList() ??
        [];
    final readingTime = (data['reading_time'] ?? '').toString();
    final tone = (data['tone'] ?? '').toString();

    final buffer = StringBuffer();
    if (title.isNotEmpty && title != 'Summary') {
      buffer.writeln('📄 $title');
      buffer.writeln();
    }
    if (summary.isNotEmpty) {
      buffer.writeln(summary);
      buffer.writeln();
    }
    if (keyPoints.isNotEmpty) {
      buffer.writeln('🔑 Key Points:');
      for (final kp in keyPoints) {
        buffer.writeln('  • $kp');
      }
      buffer.writeln();
    }
    if (highlights.isNotEmpty) {
      buffer.writeln('💡 Highlights:');
      for (final h in highlights) {
        buffer.writeln('  ❝ $h');
      }
      buffer.writeln();
    }
    if (readingTime.isNotEmpty || tone.isNotEmpty) {
      final parts = <String>[];
      if (readingTime.isNotEmpty) parts.add('⏱ $readingTime');
      if (tone.isNotEmpty) parts.add('🎯 $tone');
      buffer.writeln(parts.join('  ·  '));
    }

    return AssistantActionResult(
      action: AssistantActionType.summarize,
      success: true,
      primaryText: buffer.toString().trim(),
      statusCode: response.statusCode,
      raw: data,
    );
  }

  // ── Easy Read ─────────────────────────────────────
  /// Calls the /api/assistant/easy-read endpoint for AI-powered
  /// accessible formatting with sections, bullets, and simple language.
  Future<AssistantActionResult> easyRead(
    AssistantContentPayload payload, {
    String profile = 'ADHD',
  }) async {
    try {
      final response = await _post('/api/assistant/easy-read', {
        'text': payload.text,
        'user_profile': profile,
      });

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final formatted = (data['formatted_text'] ?? '').toString();
        final sections = data['sections'] as List? ?? [];

        String display = formatted;
        if (display.isEmpty && sections.isNotEmpty) {
          final buffer = StringBuffer();
          for (final sec in sections) {
            if (sec is Map<String, dynamic>) {
              final heading = sec['heading'] ?? '';
              final bullets = (sec['bullets'] as List?) ?? [];
              if (heading.toString().isNotEmpty) {
                buffer.writeln(heading);
              }
              for (final b in bullets) {
                buffer.writeln('  • $b');
              }
              buffer.writeln();
            }
          }
          display = buffer.toString().trim();
        }

        return AssistantActionResult(
          action: AssistantActionType.easyRead,
          success: true,
          primaryText: display.isNotEmpty ? display : _localEasyRead(payload.text),
          raw: data,
        );
      }
    } catch (e) {
      debugPrint('Easy read backend error: $e');
    }

    // Fallback to local easy-read
    return AssistantActionResult(
      action: AssistantActionType.easyRead,
      success: true,
      primaryText: _localEasyRead(payload.text),
    );
  }

  /// Local fallback for easy-read formatting
  String _localEasyRead(String text) {
    final sentences = text
        .replaceAll(RegExp(r'\s+'), ' ')
        .split(RegExp(r'(?<=[.!?])\s+'))
        .where((s) => s.trim().isNotEmpty)
        .toList();

    final buffer = StringBuffer();
    buffer.writeln('📌 Easy Read Version');
    buffer.writeln();
    for (final sentence in sentences) {
      if (sentence.length > 80) {
        for (final part in sentence.split(RegExp(r',\s*'))) {
          if (part.trim().isNotEmpty) {
            buffer.writeln('  • ${part.trim()}');
          }
        }
      } else {
        buffer.writeln('  • ${sentence.trim()}');
      }
      buffer.writeln();
    }

    return buffer.toString().trim();
  }

  // ── TTS via Flutter TTS ───────────────────────────
  /// Uses Flutter TTS for offline text-to-speech. Returns immediately.
  Future<void> speakWithFlutterTts(
    AssistantContentPayload payload, {
    double speed = 0.45,
    FlutterTts? ttsInstance,
  }) async {
    final tts = ttsInstance ?? FlutterTts();
    try {
      await tts.setLanguage('en-US');
      await tts.setSpeechRate(speed);
      await tts.setVolume(1.0);
      await tts.setPitch(1.0);
      await tts.speak(payload.text);
    } catch (e) {
      debugPrint('Flutter TTS speak failed: $e');
    }
  }
}
