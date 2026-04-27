import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/assistant_content_payload.dart';

class AssistantContentService {
  Future<AssistantContentPayload> fromClipboard() async {
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      return normalize(
        rawText: data?.text ?? '',
        source: AssistantContentSource.clipboard,
      );
    } catch (_) {
      return AssistantContentPayload.empty(
        source: AssistantContentSource.clipboard,
      );
    }
  }

  Future<AssistantContentPayload> fromAccessibilityScreen() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();
      final text = prefs.getString('neuro_screen_text') ?? '';
      return normalize(
        rawText: text,
        source: AssistantContentSource.accessibilityScreen,
      );
    } catch (_) {
      return AssistantContentPayload.empty(
        source: AssistantContentSource.accessibilityScreen,
      );
    }
  }

  Future<bool> isAccessibilityServiceActive() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();
      return prefs.getBool('neuro_accessibility_active') ?? false;
    } catch (_) {
      return false;
    }
  }

  AssistantContentPayload fromOcr(String text, {String? imagePath}) {
    return normalize(
      rawText: text,
      source: AssistantContentSource.ocr,
      meta: {
        if (imagePath != null && imagePath.isNotEmpty) 'image_path': imagePath,
      },
    );
  }

  AssistantContentPayload fromSharedText(String text) {
    return normalize(
      rawText: text,
      source: AssistantContentSource.sharedText,
    );
  }

  AssistantContentPayload fromPastedText(String text) {
    return normalize(
      rawText: text,
      source: AssistantContentSource.pastedText,
    );
  }

  AssistantContentPayload normalize({
    required String rawText,
    required AssistantContentSource source,
    Map<String, dynamic> meta = const {},
  }) {
    final cleaned = rawText
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll('\u0000', '')
        .trim();

    return AssistantContentPayload(
      text: cleaned,
      source: source,
      capturedAt: DateTime.now(),
      meta: meta,
    );
  }
}
