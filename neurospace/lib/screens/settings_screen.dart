/// NeuroSpace — Settings Screen
/// Provides accessibility controls: font size, line spacing, letter spacing,
/// dark mode toggle, accent color picker, dyslexic font toggle,
/// focus mode, reduce motion, high contrast, and TTS speed.
/// All changes apply live via NeuroThemeProvider.

import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/neuro_theme_provider.dart';
import '../models/neuro_profile.dart';
import '../services/android_assistant_bridge.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late double _fontSize;
  late double _ttsSpeed;
  late double _lineHeight;
  late double _letterSpacing;
  late bool _useDyslexicFont;
  late bool _focusMode;
  late bool _reduceMotion;
  late bool _highContrast;
  late bool _darkMode;
  late int _accentColorIndex;
  late String _language;
  late String _simplificationLevel;
  final TextEditingController _emergencyContactController =
      TextEditingController();

  // Cached overlay states (Android only)
  bool _overlayPermissionGranted = false;
  bool _accessibilityEnabled = false;
  bool _overlayActive = false;

  // Accent color palette
  static const List<Color> _accentColors = [
    Color(0xFF7C4DFF), // Purple (default ADHD)
    Color(0xFF00BCD4), // Cyan
    Color(0xFF4285F4), // Blue
    Color(0xFF4CAF50), // Green
    Color(0xFFFFA726), // Orange
    Color(0xFFEF5350), // Red
    Color(0xFFEC407A), // Pink
    Color(0xFF26C6DA), // Teal
    Color(0xFFFFD54F), // Amber
    Color(0xFF42A5F5), // Light Blue
  ];

  static const List<String> _languageOptions = [
    'English',
    'Hindi',
    'Punjabi',
  ];

  static const List<String> _simplificationOptions = [
    'Simple',
    'Very Simple',
    'Child Friendly',
    'Exam Friendly',
    'Bullet Summary',
  ];

  @override
  void initState() {
    super.initState();
    final provider = Provider.of<NeuroThemeProvider>(context, listen: false);
    final profile = provider.activeProfile;
    _fontSize = profile.fontSize;
    _ttsSpeed = profile.ttsSpeed;
    _lineHeight = profile.lineHeight;
    _letterSpacing = profile.letterSpacing;
    _useDyslexicFont = profile.fontFamily == 'OpenDyslexic';
    _focusMode = profile.focusBordersEnabled;
    _reduceMotion = false;
    _highContrast = profile.contrastMode == ContrastMode.high;
    _darkMode = _isDarkBackground(profile.backgroundColor);
    _accentColorIndex = _findClosestColor(profile.accentColor);
    _language = 'English';
    _simplificationLevel = 'Simple';

    _loadExtraPreferences();
    _refreshOverlayStates();
  }

  @override
  void dispose() {
    _emergencyContactController.dispose();
    super.dispose();
  }

  Future<void> _loadExtraPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;

    setState(() {
      _reduceMotion = prefs.getBool('reduce_motion') ?? _reduceMotion;
      _language = prefs.getString('preferred_language') ?? _language;
      _simplificationLevel =
          prefs.getString('simplification_level') ?? _simplificationLevel;
      _emergencyContactController.text =
          prefs.getString('emergency_contact') ?? '';
    });
  }

  Future<void> _saveExtraPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('reduce_motion', _reduceMotion);
    await prefs.setString('preferred_language', _language);
    await prefs.setString('simplification_level', _simplificationLevel);
    await prefs.setString(
      'emergency_contact',
      _emergencyContactController.text.trim(),
    );
  }

  /// Refresh overlay permission + active states (Android only)
  Future<void> _refreshOverlayStates() async {
    if (kIsWeb || !Platform.isAndroid) return;
    try {
      final perm = await AndroidAssistantBridge.isOverlayPermissionGranted();
      final acc = await AndroidAssistantBridge.isAccessibilityServiceEnabled();
      final active = await AndroidAssistantBridge.isOverlayActive();
      if (mounted) {
        setState(() {
          _overlayPermissionGranted = perm;
          _accessibilityEnabled = acc;
          _overlayActive = active;
        });
      }
    } catch (_) {}
  }

  bool _isDarkBackground(Color c) {
    return c.computeLuminance() < 0.3;
  }

  int _findClosestColor(Color target) {
    int closest = 0;
    double minDist = double.infinity;
    for (int i = 0; i < _accentColors.length; i++) {
      final dist = _colorDistance(target, _accentColors[i]);
      if (dist < minDist) {
        minDist = dist;
        closest = i;
      }
    }
    return closest;
  }

  double _colorDistance(Color a, Color b) {
    return ((a.red - b.red) * (a.red - b.red) +
            (a.green - b.green) * (a.green - b.green) +
            (a.blue - b.blue) * (a.blue - b.blue))
        .toDouble();
  }

  /// Apply all current settings to the theme provider
  void _applySettings() {
    final provider = Provider.of<NeuroThemeProvider>(context, listen: false);
    final current = provider.activeProfile;
    final accent = _accentColors[_accentColorIndex];

    final updated = NeuroProfile(
      profileType: current.profileType,
      fontFamily: _useDyslexicFont ? 'OpenDyslexic' : current.profileType == NeuroProfileType.adhd ? 'Inter' : current.profileType == NeuroProfileType.dyslexia ? 'OpenDyslexic' : 'Lexend',
      fontSize: _fontSize,
      letterSpacing: _letterSpacing,
      lineHeight: _lineHeight,
      backgroundColor: _darkMode
          ? const Color(0xFF0F0F1A)
          : const Color(0xFFFAFAF9),
      textColor: _darkMode
          ? const Color(0xFFF5F5F5)
          : const Color(0xFF1A1A1A),
      accentColor: accent,
      cardColor: _darkMode
          ? const Color(0xFF1E1E2E)
          : const Color(0xFFFFFFFF),
      definitionColor: current.definitionColor,
      exampleColor: current.exampleColor,
      ttsSpeed: _ttsSpeed,
      contrastMode: _highContrast ? ContrastMode.high : ContrastMode.normal,
      focusBordersEnabled: _focusMode,
      aiReasoning: current.aiReasoning,
    );

    provider.setProfile(updated);
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<NeuroThemeProvider>(context);
    final profile = themeProvider.activeProfile;

    return Scaffold(
      backgroundColor: profile.backgroundColor,
      appBar: AppBar(
        title: const Text('Accessibility Settings'),
        titleTextStyle: TextStyle(
          fontFamily: profile.fontFamily,
          fontSize: profile.fontSize + 2,
          fontWeight: FontWeight.w700,
          color: profile.textColor,
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: profile.textColor),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          // ──── Profile Info ────
          _buildSectionHeader('Current Profile', Icons.person_rounded, profile),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: profile.cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: profile.accentColor.withValues(alpha: 0.15),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: profile.accentColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    _getProfileIcon(profile.profileType),
                    color: profile.accentColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      profile.profileType.name.toUpperCase(),
                      style: TextStyle(
                        fontFamily: profile.fontFamily,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: profile.accentColor,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Personalized learning experience',
                      style: TextStyle(
                        fontFamily: profile.fontFamily,
                        fontSize: 13,
                        color: profile.textColor.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          // ════════════════════════════════════════
          //  APPEARANCE
          // ════════════════════════════════════════
          _buildSectionHeader(
              'Appearance', Icons.palette_rounded, profile),
          const SizedBox(height: 12),

          // Dark Mode Toggle
          _buildToggleCard(
            profile: profile,
            title: 'Dark Mode',
            subtitle: _darkMode ? 'Dark background' : 'Light background',
            icon: _darkMode
                ? Icons.dark_mode_rounded
                : Icons.light_mode_rounded,
            value: _darkMode,
            onChanged: (val) {
              setState(() => _darkMode = val);
              _applySettings();
            },
          ),

          const SizedBox(height: 12),

          // Accent Color Picker
          _buildSettingCard(
            profile: profile,
            title: 'Accent Color',
            subtitle: 'Tap to change',
            child: SizedBox(
              height: 44,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _accentColors.length,
                itemBuilder: (_, i) {
                  final isSelected = i == _accentColorIndex;
                  return GestureDetector(
                    onTap: () {
                      setState(() => _accentColorIndex = i);
                      _applySettings();
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 36,
                      height: 36,
                      margin: const EdgeInsets.only(right: 10),
                      decoration: BoxDecoration(
                        color: _accentColors[i],
                        shape: BoxShape.circle,
                        border: isSelected
                            ? Border.all(
                                color: profile.textColor, width: 3)
                            : null,
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: _accentColors[i].withOpacity(0.4),
                                  blurRadius: 10,
                                  spreadRadius: 2,
                                ),
                              ]
                            : null,
                      ),
                      child: isSelected
                          ? const Icon(Icons.check_rounded,
                              color: Colors.white, size: 18)
                          : null,
                    ),
                  );
                },
              ),
            ),
          ),

          const SizedBox(height: 12),

          // High Contrast Toggle
          _buildToggleCard(
            profile: profile,
            title: 'High Contrast',
            subtitle: 'Increase contrast for better readability',
            icon: Icons.contrast_rounded,
            value: _highContrast,
            onChanged: (val) {
              setState(() => _highContrast = val);
              _applySettings();
            },
          ),

          const SizedBox(height: 32),

          // ════════════════════════════════════════
          //  TYPOGRAPHY
          // ════════════════════════════════════════
          _buildSectionHeader(
              'Typography', Icons.text_fields_rounded, profile),
          const SizedBox(height: 12),

          // Font Size Slider
          _buildSettingCard(
            profile: profile,
            title: 'Font Size',
            subtitle: '${_fontSize.round()} pt',
            child: SliderTheme(
              data: SliderThemeData(
                activeTrackColor: profile.accentColor,
                inactiveTrackColor:
                    profile.accentColor.withValues(alpha: 0.15),
                thumbColor: profile.accentColor,
                overlayColor: profile.accentColor.withValues(alpha: 0.1),
              ),
              child: Slider(
                value: _fontSize,
                min: 14,
                max: 28,
                divisions: 7,
                onChanged: (val) {
                  setState(() => _fontSize = val);
                  _applySettings();
                },
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Line Spacing Slider
          _buildSettingCard(
            profile: profile,
            title: 'Line Spacing',
            subtitle: '${_lineHeight.toStringAsFixed(1)}×',
            child: SliderTheme(
              data: SliderThemeData(
                activeTrackColor: profile.accentColor,
                inactiveTrackColor:
                    profile.accentColor.withValues(alpha: 0.15),
                thumbColor: profile.accentColor,
                overlayColor: profile.accentColor.withValues(alpha: 0.1),
              ),
              child: Slider(
                value: _lineHeight,
                min: 1.0,
                max: 2.5,
                divisions: 6,
                onChanged: (val) {
                  setState(() => _lineHeight = val);
                  _applySettings();
                },
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Letter Spacing Slider
          _buildSettingCard(
            profile: profile,
            title: 'Letter Spacing',
            subtitle: '${_letterSpacing.toStringAsFixed(1)} px',
            child: SliderTheme(
              data: SliderThemeData(
                activeTrackColor: profile.accentColor,
                inactiveTrackColor:
                    profile.accentColor.withValues(alpha: 0.15),
                thumbColor: profile.accentColor,
                overlayColor: profile.accentColor.withValues(alpha: 0.1),
              ),
              child: Slider(
                value: _letterSpacing,
                min: 0.0,
                max: 3.0,
                divisions: 6,
                onChanged: (val) {
                  setState(() => _letterSpacing = val);
                  _applySettings();
                },
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Dyslexic Font Toggle
          _buildToggleCard(
            profile: profile,
            title: 'Dyslexia-friendly Font',
            subtitle: 'Use OpenDyslexic for easier reading',
            icon: Icons.font_download_rounded,
            value: _useDyslexicFont,
            onChanged: (val) {
              setState(() => _useDyslexicFont = val);
              _applySettings();
            },
          ),

          const SizedBox(height: 32),

          // ════════════════════════════════════════
          //  TEXT-TO-SPEECH
          // ════════════════════════════════════════
          _buildSectionHeader(
              'Text-to-Speech', Icons.volume_up_rounded, profile),
          const SizedBox(height: 12),

          // TTS Speed Slider
          _buildSettingCard(
            profile: profile,
            title: 'Speech Speed',
            subtitle: '${_ttsSpeed.toStringAsFixed(1)}×',
            child: Column(
              children: [
                SliderTheme(
                  data: SliderThemeData(
                    activeTrackColor: profile.accentColor,
                    inactiveTrackColor:
                        profile.accentColor.withValues(alpha: 0.15),
                    thumbColor: profile.accentColor,
                    overlayColor:
                        profile.accentColor.withValues(alpha: 0.1),
                  ),
                  child: Slider(
                    value: _ttsSpeed,
                    min: 0.5,
                    max: 2.0,
                    divisions: 6,
                    onChanged: (val) {
                      setState(() => _ttsSpeed = val);
                      _applySettings();
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('🐢 Slow',
                          style: TextStyle(
                            fontSize: 11,
                            color:
                                profile.textColor.withValues(alpha: 0.4),
                          )),
                      Text('Normal',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color:
                                profile.textColor.withValues(alpha: 0.5),
                          )),
                      Text('Fast 🐇',
                          style: TextStyle(
                            fontSize: 11,
                            color:
                                profile.textColor.withValues(alpha: 0.4),
                          )),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          // ════════════════════════════════════════
          //  DISPLAY
          // ════════════════════════════════════════
          _buildSectionHeader(
              'Display', Icons.display_settings_rounded, profile),
          const SizedBox(height: 12),

          _buildToggleCard(
            profile: profile,
            title: 'Focus Mode',
            subtitle: 'Show colored borders around interactive elements',
            icon: Icons.center_focus_strong_rounded,
            value: _focusMode,
            onChanged: (val) {
              setState(() => _focusMode = val);
              _applySettings();
            },
          ),
          const SizedBox(height: 12),
          _buildToggleCard(
            profile: profile,
            title: 'Reduce Motion',
            subtitle: 'Disable animations and transitions',
            icon: Icons.animation_rounded,
            value: _reduceMotion,
            onChanged: (val) {
              setState(() => _reduceMotion = val);
              _saveExtraPreferences();
            },
          ),

          const SizedBox(height: 32),

          // ════════════════════════════════════════
          //  FLOATING ASSISTANT (Android only)
          // ════════════════════════════════════════
          if (!kIsWeb && Platform.isAndroid) ...[
            _buildSectionHeader(
                'Floating Assistant', Icons.bubble_chart_rounded, profile),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: profile.accentColor.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                'The floating bubble appears on top of other apps so you can simplify, read, or summarize text from anywhere.',
                style: TextStyle(
                  fontFamily: profile.fontFamily,
                  fontSize: 12,
                  color: profile.textColor.withValues(alpha: 0.55),
                  height: 1.5,
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Overlay permission row
            _buildPermissionRow(
              profile: profile,
              title: 'Draw over other apps',
              ok: _overlayPermissionGranted,
              onTap: () async {
                await AndroidAssistantBridge.requestOverlayPermission();
                await Future.delayed(const Duration(seconds: 1));
                _refreshOverlayStates();
              },
            ),
            const SizedBox(height: 8),

            // Accessibility service row
            _buildPermissionRow(
              profile: profile,
              title: 'Accessibility service',
              ok: _accessibilityEnabled,
              onTap: () async {
                await AndroidAssistantBridge.openAccessibilitySettings();
                await Future.delayed(const Duration(seconds: 1));
                _refreshOverlayStates();
              },
            ),
            const SizedBox(height: 12),

            // Start / Stop Overlay toggle
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: profile.cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: profile.accentColor.withValues(alpha: 0.1),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: profile.accentColor.withValues(
                          alpha: _overlayActive ? 0.15 : 0.06),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.bubble_chart_rounded,
                      color: _overlayActive
                          ? profile.accentColor
                          : profile.textColor.withValues(alpha: 0.3),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Floating Bubble',
                          style: TextStyle(
                            fontFamily: profile.fontFamily,
                            fontSize: profile.fontSize - 1,
                            fontWeight: FontWeight.w600,
                            color: profile.textColor,
                          ),
                        ),
                        Text(
                          _overlayActive ? 'Active — visible on screen' : 'Tap to start the overlay',
                          style: TextStyle(
                            fontFamily: profile.fontFamily,
                            fontSize: 12,
                            color: profile.textColor.withValues(alpha: 0.45),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch.adaptive(
                    value: _overlayActive,
                    onChanged: (val) async {
                      if (val) {
                        final started = await AndroidAssistantBridge.startOverlay();
                        if (!started && mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Grant "Draw over other apps" permission first.'),
                            ),
                          );
                        }
                      } else {
                        await AndroidAssistantBridge.stopOverlay();
                      }
                      await Future.delayed(const Duration(milliseconds: 300));
                      _refreshOverlayStates();
                    },
                    activeColor: profile.accentColor,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),
          ],

          // ════════════════════════════════════════
          //  EXPERIENCE
          // ════════════════════════════════════════
          _buildSectionHeader(
              'Experience', Icons.tune_rounded, profile),
          const SizedBox(height: 12),

          _buildSettingCard(
            profile: profile,
            title: 'Language',
            subtitle: _language,
            child: DropdownButtonFormField<String>(
              value: _language,
              decoration: const InputDecoration(border: InputBorder.none),
              dropdownColor: profile.cardColor,
              items: _languageOptions
                  .map(
                    (lang) => DropdownMenuItem(
                      value: lang,
                      child: Text(
                        lang,
                        style: TextStyle(
                          fontFamily: profile.fontFamily,
                          color: profile.textColor,
                        ),
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value == null) return;
                setState(() => _language = value);
                _saveExtraPreferences();
              },
            ),
          ),

          const SizedBox(height: 12),

          _buildSettingCard(
            profile: profile,
            title: 'Simplification Level',
            subtitle: _simplificationLevel,
            child: DropdownButtonFormField<String>(
              value: _simplificationLevel,
              decoration: const InputDecoration(border: InputBorder.none),
              dropdownColor: profile.cardColor,
              items: _simplificationOptions
                  .map(
                    (level) => DropdownMenuItem(
                      value: level,
                      child: Text(
                        level,
                        style: TextStyle(
                          fontFamily: profile.fontFamily,
                          color: profile.textColor,
                        ),
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value == null) return;
                setState(() => _simplificationLevel = value);
                _saveExtraPreferences();
              },
            ),
          ),

          const SizedBox(height: 12),

          _buildSettingCard(
            profile: profile,
            title: 'Emergency Contact',
            subtitle: 'Used by Quick Help actions',
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _emergencyContactController,
                    keyboardType: TextInputType.phone,
                    style: TextStyle(
                      fontFamily: profile.fontFamily,
                      color: profile.textColor,
                    ),
                    decoration: InputDecoration(
                      hintText: 'e.g. +91XXXXXXXXXX',
                      hintStyle: TextStyle(
                        fontFamily: profile.fontFamily,
                        color: profile.textColor.withValues(alpha: 0.4),
                      ),
                      filled: true,
                      fillColor: profile.backgroundColor.withValues(alpha: 0.45),
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: profile.accentColor,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () async {
                    await _saveExtraPreferences();
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Emergency contact saved.')),
                    );
                  },
                  child: const Text('Save'),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          // ════════════════════════════════════════
          //  LIVE PREVIEW
          // ════════════════════════════════════════
          _buildSectionHeader('Preview', Icons.preview_rounded, profile),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: profile.cardColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: profile.accentColor.withValues(alpha: 0.15),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Sample Heading',
                  style: TextStyle(
                    fontFamily: _useDyslexicFont
                        ? 'OpenDyslexic'
                        : profile.fontFamily,
                    fontSize: _fontSize + 4,
                    fontWeight: FontWeight.w700,
                    color: profile.textColor,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'This is what your lesson text will look like with the current settings. '
                  'The font size, family, and spacing are all adjustable.',
                  style: TextStyle(
                    fontFamily: _useDyslexicFont
                        ? 'OpenDyslexic'
                        : profile.fontFamily,
                    fontSize: _fontSize,
                    color: profile.textColor.withValues(alpha: 0.8),
                    height: _lineHeight,
                    letterSpacing: _letterSpacing,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color:
                            profile.accentColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Key Point',
                        style: TextStyle(
                          fontFamily: _useDyslexicFont
                              ? 'OpenDyslexic'
                              : profile.fontFamily,
                          fontSize: _fontSize - 2,
                          fontWeight: FontWeight.w600,
                          color: profile.accentColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF4CAF50)
                            .withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Example',
                        style: TextStyle(
                          fontFamily: _useDyslexicFont
                              ? 'OpenDyslexic'
                              : profile.fontFamily,
                          fontSize: _fontSize - 2,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF4CAF50),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // ════════════════════════════════════════
          //  RESET BUTTON
          // ════════════════════════════════════════
          GestureDetector(
            onTap: () {
              final provider = Provider.of<NeuroThemeProvider>(context,
                  listen: false);
              final type = provider.activeProfile.profileType;
              provider.setProfileType(type);
              // Reset local state
              final resetProfile = provider.activeProfile;
              setState(() {
                _fontSize = resetProfile.fontSize;
                _ttsSpeed = resetProfile.ttsSpeed;
                _lineHeight = resetProfile.lineHeight;
                _letterSpacing = resetProfile.letterSpacing;
                _useDyslexicFont =
                    resetProfile.fontFamily == 'OpenDyslexic';
                _focusMode = resetProfile.focusBordersEnabled;
                _highContrast =
                    resetProfile.contrastMode == ContrastMode.high;
                _darkMode =
                    _isDarkBackground(resetProfile.backgroundColor);
                _accentColorIndex =
                    _findClosestColor(resetProfile.accentColor);
                _reduceMotion = false;
                _language = 'English';
                _simplificationLevel = 'Simple';
              });
                _saveExtraPreferences();
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: Colors.redAccent.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.redAccent.withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.restart_alt_rounded,
                      color: Colors.redAccent, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Reset to Profile Defaults',
                    style: TextStyle(
                      fontFamily: profile.fontFamily,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.redAccent,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // ── About ──
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: profile.accentColor.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: profile.accentColor.withValues(alpha: 0.1),
              ),
            ),
            child: Column(
              children: [
                Icon(Icons.accessibility_new_rounded,
                    color: profile.accentColor, size: 32),
                const SizedBox(height: 12),
                Text(
                  'Designed for neurodivergent minds',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: profile.fontFamily,
                    fontSize: profile.fontSize,
                    fontWeight: FontWeight.w600,
                    color: profile.textColor,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'WCAG 4.5:1 contrast • 8pt grid • Minimum 16pt text',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: profile.fontFamily,
                    fontSize: 12,
                    color: profile.textColor.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ),
          ],
        ),
      ),
    );
  }

  // ===========================================
  // Helpers
  // ===========================================

  Widget _buildSectionHeader(
      String title, IconData icon, NeuroProfile profile) {
    return Row(
      children: [
        Icon(icon, color: profile.accentColor, size: 20),
        const SizedBox(width: 10),
        Text(
          title.toUpperCase(),
          style: TextStyle(
            fontFamily: profile.fontFamily,
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: profile.accentColor,
            letterSpacing: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildSettingCard({
    required NeuroProfile profile,
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: profile.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: profile.accentColor.withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontFamily: profile.fontFamily,
                  fontSize: profile.fontSize,
                  fontWeight: FontWeight.w600,
                  color: profile.textColor,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: profile.accentColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  subtitle,
                  style: TextStyle(
                    fontFamily: profile.fontFamily,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: profile.accentColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }

  Widget _buildToggleCard({
    required NeuroProfile profile,
    required String title,
    required String subtitle,
    required IconData icon,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: profile.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: profile.accentColor.withValues(alpha: 0.1),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: profile.accentColor
                  .withValues(alpha: value ? 0.15 : 0.06),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon,
                color: value
                    ? profile.accentColor
                    : profile.textColor.withValues(alpha: 0.3),
                size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontFamily: profile.fontFamily,
                    fontSize: profile.fontSize - 1,
                    fontWeight: FontWeight.w600,
                    color: profile.textColor,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontFamily: profile.fontFamily,
                    fontSize: 12,
                    color: profile.textColor.withValues(alpha: 0.45),
                  ),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeColor: profile.accentColor,
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionRow({
    required NeuroProfile profile,
    required String title,
    required bool ok,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: profile.cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: profile.accentColor.withValues(alpha: 0.15)),
        ),
        child: Row(
          children: [
            Icon(
              ok ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
              color: ok ? const Color(0xFF4CAF50) : profile.textColor.withValues(alpha: 0.5),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontFamily: profile.fontFamily,
                  fontSize: profile.fontSize - 1,
                  color: profile.textColor,
                ),
              ),
            ),
            Text(
              ok ? 'Enabled' : 'Enable',
              style: TextStyle(
                fontFamily: profile.fontFamily,
                fontWeight: FontWeight.w700,
                color: ok ? const Color(0xFF4CAF50) : profile.accentColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getProfileIcon(NeuroProfileType type) {
    switch (type) {
      case NeuroProfileType.adhd:
        return Icons.bolt_rounded;
      case NeuroProfileType.dyslexia:
        return Icons.menu_book_rounded;
      case NeuroProfileType.autism:
        return Icons.grid_view_rounded;
      default:
        return Icons.person_rounded;
    }
  }
}
