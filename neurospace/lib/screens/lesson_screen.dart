/// NeuroSpace — Universal Lesson Screen
/// Morphs its entire structural layout depending on the active NeuroProfile.
/// Extended with: key_points, wikipedia_links, MCQ quiz, accessibility
/// (simplified_text toggle + audio_script TTS), and improved per-profile UI.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flip_card/flip_card.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:url_launcher/url_launcher.dart';
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
  bool _showSimplified = false;
  final FlutterTts _flutterTts = FlutterTts();

  // Track selected MCQ answers: quizIndex -> selectedOption
  final Map<int, String> _selectedAnswers = {};

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
      final backendModules = response['modules'] as List? ?? [];
      final lessonModules = <LessonModule>[];

      for (final mod in backendModules) {
        final modMap = Map<String, dynamic>.from(mod);
        final modType = modMap['type'] ?? 'text_block';

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
        } else if (modType == 'image' || modType == 'image_prompt') {
          sections.add(ModuleSection(
            heading: modMap['alt_text'] ?? modMap['description'] ?? 'Image',
            text: modMap['caption'] ?? modMap['description'] ?? '',
            type: 'image',
            imageUrl: modMap['image_url'] ?? modMap['image_base64'],
          ));
        } else if (modType == 'deep_dive') {
          sections.add(ModuleSection(
            heading: modMap['topic'] ?? 'Deep Dive',
            text: modMap['preview'] ?? 'Tap to explore more',
            type: 'deep_dive',
          ));
        } else if (modType == 'interactive_quiz') {
          sections.add(ModuleSection(
            heading: 'Quiz',
            text: modMap['question'] ?? '',
            type: 'quiz',
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
          final cap = modMap['caption'].toString();
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
          inferredTitle = modMap['topic'] ?? 'Deep Dive';
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
            keyPoints: (response['key_points'] as List?)
                    ?.map((e) => e.toString())
                    .toList() ??
                [],
            wikipediaLinks: (response['wikipedia_links'] as List?)
                    ?.map((e) => WikiLink.fromJson(Map<String, dynamic>.from(e)))
                    .toList() ??
                [],
            quizQuestions: ((response['interactive'] as Map<String, dynamic>?)?['quiz'] as List?)
                    ?.map((e) => QuizQuestion.fromJson(Map<String, dynamic>.from(e)))
                    .toList() ??
                [],
            thinkingQuestions: ((response['interactive'] as Map<String, dynamic>?)?['questions'] as List?)
                    ?.map((e) => e.toString())
                    .toList() ??
                [],
            accessibility: response['accessibility'] != null
                ? LessonAccessibility.fromJson(
                    Map<String, dynamic>.from(response['accessibility']))
                : null,
            ttsText: response['tts_text'],
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

  /// Play TTS — prefers audio_script from accessibility, fallback to full text
  Future<void> _playTts(NeuroProfile profile) async {
    if (_lesson == null) return;

    // Prefer the accessibility audio_script if available
    String textToSpeak = '';
    if (_lesson!.accessibility != null &&
        _lesson!.accessibility!.audioScript.isNotEmpty) {
      textToSpeak = _lesson!.accessibility!.audioScript;
    } else if (_lesson!.ttsText != null && _lesson!.ttsText!.isNotEmpty) {
      textToSpeak = _lesson!.ttsText!;
    } else {
      final buffer = StringBuffer();
      for (final module in _lesson!.modules) {
        buffer.writeln(module.title);
        for (final section in module.sections) {
          if (section.type != 'graph' && section.type != 'image') {
            buffer.writeln(section.text);
          }
        }
      }
      textToSpeak = buffer.toString().trim();
    }
    if (textToSpeak.isEmpty) return;

    setState(() => _isPlayingTts = true);

    try {
      await _flutterTts.setSpeechRate(profile.ttsSpeed * 0.5);
      if (profile.profileType == NeuroProfileType.dyslexia) {
        await _flutterTts.setPitch(0.9);
      } else if (profile.profileType == NeuroProfileType.adhd) {
        await _flutterTts.setPitch(1.3);
      } else {
        await _flutterTts.setPitch(1.0);
      }
      await _flutterTts.speak(textToSpeak);
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
        title: Text(
          widget.topic,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
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
          // Simplify toggle
          if (_lesson?.accessibility != null &&
              _lesson!.accessibility!.simplifiedText.isNotEmpty)
            IconButton(
              icon: Icon(
                _showSimplified ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                color: _showSimplified ? profile.accentColor : profile.textColor.withValues(alpha: 0.5),
              ),
              tooltip: _showSimplified ? 'Show full lesson' : 'Simplify',
              onPressed: () => setState(() => _showSimplified = !_showSimplified),
            ),
          // Save to Library
          IconButton(
            icon: Icon(
              _isSaved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
              color: _isSaved ? profile.accentColor : profile.textColor.withValues(alpha: 0.5),
            ),
            onPressed: _isSaved ? null : () => _saveLesson(profile),
          ),
          // TTS
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
          ? _buildLoadingState(profile)
          : _errorMessage != null
              ? _buildErrorState(profile)
              : _showSimplified
                  ? _buildSimplifiedView(profile)
                  : _buildFullLessonView(profile),
    );
  }

  // ===========================================
  // LOADING & ERROR
  // ===========================================

  Widget _buildLoadingState(NeuroProfile profile) {
    return Center(
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
    );
  }

  Widget _buildErrorState(NeuroProfile profile) {
    return Center(
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
    );
  }

  // ===========================================
  // SIMPLIFIED VIEW (Accessibility)
  // ===========================================

  Widget _buildSimplifiedView(NeuroProfile profile) {
    final simplified = _lesson!.accessibility!.simplifiedText;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: profile.accentColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: profile.accentColor.withValues(alpha: 0.2),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.auto_awesome_rounded,
                        color: profile.accentColor, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'SIMPLIFIED VIEW',
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
                const SizedBox(height: 16),
                Text(
                  simplified,
                  style: TextStyle(
                    fontFamily: profile.fontFamily,
                    fontSize: profile.fontSize + 2,
                    color: profile.textColor,
                    height: 1.8,
                    letterSpacing: profile.letterSpacing,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          // Key points
          if (_lesson!.keyPoints.isNotEmpty) ...[
            _buildKeyPointsSection(profile),
            const SizedBox(height: 24),
          ],
          // Back button
          Center(
            child: TextButton.icon(
              onPressed: () => setState(() => _showSimplified = false),
              icon: const Icon(Icons.arrow_back_rounded),
              label: const Text('View full lesson'),
              style: TextButton.styleFrom(
                foregroundColor: profile.accentColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================
  // FULL LESSON VIEW — Routes to profile-specific layout
  // ===========================================

  Widget _buildFullLessonView(NeuroProfile profile) {
    return CustomScrollView(
      slivers: [
        // Summary header
        SliverToBoxAdapter(
          child: _buildLessonHeader(profile),
        ),
        // Key Points
        if (_lesson!.keyPoints.isNotEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _buildKeyPointsSection(profile),
            ),
          ),
        // Modules — profile-specific
        SliverToBoxAdapter(
          child: _buildAdaptiveModules(profile),
        ),
        // Wikipedia Links
        if (_lesson!.wikipediaLinks.isNotEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _buildWikipediaSection(profile),
            ),
          ),
        // MCQ Quiz
        if (_lesson!.quizQuestions.isNotEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _buildMcqQuizSection(profile),
            ),
          ),
        // Thinking Questions
        if (_lesson!.thinkingQuestions.isNotEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _buildThinkingQuestionsSection(profile),
            ),
          ),
        // Bottom padding
        const SliverToBoxAdapter(child: SizedBox(height: 48)),
      ],
    );
  }

  // ===========================================
  // LESSON HEADER
  // ===========================================

  Widget _buildLessonHeader(NeuroProfile profile) {
    final isAdhd = profile.profileType == NeuroProfileType.adhd;
    final isDyslexia = profile.profileType == NeuroProfileType.dyslexia;

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      padding: EdgeInsets.all(isAdhd ? 20 : 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            profile.accentColor.withValues(alpha: 0.12),
            profile.accentColor.withValues(alpha: 0.04),
          ],
        ),
        borderRadius: BorderRadius.circular(isAdhd ? 28 : 20),
        border: Border.all(
          color: profile.accentColor.withValues(alpha: 0.15),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _lesson!.topic,
            style: TextStyle(
              fontFamily: profile.fontFamily,
              fontSize: isDyslexia ? profile.fontSize + 4 : profile.fontSize + 6,
              fontWeight: FontWeight.w800,
              color: profile.textColor,
              height: 1.3,
            ),
          ),
          if (_lesson!.modules.isNotEmpty &&
              _lesson!.modules.first.description.isNotEmpty) ...[
            SizedBox(height: isDyslexia ? 16 : 10),
            Text(
              _lesson!.modules.first.description.isNotEmpty
                  ? _lesson!.modules.first.description
                  : '',
              style: TextStyle(
                fontFamily: profile.fontFamily,
                fontSize: profile.fontSize - 1,
                color: profile.textColor.withValues(alpha: 0.7),
                height: profile.lineHeight,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ===========================================
  // KEY POINTS SECTION
  // ===========================================

  Widget _buildKeyPointsSection(NeuroProfile profile) {
    final isAdhd = profile.profileType == NeuroProfileType.adhd;

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: profile.cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: profile.accentColor.withValues(alpha: 0.15),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(isAdhd ? Icons.bolt_rounded : Icons.checklist_rounded,
                  color: profile.accentColor, size: 20),
              const SizedBox(width: 8),
              Text(
                isAdhd ? '⚡ KEY TAKEAWAYS' : 'KEY POINTS',
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
          const SizedBox(height: 16),
          ...List.generate(_lesson!.keyPoints.length, (i) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    margin: const EdgeInsets.only(right: 12),
                    decoration: BoxDecoration(
                      color: profile.accentColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text(
                        '${i + 1}',
                        style: TextStyle(
                          fontFamily: profile.fontFamily,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: profile.accentColor,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      _lesson!.keyPoints[i],
                      style: TextStyle(
                        fontFamily: profile.fontFamily,
                        fontSize: profile.fontSize,
                        color: profile.textColor,
                        height: profile.lineHeight,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // ===========================================
  // ADAPTIVE MODULES — Routes to profile layout
  // ===========================================

  Widget _buildAdaptiveModules(NeuroProfile profile) {
    if (profile.profileType == NeuroProfileType.adhd) {
      return _buildAdhdModules(profile);
    } else if (profile.profileType == NeuroProfileType.dyslexia) {
      return _buildDyslexiaModules(profile);
    } else {
      return _buildAutismModules(profile);
    }
  }

  // ===========================================
  // ADHD: Punchy cards with gradient borders
  // ===========================================

  Widget _buildAdhdModules(NeuroProfile profile) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: List.generate(_lesson!.modules.length, (index) {
          final module = _lesson!.modules[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: Column(
              children: [
                _buildAdhdModuleCard(module, profile, index),
                if (module.flashcard != null) ...[
                  const SizedBox(height: 16),
                  _buildFlashcard(module.flashcard!, profile),
                ],
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildAdhdModuleCard(
      LessonModule module, NeuroProfile profile, int index) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: profile.cardColor,
        borderRadius: BorderRadius.circular(28),
        border: profile.focusBordersEnabled
            ? Border.all(
                color: profile.accentColor.withValues(alpha: 0.25), width: 2)
            : null,
        boxShadow: [
          BoxShadow(
            color: profile.accentColor.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  profile.accentColor.withValues(alpha: 0.15),
                  profile.accentColor.withValues(alpha: 0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '⚡ CARD ${index + 1}',
              style: TextStyle(
                fontFamily: profile.fontFamily,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: profile.accentColor,
                letterSpacing: 2,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            module.title,
            style: TextStyle(
              fontFamily: profile.fontFamily,
              fontSize: profile.fontSize + 6,
              fontWeight: FontWeight.w800,
              color: profile.textColor,
              height: 1.2,
            ),
          ),
          if (module.description.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              module.description,
              style: TextStyle(
                fontFamily: profile.fontFamily,
                fontSize: profile.fontSize - 1,
                color: profile.textColor.withValues(alpha: 0.5),
              ),
            ),
          ],
          const SizedBox(height: 20),
          ...module.sections.map((s) => Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: _buildTextSection(s, profile),
              )),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms, delay: (index * 100).ms).slideY(
        begin: 0.1, end: 0, duration: 400.ms, delay: (index * 100).ms);
  }

  Widget _buildFlashcard(Flashcard flashcard, NeuroProfile profile) {
    return FlipCard(
      direction: FlipDirection.HORIZONTAL,
      front: _buildCardSide(
          'QUESTION', flashcard.question, profile, Colors.orangeAccent),
      back: _buildCardSide(
          'ANSWER', flashcard.answer, profile, const Color(0xFF4CAF50)),
    );
  }

  Widget _buildCardSide(
      String label, String text, NeuroProfile profile, Color accent) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: profile.cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: accent.withValues(alpha: 0.4), width: 2),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.15),
            blurRadius: 20,
            offset: const Offset(0, 8),
          )
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontFamily: profile.fontFamily,
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: accent,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: profile.fontFamily,
              fontSize: profile.fontSize + 2,
              fontWeight: FontWeight.w600,
              color: profile.textColor,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 20),
          Icon(Icons.touch_app_rounded,
              color: profile.textColor.withValues(alpha: 0.15), size: 28),
          Text(
            'Tap to flip',
            style: TextStyle(
              fontFamily: profile.fontFamily,
              fontSize: 11,
              color: profile.textColor.withValues(alpha: 0.3),
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================
  // DYSLEXIA: High spacing, color-coded blocks, large text
  // ===========================================

  Widget _buildDyslexiaModules(NeuroProfile profile) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: List.generate(_lesson!.modules.length, (index) {
          final module = _lesson!.modules[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 32),
            child: _buildDyslexiaModuleCard(module, profile),
          );
        }),
      ),
    );
  }

  Widget _buildDyslexiaModuleCard(LessonModule module, NeuroProfile profile) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title with thick underline
        Text(
          module.title,
          style: TextStyle(
            fontFamily: profile.fontFamily,
            fontSize: profile.fontSize + 4,
            fontWeight: FontWeight.w700,
            color: profile.textColor,
            height: profile.lineHeight,
            decoration: TextDecoration.underline,
            decorationColor: profile.accentColor.withValues(alpha: 0.5),
            decorationThickness: 3,
          ),
        ),
        if (module.description.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            module.description,
            style: TextStyle(
              fontFamily: profile.fontFamily,
              fontSize: profile.fontSize,
              color: profile.textColor.withValues(alpha: 0.7),
              height: profile.lineHeight,
            ),
          ),
        ],
        const SizedBox(height: 20),
        ...module.sections.map((s) {
          // Color-coded containers per section_type
          Color bgColor;
          switch (s.type) {
            case 'definition':
              bgColor = const Color(0xFF1E3A5F).withValues(alpha: 0.15); // Blue tint
              break;
            case 'example':
              bgColor = const Color(0xFF2E7D32).withValues(alpha: 0.12); // Green tint
              break;
            case 'summary':
              bgColor = const Color(0xFFF9A825).withValues(alpha: 0.1); // Yellow tint
              break;
            default:
              bgColor = profile.cardColor;
          }
          return Container(
            margin: const EdgeInsets.only(bottom: 20),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: profile.accentColor.withValues(alpha: 0.1),
              ),
            ),
            child: _buildTextSection(s, profile),
          );
        }),
      ],
    );
  }

  // ===========================================
  // AUTISM: Structured accordions with numbering
  // ===========================================

  Widget _buildAutismModules(NeuroProfile profile) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: List.generate(_lesson!.modules.length, (index) {
          final module = _lesson!.modules[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _buildAutismAccordion(module, profile, index),
          );
        }),
      ),
    );
  }

  Widget _buildAutismAccordion(
      LessonModule module, NeuroProfile profile, int index) {
    return Container(
      decoration: BoxDecoration(
        color: profile.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: profile.focusBordersEnabled
            ? Border.all(color: profile.accentColor.withValues(alpha: 0.1))
            : null,
      ),
      child: ExpansionTile(
        leading: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: profile.accentColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(
              '${index + 1}',
              style: TextStyle(
                fontFamily: profile.fontFamily,
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: profile.accentColor,
              ),
            ),
          ),
        ),
        title: Text(
          module.title,
          style: TextStyle(
            fontFamily: profile.fontFamily,
            fontSize: profile.fontSize,
            fontWeight: FontWeight.w600,
            color: profile.textColor,
          ),
        ),
        subtitle: module.description.isNotEmpty
            ? Text(
                module.description,
                style: TextStyle(
                  fontFamily: profile.fontFamily,
                  fontSize: profile.fontSize - 2,
                  color: profile.textColor.withValues(alpha: 0.5),
                ),
              )
            : null,
        iconColor: profile.accentColor,
        collapsedIconColor: profile.textColor.withValues(alpha: 0.4),
        childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
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

    // ---- IMAGE: Render from URL ----
    if (section.type == 'image' && section.imageUrl != null) {
      return _buildImageSection(section, profile);
    }

    // ---- DEEP DIVE: Expandable sub-topic ----
    if (section.type == 'deep_dive') {
      return _buildDeepDiveButton(section, profile);
    }

    // ---- DEFAULT: Text section with MarkdownBody ----
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              _getIconForType(section.type),
              size: 16,
              color: isDyslexia
                  ? profile.textColor.withValues(alpha: 0.7)
                  : profile.accentColor,
            ),
            const SizedBox(width: 8),
            Text(
              section.heading.toUpperCase(),
              style: TextStyle(
                fontFamily: profile.fontFamily,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: isDyslexia
                    ? profile.textColor.withValues(alpha: 0.7)
                    : profile.accentColor,
                letterSpacing: 1.5,
              ),
            ),
          ],
        ),
        SizedBox(height: isDyslexia ? 12 : 8),
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
                left: BorderSide(color: profile.accentColor, width: 3),
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
      case 'explanation':
        return Icons.info_outline_rounded;
      case 'summary':
        return Icons.summarize_rounded;
      case 'graph':
        return Icons.schema_rounded;
      case 'image':
        return Icons.image_rounded;
      case 'deep_dive':
        return Icons.explore_rounded;
      case 'quiz':
        return Icons.quiz_rounded;
      default:
        return Icons.article_rounded;
    }
  }

  // ===========================================
  // WIKIPEDIA LINKS
  // ===========================================

  Widget _buildWikipediaSection(NeuroProfile profile) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: profile.cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: profile.accentColor.withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.language_rounded,
                  color: profile.accentColor, size: 20),
              const SizedBox(width: 8),
              Text(
                'LEARN MORE',
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
          const SizedBox(height: 16),
          ...(_lesson!.wikipediaLinks.map((link) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: InkWell(
                onTap: () async {
                  final uri = Uri.tryParse(link.url);
                  if (uri != null && await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: profile.accentColor.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: profile.accentColor.withValues(alpha: 0.12),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.open_in_new_rounded,
                          color: profile.accentColor, size: 18),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          link.title,
                          style: TextStyle(
                            fontFamily: profile.fontFamily,
                            fontSize: profile.fontSize,
                            color: profile.accentColor,
                            fontWeight: FontWeight.w600,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          })),
        ],
      ),
    );
  }

  // ===========================================
  // MCQ QUIZ SECTION
  // ===========================================

  Widget _buildMcqQuizSection(NeuroProfile profile) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: profile.cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: profile.accentColor.withValues(alpha: 0.15),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.quiz_rounded,
                  color: profile.accentColor, size: 20),
              const SizedBox(width: 8),
              Text(
                'QUIZ TIME',
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
          const SizedBox(height: 20),
          ...List.generate(_lesson!.quizQuestions.length, (qi) {
            final q = _lesson!.quizQuestions[qi];
            final selected = _selectedAnswers[qi];
            final isAnswered = selected != null;
            final isCorrect = selected == q.answer;

            return Container(
              margin: const EdgeInsets.only(bottom: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Q${qi + 1}. ${q.question}',
                    style: TextStyle(
                      fontFamily: profile.fontFamily,
                      fontSize: profile.fontSize,
                      fontWeight: FontWeight.w600,
                      color: profile.textColor,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...q.options.map((option) {
                    final isSelected = selected == option;
                    final isCorrectOption = option == q.answer;
                    Color optionColor = profile.accentColor.withValues(alpha: 0.06);
                    Color borderColor = profile.accentColor.withValues(alpha: 0.12);
                    Color textColor = profile.textColor;

                    if (isAnswered) {
                      if (isCorrectOption) {
                        optionColor = const Color(0xFF4CAF50).withValues(alpha: 0.15);
                        borderColor = const Color(0xFF4CAF50).withValues(alpha: 0.4);
                        textColor = const Color(0xFF4CAF50);
                      } else if (isSelected && !isCorrect) {
                        optionColor = Colors.redAccent.withValues(alpha: 0.1);
                        borderColor = Colors.redAccent.withValues(alpha: 0.3);
                        textColor = Colors.redAccent;
                      }
                    }

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: InkWell(
                        onTap: isAnswered
                            ? null
                            : () {
                                setState(() {
                                  _selectedAnswers[qi] = option;
                                });
                              },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 14),
                          decoration: BoxDecoration(
                            color: optionColor,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: borderColor),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  option,
                                  style: TextStyle(
                                    fontFamily: profile.fontFamily,
                                    fontSize: profile.fontSize,
                                    color: textColor,
                                    fontWeight: isSelected
                                        ? FontWeight.w600
                                        : FontWeight.w400,
                                  ),
                                ),
                              ),
                              if (isAnswered && isCorrectOption)
                                const Icon(Icons.check_circle_rounded,
                                    color: Color(0xFF4CAF50), size: 20),
                              if (isAnswered && isSelected && !isCorrect)
                                const Icon(Icons.cancel_rounded,
                                    color: Colors.redAccent, size: 20),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                  if (isAnswered)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        isCorrect ? '🎉 Correct!' : '❌ The answer is: ${q.answer}',
                        style: TextStyle(
                          fontFamily: profile.fontFamily,
                          fontSize: profile.fontSize - 1,
                          fontWeight: FontWeight.w600,
                          color: isCorrect
                              ? const Color(0xFF4CAF50)
                              : Colors.redAccent,
                        ),
                      ),
                    ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // ===========================================
  // THINKING QUESTIONS
  // ===========================================

  Widget _buildThinkingQuestionsSection(NeuroProfile profile) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: profile.accentColor.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: profile.accentColor.withValues(alpha: 0.12),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.psychology_rounded,
                  color: profile.accentColor, size: 20),
              const SizedBox(width: 8),
              Text(
                'THINK ABOUT IT',
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
          const SizedBox(height: 16),
          ..._lesson!.thinkingQuestions.map((q) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('💭 ',
                        style: TextStyle(fontSize: profile.fontSize)),
                    Expanded(
                      child: Text(
                        q,
                        style: TextStyle(
                          fontFamily: profile.fontFamily,
                          fontSize: profile.fontSize,
                          fontStyle: FontStyle.italic,
                          color: profile.textColor.withValues(alpha: 0.8),
                          height: profile.lineHeight,
                        ),
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  // ===========================================
  // GRAPH: Mermaid Diagram Renderer
  // ===========================================

  Widget _buildMermaidSection(ModuleSection section, NeuroProfile profile) {
    final code = section.mermaidDiagram ?? '';
    final nodes = _parseMermaidToNodes(code);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.schema_rounded, size: 16, color: profile.accentColor),
            const SizedBox(width: 8),
            Text(
              'DIAGRAM',
              style: TextStyle(
                fontFamily: profile.fontFamily,
                fontSize: 11,
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
  // IMAGE: Render images
  // ===========================================

  Widget _buildImageSection(ModuleSection section, NeuroProfile profile) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.image_rounded, size: 16, color: profile.accentColor),
            const SizedBox(width: 8),
            Text(
              'ILLUSTRATION',
              style: TextStyle(
                fontFamily: profile.fontFamily,
                fontSize: 11,
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
                  errorBuilder: (_, __, ___) => _buildImagePlaceholder(section, profile),
                )
              : _buildImagePlaceholder(section, profile),
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

  Widget _buildImagePlaceholder(ModuleSection section, NeuroProfile profile) {
    return Container(
      height: 120,
      decoration: BoxDecoration(
        color: profile.accentColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.image_rounded,
                color: profile.accentColor.withValues(alpha: 0.4), size: 32),
            const SizedBox(height: 8),
            Text(
              section.heading,
              style: TextStyle(
                fontFamily: profile.fontFamily,
                fontSize: 12,
                color: profile.textColor.withValues(alpha: 0.4),
              ),
            ),
          ],
        ),
      ),
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
            builder: (_) => LessonScreen(
                topic: section.heading == 'Deep Dive'
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
              profile.accentColor.withValues(alpha: 0.12),
              profile.accentColor.withValues(alpha: 0.04),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: profile.accentColor.withValues(alpha: 0.2),
          ),
        ),
        child: Row(
          children: [
            Icon(Icons.explore_rounded,
                color: profile.accentColor, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '🔍 Explore: ${section.heading}',
                    style: TextStyle(
                      fontFamily: profile.fontFamily,
                      fontSize: profile.fontSize - 1,
                      fontWeight: FontWeight.w700,
                      color: profile.accentColor,
                    ),
                  ),
                  if (section.text.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      section.text,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: profile.fontFamily,
                        fontSize: profile.fontSize - 2,
                        color: profile.textColor.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded,
                color: profile.accentColor, size: 14),
          ],
        ),
      ),
    );
  }
}
