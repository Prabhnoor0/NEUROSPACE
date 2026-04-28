import 'dart:math' as math;
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:flutter_tts/flutter_tts.dart';

/// The three visual states the overlay can be in.
enum _OverlayState { bubble, actionMenu, result }

/// Which action the user picked from the menu.
enum _ActionType {
  none,
  summarizePage,
  simplifyClipboard,
  summarizeClipboard,
  easyRead,
  tts,
}

class OverlayScreen extends StatefulWidget {
  const OverlayScreen({super.key});

  @override
  State<OverlayScreen> createState() => _OverlayScreenState();
}

class _OverlayScreenState extends State<OverlayScreen> {
  // ── State ────────────────────────────────────────────
  _OverlayState _state = _OverlayState.bubble;
  _ActionType _activeAction = _ActionType.none;
  bool _isLoading = false;
  String _resultText = '';
  String _clipboardText = '';
  Map<String, dynamic>? _summaryData;
  String _contentSource = '';

  // ── Audio (Flutter TTS) ──────────────────────────────
  final FlutterTts _flutterTts = FlutterTts();
  bool _isPlaying = false;
  double _ttsProgress = 0.0;

  // ── Backend URL ──────────────────────────────────────
  List<String> get _baseUrls {
    if (Platform.isAndroid) {
      return const ['http://10.0.2.2:8000', 'http://10.0.2.2:8001'];
    }
    return const [
      'http://localhost:8000',
      'http://127.0.0.1:8000',
      'http://localhost:8001',
      'http://127.0.0.1:8001',
    ];
  }

  String get _baseUrl => _baseUrls.first;

  Future<http.Response> _postToBackend(
    String path,
    Map<String, dynamic> payload,
  ) async {
    Object? lastError;
    for (final baseUrl in _baseUrls) {
      try {
        final response = await http
            .post(
              Uri.parse('$baseUrl$path'),
              headers: {'Content-Type': 'application/json'},
              body: json.encode(payload),
            )
            .timeout(const Duration(seconds: 30));
        return response;
      } catch (e) {
        debugPrint('Backend error for $baseUrl: $e');
        lastError = e;
      }
    }
    debugPrint('All backend URLs failed. Last error: $lastError');
    throw lastError ?? Exception('No backend URL could be reached');
  }

  // ── Colors ───────────────────────────────────────────
  static const _purple = Color(0xFF7C4DFF);
  static const _cyan = Color(0xFF00BCD4);
  static const _darkBg = Color(0xFF1A1E2E);
  static const _cardBg = Color(0xFF242938);

  @override
  void initState() {
    super.initState();
    _initTts();

    // Listen for messages from the main app
    try {
      FlutterOverlayWindow.overlayListener.listen((event) {
        if (event == "close") {
          FlutterOverlayWindow.closeOverlay();
        }
      });
    } catch (_) {
      // Overlay listener not available
    }
  }

  Future<void> _initTts() async {
    await _flutterTts.setLanguage('en-US');
    await _flutterTts.setSpeechRate(0.45);
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(1.0);

    _flutterTts.setStartHandler(() {
      if (mounted) setState(() => _isPlaying = true);
    });
    _flutterTts.setCompletionHandler(() {
      if (mounted) setState(() { _isPlaying = false; _ttsProgress = 0.0; });
    });
    _flutterTts.setCancelHandler(() {
      if (mounted) setState(() { _isPlaying = false; _ttsProgress = 0.0; });
    });
    _flutterTts.setErrorHandler((msg) {
      debugPrint('[NeuroSpace] TTS error: $msg');
      if (mounted) setState(() { _isPlaying = false; _ttsProgress = 0.0; });
    });
    _flutterTts.setProgressHandler((text, start, end, word) {
      if (mounted && text.isNotEmpty) {
        setState(() => _ttsProgress = end / text.length);
      }
    });
  }

  /// Safely speak text, truncating to Android's max TTS input length.
  Future<void> _safeTtsSpeak(String text) async {
    const maxLen = 3900; // Android limit is ~4000; leave margin
    String toSpeak = text;
    if (toSpeak.length > maxLen) {
      // Try to cut at the last sentence boundary before the limit
      final truncated = toSpeak.substring(0, maxLen);
      final lastPeriod = truncated.lastIndexOf('.');
      if (lastPeriod > maxLen ~/ 2) {
        toSpeak = truncated.substring(0, lastPeriod + 1);
      } else {
        toSpeak = '$truncated...';
      }
      debugPrint('[NeuroSpace] TTS text truncated from ${text.length} to ${toSpeak.length} chars');
    }
    await _flutterTts.speak(toSpeak);
  }

  @override
  void dispose() {
    _flutterTts.stop();
    super.dispose();
  }

  // ══════════════════════════════════════════════════════
  //  STATE TRANSITIONS
  // ══════════════════════════════════════════════════════

  Future<void> _expandToMenu() async {
    setState(() => _state = _OverlayState.actionMenu);
    try {
      await FlutterOverlayWindow.resizeOverlay(
        WindowSize.matchParent,
        WindowSize.matchParent,
        false,
      );
    } catch (_) {}
  }

  Future<void> _collapseToBubble() async {
    _flutterTts.stop();
    setState(() {
      _state = _OverlayState.bubble;
      _activeAction = _ActionType.none;
      _isLoading = false;
      _resultText = '';
      _clipboardText = '';
      _summaryData = null;
      _isPlaying = false;
      _ttsProgress = 0.0;
    });
    try {
      await FlutterOverlayWindow.resizeOverlay(80, 80, false);
    } catch (_) {}
  }

  Future<void> _expandToResult() async {
    setState(() => _state = _OverlayState.result);
    try {
      await FlutterOverlayWindow.resizeOverlay(
        WindowSize.matchParent,
        WindowSize.matchParent,
        false,
      );
    } catch (_) {}
  }

  // ══════════════════════════════════════════════════════
  //  HELPERS
  // ══════════════════════════════════════════════════════

  /// Fetches FRESH clipboard text every time — no caching.
  Future<String> _getClipboard() async {
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      final text = data?.text?.trim() ?? '';
      debugPrint('[NeuroSpace] Fresh clipboard read: ${text.length} chars');
      return text;
    } catch (e) {
      debugPrint('[NeuroSpace] Clipboard read failed: $e');
      return '';
    }
  }

  /// Resets all content state before starting a new action.
  /// Prevents stale summaryData / resultText from leaking.
  void _clearContentState() {
    _resultText = '';
    _clipboardText = '';
    _summaryData = null;
    _contentSource = '';
    _isLoading = false;
    _isPlaying = false;
  }

  /// Reads the text captured by the NeuroAccessibilityService.
  /// The service writes to SharedPreferences with key 'neuro_screen_text'.
  Future<String> _getScreenText() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload(); // Force reload to get latest from native side
      final raw = prefs.getString('neuro_screen_text')?.trim() ?? '';
      final sourcePackage = prefs.getString('neuro_source_package') ?? 'unknown';
      debugPrint('[NeuroSpace] Raw screen text from $sourcePackage: ${raw.length} chars');
      final cleaned = _filterAllNoise(raw);
      debugPrint('[NeuroSpace] After filtering: ${cleaned.length} chars');
      return cleaned;
    } catch (e) {
      debugPrint('[NeuroSpace] _getScreenText failed: $e');
      return '';
    }
  }

  // ────────────────────────────────────────────────
  //  NOISE FILTER: Overlay UI labels
  // ────────────────────────────────────────────────

  /// Overlay UI labels that must never appear in "page content".
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

  /// Check if a line is overlay UI text.
  bool _isOverlayUiLine(String line) {
    for (final noise in _overlayNoisePatterns) {
      if (line == noise) return true;
    }
    // Also catch partial overlay matches
    if (line.startsWith('📱') || line.startsWith('📋') ||
        line.startsWith('⚙️') || line.startsWith('⚠️') ||
        line.startsWith('📄')) return true;
    return false;
  }

  // ────────────────────────────────────────────────
  //  NOISE FILTER: System UI / notification chrome
  // ────────────────────────────────────────────────

  /// System UI text patterns to reject.
  static const _systemNoiseExact = [
    'Android System notification',
    'Android System',
    'Silent notifications',
    'Notification shade',
    'Quick settings',
    'Now Playing',
    'Paused',
    'Phone signal',
    'Phone signal full',
    'Mobile data',
    'Wi-Fi signal',
    'Wi-Fi signal full',
    'Airplane mode',
    'Battery',
    'Battery full',
    'Battery charging',
    'Do Not Disturb',
    'Silent mode',
    'Alarm set',
    'Location active',
    'Bluetooth connected',
    'NFC on',
    'VPN active',
    'Screen rotation',
    'Cast',
    'Flashlight',
    'Auto-rotate',
    'Brightness',
    'Settings',
    'No SIM card',
    'Emergency calls only',
    'Charging',
    'USB debugging connected',
    'neurospace is running in the background',
    'NeuroSpace is running in the background',
    'Tap for more information',
    'Tap for more options',
    'Tap to turn off',
    'System UI',
    'Status bar',
    'Navigation bar',
    'Home',
    'Recent apps',
    'Overview',
    'Back button',
  ];

  /// Regex patterns for system UI noise.
  static final _systemNoiseRegexes = [
    RegExp(r'^\d{1,2}:\d{2}$'),                // Time like "12:45"
    RegExp(r'^\d{1,2}:\d{2}\s*(AM|PM)$', caseSensitive: false), // 12:45 PM
    RegExp(r'^\d{1,3}%$'),                      // Battery "85%"
    RegExp(r'^Battery\s+\d{1,3}%'),              // "Battery 85%"
    RegExp(r'^\d{1,2}/\d{1,2}/\d{2,4}$'),       // Date "4/28/26"
    RegExp(r'^(Mon|Tue|Wed|Thu|Fri|Sat|Sun)', caseSensitive: false), // Day names
    RegExp(r'^\d+ notifications?$', caseSensitive: false), // "3 notifications"
    RegExp(r'^(Charging|Charged|Battery saver)', caseSensitive: false),
    RegExp(r'^(Wi-Fi|WiFi|LTE|5G|4G|3G|H\+|Edge|No service)', caseSensitive: false),
  ];

  /// Check if a line is system UI noise.
  bool _isSystemUiLine(String line) {
    // Exact matches
    for (final noise in _systemNoiseExact) {
      if (line == noise) return true;
    }
    // Regex matches
    for (final regex in _systemNoiseRegexes) {
      if (regex.hasMatch(line)) return true;
    }
    // Lines that are purely numeric or symbols (button IDs, etc.)
    if (RegExp(r'^[\d\s\-\.\,\:\;\/\%\+\*]+$').hasMatch(line)) return true;
    return false;
  }

  // ────────────────────────────────────────────────
  //  COMBINED NOISE FILTER
  // ────────────────────────────────────────────────

  /// Remove BOTH overlay UI labels AND system UI noise from captured text.
  /// This is the main filter applied before any page summary / TTS action.
  String _filterAllNoise(String text) {
    if (text.isEmpty) return text;
    final lines = text.split('\n');
    int removed = 0;
    final filtered = lines.where((line) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) { removed++; return false; }
      if (trimmed.length <= 3) { removed++; return false; }
      if (_isOverlayUiLine(trimmed)) { removed++; return false; }
      if (_isSystemUiLine(trimmed)) { removed++; return false; }
      return true;
    }).toList();
    if (removed > 0) {
      debugPrint('[NeuroSpace] Filtered $removed noise lines, ${filtered.length} lines remain');
    }
    return filtered.join('\n').trim();
  }

  /// Normalize text for clean line-by-line reading.
  String _normalizeReadingOrder(String text) {
    if (text.isEmpty) return text;
    final lines = text.split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
    // Remove consecutive duplicates
    final deduped = <String>[];
    for (final line in lines) {
      if (deduped.isEmpty || deduped.last != line) {
        deduped.add(line);
      }
    }
    return deduped.join('\n');
  }

  /// Get readable content with source priority:
  /// 1. Accessibility screen text (from background app)
  /// 2. Clipboard text
  /// Returns (text, source label).
  Future<(String, String)> _getReadableContent() async {
    // Priority 1: Accessibility screen text from the foreground app
    final isActive = await _isAccessibilityActive();
    if (isActive) {
      final screenText = await _getScreenText();
      if (screenText.length >= 10) {
        return (_normalizeReadingOrder(screenText), 'current page');
      }
    }
    // Priority 2: Clipboard
    final clipboard = await _getClipboard();
    if (clipboard.length >= 10) {
      return (_normalizeReadingOrder(clipboard), 'clipboard');
    }
    return ('', 'none');
  }

  /// Checks if the accessibility service is active.
  Future<bool> _isAccessibilityActive() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();
      return prefs.getBool('neuro_accessibility_active') ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> _sendToSimplify(String text) async {
    try {
      final response = await _postToBackend('/api/simplify', {
        'text': text,
        'user_profile': 'ADHD',
      });

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final simplified = data['simplified_text'] ?? '';
        final modules = data['modules'] as List? ?? [];

        String display = '';
        if (modules.isNotEmpty) {
          for (final mod in modules) {
            final content = mod['content'] ?? '';
            if (content.toString().trim().isNotEmpty) {
              display += '$content\n\n';
            }
          }
        } else if (simplified.isNotEmpty) {
          display = simplified;
        } else {
          display = 'Could not simplify this text.';
        }

        setState(() {
          _resultText = display.trim();
          _isLoading = false;
        });
      } else {
        setState(() {
          _resultText = '⚠️ Backend error (${response.statusCode}). Try again.';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _resultText =
            '⚠️ Could not reach NeuroSpace backend.\nMake sure it\'s running on ${_baseUrls.join(' or ')}';
        _isLoading = false;
      });
    }
  }

  Future<void> _sendToSummarize(String text, String sourceType) async {
    debugPrint('[NeuroSpace] _sendToSummarize: source=$sourceType, textLen=${text.length}');
    try {
      final response = await _postToBackend('/api/summarize', {
        'text': text,
        'user_profile': 'ADHD',
      });

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        debugPrint('[NeuroSpace] Summarize success: title=${data['title']}');
        setState(() {
          _summaryData = data;
          _isLoading = false;
        });
      } else {
        debugPrint('[NeuroSpace] Summarize failed: status=${response.statusCode}');
        setState(() {
          _resultText = '⚠️ Backend error (${response.statusCode}). Try again.';
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('[NeuroSpace] Summarize error: $e');
      setState(() {
        _resultText =
            '⚠️ Could not reach NeuroSpace backend.\nMake sure it\'s running on ${_baseUrls.join(' or ')}';
        _isLoading = false;
      });
    }
  }

  // ══════════════════════════════════════════════════════
  //  ACTION: SUMMARIZE CURRENT PAGE
  // ══════════════════════════════════════════════════════

  Future<void> _handleSummarizePage() async {
    // Clear stale state FIRST
    setState(() {
      _clearContentState();
      _activeAction = _ActionType.summarizePage;
    });

    final isActive = await _isAccessibilityActive();
    if (!isActive) {
      setState(() {
        _resultText =
            '⚙️ Accessibility Service not enabled\n\n'
            'To summarize any page, please enable NeuroSpace in:\n\n'
            '  Settings → Accessibility → NeuroSpace\n\n'
            'This lets NeuroSpace read on-screen text to help you.';
        _isLoading = false;
      });
      _expandToResult();
      return;
    }

    final screenText = await _getScreenText();
    debugPrint('[NeuroSpace] Page summarize: screenText=${screenText.length} chars');
    if (screenText.isEmpty || screenText.length < 20) {
      setState(() {
        _resultText =
            '📄 No content detected on screen.\n\nMake sure there is text visible in the app behind this overlay.';
        _isLoading = false;
      });
      _expandToResult();
      return;
    }

    setState(() {
      _clipboardText = screenText;
      _contentSource = 'current page';
      _isLoading = true;
    });
    _expandToResult();
    await _sendToSummarize(screenText, 'page');
  }

  // ══════════════════════════════════════════════════════
  //  ACTION: SUMMARIZE CLIPBOARD
  // ══════════════════════════════════════════════════════

  Future<void> _handleSummarizeClipboard() async {
    // Clear ALL stale state before doing anything
    setState(() {
      _clearContentState();
      _activeAction = _ActionType.summarizeClipboard;
    });

    // Fetch FRESH clipboard — no fallback to accessibility text
    final text = await _getClipboard();
    debugPrint('[NeuroSpace] Clipboard summarize: "${text.length > 50 ? text.substring(0, 50) : text}..."');

    if (text.isEmpty || text.length < 10) {
      setState(() {
        _resultText =
            '📋 No text copied to clipboard.\n\nHighlight and copy some text in any app, then tap Summarize again.';
        _isLoading = false;
      });
      _expandToResult();
      return;
    }

    setState(() {
      _clipboardText = text;
      _contentSource = 'clipboard';
      _isLoading = true;
    });
    _expandToResult();
    await _sendToSummarize(text, 'clipboard');
  }

  Future<void> _handleSimplifyClipboard() async {
    // Clear ALL stale state before doing anything
    setState(() {
      _clearContentState();
      _activeAction = _ActionType.simplifyClipboard;
    });

    // Fetch FRESH clipboard — no fallback
    final text = await _getClipboard();
    debugPrint('[NeuroSpace] Clipboard simplify: "${text.length > 50 ? text.substring(0, 50) : text}..."');

    if (text.isEmpty || text.length < 10) {
      setState(() {
        _resultText =
            '📋 No text copied to clipboard.\n\nCopy some text, then tap Simplify again.';
        _isLoading = false;
      });
      _expandToResult();
      return;
    }

    setState(() {
      _clipboardText = text;
      _contentSource = 'clipboard';
      _isLoading = true;
    });
    _expandToResult();
    await _sendToSimplify(text);
  }

  Future<void> _handleEasyRead() async {
    // Clear stale state first
    setState(() {
      _clearContentState();
      _activeAction = _ActionType.easyRead;
    });

    final (text, source) = await _getReadableContent();
    debugPrint('[NeuroSpace] EasyRead: source=$source, textLen=${text.length}');

    if (text.isEmpty) {
      setState(() {
        _activeAction = _ActionType.easyRead;
        _contentSource = '';
        _resultText =
            '📋 No content available for Easy Read.\n\nTry copying text first.';
        _isLoading = false;
      });
      _expandToResult();
      return;
    }

    setState(() {
      _clipboardText = text;
      _contentSource = source;
      _isLoading = true;
    });
    _expandToResult();

    // Call backend AI easy-read endpoint
    try {
      final response = await _postToBackend('/api/assistant/easy-read', {
        'text': text,
        'user_profile': 'ADHD',
      });

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final formatted = data['formatted_text'] as String? ?? '';
        final sections = data['sections'] as List? ?? [];
        final readTime = data['estimated_read_time'] as String? ?? '';

        if (formatted.isNotEmpty) {
          setState(() {
            _resultText = formatted;
            _isLoading = false;
          });
        } else if (sections.isNotEmpty) {
          // Build from sections
          final buffer = StringBuffer();
          for (final sec in sections) {
            final heading = sec['heading'] ?? '';
            final bullets = (sec['bullets'] as List?) ?? [];
            if (heading.isNotEmpty) {
              buffer.writeln(heading);
            }
            for (final b in bullets) {
              buffer.writeln('  • $b');
            }
            buffer.writeln();
          }
          setState(() {
            _resultText = buffer.toString().trim();
            _isLoading = false;
          });
        } else {
          // Fallback to local formatting
          _localEasyRead(text);
        }
      } else {
        debugPrint('[NeuroSpace] EasyRead backend error: ${response.statusCode}');
        _localEasyRead(text);
      }
    } catch (e) {
      debugPrint('[NeuroSpace] EasyRead backend unreachable: $e');
      _localEasyRead(text);
    }
  }

  /// Local fallback for Easy Read when backend is unavailable.
  void _localEasyRead(String text) {
    final normalized = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    final sentences = normalized
        .split(RegExp(r'(?<=[.!?])\s+'))
        .where((s) => s.trim().isNotEmpty)
        .toList();

    final buffer = StringBuffer();
    buffer.writeln('📌 Easy Read Version');
    buffer.writeln();
    for (final sentence in sentences) {
      if (sentence.length > 90) {
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

    setState(() {
      _resultText = buffer.toString().trim();
      _isLoading = false;
    });
  }

  // ══════════════════════════════════════════════════════
  //  ACTION: TEXT-TO-SPEECH
  // ══════════════════════════════════════════════════════

  Future<void> _handleTTS() async {
    // Clear stale state first
    setState(() {
      _clearContentState();
      _activeAction = _ActionType.tts;
    });

    // Use the unified content pipeline — never reads overlay text
    final (text, source) = await _getReadableContent();
    debugPrint('[NeuroSpace] TTS: source=$source, textLen=${text.length}');

    if (text.isEmpty) {
      setState(() {
        _activeAction = _ActionType.tts;
        _contentSource = '';
        _resultText =
            '📋 No content to read!\n\nEither enable the accessibility service to auto-detect screen text, or copy text to your clipboard.';
        _isLoading = false;
      });
      _expandToResult();
      return;
    }

    setState(() {
      _activeAction = _ActionType.tts;
      _clipboardText = text;
      _contentSource = source;
      _resultText = text;
      _isLoading = false;
    });
    _expandToResult();

    // Use Flutter TTS — works offline, no backend needed
    try {
      await _safeTtsSpeak(text);
    } catch (e) {
      debugPrint('[NeuroSpace] Flutter TTS error: $e');
      setState(() {
        _resultText = '⚠️ Text-to-Speech failed: $e';
      });
    }
  }

  // ══════════════════════════════════════════════════════
  //  ACTION: OPEN IN NEUROSPACE
  // ══════════════════════════════════════════════════════

  Future<void> _handleOpenInApp() async {
    // Try screen text first, fall back to clipboard
    String text = '';
    final isAccessibilityActive = await _isAccessibilityActive();
    if (isAccessibilityActive) {
      text = await _getScreenText();
    }
    if (text.isEmpty) {
      text = await _getClipboard();
    }
    await FlutterOverlayWindow.shareData('open_reader:$text');
    await FlutterOverlayWindow.closeOverlay();
  }

  // ══════════════════════════════════════════════════════
  //  BUILD
  // ══════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: switch (_state) {
          _OverlayState.bubble => _buildBubble(),
          _OverlayState.actionMenu => _buildActionMenu(),
          _OverlayState.result => _buildResultView(),
        },
      ),
    );
  }

  // ─────────────────────────────────────────────────────
  //  BUBBLE — small icon pinned to right edge
  // ─────────────────────────────────────────────────────

  Widget _buildBubble() {
    return Align(
      key: const ValueKey('bubble'),
      alignment: Alignment.centerRight,
      child: GestureDetector(
        onTap: _expandToMenu,
        child: Container(
          width: 58,
          height: 58,
          margin: const EdgeInsets.only(right: 4),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [_purple, _cyan],
            ),
            boxShadow: [
              BoxShadow(
                color: _purple.withValues(alpha: 0.4),
                blurRadius: 12,
                spreadRadius: 1,
              ),
            ],
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.45),
              width: 2,
            ),
          ),
          child: const Center(
            child: Icon(
              Icons.psychology_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────
  //  ACTION MENU
  // ─────────────────────────────────────────────────────

  Widget _buildActionMenu() {
    return GestureDetector(
      key: const ValueKey('menu'),
      onTap: _collapseToBubble,
      child: Container(
        color: Colors.black.withValues(alpha: 0.4),
        child: SafeArea(
          child: Center(
            child: GestureDetector(
              onTap: () {},
              child: Container(
                width: 300,
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.7,
                ),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _darkBg,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: _purple.withValues(alpha: 0.25),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.5),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 28,
                            height: 28,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: [_purple, _cyan],
                              ),
                            ),
                            child: const Icon(
                              Icons.psychology_rounded,
                              color: Colors.white,
                              size: 15,
                            ),
                          ),
                          const SizedBox(width: 10),
                          const Text(
                            'NeuroSpace',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                          const Spacer(),
                          GestureDetector(
                            onTap: _collapseToBubble,
                            child: Container(
                              width: 26,
                              height: 26,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.close_rounded,
                                color: Colors.white54,
                                size: 15,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Tap an action below',
                        style: TextStyle(
                          fontSize: 10.5,
                          color: Colors.white.withValues(alpha: 0.35),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _ActionButton(
                        icon: Icons.article_rounded,
                        label: 'Explain Screen',
                        subtitle: 'Summarize visible content',
                        gradient: const [Color(0xFF7C4DFF), Color(0xFF651FFF)],
                        onTap: _handleSummarizePage,
                      ),
                      const SizedBox(height: 6),
                      _ActionButton(
                        icon: Icons.text_fields_rounded,
                        label: 'Simplify Clipboard',
                        subtitle: 'Rewrite in easy words',
                        gradient: const [Color(0xFF5E35B1), Color(0xFF4527A0)],
                        onTap: _handleSimplifyClipboard,
                      ),
                      const SizedBox(height: 6),
                      _ActionButton(
                        icon: Icons.content_paste_rounded,
                        label: 'Summarize Clipboard',
                        subtitle: 'Short summary',
                        gradient: const [Color(0xFF448AFF), Color(0xFF2962FF)],
                        onTap: _handleSummarizeClipboard,
                      ),
                      const SizedBox(height: 6),
                      _ActionButton(
                        icon: Icons.format_size_rounded,
                        label: 'Easy Read',
                        subtitle: 'Digestible bullets',
                        gradient: const [Color(0xFF4CAF50), Color(0xFF2E7D32)],
                        onTap: _handleEasyRead,
                      ),
                      const SizedBox(height: 6),
                      _ActionButton(
                        icon: Icons.volume_up_rounded,
                        label: 'Read Aloud',
                        subtitle: 'Listen to text',
                        gradient: const [Color(0xFF00BCD4), Color(0xFF0097A7)],
                        onTap: _handleTTS,
                      ),
                      const SizedBox(height: 6),
                      _ActionButton(
                        icon: Icons.camera_alt_rounded,
                        label: 'Scan / Open',
                        subtitle: 'OCR + reader',
                        gradient: const [Color(0xFFFF7043), Color(0xFFE64A19)],
                        onTap: _handleOpenInApp,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────
  //  RESULT VIEW (summarized text / TTS playback)
  // ─────────────────────────────────────────────────────

  Widget _buildResultView() {
    final isTTS = _activeAction == _ActionType.tts;
    final isPageSummary = _activeAction == _ActionType.summarizePage;
    final isSimplify = _activeAction == _ActionType.simplifyClipboard;
    final isEasyRead = _activeAction == _ActionType.easyRead;
    final title = isTTS
        ? '🔊 Read Aloud'
        : isPageSummary
        ? '📄 Page Summary'
        : isSimplify
        ? '✨ Simplified Text'
        : isEasyRead
        ? '🔤 Easy Read'
        : '🧠 Text Summary';
    final accentColor = isTTS
        ? _cyan
        : isEasyRead
        ? const Color(0xFF4CAF50)
        : isSimplify
        ? const Color(0xFF5E35B1)
        : _purple;

    return Container(
      margin: const EdgeInsets.only(top: 80, left: 16, right: 16, bottom: 40),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _darkBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: accentColor.withValues(alpha: 0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 40,
            spreadRadius: 10,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isTTS
                      ? Icons.volume_up_rounded
                      : isPageSummary
                      ? Icons.article_rounded
                      : isSimplify
                      ? Icons.text_fields_rounded
                      : isEasyRead
                      ? Icons.format_size_rounded
                      : Icons.auto_awesome_rounded,
                  color: accentColor,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
              GestureDetector(
                onTap: _collapseToBubble,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.close_rounded,
                    color: Colors.white60,
                    size: 20,
                  ),
                ),
              ),
            ],
          ),

          // Source indicator
          if (_contentSource.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: accentColor.withValues(alpha: 0.15)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _contentSource == 'current page'
                        ? Icons.phone_android_rounded
                        : Icons.content_paste_rounded,
                    size: 13,
                    color: accentColor.withValues(alpha: 0.7),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _contentSource == 'current page'
                        ? 'Reading current page'
                        : 'Reading clipboard text',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: accentColor.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 20),

          // TTS playback controls
          if (isTTS && !_isLoading && _resultText.isNotEmpty) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _cardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _cyan.withValues(alpha: 0.15),
                  width: 1,
                ),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () async {
                          if (_isPlaying) {
                            await _flutterTts.stop();
                            setState(() { _isPlaying = false; _ttsProgress = 0.0; });
                          } else {
                            setState(() => _isPlaying = true);
                            await _safeTtsSpeak(_clipboardText);
                          }
                        },
                        child: Container(
                          width: 48,
                          height: 48,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [_cyan, Color(0xFF0097A7)],
                            ),
                          ),
                          child: Icon(
                            _isPlaying
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _isPlaying ? 'Now Playing' : 'Ready to Play',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${_clipboardText.split(' ').take(8).join(' ')}...',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.white.withValues(alpha: 0.4),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      GestureDetector(
                        onTap: () async {
                          await _flutterTts.stop();
                          setState(() { _isPlaying = false; _ttsProgress = 0.0; });
                        },
                        child: Icon(
                          Icons.stop_rounded,
                          color: Colors.white.withValues(alpha: 0.5),
                          size: 28,
                        ),
                      ),
                    ],
                  ),
                  if (_isPlaying) ...[
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: _ttsProgress,
                        backgroundColor: Colors.white.withValues(alpha: 0.1),
                        valueColor: const AlwaysStoppedAnimation<Color>(_cyan),
                        minHeight: 3,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Content area
          Expanded(
            child: _isLoading
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 48,
                          height: 48,
                          child: CircularProgressIndicator(
                            color: accentColor,
                            strokeWidth: 3,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          isTTS
                              ? 'Generating audio...'
                              : isPageSummary
                              ? 'Reading & simplifying page...'
                              : isSimplify
                              ? 'Simplifying copied text...'
                              : 'Simplifying text...',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white.withValues(alpha: 0.5),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  )
                : SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: _cardBg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: accentColor.withValues(alpha: 0.1),
                          width: 1,
                        ),
                      ),
                      child: _summaryData != null
                          ? _buildSummaryContent(_summaryData!, accentColor)
                          : Text(
                              _resultText,
                              style: TextStyle(
                                fontSize: 16,
                                height: 1.6,
                                color: Colors.white.withValues(alpha: 0.85),
                                letterSpacing: 0.2,
                              ),
                            ),
                    ),
                  ),
          ),

          const SizedBox(height: 16),

          if (_summaryData != null && !_isLoading) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildSmallAction(
                  Icons.volume_up_rounded,
                  'Read Aloud',
                  () async {
                    final summaryText = _summaryData!['summary'] ?? '';
                    if (summaryText.toString().isNotEmpty) {
                      setState(() {
                        _activeAction = _ActionType.tts;
                        _clipboardText = summaryText;
                        _resultText = summaryText;
                      });
                      await _safeTtsSpeak(summaryText);
                    }
                  },
                  accentColor,
                ),
                _buildSmallAction(Icons.copy_rounded, 'Copy', () {
                  Clipboard.setData(
                    ClipboardData(text: _summaryData!['summary'] ?? ''),
                  );
                }, accentColor),
                _buildSmallAction(
                  Icons.open_in_new_rounded,
                  'Reader',
                  () async {
                    await FlutterOverlayWindow.shareData(
                      'open_reader:${_summaryData!['summary']}',
                    );
                    await FlutterOverlayWindow.closeOverlay();
                  },
                  accentColor,
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],

          // Bottom action row
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    _flutterTts.stop();
                    setState(() {
                      _state = _OverlayState.actionMenu;
                      _activeAction = _ActionType.none;
                      _isLoading = false;
                      _resultText = '';
                      _isPlaying = false;
                      _ttsProgress = 0.0;
                      _contentSource = '';
                      _summaryData = null;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.arrow_back_rounded,
                          color: Colors.white60,
                          size: 18,
                        ),
                        SizedBox(width: 6),
                        Text(
                          'Back',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.white60,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: _collapseToBubble,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.minimize_rounded,
                          color: Colors.redAccent,
                          size: 18,
                        ),
                        SizedBox(width: 6),
                        Text(
                          'Minimize',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.redAccent,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
  // ─────────────────────────────────────────────────────
  //  STRUCTURED SUMMARY VIEW
  // ─────────────────────────────────────────────────────

  Widget _buildSummaryContent(Map<String, dynamic> data, Color accentColor) {
    final title = data['title'] as String? ?? 'Summary';
    final summary = data['summary'] as String? ?? '';
    final keyPoints =
        (data['key_points'] as List?)?.map((e) => e.toString()).toList() ?? [];
    final highlights =
        (data['highlights'] as List?)?.map((e) => e.toString()).toList() ?? [];
    final readingTime = data['reading_time'] as String? ?? '';
    final tone = data['tone'] as String? ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title.isNotEmpty &&
            title != 'Summary' &&
            title != 'Basic Summary') ...[
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: accentColor,
            ),
          ),
          const SizedBox(height: 12),
        ],
        Text(
          summary,
          style: TextStyle(
            fontSize: 16,
            height: 1.5,
            color: Colors.white.withValues(alpha: 0.9),
          ),
        ),
        if (keyPoints.isNotEmpty) ...[
          const SizedBox(height: 20),
          const Text(
            'Key Takeaways',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Colors.white60,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          ...keyPoints.map(
            (kp) => Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 6, right: 10),
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: accentColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      kp,
                      style: TextStyle(
                        fontSize: 15,
                        height: 1.4,
                        color: Colors.white.withValues(alpha: 0.8),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
        if (highlights.isNotEmpty) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: accentColor.withValues(alpha: 0.2)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.format_quote_rounded, color: accentColor, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    highlights.first,
                    style: TextStyle(
                      fontSize: 14,
                      fontStyle: FontStyle.italic,
                      color: accentColor.withValues(alpha: 0.9),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        if (readingTime.isNotEmpty || tone.isNotEmpty) ...[
          const SizedBox(height: 20),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (readingTime.isNotEmpty)
                _buildChip(Icons.timer_outlined, readingTime, accentColor),
              if (tone.isNotEmpty)
                _buildChip(Icons.mood_rounded, tone, accentColor),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSmallAction(
    IconData icon,
    String label,
    VoidCallback onTap,
    Color color,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
              border: Border.all(color: color.withValues(alpha: 0.2)),
            ),
            child: Icon(icon, size: 20, color: color),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.white.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════
//  ACTION BUTTON WIDGET
// ═══════════════════════════════════════════════════════

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final List<Color> gradient;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.gradient,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF242938),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: gradient[0].withValues(alpha: 0.2),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(11),
                gradient: LinearGradient(
                  colors: gradient,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: gradient[0].withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(icon, color: Colors.white, size: 19),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: 0.2,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 10.5,
                      color: Colors.white.withValues(alpha: 0.4),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              color: Colors.white.withValues(alpha: 0.2),
              size: 13,
            ),
          ],
        ),
      ),
    );
  }
}
