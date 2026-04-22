import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/neuro_theme_provider.dart';
import '../widgets/neuro_text.dart';
import '../widgets/reading_ruler.dart';

class ReaderScreen extends StatelessWidget {
  final String title;
  final String content;

  const ReaderScreen({
    super.key,
    required this.title,
    required this.content,
  });

  @override
  Widget build(BuildContext context) {
    final profile = Provider.of<NeuroThemeProvider>(context).activeProfile;

    return Scaffold(
      backgroundColor: profile.backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: profile.textColor),
        title: Text(
          title,
          style: TextStyle(
            fontFamily: profile.fontFamily,
            color: profile.textColor,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: ReadingRuler(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontFamily: profile.fontFamily,
                  fontSize: profile.fontSize + 12,
                  fontWeight: FontWeight.w900,
                  color: profile.textColor,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 24),
              NeuroText(
                text: content,
                style: TextStyle(
                  fontFamily: profile.fontFamily,
                  fontSize: profile.fontSize,
                  color: profile.textColor,
                  height: profile.lineHeight,
                  letterSpacing: profile.letterSpacing,
                ),
              ),
              const SizedBox(height: 100), // padding for ruler spacing
            ],
          ),
        ),
      ),
    );
  }
}
