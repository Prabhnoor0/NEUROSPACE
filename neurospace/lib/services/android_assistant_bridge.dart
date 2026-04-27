import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter/services.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';

/// Bridge between Flutter and native Android assistant features.
/// Provides overlay control, permission checks, and accessibility service management.
/// All methods are safe to call on non-Android platforms (they return graceful defaults).
class AndroidAssistantBridge {
  static const MethodChannel _channel =
      MethodChannel('neurospace/android_assistant');

  static bool get _isAndroidNative => !kIsWeb && Platform.isAndroid;

  // ══════════════════════════════════════════════
  //  OVERLAY PERMISSION
  // ══════════════════════════════════════════════

  /// Check if "Draw over other apps" permission is granted.
  static Future<bool> isOverlayPermissionGranted() async {
    if (!_isAndroidNative) return false;
    try {
      return await FlutterOverlayWindow.isPermissionGranted();
    } catch (e) {
      debugPrint('Overlay permission check failed: $e');
      return false;
    }
  }

  /// Request the overlay permission (opens Android Settings).
  static Future<void> requestOverlayPermission() async {
    if (!_isAndroidNative) return;
    try {
      await FlutterOverlayWindow.requestPermission();
    } catch (e) {
      debugPrint('Overlay permission request failed: $e');
      // Fallback to native channel
      try {
        await _channel.invokeMethod('requestOverlayPermission');
      } catch (_) {}
    }
  }

  // ══════════════════════════════════════════════
  //  OVERLAY LIFECYCLE
  // ══════════════════════════════════════════════

  /// Start the floating overlay bubble.
  static Future<bool> startOverlay() async {
    if (!_isAndroidNative) return false;
    try {
      final granted = await isOverlayPermissionGranted();
      if (!granted) return false;

      await FlutterOverlayWindow.showOverlay(
        enableDrag: false,
        overlayTitle: "NeuroSpace",
        overlayContent: "Tap the bubble for accessibility tools",
        flag: OverlayFlag.defaultFlag,
        visibility: NotificationVisibility.visibilityPublic,
        positionGravity: PositionGravity.right,
        width: 80,
        height: 80,
      );
      return true;
    } catch (e) {
      debugPrint('Start overlay failed: $e');
      return false;
    }
  }

  /// Stop the floating overlay bubble.
  static Future<void> stopOverlay() async {
    if (!_isAndroidNative) return;
    try {
      final active = await isOverlayActive();
      if (active) {
        await FlutterOverlayWindow.closeOverlay();
      }
    } catch (e) {
      debugPrint('Stop overlay failed: $e');
    }
  }

  /// Check if the overlay is currently showing.
  static Future<bool> isOverlayActive() async {
    if (!_isAndroidNative) return false;
    try {
      return await FlutterOverlayWindow.isActive();
    } catch (e) {
      debugPrint('Overlay active check failed: $e');
      return false;
    }
  }

  // ══════════════════════════════════════════════
  //  ACCESSIBILITY SERVICE
  // ══════════════════════════════════════════════

  /// Open Android Accessibility Settings.
  static Future<void> openAccessibilitySettings() async {
    if (!_isAndroidNative) return;
    try {
      await _channel.invokeMethod('openAccessibilitySettings');
    } catch (e) {
      debugPrint('Open accessibility settings failed: $e');
    }
  }

  /// Open overlay permission settings screen.
  static Future<void> openOverlaySettings() async {
    if (!_isAndroidNative) return;
    try {
      await _channel.invokeMethod('openOverlaySettings');
    } catch (e) {
      debugPrint('Open overlay settings failed: $e');
    }
  }

  /// Check if NeuroAccessibilityService is enabled.
  static Future<bool> isAccessibilityServiceEnabled() async {
    if (!_isAndroidNative) return false;
    try {
      final enabled =
          await _channel.invokeMethod<bool>('isAccessibilityServiceEnabled');
      return enabled ?? false;
    } catch (e) {
      debugPrint('Accessibility service check failed: $e');
      return false;
    }
  }
}
