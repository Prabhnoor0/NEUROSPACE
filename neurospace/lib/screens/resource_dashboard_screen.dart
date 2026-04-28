import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../models/neuro_profile.dart';
import '../models/resource_models.dart';
import '../providers/neuro_theme_provider.dart';
import '../providers/booking_provider.dart';
import '../services/location_service.dart';
import 'resource_results_screen.dart';
import 'resource_ngos_screen.dart';
import 'resource_history_screen.dart';
import 'session_detail_screen.dart';
import '../services/resource_service.dart';

class ResourceDashboardScreen extends StatefulWidget {
  const ResourceDashboardScreen({super.key});
  @override
  State<ResourceDashboardScreen> createState() => _ResourceDashboardScreenState();
}

class _ResourceDashboardScreenState extends State<ResourceDashboardScreen> {
  String _selectedCategory = 'education';
  String _selectedUrgency = 'medium';
  String _selectedBudget = 'any';
  String _selectedMode = 'both';
  String? _selectedDiagnosis;
  bool _isSearching = false;
  double? _lat, _lng;

  @override
  void initState() {
    super.initState();
    _loadLocation();
    final prov = Provider.of<BookingProvider>(context, listen: false);
    prov.loadAll();
    final pt = Provider.of<NeuroThemeProvider>(context, listen: false).activeProfile.profileType;
    if (pt == NeuroProfileType.adhd) _selectedDiagnosis = 'ADHD';
    else if (pt == NeuroProfileType.dyslexia) _selectedDiagnosis = 'Dyslexia';
    else if (pt == NeuroProfileType.autism) _selectedDiagnosis = 'Autism';
  }

  Future<void> _loadLocation() async {
    final c = LocationService.cachedPosition;
    if (c != null) setState(() { _lat = c.latitude; _lng = c.longitude; });
  }

  Future<void> _findResources() async {
    if (_lat == null && mounted) {
      final p = await LocationService.getCurrentLocation(context);
      if (p != null) { _lat = p.latitude; _lng = p.longitude; }
    }
    setState(() => _isSearching = true);
    final results = await ResourceService.getRecommendations(
      diagnosis: _selectedDiagnosis, urgency: _selectedUrgency,
      budget: _selectedBudget == 'any' ? null : _selectedBudget,
      latitude: _lat, longitude: _lng, deliveryMode: _selectedMode, category: _selectedCategory,
    );
    if (!mounted) return;
    setState(() => _isSearching = false);
    Navigator.push(context, MaterialPageRoute(builder: (_) => ResourceResultsScreen(results: results, diagnosis: _selectedDiagnosis, category: _selectedCategory)));
  }

  @override
  Widget build(BuildContext context) {
    final profile = Provider.of<NeuroThemeProvider>(context).activeProfile;
    final bp = Provider.of<BookingProvider>(context);

    return Scaffold(
      backgroundColor: profile.backgroundColor,
      body: SafeArea(
        child: RefreshIndicator(
          color: profile.accentColor,
          onRefresh: () => bp.loadAll(),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const SizedBox(height: 12),
              _header(profile),
              const SizedBox(height: 20),
              _heroStats(profile, bp),
              const SizedBox(height: 20),
              if (bp.stats.nextSession != null) _nextSession(profile, bp.stats.nextSession!),
              if (bp.stats.nextSession != null) const SizedBox(height: 20),
              if (bp.stats.recentActivity.isNotEmpty) _recentActivity(profile, bp),
              if (bp.stats.recentActivity.isNotEmpty) const SizedBox(height: 20),
              if (bp.upcoming.isNotEmpty) _upcomingList(profile, bp),
              if (bp.upcoming.isNotEmpty) const SizedBox(height: 20),
              _sectionTitle(profile, '🔍 Find Resources'),
              const SizedBox(height: 12),
              _searchForm(profile),
              const SizedBox(height: 20),
              _quickNav(profile),
              const SizedBox(height: 40),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _header(NeuroProfile p) {
    return Row(children: [
      GestureDetector(onTap: () => Navigator.pop(context), child: Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: p.cardColor, shape: BoxShape.circle), child: Icon(Icons.arrow_back_ios_new_rounded, color: p.textColor, size: 18))),
      const SizedBox(width: 14),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Resource Hub', style: TextStyle(fontFamily: p.fontFamily, fontSize: 24, fontWeight: FontWeight.w800, color: p.textColor)),
        Text('Your booking control center', style: TextStyle(fontFamily: p.fontFamily, fontSize: 13, color: p.textColor.withValues(alpha: 0.55))),
      ])),
      Container(width: 44, height: 44, decoration: BoxDecoration(gradient: LinearGradient(colors: [p.accentColor, p.accentColor.withValues(alpha: 0.7)]), shape: BoxShape.circle), child: const Icon(Icons.health_and_safety_rounded, color: Colors.white, size: 22)),
    ]).animate().fadeIn(duration: 500.ms).slideY(begin: -0.15, end: 0, duration: 500.ms);
  }

  Widget _heroStats(NeuroProfile p, BookingProvider bp) {
    final s = bp.stats;
    return Row(children: [
      _statChip(p, '${s.totalBookings}', 'Total', const Color(0xFF42A5F5)),
      const SizedBox(width: 8),
      _statChip(p, '${s.upcomingCount}', 'Upcoming', const Color(0xFF4CAF50)),
      const SizedBox(width: 8),
      _statChip(p, '${s.pending}', 'Pending', const Color(0xFFFFA726)),
      const SizedBox(width: 8),
      _statChip(p, '${s.confirmed}', 'Confirmed', const Color(0xFF26A69A)),
      const SizedBox(width: 8),
      _statChip(p, '${s.completed}', 'Done', const Color(0xFF7C4DFF)),
    ]).animate().fadeIn(delay: 150.ms, duration: 400.ms);
  }

  Widget _statChip(NeuroProfile p, String value, String label, Color c) {
    return Expanded(child: Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(color: c.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(14), border: Border.all(color: c.withValues(alpha: 0.2))),
      child: Column(children: [
        Text(value, style: TextStyle(fontFamily: p.fontFamily, fontSize: 20, fontWeight: FontWeight.w800, color: c)),
        Text(label, style: TextStyle(fontFamily: p.fontFamily, fontSize: 10, color: p.textColor.withValues(alpha: 0.5))),
      ]),
    ));
  }

  Widget _nextSession(NeuroProfile p, BookingData b) {
    final st = b.statusType;
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SessionDetailScreen(bookingId: b.bookingId))).then((_) => Provider.of<BookingProvider>(context, listen: false).loadAll()),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(gradient: LinearGradient(colors: [p.accentColor.withValues(alpha: 0.15), p.accentColor.withValues(alpha: 0.05)]), borderRadius: BorderRadius.circular(18), border: Border.all(color: p.accentColor.withValues(alpha: 0.25))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(Icons.upcoming_rounded, color: p.accentColor, size: 18),
            const SizedBox(width: 8),
            Text('Next Session', style: TextStyle(fontFamily: p.fontFamily, fontSize: 13, fontWeight: FontWeight.w700, color: p.accentColor)),
            const Spacer(),
            Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: st.color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)), child: Text(st.label, style: TextStyle(fontFamily: p.fontFamily, fontSize: 10, fontWeight: FontWeight.w700, color: st.color))),
          ]),
          const SizedBox(height: 10),
          Text(b.title, style: TextStyle(fontFamily: p.fontFamily, fontSize: 16, fontWeight: FontWeight.w700, color: p.textColor), maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 4),
          Row(children: [
            Icon(Icons.calendar_today_rounded, size: 12, color: p.textColor.withValues(alpha: 0.45)),
            const SizedBox(width: 4),
            Text('${b.date} at ${b.time}', style: TextStyle(fontFamily: p.fontFamily, fontSize: 12, color: p.textColor.withValues(alpha: 0.6))),
            const SizedBox(width: 12),
            Icon(Icons.person_rounded, size: 12, color: p.textColor.withValues(alpha: 0.45)),
            const SizedBox(width: 4),
            Expanded(child: Text(b.providerName ?? b.resourceName, style: TextStyle(fontFamily: p.fontFamily, fontSize: 12, color: p.textColor.withValues(alpha: 0.6)), overflow: TextOverflow.ellipsis)),
          ]),
          if (b.summary.shortSummary != null) ...[
            const SizedBox(height: 6),
            Text(b.summary.shortSummary!, style: TextStyle(fontFamily: p.fontFamily, fontSize: 11, color: p.textColor.withValues(alpha: 0.45), fontStyle: FontStyle.italic), maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
        ]),
      ),
    ).animate().fadeIn(delay: 250.ms, duration: 400.ms);
  }

  Widget _recentActivity(NeuroProfile p, BookingProvider bp) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _sectionTitle(p, '⚡ Recent Activity'),
      const SizedBox(height: 10),
      ...bp.stats.recentActivity.take(5).map((e) {
        final st = BookingStatusType.fromString(e.status);
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: p.cardColor, borderRadius: BorderRadius.circular(12)),
            child: Row(children: [
              Container(width: 8, height: 8, decoration: BoxDecoration(color: st.color, shape: BoxShape.circle)),
              const SizedBox(width: 10),
              Expanded(child: Text(e.title, style: TextStyle(fontFamily: p.fontFamily, fontSize: 13, color: p.textColor.withValues(alpha: 0.8)), maxLines: 1, overflow: TextOverflow.ellipsis)),
              Text(_timeAgo(e.timestamp), style: TextStyle(fontFamily: p.fontFamily, fontSize: 10, color: p.textColor.withValues(alpha: 0.35))),
            ]),
          ),
        );
      }),
    ]);
  }

  Widget _upcomingList(NeuroProfile p, BookingProvider bp) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(child: _sectionTitle(p, '📅 Upcoming Sessions')),
        GestureDetector(
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ResourceHistoryScreen())).then((_) => bp.loadAll()),
          child: Text('See All', style: TextStyle(fontFamily: p.fontFamily, fontSize: 13, color: p.accentColor, fontWeight: FontWeight.w600)),
        ),
      ]),
      const SizedBox(height: 10),
      ...bp.upcoming.take(3).map((b) => _miniBookingCard(p, b)),
    ]);
  }

  Widget _miniBookingCard(NeuroProfile p, BookingData b) {
    final st = b.statusType;
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SessionDetailScreen(bookingId: b.bookingId))).then((_) => Provider.of<BookingProvider>(context, listen: false).loadAll()),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: p.cardColor, borderRadius: BorderRadius.circular(14), border: Border.all(color: st.color.withValues(alpha: 0.2))),
        child: Row(children: [
          Container(width: 40, height: 40, decoration: BoxDecoration(color: st.color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)), child: Icon(st.icon, color: st.color, size: 20)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(b.title, style: TextStyle(fontFamily: p.fontFamily, fontSize: 14, fontWeight: FontWeight.w700, color: p.textColor), maxLines: 1, overflow: TextOverflow.ellipsis),
            Text('${b.date} · ${b.time} · ${b.modeLabel}', style: TextStyle(fontFamily: p.fontFamily, fontSize: 11, color: p.textColor.withValues(alpha: 0.5))),
          ])),
          Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: st.color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)), child: Text(st.label, style: TextStyle(fontFamily: p.fontFamily, fontSize: 10, fontWeight: FontWeight.w700, color: st.color))),
        ]),
      ),
    );
  }

  Widget _searchForm(NeuroProfile p) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: p.cardColor, borderRadius: BorderRadius.circular(18)),
      child: Column(children: [
        Row(children: [
          Expanded(child: _chip(p, '📚 Education', _selectedCategory == 'education', () => setState(() => _selectedCategory = 'education'))),
          const SizedBox(width: 8),
          Expanded(child: _chip(p, '🏥 Medical', _selectedCategory == 'medical', () => setState(() => _selectedCategory = 'medical'))),
        ]),
        const SizedBox(height: 10),
        _dropdown(p, _selectedDiagnosis, 'Diagnosis (optional)', ['ADHD', 'Dyslexia', 'Autism', 'Other'], (v) => setState(() => _selectedDiagnosis = v)),
        const SizedBox(height: 10),
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (final e in [('low', '🟢 Low'), ('medium', '🟡 Med'), ('high', '🟠 High'), ('urgent', '🔴 Urgent')])
            _chip(p, e.$2, _selectedUrgency == e.$1, () => setState(() => _selectedUrgency = e.$1), compact: true),
        ]),
        const SizedBox(height: 14),
        SizedBox(width: double.infinity, height: 48, child: ElevatedButton.icon(
          onPressed: _isSearching ? null : _findResources,
          style: ElevatedButton.styleFrom(backgroundColor: p.accentColor, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), elevation: 0),
          icon: _isSearching ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.search_rounded, size: 20),
          label: Text(_isSearching ? 'Searching...' : 'Find Resources', style: TextStyle(fontFamily: p.fontFamily, fontSize: 15, fontWeight: FontWeight.w700)),
        )),
      ]),
    ).animate().fadeIn(delay: 400.ms, duration: 400.ms);
  }

  Widget _quickNav(NeuroProfile p) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _sectionTitle(p, '⚡ Quick Access'),
      const SizedBox(height: 10),
      _navTile(p, Icons.history_rounded, 'All Sessions', 'View & manage all bookings', const Color(0xFF5C6BC0), () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ResourceHistoryScreen())).then((_) => Provider.of<BookingProvider>(context, listen: false).loadAll())),
      const SizedBox(height: 8),
      _navTile(p, Icons.volunteer_activism_rounded, 'Nearby NGOs', 'Get help from local organizations', const Color(0xFFFF7043), () async {
        if (_lat == null && mounted) { final pos = await LocationService.getCurrentLocation(context); if (pos != null) { _lat = pos.latitude; _lng = pos.longitude; } }
        if (!mounted) return;
        Navigator.push(context, MaterialPageRoute(builder: (_) => ResourceNGOsScreen(latitude: _lat ?? 28.6139, longitude: _lng ?? 77.2090)));
      }),
    ]);
  }

  Widget _navTile(NeuroProfile p, IconData icon, String title, String sub, Color c, VoidCallback onTap) {
    return InkWell(onTap: onTap, borderRadius: BorderRadius.circular(14), child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: p.cardColor, borderRadius: BorderRadius.circular(14), border: Border.all(color: c.withValues(alpha: 0.2))),
      child: Row(children: [
        Container(width: 40, height: 40, decoration: BoxDecoration(color: c.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: c, size: 20)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: TextStyle(fontFamily: p.fontFamily, fontSize: 14, fontWeight: FontWeight.w700, color: p.textColor)),
          Text(sub, style: TextStyle(fontFamily: p.fontFamily, fontSize: 11, color: p.textColor.withValues(alpha: 0.5))),
        ])),
        Icon(Icons.arrow_forward_ios_rounded, size: 14, color: p.textColor.withValues(alpha: 0.3)),
      ]),
    ));
  }

  Widget _sectionTitle(NeuroProfile p, String t) => Text(t, style: TextStyle(fontFamily: p.fontFamily, fontSize: 16, fontWeight: FontWeight.w700, color: p.textColor));

  Widget _chip(NeuroProfile p, String label, bool selected, VoidCallback onTap, {bool compact = false}) {
    return GestureDetector(onTap: onTap, child: AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: EdgeInsets.symmetric(vertical: compact ? 8 : 12, horizontal: compact ? 12 : 14),
      decoration: BoxDecoration(
        color: selected ? p.accentColor.withValues(alpha: 0.15) : p.backgroundColor.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: selected ? p.accentColor.withValues(alpha: 0.5) : Colors.transparent),
      ),
      child: Center(child: Text(label, style: TextStyle(fontFamily: p.fontFamily, fontSize: compact ? 12 : 13, fontWeight: selected ? FontWeight.w700 : FontWeight.w500, color: selected ? p.accentColor : p.textColor.withValues(alpha: 0.6)))),
    ));
  }

  Widget _dropdown(NeuroProfile p, String? value, String hint, List<String> items, ValueChanged<String?> onChanged) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      decoration: BoxDecoration(color: p.backgroundColor.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(12)),
      child: DropdownButtonHideUnderline(child: DropdownButton<String>(
        value: value, hint: Text(hint, style: TextStyle(fontFamily: p.fontFamily, fontSize: 13, color: p.textColor.withValues(alpha: 0.4))),
        isExpanded: true, dropdownColor: p.cardColor,
        icon: Icon(Icons.expand_more_rounded, color: p.textColor.withValues(alpha: 0.4)),
        style: TextStyle(fontFamily: p.fontFamily, fontSize: 13, color: p.textColor),
        items: items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(), onChanged: onChanged,
      )),
    );
  }

  String _timeAgo(String iso) {
    try {
      final d = DateTime.parse(iso);
      final diff = DateTime.now().difference(d);
      if (diff.inMinutes < 1) return 'now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m';
      if (diff.inHours < 24) return '${diff.inHours}h';
      return '${diff.inDays}d';
    } catch (_) { return ''; }
  }
}
