import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../providers/neuro_theme_provider.dart';

class PanicScreen extends StatefulWidget {
  const PanicScreen({super.key});

  @override
  State<PanicScreen> createState() => _PanicScreenState();
}

class _PanicScreenState extends State<PanicScreen> {
  int _currentStep = 0;

  final List<Map<String, dynamic>> _groundingSteps = [
    {
      'title': 'Breathe.',
      'subtitle': 'You are safe. Tap anywhere to begin.',
      'icon': Icons.air_rounded,
      'color': const Color(0xFF64B5F6), // Soft calm blue
    },
    {
      'title': 'Look around.',
      'subtitle': 'Find 5 things you can see.\nSay them out loud.',
      'icon': Icons.visibility_rounded,
      'color': const Color(0xFF81C784),
    },
    {
      'title': 'Reach out.',
      'subtitle': 'Find 4 things you can physically feel.\nWhat is their texture?',
      'icon': Icons.back_hand_rounded,
      'color': const Color(0xFFFFB74D),
    },
    {
      'title': 'Listen closely.',
      'subtitle': 'Find 3 things you can hear right now.\nA car? A fridge hum?',
      'icon': Icons.hearing_rounded,
      'color': const Color(0xFFBA68C8),
    },
    {
      'title': 'Take a breath in.',
      'subtitle': 'Find 2 things you can smell.',
      'icon': Icons.spa_rounded,
      'color': const Color(0xFF4DB6AC),
    },
    {
      'title': 'Notice your taste.',
      'subtitle': 'Find 1 thing you can taste.\nEven just the inside of your mouth.',
      'icon': Icons.restaurant_rounded,
      'color': const Color(0xFFE57373),
    },
    {
      'title': 'You are grounded.',
      'subtitle': 'You made it through. You are back in your body.',
      'icon': Icons.favorite_rounded,
      'color': const Color(0xFF64B5F6),
    },
  ];

  void _nextStep() {
    if (_currentStep < _groundingSteps.length - 1) {
      setState(() {
        _currentStep++;
      });
    }
  }

  void _exit() {
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    // We intentionally force a dark, low-sensory environment regardless of the user's Theme profile.
    final fontFamily = Provider.of<NeuroThemeProvider>(context, listen: false).activeProfile.fontFamily;
    final step = _groundingSteps[_currentStep];

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A), // Near pitch-black to reduce light sensitivity
      body: GestureDetector(
        onTap: _nextStep,
        behavior: HitTestBehavior.opaque, // Entire screen is tappable
        child: Stack(
          children: [
            // Ambient animated pulse
            Center(
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: step['color'].withValues(alpha: 0.1),
                  boxShadow: [
                    BoxShadow(
                      color: step['color'].withValues(alpha: 0.05),
                      blurRadius: 100,
                      spreadRadius: 50,
                    )
                  ],
                ),
              )
              .animate(onPlay: (controller) => controller.repeat(reverse: true))
              .scale(begin: const Offset(0.8, 0.8), end: const Offset(1.2, 1.2), duration: 5000.ms, curve: Curves.easeInOutSine),
            ),
            
            // Core Content
            SafeArea(
              child: Column(
                children: [
                  // Exit button
                  Align(
                    alignment: Alignment.topLeft,
                    child: IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.white30, size: 32),
                      onPressed: _exit,
                    ),
                  ),
                  
                  const Spacer(),
                  
                  // Main Icon
                  Icon(
                    step['icon'],
                    color: step['color'],
                    size: 80,
                  )
                  .animate(key: ValueKey(_currentStep))
                  .fadeIn(duration: 800.ms)
                  .slideY(begin: 0.2, end: 0, curve: Curves.easeOut),
                  
                  const SizedBox(height: 40),
                  
                  // Title
                  Text(
                    step['title'],
                    style: TextStyle(
                      fontFamily: fontFamily,
                      fontSize: 36,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  )
                  .animate(key: ValueKey('t_$_currentStep'))
                  .fadeIn(delay: 200.ms, duration: 800.ms),
                  
                  const SizedBox(height: 20),
                  
                  // Subtitle
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32.0),
                    child: Text(
                      step['subtitle'],
                      style: TextStyle(
                        fontFamily: fontFamily,
                        fontSize: 20,
                        fontWeight: FontWeight.w500,
                        color: Colors.white70,
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  )
                  .animate(key: ValueKey('s_$_currentStep'))
                  .fadeIn(delay: 600.ms, duration: 800.ms),
                  
                  const Spacer(),
                  
                  // Action Hint
                  if (_currentStep < _groundingSteps.length - 1)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 32.0),
                      child: Text(
                        'Tap anywhere to continue',
                        style: TextStyle(
                          fontFamily: fontFamily,
                          fontSize: 14,
                          color: Colors.white24,
                          letterSpacing: 1.2,
                        ),
                      )
                      .animate(onPlay: (controller) => controller.repeat(reverse: true))
                      .fadeIn(duration: 2000.ms),
                    ),
                  
                  if (_currentStep == _groundingSteps.length - 1)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 32.0),
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: step['color'],
                          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                        ),
                        onPressed: _exit,
                        child: Text(
                          'Return to Dashboard',
                          style: TextStyle(
                            fontFamily: fontFamily,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF0A0A0A),
                          ),
                        ),
                      )
                      .animate()
                      .fadeIn(delay: 1000.ms),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
