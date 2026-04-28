/// NeuroSpace — Resource Allocation Assistant Dashboard
/// Main hub for finding resources, booking sessions, discovering NGOs,
/// and viewing history. Accessibility-first, calm UI.

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../models/neuro_profile.dart';
import '../models/resource_models.dart';
import '../providers/neuro_theme_provider.dart';
import '../services/firebase_service.dart';
import '../services/location_service.dart';
import '../services/resource_service.dart';
import 'resource_results_screen.dart';
import 'resource_ngos_screen.dart';
import 'resource_history_screen.dart';

class ResourceDashboardScreen extends StatefulWidget {
  const ResourceDashboardScreen({super.key});

  @override
  State<ResourceDashboardScreen> createState() =>
      _ResourceDashboardScreenState();
}

class _ResourceDashboardScreenState extends State<ResourceDashboardScreen> {
  // Form state
  String _selectedCategory = 'education';
  String _selectedUrgency = 'medium';
  String _selectedBudget = 'any';
  String _selectedMode = 'both';
  String? _selectedDiagnosis;
  String? _selectedAgeGroup;
  bool _isLoading = false;
  double? _lat;
  double? _lng;
  int _upcomingCount = 0;

  final List<String> _diagnoses = ['ADHD', 'Dyslexia', 'Autism', 'Other'];
  final List<String> _ageGroups = ['Child (3-12)', 'Teen (13-17)', 'Adult (18+)'];

  @override
  void initState() {
    super.initState();
    _loadLocation();
    _loadUpcomingCount();
    // Pre-select diagnosis from active profile
    final profileType = Provider.of<NeuroThemeProvider>(context, listen: false)
        .activeProfile
        .profileType;
    if (profileType == NeuroProfileType.adhd) {
      _selectedDiagnosis = 'ADHD';
    } else if (profileType == NeuroProfileType.dyslexia) {
      _selectedDiagnosis = 'Dyslexia';
    } else if (profileType == NeuroProfileType.autism) {
      _selectedDiagnosis = 'Autism';
    }
  }

  Future<void> _loadLocation() async {
    final cached = LocationService.cachedPosition;
    if (cached != null) {
      setState(() {
        _lat = cached.latitude;
        _lng = cached.longitude;
      });
    }
  }

  Future<void> _loadUpcomingCount() async {
    final userId = FirebaseService.currentUserId;
    if (userId == null) return;
    try {
      final bookings = await FirebaseService.getBookings(userId);
      final now = DateTime.now();
      int count = 0;
      for (final b in bookings) {
        final status = b['status'] as String? ?? 'pending';
        if (status == 'cancelled' || status == 'completed') continue;
        final dateStr = b['date'] as String? ?? '';
        try {
          final d = DateTime.parse(dateStr);
          if (!d.isBefore(now)) count++;
        } catch (_) {
          count++;
        }
      }
      if (mounted) setState(() => _upcomingCount = count);
    } catch (_) {}
  }

  Future<void> _findResources() async {
    // Ensure location
    if (_lat == null || _lng == null) {
      if (!mounted) return;
      final pos = await LocationService.getCurrentLocation(context);
      if (pos != null) {
        _lat = pos.latitude;
        _lng = pos.longitude;
      }
    }

    setState(() => _isLoading = true);

    final results = await ResourceService.getRecommendations(
      diagnosis: _selectedDiagnosis,
      urgency: _selectedUrgency,
      budget: _selectedBudget == 'any' ? null : _selectedBudget,
      latitude: _lat,
      longitude: _lng,
      deliveryMode: _selectedMode,
      category: _selectedCategory,
      ageGroup: _selectedAgeGroup,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ResourceResultsScreen(
          results: results,
          diagnosis: _selectedDiagnosis,
          category: _selectedCategory,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profile = Provider.of<NeuroThemeProvider>(context).activeProfile;

    return Scaffold(
      backgroundColor: profile.backgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),
              _buildHeader(profile),
              const SizedBox(height: 24),
              _buildQuickStats(profile),
              const SizedBox(height: 24),
              _buildSectionTitle(profile, '🔍 Find Resources'),
              const SizedBox(height: 14),
              _buildCategorySelector(profile),
              const SizedBox(height: 16),
              _buildDiagnosisSelector(profile),
              const SizedBox(height: 16),
              _buildUrgencySelector(profile),
              const SizedBox(height: 16),
              _buildBudgetSelector(profile),
              const SizedBox(height: 16),
              _buildModeSelector(profile),
              const SizedBox(height: 16),
              _buildAgeGroupSelector(profile),
              const SizedBox(height: 24),
              _buildSearchButton(profile),
              const SizedBox(height: 28),
              _buildQuickNav(profile),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  // =============================================
  // Header
  // =============================================
  Widget _buildHeader(NeuroProfile profile) {
    return Row(
      children: [
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: profile.cardColor,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.arrow_back_ios_new_rounded,
                color: profile.textColor, size: 18),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Resource Assistant',
                style: TextStyle(
                  fontFamily: profile.fontFamily,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: profile.textColor,
                  letterSpacing: profile.letterSpacing,
                ),
              ),
              Text(
                'Find the right support for you',
                style: TextStyle(
                  fontFamily: profile.fontFamily,
                  fontSize: 13,
                  color: profile.textColor.withValues(alpha: 0.55),
                ),
              ),
            ],
          ),
        ),
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                profile.accentColor,
                profile.accentColor.withValues(alpha: 0.7),
              ],
            ),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: profile.accentColor.withValues(alpha: 0.3),
                blurRadius: 12,
              ),
            ],
          ),
          child: const Icon(Icons.health_and_safety_rounded,
              color: Colors.white, size: 22),
        ),
      ],
    )
        .animate()
        .fadeIn(duration: 500.ms)
        .slideY(begin: -0.15, end: 0, duration: 500.ms);
  }

  // =============================================
  // Quick Stats
  // =============================================
  Widget _buildQuickStats(NeuroProfile profile) {
    return Row(
      children: [
        Expanded(
          child: _statCard(
            profile,
            icon: Icons.event_rounded,
            label: 'Upcoming',
            value: '$_upcomingCount',
            color: const Color(0xFF4CAF50),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const ResourceHistoryScreen()),
              ).then((_) => _loadUpcomingCount());
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _statCard(
            profile,
            icon: Icons.volunteer_activism_rounded,
            label: 'NGOs Near You',
            value: 'Find',
            color: const Color(0xFFFF7043),
            onTap: () async {
              if (_lat == null && mounted) {
                final pos = await LocationService.getCurrentLocation(context);
                if (pos != null) {
                  _lat = pos.latitude;
                  _lng = pos.longitude;
                }
              }
              if (!mounted) return;
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ResourceNGOsScreen(
                    latitude: _lat ?? 28.6139,
                    longitude: _lng ?? 77.2090,
                  ),
                ),
              );
            },
          ),
        ),
      ],
    )
        .animate()
        .fadeIn(delay: 200.ms, duration: 400.ms)
        .slideY(begin: 0.1, end: 0, delay: 200.ms, duration: 400.ms);
  }

  Widget _statCard(
    NeuroProfile profile, {
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: profile.cardColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 10),
            Text(
              value,
              style: TextStyle(
                fontFamily: profile.fontFamily,
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: profile.textColor,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
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

  // =============================================
  // Section Title
  // =============================================
  Widget _buildSectionTitle(NeuroProfile profile, String title) {
    return Text(
      title,
      style: TextStyle(
        fontFamily: profile.fontFamily,
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: profile.textColor,
        letterSpacing: profile.letterSpacing,
      ),
    ).animate().fadeIn(delay: 300.ms, duration: 400.ms);
  }

  // =============================================
  // Category Selector
  // =============================================
  Widget _buildCategorySelector(NeuroProfile profile) {
    return Row(
      children: [
        Expanded(
          child: _choiceChip(
            profile,
            label: '📚 Education',
            selected: _selectedCategory == 'education',
            onTap: () => setState(() => _selectedCategory = 'education'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _choiceChip(
            profile,
            label: '🏥 Medical',
            selected: _selectedCategory == 'medical',
            onTap: () => setState(() => _selectedCategory = 'medical'),
          ),
        ),
      ],
    );
  }

  // =============================================
  // Diagnosis Selector
  // =============================================
  Widget _buildDiagnosisSelector(NeuroProfile profile) {
    return _buildDropdown(
      profile,
      label: 'Diagnosis',
      value: _selectedDiagnosis,
      hint: 'Select diagnosis (optional)',
      items: _diagnoses,
      onChanged: (v) => setState(() => _selectedDiagnosis = v),
    );
  }

  // =============================================
  // Urgency Selector
  // =============================================
  Widget _buildUrgencySelector(NeuroProfile profile) {
    final urgencies = ['low', 'medium', 'high', 'urgent'];
    final labels = ['🟢 Low', '🟡 Medium', '🟠 High', '🔴 Urgent'];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: List.generate(urgencies.length, (i) {
        return _choiceChip(
          profile,
          label: labels[i],
          selected: _selectedUrgency == urgencies[i],
          onTap: () => setState(() => _selectedUrgency = urgencies[i]),
          compact: true,
        );
      }),
    );
  }

  // =============================================
  // Budget Selector
  // =============================================
  Widget _buildBudgetSelector(NeuroProfile profile) {
    final budgets = ['any', 'free', 'low', 'medium', 'high'];
    final labels = ['Any', 'Free', 'Low', 'Medium', 'High'];

    return _buildDropdown(
      profile,
      label: 'Budget',
      value: _selectedBudget,
      hint: 'Any budget',
      items: budgets,
      itemLabels: labels,
      onChanged: (v) => setState(() => _selectedBudget = v ?? 'any'),
    );
  }

  // =============================================
  // Mode Selector
  // =============================================
  Widget _buildModeSelector(NeuroProfile profile) {
    return Row(
      children: [
        Expanded(
          child: _choiceChip(
            profile,
            label: '🌐 Online',
            selected: _selectedMode == 'online',
            onTap: () => setState(() => _selectedMode = 'online'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _choiceChip(
            profile,
            label: '📍 Offline',
            selected: _selectedMode == 'offline',
            onTap: () => setState(() => _selectedMode = 'offline'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _choiceChip(
            profile,
            label: '🔄 Both',
            selected: _selectedMode == 'both',
            onTap: () => setState(() => _selectedMode = 'both'),
          ),
        ),
      ],
    );
  }

  // =============================================
  // Age Group Selector
  // =============================================
  Widget _buildAgeGroupSelector(NeuroProfile profile) {
    return _buildDropdown(
      profile,
      label: 'Age Group',
      value: _selectedAgeGroup,
      hint: 'Select age group (optional)',
      items: _ageGroups,
      onChanged: (v) => setState(() => _selectedAgeGroup = v),
    );
  }

  // =============================================
  // Search Button
  // =============================================
  Widget _buildSearchButton(NeuroProfile profile) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _findResources,
        style: ElevatedButton.styleFrom(
          backgroundColor: profile.accentColor,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
        ),
        child: _isLoading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                    strokeWidth: 2.5, color: Colors.white),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.search_rounded, size: 22),
                  const SizedBox(width: 10),
                  Text(
                    'Find Resources',
                    style: TextStyle(
                      fontFamily: profile.fontFamily,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
      ),
    )
        .animate()
        .fadeIn(delay: 500.ms, duration: 400.ms)
        .slideY(begin: 0.15, end: 0, delay: 500.ms, duration: 400.ms);
  }

  // =============================================
  // Quick Nav
  // =============================================
  Widget _buildQuickNav(NeuroProfile profile) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(profile, '⚡ Quick Access'),
        const SizedBox(height: 14),
        _navTile(
          profile,
          icon: Icons.history_rounded,
          title: 'My Sessions',
          subtitle: 'View upcoming, past & cancelled bookings',
          color: const Color(0xFF5C6BC0),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const ResourceHistoryScreen()),
            ).then((_) => _loadUpcomingCount());
          },
        ),
        const SizedBox(height: 10),
        _navTile(
          profile,
          icon: Icons.volunteer_activism_rounded,
          title: 'Nearby NGOs',
          subtitle: 'Get help from local organizations',
          color: const Color(0xFFFF7043),
          onTap: () async {
            if (_lat == null && mounted) {
              final pos = await LocationService.getCurrentLocation(context);
              if (pos != null) {
                _lat = pos.latitude;
                _lng = pos.longitude;
              }
            }
            if (!mounted) return;
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ResourceNGOsScreen(
                  latitude: _lat ?? 28.6139,
                  longitude: _lng ?? 77.2090,
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _navTile(
    NeuroProfile profile, {
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
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 22),
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
                      fontSize: profile.fontSize,
                      fontWeight: FontWeight.w700,
                      color: profile.textColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontFamily: profile.fontFamily,
                      fontSize: 12,
                      color: profile.textColor.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded,
                size: 14,
                color: profile.textColor.withValues(alpha: 0.3)),
          ],
        ),
      ),
    );
  }

  // =============================================
  // Shared Widgets
  // =============================================
  Widget _choiceChip(
    NeuroProfile profile, {
    required String label,
    required bool selected,
    required VoidCallback onTap,
    bool compact = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: EdgeInsets.symmetric(
          vertical: compact ? 10 : 14,
          horizontal: compact ? 14 : 16,
        ),
        decoration: BoxDecoration(
          color: selected
              ? profile.accentColor.withValues(alpha: 0.15)
              : profile.cardColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected
                ? profile.accentColor.withValues(alpha: 0.5)
                : profile.accentColor.withValues(alpha: 0.1),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontFamily: profile.fontFamily,
              fontSize: compact ? 13 : 14,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected
                  ? profile.accentColor
                  : profile.textColor.withValues(alpha: 0.65),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDropdown(
    NeuroProfile profile, {
    required String label,
    required String? value,
    required String hint,
    required List<String> items,
    List<String>? itemLabels,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: profile.cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: profile.accentColor.withValues(alpha: 0.12)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          hint: Text(
            hint,
            style: TextStyle(
              fontFamily: profile.fontFamily,
              fontSize: 14,
              color: profile.textColor.withValues(alpha: 0.4),
            ),
          ),
          isExpanded: true,
          dropdownColor: profile.cardColor,
          icon: Icon(Icons.expand_more_rounded,
              color: profile.textColor.withValues(alpha: 0.4)),
          style: TextStyle(
            fontFamily: profile.fontFamily,
            fontSize: 14,
            color: profile.textColor,
          ),
          items: List.generate(items.length, (i) {
            return DropdownMenuItem(
              value: items[i],
              child: Text(itemLabels != null ? itemLabels[i] : items[i]),
            );
          }),
          onChanged: onChanged,
        ),
      ),
    );
  }
}
