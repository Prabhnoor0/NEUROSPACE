/// NeuroSpace — Bubble Provider
/// State management for the global floating accessibility bubble.
/// Controls bubble position, expansion state, action results, and TTS.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:io' show Platform;

import '../models/assistant_content_payload.dart';
import '../services/assistant_action_engine.dart';
import '../services/assistant_content_service.dart';
import '../services/api_service.dart';

enum BubbleState { collapsed, expanded, result }

enum BubbleAction { none, tts, simplify, summarize, easyRead, scan, voice }

class BubbleProvider extends ChangeNotifier {
  // ── State ──
  BubbleState _state = BubbleState.collapsed;
  BubbleAction _currentAction = BubbleAction.none;
  Offset _position = const Offset(20, 200);
  bool _isVisible = true;
  bool _isProcessing = false;
  bool _isSpeaking = false;
  String _resultText = '';
  String _clipboardText = '';
  String _errorText = '';

  // ── TTS ──
  final FlutterTts _tts = FlutterTts();
  final AssistantContentService _contentService = AssistantContentService();
  final AssistantActionEngine _actionEngine = const AssistantActionEngine();

  BubbleProvider() {
    _initTts();
  }

  void _initTts() {
    _tts.setCompletionHandler(() {
      _isSpeaking = false;
      notifyListeners();
    });
    _tts.setErrorHandler((msg) {
      _isSpeaking = false;
      notifyListeners();
    });
    _tts.setCancelHandler(() {
      _isSpeaking = false;
      notifyListeners();
    });
  }

  // ── Getters ──
  BubbleState get state => _state;
  BubbleAction get currentAction => _currentAction;
  Offset get position => _position;
  bool get isVisible => _isVisible;
  bool get isProcessing => _isProcessing;
  bool get isSpeaking => _isSpeaking;
  String get resultText => _resultText;
  String get clipboardText => _clipboardText;
  String get errorText => _errorText;

  // ── Backend URL ──
  List<String> get _baseUrls {
    if (Platform.isAndroid) {
      return const [
        'http://10.0.2.2:8000',
        'http://10.0.2.2:8001',
      ];
    }
    return const [
      'http://localhost:8000',
      'http://127.0.0.1:8000',
      'http://localhost:8001',
      'http://127.0.0.1:8001',
    ];
  }

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
        lastError = e;
      }
    }
    throw lastError ?? Exception('No backend URL could be reached');
  }

  // ══════════════════════════════════════════════
  //  STATE TRANSITIONS
  // ══════════════════════════════════════════════

  void expand() {
    _state = BubbleState.expanded;
    _errorText = '';
    notifyListeners();
  }

  void collapse() {
    _tts.stop();
    _state = BubbleState.collapsed;
    _currentAction = BubbleAction.none;
    _isProcessing = false;
    _isSpeaking = false;
    _resultText = '';
    _clipboardText = '';
    _errorText = '';
    notifyListeners();
  }

  void showResult() {
    _state = BubbleState.result;
    notifyListeners();
  }

  void updatePosition(Offset delta) {
    _position += delta;
    notifyListeners();
  }

  void setPosition(Offset pos) {
    _position = pos;
    notifyListeners();
  }

  void toggleVisibility() {
    _isVisible = !_isVisible;
    notifyListeners();
  }

  void show() {
    _isVisible = true;
    notifyListeners();
  }

  void hide() {
    _isVisible = false;
    collapse();
    notifyListeners();
  }

  // ══════════════════════════════════════════════
  //  CLIPBOARD ACCESS
  // ══════════════════════════════════════════════

  Future<String> _getClipboard() async {
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      return data?.text?.trim() ?? '';
    } catch (_) {
      return '';
    }
  }

  Future<AssistantContentPayload> _resolvePayload({String? text}) async {
    if (text != null && text.trim().isNotEmpty) {
      debugPrint('[NeuroSpace] Using explicit text input (${text.length} chars)');
      return _contentService.fromPastedText(text);
    }

    final accessibilityActive = await _contentService.isAccessibilityServiceActive();
    debugPrint('[NeuroSpace] Accessibility service active: $accessibilityActive');

    if (accessibilityActive) {
      final screenPayload = await _contentService.fromAccessibilityScreen();
      debugPrint('[NeuroSpace] Screen text: ${screenPayload.text.length} chars, '
          'hasEnough: ${screenPayload.hasEnoughText}');
      if (screenPayload.text.isNotEmpty) {
        debugPrint('[NeuroSpace] Screen preview: "${screenPayload.text.substring(0, screenPayload.text.length > 100 ? 100 : screenPayload.text.length)}..."');
      }
      if (screenPayload.hasEnoughText) {
        debugPrint('[NeuroSpace] ✅ Using SCREEN text as source');
        return screenPayload;
      }
    }

    final clipboardPayload = await _contentService.fromClipboard();
    debugPrint('[NeuroSpace] Falling back to clipboard: ${clipboardPayload.text.length} chars');
    return clipboardPayload;
  }

  // ══════════════════════════════════════════════
  //  ACTION: TEXT-TO-SPEECH
  // ══════════════════════════════════════════════

  Future<void> handleTTS({String? text, double speechRate = 0.45}) async {
    final payload = await _resolvePayload(text: text);

    if (!payload.hasEnoughText) {
      _currentAction = BubbleAction.tts;
      _errorText = '📋 No text to read!\n\nCopy some text first, then tap Read Aloud.';
      _state = BubbleState.result;
      notifyListeners();
      return;
    }

    _currentAction = BubbleAction.tts;
    _clipboardText = payload.text;
    _resultText = payload.text;
    _state = BubbleState.result;
    _isSpeaking = true;
    notifyListeners();

    try {
      await _tts.setSpeechRate(speechRate);
      await _tts.speak(payload.text);
    } catch (e) {
      _isSpeaking = false;
      _errorText = '⚠️ TTS error: $e';
      notifyListeners();
    }
  }

  Future<void> stopTTS() async {
    await _tts.stop();
    _isSpeaking = false;
    notifyListeners();
  }

  Future<void> toggleTTS() async {
    if (_isSpeaking) {
      await stopTTS();
    } else if (_resultText.isNotEmpty) {
      _isSpeaking = true;
      notifyListeners();
      await _tts.speak(_resultText);
    }
  }

  // ══════════════════════════════════════════════
  //  ACTION: SUMMARIZE
  // ══════════════════════════════════════════════

  Future<void> handleSimplify({String? text, String profile = 'ADHD'}) async {
    final payload = await _resolvePayload(text: text);

    if (!payload.hasEnoughText) {
      _currentAction = BubbleAction.simplify;
      _errorText =
          '📋 No text to simplify!\n\nCopy some text first, then tap Simplify.';
      _state = BubbleState.result;
      notifyListeners();
      return;
    }

    _currentAction = BubbleAction.simplify;
    _clipboardText = payload.text;
    _isProcessing = true;
    _errorText = '';
    _state = BubbleState.result;
    notifyListeners();

    try {
      final result = await _actionEngine.simplify(payload, profile: profile);
      if (result.success) {
        _resultText = result.primaryText;
      } else {
        _errorText = '⚠️ ${result.primaryText} Try again.';
      }
    } catch (e) {
      _errorText =
          '⚠️ Could not reach backend.\nMake sure it\'s running on ${_baseUrls.join(' or ')}.';
    }

    _isProcessing = false;
    notifyListeners();
  }

  Future<void> handleSummarize({String? text, String profile = 'ADHD'}) async {
    final payload = await _resolvePayload(text: text);

    if (!payload.hasEnoughText) {
      _currentAction = BubbleAction.summarize;
      _errorText =
          '📋 No text to summarize!\n\nCopy some text first, then tap Summarize.';
      _state = BubbleState.result;
      notifyListeners();
      return;
    }

    _currentAction = BubbleAction.summarize;
    _clipboardText = payload.text;
    _isProcessing = true;
    _errorText = '';
    _state = BubbleState.result;
    notifyListeners();

    try {
      final result = await _actionEngine.summarize(payload, profile: profile);
      if (result.success) {
        _resultText = result.primaryText;
      } else {
        _errorText = '⚠️ ${result.primaryText} Try again.';
      }
    } catch (e) {
      _errorText =
          '⚠️ Could not reach backend.\nMake sure it\'s running on ${_baseUrls.join(' or ')}.';
    }

    _isProcessing = false;
    notifyListeners();
  }

  // ══════════════════════════════════════════════
  //  ACTION: EASY READ (Format for neurodivergent)
  // ══════════════════════════════════════════════

  Future<void> handleEasyRead({String? text}) async {
    final payload = await _resolvePayload(text: text);

    if (!payload.hasEnoughText) {
      _currentAction = BubbleAction.easyRead;
      _errorText =
          '📋 No text to format!\n\nCopy some text first, then tap Easy Read.';
      _state = BubbleState.result;
      notifyListeners();
      return;
    }

    _currentAction = BubbleAction.easyRead;
    _clipboardText = payload.text;
    final result = _actionEngine.easyRead(payload);
    _resultText = result.primaryText;
    _state = BubbleState.result;
    notifyListeners();
  }

  Future<void> handleVoiceCommand(String transcription) async {
    _currentAction = BubbleAction.voice;
    _isProcessing = true;
    _errorText = '';
    _state = BubbleState.result;
    notifyListeners();

    try {
      final intent = await ApiService.parseVoiceIntent(transcription);
      final feature = (intent?['feature_name'] ?? '').toString().toLowerCase();

      if (feature == 'read') {
        _isProcessing = false;
        notifyListeners();
        await handleTTS();
        return;
      }
      if (feature == 'simplify') {
        _isProcessing = false;
        notifyListeners();
        await handleSimplify();
        return;
      }
      if (feature == 'summarize') {
        _isProcessing = false;
        notifyListeners();
        await handleSummarize();
        return;
      }
      if (feature == 'close') {
        _isProcessing = false;
        collapse();
        return;
      }

      _resultText = (intent?['speak_message'] ??
              'I could not match that command. Try: read this, simplify this, summarize this.')
          .toString();
    } catch (e) {
      _errorText = '⚠️ Voice command failed. Please try again.';
    }

    _isProcessing = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _tts.stop();
    super.dispose();
  }
}
