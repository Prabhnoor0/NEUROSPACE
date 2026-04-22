import 'package:flutter_test/flutter_test.dart';
import 'package:neurospace/main.dart';

void main() {
  testWidgets('NeuroSpace app starts', (WidgetTester tester) async {
    await tester.pumpWidget(const NeuroSpaceApp());
    // Verify the splash screen loads
    expect(find.text('NeuroSpace'), findsOneWidget);
  });
}
