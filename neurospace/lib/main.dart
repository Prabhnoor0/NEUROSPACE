import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'firebase_options.dart';
import 'providers/neuro_theme_provider.dart';
import 'providers/bubble_provider.dart';
import 'screens/splash_screen.dart';
import 'screens/overlay_screen.dart';
import 'screens/reader_screen.dart';
import 'widgets/global_bubble.dart';
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
  bool firebaseReady = false;

  // Initialize Firebase with generated config
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    ).timeout(const Duration(seconds: 5));
    firebaseReady = true;
  } catch (e) {
    // App already initialized or timed out — continue anyway
    debugPrint('Firebase init: $e');
  }

  // Sign in anonymously (creates a persistent user ID) - don't block app startup
  if (firebaseReady) {
    try {
      await FirebaseService.ensureAuthenticated()
          .timeout(const Duration(seconds: 5));
    } catch (e) {
      debugPrint('Firebase auth: $e');
    }
  } else {
    debugPrint('Firebase auth skipped: Firebase not initialized for this platform.');
  }

  runApp(const NeuroSpaceApp());
}

class NeuroSpaceApp extends StatelessWidget {
  const NeuroSpaceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => NeuroThemeProvider()..loadSavedProfile(),
        ),
        ChangeNotifierProvider(
          create: (_) => BubbleProvider(),
        ),
      ],
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
              // Use a builder to inject the global bubble ABOVE the Navigator
              // so it persists across all screen navigations.
              builder: (context, child) {
                return Stack(
                  children: [
                    child!,
                    // Global Accessibility Bubble — always on top
                    const GlobalAccessibilityBubble(),
                  ],
                );
              },
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
    // Listen for data shared from the overlay (Android only)
    if (!kIsWeb && Platform.isAndroid) {
      try {
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
      } catch (_) {
        // Overlay not supported on this platform
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return const SplashScreen();
  }
}
