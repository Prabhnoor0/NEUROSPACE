import 'dart:math' as math;
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';

/// The three visual states the overlay can be in.
enum _OverlayState { bubble, actionMenu, result }

/// Which action the user picked from the menu.
enum _ActionType { none, summarizePage, summarizeClipboard, tts }

class OverlayScreen extends StatefulWidget {
  const OverlayScreen({super.key});

  @override
  State<OverlayScreen> createState() => _OverlayScreenState();
}

class _OverlayScreenState extends State<OverlayScreen>
    with TickerProviderStateMixin {
  // ── State ────────────────────────────────────────────
  _OverlayState _state = _OverlayState.bubble;
  _ActionType _activeAction = _ActionType.none;
  bool _isLoading = false;
  String _resultText = '';
  String _clipboardText = '';

  // ── Animation ────────────────────────────────────────
  late AnimationController _bubbleController;
  late AnimationController _pulseController;

  // ── Audio ────────────────────────────────────────────
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;

  // ── Backend URL ──────────────────────────────────────
  static const String _baseUrl = 'http://10.0.2.2:8080';

  // ── Colors ───────────────────────────────────────────
  static const _purple = Color(0xFF7C4DFF);
  static const _cyan = Color(0xFF00BCD4);
  static const _darkBg = Color(0xFF1A1E2E);
  static const _cardBg = Color(0xFF242938);

  @override
  void initState() {
    super.initState();

    _bubbleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    // Listen for messages from the main app
    FlutterOverlayWindow.overlayListener.listen((event) {
      if (event == "close") {
        FlutterOverlayWindow.closeOverlay();
      }
    });
  }

  @override
  void dispose() {
    _bubbleController.dispose();
    _pulseController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  // ══════════════════════════════════════════════════════
  //  STATE TRANSITIONS
  // ══════════════════════════════════════════════════════

  Future<void> _expandToMenu() async {
    setState(() => _state = _OverlayState.actionMenu);
    await FlutterOverlayWindow.resizeOverlay(350, 480, true);
  }

  Future<void> _collapseToBubble() async {
    _audioPlayer.stop();
    setState(() {
      _state = _OverlayState.bubble;
      _activeAction = _ActionType.none;
      _isLoading = false;
      _resultText = '';
      _clipboardText = '';
      _isPlaying = false;
    });
    await FlutterOverlayWindow.resizeOverlay(90, 90, true);
  }

  Future<void> _expandToResult() async {
    setState(() => _state = _OverlayState.result);
    await FlutterOverlayWindow.resizeOverlay(
      WindowSize.matchParent,
      WindowSize.matchParent,
      true,
    );
  }

  // ══════════════════════════════════════════════════════
  //  HELPERS
  // ══════════════════════════════════════════════════════

  Future<String> _getClipboard() async {
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      return data?.text?.trim() ?? '';
    } catch (_) {
      return '';
    }
  }

  /// Reads the text captured by the NeuroAccessibilityService.
  /// The service writes to SharedPreferences with key 'neuro_screen_text'.
  Future<String> _getScreenText() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload(); // Force reload to get latest from native side
      return prefs.getString('neuro_screen_text')?.trim() ?? '';
    } catch (_) {
      return '';
    }
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
      final response = await http
          .post(
            Uri.parse('$_baseUrl/api/simplify'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({
              'text': text,
              'user_profile': 'adhd',
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
            display += '### $title\n$content\n\n';
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
            '⚠️ Could not reach NeuroSpace backend.\nMake sure it\'s running at $_baseUrl';
        _isLoading = false;
      });
    }
  }

  // ══════════════════════════════════════════════════════
  //  ACTION: SUMMARIZE CURRENT PAGE
  // ══════════════════════════════════════════════════════

  Future<void> _handleSummarizePage() async {
    final isActive = await _isAccessibilityActive();
    if (!isActive) {
      setState(() {
        _activeAction = _ActionType.summarizePage;
        _resultText =
            '⚙️ Accessibility Service not enabled\n\n'
            'To summarize any page, please enable NeuroSpace in:\n\n'
            '  Settings → Accessibility → NeuroSpace\n\n'
            'This lets NeuroSpace read on-screen text to help you.';
        _isLoading = false;
      });
      await _expandToResult();
      return;
    }

    final screenText = await _getScreenText();
    if (screenText.isEmpty || screenText.length < 20) {
      setState(() {
        _activeAction = _ActionType.summarizePage;
        _resultText =
            '📄 No content detected on screen.\n\nMake sure there is text visible in the app behind this overlay.';
        _isLoading = false;
      });
      await _expandToResult();
      return;
    }

    setState(() {
      _activeAction = _ActionType.summarizePage;
      _clipboardText = screenText;
      _isLoading = true;
    });
    await _expandToResult();
    await _sendToSimplify(screenText);
  }

  // ══════════════════════════════════════════════════════
  //  ACTION: SUMMARIZE CLIPBOARD
  // ══════════════════════════════════════════════════════

  Future<void> _handleSummarizeClipboard() async {
    final text = await _getClipboard();
    if (text.isEmpty || text.length < 10) {
      setState(() {
        _activeAction = _ActionType.summarizeClipboard;
        _resultText =
            '📋 No text on clipboard!\n\nHighlight and copy some text in any app, then tap Summarize again.';
        _isLoading = false;
      });
      await _expandToResult();
      return;
    }

    setState(() {
      _activeAction = _ActionType.summarizeClipboard;
      _clipboardText = text;
      _isLoading = true;
    });
    await _expandToResult();
    await _sendToSimplify(text);
  }

  // ══════════════════════════════════════════════════════
  //  ACTION: TEXT-TO-SPEECH
  // ══════════════════════════════════════════════════════

  Future<void> _handleTTS() async {
    // Try screen text first, fall back to clipboard
    String text = '';
    final isAccessibilityActive = await _isAccessibilityActive();
    if (isAccessibilityActive) {
      text = await _getScreenText();
    }
    if (text.isEmpty || text.length < 10) {
      text = await _getClipboard();
    }

    if (text.isEmpty || text.length < 10) {
      setState(() {
        _activeAction = _ActionType.tts;
        _resultText =
            '📋 No content to read!\n\nEither enable the accessibility service to auto-detect screen text, or copy text to your clipboard.';
        _isLoading = false;
      });
      await _expandToResult();
      return;
    }

    setState(() {
      _activeAction = _ActionType.tts;
      _clipboardText = text;
      _isLoading = true;
    });
    await _expandToResult();

    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/api/text-to-speech'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({
              'text': text,
              'speed': 1.0,
            }),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final dir = await getTemporaryDirectory();
        final file = File('${dir.path}/neuro_tts.mp3');
        await file.writeAsBytes(response.bodyBytes);

        await _audioPlayer.play(DeviceFileSource(file.path));
        setState(() {
          _isPlaying = true;
          _resultText = text;
          _isLoading = false;
        });

        _audioPlayer.onPlayerComplete.listen((_) {
          if (mounted) setState(() => _isPlaying = false);
        });
      } else {
        setState(() {
          _resultText = '⚠️ TTS failed (${response.statusCode}). Try again.';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _resultText =
            '⚠️ Could not reach backend for TTS.\nMake sure it\'s running at $_baseUrl';
        _isLoading = false;
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
      child: switch (_state) {
        _OverlayState.bubble => _buildBubble(),
        _OverlayState.actionMenu => _buildActionMenu(),
        _OverlayState.result => _buildResultView(),
      },
    );
  }

  // ─────────────────────────────────────────────────────
  //  BUBBLE (small floating icon — anchored to right side)
  // ─────────────────────────────────────────────────────

  Widget _buildBubble() {
    return GestureDetector(
      onTap: _expandToMenu,
      child: Align(
        alignment: Alignment.centerRight,
        child: AnimatedBuilder(
          animation: _bubbleController,
          builder: (context, child) {
            final bounce =
                math.sin(_bubbleController.value * 2 * math.pi) * 4;
            final pulseScale =
                1.0 + (_pulseController.value * 0.05);
            return Transform.translate(
              offset: Offset(0, bounce),
              child: Transform.scale(
                scale: pulseScale,
                child: Container(
                  width: 60,
                  height: 60,
                  margin: const EdgeInsets.only(right: 6),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [_purple, _cyan],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: _purple.withValues(alpha: 0.45),
                        blurRadius: 16,
                        spreadRadius: 1,
                      ),
                      BoxShadow(
                        color: _cyan.withValues(alpha: 0.2),
                        blurRadius: 10,
                        offset: const Offset(2, 2),
                      ),
                    ],
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.4),
                      width: 2,
                    ),
                  ),
                  child: const Icon(
                    Icons.psychology_rounded,
                    color: Colors.white,
                    size: 30,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────
  //  ACTION MENU (4 option cards)
  // ─────────────────────────────────────────────────────

  Widget _buildActionMenu() {
    return Center(
      child: Container(
        width: 320,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: _darkBg,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: _purple.withValues(alpha: 0.3), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.65),
              blurRadius: 30,
              spreadRadius: 5,
            ),
            BoxShadow(
              color: _purple.withValues(alpha: 0.08),
              blurRadius: 40,
              spreadRadius: -5,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(colors: [_purple, _cyan]),
                  ),
                  child: const Icon(Icons.psychology_rounded,
                      color: Colors.white, size: 16),
                ),
                const SizedBox(width: 10),
                const Text(
                  'NeuroSpace',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: 0.3,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: _collapseToBubble,
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.close_rounded,
                        color: Colors.white54, size: 16),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 5),
            Text(
              'Tap an action to process this page',
              style: TextStyle(
                fontSize: 11,
                color: Colors.white.withValues(alpha: 0.4),
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 14),

            // ── ACTION 1: Summarize Page (uses AccessibilityService) ──
            _ActionButton(
              icon: Icons.article_rounded,
              label: 'Summarize Page',
              subtitle: 'Simplify current screen content',
              gradient: const [Color(0xFF7C4DFF), Color(0xFF651FFF)],
              onTap: _handleSummarizePage,
            ),
            const SizedBox(height: 8),

            // ── ACTION 2: Summarize Clipboard ──
            _ActionButton(
              icon: Icons.content_paste_rounded,
              label: 'Summarize Copied Text',
              subtitle: 'Simplify text from clipboard',
              gradient: const [Color(0xFF448AFF), Color(0xFF2962FF)],
              onTap: _handleSummarizeClipboard,
            ),
            const SizedBox(height: 8),

            // ── ACTION 3: Read Aloud ──
            _ActionButton(
              icon: Icons.volume_up_rounded,
              label: 'Read Aloud',
              subtitle: 'Listen to page or copied text',
              gradient: const [Color(0xFF00BCD4), Color(0xFF0097A7)],
              onTap: _handleTTS,
            ),
            const SizedBox(height: 8),

            // ── ACTION 4: Open in NeuroSpace ──
            _ActionButton(
              icon: Icons.open_in_new_rounded,
              label: 'Open in NeuroSpace',
              subtitle: 'Read with full accessibility tools',
              gradient: const [Color(0xFFFF7043), Color(0xFFE64A19)],
              onTap: _handleOpenInApp,
            ),
          ],
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
    final title = isTTS
        ? '🔊 Read Aloud'
        : isPageSummary
            ? '📄 Page Summary'
            : '🧠 Text Summary';
    final accentColor = isTTS ? _cyan : _purple;

    return Container(
      margin: const EdgeInsets.only(top: 80, left: 16, right: 16, bottom: 40),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _darkBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: accentColor.withValues(alpha: 0.3), width: 1.5),
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
                  child: const Icon(Icons.close_rounded,
                      color: Colors.white60, size: 20),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // TTS playback controls
          if (isTTS && !_isLoading && _resultText.isNotEmpty) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _cardBg,
                borderRadius: BorderRadius.circular(16),
                border:
                    Border.all(color: _cyan.withValues(alpha: 0.15), width: 1),
              ),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () async {
                      if (_isPlaying) {
                        await _audioPlayer.pause();
                        setState(() => _isPlaying = false);
                      } else {
                        await _audioPlayer.resume();
                        setState(() => _isPlaying = true);
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
                        const Text(
                          'Now Playing',
                          style: TextStyle(
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
                      await _audioPlayer.stop();
                      setState(() => _isPlaying = false);
                    },
                    child: Icon(Icons.stop_rounded,
                        color: Colors.white.withValues(alpha: 0.5), size: 28),
                  ),
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
                      child: Text(
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

          // Bottom action row
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () async {
                    _audioPlayer.stop();
                    setState(() {
                      _state = _OverlayState.actionMenu;
                      _activeAction = _ActionType.none;
                      _isLoading = false;
                      _resultText = '';
                      _isPlaying = false;
                    });
                    await FlutterOverlayWindow.resizeOverlay(350, 480, true);
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
                        Icon(Icons.arrow_back_rounded,
                            color: Colors.white60, size: 18),
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
                        Icon(Icons.minimize_rounded,
                            color: Colors.redAccent, size: 18),
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
            Icon(Icons.arrow_forward_ios_rounded,
                color: Colors.white.withValues(alpha: 0.2), size: 13),
          ],
        ),
      ),
    );
  }
}
