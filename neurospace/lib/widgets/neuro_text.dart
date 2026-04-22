import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:provider/provider.dart';
import '../providers/neuro_theme_provider.dart';

class NeuroText extends StatefulWidget {
  final String text;
  final TextStyle style;

  const NeuroText({
    super.key,
    required this.text,
    required this.style,
  });

  @override
  State<NeuroText> createState() => _NeuroTextState();
}

class _NeuroTextState extends State<NeuroText> {
  String? _tappedWord;

  List<TextSpan> _buildSpans(BuildContext context) {
    final profile = Provider.of<NeuroThemeProvider>(context).activeProfile;
    final words = widget.text.split(RegExp(r'(\s+)'));
    
    return words.map((word) {
      final isTapped = word == _tappedWord;
      
      // Preserve whitespace words without gesture recognizers
      if (word.trim().isEmpty) {
        return TextSpan(text: word, style: widget.style);
      }

      return TextSpan(
        text: word,
        style: widget.style.copyWith(
          backgroundColor: isTapped ? profile.accentColor.withValues(alpha: 0.3) : Colors.transparent,
          decoration: isTapped ? TextDecoration.underline : TextDecoration.none,
          decorationColor: profile.accentColor,
          decorationStyle: TextDecorationStyle.dotted,
        ),
        recognizer: TapGestureRecognizer()
          ..onTap = () {
            setState(() {
              _tappedWord = word;
            });
            _showDefinitionBottomSheet(context, word.replaceAll(RegExp(r'[^\w\s]'), ''));
            
            // Reset tap state after sheet closes
            Future.delayed(const Duration(milliseconds: 300), () {
              if (mounted) setState(() => _tappedWord = null);
            });
          },
      );
    }).toList();
  }

  void _showDefinitionBottomSheet(BuildContext context, String word) {
    final profile = Provider.of<NeuroThemeProvider>(context, listen: false).activeProfile;
    
    // Mock definition logic for now. Later this will hit the text_simplifier.py service.
    String definition = "A simple explanation of $word.";
    if (word.toLowerCase() == "photosynthesis") {
      definition = "How plants eat sunlight to grow!";
    } else if (word.toLowerCase() == "ephemeral") {
      definition = "Something that lasts for a very short time.";
    } else if (word.toLowerCase() == "neurodivergent") {
      definition = "Having a brain that functions in ways that are different from the norm.";
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: profile.cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: profile.textColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Icon(Icons.lightbulb_circle_rounded, color: profile.accentColor, size: 28),
                  const SizedBox(width: 12),
                  Text(
                    word,
                    style: TextStyle(
                      fontFamily: profile.fontFamily,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: profile.textColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                definition,
                style: TextStyle(
                  fontFamily: profile.fontFamily,
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  color: profile.textColor.withValues(alpha: 0.9),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        children: _buildSpans(context),
      ),
    );
  }
}
