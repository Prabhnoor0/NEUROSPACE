/// NeuroSpace — Scan Result Screen
/// Displays the OCR-extracted text, AI summary, simplified version,
/// and key terms from a scanned image.
/// Enhanced with: TTS, Summarize, Easy Read action bar + Copy/Share.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../providers/neuro_theme_provider.dart';
import '../providers/bubble_provider.dart';
import '../models/neuro_profile.dart';

class ScanResultScreen extends StatefulWidget {
  final String extractedText;
  final String summary;
  final String simplified;
  final List<Map<String, dynamic>> keyTerms;

  const ScanResultScreen({
    super.key,
    required this.extractedText,
    required this.summary,
    required this.simplified,
    this.keyTerms = const [],
  });

  @override
  State<ScanResultScreen> createState() => _ScanResultScreenState();
}

class _ScanResultScreenState extends State<ScanResultScreen> {
  final FlutterTts _tts = FlutterTts();
  bool _isSpeaking = false;
  bool _easyReadMode = false;

  @override
  void initState() {
    super.initState();
    _tts.setCompletionHandler(() {
      if (mounted) setState(() => _isSpeaking = false);
    });
    _tts.setErrorHandler((_) {
      if (mounted) setState(() => _isSpeaking = false);
    });
  }

  @override
  void dispose() {
    _tts.stop();
    super.dispose();
  }

  /// Play TTS for the best available text
  Future<void> _playTTS(NeuroProfile profile) async {
    final text = widget.simplified.isNotEmpty
        ? widget.simplified
        : widget.summary.isNotEmpty
            ? widget.summary
            : widget.extractedText;

    if (text.isEmpty) return;

    if (_isSpeaking) {
      await _tts.stop();
      setState(() => _isSpeaking = false);
      return;
    }

    setState(() => _isSpeaking = true);
    await _tts.setSpeechRate(profile.ttsSpeed * 0.45);
    await _tts.speak(text);
  }

  /// Send text to bubble for AI summarization
  void _handleSummarize(NeuroProfile profile) {
    final bubble = Provider.of<BubbleProvider>(context, listen: false);
    final text = widget.extractedText.isNotEmpty
        ? widget.extractedText
        : widget.simplified;
    bubble.handleSummarize(
      text: text,
      profile: profile.profileType.name,
    );
    bubble.show();
  }

  /// Copy simplified text to clipboard
  void _copyText(NeuroProfile profile) {
    final text = widget.simplified.isNotEmpty
        ? widget.simplified
        : widget.extractedText;
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('📋 Copied to clipboard!'),
        backgroundColor: profile.accentColor,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profile = Provider.of<NeuroThemeProvider>(context).activeProfile;
    final accentColor = profile.accentColor;

    // Easy Read overrides
    final displayFont = _easyReadMode ? 'OpenDyslexic' : profile.fontFamily;
    final displaySize = _easyReadMode ? 18.0 : profile.fontSize;
    final displayHeight = _easyReadMode ? 2.2 : profile.lineHeight;
    final displaySpacing = _easyReadMode ? 1.5 : profile.letterSpacing;
    final displayBg =
        _easyReadMode ? const Color(0xFFFFF9E6) : profile.backgroundColor;
    final displayTextColor =
        _easyReadMode ? const Color(0xFF1A1A1A) : profile.textColor;

    return Scaffold(
      backgroundColor: displayBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: displayTextColor),
        title: Text(
          '📸 Scan Result',
          style: TextStyle(
            fontFamily: displayFont,
            color: displayTextColor,
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          // Easy Read toggle
          IconButton(
            icon: Icon(
              _easyReadMode
                  ? Icons.format_size_rounded
                  : Icons.text_fields_rounded,
              color: _easyReadMode ? accentColor : displayTextColor.withOpacity(0.5),
            ),
            tooltip: _easyReadMode ? 'Normal View' : 'Easy Read',
            onPressed: () => setState(() => _easyReadMode = !_easyReadMode),
          ),
          // Copy
          IconButton(
            icon: Icon(Icons.copy_rounded,
                color: displayTextColor.withOpacity(0.5)),
            tooltip: 'Copy text',
            onPressed: () => _copyText(profile),
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Content Area ──
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Summary Card ──
                  _buildSection(
                    profile,
                    icon: Icons.auto_awesome_rounded,
                    title: 'Summary',
                    color: accentColor,
                    displayFont: displayFont,
                    displayTextColor: displayTextColor,
                    child: Text(
                      widget.summary.isNotEmpty
                          ? widget.summary
                          : 'No summary available.',
                      style: TextStyle(
                        fontFamily: displayFont,
                        fontSize: displaySize + 1,
                        color: displayTextColor,
                        height: displayHeight,
                        letterSpacing: displaySpacing,
                      ),
                    ),
                  ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1),

                  const SizedBox(height: 16),

                  // ── Simplified Version ──
                  _buildSection(
                    profile,
                    icon: Icons.lightbulb_rounded,
                    title: 'Simplified',
                    color: const Color(0xFF4CAF50),
                    displayFont: displayFont,
                    displayTextColor: displayTextColor,
                    child: Text(
                      widget.simplified.isNotEmpty
                          ? widget.simplified
                          : widget.extractedText,
                      style: TextStyle(
                        fontFamily: displayFont,
                        fontSize: displaySize,
                        color: displayTextColor,
                        height: displayHeight,
                        letterSpacing: displaySpacing,
                      ),
                    ),
                  )
                      .animate()
                      .fadeIn(delay: 150.ms, duration: 400.ms)
                      .slideY(begin: 0.1),

                  if (widget.keyTerms.isNotEmpty) ...[
                    const SizedBox(height: 16),

                    // ── Key Terms ──
                    _buildSection(
                      profile,
                      icon: Icons.menu_book_rounded,
                      title: 'Key Terms',
                      color: const Color(0xFFFFA726),
                      displayFont: displayFont,
                      displayTextColor: displayTextColor,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: widget.keyTerms.map((term) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  margin: const EdgeInsets.only(top: 6),
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFFA726),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: RichText(
                                    text: TextSpan(
                                      children: [
                                        TextSpan(
                                          text: '${term['term'] ?? ''}: ',
                                          style: TextStyle(
                                            fontFamily: displayFont,
                                            fontSize: displaySize,
                                            fontWeight: FontWeight.w700,
                                            color: displayTextColor,
                                            height: displayHeight,
                                          ),
                                        ),
                                        TextSpan(
                                          text: term['definition'] ?? '',
                                          style: TextStyle(
                                            fontFamily: displayFont,
                                            fontSize: displaySize,
                                            color: displayTextColor
                                                .withOpacity(0.75),
                                            height: displayHeight,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    )
                        .animate()
                        .fadeIn(delay: 300.ms, duration: 400.ms)
                        .slideY(begin: 0.1),
                  ],

                  const SizedBox(height: 16),

                  // ── Raw Extracted Text (collapsible) ──
                  ExpansionTile(
                    tilePadding: const EdgeInsets.symmetric(horizontal: 16),
                    childrenPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    collapsedIconColor: displayTextColor.withOpacity(0.5),
                    iconColor: accentColor,
                    title: Row(
                      children: [
                        Icon(Icons.text_snippet_rounded,
                            color: displayTextColor.withOpacity(0.5),
                            size: 20),
                        const SizedBox(width: 10),
                        Text(
                          'Original Extracted Text',
                          style: TextStyle(
                            fontFamily: displayFont,
                            fontSize: displaySize - 1,
                            fontWeight: FontWeight.w600,
                            color: displayTextColor.withOpacity(0.6),
                          ),
                        ),
                      ],
                    ),
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: _easyReadMode
                              ? Colors.white
                              : profile.cardColor.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: SelectableText(
                          widget.extractedText,
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: displaySize - 2,
                            color: displayTextColor.withOpacity(0.7),
                            height: 1.6,
                          ),
                        ),
                      ),
                    ],
                  ).animate().fadeIn(delay: 450.ms, duration: 400.ms),

                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),

          // ── BOTTOM ACTION BAR ──
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            decoration: BoxDecoration(
              color: _easyReadMode
                  ? Colors.white
                  : profile.cardColor,
              border: Border(
                top: BorderSide(
                  color: accentColor.withOpacity(0.1),
                  width: 1,
                ),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  // 🔊 Read Aloud
                  Expanded(
                    child: _buildBottomAction(
                      icon: _isSpeaking
                          ? Icons.stop_rounded
                          : Icons.volume_up_rounded,
                      label: _isSpeaking ? 'Stop' : 'Read',
                      color: const Color(0xFF00BCD4),
                      textColor: displayTextColor,
                      onTap: () => _playTTS(profile),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // 📝 Summarize
                  Expanded(
                    child: _buildBottomAction(
                      icon: Icons.auto_awesome_rounded,
                      label: 'Summarize',
                      color: const Color(0xFF7C4DFF),
                      textColor: displayTextColor,
                      onTap: () => _handleSummarize(profile),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // 🔤 Easy Read
                  Expanded(
                    child: _buildBottomAction(
                      icon: Icons.format_size_rounded,
                      label: _easyReadMode ? 'Normal' : 'Easy Read',
                      color: const Color(0xFF4CAF50),
                      textColor: displayTextColor,
                      isActive: _easyReadMode,
                      onTap: () =>
                          setState(() => _easyReadMode = !_easyReadMode),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomAction({
    required IconData icon,
    required String label,
    required Color color,
    required Color textColor,
    required VoidCallback onTap,
    bool isActive = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isActive
              ? color.withOpacity(0.15)
              : color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(14),
          border: isActive
              ? Border.all(color: color.withOpacity(0.3))
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(
    NeuroProfile profile, {
    required IconData icon,
    required String title,
    required Color color,
    required Widget child,
    required String displayFont,
    required Color displayTextColor,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _easyReadMode ? Colors.white : profile.cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.2), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: TextStyle(
                  fontFamily: displayFont,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: displayTextColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}
