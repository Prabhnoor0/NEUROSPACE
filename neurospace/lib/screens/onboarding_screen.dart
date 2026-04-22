// NeuroSpace — Morphing Onboarding Screen
// The app's first impression. As users tap traits, the entire UI
// morphs in real-time: fonts shift, colors cross-fade, spacing adjusts.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../providers/neuro_theme_provider.dart';
import '../models/neuro_profile.dart';
import 'dashboard_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  late AnimationController _bgController;
  int _currentPage = 0; // 0 = traits, 1 = preview/confirm

  @override
  void initState() {
    super.initState();
    _bgController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _bgController.dispose();
    super.dispose();
  }

  void _goToConfirm() {
    setState(() => _currentPage = 1);
  }

  void _goBack() {
    setState(() => _currentPage = 0);
  }

  void _completeOnboarding(BuildContext context) {
    final themeProvider =
        Provider.of<NeuroThemeProvider>(context, listen: false);
    themeProvider.completeOnboarding();
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const DashboardScreen(),
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(
            opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 800),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<NeuroThemeProvider>(context);
    final profile = themeProvider.activeProfile;

    return Scaffold(
      body: AnimatedContainer(
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOut,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              profile.backgroundColor,
              Color.lerp(
                    profile.backgroundColor,
                    profile.accentColor,
                    0.08,
                  ) ??
                  profile.backgroundColor,
              profile.backgroundColor,
            ],
          ),
        ),
        child: SafeArea(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 500),
            transitionBuilder: (child, animation) {
              return SlideTransition(
                position: Tween<Offset>(
                  begin: _currentPage == 1
                      ? const Offset(1.0, 0.0)
                      : const Offset(-1.0, 0.0),
                  end: Offset.zero,
                ).animate(CurvedAnimation(
                  parent: animation,
                  curve: Curves.easeOutCubic,
                )),
                child: FadeTransition(opacity: animation, child: child),
              );
            },
            child: _currentPage == 0
                ? _TraitsPage(
                    key: const ValueKey('traits'),
                    onContinue: _goToConfirm,
                  )
                : _ConfirmPage(
                    key: const ValueKey('confirm'),
                    onBack: _goBack,
                    onComplete: () => _completeOnboarding(context),
                  ),
          ),
        ),
      ),
    );
  }
}

// ============================================
// Page 1: Trait Selection
// ============================================

class _TraitsPage extends StatelessWidget {
  final VoidCallback onContinue;

  const _TraitsPage({super.key, required this.onContinue});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<NeuroThemeProvider>(context);
    final profile = themeProvider.activeProfile;
    final hasSelection = themeProvider.selectedTraits.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 32),

          // Logo + Title
          Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 400),
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      profile.accentColor,
                      profile.accentColor.withValues(alpha: 0.6),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: profile.accentColor.withValues(alpha: 0.25),
                      blurRadius: 16,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.psychology_rounded,
                  color: Colors.white,
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 400),
                  style: TextStyle(
                    fontFamily: profile.fontFamily,
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: profile.textColor,
                    letterSpacing: profile.letterSpacing,
                  ),
                  child: const Text('NeuroSpace'),
                ),
              ),
            ],
          )
              .animate()
              .fadeIn(duration: 600.ms, curve: Curves.easeOut)
              .slideY(begin: -0.3, end: 0, duration: 600.ms),

          const SizedBox(height: 28),

          // Subtitle
          AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 400),
            style: TextStyle(
              fontFamily: profile.fontFamily,
              fontSize: profile.fontSize + 6,
              fontWeight: FontWeight.w700,
              color: profile.textColor,
              letterSpacing: profile.letterSpacing,
              height: profile.lineHeight,
            ),
            child: const Text('How does your\nbrain work best?'),
          )
              .animate()
              .fadeIn(delay: 200.ms, duration: 500.ms)
              .slideY(begin: 0.2, end: 0, duration: 500.ms),

          const SizedBox(height: 6),

          AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 400),
            style: TextStyle(
              fontFamily: profile.fontFamily,
              fontSize: profile.fontSize - 2,
              color: profile.textColor.withValues(alpha: 0.5),
              letterSpacing: profile.letterSpacing,
              height: profile.lineHeight,
            ),
            child: const Text('Tap what feels right. Watch the app adapt.'),
          )
              .animate()
              .fadeIn(delay: 350.ms, duration: 500.ms),

          const SizedBox(height: 28),

          // Trait Cards
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                children: [
                  _AnimatedTraitCard(
                    traitKey: 'lose_focus',
                    icon: '⚡',
                    title: 'I lose focus easily',
                    subtitle: 'Gamified, bite-sized cards with quizzes',
                    profileHint: 'ADHD Optimized',
                    delay: 400,
                  ),
                  const SizedBox(height: 12),
                  _AnimatedTraitCard(
                    traitKey: 'dense_text',
                    icon: '📖',
                    title: 'Dense text makes me dizzy',
                    subtitle: 'Larger fonts, wider spacing, audio-first',
                    profileHint: 'Dyslexia Optimized',
                    delay: 500,
                  ),
                  const SizedBox(height: 12),
                  _AnimatedTraitCard(
                    traitKey: 'bright_lights',
                    icon: '🔆',
                    title: 'Bright lights hurt my eyes',
                    subtitle: 'Low-contrast, calming color palette',
                    profileHint: 'Sensory Friendly',
                    delay: 600,
                  ),
                  const SizedBox(height: 12),
                  _AnimatedTraitCard(
                    traitKey: 'literal_explanations',
                    icon: '🧩',
                    title: 'I need literal explanations',
                    subtitle: 'Structured, step-by-step, no metaphors',
                    profileHint: 'Autism Optimized',
                    delay: 700,
                  ),
                  const SizedBox(height: 80), // Space for button
                ],
              ),
            ),
          ),

          // Continue Button
          AnimatedOpacity(
            duration: const Duration(milliseconds: 300),
            opacity: hasSelection ? 1.0 : 0.4,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 400),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: LinearGradient(
                      colors: [
                        profile.accentColor,
                        profile.accentColor.withValues(alpha: 0.7),
                      ],
                    ),
                    boxShadow: hasSelection
                        ? [
                            BoxShadow(
                              color: profile.accentColor.withValues(alpha: 0.3),
                              blurRadius: 16,
                              offset: const Offset(0, 4),
                            ),
                          ]
                        : [],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: hasSelection ? onContinue : null,
                      child: Center(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'See my NeuroSpace',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                                fontFamily: profile.fontFamily,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(width: 10),
                            const Icon(Icons.arrow_forward_rounded,
                                color: Colors.white, size: 22),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          )
              .animate()
              .fadeIn(delay: 900.ms, duration: 500.ms)
              .slideY(begin: 0.5, end: 0, delay: 900.ms, duration: 500.ms),
        ],
      ),
    );
  }
}

// ============================================
// Animated Trait Card
// ============================================

class _AnimatedTraitCard extends StatelessWidget {
  final String traitKey;
  final String icon;
  final String title;
  final String subtitle;
  final String profileHint;
  final int delay;

  const _AnimatedTraitCard({
    required this.traitKey,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.profileHint,
    required this.delay,
  });

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<NeuroThemeProvider>(context);
    final profile = themeProvider.activeProfile;
    final isSelected = themeProvider.selectedTraits.contains(traitKey);

    return GestureDetector(
      onTap: () => themeProvider.toggleTrait(traitKey),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: isSelected
              ? profile.accentColor.withValues(alpha: 0.12)
              : profile.cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? profile.accentColor
                : profile.cardColor.withValues(alpha: 0.3),
            width: isSelected ? 2.0 : 1.0,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: profile.accentColor.withValues(alpha: 0.15),
                    blurRadius: 20,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [],
        ),
        child: Row(
          children: [
            // Emoji icon with animated scale
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: isSelected
                    ? profile.accentColor.withValues(alpha: 0.15)
                    : profile.backgroundColor.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(
                child: AnimatedScale(
                  scale: isSelected ? 1.2 : 1.0,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.elasticOut,
                  child: Text(icon, style: const TextStyle(fontSize: 26)),
                ),
              ),
            ),
            const SizedBox(width: 14),

            // Text content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 400),
                    style: TextStyle(
                      fontFamily: profile.fontFamily,
                      fontSize: profile.fontSize - 1,
                      fontWeight: FontWeight.w700,
                      color: profile.textColor,
                      letterSpacing: profile.letterSpacing,
                    ),
                    child: Text(title),
                  ),
                  const SizedBox(height: 3),
                  AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 400),
                    style: TextStyle(
                      fontFamily: profile.fontFamily,
                      fontSize: profile.fontSize - 4,
                      color: profile.textColor.withValues(alpha: 0.5),
                      letterSpacing: profile.letterSpacing,
                      height: 1.3,
                    ),
                    child: Text(subtitle),
                  ),
                  if (isSelected) ...[
                    const SizedBox(height: 6),
                    AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 300),
                      style: TextStyle(
                        fontFamily: profile.fontFamily,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: profile.accentColor,
                        letterSpacing: 1.0,
                      ),
                      child: Text(profileHint.toUpperCase()),
                    ),
                  ],
                ],
              ),
            ),

            // Checkbox indicator
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? profile.accentColor : Colors.transparent,
                border: Border.all(
                  color: isSelected
                      ? profile.accentColor
                      : profile.textColor.withValues(alpha: 0.2),
                  width: 2,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: profile.accentColor.withValues(alpha: 0.3),
                          blurRadius: 8,
                        ),
                      ]
                    : [],
              ),
              child: isSelected
                  ? const Icon(Icons.check_rounded, size: 18, color: Colors.white)
                  : null,
            ),
          ],
        ),
      ),
    )
        .animate()
        .fadeIn(delay: Duration(milliseconds: delay), duration: 400.ms)
        .slideX(
          begin: 0.15,
          end: 0,
          delay: Duration(milliseconds: delay),
          duration: 400.ms,
          curve: Curves.easeOutCubic,
        );
  }
}

// ============================================
// Page 2: Preview & Confirm
// ============================================

class _ConfirmPage extends StatelessWidget {
  final VoidCallback onBack;
  final VoidCallback onComplete;

  const _ConfirmPage({
    super.key,
    required this.onBack,
    required this.onComplete,
  });

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<NeuroThemeProvider>(context);
    final profile = themeProvider.activeProfile;
    final profileName = profile.profileType.name.toUpperCase();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 32),

          // Back button
          GestureDetector(
            onTap: onBack,
            child: Row(
              children: [
                Icon(Icons.arrow_back_rounded,
                    color: profile.textColor.withValues(alpha: 0.6), size: 22),
                const SizedBox(width: 8),
                AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 400),
                  style: TextStyle(
                    fontFamily: profile.fontFamily,
                    fontSize: 15,
                    color: profile.textColor.withValues(alpha: 0.6),
                  ),
                  child: const Text('Change traits'),
                ),
              ],
            ),
          ),

          const SizedBox(height: 28),

          // Title
          AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 400),
            style: TextStyle(
              fontFamily: profile.fontFamily,
              fontSize: profile.fontSize + 8,
              fontWeight: FontWeight.w800,
              color: profile.textColor,
              letterSpacing: profile.letterSpacing,
              height: profile.lineHeight,
            ),
            child: const Text('Your NeuroSpace\nis ready ✨'),
          )
              .animate()
              .fadeIn(duration: 500.ms)
              .slideY(begin: 0.2, end: 0, duration: 500.ms),

          const SizedBox(height: 24),

          // Profile badge
          AnimatedContainer(
            duration: const Duration(milliseconds: 400),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: profile.accentColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: profile.accentColor.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.auto_awesome_rounded,
                    color: profile.accentColor, size: 18),
                const SizedBox(width: 8),
                AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 400),
                  style: TextStyle(
                    fontFamily: profile.fontFamily,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: profile.accentColor,
                    letterSpacing: 1.5,
                  ),
                  child: Text('$profileName PROFILE'),
                ),
              ],
            ),
          )
              .animate()
              .fadeIn(delay: 200.ms, duration: 400.ms)
              .scale(begin: const Offset(0.9, 0.9), end: const Offset(1.0, 1.0),
                  delay: 200.ms, duration: 400.ms),

          const SizedBox(height: 28),

          // Live Preview Card
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _PreviewCard(
                    title: '🔤 Typography',
                    items: [
                      _PreviewItem('Font', profile.fontFamily),
                      _PreviewItem('Size', '${profile.fontSize.toInt()}px'),
                      _PreviewItem(
                          'Spacing', '${profile.letterSpacing.toStringAsFixed(1)}'),
                      _PreviewItem(
                          'Line Height', '${profile.lineHeight.toStringAsFixed(1)}x'),
                    ],
                    delay: 300,
                  ),
                  const SizedBox(height: 14),
                  _PreviewCard(
                    title: '🎨 Colors',
                    items: [
                      _PreviewItem(
                          'Contrast', profile.contrastMode.name.toUpperCase()),
                      _PreviewItem('Focus Borders',
                          profile.focusBordersEnabled ? 'ON' : 'OFF'),
                    ],
                    colorPreview: [
                      profile.backgroundColor,
                      profile.cardColor,
                      profile.accentColor,
                      profile.definitionColor,
                      profile.exampleColor,
                    ],
                    delay: 400,
                  ),
                  const SizedBox(height: 14),
                  _PreviewCard(
                    title: '🔊 Audio',
                    items: [
                      _PreviewItem('TTS Speed', '${profile.ttsSpeed}x'),
                      _PreviewItem(
                          'Auto-play',
                          profile.profileType == NeuroProfileType.dyslexia
                              ? 'ON'
                              : 'OFF'),
                    ],
                    delay: 500,
                  ),
                  const SizedBox(height: 14),

                  // Live text preview
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 400),
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: profile.cardColor,
                      borderRadius: BorderRadius.circular(20),
                      border: profile.focusBordersEnabled
                          ? Border.all(
                              color: profile.accentColor.withValues(alpha: 0.3),
                              width: 1.5,
                            )
                          : null,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 400),
                          style: TextStyle(
                            fontFamily: profile.fontFamily,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: profile.textColor.withValues(alpha: 0.4),
                            letterSpacing: 1.5,
                          ),
                          child: const Text('LIVE PREVIEW'),
                        ),
                        const SizedBox(height: 12),
                        AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 400),
                          style: TextStyle(
                            fontFamily: profile.fontFamily,
                            fontSize: profile.fontSize + 2,
                            fontWeight: FontWeight.w700,
                            color: profile.textColor,
                            letterSpacing: profile.letterSpacing,
                            height: profile.lineHeight,
                          ),
                          child: const Text('How does Wi-Fi work?'),
                        ),
                        const SizedBox(height: 10),
                        AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 400),
                          style: TextStyle(
                            fontFamily: profile.fontFamily,
                            fontSize: profile.fontSize,
                            color: profile.textColor.withValues(alpha: 0.8),
                            letterSpacing: profile.letterSpacing,
                            height: profile.lineHeight,
                          ),
                          child: const Text(
                            'Wi-Fi uses radio waves to send data between '
                            'your device and a router. The router connects to '
                            'the internet through a cable.',
                          ),
                        ),
                      ],
                    ),
                  )
                      .animate()
                      .fadeIn(delay: 600.ms, duration: 500.ms),

                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),

          // Start button
          Padding(
            padding: const EdgeInsets.only(bottom: 24),
            child: SizedBox(
              width: double.infinity,
              height: 58,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 400),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: LinearGradient(
                    colors: [
                      profile.accentColor,
                      profile.accentColor.withValues(alpha: 0.7),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: profile.accentColor.withValues(alpha: 0.35),
                      blurRadius: 20,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: onComplete,
                    child: Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.rocket_launch_rounded,
                              color: Colors.white, size: 22),
                          const SizedBox(width: 10),
                          Text(
                            'Enter NeuroSpace',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              fontFamily: profile.fontFamily,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          )
              .animate()
              .fadeIn(delay: 800.ms, duration: 500.ms)
              .slideY(begin: 0.4, end: 0, delay: 800.ms, duration: 500.ms),
        ],
      ),
    );
  }
}

// ============================================
// Preview Card Widget
// ============================================

class _PreviewCard extends StatelessWidget {
  final String title;
  final List<_PreviewItem> items;
  final List<Color>? colorPreview;
  final int delay;

  const _PreviewCard({
    required this.title,
    required this.items,
    this.colorPreview,
    required this.delay,
  });

  @override
  Widget build(BuildContext context) {
    final profile =
        Provider.of<NeuroThemeProvider>(context).activeProfile;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: profile.cardColor,
        borderRadius: BorderRadius.circular(18),
        border: profile.focusBordersEnabled
            ? Border.all(
                color: profile.accentColor.withValues(alpha: 0.2),
                width: 1,
              )
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 400),
            style: TextStyle(
              fontFamily: profile.fontFamily,
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: profile.textColor,
              letterSpacing: profile.letterSpacing,
            ),
            child: Text(title),
          ),
          const SizedBox(height: 12),
          ...items.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 400),
                      style: TextStyle(
                        fontFamily: profile.fontFamily,
                        fontSize: 13,
                        color: profile.textColor.withValues(alpha: 0.5),
                      ),
                      child: Text(item.label),
                    ),
                    AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 400),
                      style: TextStyle(
                        fontFamily: profile.fontFamily,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: profile.textColor.withValues(alpha: 0.9),
                      ),
                      child: Text(item.value),
                    ),
                  ],
                ),
              )),
          if (colorPreview != null) ...[
            const SizedBox(height: 8),
            Row(
              children: colorPreview!.map((color) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 400),
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: profile.textColor.withValues(alpha: 0.15),
                        width: 1,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    )
        .animate()
        .fadeIn(
          delay: Duration(milliseconds: delay),
          duration: 400.ms,
        )
        .slideY(
          begin: 0.15,
          end: 0,
          delay: Duration(milliseconds: delay),
          duration: 400.ms,
          curve: Curves.easeOutCubic,
        );
  }
}

class _PreviewItem {
  final String label;
  final String value;
  const _PreviewItem(this.label, this.value);
}
