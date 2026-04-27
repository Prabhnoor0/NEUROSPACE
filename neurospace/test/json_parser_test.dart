import 'package:flutter_test/flutter_test.dart';
import 'package:neurospace/models/lesson.dart';

void main() {
  group('DeepDiveLesson JSON Parsing', () {
    test('parses unified schema successfully', () {
      final Map<String, dynamic> mockJson = {
        'title': 'Test Lesson',
        'summary': 'This is a summary',
        'key_points': ['Point 1', 'Point 2'],
        'modules': [
          {
            'type': 'text_block',
            'content': 'Hello World',
            'section_type': 'explanation'
          }
        ],
        'wikipedia_links': [
          {'title': 'Wiki', 'url': 'https://wikipedia.org'}
        ],
        'interactive': {
          'quiz': [
            {
              'question': 'Is this a test?',
              'options': ['Yes', 'No'],
              'answer': 'Yes'
            }
          ],
          'questions': ['Why are we testing?']
        },
        'accessibility': {
          'simplified_text': 'Simple test',
          'audio_script': 'Audio test'
        },
        'tts_text': 'TTS test',
      };

      final lesson = DeepDiveLesson.fromJson(mockJson);

      expect(lesson.topic, 'Test Lesson');
      expect(lesson.keyPoints.length, 2);
      expect(lesson.keyPoints[0], 'Point 1');
      expect(lesson.modules.length, 1);
      expect(lesson.modules[0].sections[0].text, 'Hello World');
      expect(lesson.wikipediaLinks.length, 1);
      expect(lesson.wikipediaLinks[0].title, 'Wiki');
      expect(lesson.quizQuestions.length, 1);
      expect(lesson.quizQuestions[0].answer, 'Yes');
      expect(lesson.accessibility?.simplifiedText, 'Simple test');
    });

    test('handles missing optional fields gracefully', () {
      final Map<String, dynamic> minimalJson = {
        'title': 'Minimal Lesson',
      };

      final lesson = DeepDiveLesson.fromJson(minimalJson);

      expect(lesson.topic, 'Minimal Lesson');
      expect(lesson.keyPoints, isEmpty);
      expect(lesson.modules, isEmpty);
      expect(lesson.wikipediaLinks, isEmpty);
      expect(lesson.quizQuestions, isEmpty);
      expect(lesson.accessibility, isNull);
    });
  });
}
