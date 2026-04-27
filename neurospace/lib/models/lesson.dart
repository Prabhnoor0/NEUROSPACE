/// NeuroSpace — Lesson Models
/// Defines the structured JSON syllabus that the backend AI generates.
/// Extended with unified schema: key_points, wikipedia_links, interactive MCQ,
/// accessibility (simplified_text + audio_script).

class LessonModule {
  final String title;
  final String description;
  final List<ModuleSection> sections;
  final Flashcard? flashcard;

  LessonModule({
    required this.title,
    required this.description,
    required this.sections,
    this.flashcard,
  });

  factory LessonModule.fromJson(Map<String, dynamic> json) {
    final sectionsJson = json['sections'] as List?;
    final unifiedContent = (json['content'] ?? '').toString();
    final unifiedType = (json['section_type'] ?? json['type'] ?? 'explanation').toString();

    // Support both legacy module schema (with sections[]) and unified schema
    // where each module item itself is a single text block.
    final resolvedSections = sectionsJson != null
        ? sectionsJson
            .map((e) => ModuleSection.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList()
        : (unifiedContent.trim().isNotEmpty
            ? [
                ModuleSection(
                  heading: (json['title'] ?? '').toString(),
                  text: unifiedContent,
                  type: unifiedType,
                ),
              ]
            : <ModuleSection>[]);

    return LessonModule(
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      sections: resolvedSections,
      flashcard: json['flashcard'] != null
          ? Flashcard.fromJson(Map<String, dynamic>.from(json['flashcard'] as Map))
          : null,
    );
  }
}

class ModuleSection {
  final String heading;
  final String text;
  final String type; // 'definition', 'example', 'analogy', 'literal_fact', 'explanation', 'summary'
  final String? imageUrl;
  final String? mermaidDiagram;

  ModuleSection({
    required this.heading,
    required this.text,
    required this.type,
    this.imageUrl,
    this.mermaidDiagram,
  });

  factory ModuleSection.fromJson(Map<String, dynamic> json) {
    return ModuleSection(
      heading: json['heading'] ?? '',
      text: json['text'] ?? '',
      type: json['type'] ?? 'literal_fact',
      imageUrl: json['image_url'],
      mermaidDiagram: json['mermaid_diagram'],
    );
  }
}

class Flashcard {
  final String question;
  final String answer;

  Flashcard({
    required this.question,
    required this.answer,
  });

  factory Flashcard.fromJson(Map<String, dynamic> json) {
    return Flashcard(
      question: json['question'] ?? '',
      answer: json['answer'] ?? '',
    );
  }
}

/// MCQ Quiz question with multiple-choice options
class QuizQuestion {
  final String question;
  final List<String> options;
  final String answer;

  QuizQuestion({
    required this.question,
    required this.options,
    required this.answer,
  });

  factory QuizQuestion.fromJson(Map<String, dynamic> json) {
    return QuizQuestion(
      question: json['question'] ?? '',
      options: (json['options'] as List?)?.map((e) => e.toString()).toList() ?? [],
      answer: json['answer'] ?? '',
    );
  }
}

/// Wikipedia link reference
class WikiLink {
  final String title;
  final String url;

  WikiLink({required this.title, required this.url});

  factory WikiLink.fromJson(Map<String, dynamic> json) {
    return WikiLink(
      title: json['title'] ?? '',
      url: json['url'] ?? '',
    );
  }
}

/// Accessibility data from the LLM
class LessonAccessibility {
  final String simplifiedText;
  final String audioScript;

  LessonAccessibility({
    required this.simplifiedText,
    required this.audioScript,
  });

  factory LessonAccessibility.fromJson(Map<String, dynamic> json) {
    return LessonAccessibility(
      simplifiedText: json['simplified_text'] ?? '',
      audioScript: json['audio_script'] ?? '',
    );
  }
}

class DeepDiveLesson {
  final String topic;
  final String targetProfile;
  final List<LessonModule> modules;

  // New unified schema fields
  final List<String> keyPoints;
  final List<WikiLink> wikipediaLinks;
  final List<QuizQuestion> quizQuestions;
  final List<String> thinkingQuestions;
  final LessonAccessibility? accessibility;
  final String? ttsText;

  DeepDiveLesson({
    required this.topic,
    required this.targetProfile,
    required this.modules,
    this.keyPoints = const [],
    this.wikipediaLinks = const [],
    this.quizQuestions = const [],
    this.thinkingQuestions = const [],
    this.accessibility,
    this.ttsText,
  });

  factory DeepDiveLesson.fromJson(Map<String, dynamic> json) {
    // Parse interactive section
    final interactiveRaw = json['interactive'];
    final interactive = interactiveRaw is Map
      ? Map<String, dynamic>.from(interactiveRaw)
      : null;
    final quizList = (interactive?['quiz'] as List?)
        ?.map((e) => QuizQuestion.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList() ??
        [];
    final questionsList = (interactive?['questions'] as List?)
            ?.map((e) => e.toString())
            .toList() ??
        [];

    return DeepDiveLesson(
      topic: json['topic'] ?? json['title'] ?? '',
      targetProfile: json['target_profile'] ?? 'custom',
      modules: (json['modules'] as List?)
              ?.map((e) => LessonModule.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList() ??
          [],
      keyPoints: (json['key_points'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      wikipediaLinks: (json['wikipedia_links'] as List?)
              ?.map((e) => WikiLink.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList() ??
          [],
      quizQuestions: quizList,
      thinkingQuestions: questionsList,
      accessibility: json['accessibility'] != null
          ? LessonAccessibility.fromJson(
              Map<String, dynamic>.from(json['accessibility'] as Map),
            )
          : null,
      ttsText: json['tts_text'],
    );
  }
}

// ==========================================
// MOCK DATA GENERATOR
// ==========================================

class MockLessonGenerator {
  static DeepDiveLesson getMockLesson(String profileType) {
    return DeepDiveLesson(
      topic: 'How Wi-Fi Works',
      targetProfile: profileType,
      keyPoints: [
        'Wi-Fi uses radio waves to transmit data wirelessly',
        'A router connects your devices to the internet',
        'Wi-Fi operates on 2.4GHz and 5GHz frequencies',
      ],
      wikipediaLinks: [
        WikiLink(title: 'Wi-Fi', url: 'https://en.wikipedia.org/wiki/Wi-Fi'),
      ],
      quizQuestions: [
        QuizQuestion(
          question: 'What type of waves does Wi-Fi use?',
          options: ['Sound waves', 'Radio waves', 'Light waves', 'Micro waves'],
          answer: 'Radio waves',
        ),
      ],
      thinkingQuestions: ['Why does Wi-Fi signal get weaker through walls?'],
      accessibility: LessonAccessibility(
        simplifiedText: 'Wi-Fi lets your phone connect to the internet without a cable. A router sends radio waves that carry data to your devices.',
        audioScript: 'Let me explain how Wi-Fi works. Wi-Fi is a way to connect to the internet without any wires. Your router, that box plugged into the wall, sends out radio waves. Your phone picks up those waves and turns them into the websites and videos you see.',
      ),
      modules: [
        LessonModule(
          title: 'The Invisible Cable',
          description: 'Understanding radio waves.',
          sections: [
            ModuleSection(
              heading: 'Definition',
              text: 'Wi-Fi is a wireless networking technology that allows devices '
                  'like computers, mobile devices, and other equipment to interface '
                  'with the Internet.',
              type: 'definition',
            ),
            ModuleSection(
              heading: profileType == 'autism' ? 'Literal Fact' : 'Example',
              text: profileType == 'autism'
                  ? 'A router emits electromagnetic waves at 2.4GHz or 5GHz frequencies to transmit binary data.'
                  : 'Think of Wi-Fi like a walkie-talkie. Your phone talks to the router using radio waves instead of sound waves!',
              type: profileType == 'autism' ? 'literal_fact' : 'analogy',
            ),
          ],
          flashcard: profileType == 'adhd'
              ? Flashcard(
                  question: 'What type of waves does Wi-Fi use?',
                  answer: 'Radio Waves! 📻',
                )
              : null,
        ),
        LessonModule(
          title: 'The Router (The Boss)',
          description: 'The traffic cop of your home network.',
          sections: [
            ModuleSection(
              heading: 'How it connects',
              text: 'The router is physically connected to the internet via a modem and a cable in your wall. '
                  'It takes the internet from that wire and broadcasts it wirelessly to the room.',
              type: 'literal_fact',
            ),
          ],
          flashcard: profileType == 'adhd'
              ? Flashcard(
                  question: 'What connects your wireless devices to the actual cable in the wall?',
                  answer: 'The Router!',
                )
              : null,
        )
      ],
    );
  }
}
