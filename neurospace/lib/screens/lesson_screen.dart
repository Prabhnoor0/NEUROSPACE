/// NeuroSpace — Universal Lesson Screen
/// Morphs its entire structural layout depending on the active NeuroProfile.

import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flip_card/flip_card.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../providers/neuro_theme_provider.dart';
import '../models/neuro_profile.dart';
import '../models/lesson.dart';
import '../services/firebase_service.dart';
import '../services/api_service.dart';

class LessonScreen extends StatefulWidget {
  final String topic;

  const LessonScreen({super.key, required this.topic});

  @override
  State<LessonScreen> createState() => _LessonScreenState();
}

class _LessonScreenState extends State<LessonScreen> {
  DeepDiveLesson? _lesson;
  final PageController _pageController = PageController();
  bool _isSaved = false;
  bool _isLoading = true;
  String? _errorMessage;
  bool _isPlayingTts = false;
  final FlutterTts _flutterTts = FlutterTts();

  @override
  void initState() {
    super.initState();
    _initTts();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _generateLesson();
    });
  }

  void _initTts() {
    _flutterTts.setStartHandler(() {
      if (mounted) setState(() => _isPlayingTts = true);
    });
    _flutterTts.setCompletionHandler(() {
      if (mounted) setState(() => _isPlayingTts = false);
    });
    _flutterTts.setErrorHandler((msg) {
      if (mounted) setState(() => _isPlayingTts = false);
      debugPrint("TTS error: $msg");
    });
  }

  Future<void> _generateLesson() async {
    final themeProvider = Provider.of<NeuroThemeProvider>(context, listen: false);
    final profile = themeProvider.activeProfile;
    final energyLevel = themeProvider.energyLevel;

    // Map profile type to backend enum value
    String profileStr;
    switch (profile.profileType) {
      case NeuroProfileType.adhd:
        profileStr = 'ADHD';
        break;
      case NeuroProfileType.dyslexia:
        profileStr = 'Dyslexia';
        break;
      case NeuroProfileType.autism:
        profileStr = 'Autism';
        break;
      default:
        profileStr = 'ADHD';
    }

    String energyStr;
    switch (energyLevel) {
      case EnergyLevel.high:
        energyStr = 'High';
        break;
      case EnergyLevel.medium:
        energyStr = 'Medium';
        break;
      case EnergyLevel.low:
        energyStr = 'Low';
        break;
    }

    try {
      final response = await ApiService.generateLesson(
        topic: widget.topic,
        userProfile: profileStr,
        energyLevel: energyStr,
      );

      // Parse backend response into DeepDiveLesson
      // Backend returns modules with type/content fields; map to our model
      final backendModules = response['modules'] as List? ?? [];
      final lessonModules = <LessonModule>[];

      for (final mod in backendModules) {
        final modMap = Map<String, dynamic>.from(mod);
        final modType = modMap['type'] ?? 'text_block';

        // Build sections from the backend module
        final sections = <ModuleSection>[];

        if (modType == 'text_block') {
          sections.add(ModuleSection(
            heading: modMap['section_type'] ?? 'Explanation',
            text: modMap['content'] ?? '',
            type: modMap['section_type'] ?? 'explanation',
          ));
        } else if (modType == 'key_point') {
          sections.add(ModuleSection(
            heading: 'Key Point',
            text: modMap['content'] ?? '',
            type: 'definition',
          ));
        } else if (modType == 'graph') {
          sections.add(ModuleSection(
            heading: 'Diagram',
            text: modMap['caption'] ?? 'Visual diagram',
            type: 'graph',
            mermaidDiagram: modMap['mermaid_code'],
          ));
        } else if (modType == 'image') {
          sections.add(ModuleSection(
            heading: modMap['alt_text'] ?? 'Image',
            text: modMap['caption'] ?? '',
            type: 'image',
            imageUrl: modMap['image_url'] ?? modMap['image_base64'],
          ));
        } else if (modType == 'deep_dive') {
          sections.add(ModuleSection(
            heading: 'Deep Dive',
            text: modMap['preview'] ?? 'Tap to explore more',
            type: 'deep_dive',
          ));
        } else if (modType == 'interactive_quiz') {
          sections.add(ModuleSection(
            heading: 'Quiz',
            text: modMap['question'] ?? '',
            type: 'example',
          ));
        } else {
          sections.add(ModuleSection(
            heading: modType,
            text: modMap['content'] ?? modMap['preview'] ?? '',
            type: 'explanation',
          ));
        }

        Flashcard? flashcard;
        if (modType == 'interactive_quiz' && modMap['question'] != null) {
          flashcard = Flashcard(
            question: modMap['question'] ?? '',
            answer: modMap['answer'] ?? '',
          );
        }

        String inferredTitle = 'Concept';
        if (modMap['topic'] != null) {
          inferredTitle = modMap['topic'];
        } else if (modMap['caption'] != null && modMap['caption'].toString().isNotEmpty) {
          // Sometimes caption is a good title for graphs/images
          final cap = modMap['caption'].toString();
          // Title shouldn't be too long, if caption is long, use generic
          inferredTitle = cap.length > 30 ? 'Visualization' : cap;
        } else if (modType == 'text_block') {
          final st = (modMap['section_type'] ?? '').toString();
          inferredTitle = st.isNotEmpty ? st[0].toUpperCase() + st.substring(1) : 'Explanation';
        } else if (modType == 'key_point') {
          inferredTitle = 'Key Takeaway';
        } else if (modType == 'graph') {
          inferredTitle = 'Visual Diagram';
        } else if (modType == 'image' || modType == 'image_prompt') {
          inferredTitle = 'Illustration';
        } else if (modType == 'deep_dive') {
          inferredTitle = 'Deep Dive';
        } else if (modType == 'interactive_quiz') {
          inferredTitle = 'Quiz Checkpoint';
        } else {
          inferredTitle = modType.toString().replaceAll('_', ' ');
          inferredTitle = inferredTitle[0].toUpperCase() + inferredTitle.substring(1);
        }

        lessonModules.add(LessonModule(
          title: inferredTitle,
          description: modMap['preview'] ?? '',
          sections: sections,
          flashcard: flashcard,
        ));
      }

      // If backend returned flat modules, group them into logical chunks
      if (mounted) {
        setState(() {
          _lesson = DeepDiveLesson(
            topic: response['title'] ?? widget.topic,
            targetProfile: profileStr,
            modules: lessonModules.isNotEmpty
                ? lessonModules
                : [
                    LessonModule(
                      title: response['title'] ?? widget.topic,
                      description: response['summary'] ?? '',
                      sections: [
                        ModuleSection(
                          heading: 'Content',
                          text: response['summary'] ?? 'No content available.',
                          type: 'explanation',
                        ),
                      ],
                    ),
                  ],
          );
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  /// Play TTS for the entire lesson
  Future<void> _playTts(NeuroProfile profile) async {
    if (_lesson == null) return;

    // Gather all text from the lesson
    final buffer = StringBuffer();
    for (final module in _lesson!.modules) {
      buffer.writeln(module.title);
      buffer.writeln(module.description);
      for (final section in module.sections) {
        if (section.type != 'graph' && section.type != 'image') {
          buffer.writeln(section.text);
        }
      }
    }
    final fullText = buffer.toString().trim();
    if (fullText.isEmpty) return;

    setState(() => _isPlayingTts = true);

    try {
      await _flutterTts.setSpeechRate(profile.ttsSpeed * 0.5); // Normalize speed for local TTS engine
      if (profile.profileType == NeuroProfileType.dyslexia) {
        await _flutterTts.setPitch(0.9); // Deep, calm voice for Dyslexia
      } else if (profile.profileType == NeuroProfileType.adhd) {
        await _flutterTts.setPitch(1.3); // High energy curve
      } else {
        await _flutterTts.setPitch(1.0); // Neutral soothing
      }

      await _flutterTts.speak(fullText);
    } catch (e) {
      if (mounted) {
        setState(() => _isPlayingTts = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('TTS error: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _flutterTts.stop();
    _pageController.dispose();
    super.dispose();
  }

  /// Save the current lesson to Firebase Library
  Future<void> _saveLesson(NeuroProfile profile) async {
    final userId = FirebaseService.currentUserId;
    if (userId == null) return;

    try {
      // Convert lesson modules to serializable maps
      final moduleMaps = _lesson!.modules.map((m) => {
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
          'summary': _lesson!.modules.isNotEmpty
              ? _lesson!.modules.first.description
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
            icon: _isPlayingTts
                ? SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: profile.accentColor,
                    ),
                  )
                : Icon(Icons.volume_up_rounded, color: profile.accentColor),
            onPressed: _isPlayingTts
                ? () {
                    _flutterTts.stop();
                    setState(() => _isPlayingTts = false);
                  }
                : () => _playTts(profile),
          ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: profile.accentColor),
                  const SizedBox(height: 16),
                  Text(
                    'Generating lesson on "${widget.topic}"...',
                    style: TextStyle(
                      fontFamily: profile.fontFamily,
                      color: profile.textColor.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            )
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.error_outline_rounded,
                            color: profile.accentColor, size: 48),
                        const SizedBox(height: 16),
                        Text(
                          'Failed to generate lesson',
                          style: TextStyle(
                            fontFamily: profile.fontFamily,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: profile.textColor,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _errorMessage!,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: profile.fontFamily,
                            fontSize: 13,
                            color: profile.textColor.withValues(alpha: 0.5),
                          ),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: () {
                            setState(() {
                              _isLoading = true;
                              _errorMessage = null;
                            });
                            _generateLesson();
                          },
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('Retry'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: profile.accentColor,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
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
        itemCount: _lesson!.modules.length * 2, // module + flashcard
        itemBuilder: (context, index) {
          final moduleIndex = index ~/ 2;
          final isFlashcard = index % 2 != 0;

          if (isFlashcard) {
            final card = _lesson!.modules[moduleIndex].flashcard;
            if (card == null) return const SizedBox.shrink();
            return _buildFlashcard(card, profile);
          } else {
            return _buildAdhdModuleCard(
                _lesson!.modules[moduleIndex], profile, moduleIndex);
          }
        },
      );
    }
    // 2. Dyslexia Layout -> Continuous scroll, high spacing, warm distinct colors
    else if (profile.profileType == NeuroProfileType.dyslexia) {
      return ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        itemCount: _lesson!.modules.length,
        itemBuilder: (context, index) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 32),
            child: _buildDyslexiaModuleCard(_lesson!.modules[index], profile),
          );
        },
      );
    }
    // 3. Autism Layout -> Accordion, deeply structured, literal descriptions
    else {
      return ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        itemCount: _lesson!.modules.length,
        itemBuilder: (context, index) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _buildAutismAccordion(_lesson!.modules[index], profile),
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

    // ---- GRAPH: Render Mermaid diagram ----
    if (section.type == 'graph' && section.mermaidDiagram != null) {
      return _buildMermaidSection(section, profile);
    }

    // ---- IMAGE: Render from base64 or URL ----
    if (section.type == 'image' && section.imageUrl != null) {
      return _buildImageSection(section, profile);
    }

    // ---- DEEP DIVE: Expandable sub-topic button ----
    if (section.type == 'deep_dive') {
      return _buildDeepDiveButton(section, profile);
    }

    // ---- DEFAULT: Text section ----
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              _getIconForType(section.type),
              size: 18,
              color: isDyslexia
                  ? profile.textColor.withValues(alpha: 0.8)
                  : profile.accentColor,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
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
            ),
          ],
        ),
        const SizedBox(height: 8),
        MarkdownBody(
          data: section.text,
          styleSheet: MarkdownStyleSheet(
            p: TextStyle(
              fontFamily: profile.fontFamily,
              fontSize: profile.fontSize,
              color: profile.textColor,
              height: profile.lineHeight,
              letterSpacing: profile.letterSpacing,
            ),
            h1: TextStyle(
              fontFamily: profile.fontFamily,
              fontSize: profile.fontSize + 8,
              fontWeight: FontWeight.w800,
              color: profile.textColor,
            ),
            h2: TextStyle(
              fontFamily: profile.fontFamily,
              fontSize: profile.fontSize + 6,
              fontWeight: FontWeight.w700,
              color: profile.textColor,
            ),
            h3: TextStyle(
              fontFamily: profile.fontFamily,
              fontSize: profile.fontSize + 4,
              fontWeight: FontWeight.w700,
              color: profile.textColor,
            ),
            strong: TextStyle(
              fontFamily: profile.fontFamily,
              fontWeight: FontWeight.w700,
              color: profile.accentColor,
            ),
            em: TextStyle(
              fontFamily: profile.fontFamily,
              fontStyle: FontStyle.italic,
              color: profile.textColor.withValues(alpha: 0.9),
            ),
            listBullet: TextStyle(
              fontFamily: profile.fontFamily,
              color: profile.accentColor,
            ),
            blockquoteDecoration: BoxDecoration(
              color: profile.accentColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border(
                left: BorderSide(
                  color: profile.accentColor,
                  width: 3,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  IconData _getIconForType(String type) {
    switch (type) {
      case 'definition':
        return Icons.book_rounded;
      case 'example':
        return Icons.lightbulb_rounded;
      case 'graph':
        return Icons.schema_rounded;
      case 'image':
        return Icons.image_rounded;
      case 'deep_dive':
        return Icons.explore_rounded;
      default:
        return Icons.info_outline_rounded;
    }
  }

  // ===========================================
  // GRAPH: Mermaid Diagram Renderer
  // ===========================================

  Widget _buildMermaidSection(ModuleSection section, NeuroProfile profile) {
    final code = section.mermaidDiagram ?? '';
    // Parse mermaid code into visual flow nodes
    final nodes = _parseMermaidToNodes(code);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.schema_rounded, size: 18, color: profile.accentColor),
            const SizedBox(width: 8),
            Text(
              'DIAGRAM',
              style: TextStyle(
                fontFamily: profile.fontFamily,
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: profile.accentColor,
                letterSpacing: 1.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (section.text.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              section.text,
              style: TextStyle(
                fontFamily: profile.fontFamily,
                fontSize: profile.fontSize - 1,
                color: profile.textColor.withValues(alpha: 0.7),
              ),
            ),
          ),
        // Render the flowchart visually
        if (nodes.isNotEmpty) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: profile.accentColor.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: profile.accentColor.withValues(alpha: 0.2),
              ),
            ),
            child: Column(
              children: [
                for (int i = 0; i < nodes.length; i++) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 14),
                    decoration: BoxDecoration(
                      color: profile.accentColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: profile.accentColor.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      nodes[i],
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: profile.fontFamily,
                        fontSize: profile.fontSize - 1,
                        fontWeight: FontWeight.w600,
                        color: profile.textColor,
                      ),
                    ),
                  ),
                  if (i < nodes.length - 1) ...[
                    const SizedBox(height: 4),
                    Icon(Icons.arrow_downward_rounded,
                        color: profile.accentColor.withValues(alpha: 0.5),
                        size: 20),
                    const SizedBox(height: 4),
                  ],
                ],
              ],
            ),
          ),
        ] else ...[
          // Fallback: show raw mermaid code in a styled block
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: profile.cardColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: profile.accentColor.withValues(alpha: 0.2),
              ),
            ),
            child: Text(
              code,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                color: profile.textColor.withValues(alpha: 0.8),
                height: 1.6,
              ),
            ),
          ),
        ],
      ],
    );
  }

  List<String> _parseMermaidToNodes(String mermaid) {
    // Simple parser: extract node labels from mermaid flowchart
    final nodes = <String>[];
    final lines = mermaid.split('\n');
    final labelRegex = RegExp(r'\[([^\]]+)\]|\(([^)]+)\)|"([^"]+)"');

    for (final line in lines) {
      if (line.trim().startsWith('graph') ||
          line.trim().startsWith('flowchart') ||
          line.trim().isEmpty) continue;

      final matches = labelRegex.allMatches(line);
      for (final match in matches) {
        final label = match.group(1) ?? match.group(2) ?? match.group(3);
        if (label != null && !nodes.contains(label)) {
          nodes.add(label);
        }
      }
    }
    return nodes;
  }

  // ===========================================
  // IMAGE: Render AI-generated images
  // ===========================================

  Widget _buildImageSection(ModuleSection section, NeuroProfile profile) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.image_rounded, size: 18, color: profile.accentColor),
            const SizedBox(width: 8),
            Text(
              'ILLUSTRATION',
              style: TextStyle(
                fontFamily: profile.fontFamily,
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: profile.accentColor,
                letterSpacing: 1.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: section.imageUrl!.startsWith('http')
              ? Image.network(
                  section.imageUrl!,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    height: 150,
                    decoration: BoxDecoration(
                      color: profile.accentColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.image_rounded,
                              color: profile.accentColor, size: 32),
                          const SizedBox(height: 8),
                          Text(
                            section.heading,
                            style: TextStyle(
                              fontFamily: profile.fontFamily,
                              color: profile.textColor.withValues(alpha: 0.6),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              : Container(
                  height: 150,
                  decoration: BoxDecoration(
                    color: profile.accentColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.image_rounded,
                            color: profile.accentColor, size: 32),
                        const SizedBox(height: 8),
                        Text(
                          section.heading,
                          style: TextStyle(
                            fontFamily: profile.fontFamily,
                            color: profile.textColor.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
        ),
        if (section.text.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            section.text,
            style: TextStyle(
              fontFamily: profile.fontFamily,
              fontSize: profile.fontSize - 2,
              fontStyle: FontStyle.italic,
              color: profile.textColor.withValues(alpha: 0.6),
            ),
          ),
        ],
      ],
    );
  }

  // ===========================================
  // DEEP DIVE: Get More Details Button
  // ===========================================

  Widget _buildDeepDiveButton(ModuleSection section, NeuroProfile profile) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => LessonScreen(topic: section.heading == 'Deep Dive'
                ? section.text.split('.').first
                : section.heading),
          ),
        );
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              profile.accentColor.withValues(alpha: 0.15),
              profile.accentColor.withValues(alpha: 0.05),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: profile.accentColor.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          children: [
            Icon(Icons.explore_rounded,
                color: profile.accentColor, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '🔍 Get More Details',
                    style: TextStyle(
                      fontFamily: profile.fontFamily,
                      fontSize: profile.fontSize,
                      fontWeight: FontWeight.w700,
                      color: profile.accentColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    section.text,
                    style: TextStyle(
                      fontFamily: profile.fontFamily,
                      fontSize: profile.fontSize - 2,
                      color: profile.textColor.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded,
                color: profile.accentColor, size: 16),
          ],
        ),
      ),
    );
  }
}
