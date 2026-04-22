import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/neuro_theme_provider.dart';
import '../models/neuro_profile.dart';

class ReadingRuler extends StatefulWidget {
  final Widget child;

  const ReadingRuler({super.key, required this.child});

  @override
  State<ReadingRuler> createState() => _ReadingRulerState();
}

class _ReadingRulerState extends State<ReadingRuler> {
  double _rulerOffsetY = 200.0;
  final double _rulerHeight = 80.0;
  bool _isActive = true; // Auto-activate for testing

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<NeuroThemeProvider>(context);
    final profile = themeProvider.activeProfile;

    // Only Dyslexia really benefits heavily from this by default, but make it available
    if (!_isActive) {
      return widget.child;
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxHeight = constraints.maxHeight;

        return Stack(
          children: [
            // Target content
            widget.child,

            // Top mask
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: _rulerOffsetY,
              child: IgnorePointer(
                child: Container(
                  color: profile.backgroundColor.withValues(alpha: 0.65),
                ),
              ),
            ),

            // Bottom mask
            Positioned(
              top: _rulerOffsetY + _rulerHeight,
              left: 0,
              right: 0,
              bottom: 0,
              child: IgnorePointer(
                child: Container(
                  color: profile.backgroundColor.withValues(alpha: 0.65),
                ),
              ),
            ),

            // Ruler edges (for contrast)
            Positioned(
              top: _rulerOffsetY,
              left: 0,
              right: 0,
              height: 2,
              child: IgnorePointer(
                child: Container(color: profile.accentColor.withValues(alpha: 0.5)),
              ),
            ),
            Positioned(
              top: _rulerOffsetY + _rulerHeight - 2,
              left: 0,
              right: 0,
              height: 2,
              child: IgnorePointer(
                child: Container(color: profile.accentColor.withValues(alpha: 0.5)),
              ),
            ),

            // Drag handler on the right
            Positioned(
              top: _rulerOffsetY + (_rulerHeight / 2) - 25,
              right: 8,
              child: GestureDetector(
                onPanUpdate: (details) {
                  setState(() {
                    _rulerOffsetY += details.delta.dy;
                    // Clamp to screen bounds
                    if (_rulerOffsetY < 0) _rulerOffsetY = 0;
                    if (_rulerOffsetY > maxHeight - _rulerHeight) {
                      _rulerOffsetY = maxHeight - _rulerHeight;
                    }
                  });
                },
                child: Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: profile.accentColor,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 10,
                      )
                    ],
                  ),
                  child: const Icon(Icons.drag_indicator_rounded, color: Colors.white),
                ),
              ),
            ),

            // Close ruler button
            Positioned(
              top: 16,
              right: 16,
              child: GestureDetector(
                onTap: () {
                  setState(() => _isActive = false);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: profile.cardColor,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: profile.accentColor.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    'Close Ruler',
                    style: TextStyle(
                      fontFamily: profile.fontFamily,
                      color: profile.textColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
