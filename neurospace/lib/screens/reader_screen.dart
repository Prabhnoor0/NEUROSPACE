/// NeuroSpace — Reader Screen
/// Displays shared or simplified text with full accessibility toolbar.
/// Features: TTS play/pause, Summarize via API, Easy Read mode, Copy All.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../providers/neuro_theme_provider.dart';
import '../providers/bubble_provider.dart';
import '../models/neuro_profile.dart';
import '../widgets/neuro_text.dart';
import '../widgets/reading_ruler.dart';

class ReaderScreen extends StatefulWidget {
  final String title;
  final String content;

  const ReaderScreen({
    super.key,
    required this.title,
    required this.content,
  });

  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen> {
  final FlutterTts _tts = FlutterTts();
  final ScrollController _scrollController = ScrollController();

  bool _isSpeaking = false;
  bool _easyReadMode = false;
  double _readingProgress = 0.0;

  @override
  void initState() {
    super.initState();
    _tts.setCompletionHandler(() {
      if (mounted) setState(() => _isSpeaking = false);
    });
    _tts.setErrorHandler((_) {
      if (mounted) setState(() => _isSpeaking = false);
    });

    _scrollController.addListener(_updateReadingProgress);
  }

  @override
  void dispose() {
    _tts.stop();
    _scrollController.dispose();
    super.dispose();
  }

  void _updateReadingProgress() {
    if (!_scrollController.hasClients) return;
    final maxScroll = _scrollController.position.maxScrollExtent;
    if (maxScroll <= 0) return;
    setState(() {
      _readingProgress = _scrollController.offset / maxScroll;
    });
  }

  Future<void> _toggleTTS(NeuroProfile profile) async {
    if (_isSpeaking) {
      await _tts.stop();
      setState(() => _isSpeaking = false);
      return;
    }

    setState(() => _isSpeaking = true);
    await _tts.setSpeechRate(profile.ttsSpeed * 0.45);

    if (profile.profileType == NeuroProfileType.dyslexia) {
      await _tts.setPitch(0.9);
    } else if (profile.profileType == NeuroProfileType.adhd) {
      await _tts.setPitch(1.3);
    } else {
      await _tts.setPitch(1.0);
    }

    await _tts.speak(widget.content);
  }

  void _handleSummarize(NeuroProfile profile) {
    final bubble = Provider.of<BubbleProvider>(context, listen: false);
    bubble.handleSummarize(
      text: widget.content,
      profile: profile.profileType.name,
    );
    bubble.show();
  }

  void _copyAll(NeuroProfile profile) {
    Clipboard.setData(ClipboardData(text: widget.content));
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
          widget.title,
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
              color: _easyReadMode
                  ? profile.accentColor
                  : displayTextColor.withOpacity(0.5),
            ),
            tooltip: _easyReadMode ? 'Normal View' : 'Easy Read',
            onPressed: () => setState(() => _easyReadMode = !_easyReadMode),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(3),
          child: LinearProgressIndicator(
            value: _readingProgress,
            backgroundColor: Colors.transparent,
            valueColor: AlwaysStoppedAnimation<Color>(
              profile.accentColor.withOpacity(0.5),
            ),
            minHeight: 3,
          ),
        ),
      ),
      body: Column(
        children: [
          // ── Content ──
          Expanded(
            child: ReadingRuler(
              child: SingleChildScrollView(
                controller: _scrollController,
                physics: const BouncingScrollPhysics(),
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: TextStyle(
                        fontFamily: displayFont,
                        fontSize: displaySize + 12,
                        fontWeight: FontWeight.w900,
                        color: displayTextColor,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 24),
                    _easyReadMode
                        ? _buildEasyReadContent(
                            displayFont,
                            displaySize,
                            displayHeight,
                            displaySpacing,
                            displayTextColor,
                          )
                        : NeuroText(
                            text: widget.content,
                            style: TextStyle(
                              fontFamily: displayFont,
                              fontSize: displaySize,
                              color: displayTextColor,
                              height: displayHeight,
                              letterSpacing: displaySpacing,
                            ),
                          ),
                    const SizedBox(height: 100), // padding for ruler spacing
                  ],
                ),
              ),
            ),
          ),

          // ── BOTTOM ACTION BAR ──
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            decoration: BoxDecoration(
              color: _easyReadMode ? Colors.white : profile.cardColor,
              border: Border(
                top: BorderSide(
                  color: profile.accentColor.withOpacity(0.1),
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
                      onTap: () => _toggleTTS(profile),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // 📝 Summarize
                  Expanded(
                    child: _buildBottomAction(
                      icon: Icons.auto_awesome_rounded,
                      label: 'Summarize',
                      color: const Color(0xFF7C4DFF),
                      onTap: () => _handleSummarize(profile),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // 🔤 Easy Read
                  Expanded(
                    child: _buildBottomAction(
                      icon: Icons.format_size_rounded,
                      label: _easyReadMode ? 'Normal' : 'Easy',
                      color: const Color(0xFF4CAF50),
                      isActive: _easyReadMode,
                      onTap: () =>
                          setState(() => _easyReadMode = !_easyReadMode),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // 📋 Copy
                  Expanded(
                    child: _buildBottomAction(
                      icon: Icons.copy_rounded,
                      label: 'Copy',
                      color: const Color(0xFFFFA726),
                      onTap: () => _copyAll(profile),
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

  /// Easy Read mode: break content into bullet-point sentences
  Widget _buildEasyReadContent(
    String font,
    double size,
    double height,
    double spacing,
    Color textColor,
  ) {
    final sentences = widget.content
        .replaceAll(RegExp(r'\s+'), ' ')
        .split(RegExp(r'(?<=[.!?])\s+'))
        .where((s) => s.trim().isNotEmpty)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: sentences.map((sentence) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 8),
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: const Color(0xFF4CAF50),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  sentence.trim(),
                  style: TextStyle(
                    fontFamily: font,
                    fontSize: size,
                    color: textColor,
                    height: height,
                    letterSpacing: spacing,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildBottomAction({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
    bool isActive = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color:
              isActive ? color.withOpacity(0.15) : color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(14),
          border:
              isActive ? Border.all(color: color.withOpacity(0.3)) : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
