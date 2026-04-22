/// NeuroSpace — Universal Lesson Screen
/// Morphs its entire structural layout depending on the active NeuroProfile.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flip_card/flip_card.dart';
import '../providers/neuro_theme_provider.dart';
import '../models/neuro_profile.dart';
import '../models/lesson.dart';
import '../services/firebase_service.dart';

class LessonScreen extends StatefulWidget {
  final String topic;

  const LessonScreen({super.key, required this.topic});

  @override
  State<LessonScreen> createState() => _LessonScreenState();
}

class _LessonScreenState extends State<LessonScreen> {
  late DeepDiveLesson _lesson;
  final PageController _pageController = PageController();
  bool _isSaved = false;

  @override
  void initState() {
    super.initState();
    // Simulate loading a lesson specifically targeted at the active profile
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final type = Provider.of<NeuroThemeProvider>(context, listen: false)
          .activeProfile
          .profileType
          .name;
      setState(() {
        _lesson = MockLessonGenerator.getMockLesson(type);
      });
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  /// Save the current lesson to Firebase Library
  Future<void> _saveLesson(NeuroProfile profile) async {
    final userId = FirebaseService.currentUserId;
    if (userId == null) return;

    try {
      // Convert lesson modules to serializable maps
      final moduleMaps = _lesson.modules.map((m) => {
        'title': m.title,
        'description': m.description,
        'content': m.sections.map((s) => s.text).join('\n\n'),
        'sections': m.sections.map((s) => {
          'heading': s.heading,
          'text': s.text,
          'type': s.type,
        }).toList(),
      }).toList();

      await FirebaseService.saveLesson(
        userId: userId,
        lessonData: {
          'title': widget.topic,
          'topic': widget.topic,
          'summary': _lesson.modules.isNotEmpty
              ? _lesson.modules.first.description
              : '',
          'profileUsed': profile.profileType.name,
          'modules': moduleMaps,
        },
      );

      if (mounted) {
        setState(() => _isSaved = true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('✅ Lesson saved to your Library!'),
            backgroundColor: profile.accentColor,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<NeuroThemeProvider>(context);
    final profile = themeProvider.activeProfile;

    return Scaffold(
      backgroundColor: profile.backgroundColor,
      appBar: AppBar(
        title: Text(widget.topic),
        titleTextStyle: TextStyle(
          fontFamily: profile.fontFamily,
          fontSize: profile.fontSize,
          fontWeight: FontWeight.w700,
          color: profile.textColor,
        ),
        iconTheme: IconThemeData(color: profile.textColor),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          // Save to Library button
          IconButton(
            icon: Icon(
              _isSaved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
              color: _isSaved ? profile.accentColor : profile.textColor.withValues(alpha: 0.5),
            ),
            onPressed: _isSaved ? null : () => _saveLesson(profile),
          ),
          IconButton(
            icon: Icon(Icons.volume_up_rounded, color: profile.accentColor),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Playing audio...')),
              );
            },
          ),
        ],
      ),
      body: _lesson == null
          ? Center(
              child: CircularProgressIndicator(color: profile.accentColor),
            )
          : _buildAdaptiveLayout(profile),
    );
  }

  // ===========================================
  // LAYOUT ENGINE: Morphs based on Profile
  // ===========================================

  Widget _buildAdaptiveLayout(NeuroProfile profile) {
    // 1. ADHD Layout -> TikTok swipe cards + Flashcards
    if (profile.profileType == NeuroProfileType.adhd) {
      return PageView.builder(
        controller: _pageController,
        scrollDirection: Axis.vertical,
        physics: const BouncingScrollPhysics(),
        itemCount: _lesson.modules.length * 2, // module + flashcard
        itemBuilder: (context, index) {
          final moduleIndex = index ~/ 2;
          final isFlashcard = index % 2 != 0;

          if (isFlashcard) {
            final card = _lesson.modules[moduleIndex].flashcard;
            if (card == null) return const SizedBox.shrink();
            return _buildFlashcard(card, profile);
          } else {
            return _buildAdhdModuleCard(
                _lesson.modules[moduleIndex], profile, moduleIndex);
          }
        },
      );
    }
    // 2. Dyslexia Layout -> Continuous scroll, high spacing, warm distinct colors
    else if (profile.profileType == NeuroProfileType.dyslexia) {
      return ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        itemCount: _lesson.modules.length,
        itemBuilder: (context, index) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 32),
            child: _buildDyslexiaModuleCard(_lesson.modules[index], profile),
          );
        },
      );
    }
    // 3. Autism Layout -> Accordion, deeply structured, literal descriptions
    else {
      return ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        itemCount: _lesson.modules.length,
        itemBuilder: (context, index) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _buildAutismAccordion(_lesson.modules[index], profile),
          );
        },
      );
    }
  }

  // ===========================================
  // ADHD: Swipeable Gamified Cards
  // ===========================================

  Widget _buildAdhdModuleCard(
      LessonModule module, NeuroProfile profile, int index) {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: profile.cardColor,
          borderRadius: BorderRadius.circular(32),
          border: profile.focusBordersEnabled
              ? Border.all(color: profile.accentColor.withValues(alpha: 0.3), width: 2)
              : null,
          boxShadow: [
            BoxShadow(
              color: profile.accentColor.withValues(alpha: 0.15),
              blurRadius: 30,
              offset: const Offset(0, 10),
            )
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: profile.accentColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'MODULE ${index + 1}',
                style: TextStyle(
                  fontFamily: profile.fontFamily,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: profile.accentColor,
                  letterSpacing: 2,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              module.title,
              style: TextStyle(
                fontFamily: profile.fontFamily,
                fontSize: profile.fontSize + 8,
                fontWeight: FontWeight.w800,
                color: profile.textColor,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              module.description,
              style: TextStyle(
                fontFamily: profile.fontFamily,
                fontSize: profile.fontSize,
                color: profile.textColor.withValues(alpha: 0.6),
                height: profile.lineHeight,
              ),
            ),
            const SizedBox(height: 24),
            ...module.sections.map((s) => _buildTextSection(s, profile)),
            const SizedBox(height: 32),
            Center(
              child: Column(
                children: [
                  const Icon(Icons.swipe_up_rounded,
                      color: Colors.grey, size: 28),
                  const SizedBox(height: 4),
                  Text(
                    'Swipe up for Quiz',
                    style: TextStyle(
                      fontFamily: profile.fontFamily,
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  )
                ],
              ),
            ).animate(onPlay: (c) => c.repeat()).slideY(
                begin: 0, end: -0.5, duration: 1000.ms, curve: Curves.easeInOut),
          ],
        ),
      ),
    );
  }

  Widget _buildFlashcard(Flashcard flashcard, NeuroProfile profile) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: FlipCard(
          direction: FlipDirection.HORIZONTAL,
          front: _buildCardSide(
              'Question', flashcard.question, profile, Colors.orangeAccent),
          back: _buildCardSide('Answer', flashcard.answer, profile,
              const Color(0xFF4CAF50)),
        ),
      ),
    );
  }

  Widget _buildCardSide(
      String label, String text, NeuroProfile profile, Color accent) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: profile.cardColor,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: accent.withValues(alpha: 0.5), width: 3),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.2),
            blurRadius: 30,
            offset: const Offset(0, 10),
          )
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontFamily: profile.fontFamily,
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: accent,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: profile.fontFamily,
              fontSize: profile.fontSize + 4,
              fontWeight: FontWeight.w700,
              color: profile.textColor,
            ),
          ),
          const SizedBox(height: 32),
          Icon(Icons.touch_app_rounded,
              color: profile.textColor.withValues(alpha: 0.2), size: 32),
        ],
      ),
    );
  }

  // ===========================================
  // DYSLEXIA: High Spacing, Color Blocks
  // ===========================================

  Widget _buildDyslexiaModuleCard(LessonModule module, NeuroProfile profile) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          module.title,
          style: TextStyle(
            fontFamily: profile.fontFamily,
            fontSize: profile.fontSize + 6,
            fontWeight: FontWeight.w700,
            color: profile.textColor,
            height: profile.lineHeight,
            decoration: TextDecoration.underline,
            decorationColor: profile.accentColor,
            decorationThickness: 4,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          module.description,
          style: TextStyle(
            fontFamily: profile.fontFamily,
            fontSize: profile.fontSize,
            color: profile.textColor.withValues(alpha: 0.8),
            height: profile.lineHeight,
          ),
        ),
        const SizedBox(height: 24),
        ...module.sections.map((s) {
          final isDef = s.type == 'definition';
          return Container(
            margin: const EdgeInsets.only(bottom: 20),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDef ? profile.definitionColor : profile.exampleColor,
              borderRadius: BorderRadius.circular(20),
            ),
            child: _buildTextSection(s, profile),
          );
        }),
      ],
    );
  }

  // ===========================================
  // AUTISM: Structured Accordion
  // ===========================================

  Widget _buildAutismAccordion(LessonModule module, NeuroProfile profile) {
    return Container(
      decoration: BoxDecoration(
        color: profile.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: profile.focusBordersEnabled
            ? Border.all(color: profile.accentColor.withValues(alpha: 0.1))
            : null,
      ),
      child: ExpansionTile(
        title: Text(
          module.title,
          style: TextStyle(
            fontFamily: profile.fontFamily,
            fontSize: profile.fontSize,
            fontWeight: FontWeight.w600,
            color: profile.textColor,
          ),
        ),
        subtitle: Text(
          module.description,
          style: TextStyle(
            fontFamily: profile.fontFamily,
            fontSize: profile.fontSize - 2,
            color: profile.textColor.withValues(alpha: 0.5),
          ),
        ),
        iconColor: profile.accentColor,
        collapsedIconColor: profile.textColor.withValues(alpha: 0.4),
        childrenPadding: const EdgeInsets.all(20),
        children: module.sections
            .map((s) => Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: _buildTextSection(s, profile),
                ))
            .toList(),
      ),
    );
  }

  // ===========================================
  // SHARED: Section Renderer
  // ===========================================

  Widget _buildTextSection(ModuleSection section, NeuroProfile profile) {
    final isDyslexia = profile.profileType == NeuroProfileType.dyslexia;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              section.type == 'definition'
                  ? Icons.book_rounded
                  : section.type == 'example'
                      ? Icons.lightbulb_rounded
                      : Icons.info_outline_rounded,
              size: 18,
              color: isDyslexia
                  ? profile.textColor.withValues(alpha: 0.8)
                  : profile.accentColor,
            ),
            const SizedBox(width: 8),
            Text(
              section.heading.toUpperCase(),
              style: TextStyle(
                fontFamily: profile.fontFamily,
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: isDyslexia
                    ? profile.textColor.withValues(alpha: 0.8)
                    : profile.accentColor,
                letterSpacing: 1.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          section.text,
          style: TextStyle(
            fontFamily: profile.fontFamily,
            fontSize: profile.fontSize,
            color: profile.textColor,
            height: profile.lineHeight,
            letterSpacing: profile.letterSpacing,
          ),
        ),
      ],
    );
  }
}
