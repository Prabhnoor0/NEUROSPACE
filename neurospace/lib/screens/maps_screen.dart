import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:geolocator/geolocator.dart';
import '../providers/neuro_theme_provider.dart';
import '../services/api_service.dart';

class QuietMapScreen extends StatefulWidget {
  const QuietMapScreen({super.key});

  @override
  State<QuietMapScreen> createState() => _QuietMapScreenState();
}

class _QuietMapScreenState extends State<QuietMapScreen> {
  final MapController _mapController = MapController();
  int _selectedIndex = 0;
  bool _isLoading = true;
  LatLng _currentLocation = const LatLng(37.7749, -122.4194); // Fallback SF

  List<Map<String, dynamic>> _quietPlaces = [];

  @override
  void initState() {
    super.initState();
    _initLocationAndFetchPlaces();
  }

  Future<void> _initLocationAndFetchPlaces() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // Location services disabled, fallback to default and fetch
      await _fetchPlaces(_currentLocation);
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        await _fetchPlaces(_currentLocation);
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      await _fetchPlaces(_currentLocation);
      return;
    }

    try {
      Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.medium);
      _currentLocation = LatLng(position.latitude, position.longitude);
    } catch (e) {
      debugPrint("Error getting location: $e");
      // Fallback
    }

    await _fetchPlaces(_currentLocation);
  }

  Future<void> _fetchPlaces(LatLng loc) async {
    setState(() => _isLoading = true);
    try {
      final results = await ApiService.fetchQuietSpaces(loc.latitude, loc.longitude);
      
      final parsedPlaces = results.map((p) {
        final locData = p['location'] as Map<String, dynamic>;
        
        // Map string icons to IconData
        IconData icon = Icons.park_rounded;
        if (p['image_icon'] == 'cafe') icon = Icons.local_cafe_rounded;
        if (p['image_icon'] == 'library') icon = Icons.local_library_rounded;
        if (p['image_icon'] == 'spa') icon = Icons.spa_rounded;

        return {
          'name': p['name'],
          'category': p['category'] ?? 'Sanctuary',
          'location': LatLng((locData['lat'] as num).toDouble(), (locData['lng'] as num).toDouble()),
          'crowd': p['crowd'] ?? 'Unknown',
          'lighting': p['lighting'] ?? 'Standard',
          'noise': p['noise'] ?? 'Unknown',
          'image_icon': icon,
        };
      }).toList();

      if (mounted) {
        setState(() {
          _quietPlaces = parsedPlaces;
          _isLoading = false;
        });
        
        if (_quietPlaces.isNotEmpty) {
          _mapController.move(_quietPlaces[0]['location'], 14.5);
        } else {
          _mapController.move(loc, 14.0);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  void _onCardChanged(int index) {
    if (_quietPlaces.isEmpty) return;
    setState(() => _selectedIndex = index);
    _mapController.move(_quietPlaces[index]['location'], 15.0);
  }

  @override
  Widget build(BuildContext context) {
    final profile = Provider.of<NeuroThemeProvider>(context).activeProfile;

    return Scaffold(
      backgroundColor: profile.backgroundColor,
      body: Stack(
        children: [
          // 1. OpenStreetMap Layer (dark tile server, no API key needed)
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: LatLng(37.7749, -122.4194),
              initialZoom: 12.0,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all,
              ),
            ),
            children: [
              // Dark tile layer — sensory-friendly low-contrast map
              TileLayer(
                urlTemplate:
                    'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}@2x.png',
                subdomains: const ['a', 'b', 'c', 'd'],
                userAgentPackageName: 'com.neurospace.app',
                maxZoom: 19,
              ),

              // Quiet place markers
              MarkerLayer(
                markers: _quietPlaces.asMap().entries.map((entry) {
                  final index = entry.key;
                  final place = entry.value;
                  final isSelected = index == _selectedIndex;

                  return Marker(
                    width: isSelected ? 48 : 36,
                    height: isSelected ? 48 : 36,
                    point: place['location'],
                    child: GestureDetector(
                      onTap: () => _onCardChanged(index),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? profile.accentColor
                              : profile.cardColor,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected
                                ? Colors.white
                                : profile.accentColor.withValues(alpha: 0.5),
                            width: isSelected ? 3 : 1.5,
                          ),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: profile.accentColor
                                        .withValues(alpha: 0.5),
                                    blurRadius: 12,
                                    spreadRadius: 2,
                                  )
                                ]
                              : [],
                        ),
                        child: Icon(
                          place['image_icon'],
                          color: isSelected
                              ? Colors.white
                              : profile.accentColor,
                          size: isSelected ? 24 : 18,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),

          // 1.5 Loading Overlay
          if (_isLoading)
            Positioned.fill(
              child: Container(
                color: profile.backgroundColor.withValues(alpha: 0.5),
                child: Center(
                  child: CircularProgressIndicator(
                    color: profile.accentColor,
                  ),
                ),
              ),
            ),

          // 2. Custom App Bar Overlay
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.only(
                  top: 50, left: 16, right: 16, bottom: 20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    profile.backgroundColor,
                    profile.backgroundColor.withValues(alpha: 0),
                  ],
                ),
              ),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                          color: profile.cardColor, shape: BoxShape.circle),
                      child: Icon(Icons.arrow_back_ios_new_rounded,
                          color: profile.textColor, size: 20),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    'Quiet Spaces',
                    style: TextStyle(
                      fontFamily: profile.fontFamily,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: profile.textColor,
                      shadows: const [
                        Shadow(color: Colors.black54, blurRadius: 8)
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 3. Place Detail Cards Overlay
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            height: 220,
            child: PageView.builder(
              controller: PageController(viewportFraction: 0.85),
              onPageChanged: _onCardChanged,
              itemCount: _quietPlaces.length,
              itemBuilder: (context, index) {
                final place = _quietPlaces[index];
                final isSelected = index == _selectedIndex;

                return AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: EdgeInsets.only(
                    left: 8,
                    right: 8,
                    top: isSelected ? 0 : 20,
                    bottom: isSelected ? 0 : 20,
                  ),
                  decoration: BoxDecoration(
                    color: profile.cardColor,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: isSelected
                          ? profile.accentColor
                          : Colors.transparent,
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 15,
                        offset: const Offset(0, 10),
                      )
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: profile.accentColor
                                    .withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(place['image_icon'],
                                  color: profile.accentColor),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    place['category'].toUpperCase(),
                                    style: TextStyle(
                                      fontFamily: profile.fontFamily,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      color: profile.accentColor,
                                      letterSpacing: 1.5,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    place['name'],
                                    style: TextStyle(
                                      fontFamily: profile.fontFamily,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: profile.textColor,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _buildInfoChip(
                                Icons.groups_rounded, place['crowd'], profile),
                            _buildInfoChip(Icons.volume_off_rounded,
                                place['noise'], profile),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _buildInfoChip(Icons.wb_sunny_rounded,
                            place['lighting'], profile),
                      ],
                    ),
                  ),
                );
              },
            ),
          )
              .animate()
              .slideY(
                  begin: 1.0,
                  end: 0.0,
                  curve: Curves.easeOutBack,
                  duration: 800.ms),
        ],
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String text, dynamic profile) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon,
            size: 14, color: profile.textColor.withValues(alpha: 0.5)),
        const SizedBox(width: 6),
        Text(
          text,
          style: TextStyle(
            fontFamily: profile.fontFamily,
            fontSize: 12,
            color: profile.textColor.withValues(alpha: 0.8),
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}
