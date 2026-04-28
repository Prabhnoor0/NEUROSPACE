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
    'Screen text, clipboard, OCR, or voice',
    'Read visible text or clipboard',
    'Convert into easier language',
    'Get a simple summary',
    'Format for your brain',
    'Camera → OCR → actions',
    'Voice Command',
    'Listening...',
    'Scan Text',
    'Scroll for more',
    'Swipe up for more',
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
    RegExp(r'^(Wi-Fi|WiFi|LTE|5G|4G|3G|H\+|Edge|No service)',
        caseSensitive: false),
  ];

  // ────────────────────────────────────────────────
  //  ADVERTISEMENT / PROMO NOISE FILTER
  // ────────────────────────────────────────────────

  static final _adNoiseRegexes = [
    // Common ad labels
    RegExp(r'^(Ad|AD|Ads|ADS|Sponsored|Advertisement|Promoted|Promo)$',
        caseSensitive: false),
    // Call-to-action buttons from ads
    RegExp(
        r'^(Install Now|Download|Get it on|Shop Now|Buy Now|Order Now|Sign Up|Subscribe|Learn More|Visit Site|Open App)$',
        caseSensitive: false),
    // Login / signup prompts (usually promo banners)
    RegExp(r'^Login for better experience', caseSensitive: false),
    RegExp(r'^(Login Now|Sign In|Register|Create Account)$',
        caseSensitive: false),
    // Ad controls
    RegExp(r'^(Skip Ad|Close Ad|Why this ad|Report this ad|Ad choices)$',
        caseSensitive: false),
    // Ad dimensions
    RegExp(r'^\d+\s*[×x]\s*\d+$'),
    // App store prompts
    RegExp(r'^(Free|FREE|\$\d+\.\d{2}|₹\d+|€\d+|£\d+)\s*$'),
    // "Rated X stars" ad fragments
    RegExp(r'^\d+(\.\d+)?\s*★', caseSensitive: false),
    // Cookie/GDPR consent banners
    RegExp(r'(Accept (All )?Cookies|Cookie Policy|We use cookies)',
        caseSensitive: false),
    RegExp(r'^(Accept|Reject|Manage|Preferences|Consent)$',
        caseSensitive: false),
  ];

  static const _adNoiseSubstrings = [
    'AdChoices',
    'Sponsored Content',
    'Promoted Content',
    'Install from',
    'Download the app',
    'Get the app',
    'ADVERTISEMENT',
    'adsbygoogle',
    'doubleclick',
    'googlesyndication',
  ];

  // ────────────────────────────────────────────────
  //  NAVIGATION CHROME FILTER
  // ────────────────────────────────────────────────

  static const _navChromeExact = {
    'Home',
    'Search',
    'Menu',
    'More',
    'Share',
    'Back',
    'Forward',
    'Refresh',
    'Stop',
    'Settings',
    'Close',
    'Cancel',
    'OK',
    'Done',
    'Yes',
    'No',
    'Got it',
    'Allow',
    'Deny',
    'Accept',
    'Decline',
    'Skip',
    'Next',
    'Previous',
    'Prev',
    'Like',
    'Dislike',
    'Save',
    'Bookmark',
    'Report',
    'Follow',
    'Unfollow',
    'Mute',
    'Unmute',
    'Reply',
    'Repost',
    'Retweet',
  };

  /// Combined noise filter for overlay + system UI + ads + navigation chrome.
  String _filterAllNoise(String text) {
    if (text.isEmpty) return text;
    final lines = text.split('\n');
    final filtered = lines.where((line) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) return false;

      // Skip very short fragments (single words under 4 chars are usually icons/labels)
      if (trimmed.length <= 3) return false;

      // Overlay noise — exact match
      for (final noise in _overlayNoisePatterns) {
        if (trimmed == noise) return false;
      }
      if (trimmed.startsWith('📱') ||
          trimmed.startsWith('📋') ||
          trimmed.startsWith('⚙️') ||
          trimmed.startsWith('⚠️') ||
          trimmed.startsWith('📄')) return false;

      // System noise — exact match
      for (final noise in _systemNoiseExact) {
        if (trimmed == noise) return false;
      }
      for (final regex in _systemNoiseRegexes) {
        if (regex.hasMatch(trimmed)) return false;
      }

      // Pure numeric / symbol noise
      if (RegExp(r'^[\d\s\-\.\,\:\;\/%\+\*]+$').hasMatch(trimmed)) {
        return false;
      }

      // Navigation chrome — exact match
      if (_navChromeExact.contains(trimmed)) return false;

      // Ad noise — regex patterns
      for (final regex in _adNoiseRegexes) {
        if (regex.hasMatch(trimmed)) return false;
      }

      // Ad noise — substring match
      for (final adText in _adNoiseSubstrings) {
        if (trimmed.contains(adText)) return false;
      }

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
      final pkg = prefs.getString('neuro_source_package') ?? '';
      final filtered = _filterAllNoise(raw);
      debugPrint(
          '[ContentService] Screen text from $pkg: raw=${raw.length}, filtered=${filtered.length} chars');

      if (filtered.length < 15) {
        debugPrint(
            '[ContentService] Filtered text too short (${filtered.length}), likely just UI chrome');
        return AssistantContentPayload.empty(
          source: AssistantContentSource.accessibilityScreen,
        );
      }

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
