import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../providers/neuro_theme_provider.dart';
import '../services/location_service.dart';
import 'maps_screen.dart';

class QuickHelpScreen extends StatefulWidget {
  const QuickHelpScreen({super.key});

  @override
  State<QuickHelpScreen> createState() => _QuickHelpScreenState();
}

class _QuickHelpScreenState extends State<QuickHelpScreen> {
  final FlutterTts _tts = FlutterTts();

  bool _loading = false;
  Position? _position;
  String _contact = '';

  @override
  void initState() {
    super.initState();
    _loadContact();
  }

  @override
  void dispose() {
    _tts.stop();
    super.dispose();
  }

  Future<void> _loadContact() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString('emergency_contact') ?? '';
    if (!mounted) return;
    setState(() => _contact = value);
  }

  /// Get device location using the centralized LocationService.
  /// Shows permission dialogs automatically if needed.
  Future<Position?> _ensureLocation() async {
    if (!mounted) return _position;
    final pos = await LocationService.getCurrentLocation(context);
    if (pos != null && mounted) {
      setState(() => _position = pos);
    }
    return pos ?? _position;
  }

  Future<void> _openNearbyHospitals() async {
    setState(() => _loading = true);
    final pos = await _ensureLocation();
    setState(() => _loading = false);

    final Uri uri;
    if (pos != null) {
      // Use @lat,lng,zoom format — this centers Google Maps on the actual
      // device coordinates and searches "hospital" in that area.
      uri = Uri.parse(
        'https://www.google.com/maps/search/hospital/@${pos.latitude},${pos.longitude},15z',
      );
    } else {
      // Fallback: generic search (will use Google Maps' own location)
      uri = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent("hospital near me")}',
      );
    }
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _shareLocation() async {
    final pos = await _ensureLocation();
    if (pos == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Location unavailable. Please enable location services.')),
      );
      return;
    }

    final message = 'I need help. My current location: '
        'https://maps.google.com/?q=${pos.latitude},${pos.longitude}';

    final sms = Uri.parse('sms:${_contact.isNotEmpty ? _contact : ''}?body=${Uri.encodeComponent(message)}');
    await launchUrl(sms, mode: LaunchMode.externalApplication);
  }

  Future<void> _callEmergency() async {
    final target = _contact.isNotEmpty ? _contact : '112';
    final uri = Uri.parse('tel:$target');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _speakLocation() async {
    final pos = await _ensureLocation();
    final text = pos == null
        ? 'I could not get your location right now.'
        : 'Your current location is latitude ${pos.latitude.toStringAsFixed(4)} and longitude ${pos.longitude.toStringAsFixed(4)}.';

    await _tts.setSpeechRate(0.45);
    await _tts.speak(text);
  }

  @override
  Widget build(BuildContext context) {
    final profile = Provider.of<NeuroThemeProvider>(context).activeProfile;

    return Scaffold(
      backgroundColor: profile.backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: profile.textColor),
        title: Text(
          'Quick Help',
          style: TextStyle(
            fontFamily: profile.fontFamily,
            color: profile.textColor,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
            children: [
              _helpCard(
                profile,
                icon: Icons.local_hospital_rounded,
                title: 'Nearby Hospital',
                subtitle: 'Open emergency medical locations in maps',
                color: const Color(0xFFEF5350),
                onTap: _openNearbyHospitals,
              ),
              const SizedBox(height: 10),
              _helpCard(
                profile,
                icon: Icons.map_rounded,
                title: 'Safe Quiet Place',
                subtitle: 'Open nearby calm spaces finder',
                color: const Color(0xFF4DB6AC),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const QuietMapScreen()),
                  );
                },
              ),
              const SizedBox(height: 10),
              _helpCard(
                profile,
                icon: Icons.call_rounded,
                title: 'Emergency Contact',
                subtitle: _contact.isNotEmpty
                    ? 'Call $_contact'
                    : 'No saved contact, calling 112 fallback',
                color: const Color(0xFFFF7043),
                onTap: _callEmergency,
              ),
              const SizedBox(height: 10),
              _helpCard(
                profile,
                icon: Icons.share_location_rounded,
                title: 'Share My Location',
                subtitle: 'Send your live coordinates via SMS',
                color: const Color(0xFF5C6BC0),
                onTap: _shareLocation,
              ),
              const SizedBox(height: 10),
              _helpCard(
                profile,
                icon: Icons.record_voice_over_rounded,
                title: 'Read Current Location',
                subtitle: 'Speak your current coordinates aloud',
                color: const Color(0xFF26A69A),
                onTap: _speakLocation,
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: profile.cardColor,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: profile.accentColor.withValues(alpha: 0.12)),
                ),
                child: Text(
                  'Tip: Save an emergency contact in Settings for one-tap calling and location sharing.',
                  style: TextStyle(
                    fontFamily: profile.fontFamily,
                    fontSize: 13,
                    color: profile.textColor.withValues(alpha: 0.7),
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ),
          if (_loading)
            Positioned.fill(
              child: Container(
                color: Colors.black.withValues(alpha: 0.25),
                child: const Center(child: CircularProgressIndicator()),
              ),
            ),
        ],
      ),
    );
  }

  Widget _helpCard(
    dynamic profile, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: profile.cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontFamily: profile.fontFamily,
                      fontSize: profile.fontSize,
                      fontWeight: FontWeight.w700,
                      color: profile.textColor,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontFamily: profile.fontFamily,
                      fontSize: 12,
                      color: profile.textColor.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded, size: 14, color: profile.textColor.withValues(alpha: 0.4)),
          ],
        ),
      ),
    );
  }
}
