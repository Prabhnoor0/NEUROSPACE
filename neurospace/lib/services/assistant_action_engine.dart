import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

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
      action: AssistantActionType.summarize,
      success: true,
      primaryText: display,
      statusCode: response.statusCode,
      raw: data,
    );
  }

  AssistantActionResult easyRead(AssistantContentPayload payload) {
    final sentences = payload.text
        .replaceAll(RegExp(r'\s+'), ' ')
        .split(RegExp(r'(?<=[.!?])\s+'))
        .where((s) => s.trim().isNotEmpty)
        .toList();

    final buffer = StringBuffer();
    for (final sentence in sentences) {
      if (sentence.length > 80) {
        for (final part in sentence.split(RegExp(r',\s*'))) {
          if (part.trim().isNotEmpty) {
            buffer.writeln('• ${part.trim()}');
          }
        }
      } else {
        buffer.writeln('• ${sentence.trim()}');
      }
      buffer.writeln();
    }

    return AssistantActionResult(
      action: AssistantActionType.easyRead,
      success: true,
      primaryText: buffer.toString().trim(),
    );
  }

  Future<http.Response?> fetchTtsAudio(
    AssistantContentPayload payload, {
    double speed = 1.0,
  }) async {
    try {
      final response = await _post('/api/text-to-speech', {
        'text': payload.text,
        'speed': speed,
      });
      if (response.statusCode == 200) return response;
    } catch (e) {
      debugPrint('TTS fetch failed: $e');
    }
    return null;
  }
}
