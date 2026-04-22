/// NeuroSpace — Lesson Models
/// Defines the structured JSON syllabus that the backend AI generates.

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
    return LessonModule(
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      sections: (json['sections'] as List?)
              ?.map((e) => ModuleSection.fromJson(e))
              .toList() ??
          [],
      flashcard: json['flashcard'] != null
          ? Flashcard.fromJson(json['flashcard'])
          : null,
    );
  }
}

class ModuleSection {
  final String heading;
  final String text;
  final String type; // 'definition', 'example', 'analogy', 'literal_fact'
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

class DeepDiveLesson {
  final String topic;
  final String targetProfile;
  final List<LessonModule> modules;

  DeepDiveLesson({
    required this.topic,
    required this.targetProfile,
    required this.modules,
  });

  factory DeepDiveLesson.fromJson(Map<String, dynamic> json) {
    return DeepDiveLesson(
      topic: json['topic'] ?? '',
      targetProfile: json['target_profile'] ?? 'custom',
      modules: (json['modules'] as List?)
              ?.map((e) => LessonModule.fromJson(e))
              .toList() ??
          [],
    );
  }
}

// ==========================================
// MOCK DATA GENERATOR
// ==========================================

class MockLessonGenerator {
  static DeepDiveLesson getMockLesson(String profileType) {
    // Generate a different mock lesson layout depending on the exact profile asked for
    return DeepDiveLesson(
      topic: 'How Wi-Fi Works',
      targetProfile: profileType,
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
              : null, // Flashcards mainly used for ADHD dopamine
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
