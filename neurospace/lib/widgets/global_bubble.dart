/// NeuroSpace — Global Accessibility Bubble
/// A persistent, draggable floating circle that stays on top of ALL in-app screens.
/// Tap to expand into a mini-app with: TTS, Summarize, Easy Read, Scan.
/// Injected at the MaterialApp level above the Navigator.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:speech_to_text/speech_to_text.dart';
import '../providers/bubble_provider.dart';
import '../providers/neuro_theme_provider.dart';
import '../screens/scan_result_screen.dart';
import '../services/api_service.dart';

class GlobalAccessibilityBubble extends StatefulWidget {
  const GlobalAccessibilityBubble({super.key});

  @override
  State<GlobalAccessibilityBubble> createState() =>
      _GlobalAccessibilityBubbleState();
}

class _GlobalAccessibilityBubbleState extends State<GlobalAccessibilityBubble>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _expandController;
  late Animation<double> _expandAnimation;
  final SpeechToText _speech = SpeechToText();
  bool _isListening = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _expandController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _expandAnimation = CurvedAnimation(
      parent: _expandController,
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _expandController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<BubbleProvider>(
      builder: (context, bubble, _) {
        if (!bubble.isVisible) return const SizedBox.shrink();

        // Sync expand animation with state
        if (bubble.state != BubbleState.collapsed) {
          _expandController.forward();
        } else {
          _expandController.reverse();
        }

        return Positioned(
          left: bubble.position.dx,
          top: bubble.position.dy,
          child: GestureDetector(
            onPanUpdate: (details) => bubble.updatePosition(details.delta),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              transitionBuilder: (child, animation) {
                return ScaleTransition(scale: animation, child: child);
              },
              child: switch (bubble.state) {
                BubbleState.collapsed => _buildCollapsedBubble(bubble),
                BubbleState.expanded => _buildExpandedMenu(bubble),
                BubbleState.result => _buildResultView(bubble),
              },
            ),
          ),
        );
      },
    );
  }

  // ─────────────────────────────────────────────
  //  COLLAPSED BUBBLE (small floating circle)
  // ─────────────────────────────────────────────

  Widget _buildCollapsedBubble(BubbleProvider bubble) {
    return GestureDetector(
      key: const ValueKey('collapsed'),
      onTap: () => bubble.expand(),
      child: AnimatedBuilder(
        animation: _pulseController,
        builder: (context, child) {
          final scale = 1.0 + (_pulseController.value * 0.06);
          final glowOpacity = 0.3 + (_pulseController.value * 0.15);
          return Transform.scale(
            scale: scale,
            child: Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF7C4DFF), Color(0xFF00BCD4)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF7C4DFF).withOpacity(glowOpacity),
                    blurRadius: 18,
                    spreadRadius: 2,
                  ),
                  BoxShadow(
                    color: const Color(0xFF00BCD4).withOpacity(0.15),
                    blurRadius: 12,
                    offset: const Offset(2, 4),
                  ),
                ],
                border: Border.all(
                  color: Colors.white.withOpacity(0.35),
                  width: 2,
                ),
              ),
              child: const Icon(
                Icons.psychology_rounded,
                color: Colors.white,
                size: 28,
              ),
            ),
          );
        },
      ),
    );
  }

  // ─────────────────────────────────────────────
  //  EXPANDED MENU (4 action buttons)
  // ─────────────────────────────────────────────

  Widget _buildExpandedMenu(BubbleProvider bubble) {
    final profile =
        Provider.of<NeuroThemeProvider>(context, listen: false).activeProfile;

    return Material(
      key: const ValueKey('expanded'),
      color: Colors.transparent,
      child: Container(
        width: 280,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1E2E).withOpacity(0.97),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: const Color(0xFF7C4DFF).withOpacity(0.3),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.5),
              blurRadius: 30,
              spreadRadius: 5,
            ),
            BoxShadow(
              color: const Color(0xFF7C4DFF).withOpacity(0.08),
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
                  width: 28,
                  height: 28,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [Color(0xFF7C4DFF), Color(0xFF00BCD4)],
                    ),
                  ),
                  child: const Icon(Icons.psychology_rounded,
                      color: Colors.white, size: 15),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'NeuroSpace',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () => bubble.collapse(),
                  child: Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.close_rounded,
                        color: Colors.white54, size: 15),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Screen text, clipboard, OCR, or voice',
              style: TextStyle(
                fontSize: 11,
                color: Colors.white.withOpacity(0.4),
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 14),

            // ── ACTION 1: Read Aloud ──
            _BubbleActionButton(
              icon: Icons.volume_up_rounded,
              label: 'Read Aloud',
              subtitle: 'Read visible text or clipboard',
              gradient: const [Color(0xFF00BCD4), Color(0xFF0097A7)],
              onTap: () => bubble.handleTTS(
                speechRate: profile.ttsSpeed * 0.5,
              ),
            ),
            const SizedBox(height: 8),

            // ── ACTION 2: Simplify ──
            _BubbleActionButton(
              icon: Icons.text_fields_rounded,
              label: 'Simplify',
              subtitle: 'Convert into easier language',
              gradient: const [Color(0xFF5E35B1), Color(0xFF4527A0)],
              onTap: () => bubble.handleSimplify(
                profile: profile.profileType.name,
              ),
            ),
            const SizedBox(height: 8),

            // ── ACTION 3: Summarize ──
            _BubbleActionButton(
              icon: Icons.auto_awesome_rounded,
              label: 'Summarize',
              subtitle: 'Get a simple summary',
              gradient: const [Color(0xFF7C4DFF), Color(0xFF651FFF)],
              onTap: () => bubble.handleSummarize(
                profile: profile.profileType.name,
              ),
            ),
            const SizedBox(height: 8),

            // ── ACTION 4: Easy Read ──
            _BubbleActionButton(
              icon: Icons.format_size_rounded,
              label: 'Easy Read',
              subtitle: 'Format for your brain',
              gradient: const [Color(0xFF4CAF50), Color(0xFF388E3C)],
              onTap: () => bubble.handleEasyRead(),
            ),
            const SizedBox(height: 8),

            // ── ACTION 5: Voice Command ──
            _BubbleActionButton(
              icon: _isListening ? Icons.mic_off_rounded : Icons.mic_rounded,
              label: _isListening ? 'Listening...' : 'Voice Command',
              subtitle: 'Say: read this / simplify this / summarize this',
              gradient: const [Color(0xFF26A69A), Color(0xFF00796B)],
              onTap: () => _handleVoiceCommandFromBubble(bubble),
            ),
            const SizedBox(height: 8),

            // ── ACTION 6: Scan Text ──
            _BubbleActionButton(
              icon: Icons.camera_alt_rounded,
              label: 'Scan Text',
              subtitle: 'Camera → OCR → actions',
              gradient: const [Color(0xFFFF7043), Color(0xFFE64A19)],
              onTap: () => _handleScanFromBubble(bubble),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  //  RESULT VIEW (output from actions)
  // ─────────────────────────────────────────────

  Widget _buildResultView(BubbleProvider bubble) {
    final profile =
        Provider.of<NeuroThemeProvider>(context, listen: false).activeProfile;
    final isTTS = bubble.currentAction == BubbleAction.tts;
    final isEasyRead = bubble.currentAction == BubbleAction.easyRead;
    final hasError = bubble.errorText.isNotEmpty;

    final title = switch (bubble.currentAction) {
      BubbleAction.tts => '🔊 Read Aloud',
      BubbleAction.simplify => '✨ Simplify',
      BubbleAction.summarize => '📝 Summary',
      BubbleAction.easyRead => '🔤 Easy Read',
      BubbleAction.scan => '📸 Scan Result',
      BubbleAction.voice => '🎤 Voice Command',
      _ => 'Result',
    };

    final accentColor = switch (bubble.currentAction) {
      BubbleAction.tts => const Color(0xFF00BCD4),
      BubbleAction.simplify => const Color(0xFF5E35B1),
      BubbleAction.summarize => const Color(0xFF7C4DFF),
      BubbleAction.easyRead => const Color(0xFF4CAF50),
      BubbleAction.scan => const Color(0xFFFF7043),
      BubbleAction.voice => const Color(0xFF26A69A),
      _ => const Color(0xFF7C4DFF),
    };

    // Choose font based on action
    final displayFont = isEasyRead ? 'OpenDyslexic' : profile.fontFamily;
    final displaySize = isEasyRead ? 18.0 : profile.fontSize;
    final displayHeight = isEasyRead ? 2.0 : profile.lineHeight;
    final displayLetterSpacing = isEasyRead ? 1.2 : profile.letterSpacing;

    return Material(
      key: const ValueKey('result'),
      color: Colors.transparent,
      child: Container(
        width: 300,
        constraints: const BoxConstraints(maxHeight: 420),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isEasyRead
              ? const Color(0xFFFFF9E6) // warm off-white for easy read
              : const Color(0xFF1A1E2E).withOpacity(0.97),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: accentColor.withOpacity(0.3),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.45),
              blurRadius: 30,
              spreadRadius: 5,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: accentColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    isTTS
                        ? Icons.volume_up_rounded
                        : bubble.currentAction == BubbleAction.summarize
                            ? Icons.auto_awesome_rounded
                          : bubble.currentAction == BubbleAction.simplify
                            ? Icons.text_fields_rounded
                            : bubble.currentAction == BubbleAction.voice
                              ? Icons.mic_rounded
                            : isEasyRead
                                ? Icons.format_size_rounded
                                : Icons.camera_alt_rounded,
                    color: accentColor,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: isEasyRead
                          ? const Color(0xFF1A1A1A)
                          : Colors.white,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () => bubble.collapse(),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: (isEasyRead ? Colors.black : Colors.white)
                          .withOpacity(0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.close_rounded,
                        color: isEasyRead
                            ? Colors.black45
                            : Colors.white60,
                        size: 18),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // TTS playback controls
            if (isTTS && !bubble.isProcessing && bubble.resultText.isNotEmpty)
              _buildTTSControls(bubble, accentColor),

            // Loading state
            if (bubble.isProcessing)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 36,
                        height: 36,
                        child: CircularProgressIndicator(
                          color: accentColor,
                          strokeWidth: 3,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        bubble.currentAction == BubbleAction.summarize ||
                                bubble.currentAction == BubbleAction.simplify
                            ? 'Processing text...'
                            : 'Processing...',
                        style: TextStyle(
                          fontSize: 13,
                          color: isEasyRead
                              ? Colors.black45
                              : Colors.white.withOpacity(0.5),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // Error state
            if (hasError && !bubble.isProcessing)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  bubble.errorText,
                  style: TextStyle(
                    fontSize: 14,
                    color: isEasyRead
                        ? Colors.black87
                        : Colors.white.withOpacity(0.7),
                    height: 1.6,
                  ),
                ),
              ),

            // Result text
            if (!hasError && !bubble.isProcessing && bubble.resultText.isNotEmpty)
              Flexible(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isEasyRead
                          ? Colors.white
                          : const Color(0xFF242938),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: accentColor.withOpacity(0.1),
                      ),
                    ),
                    child: SelectableText(
                      bubble.resultText,
                      style: TextStyle(
                        fontFamily: displayFont,
                        fontSize: displaySize,
                        height: displayHeight,
                        letterSpacing: displayLetterSpacing,
                        color: isEasyRead
                            ? const Color(0xFF1A1A1A)
                            : Colors.white.withOpacity(0.85),
                      ),
                    ),
                  ),
                ),
              ),

            const SizedBox(height: 12),

            // Bottom actions
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => bubble.expand(),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: (isEasyRead ? Colors.black : Colors.white)
                            .withOpacity(0.06),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.arrow_back_rounded,
                              color: isEasyRead
                                  ? Colors.black45
                                  : Colors.white54,
                              size: 16),
                          const SizedBox(width: 4),
                          Text(
                            'Back',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: isEasyRead
                                  ? Colors.black54
                                  : Colors.white54,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: GestureDetector(
                    onTap: () => bubble.collapse(),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.minimize_rounded,
                              color: Colors.redAccent, size: 16),
                          SizedBox(width: 4),
                          Text(
                            'Minimize',
                            style: TextStyle(
                              fontSize: 13,
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
      ),
    );
  }

  Future<void> _handleVoiceCommandFromBubble(BubbleProvider bubble) async {
    if (_isListening) {
      await _speech.stop();
      if (mounted) {
        setState(() => _isListening = false);
      }
      return;
    }

    final available = await _speech.initialize(
      onError: (_) {
        if (mounted) setState(() => _isListening = false);
      },
      onStatus: (status) {
        if (status == 'done' && mounted) {
          setState(() => _isListening = false);
        }
      },
    );

    if (!available) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Microphone access unavailable for voice command.')),
      );
      return;
    }

    if (mounted) setState(() => _isListening = true);

    await _speech.listen(
      listenMode: ListenMode.confirmation,
      partialResults: false,
      onResult: (result) async {
        if (!result.finalResult) return;
        final recognized = result.recognizedWords.trim();
        if (recognized.isEmpty) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('No command heard. Try again.')),
            );
          }
          return;
        }
        await bubble.handleVoiceCommand(recognized);
      },
    );
  }

  // ─────────────────────────────────────────────
  //  TTS PLAYBACK CONTROLS
  // ─────────────────────────────────────────────

  Widget _buildTTSControls(BubbleProvider bubble, Color accentColor) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF242938),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accentColor.withOpacity(0.15)),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => bubble.toggleTTS(),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [accentColor, accentColor.withOpacity(0.7)],
                ),
              ),
              child: Icon(
                bubble.isSpeaking
                    ? Icons.pause_rounded
                    : Icons.play_arrow_rounded,
                color: Colors.white,
                size: 22,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  bubble.isSpeaking ? 'Reading...' : 'Paused',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                Text(
                  '${bubble.resultText.split(' ').take(6).join(' ')}...',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.white.withOpacity(0.4),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (bubble.isSpeaking)
            GestureDetector(
              onTap: () => bubble.stopTTS(),
              child: Icon(Icons.stop_rounded,
                  color: Colors.white.withOpacity(0.5), size: 24),
            ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  //  SCAN FROM BUBBLE
  // ─────────────────────────────────────────────

  Future<void> _handleScanFromBubble(BubbleProvider bubble) async {
    bubble.collapse();

    final picker = ImagePicker();
    final XFile? pickedFile = await picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 2048,
      maxHeight: 2048,
      imageQuality: 85,
    );

    if (pickedFile == null) return;
    if (!mounted) return;

    final profile =
        Provider.of<NeuroThemeProvider>(context, listen: false).activeProfile;
    final profileStr = profile.profileType.name.toUpperCase();

    final result = await ApiService.scanImage(
      pickedFile.path,
      profile: profileStr,
    );

    if (result != null && mounted) {
      List<Map<String, dynamic>> keyTerms = [];
      if (result['key_terms'] != null && result['key_terms'] is List) {
        keyTerms = (result['key_terms'] as List)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
      }

      bubble.collapse();

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ScanResultScreen(
            extractedText: result['extracted_text'] ?? '',
            summary: result['summary'] ?? '',
            simplified: result['simplified'] ?? '',
            keyTerms: keyTerms,
          ),
        ),
      );
    } else {
      bubble.collapse();
    }
  }
}

// ═══════════════════════════════════════════════════
//  BUBBLE ACTION BUTTON WIDGET
// ═══════════════════════════════════════════════════

class _BubbleActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final List<Color> gradient;
  final VoidCallback onTap;

  const _BubbleActionButton({
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
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: const Color(0xFF242938),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: gradient[0].withOpacity(0.2),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                gradient: LinearGradient(
                  colors: gradient,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: gradient[0].withOpacity(0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(icon, color: Colors.white, size: 18),
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
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 10.5,
                      color: Colors.white.withOpacity(0.4),
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded,
                color: Colors.white.withOpacity(0.2), size: 12),
          ],
        ),
      ),
    );
  }
}
