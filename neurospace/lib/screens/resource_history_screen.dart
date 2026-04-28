import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../models/neuro_profile.dart';
import '../models/resource_models.dart';
import '../providers/neuro_theme_provider.dart';
import '../providers/booking_provider.dart';
import 'session_detail_screen.dart';

class ResourceHistoryScreen extends StatefulWidget {
  const ResourceHistoryScreen({super.key});
  @override
  State<ResourceHistoryScreen> createState() => _ResourceHistoryScreenState();
}

class _ResourceHistoryScreenState extends State<ResourceHistoryScreen> with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';

  final _tabs = ['All', 'Upcoming', 'Pending', 'Confirmed', 'Completed', 'Cancelled'];

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: _tabs.length, vsync: this);
    _searchCtrl.addListener(() => setState(() => _searchQuery = _searchCtrl.text));
    Provider.of<BookingProvider>(context, listen: false).loadAll();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  List<BookingData> _getFiltered(BookingProvider bp, int tab) {
    List<BookingData> list;
    switch (tab) {
      case 1: list = bp.upcoming; break;
      case 2: list = bp.pending; break;
      case 3: list = bp.confirmed; break;
      case 4: list = bp.completed; break;
      case 5: list = [...bp.cancelled, ...bp.rescheduled]; break;
      default: list = bp.bookings;
    }
    if (_searchQuery.isNotEmpty) list = list.where((b) {
      final q = _searchQuery.toLowerCase();
      return b.title.toLowerCase().contains(q) || b.resourceName.toLowerCase().contains(q) || (b.providerName?.toLowerCase().contains(q) ?? false) || b.category.contains(q);
    }).toList();
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final p = Provider.of<NeuroThemeProvider>(context).activeProfile;
    final bp = Provider.of<BookingProvider>(context);

    return Scaffold(
      backgroundColor: p.backgroundColor,
      body: SafeArea(
        child: Column(children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(children: [
              GestureDetector(onTap: () => Navigator.pop(context), child: Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: p.cardColor, shape: BoxShape.circle), child: Icon(Icons.arrow_back_ios_new_rounded, color: p.textColor, size: 18))),
              const SizedBox(width: 14),
              Expanded(child: Text('My Sessions', style: TextStyle(fontFamily: p.fontFamily, fontSize: 22, fontWeight: FontWeight.w800, color: p.textColor))),
              GestureDetector(onTap: () => bp.loadAll(), child: Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: p.cardColor, shape: BoxShape.circle), child: Icon(Icons.refresh_rounded, color: p.accentColor, size: 20))),
            ]),
          ),
          const SizedBox(height: 12),
          // Search
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(color: p.cardColor, borderRadius: BorderRadius.circular(14)),
              child: TextField(
                controller: _searchCtrl,
                style: TextStyle(fontFamily: p.fontFamily, fontSize: 14, color: p.textColor),
                decoration: InputDecoration(
                  hintText: 'Search by name, provider, category...', border: InputBorder.none,
                  hintStyle: TextStyle(fontFamily: p.fontFamily, fontSize: 13, color: p.textColor.withValues(alpha: 0.35)),
                  icon: Icon(Icons.search_rounded, color: p.textColor.withValues(alpha: 0.35), size: 20),
                  suffixIcon: _searchQuery.isNotEmpty ? GestureDetector(onTap: () { _searchCtrl.clear(); setState(() {}); }, child: Icon(Icons.clear_rounded, color: p.textColor.withValues(alpha: 0.35), size: 18)) : null,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Tabs
          TabBar(
            controller: _tabCtrl,
            isScrollable: true,
            labelColor: p.accentColor,
            unselectedLabelColor: p.textColor.withValues(alpha: 0.4),
            indicatorColor: p.accentColor,
            indicatorSize: TabBarIndicatorSize.label,
            labelStyle: TextStyle(fontFamily: p.fontFamily, fontSize: 13, fontWeight: FontWeight.w700),
            unselectedLabelStyle: TextStyle(fontFamily: p.fontFamily, fontSize: 13, fontWeight: FontWeight.w500),
            tabAlignment: TabAlignment.start,
            tabs: _tabs.map((t) => Tab(text: t)).toList(),
            onTap: (_) => setState(() {}),
          ),
          const SizedBox(height: 8),
          // List
          Expanded(
            child: RefreshIndicator(
              color: p.accentColor,
              onRefresh: () => bp.loadAll(),
              child: bp.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _buildList(p, bp),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildList(NeuroProfile p, BookingProvider bp) {
    final items = _getFiltered(bp, _tabCtrl.index);
    if (items.isEmpty) {
      return ListView(children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.25),
        Center(child: Column(children: [
          Icon(Icons.event_busy_rounded, size: 56, color: p.textColor.withValues(alpha: 0.2)),
          const SizedBox(height: 12),
          Text('No sessions found', style: TextStyle(fontFamily: p.fontFamily, fontSize: 16, fontWeight: FontWeight.w600, color: p.textColor.withValues(alpha: 0.4))),
          const SizedBox(height: 4),
          Text('Try a different filter or book a session', style: TextStyle(fontFamily: p.fontFamily, fontSize: 12, color: p.textColor.withValues(alpha: 0.3))),
        ])),
      ]);
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
      itemCount: items.length,
      itemBuilder: (ctx, i) => _bookingCard(p, items[i], i),
    );
  }

  Widget _bookingCard(NeuroProfile p, BookingData b, int i) {
    final st = b.statusType;
    final bp = Provider.of<BookingProvider>(context, listen: false);

    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SessionDetailScreen(bookingId: b.bookingId))).then((_) => bp.loadAll()),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: p.cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: st.color.withValues(alpha: 0.15)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Top row: title + badge
          Row(children: [
            Container(width: 40, height: 40, decoration: BoxDecoration(color: st.color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)), child: Icon(st.icon, color: st.color, size: 20)),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(b.title, style: TextStyle(fontFamily: p.fontFamily, fontSize: 14, fontWeight: FontWeight.w700, color: p.textColor), maxLines: 1, overflow: TextOverflow.ellipsis),
              Text(b.providerName ?? b.resourceName, style: TextStyle(fontFamily: p.fontFamily, fontSize: 11, color: p.textColor.withValues(alpha: 0.5))),
            ])),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: st.color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
              child: Text(st.label, style: TextStyle(fontFamily: p.fontFamily, fontSize: 10, fontWeight: FontWeight.w700, color: st.color)),
            ),
          ]),
          const SizedBox(height: 10),
          // Info chips
          Wrap(spacing: 12, children: [
            _infoChip(p, Icons.calendar_today_rounded, b.date),
            _infoChip(p, Icons.access_time_rounded, b.time),
            _infoChip(p, Icons.devices_rounded, b.modeLabel),
            _infoChip(p, Icons.category_rounded, b.category),
          ]),
          // Summary preview
          if (b.summary.shortSummary != null) ...[
            const SizedBox(height: 8),
            Text(b.summary.shortSummary!, style: TextStyle(fontFamily: p.fontFamily, fontSize: 11, color: p.textColor.withValues(alpha: 0.4), fontStyle: FontStyle.italic), maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
          // Quick actions
          const SizedBox(height: 10),
          Row(children: [
            _miniAction(p, 'Details', Icons.info_outline_rounded, p.accentColor, () => Navigator.push(context, MaterialPageRoute(builder: (_) => SessionDetailScreen(bookingId: b.bookingId))).then((_) => bp.loadAll())),
            if (b.canConfirm) _miniAction(p, 'Confirm', Icons.check_rounded, const Color(0xFF4CAF50), () async { await bp.confirmBooking(b.bookingId); }),
            if (b.canCancel) _miniAction(p, 'Cancel', Icons.close_rounded, const Color(0xFFEF5350), () async { await bp.cancelBooking(b.bookingId); }),
          ]),
        ]),
      ),
    ).animate().fadeIn(delay: Duration(milliseconds: 50 * i), duration: 300.ms);
  }

  Widget _infoChip(NeuroProfile p, IconData icon, String text) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 12, color: p.textColor.withValues(alpha: 0.35)),
      const SizedBox(width: 3),
      Text(text, style: TextStyle(fontFamily: p.fontFamily, fontSize: 11, color: p.textColor.withValues(alpha: 0.5))),
    ]);
  }

  Widget _miniAction(NeuroProfile p, String label, IconData icon, Color c, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(color: c.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 14, color: c),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(fontFamily: p.fontFamily, fontSize: 11, fontWeight: FontWeight.w600, color: c)),
          ]),
        ),
      ),
    );
  }
}
