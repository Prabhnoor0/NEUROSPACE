/// NeuroSpace — NeuroProfile Model
/// Defines the user's neuro-profile which drives the entire app's theming.
/// Supports both hardcoded presets (fallback) and AI-generated themes.

import 'package:flutter/material.dart';

enum NeuroProfileType { adhd, dyslexia, autism, custom }

enum EnergyLevel { high, medium, low }

enum ContrastMode { high, normal, low }

class NeuroProfile {
  final NeuroProfileType profileType;
  final String fontFamily;
  final double fontSize;
  final double letterSpacing;
  final double lineHeight;
  final Color backgroundColor;
  final Color textColor;
  final Color accentColor;
  final Color cardColor;
  final Color definitionColor;
  final Color exampleColor;
  final double ttsSpeed;
  final ContrastMode contrastMode;
  final bool focusBordersEnabled;
  final String? aiReasoning; // AI's explanation for why it chose these settings

  const NeuroProfile({
    required this.profileType,
    this.fontFamily = 'Inter',
    this.fontSize = 16.0,
    this.letterSpacing = 0.0,
    this.lineHeight = 1.5,
    this.backgroundColor = const Color(0xFF121212),
    this.textColor = const Color(0xFFE0E0E0),
    this.accentColor = const Color(0xFF4285F4),
    this.cardColor = const Color(0xFF1E1E2E),
    this.definitionColor = const Color(0xFF1A237E),
    this.exampleColor = const Color(0xFF1B5E20),
    this.ttsSpeed = 1.0,
    this.contrastMode = ContrastMode.normal,
    this.focusBordersEnabled = false,
    this.aiReasoning,
  });

  // =============================================
  // Preset Profiles (fallback when AI unavailable)
  // =============================================

  /// ADHD: Gamified, vibrant, focus-bordered, fast TTS
  static const adhd = NeuroProfile(
    profileType: NeuroProfileType.adhd,
    fontFamily: 'Inter',
    fontSize: 17.0,
    letterSpacing: 0.3,
    lineHeight: 1.6,
    backgroundColor: Color(0xFF0F0F1A),
    textColor: Color(0xFFF5F5F5),
    accentColor: Color(0xFFFF6B6B),
    cardColor: Color(0xFF1A1A2E),
    definitionColor: Color(0xFF2D1B69),
    exampleColor: Color(0xFF1B4332),
    ttsSpeed: 1.1,
    contrastMode: ContrastMode.normal,
    focusBordersEnabled: true,
  );

  /// Dyslexia: OpenDyslexic font, high spacing, warm colors, clear sections
  static const dyslexia = NeuroProfile(
    profileType: NeuroProfileType.dyslexia,
    fontFamily: 'OpenDyslexic',
    fontSize: 18.0,
    letterSpacing: 1.5,
    lineHeight: 2.0,
    backgroundColor: Color(0xFFFFF9C4),
    textColor: Color(0xFF1A1A1A),
    accentColor: Color(0xFF1565C0),
    cardColor: Color(0xFFFFF3E0),
    definitionColor: Color(0xFFBBDEFB),
    exampleColor: Color(0xFFC8E6C9),
    ttsSpeed: 1.0,
    contrastMode: ContrastMode.high,
    focusBordersEnabled: false,
  );

  /// Autism: Structured, calm, low-contrast, literal, deep-dive enabled
  static const autism = NeuroProfile(
    profileType: NeuroProfileType.autism,
    fontFamily: 'Lexend',
    fontSize: 16.0,
    letterSpacing: 0.5,
    lineHeight: 1.8,
    backgroundColor: Color(0xFF1A2332),
    textColor: Color(0xFFCCD6E0),
    accentColor: Color(0xFF5B9BD5),
    cardColor: Color(0xFF243447),
    definitionColor: Color(0xFF1E3A5F),
    exampleColor: Color(0xFF2E4A3A),
    ttsSpeed: 0.9,
    contrastMode: ContrastMode.low,
    focusBordersEnabled: false,
  );

  /// Get preset profile by type (fallback)
  static NeuroProfile getPreset(NeuroProfileType type) {
    switch (type) {
      case NeuroProfileType.adhd:
        return adhd;
      case NeuroProfileType.dyslexia:
        return dyslexia;
      case NeuroProfileType.autism:
        return autism;
      case NeuroProfileType.custom:
        return adhd; // Default fallback
    }
  }

  // =============================================
  // AI-Generated Profile Factory
  // =============================================

  /// Create a NeuroProfile from an AI-generated theme JSON response.
  /// This is called when Groq returns personalized theme settings.
  factory NeuroProfile.fromAIResponse(Map<String, dynamic> data) {
    // Parse profile type
    NeuroProfileType type = NeuroProfileType.custom;
    final typeStr = data['profileType'] as String? ?? 'custom';
    try {
      type = NeuroProfileType.values.firstWhere((e) => e.name == typeStr);
    } catch (_) {
      type = NeuroProfileType.custom;
    }

    // Parse contrast mode
    ContrastMode contrast = ContrastMode.normal;
    final contrastStr = data['contrastMode'] as String? ?? 'normal';
    try {
      contrast = ContrastMode.values.firstWhere((e) => e.name == contrastStr);
    } catch (_) {}

    return NeuroProfile(
      profileType: type,
      fontFamily: data['fontFamily'] as String? ?? 'Inter',
      fontSize: (data['fontSize'] as num?)?.toDouble() ?? 16.0,
      letterSpacing: (data['letterSpacing'] as num?)?.toDouble() ?? 0.0,
      lineHeight: (data['lineHeight'] as num?)?.toDouble() ?? 1.5,
      backgroundColor: _parseHexColor(data['backgroundColor'], 0xFF121212),
      textColor: _parseHexColor(data['textColor'], 0xFFE0E0E0),
      accentColor: _parseHexColor(data['accentColor'], 0xFF4285F4),
      cardColor: _parseHexColor(data['cardColor'], 0xFF1E1E2E),
      definitionColor: _parseHexColor(data['definitionColor'], 0xFF1A237E),
      exampleColor: _parseHexColor(data['exampleColor'], 0xFF1B5E20),
      ttsSpeed: (data['ttsSpeed'] as num?)?.toDouble() ?? 1.0,
      contrastMode: contrast,
      focusBordersEnabled: data['focusBordersEnabled'] as bool? ?? false,
      aiReasoning: data['reasoning'] as String?,
    );
  }

  /// Parse a hex color string like "#FF6B6B" into a Color.
  static Color _parseHexColor(dynamic hexStr, int fallback) {
    if (hexStr == null || hexStr is! String) return Color(fallback);

    String hex = hexStr.replaceAll('#', '');
    if (hex.length == 6) hex = 'FF$hex'; // Add alpha
    if (hex.length == 8) {
      try {
        return Color(int.parse(hex, radix: 16));
      } catch (_) {}
    }
    return Color(fallback);
  }

  // =============================================
  // Serialization
  // =============================================

  /// Convert to a Map for Firebase
  Map<String, dynamic> toMap() {
    return {
      'profileType': profileType.name,
      'fontFamily': fontFamily,
      'fontSize': fontSize,
      'letterSpacing': letterSpacing,
      'lineHeight': lineHeight,
      'backgroundColor': '#${backgroundColor.value.toRadixString(16).padLeft(8, '0').substring(2)}',
      'textColor': '#${textColor.value.toRadixString(16).padLeft(8, '0').substring(2)}',
      'accentColor': '#${accentColor.value.toRadixString(16).padLeft(8, '0').substring(2)}',
      'cardColor': '#${cardColor.value.toRadixString(16).padLeft(8, '0').substring(2)}',
      'definitionColor': '#${definitionColor.value.toRadixString(16).padLeft(8, '0').substring(2)}',
      'exampleColor': '#${exampleColor.value.toRadixString(16).padLeft(8, '0').substring(2)}',
      'ttsSpeed': ttsSpeed,
      'contrastMode': contrastMode.name,
      'focusBordersEnabled': focusBordersEnabled,
      'aiReasoning': aiReasoning,
    };
  }

  /// Create from a Firebase map (same format as toMap)
  factory NeuroProfile.fromMap(Map<String, dynamic> data) {
    return NeuroProfile.fromAIResponse(data);
  }

  /// Convert profile to a Flutter ThemeData
  ThemeData toThemeData() {
    final brightness = (backgroundColor.computeLuminance() > 0.5)
        ? Brightness.light
        : Brightness.dark;

    return ThemeData(
      brightness: brightness,
      scaffoldBackgroundColor: backgroundColor,
      primaryColor: accentColor,
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: accentColor,
        onPrimary: Colors.white,
        secondary: accentColor.withOpacity(0.7),
        onSecondary: Colors.white,
        error: const Color(0xFFCF6679),
        onError: Colors.white,
        surface: cardColor,
        onSurface: textColor,
      ),
      cardColor: cardColor,
      textTheme: TextTheme(
        headlineLarge: TextStyle(
          fontFamily: fontFamily,
          fontSize: fontSize + 12,
          fontWeight: FontWeight.bold,
          color: textColor,
          letterSpacing: letterSpacing,
          height: lineHeight,
        ),
        headlineMedium: TextStyle(
          fontFamily: fontFamily,
          fontSize: fontSize + 6,
          fontWeight: FontWeight.w600,
          color: textColor,
          letterSpacing: letterSpacing,
          height: lineHeight,
        ),
        titleLarge: TextStyle(
          fontFamily: fontFamily,
          fontSize: fontSize + 4,
          fontWeight: FontWeight.w600,
          color: textColor,
          letterSpacing: letterSpacing,
          height: lineHeight,
        ),
        bodyLarge: TextStyle(
          fontFamily: fontFamily,
          fontSize: fontSize,
          color: textColor,
          letterSpacing: letterSpacing,
          height: lineHeight,
        ),
        bodyMedium: TextStyle(
          fontFamily: fontFamily,
          fontSize: fontSize - 2,
          color: textColor.withOpacity(0.85),
          letterSpacing: letterSpacing,
          height: lineHeight,
        ),
        labelLarge: TextStyle(
          fontFamily: fontFamily,
          fontSize: fontSize - 1,
          fontWeight: FontWeight.w500,
          color: accentColor,
          letterSpacing: letterSpacing + 0.5,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: backgroundColor,
        foregroundColor: textColor,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        color: cardColor,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: focusBordersEnabled
              ? BorderSide(color: accentColor.withValues(alpha: 0.3), width: 1.5)
              : BorderSide.none,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accentColor,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: cardColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: accentColor, width: 2),
        ),
        hintStyle: TextStyle(
          color: textColor.withOpacity(0.4),
          fontFamily: fontFamily,
        ),
      ),
    );
  }
}
