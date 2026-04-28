/// NeuroSpace — Resource Session History Screen
/// Shows upcoming, past, and cancelled bookings + help requests.

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../models/neuro_profile.dart';
import '../models/resource_models.dart';
import '../providers/neuro_theme_provider.dart';
import '../services/firebase_service.dart';
import '../services/resource_service.dart';

class ResourceHistoryScreen extends StatefulWidget {
  const ResourceHistoryScreen({super.key});

  @override
  State<ResourceHistoryScreen> createState() => _ResourceHistoryScreenState();
}

class _ResourceHistoryScreenState extends State<ResourceHistoryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<BookingData> _upcoming = [];
  List<BookingData> _past = [];
  List<BookingData> _cancelled = [];
  List<HelpRequestData> _helpRequests = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    final userId = FirebaseService.currentUserId;
    if (userId == null) {
      setState(() => _isLoading = false);
      return;
    }

    final bookings = await ResourceService.getBookingsFromFirebase(userId);
    final helpReqs = await ResourceService.getHelpRequestsFromFirebase(userId);

    final now = DateTime.now();
    final upcoming = <BookingData>[];
    final past = <BookingData>[];
    final cancelled = <BookingData>[];

    for (final b in bookings) {
      if (b.status == 'cancelled') {
        cancelled.add(b);
        continue;
      }
      if (b.status == 'completed') {
        past.add(b);
        continue;
      }
      try {
        final d = DateTime.parse(b.date);
        if (d.isBefore(now) &&
            b.status != 'pending' &&
            b.status != 'confirmed') {
          past.add(b);
        } else {
          upcoming.add(b);
        }
      } catch (_) {
        upcoming.add(b);
      }
    }

    if (mounted) {
      setState(() {
        _upcoming = upcoming;
        _past = past;
        _cancelled = cancelled;
        _helpRequests = helpReqs;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = Provider.of<NeuroThemeProvider>(context).activeProfile;

    return Scaffold(
      backgroundColor: profile.backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(profile),
            _buildTabBar(profile),
            Expanded(
              child: _isLoading
                  ? Center(
                      child: CircularProgressIndicator(
                          color: profile.accentColor))
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        _buildBookingList(profile, _upcoming, 'upcoming'),
                        _buildBookingList(profile, _past, 'past'),
                        _buildBookingList(profile, _cancelled, 'cancelled'),
                        _buildHelpRequestList(profile),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(NeuroProfile profile) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
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
                  'My Sessions',
                  style: TextStyle(
                    fontFamily: profile.fontFamily,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: profile.textColor,
                  ),
                ),
                Text(
                  'Bookings & help requests',
                  style: TextStyle(
                    fontFamily: profile.fontFamily,
                    fontSize: 12,
                    color: profile.textColor.withValues(alpha: 0.55),
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: _loadData,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: profile.cardColor,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.refresh_rounded,
                  color: profile.accentColor, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar(NeuroProfile profile) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      decoration: BoxDecoration(
        color: profile.cardColor,
        borderRadius: BorderRadius.circular(14),
      ),
      child: TabBar(
        controller: _tabController,
        labelColor: profile.accentColor,
        unselectedLabelColor: profile.textColor.withValues(alpha: 0.45),
        indicatorSize: TabBarIndicatorSize.tab,
        indicator: BoxDecoration(
          color: profile.accentColor.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        dividerColor: Colors.transparent,
        labelStyle: TextStyle(
          fontFamily: profile.fontFamily,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
        unselectedLabelStyle: TextStyle(
          fontFamily: profile.fontFamily,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
        tabs: [
          Tab(text: 'Upcoming (${_upcoming.length})'),
          Tab(text: 'Past (${_past.length})'),
          Tab(text: 'Cancelled (${_cancelled.length})'),
          Tab(text: 'Help (${_helpRequests.length})'),
        ],
      ),
    );
  }

  Widget _buildBookingList(
      NeuroProfile profile, List<BookingData> items, String type) {
    if (items.isEmpty) {
      return _buildEmptyTab(
        profile,
        icon: type == 'upcoming'
            ? Icons.event_available_rounded
            : type == 'cancelled'
                ? Icons.event_busy_rounded
                : Icons.history_rounded,
        message: type == 'upcoming'
            ? 'No upcoming sessions'
            : type == 'cancelled'
                ? 'No cancelled sessions'
                : 'No past sessions',
      );
    }

    return ListView.separated(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 30),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (ctx, i) {
        final booking = items[i];
        return _BookingCard(
          booking: booking,
          showActions: type == 'upcoming',
          onCancel: type == 'upcoming'
              ? () async {
                  final userId = FirebaseService.currentUserId;
                  if (userId == null) return;
                  // Update status on backend
                  await ResourceService.updateBooking(
                    bookingId: booking.bookingId,
                    status: 'cancelled',
                  );
                  // Update in Firebase (find the firebase key)
                  final fbBookings =
                      await FirebaseService.getBookings(userId);
                  for (final fb in fbBookings) {
                    if (fb['booking_id'] == booking.bookingId) {
                      final key = fb['firebase_key'] as String?;
                      if (key != null) {
                        await FirebaseService.updateBookingStatus(
                          userId: userId,
                          firebaseKey: key,
                          status: 'cancelled',
                        );
                      }
                      break;
                    }
                  }
                  _loadData();
                }
              : null,
        )
            .animate()
            .fadeIn(
                delay: Duration(milliseconds: 60 * i), duration: 350.ms)
            .slideX(
                begin: 0.06,
                end: 0,
                delay: Duration(milliseconds: 60 * i),
                duration: 350.ms);
      },
    );
  }

  Widget _buildHelpRequestList(NeuroProfile profile) {
    if (_helpRequests.isEmpty) {
      return _buildEmptyTab(
        profile,
        icon: Icons.help_outline_rounded,
        message: 'No help requests yet',
      );
    }

    return ListView.separated(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 30),
      itemCount: _helpRequests.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (ctx, i) {
        final req = _helpRequests[i];
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: profile.cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: profile.accentColor.withValues(alpha: 0.15)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF7043).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.volunteer_activism_rounded,
                        color: Color(0xFFFF7043), size: 18),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          req.ngoName,
                          style: TextStyle(
                            fontFamily: profile.fontFamily,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: profile.textColor,
                          ),
                        ),
                        Text(
                          'Status: ${req.status.toUpperCase()}',
                          style: TextStyle(
                            fontFamily: profile.fontFamily,
                            fontSize: 11,
                            color: const Color(0xFF4CAF50),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    _formatDate(req.createdAt),
                    style: TextStyle(
                      fontFamily: profile.fontFamily,
                      fontSize: 11,
                      color: profile.textColor.withValues(alpha: 0.4),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                req.message,
                style: TextStyle(
                  fontFamily: profile.fontFamily,
                  fontSize: 13,
                  color: profile.textColor.withValues(alpha: 0.7),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Contact preference: ${req.contactPreference}',
                style: TextStyle(
                  fontFamily: profile.fontFamily,
                  fontSize: 11,
                  color: profile.textColor.withValues(alpha: 0.4),
                ),
              ),
            ],
          ),
        )
            .animate()
            .fadeIn(
                delay: Duration(milliseconds: 80 * i), duration: 350.ms);
      },
    );
  }

  Widget _buildEmptyTab(
    NeuroProfile profile, {
    required IconData icon,
    required String message,
  }) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 52, color: profile.textColor.withValues(alpha: 0.25)),
          const SizedBox(height: 12),
          Text(
            message,
            style: TextStyle(
              fontFamily: profile.fontFamily,
              fontSize: 16,
              color: profile.textColor.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Book a resource session to see it here.',
            style: TextStyle(
              fontFamily: profile.fontFamily,
              fontSize: 12,
              color: profile.textColor.withValues(alpha: 0.35),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(String iso) {
    try {
      final d = DateTime.parse(iso);
      return '${d.day}/${d.month}/${d.year}';
    } catch (_) {
      return iso;
    }
  }
}

// =============================================
// Booking Card
// =============================================

class _BookingCard extends StatelessWidget {
  final BookingData booking;
  final bool showActions;
  final VoidCallback? onCancel;

  const _BookingCard({
    required this.booking,
    this.showActions = false,
    this.onCancel,
  });

  Color get _statusColor {
    switch (booking.status) {
      case 'confirmed':
        return const Color(0xFF4CAF50);
      case 'pending':
        return const Color(0xFFFFA726);
      case 'completed':
        return const Color(0xFF42A5F5);
      case 'cancelled':
        return const Color(0xFFEF5350);
      case 'rescheduled':
        return const Color(0xFF7C4DFF);
      default:
        return const Color(0xFF78909C);
    }
  }

  IconData get _typeIcon {
    switch (booking.resourceType) {
      case 'hospital':
        return Icons.local_hospital_rounded;
      case 'neurologist':
      case 'psychologist':
        return Icons.psychology_rounded;
      case 'speech_therapy':
        return Icons.record_voice_over_rounded;
      case 'occupational_therapy':
        return Icons.accessibility_new_rounded;
      case 'special_educator':
        return Icons.school_rounded;
      default:
        return Icons.health_and_safety_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = Provider.of<NeuroThemeProvider>(context).activeProfile;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: profile.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _statusColor.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(_typeIcon, color: _statusColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      booking.resourceName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: profile.fontFamily,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: profile.textColor,
                      ),
                    ),
                    Text(
                      booking.resourceType
                          .replaceAll('_', ' ')
                          .split(' ')
                          .map((w) => w.isNotEmpty
                              ? '${w[0].toUpperCase()}${w.substring(1)}'
                              : '')
                          .join(' '),
                      style: TextStyle(
                        fontFamily: profile.fontFamily,
                        fontSize: 11,
                        color: profile.textColor.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  booking.statusLabel,
                  style: TextStyle(
                    fontFamily: profile.fontFamily,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: _statusColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 14,
            runSpacing: 6,
            children: [
              _info(profile, Icons.calendar_today_rounded, booking.date),
              _info(profile, Icons.access_time_rounded, booking.time),
              if (booking.location != null)
                _info(profile, Icons.location_on_rounded, booking.location!),
            ],
          ),
          if (booking.notes != null && booking.notes!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Notes: ${booking.notes}',
              style: TextStyle(
                fontFamily: profile.fontFamily,
                fontSize: 12,
                color: profile.textColor.withValues(alpha: 0.5),
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
          if (showActions && onCancel != null) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onCancel,
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFEF5350),
                  side: const BorderSide(
                      color: Color(0x40EF5350)),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                ),
                icon: const Icon(Icons.cancel_rounded, size: 16),
                label: Text(
                  'Cancel Booking',
                  style: TextStyle(
                    fontFamily: profile.fontFamily,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _info(NeuroProfile profile, IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon,
            size: 13, color: profile.textColor.withValues(alpha: 0.4)),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(
            fontFamily: profile.fontFamily,
            fontSize: 12,
            color: profile.textColor.withValues(alpha: 0.6),
          ),
        ),
      ],
    );
  }
}
