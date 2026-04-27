/// NeuroSpace — Bubble Provider
/// State management for the global floating accessibility bubble.
/// Controls bubble position, expansion state, action results, and TTS.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:io' show Platform;

enum BubbleState { collapsed, expanded, result }

enum BubbleAction { none, tts, summarize, easyRead, scan }

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
  String get _baseUrl {
    if (Platform.isAndroid) {
      return 'http://10.0.2.2:8000';
    } else {
      return 'http://localhost:8000';
    }
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

  // ══════════════════════════════════════════════
  //  ACTION: TEXT-TO-SPEECH
  // ══════════════════════════════════════════════

  Future<void> handleTTS({String? text, double speechRate = 0.45}) async {
    String textToRead = text ?? '';

    if (textToRead.isEmpty) {
      textToRead = await _getClipboard();
    }

    if (textToRead.isEmpty || textToRead.length < 5) {
      _currentAction = BubbleAction.tts;
      _errorText = '📋 No text to read!\n\nCopy some text first, then tap Read Aloud.';
      _state = BubbleState.result;
      notifyListeners();
      return;
    }

    _currentAction = BubbleAction.tts;
    _clipboardText = textToRead;
    _resultText = textToRead;
    _state = BubbleState.result;
    _isSpeaking = true;
    notifyListeners();

    try {
      await _tts.setSpeechRate(speechRate);
      await _tts.speak(textToRead);
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

  Future<void> handleSummarize({String? text, String profile = 'adhd'}) async {
    String textToSummarize = text ?? '';

    if (textToSummarize.isEmpty) {
      textToSummarize = await _getClipboard();
    }

    if (textToSummarize.isEmpty || textToSummarize.length < 10) {
      _currentAction = BubbleAction.summarize;
      _errorText =
          '📋 No text to summarize!\n\nCopy some text first, then tap Summarize.';
      _state = BubbleState.result;
      notifyListeners();
      return;
    }

    _currentAction = BubbleAction.summarize;
    _clipboardText = textToSummarize;
    _isProcessing = true;
    _state = BubbleState.result;
    notifyListeners();

    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/api/simplify'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({
              'text': textToSummarize,
              'user_profile': profile,
            }),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final simplified = data['simplified_text'] ?? '';
        final modules = data['modules'] as List? ?? [];

        String display = '';
        if (modules.isNotEmpty) {
          for (final mod in modules) {
            final title = mod['title'] ?? '';
            final content = mod['content'] ?? '';
            display += '📌 $title\n$content\n\n';
          }
        } else if (simplified.isNotEmpty) {
          display = simplified;
        } else {
          display = 'Could not summarize this text.';
        }

        _resultText = display.trim();
      } else {
        _errorText = '⚠️ Backend error (${response.statusCode}). Try again.';
      }
    } catch (e) {
      _errorText = '⚠️ Could not reach backend.\nMake sure it\'s running.';
    }

    _isProcessing = false;
    notifyListeners();
  }

  // ══════════════════════════════════════════════
  //  ACTION: EASY READ (Format for neurodivergent)
  // ══════════════════════════════════════════════

  Future<void> handleEasyRead({String? text}) async {
    String textToFormat = text ?? '';

    if (textToFormat.isEmpty) {
      textToFormat = await _getClipboard();
    }

    if (textToFormat.isEmpty || textToFormat.length < 5) {
      _currentAction = BubbleAction.easyRead;
      _errorText =
          '📋 No text to format!\n\nCopy some text first, then tap Easy Read.';
      _state = BubbleState.result;
      notifyListeners();
      return;
    }

    _currentAction = BubbleAction.easyRead;
    _clipboardText = textToFormat;

    // Format locally for instant response:
    // - Break into short sentences
    // - Add bullet points
    // - Clean up whitespace
    final sentences = textToFormat
        .replaceAll(RegExp(r'\s+'), ' ')
        .split(RegExp(r'(?<=[.!?])\s+'))
        .where((s) => s.trim().isNotEmpty)
        .toList();

    final buffer = StringBuffer();
    for (int i = 0; i < sentences.length; i++) {
      String sentence = sentences[i].trim();
      // Keep sentences short — split long ones at commas
      if (sentence.length > 80) {
        final parts = sentence.split(RegExp(r',\s*'));
        for (final part in parts) {
          if (part.trim().isNotEmpty) {
            buffer.writeln('• ${part.trim()}');
          }
        }
      } else {
        buffer.writeln('• $sentence');
      }
      if (i < sentences.length - 1) buffer.writeln();
    }

    _resultText = buffer.toString().trim();
    _state = BubbleState.result;
    notifyListeners();
  }

  @override
  void dispose() {
    _tts.stop();
    super.dispose();
  }
}
