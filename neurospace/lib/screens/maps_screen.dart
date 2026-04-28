import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../providers/neuro_theme_provider.dart';
import '../services/api_service.dart';
import '../services/location_service.dart';

/// Logging helper
void _log(String msg) => debugPrint('[QuietMap] $msg');

enum _PlacesViewMode { map, list }

class QuietMapScreen extends StatefulWidget {
  const QuietMapScreen({super.key});

  @override
  State<QuietMapScreen> createState() => _QuietMapScreenState();
}

class _QuietMapScreenState extends State<QuietMapScreen> {
  final MapController _mapController = MapController();
  final Distance _distance = const Distance();

  _PlacesViewMode _viewMode = _PlacesViewMode.map;
  int _selectedIndex = 0;
  bool _isLoading = true;
  LatLng _currentLocation = const LatLng(28.6139, 77.2090); // Fallback: New Delhi
  bool _locationAcquired = false;
  String? _locationError;

  final Set<String> _activeFilters = <String>{};
  List<Map<String, dynamic>> _quietPlaces = [];

  static const List<String> _filterOrder = [
    'quiet',
    'indoor',
    'wheelchair',
    'low_crowd',
    'accessible_entrance',
  ];

  static const Map<String, String> _filterLabels = {
    'quiet': 'Quiet',
    'indoor': 'Indoor',
    'wheelchair': 'Wheelchair',
    'low_crowd': 'Low Crowd',
    'accessible_entrance': 'Accessible Entrance',
  };

  @override
  void initState() {
    super.initState();
    _initLocationAndFetchPlaces();
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _filteredPlaces {
    return _quietPlaces.where((p) {
      for (final filter in _activeFilters) {
        if (!_matchesFilter(p, filter)) {
          return false;
        }
      }
      return true;
    }).toList();
  }

  bool _matchesFilter(Map<String, dynamic> place, String filter) {
    final noise = (place['noise'] ?? '').toString().toLowerCase();
    final crowd = (place['crowd'] ?? '').toString().toLowerCase();
    final category = (place['category'] ?? '').toString().toLowerCase();

    switch (filter) {
      case 'quiet':
        return noise.contains('quiet') ||
            noise.contains('low') ||
            noise.contains('silent');
      case 'indoor':
        return category.contains('library') ||
            category.contains('cafe') ||
            category.contains('indoor');
      case 'wheelchair':
        return place['wheelchair_friendly'] == true;
      case 'low_crowd':
        return crowd.contains('low') || crowd.contains('light') || crowd.contains('calm');
      case 'accessible_entrance':
        return place['accessible_entrance'] == true;
      default:
        return true;
    }
  }

  void _toggleFilter(String filter) {
    setState(() {
      if (_activeFilters.contains(filter)) {
        _activeFilters.remove(filter);
      } else {
        _activeFilters.add(filter);
      }
      _selectedIndex = 0;
    });

    final filtered = _filteredPlaces;
    if (filtered.isNotEmpty) {
      _mapController.move(filtered.first['location'] as LatLng, 14.5);
    }
  }

  Future<void> _initLocationAndFetchPlaces() async {
    _log('Starting location acquisition via LocationService...');

    if (!mounted) return;

    final position = await LocationService.getCurrentLocation(context);

    if (position != null) {
      _currentLocation = LatLng(position.latitude, position.longitude);
      _locationAcquired = true;
      _locationError = null;
      _log('GPS fix acquired: ${position.latitude}, ${position.longitude}');
    } else {
      _log('Location unavailable — using fallback: ${_currentLocation.latitude}, ${_currentLocation.longitude}');
      if (!_locationAcquired) {
        setState(() => _locationError = 'Location unavailable');
      }
    }

    _log('Final location: ${_currentLocation.latitude}, ${_currentLocation.longitude} (acquired: $_locationAcquired)');
    await _fetchPlaces(_currentLocation);
  }

  Future<void> _fetchPlaces(LatLng loc) async {
    setState(() => _isLoading = true);
    try {
      final results = await ApiService.fetchQuietSpaces(loc.latitude, loc.longitude);

      final parsedPlaces = results.map((p) {
        final locData = p['location'] as Map<String, dynamic>? ?? {};
        final lat = (locData['lat'] as num?)?.toDouble() ?? _currentLocation.latitude;
        final lng = (locData['lng'] as num?)?.toDouble() ?? _currentLocation.longitude;
        final placeLoc = LatLng(lat, lng);

        IconData icon = Icons.park_rounded;
        final rawIcon = (p['image_icon'] ?? '').toString().toLowerCase();
        if (rawIcon == 'cafe') icon = Icons.local_cafe_rounded;
        if (rawIcon == 'library') icon = Icons.local_library_rounded;
        if (rawIcon == 'spa') icon = Icons.spa_rounded;

        final distanceKm = _distance.as(LengthUnit.Kilometer, _currentLocation, placeLoc);

        return {
          'name': (p['name'] ?? 'Unnamed Quiet Spot').toString(),
          'category': (p['category'] ?? 'Sanctuary').toString(),
          'location': placeLoc,
          'crowd': (p['crowd'] ?? 'Unknown').toString(),
          'lighting': (p['lighting'] ?? 'Standard').toString(),
          'noise': (p['noise'] ?? 'Unknown').toString(),
          'rating': ((p['rating'] as num?)?.toDouble() ?? 4.2),
          'wheelchair_friendly': p['wheelchair_friendly'] == true,
          'accessible_entrance': p['accessible_entrance'] == true,
          'distance_km': distanceKm,
          'image_icon': icon,
        };
      }).toList();

      if (!mounted) return;

      setState(() {
        _quietPlaces = parsedPlaces;
        _isLoading = false;
        _selectedIndex = 0;
      });

      final filtered = _filteredPlaces;
      if (filtered.isNotEmpty) {
        _mapController.move(filtered.first['location'] as LatLng, 14.5);
      } else {
        _mapController.move(loc, 14.0);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  void _onCardChanged(int index) {
    final filtered = _filteredPlaces;
    if (filtered.isEmpty || index >= filtered.length) return;

    setState(() => _selectedIndex = index);
    _mapController.move(filtered[index]['location'] as LatLng, 15.0);
  }

  @override
  Widget build(BuildContext context) {
    final profile = Provider.of<NeuroThemeProvider>(context).activeProfile;
    final filtered = _filteredPlaces;

    if (_selectedIndex >= filtered.length && filtered.isNotEmpty) {
      _selectedIndex = 0;
    }

    return Scaffold(
      backgroundColor: profile.backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(profile),
            _buildViewToggle(profile),
            _buildFilters(profile),
            Expanded(
              child: _isLoading
                  ? Center(
                      child: CircularProgressIndicator(color: profile.accentColor),
                    )
                  : filtered.isEmpty
                      ? _buildEmptyState(profile)
                      : _viewMode == _PlacesViewMode.map
                          ? _buildMapMode(profile, filtered)
                          : _buildListMode(profile, filtered),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(dynamic profile) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: profile.cardColor,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.arrow_back_ios_new_rounded,
                color: profile.textColor,
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Quiet Spaces',
                  style: TextStyle(
                    fontFamily: profile.fontFamily,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: profile.textColor,
                  ),
                ),
                Text(
                  'Find calm, low-stimulation places nearby',
                  style: TextStyle(
                    fontFamily: profile.fontFamily,
                    fontSize: 12,
                    color: profile.textColor.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildViewToggle(dynamic profile) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: profile.cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: profile.accentColor.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _toggleButton(
              profile: profile,
              label: 'Map View',
              icon: Icons.map_rounded,
              selected: _viewMode == _PlacesViewMode.map,
              onTap: () => setState(() => _viewMode = _PlacesViewMode.map),
            ),
          ),
          Expanded(
            child: _toggleButton(
              profile: profile,
              label: 'List View',
              icon: Icons.view_list_rounded,
              selected: _viewMode == _PlacesViewMode.list,
              onTap: () => setState(() => _viewMode = _PlacesViewMode.list),
            ),
          ),
        ],
      ),
    );
  }

  Widget _toggleButton({
    required dynamic profile,
    required String label,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? profile.accentColor.withValues(alpha: 0.18) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: selected ? profile.accentColor : profile.textColor.withValues(alpha: 0.5),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontFamily: profile.fontFamily,
                fontSize: 13,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? profile.accentColor : profile.textColor.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilters(dynamic profile) {
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: _filterOrder.map((filter) {
          final active = _activeFilters.contains(filter);
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              selected: active,
              label: Text(_filterLabels[filter] ?? filter),
              onSelected: (_) => _toggleFilter(filter),
              showCheckmark: false,
              backgroundColor: profile.cardColor,
              selectedColor: profile.accentColor.withValues(alpha: 0.16),
              labelStyle: TextStyle(
                fontFamily: profile.fontFamily,
                color: active ? profile.accentColor : profile.textColor.withValues(alpha: 0.7),
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                fontSize: 12,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22),
                side: BorderSide(
                  color: active
                      ? profile.accentColor.withValues(alpha: 0.35)
                      : profile.accentColor.withValues(alpha: 0.12),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  void _recenterOnMe() {
    _mapController.move(_currentLocation, 14.0);
  }

  Widget _buildMapMode(dynamic profile, List<Map<String, dynamic>> places) {
    // Build place markers
    final placeMarkers = places.asMap().entries.map((entry) {
      final index = entry.key;
      final place = entry.value;
      final isSelected = index == _selectedIndex;

      return Marker(
        width: isSelected ? 48 : 36,
        height: isSelected ? 48 : 36,
        point: place['location'] as LatLng,
        child: GestureDetector(
          onTap: () => _onCardChanged(index),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            decoration: BoxDecoration(
              color: isSelected ? profile.accentColor : profile.cardColor,
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected ? Colors.white : profile.accentColor.withValues(alpha: 0.45),
                width: isSelected ? 3 : 1.5,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: profile.accentColor.withValues(alpha: 0.5),
                        blurRadius: 12,
                        spreadRadius: 2,
                      ),
                    ]
                  : [],
            ),
            child: Icon(
              place['image_icon'] as IconData,
              color: isSelected ? Colors.white : profile.accentColor,
              size: isSelected ? 24 : 18,
            ),
          ),
        ),
      );
    }).toList();

    // Add "my location" marker (blue pulsing dot)
    final myLocationMarker = Marker(
      width: 28,
      height: 28,
      point: _currentLocation,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.blue,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 3),
          boxShadow: [
            BoxShadow(
              color: Colors.blue.withValues(alpha: 0.45),
              blurRadius: 12,
              spreadRadius: 4,
            ),
          ],
        ),
      ),
    );

    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: _currentLocation,
            initialZoom: 13.0,
            interactionOptions: const InteractionOptions(flags: InteractiveFlag.all),
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.neurospace.app',
              maxZoom: 19,
            ),
            MarkerLayer(
              markers: [myLocationMarker, ...placeMarkers],
            ),
          ],
        ),
        // Location error banner
        if (_locationError != null)
          Positioned(
            top: 8,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.orange.shade800,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Using approximate location • $_locationError',
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ),
        // Re-center button
        Positioned(
          top: _locationError != null ? 56 : 12,
          right: 16,
          child: GestureDetector(
            onTap: _recenterOnMe,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: profile.cardColor,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: Icon(Icons.my_location_rounded, color: profile.accentColor, size: 22),
            ),
          ),
        ),
        // Place cards
        Positioned(
          bottom: 24,
          left: 0,
          right: 0,
          height: 228,
          child: PageView.builder(
            controller: PageController(viewportFraction: 0.88),
            onPageChanged: _onCardChanged,
            itemCount: places.length,
            itemBuilder: (context, index) {
              final place = places[index];
              final isSelected = index == _selectedIndex;
              return _buildPlaceCard(profile, place, isSelected: isSelected);
            },
          ),
        ).animate().slideY(begin: 1, end: 0, duration: 700.ms, curve: Curves.easeOutBack),
      ],
    );
  }

  Widget _buildListMode(dynamic profile, List<Map<String, dynamic>> places) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
      itemCount: places.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final place = places[index];
        return GestureDetector(
          onTap: () {
            _onCardChanged(index);
            setState(() => _viewMode = _PlacesViewMode.map);
          },
          child: _buildPlaceCard(profile, place, isSelected: false),
        );
      },
    );
  }

  Widget _buildPlaceCard(dynamic profile, Map<String, dynamic> place, {required bool isSelected}) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 260),
      margin: EdgeInsets.only(
        left: 8,
        right: 8,
        top: isSelected ? 0 : 8,
        bottom: isSelected ? 0 : 8,
      ),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: profile.cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isSelected ? profile.accentColor : profile.accentColor.withValues(alpha: 0.08),
          width: isSelected ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.22),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: profile.accentColor.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(place['image_icon'] as IconData, color: profile.accentColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      (place['category'] as String).toUpperCase(),
                      style: TextStyle(
                        fontFamily: profile.fontFamily,
                        fontSize: 10,
                        letterSpacing: 1.4,
                        fontWeight: FontWeight.w800,
                        color: profile.accentColor,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      place['name'] as String,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: profile.fontFamily,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: profile.textColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 14,
            runSpacing: 8,
            children: [
              _infoText(profile, Icons.route_rounded, '${(place['distance_km'] as double).toStringAsFixed(1)} km'),
              _infoText(profile, Icons.star_rounded, (place['rating'] as double).toStringAsFixed(1)),
              _infoText(profile, Icons.volume_off_rounded, place['noise'] as String),
              _infoText(profile, Icons.groups_rounded, place['crowd'] as String),
              _infoText(profile, Icons.wb_sunny_rounded, place['lighting'] as String),
            ],
          ),
        ],
      ),
    );
  }

  Widget _infoText(dynamic profile, IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: profile.textColor.withValues(alpha: 0.55)),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(
            fontFamily: profile.fontFamily,
            fontSize: 12,
            color: profile.textColor.withValues(alpha: 0.75),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(dynamic profile) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off_rounded, size: 52, color: profile.textColor.withValues(alpha: 0.35)),
            const SizedBox(height: 12),
            Text(
              'No places match your current filters.',
              style: TextStyle(
                fontFamily: profile.fontFamily,
                fontSize: profile.fontSize,
                color: profile.textColor.withValues(alpha: 0.7),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Try turning off one or two filters.',
              style: TextStyle(
                fontFamily: profile.fontFamily,
                fontSize: 12,
                color: profile.textColor.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
