enum AssistantContentSource {
  clipboard,
  accessibilityScreen,
  ocr,
  sharedText,
  pastedText,
  unknown,
}

class AssistantContentPayload {
  final String text;
  final AssistantContentSource source;
  final DateTime capturedAt;
  final Map<String, dynamic> meta;

  const AssistantContentPayload({
    required this.text,
    required this.source,
    required this.capturedAt,
    this.meta = const {},
  });

  bool get hasEnoughText => text.trim().length >= 5;

  AssistantContentPayload copyWith({
    String? text,
    AssistantContentSource? source,
    DateTime? capturedAt,
    Map<String, dynamic>? meta,
  }) {
    return AssistantContentPayload(
      text: text ?? this.text,
      source: source ?? this.source,
      capturedAt: capturedAt ?? this.capturedAt,
      meta: meta ?? this.meta,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'text': text,
      'source': source.name,
      'captured_at': capturedAt.toIso8601String(),
      'meta': meta,
    };
  }

  static AssistantContentPayload empty({
    AssistantContentSource source = AssistantContentSource.unknown,
  }) {
    return AssistantContentPayload(
      text: '',
      source: source,
      capturedAt: DateTime.now(),
      meta: const {},
    );
  }
}
