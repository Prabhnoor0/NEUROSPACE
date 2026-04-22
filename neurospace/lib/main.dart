import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'firebase_options.dart';
import 'providers/neuro_theme_provider.dart';
import 'screens/splash_screen.dart';
import 'screens/overlay_screen.dart';
import 'screens/reader_screen.dart';
import 'services/firebase_service.dart';

@pragma("vm:entry-point")
void overlayMain() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      home: const OverlayScreen(),
    ),
  );
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase with generated config
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Sign in anonymously (creates a persistent user ID)
  await FirebaseService.ensureAuthenticated();

  runApp(const NeuroSpaceApp());
}

class NeuroSpaceApp extends StatelessWidget {
  const NeuroSpaceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => NeuroThemeProvider()..loadSavedProfile(),
      child: Consumer<NeuroThemeProvider>(
        builder: (context, themeProvider, _) {
          return AnimatedTheme(
            data: themeProvider.themeData,
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeInOut,
            child: MaterialApp(
              title: 'NeuroSpace',
              debugShowCheckedModeBanner: false,
              theme: themeProvider.themeData,
              home: const _AppShell(),
            ),
          );
        },
      ),
    );
  }
}

/// Wrapper that listens for overlay messages (e.g. "Open in NeuroSpace" action)
/// and navigates to the Reader screen with the shared text.
class _AppShell extends StatefulWidget {
  const _AppShell();

  @override
  State<_AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<_AppShell> {
  @override
  void initState() {
    super.initState();
    // Listen for data shared from the overlay
    FlutterOverlayWindow.overlayListener.listen((event) {
      if (event is String && event.startsWith('open_reader:')) {
        final text = event.substring('open_reader:'.length);
        if (text.isNotEmpty && mounted) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ReaderScreen(
                title: 'Shared Text',
                content: text,
              ),
            ),
          );
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return const SplashScreen();
  }
}
