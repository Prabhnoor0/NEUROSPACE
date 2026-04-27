import 'package:flutter_test/flutter_test.dart';
import 'package:neurospace/models/assistant_content_payload.dart';
import 'package:neurospace/services/assistant_action_engine.dart';
import 'package:neurospace/services/assistant_content_service.dart';

void main() {
  group('AssistantContentService', () {
    final service = AssistantContentService();

    test('normalize trims and collapses whitespace', () {
      final payload = service.normalize(
        rawText: '  Hello   world\n\nthis   is  NeuroSpace  ',
        source: AssistantContentSource.clipboard,
      );

      expect(payload.text, 'Hello world this is NeuroSpace');
      expect(payload.source, AssistantContentSource.clipboard);
      expect(payload.hasEnoughText, isTrue);
    });

    test('empty payload is flagged as insufficient text', () {
      final payload = AssistantContentPayload.empty();
      expect(payload.hasEnoughText, isFalse);
    });
  });

  group('AssistantActionEngine', () {
    const engine = AssistantActionEngine();

    test('easyRead returns bullet formatted text', () {
      final payload = AssistantContentPayload(
        text: 'NeuroSpace helps users learn. It simplifies complex text.',
        source: AssistantContentSource.pastedText,
        capturedAt: DateTime.now(),
      );

      final result = engine.easyRead(payload);
      expect(result.success, isTrue);
      expect(result.primaryText.contains('•'), isTrue);
      expect(result.action, AssistantActionType.easyRead);
    });
  });
}
