/// NeuroSpace — Centralized Location Service
/// Handles all location permission requests and GPS fetching.
/// Shows user-friendly dialogs when permissions are denied.

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

class LocationService {
  static Position? _cachedPosition;

  /// Get the last known/cached position without fetching a new one.
  static Position? get cachedPosition => _cachedPosition;

  /// Request location permission with a user-friendly dialog explaining why.
  /// Returns true if permission is granted, false otherwise.
  static Future<bool> requestPermission(BuildContext context) async {
    // 1. Check if location services are enabled
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (!context.mounted) return false;
      await _showDialog(
        context,
        title: 'Location Services Disabled',
        message:
            'NeuroSpace needs location access to find quiet spaces and '
            'nearby hospitals for you.\n\n'
            'Please enable Location Services in your device settings.',
        actionLabel: 'Open Settings',
        onAction: () => Geolocator.openLocationSettings(),
      );
      return false;
    }

    // 2. Check current permission
    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.deniedForever) {
      if (!context.mounted) return false;
      await _showDialog(
        context,
        title: 'Location Permission Required',
        message:
            'Location access was permanently denied.\n\n'
            'NeuroSpace needs your location to show nearby quiet spaces, '
            'hospitals, and share your location in emergencies.\n\n'
            'Please enable it in App Settings → Permissions → Location.',
        actionLabel: 'Open App Settings',
        onAction: () => Geolocator.openAppSettings(),
      );
      return false;
    }

    if (permission == LocationPermission.denied) {
      // Show a rationale dialog BEFORE the system dialog
      if (!context.mounted) return false;
      final shouldRequest = await _showRationaleDialog(context);
      if (!shouldRequest) return false;

      // Now trigger the system permission dialog
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return false;
      }
      if (permission == LocationPermission.deniedForever) {
        if (!context.mounted) return false;
        await _showDialog(
          context,
          title: 'Permission Denied',
          message:
              'Location access was denied. You can enable it later '
              'from App Settings → Permissions → Location.',
          actionLabel: 'Open App Settings',
          onAction: () => Geolocator.openAppSettings(),
        );
        return false;
      }
    }

    // Permission is whileInUse or always — granted!
    return true;
  }

  /// Fetch the device's current GPS location.
  /// Requests permission if needed (shows dialogs).
  /// Returns null if permission denied or GPS unavailable.
  static Future<Position?> getCurrentLocation(BuildContext context) async {
    final hasPermission = await requestPermission(context);
    if (!hasPermission) return _cachedPosition;

    // Try last known first (instant)
    try {
      final lastKnown = await Geolocator.getLastKnownPosition();
      if (lastKnown != null) {
        _cachedPosition = lastKnown;
        debugPrint('[LocationService] Last known: ${lastKnown.latitude}, ${lastKnown.longitude}');
      }
    } catch (e) {
      debugPrint('[LocationService] getLastKnownPosition error: $e');
    }

    // Get fresh high-accuracy GPS fix
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: AndroidSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 0,
          forceLocationManager: false,
          timeLimit: const Duration(seconds: 15),
        ),
      ).timeout(const Duration(seconds: 20));

      _cachedPosition = position;
      debugPrint('[LocationService] GPS fix: ${position.latitude}, ${position.longitude}');
      return position;
    } catch (e) {
      debugPrint('[LocationService] getCurrentPosition error: $e');
      // Return cached if fresh fix fails
      return _cachedPosition;
    }
  }

  /// Show a rationale dialog explaining why location is needed.
  /// Returns true if user wants to proceed, false if they cancel.
  static Future<bool> _showRationaleDialog(BuildContext context) async {
    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Row(
              children: [
                Icon(Icons.location_on_rounded, color: Color(0xFF4DB6AC), size: 28),
                SizedBox(width: 10),
                Text('Allow Location'),
              ],
            ),
            content: const Text(
              'NeuroSpace uses your location to:\n\n'
              '📍 Find quiet, sensory-friendly spaces near you\n'
              '🏥 Locate nearby hospitals in emergencies\n'
              '📤 Share your coordinates with trusted contacts\n\n'
              'Your location data stays on your device and is never stored.',
              style: TextStyle(fontSize: 14, height: 1.5),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Not Now', style: TextStyle(color: Colors.grey)),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF4DB6AC),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Allow Location'),
              ),
            ],
          ),
        ) ??
        false;
  }

  /// Show an info/action dialog.
  static Future<void> _showDialog(
    BuildContext context, {
    required String title,
    required String message,
    required String actionLabel,
    required VoidCallback onAction,
  }) async {
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.location_off_rounded, color: Colors.orange, size: 28),
            const SizedBox(width: 10),
            Expanded(child: Text(title, style: const TextStyle(fontSize: 18))),
          ],
        ),
        content: Text(message, style: const TextStyle(fontSize: 14, height: 1.5)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              onAction();
            },
            style: FilledButton.styleFrom(
              backgroundColor: Colors.orange,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(actionLabel),
          ),
        ],
      ),
    );
  }
}
