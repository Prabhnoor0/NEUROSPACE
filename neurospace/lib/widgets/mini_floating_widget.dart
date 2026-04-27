/// NeuroSpace — Mini Floating Widget
/// A persistent, draggable mini-window that hovers on top of all screens.
/// Shows the current lesson title, TTS play/pause, Summarize, Easy Read, and close.
/// Implemented as a global OverlayEntry managed by a singleton.
/// Enhanced with: Summarize and Easy Read actions via BubbleProvider.

import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:provider/provider.dart';
import '../providers/bubble_provider.dart';

class MiniFloatingWidget {
  static OverlayEntry? _overlayEntry;
  static final FlutterTts _tts = FlutterTts();
  static bool _isSpeaking = false;
  static String _currentTitle = '';
  static String _currentText = '';
  static Offset _position = const Offset(20, 120);
  static _MiniWidgetState? _widgetState;

  /// Show the mini floating widget with the given content
  static void show(
    BuildContext context, {
    required String title,
    required String text,
    required Color accentColor,
    required Color cardColor,
    required Color textColor,
    required String fontFamily,
  }) {
    // Remove existing if any
    hide();

    _currentTitle = title;
    _currentText = text;

    _overlayEntry = OverlayEntry(
      builder: (ctx) => _MiniWidgetOverlay(
        title: title,
        text: text,
        accentColor: accentColor,
        cardColor: cardColor,
        textColor: textColor,
        fontFamily: fontFamily,
        initialPosition: _position,
        onClose: () => hide(),
        onPositionChanged: (pos) => _position = pos,
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  /// Hide and remove the mini widget
  static void hide() {
    _tts.stop();
    _isSpeaking = false;
    _overlayEntry?.remove();
    _overlayEntry = null;
    _widgetState = null;
  }

  /// Check if currently showing
  static bool get isShowing => _overlayEntry != null;
}

class _MiniWidgetOverlay extends StatefulWidget {
  final String title;
  final String text;
  final Color accentColor;
  final Color cardColor;
  final Color textColor;
  final String fontFamily;
  final Offset initialPosition;
  final VoidCallback onClose;
  final ValueChanged<Offset> onPositionChanged;

  const _MiniWidgetOverlay({
    required this.title,
    required this.text,
    required this.accentColor,
    required this.cardColor,
    required this.textColor,
    required this.fontFamily,
    required this.initialPosition,
    required this.onClose,
    required this.onPositionChanged,
  });

  @override
  State<_MiniWidgetOverlay> createState() => _MiniWidgetState();
}

class _MiniWidgetState extends State<_MiniWidgetOverlay>
    with SingleTickerProviderStateMixin {
  late Offset _position;
  final FlutterTts _tts = FlutterTts();
  bool _isSpeaking = false;
  bool _isExpanded = false;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _position = widget.initialPosition;
    MiniFloatingWidget._widgetState = this;

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _tts.setCompletionHandler(() {
      if (mounted) setState(() => _isSpeaking = false);
      _pulseController.stop();
    });
    _tts.setErrorHandler((_) {
      if (mounted) setState(() => _isSpeaking = false);
      _pulseController.stop();
    });
  }

  @override
  void dispose() {
    _tts.stop();
    _pulseController.dispose();
    super.dispose();
  }

  void _toggleTTS() async {
    if (_isSpeaking) {
      await _tts.stop();
      _pulseController.stop();
      setState(() => _isSpeaking = false);
    } else {
      await _tts.setSpeechRate(0.45);
      await _tts.speak(widget.text);
      _pulseController.repeat(reverse: true);
      setState(() => _isSpeaking = true);
    }
  }

  void _handleSummarize() {
    try {
      final bubble = Provider.of<BubbleProvider>(context, listen: false);
      bubble.handleSummarize(text: widget.text);
      bubble.show();
    } catch (_) {
      // BubbleProvider not in tree — show snackbar instead
    }
  }

  void _handleEasyRead() {
    try {
      final bubble = Provider.of<BubbleProvider>(context, listen: false);
      bubble.handleEasyRead(text: widget.text);
      bubble.show();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: _position.dx,
      top: _position.dy,
      child: GestureDetector(
        onPanUpdate: (details) {
          setState(() {
            _position += details.delta;
          });
          widget.onPositionChanged(_position);
        },
        onTap: () => setState(() => _isExpanded = !_isExpanded),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          width: _isExpanded ? 270 : 60,
          height: _isExpanded ? 170 : 60,
          child: Material(
            color: Colors.transparent,
            child: Container(
              decoration: BoxDecoration(
                color: widget.cardColor,
                borderRadius: BorderRadius.circular(_isExpanded ? 20 : 30),
                border: Border.all(
                  color: widget.accentColor.withOpacity(0.3),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: widget.accentColor.withOpacity(0.2),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: _isExpanded ? _buildExpanded() : _buildCollapsed(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCollapsed() {
    return Center(
      child: AnimatedBuilder(
        animation: _pulseController,
        builder: (context, child) {
          final scale =
              _isSpeaking ? 1.0 + (_pulseController.value * 0.15) : 1.0;
          return Transform.scale(
            scale: scale,
            child: Icon(
              _isSpeaking
                  ? Icons.graphic_eq_rounded
                  : Icons.psychology_rounded,
              color: widget.accentColor,
              size: 28,
            ),
          );
        },
      ),
    );
  }

  Widget _buildExpanded() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title row with close button
          Row(
            children: [
              Icon(Icons.psychology_rounded,
                  color: widget.accentColor, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: widget.fontFamily,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: widget.textColor,
                  ),
                ),
              ),
              GestureDetector(
                onTap: widget.onClose,
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.close_rounded,
                      color: Colors.red.shade300, size: 14),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // Summary snippet
          Text(
            widget.text,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: widget.fontFamily,
              fontSize: 11,
              color: widget.textColor.withOpacity(0.6),
              height: 1.3,
            ),
          ),
          const Spacer(),
          // Controls row — TTS + Summarize + Easy Read
          Row(
            children: [
              // Play/Pause button
              _miniAction(
                icon: _isSpeaking
                    ? Icons.stop_rounded
                    : Icons.play_arrow_rounded,
                label: _isSpeaking ? 'Stop' : 'Read',
                color: widget.accentColor,
                onTap: _toggleTTS,
              ),
              const SizedBox(width: 6),
              // Summarize
              _miniAction(
                icon: Icons.auto_awesome_rounded,
                label: 'Sum',
                color: const Color(0xFF7C4DFF),
                onTap: _handleSummarize,
              ),
              const SizedBox(width: 6),
              // Easy Read
              _miniAction(
                icon: Icons.format_size_rounded,
                label: 'Easy',
                color: const Color(0xFF4CAF50),
                onTap: _handleEasyRead,
              ),
              const Spacer(),
              // Speaking indicator
              if (_isSpeaking)
                Row(
                  children: List.generate(3, (i) {
                    return AnimatedBuilder(
                      animation: _pulseController,
                      builder: (context, child) {
                        final delay = i * 0.2;
                        final value =
                            ((_pulseController.value + delay) % 1.0);
                        return Container(
                          margin: const EdgeInsets.symmetric(horizontal: 1),
                          width: 3,
                          height: 6 + (value * 10),
                          decoration: BoxDecoration(
                            color: widget.accentColor,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        );
                      },
                    );
                  }),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _miniAction({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 13),
            const SizedBox(width: 3),
            Text(
              label,
              style: TextStyle(
                fontFamily: widget.fontFamily,
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
