import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/assistant_content_payload.dart';

class AssistantContentService {
  // ────────────────────────────────────────────────
  //  OVERLAY UI NOISE FILTER
  // ────────────────────────────────────────────────

  static const _overlayNoisePatterns = [
    'NeuroSpace',
    'ADHD MODE',
    'Tap an action below',
    'Tap a feature to start using it',
    'Read Aloud',
    'Simplify',
    'Summarize',
    'Easy Read',
    'Scan / Open',
    'Explain Screen',
    'Simplify Clipboard',
    'Summarize Clipboard',
    'Listen to text',
    'Rewrite in easy words',
    'Short summary',
    'Digestible bullets',
    'OCR + reader',
    'Summarize visible content',
    'Back',
    'Minimize',
    'Close',
    'Search Wikipedia, topics, anything...',
    'Page Summary',
    'Reading current page',
    'Reading clipboard text',
    'No content detected',
    'Accessibility Service not enabled',
  ];

  // ────────────────────────────────────────────────
  //  SYSTEM UI NOISE FILTER
  // ────────────────────────────────────────────────

  static const _systemNoiseExact = [
    'Android System notification',
    'Android System',
    'Silent notifications',
    'Now Playing',
    'Paused',
    'Phone signal',
    'Phone signal full',
    'Mobile data',
    'Wi-Fi signal',
    'Wi-Fi signal full',
    'Battery',
    'Battery full',
    'Battery charging',
    'Do Not Disturb',
    'Charging',
    'USB debugging connected',
    'neurospace is running in the background',
    'NeuroSpace is running in the background',
    'Tap for more information',
    'Tap for more options',
    'System UI',
    'Status bar',
    'Navigation bar',
    'Home',
    'Recent apps',
    'Overview',
    'Back button',
  ];

  static final _systemNoiseRegexes = [
    RegExp(r'^\d{1,2}:\d{2}$'),
    RegExp(r'^\d{1,2}:\d{2}\s*(AM|PM)$', caseSensitive: false),
    RegExp(r'^\d{1,3}%$'),
    RegExp(r'^Battery\s+\d{1,3}%'),
    RegExp(r'^\d{1,2}/\d{1,2}/\d{2,4}$'),
    RegExp(r'^(Mon|Tue|Wed|Thu|Fri|Sat|Sun)', caseSensitive: false),
    RegExp(r'^\d+ notifications?$', caseSensitive: false),
    RegExp(r'^(Charging|Charged|Battery saver)', caseSensitive: false),
    RegExp(r'^(Wi-Fi|WiFi|LTE|5G|4G|3G|H\+|Edge|No service)', caseSensitive: false),
  ];

  /// Combined noise filter for overlay + system UI.
  String _filterAllNoise(String text) {
    if (text.isEmpty) return text;
    final lines = text.split('\n');
    final filtered = lines.where((line) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) return false;
      if (trimmed.length <= 3) return false;
      // Overlay noise
      for (final noise in _overlayNoisePatterns) {
        if (trimmed == noise) return false;
      }
      if (trimmed.startsWith('📱') || trimmed.startsWith('📋') ||
          trimmed.startsWith('⚙️') || trimmed.startsWith('⚠️') ||
          trimmed.startsWith('📄')) return false;
      // System noise
      for (final noise in _systemNoiseExact) {
        if (trimmed == noise) return false;
      }
      for (final regex in _systemNoiseRegexes) {
        if (regex.hasMatch(trimmed)) return false;
      }
      if (RegExp(r'^[\d\s\-\.\,\:\;\/\%\+\*]+$').hasMatch(trimmed)) return false;
      return true;
    }).toList();
    return filtered.join('\n').trim();
  }

  // ────────────────────────────────────────────────
  //  CONTENT SOURCES
  // ────────────────────────────────────────────────

  Future<AssistantContentPayload> fromClipboard() async {
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      final text = data?.text?.trim() ?? '';
      debugPrint('[ContentService] Clipboard read: ${text.length} chars');
      return normalize(
        rawText: text,
        source: AssistantContentSource.clipboard,
      );
    } catch (e) {
      debugPrint('[ContentService] Clipboard read failed: $e');
      return AssistantContentPayload.empty(
        source: AssistantContentSource.clipboard,
      );
    }
  }

  Future<AssistantContentPayload> fromAccessibilityScreen() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();
      final raw = prefs.getString('neuro_screen_text') ?? '';
      final filtered = _filterAllNoise(raw);
      debugPrint('[ContentService] Screen text: raw=${raw.length}, filtered=${filtered.length} chars');
      return normalize(
        rawText: filtered,
        source: AssistantContentSource.accessibilityScreen,
      );
    } catch (e) {
      debugPrint('[ContentService] Screen text failed: $e');
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
