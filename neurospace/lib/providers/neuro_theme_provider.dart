/// NeuroSpace — Theme Provider
/// Manages the active neuro-profile and provides animated theme switching.
/// Uses Groq AI to dynamically generate theme settings based on user traits.
/// Syncs profile to Firebase Realtime Database for persistence.

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/neuro_profile.dart';
import '../services/firebase_service.dart';
import '../services/api_service.dart';

class NeuroThemeProvider extends ChangeNotifier {
  NeuroProfile _activeProfile = NeuroProfile.adhd;
  EnergyLevel _energyLevel = EnergyLevel.medium;
  bool _isOnboarded = false;
  bool _isGeneratingTheme = false;
  String? _aiReasoning;

  // Selected traits during onboarding
  final Set<String> _selectedTraits = {};

  // =============================================
  // Getters
  // =============================================

  NeuroProfile get activeProfile => _activeProfile;
  ThemeData get themeData => _activeProfile.toThemeData();
  EnergyLevel get energyLevel => _energyLevel;
  bool get isOnboarded => _isOnboarded;
  Set<String> get selectedTraits => _selectedTraits;
  NeuroProfileType get profileType => _activeProfile.profileType;
  bool get isGeneratingTheme => _isGeneratingTheme;
  String? get aiReasoning => _aiReasoning;

  // =============================================
  // Profile Switching
  // =============================================

  /// Set a preset profile by type (manual fallback)
  void setProfileType(NeuroProfileType type) {
    _activeProfile = NeuroProfile.getPreset(type);
    _saveProfile();
    _syncToFirebase();
    notifyListeners();
  }

  /// Set a fully custom profile (from AI or manual)
  void setProfile(NeuroProfile profile) {
    _activeProfile = profile;
    _aiReasoning = profile.aiReasoning;
    _saveProfile();
    _syncToFirebase();
    notifyListeners();
  }

  // =============================================
  // AI-Powered Theme Generation
  // =============================================

  /// Toggle a trait and request AI-generated theme from Groq.
  /// Falls back to local blending if the backend is unavailable.
  bool toggleTrait(String trait) {
    if (_selectedTraits.contains(trait)) {
      _selectedTraits.remove(trait);
    } else {
      _selectedTraits.add(trait);
    }

    // Immediately apply local fallback for instant visual feedback
    _applyLocalBlend();
    notifyListeners();

    // Then request AI-generated theme in the background
    _requestAITheme();

    return _selectedTraits.contains(trait);
  }

  /// Request a full AI-generated theme from the Groq backend.
  Future<void> _requestAITheme() async {
    if (_selectedTraits.isEmpty) return;

    _isGeneratingTheme = true;
    notifyListeners();

    try {
      final themeData = await ApiService.generateTheme(
        traits: _selectedTraits.toList(),
        energyLevel: _energyLevel.name,
      );

      if (themeData != null) {
        _activeProfile = NeuroProfile.fromAIResponse(themeData);
        _aiReasoning = themeData['reasoning'] as String?;
        _saveProfile();
        debugPrint('AI theme applied: ${_activeProfile.profileType.name} — $_aiReasoning');
      }
    } catch (e) {
      debugPrint('AI theme generation failed, using local blend: $e');
      // Local blend already applied, so this is fine
    }

    _isGeneratingTheme = false;
    notifyListeners();
  }

  /// Fast local blending as an instant preview while AI generates the real theme.
  /// This gives immediate visual feedback when traits are toggled.
  void _applyLocalBlend() {
    if (_selectedTraits.isEmpty) return;

    // Start with ADHD as base, then morph
    NeuroProfile baseProfile = NeuroProfile.adhd;

    if (_selectedTraits.contains('literal_explanations') ||
        _selectedTraits.contains('bright_lights')) {
      baseProfile = NeuroProfile.autism;
    } else if (_selectedTraits.contains('dense_text')) {
      baseProfile = NeuroProfile.dyslexia;
    }

    String newFontFamily = baseProfile.fontFamily;
    double newFontSize = baseProfile.fontSize;
    double newLetterSpacing = baseProfile.letterSpacing;
    double newLineHeight = baseProfile.lineHeight;
    double newTtsSpeed = baseProfile.ttsSpeed;
    bool newFocusBorders = baseProfile.focusBordersEnabled;
    Color newBackground = baseProfile.backgroundColor;
    Color newTextColor = baseProfile.textColor;
    Color newAccent = baseProfile.accentColor;
    Color newCard = baseProfile.cardColor;
    ContrastMode newContrast = baseProfile.contrastMode;
    NeuroProfileType newType = baseProfile.profileType;

    if (_selectedTraits.contains('dense_text')) {
      newFontFamily = NeuroProfile.dyslexia.fontFamily;
      newFontSize = NeuroProfile.dyslexia.fontSize;
      newLetterSpacing = NeuroProfile.dyslexia.letterSpacing;
      newLineHeight = NeuroProfile.dyslexia.lineHeight;
      newType = NeuroProfileType.dyslexia;
    }

    if (_selectedTraits.contains('lose_focus')) {
      newFocusBorders = true;
      newTtsSpeed = 1.1;
      newAccent = NeuroProfile.adhd.accentColor;
      if (!_selectedTraits.contains('dense_text')) {
        newType = NeuroProfileType.adhd;
      }
    }

    if (_selectedTraits.contains('bright_lights')) {
      newBackground = NeuroProfile.autism.backgroundColor;
      newTextColor = NeuroProfile.autism.textColor;
      newCard = NeuroProfile.autism.cardColor;
      newContrast = ContrastMode.low;
    }

    if (_selectedTraits.contains('literal_explanations')) {
      if (newType != NeuroProfileType.dyslexia) {
        newType = NeuroProfileType.autism;
      }
    }

    _activeProfile = NeuroProfile(
      profileType: newType,
      fontFamily: newFontFamily,
      fontSize: newFontSize,
      letterSpacing: newLetterSpacing,
      lineHeight: newLineHeight,
      backgroundColor: newBackground,
      textColor: newTextColor,
      accentColor: newAccent,
      cardColor: newCard,
      definitionColor: baseProfile.definitionColor,
      exampleColor: baseProfile.exampleColor,
      ttsSpeed: newTtsSpeed,
      contrastMode: newContrast,
      focusBordersEnabled: newFocusBorders,
    );
  }

  /// Complete onboarding
  void completeOnboarding() {
    _isOnboarded = true;
    _saveProfile();
    _syncToFirebase();
    notifyListeners();
  }

  // =============================================
  // Energy Level
  // =============================================

  void setEnergyLevel(EnergyLevel level) {
    _energyLevel = level;

    // Re-request AI theme with new energy level
    if (_selectedTraits.isNotEmpty) {
      _requestAITheme();
    }

    _syncToFirebase();
    notifyListeners();
  }

  /// Get max modules based on energy level
  int get maxModules {
    switch (_energyLevel) {
      case EnergyLevel.high:
        return 12;
      case EnergyLevel.medium:
        return 7;
      case EnergyLevel.low:
        return 4;
    }
  }

  // =============================================
  // Persistence (SharedPreferences + Firebase)
  // =============================================

  /// Load saved profile from local storage, then try Firebase
  Future<void> loadSavedProfile() async {
    final prefs = await SharedPreferences.getInstance();
    _isOnboarded = prefs.getBool('isOnboarded') ?? false;

    // Try to load full AI-generated profile from prefs
    final savedThemeJson = prefs.getString('aiThemeJson');
    if (savedThemeJson != null) {
      try {
        final data = Map<String, dynamic>.from(
          jsonDecode(savedThemeJson) as Map,
        );
        if (data.isNotEmpty) {
          _activeProfile = NeuroProfile.fromMap(data);
          _aiReasoning = data['aiReasoning'] as String?;
        }
      } catch (_) {
        // Fall back to preset
        _loadPresetFromPrefs(prefs);
      }
    } else {
      _loadPresetFromPrefs(prefs);
    }

    final savedEnergy = prefs.getString('energyLevel');
    if (savedEnergy != null) {
      try {
        _energyLevel = EnergyLevel.values.firstWhere(
          (e) => e.name == savedEnergy,
        );
      } catch (_) {}
    }

    // Try to load from Firebase (cloud sync)
    try {
      final userId = FirebaseService.currentUserId;
      if (userId != null) {
        final cloudProfile = await FirebaseService.getProfile(userId);
        if (cloudProfile != null && cloudProfile.containsKey('fontFamily')) {
          // Full AI profile saved in cloud
          _activeProfile = NeuroProfile.fromMap(cloudProfile);
          _aiReasoning = cloudProfile['aiReasoning'] as String?;
        }
      }
    } catch (_) {
      // Firebase not available — use local
    }

    notifyListeners();
  }

  void _loadPresetFromPrefs(SharedPreferences prefs) {
    final savedType = prefs.getString('profileType');
    if (savedType != null) {
      try {
        final type = NeuroProfileType.values.firstWhere(
          (e) => e.name == savedType,
        );
        _activeProfile = NeuroProfile.getPreset(type);
      } catch (_) {}
    }
  }

  /// Save current profile to local storage
  Future<void> _saveProfile() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('profileType', _activeProfile.profileType.name);
    await prefs.setBool('isOnboarded', _isOnboarded);
    await prefs.setString('energyLevel', _energyLevel.name);

    // Save full theme JSON for AI-generated profiles
    try {
      final themeMap = _activeProfile.toMap();
      final jsonStr = jsonEncode(themeMap);
      await prefs.setString('aiThemeJson', jsonStr);
    } catch (_) {}
  }

  /// Sync profile to Firebase Realtime Database
  Future<void> _syncToFirebase() async {
    try {
      final userId = FirebaseService.currentUserId;
      if (userId == null) return;

      final profileData = _activeProfile.toMap();
      profileData['isOnboarded'] = _isOnboarded;
      profileData['energyLevel'] = _energyLevel.name;
      profileData['selectedTraits'] = _selectedTraits.toList();

      await FirebaseService.saveProfile(
        userId: userId,
        profileData: profileData,
      );
    } catch (e) {
      debugPrint('Firebase sync failed: $e');
    }
  }
}
