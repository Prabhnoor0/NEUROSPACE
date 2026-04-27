// NeuroSpace — Dashboard Screen
// The main hub showing search, mental battery, quick actions, and recent lessons.
// Fully adaptive to the active NeuroProfile.

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:async';
import 'dart:io' show Platform;
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:image_picker/image_picker.dart';
import '../providers/neuro_theme_provider.dart';
import '../models/neuro_profile.dart';
import '../services/api_service.dart';
import '../services/firebase_service.dart';
import 'lesson_screen.dart';
import 'search_screen.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'library_screen.dart';
import 'focus_timer_screen.dart';
import 'panic_screen.dart';
import 'maps_screen.dart';
import 'settings_screen.dart';
import 'scan_result_screen.dart';
import 'quick_help_screen.dart';
import '../services/android_assistant_bridge.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final TextEditingController _searchController = TextEditingController();
  bool _isConnected = false;
  String _backendVersion = '';
  bool _isSearching = false;
  List<Map<String, dynamic>> _recentLessons = [];
  int _totalStudyMinutes = 0;

  @override
  void initState() {
    super.initState();
    _checkBackend();
    _autoShowOverlay();
    _loadRecentData();
  }

  Future<void> _loadRecentData() async {
    try {
      final userId = FirebaseService.currentUserId;
      if (userId != null) {
        final lessons = await FirebaseService.getLessons(userId);
        final totalMin = await FirebaseService.getTotalStudyMinutes(userId);
        if (mounted) {
          setState(() {
            _recentLessons = lessons.take(3).toList();
            _totalStudyMinutes = totalMin;
          });
        }
      }
    } catch (_) {}
  }

  /// Auto-show the floating NeuroSpace bubble if overlay permission is granted.
  /// This means the user only needs to grant permission once — the bubble
  /// will appear automatically every time they open the app.
  Future<void> _autoShowOverlay() async {
    try {
      final bool granted = await FlutterOverlayWindow.isPermissionGranted();
      if (granted) {
        final bool isActive = await FlutterOverlayWindow.isActive();
        if (!isActive) {
          await _launchOverlayBubble();
        }
      }
    } catch (_) {
      // Overlay not supported or permission check failed — ignore silently
    }
  }

  /// Shared method to launch the overlay bubble.
  Future<void> _launchOverlayBubble() async {
      await FlutterOverlayWindow.showOverlay(
        enableDrag: false,
        overlayTitle: "NeuroSpace",
        overlayContent: "Tap the bubble for accessibility tools",
        flag: OverlayFlag.defaultFlag,
        visibility: NotificationVisibility.visibilityPublic,
        positionGravity: PositionGravity.none,
        width: WindowSize.matchParent,
        height: WindowSize.matchParent,
      );
  }

  Future<void> _showAssistantSetupSheet() async {
    final profile = Provider.of<NeuroThemeProvider>(context, listen: false).activeProfile;
    bool overlayGranted = false;
    bool accessibilityEnabled = false;

    try {
      overlayGranted = await FlutterOverlayWindow.isPermissionGranted();
    } catch (_) {}

    try {
      accessibilityEnabled = await AndroidAssistantBridge.isAccessibilityServiceEnabled();
    } catch (_) {}

    if (!mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: profile.cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        Timer? pollTimer;
        return StatefulBuilder(builder: (context, setModalState) {
          pollTimer ??= Timer.periodic(const Duration(seconds: 1), (timer) async {
            try {
              final over = await FlutterOverlayWindow.isPermissionGranted();
              final acc = await AndroidAssistantBridge.isAccessibilityServiceEnabled();
              if (over != overlayGranted || acc != accessibilityEnabled) {
                if (context.mounted) {
                  setModalState(() {
                    overlayGranted = over;
                    accessibilityEnabled = acc;
                  });
                }
              }
            } catch (_) {}
          });

          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Assistant Setup',
                    style: TextStyle(
                      fontFamily: profile.fontFamily,
                      fontSize: profile.fontSize + 4,
                      fontWeight: FontWeight.w800,
                      color: profile.textColor,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Enable permissions for global floating accessibility helper.',
                    style: TextStyle(
                      fontFamily: profile.fontFamily,
                      fontSize: profile.fontSize - 2,
                      color: profile.textColor.withOpacity(0.65),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildSetupRow(
                    title: 'Draw over other apps',
                    ok: overlayGranted,
                    profile: profile,
                    onTap: () async {
                      final granted = await FlutterOverlayWindow.isPermissionGranted();
                      if (!granted) {
                        await FlutterOverlayWindow.requestPermission();
                      }
                    },
                  ),
                  const SizedBox(height: 10),
                  _buildSetupRow(
                    title: 'Accessibility service',
                    ok: accessibilityEnabled,
                    profile: profile,
                    onTap: () async {
                      await AndroidAssistantBridge.openAccessibilitySettings();
                    },
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: profile.accentColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () async {
                        pollTimer?.cancel();
                        Navigator.pop(ctx);
                        await _launchOverlayBubble();
                      },
                      icon: const Icon(Icons.bubble_chart_rounded),
                      label: const Text('Start Floating Assistant'),
                    ),
                  ),
                ],
              ),
            ),
          );
        });
      },
    ).whenComplete(() {
      // ignore: avoid_print
      print('Bottom sheet closed');
    });
  }

  Widget _buildSetupRow({
    required String title,
    required bool ok,
    required dynamic profile,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: profile.backgroundColor.withOpacity(0.45),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: profile.accentColor.withOpacity(0.15)),
        ),
        child: Row(
          children: [
            Icon(
              ok ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
              color: ok ? const Color(0xFF4CAF50) : profile.textColor.withOpacity(0.5),
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

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _checkBackend() async {
    try {
      final health = await ApiService.healthCheck();
      if (mounted) {
        setState(() {
          _isConnected = true;
          _backendVersion = health['version'] ?? '';
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isConnected = false);
    }
  }

  void _onSearchSubmitted(String topic) {
    if (topic.trim().isEmpty) return;
    setState(() => _isSearching = true);
    
    // Navigate to the search screen with Wikipedia + web results
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SearchScreen(initialQuery: topic),
      ),
    );
    
    setState(() => _isSearching = false);
  }

  // =============================================
  // Snap-to-Understand: Camera Scan Flow
  // =============================================

  Future<void> _launchScanFlow(BuildContext ctx) async {
    final profile = Provider.of<NeuroThemeProvider>(ctx, listen: false);
    final picker = ImagePicker();

    // Show source picker bottom sheet
    final source = await showModalBottomSheet<ImageSource>(
      context: ctx,
      backgroundColor: profile.activeProfile.cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '📸 Scan Text',
                style: TextStyle(
                  fontFamily: profile.activeProfile.fontFamily,
                  fontSize: profile.activeProfile.fontSize + 4,
                  fontWeight: FontWeight.w800,
                  color: profile.activeProfile.textColor,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Take a photo or pick from gallery to simplify text',
                style: TextStyle(
                  fontFamily: profile.activeProfile.fontFamily,
                  fontSize: profile.activeProfile.fontSize - 1,
                  color: profile.activeProfile.textColor.withOpacity(0.6),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: _buildSourceOption(
                      profile.activeProfile,
                      icon: Icons.camera_alt_rounded,
                      label: 'Camera',
                      onTap: () => Navigator.pop(context, ImageSource.camera),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildSourceOption(
                      profile.activeProfile,
                      icon: Icons.photo_library_rounded,
                      label: 'Gallery',
                      onTap: () => Navigator.pop(context, ImageSource.gallery),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );

    if (source == null) return;

    // Pick image
    final XFile? pickedFile = await picker.pickImage(
      source: source,
      maxWidth: 2048,
      maxHeight: 2048,
      imageQuality: 85,
    );

    if (pickedFile == null || !mounted) return;

    // Show scanning overlay
    _showScanningOverlay(ctx, profile.activeProfile);

    // Upload to backend
    final currentProfile = profile.activeProfile.profileType == NeuroProfileType.adhd
        ? 'ADHD'
        : profile.activeProfile.profileType == NeuroProfileType.dyslexia
            ? 'Dyslexia'
            : 'Autism';

    final result = await ApiService.scanImage(
      pickedFile.path,
      profile: currentProfile,
    );

    // Dismiss the overlay
    if (mounted) Navigator.of(ctx).pop();

    if (result != null && mounted) {
      // Parse key terms
      List<Map<String, dynamic>> keyTerms = [];
      if (result['key_terms'] != null && result['key_terms'] is List) {
        keyTerms = (result['key_terms'] as List)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
      }

      Navigator.push(
        ctx,
        MaterialPageRoute(
          builder: (_) => ScanResultScreen(
            extractedText: result['extracted_text'] ?? '',
            summary: result['summary'] ?? '',
            simplified: result['simplified'] ?? '',
            keyTerms: keyTerms,
          ),
        ),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(ctx).showSnackBar(
        SnackBar(
          content: Text(
            'Could not process the image. Try a clearer photo.',
            style: TextStyle(fontFamily: profile.activeProfile.fontFamily),
          ),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }

  Widget _buildSourceOption(
    dynamic profileData, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: profileData.accentColor.withOpacity(0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: profileData.accentColor.withOpacity(0.2),
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: profileData.accentColor, size: 32),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontFamily: profileData.fontFamily,
                fontSize: profileData.fontSize,
                fontWeight: FontWeight.w600,
                color: profileData.textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showScanningOverlay(BuildContext ctx, dynamic profileData) {
    showDialog(
      context: ctx,
      barrierDismissible: false,
      builder: (context) => PopScope(
        canPop: false,
        child: Center(
          child: Container(
            margin: const EdgeInsets.all(40),
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: profileData.cardColor,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 30,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(
                  color: profileData.accentColor,
                  strokeWidth: 3,
                ),
                const SizedBox(height: 20),
                Text(
                  '🔍 Scanning & Simplifying...',
                  style: TextStyle(
                    fontFamily: profileData.fontFamily,
                    fontSize: profileData.fontSize + 2,
                    fontWeight: FontWeight.w700,
                    color: profileData.textColor,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'AI is reading and rewriting the text\nfor your brain style',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: profileData.fontFamily,
                    fontSize: profileData.fontSize - 2,
                    color: profileData.textColor.withOpacity(0.6),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<NeuroThemeProvider>(context);
    final profile = themeProvider.activeProfile;

    return Scaffold(
      body: AnimatedContainer(
        duration: const Duration(milliseconds: 500),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              profile.backgroundColor,
              Color.lerp(profile.backgroundColor, profile.accentColor, 0.04) ??
                  profile.backgroundColor,
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 16),
                _buildHeader(profile),
                const SizedBox(height: 24),
                _buildSearchBar(profile),
                const SizedBox(height: 28),
                _buildMentalBattery(profile, themeProvider),
                const SizedBox(height: 28),
                _buildQuickActions(profile),
                const SizedBox(height: 28),
                _buildStudyStats(profile),
                const SizedBox(height: 28),
                _buildRecentLessons(profile),
                const SizedBox(height: 28),
                _buildBackendStatus(profile),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // =============================================
  // Header with logo and profile switcher
  // =============================================
  Widget _buildHeader(NeuroProfile profile) {
    return Row(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 400),
          width: 46,
          height: 46,
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
                blurRadius: 12,
                spreadRadius: 1,
              ),
            ],
          ),
          child: const Icon(Icons.psychology_rounded, color: Colors.white, size: 24),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 400),
                style: TextStyle(
                  fontFamily: profile.fontFamily,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: profile.textColor,
                  letterSpacing: profile.letterSpacing,
                ),
                child: const Text('NeuroSpace'),
              ),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 400),
                style: TextStyle(
                  fontFamily: profile.fontFamily,
                  fontSize: 12,
                  color: profile.accentColor,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
                child: Text(
                    '${profile.profileType.name.toUpperCase()} MODE'),
              ),
            ],
          ),
        ),
        // Settings
        AnimatedContainer(
          duration: const Duration(milliseconds: 400),
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: profile.cardColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: IconButton(
            icon: Icon(Icons.settings_rounded,
                color: profile.textColor.withValues(alpha: 0.5), size: 20),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const SettingsScreen(),
                ),
              );
            },
            padding: EdgeInsets.zero,
          ),
        ),
        const SizedBox(width: 8),
        // Profile switch
        AnimatedContainer(
          duration: const Duration(milliseconds: 400),
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: profile.cardColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: IconButton(
            icon: Icon(Icons.tune_rounded,
                color: profile.textColor.withValues(alpha: 0.5), size: 20),
            onPressed: () => _showProfileSwitcher(context),
            padding: EdgeInsets.zero,
          ),
        ),
      ],
    )
        .animate()
        .fadeIn(duration: 500.ms)
        .slideY(begin: -0.15, end: 0, duration: 500.ms);
  }

  // =============================================
  // Search Bar
  // =============================================
  Widget _buildSearchBar(NeuroProfile profile) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      decoration: BoxDecoration(
        color: profile.cardColor,
        borderRadius: BorderRadius.circular(20),
        border: profile.focusBordersEnabled
            ? Border.all(
                color: profile.accentColor.withValues(alpha: 0.25),
                width: 1.5,
              )
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        onSubmitted: _onSearchSubmitted,
        style: TextStyle(
          fontFamily: profile.fontFamily,
          fontSize: profile.fontSize,
          color: profile.textColor,
          letterSpacing: profile.letterSpacing,
        ),
        decoration: InputDecoration(
          hintText: 'Search Wikipedia, topics, anything...',
          hintStyle: TextStyle(
            fontFamily: profile.fontFamily,
            color: profile.textColor.withValues(alpha: 0.35),
          ),
          prefixIcon: Padding(
            padding: const EdgeInsets.only(left: 16, right: 8),
            child: Icon(Icons.search_rounded,
                color: profile.accentColor.withValues(alpha: 0.6), size: 24),
          ),
          suffixIcon: Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => _launchScanFlow(context),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: profile.accentColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.camera_alt_rounded,
                    color: profile.accentColor.withValues(alpha: 0.5), size: 20),
              ),
            ),
          ),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 0, vertical: 16),
        ),
      ),
    )
        .animate()
        .fadeIn(delay: 150.ms, duration: 500.ms)
        .slideY(begin: 0.1, end: 0, delay: 150.ms, duration: 500.ms);
  }

  // =============================================
  // Mental Battery
  // =============================================
  Widget _buildMentalBattery(
      NeuroProfile profile, NeuroThemeProvider themeProvider) {
    final energy = themeProvider.energyLevel;
    final batteryPercent = energy == EnergyLevel.high
        ? 0.85
        : energy == EnergyLevel.medium
            ? 0.55
            : 0.25;
    final batteryLabel = energy == EnergyLevel.high
        ? '🔥 Full power!'
        : energy == EnergyLevel.medium
            ? '⚡ Good to go'
            : '🌙 Low energy';
    final batteryColor = energy == EnergyLevel.high
        ? const Color(0xFF4CAF50)
        : energy == EnergyLevel.medium
            ? const Color(0xFFFFA726)
            : const Color(0xFFEF5350);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: profile.cardColor,
        borderRadius: BorderRadius.circular(22),
        border: profile.focusBordersEnabled
            ? Border.all(
                color: profile.accentColor.withValues(alpha: 0.2), width: 1)
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
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
                child: const Text('🧠 Mental Battery'),
              ),
              const Spacer(),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 400),
                style: TextStyle(
                  fontFamily: profile.fontFamily,
                  fontSize: 13,
                  color: profile.textColor.withValues(alpha: 0.5),
                ),
                child: Text(batteryLabel),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Battery bar
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeOutCubic,
              height: 12,
              width: double.infinity,
              decoration: BoxDecoration(
                color: profile.backgroundColor.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: batteryPercent,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 600),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    gradient: LinearGradient(
                      colors: [
                        batteryColor,
                        batteryColor.withValues(alpha: 0.7),
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: batteryColor.withValues(alpha: 0.3),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 14),

          // Energy level buttons
          Row(
            children: EnergyLevel.values.map((level) {
              final isActive = energy == level;
              final label = level == EnergyLevel.high
                  ? '🔥 High'
                  : level == EnergyLevel.medium
                      ? '⚡ Medium'
                      : '🌙 Low';
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    right: level != EnergyLevel.low ? 8 : 0,
                  ),
                  child: GestureDetector(
                    onTap: () => themeProvider.setEnergyLevel(level),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: isActive
                            ? profile.accentColor.withValues(alpha: 0.15)
                            : profile.backgroundColor.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isActive
                              ? profile.accentColor.withValues(alpha: 0.5)
                              : Colors.transparent,
                        ),
                      ),
                      child: Center(
                        child: AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 300),
                          style: TextStyle(
                            fontFamily: profile.fontFamily,
                            fontSize: 12,
                            fontWeight:
                                isActive ? FontWeight.w700 : FontWeight.w500,
                            color: isActive
                                ? profile.accentColor
                                : profile.textColor.withValues(alpha: 0.5),
                          ),
                          child: Text(label),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 8),
          AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 400),
            style: TextStyle(
              fontFamily: profile.fontFamily,
              fontSize: 11,
              color: profile.textColor.withValues(alpha: 0.3),
            ),
            child: Text(
                'Lessons will adapt: ${themeProvider.maxModules} modules max'),
          ),
        ],
      ),
    )
        .animate()
        .fadeIn(delay: 300.ms, duration: 500.ms)
        .slideY(begin: 0.1, end: 0, delay: 300.ms, duration: 500.ms);
  }

  // =============================================
  // Quick Actions Grid
  // =============================================
  Widget _buildQuickActions(NeuroProfile profile) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 400),
          style: TextStyle(
            fontFamily: profile.fontFamily,
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: profile.textColor,
            letterSpacing: profile.letterSpacing,
          ),
          child: const Text('Quick Actions'),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            _QuickActionCard(
              icon: Icons.auto_stories_rounded,
              label: 'Deep Dive',
              color: const Color(0xFF7C4DFF),
              delay: 400,
              onTap: () {
                if (_searchController.text.isNotEmpty) {
                  _onSearchSubmitted(_searchController.text);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Type a topic in the search bar first!')),
                  );
                }
              },
            ),
            const SizedBox(width: 12),
            _QuickActionCard(
              icon: Icons.bubble_chart_rounded,
              label: 'Hover & Simplify',
              color: const Color(0xFF00BCD4),
              delay: 500,
              onTap: () async {
                final bool status = await FlutterOverlayWindow.isPermissionGranted();
                if (!status) {
                  await _showAssistantSetupSheet();
                } else {
                  await _launchOverlayBubble();
                }
              },
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _QuickActionCard(
              icon: Icons.timer_rounded,
              label: 'Focus Timer',
              color: const Color(0xFFFF7043),
              delay: 600,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const FocusTimerScreen()),
                );
              },
            ),
            const SizedBox(width: 12),
            _QuickActionCard(
              icon: Icons.favorite_rounded,
              label: 'Panic Button',
              color: const Color(0xFFEF5350),
              delay: 700,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const PanicScreen()),
                );
              },
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _QuickActionCard(
              icon: Icons.map_rounded,
              label: 'Quiet Spaces',
              color: const Color(0xFF4DB6AC),
              delay: 800,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const QuietMapScreen()),
                );
              },
            ),
            const SizedBox(width: 12),
            _QuickActionCard(
              icon: Icons.accessibility_new_rounded,
              label: 'Assistant Setup',
              color: const Color(0xFF26A69A),
              delay: 900,
              onTap: () async {
                if (!kIsWeb && Platform.isAndroid) {
                  await _showAssistantSetupSheet();
                } else {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Global overlay setup is Android-only.')),
                  );
                }
              },
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _QuickActionCard(
              icon: Icons.support_agent_rounded,
              label: 'Quick Help',
              color: const Color(0xFF5C6BC0),
              delay: 1000,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const QuickHelpScreen()),
                );
              },
            ),
            const SizedBox(width: 12),
            Expanded(child: Container()),
          ],
        ),
      ],
    );
  }

  // =============================================
  // Study Stats Card
  // =============================================
  Widget _buildStudyStats(NeuroProfile profile) {
    final hours = _totalStudyMinutes ~/ 60;
    final mins = _totalStudyMinutes % 60;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: profile.cardColor,
        borderRadius: BorderRadius.circular(22),
        border: profile.focusBordersEnabled
            ? Border.all(
                color: profile.accentColor.withValues(alpha: 0.15),
                width: 1)
            : null,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF4CAF50).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.timer_rounded,
                color: Color(0xFF4CAF50), size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Total Focus Time',
                  style: TextStyle(
                    fontFamily: profile.fontFamily,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: profile.textColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _totalStudyMinutes == 0
                      ? 'No sessions yet — start a Focus Timer!'
                      : '${hours > 0 ? "${hours}h " : ""}${mins}m across your sessions',
                  style: TextStyle(
                    fontFamily: profile.fontFamily,
                    fontSize: 12,
                    color: profile.textColor.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ),
          Text(
            _totalStudyMinutes > 0 ? '${_totalStudyMinutes}m' : '0m',
            style: TextStyle(
              fontFamily: profile.fontFamily,
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF4CAF50),
            ),
          ),
        ],
      ),
    )
        .animate()
        .fadeIn(delay: 700.ms, duration: 400.ms);
  }

  // =============================================
  // Recent Lessons (from Firebase)
  // =============================================
  Widget _buildRecentLessons(NeuroProfile profile) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 400),
              style: TextStyle(
                fontFamily: profile.fontFamily,
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: profile.textColor,
                letterSpacing: profile.letterSpacing,
              ),
              child: const Text('Recent Lessons'),
            ),
            const Spacer(),
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const LibraryScreen()),
                ).then((_) => _loadRecentData());
              },
              child: Text(
                'See All →',
                style: TextStyle(
                  fontFamily: profile.fontFamily,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: profile.accentColor,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (_recentLessons.isEmpty)
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const LibraryScreen()),
              );
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 400),
              width: double.infinity,
              padding:
                  const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
              decoration: BoxDecoration(
                color: profile.cardColor,
                borderRadius: BorderRadius.circular(20),
                border: profile.focusBordersEnabled
                    ? Border.all(
                        color:
                            profile.accentColor.withValues(alpha: 0.15),
                        width: 1,
                      )
                    : null,
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: profile.accentColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(Icons.auto_awesome_motion_rounded,
                        color: profile.accentColor, size: 28),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Your Library is Empty',
                          style: TextStyle(
                            fontFamily: profile.fontFamily,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: profile.textColor,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Search a topic above to generate & save your first lesson.',
                          style: TextStyle(
                            fontFamily: profile.fontFamily,
                            fontSize: 12,
                            color:
                                profile.textColor.withValues(alpha: 0.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            )
                .animate()
                .fadeIn(
                    delay: Duration(milliseconds: 800),
                    duration: 500.ms),
          )
        else
          ..._recentLessons.asMap().entries.map((entry) {
            final index = entry.key;
            final lesson = entry.value;
            final title = lesson['title'] ?? 'Untitled';
            final profileUsed = lesson['profileUsed'] ?? 'ADHD';
            final createdAt = lesson['createdAt'] ?? '';

            String dateStr = '';
            try {
              final date = DateTime.parse(createdAt);
              final diff = DateTime.now().difference(date);
              if (diff.inMinutes < 60) {
                dateStr = '${diff.inMinutes}m ago';
              } else if (diff.inHours < 24) {
                dateStr = '${diff.inHours}h ago';
              } else {
                dateStr = '${diff.inDays}d ago';
              }
            } catch (_) {}

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: profile.cardColor,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: profile.accentColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.auto_stories_rounded,
                        color: profile.accentColor, size: 20),
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
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: profile.textColor,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${profileUsed.toUpperCase()} $dateStr',
                          style: TextStyle(
                            fontFamily: profile.fontFamily,
                            fontSize: 11,
                            color:
                                profile.textColor.withValues(alpha: 0.4),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded,
                      color: profile.textColor.withValues(alpha: 0.2),
                      size: 20),
                ],
              ),
            )
                .animate()
                .fadeIn(
                    delay: Duration(milliseconds: 800 + (index * 100)),
                    duration: 400.ms);
          }),
      ],
    )
        .animate()
        .fadeIn(delay: Duration(milliseconds: 750), duration: 400.ms);
  }

  // =============================================
  // Backend Status Card
  // =============================================
  Widget _buildBackendStatus(NeuroProfile profile) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: profile.cardColor.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _isConnected
                  ? const Color(0xFF4CAF50)
                  : const Color(0xFFFFA726),
              boxShadow: [
                BoxShadow(
                  color: (_isConnected
                          ? const Color(0xFF4CAF50)
                          : const Color(0xFFFFA726))
                      .withValues(alpha: 0.4),
                  blurRadius: 6,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 400),
              style: TextStyle(
                fontFamily: profile.fontFamily,
                fontSize: 12,
                color: profile.textColor.withValues(alpha: 0.4),
              ),
              child: Text(
                _isConnected
                    ? 'Backend online v$_backendVersion • ${ApiService.baseUrl}'
                    : 'Backend offline • running in local mode',
              ),
            ),
          ),
        ],
      ),
    )
        .animate()
        .fadeIn(delay: 900.ms, duration: 400.ms);
  }

  // =============================================
  // Profile Switcher Bottom Sheet
  // =============================================
  void _showProfileSwitcher(BuildContext context) {
    final themeProvider =
        Provider.of<NeuroThemeProvider>(context, listen: false);
    final profile = themeProvider.activeProfile;

    showModalBottomSheet(
      context: context,
      backgroundColor: profile.cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: profile.textColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Switch Profile',
                style: TextStyle(
                  fontFamily: profile.fontFamily,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: profile.textColor,
                ),
              ),
              const SizedBox(height: 16),
              _ProfileOption(
                label: '⚡ ADHD',
                subtitle: 'Gamified, fast, focus borders',
                type: NeuroProfileType.adhd,
                isActive:
                    profile.profileType == NeuroProfileType.adhd,
              ),
              const SizedBox(height: 10),
              _ProfileOption(
                label: '📖 Dyslexia',
                subtitle: 'Large fonts, spacing, warm tones',
                type: NeuroProfileType.dyslexia,
                isActive:
                    profile.profileType == NeuroProfileType.dyslexia,
              ),
              const SizedBox(height: 10),
              _ProfileOption(
                label: '🧩 Autism',
                subtitle: 'Calm, structured, low contrast',
                type: NeuroProfileType.autism,
                isActive:
                    profile.profileType == NeuroProfileType.autism,
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }
}

// =============================================
// Quick Action Card
// =============================================

class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final int delay;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.delay,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final profile =
        Provider.of<NeuroThemeProvider>(context).activeProfile;

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 400),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: profile.cardColor,
            borderRadius: BorderRadius.circular(20),
            border: profile.focusBordersEnabled
                ? Border.all(
                    color: color.withValues(alpha: 0.2),
                    width: 1,
                  )
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(height: 12),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 400),
                style: TextStyle(
                  fontFamily: profile.fontFamily,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: profile.textColor,
                  letterSpacing: profile.letterSpacing,
                ),
                child: Text(label),
              ),
            ],
          ),
        )
            .animate()
            .fadeIn(delay: Duration(milliseconds: delay), duration: 400.ms)
            .scale(
              begin: const Offset(0.95, 0.95),
              end: const Offset(1.0, 1.0),
              delay: Duration(milliseconds: delay),
              duration: 400.ms,
            ),
      ),
    );
  }
}

// =============================================
// Profile Option Tile
// =============================================

class _ProfileOption extends StatelessWidget {
  final String label;
  final String subtitle;
  final NeuroProfileType type;
  final bool isActive;

  const _ProfileOption({
    required this.label,
    required this.subtitle,
    required this.type,
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    final themeProvider =
        Provider.of<NeuroThemeProvider>(context, listen: false);
    final profile = themeProvider.activeProfile;

    return GestureDetector(
      onTap: () {
        themeProvider.setProfileType(type);
        Navigator.pop(context);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isActive
              ? profile.accentColor.withValues(alpha: 0.1)
              : profile.backgroundColor.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isActive
                ? profile.accentColor.withValues(alpha: 0.4)
                : Colors.transparent,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontFamily: profile.fontFamily,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: profile.textColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontFamily: profile.fontFamily,
                      fontSize: 12,
                      color: profile.textColor.withValues(alpha: 0.4),
                    ),
                  ),
                ],
              ),
            ),
            if (isActive)
              Icon(Icons.check_circle_rounded,
                  color: profile.accentColor, size: 22),
          ],
        ),
      ),
    );
  }
}
