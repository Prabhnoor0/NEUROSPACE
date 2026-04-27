import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:neurospace/screens/settings_screen.dart';
import 'package:neurospace/providers/neuro_theme_provider.dart';

void main() {
  testWidgets('SettingsScreen displays sliders and toggles', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => NeuroThemeProvider()),
        ],
        child: const MaterialApp(
          home: SettingsScreen(),
        ),
      ),
    );

    // Verify app bar title
    expect(find.text('Accessibility Settings'), findsOneWidget);

    // Verify key fields are present
    expect(find.text('Font Size'), findsOneWidget);
    expect(find.text('Dyslexia-friendly Font'), findsOneWidget);
    expect(find.text('Speech Speed'), findsOneWidget);
    expect(find.text('Focus Mode'), findsOneWidget);

    // Try finding one of the Sliders
    expect(find.byType(Slider), findsWidgets);
    
    // Try finding one of the Switches
    expect(find.byType(Switch), findsWidgets);
  });
}
