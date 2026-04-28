/// NeuroSpace — Resource Recommendation Results Screen
/// Shows scored, ranked resource recommendations with booking actions.

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../models/neuro_profile.dart';
import '../models/resource_models.dart';
import '../providers/neuro_theme_provider.dart';
import '../providers/booking_provider.dart';
import '../services/firebase_service.dart';
import '../services/resource_service.dart';

class ResourceResultsScreen extends StatelessWidget {
  final List<RecommendedResource> results;
  final String? diagnosis;
  final String category;

  const ResourceResultsScreen({
    super.key,
    required this.results,
    this.diagnosis,
    required this.category,
  });

  @override
  Widget build(BuildContext context) {
    final profile = Provider.of<NeuroThemeProvider>(context).activeProfile;

    return Scaffold(
      backgroundColor: profile.backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context, profile),
            Expanded(
              child: results.isEmpty
                  ? _buildEmpty(profile)
                  : ListView.separated(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 30),
                      itemCount: results.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (ctx, i) {
                        return _ResourceCard(
                          resource: results[i],
                          rank: i + 1,
                        )
                            .animate()
                            .fadeIn(
                                delay: Duration(milliseconds: 80 * i),
                                duration: 400.ms)
                            .slideX(
                                begin: 0.08,
                                end: 0,
                                delay: Duration(milliseconds: 80 * i),
                                duration: 400.ms);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, NeuroProfile profile) {
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
                  'Recommendations',
                  style: TextStyle(
                    fontFamily: profile.fontFamily,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: profile.textColor,
                  ),
                ),
                Text(
                  '${results.length} results${diagnosis != null ? ' for $diagnosis' : ''}',
                  style: TextStyle(
                    fontFamily: profile.fontFamily,
                    fontSize: 12,
                    color: profile.textColor.withValues(alpha: 0.55),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty(NeuroProfile profile) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off_rounded,
                size: 56,
                color: profile.textColor.withValues(alpha: 0.3)),
            const SizedBox(height: 16),
            Text(
              'No resources found',
              style: TextStyle(
                fontFamily: profile.fontFamily,
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: profile.textColor.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Try expanding your search radius or changing filters.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: profile.fontFamily,
                fontSize: 13,
                color: profile.textColor.withValues(alpha: 0.45),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================
// Resource Card
// =============================================

class _ResourceCard extends StatelessWidget {
  final RecommendedResource resource;
  final int rank;

  const _ResourceCard({required this.resource, required this.rank});

  IconData get _typeIcon {
    switch (resource.type) {
      case 'hospital':
        return Icons.local_hospital_rounded;
      case 'neurologist':
        return Icons.psychology_rounded;
      case 'psychologist':
        return Icons.self_improvement_rounded;
      case 'speech_therapy':
        return Icons.record_voice_over_rounded;
      case 'occupational_therapy':
        return Icons.accessibility_new_rounded;
      case 'rehab_center':
        return Icons.healing_rounded;
      case 'special_educator':
        return Icons.school_rounded;
      case 'remedial_learning':
        return Icons.menu_book_rounded;
      case 'support_group':
        return Icons.groups_rounded;
      case 'ngo':
        return Icons.volunteer_activism_rounded;
      default:
        return Icons.health_and_safety_rounded;
    }
  }

  Color get _typeColor {
    switch (resource.type) {
      case 'hospital':
        return const Color(0xFFEF5350);
      case 'neurologist':
      case 'psychologist':
        return const Color(0xFF7C4DFF);
      case 'speech_therapy':
        return const Color(0xFF00BCD4);
      case 'occupational_therapy':
        return const Color(0xFF26A69A);
      case 'rehab_center':
        return const Color(0xFFFF7043);
      case 'special_educator':
      case 'remedial_learning':
        return const Color(0xFF42A5F5);
      case 'support_group':
        return const Color(0xFF5C6BC0);
      case 'ngo':
        return const Color(0xFFFF7043);
      default:
        return const Color(0xFF78909C);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = Provider.of<NeuroThemeProvider>(context).activeProfile;

    return GestureDetector(
      onTap: () => _showDetailSheet(context, profile),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: profile.cardColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _typeColor.withValues(alpha: 0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top row: rank, name, score
            Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: _typeColor.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '#$rank',
                      style: TextStyle(
                        fontFamily: profile.fontFamily,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: _typeColor,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: _typeColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(_typeIcon, color: _typeColor, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        resource.name,
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
                        resource.typeLabel,
                        style: TextStyle(
                          fontFamily: profile.fontFamily,
                          fontSize: 11,
                          color: _typeColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                // Score badge
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _scoreColor(resource.score).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${resource.score.toInt()}%',
                    style: TextStyle(
                      fontFamily: profile.fontFamily,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: _scoreColor(resource.score),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Reason
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: profile.backgroundColor.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.lightbulb_outline_rounded,
                      size: 16,
                      color: profile.textColor.withValues(alpha: 0.4)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      resource.reason,
                      style: TextStyle(
                        fontFamily: profile.fontFamily,
                        fontSize: 12,
                        color: profile.textColor.withValues(alpha: 0.65),
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 10),

            // Info chips
            Wrap(
              spacing: 10,
              runSpacing: 6,
              children: [
                if (resource.distanceKm != null)
                  _infoChip(profile, Icons.route_rounded,
                      '${resource.distanceKm!.toStringAsFixed(1)} km'),
                if (resource.priceRange != null)
                  _infoChip(
                      profile, Icons.payments_rounded, resource.priceRange!),
                _infoChip(profile, Icons.schedule_rounded,
                    resource.availability),
                if (resource.timings != null)
                  _infoChip(
                      profile, Icons.access_time_rounded, resource.timings!),
              ],
            ),

            // Book button
            if (resource.bookingAvailable) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _showBookingSheet(context, profile),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: profile.accentColor,
                    side: BorderSide(
                        color: profile.accentColor.withValues(alpha: 0.4)),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  icon: const Icon(Icons.calendar_month_rounded, size: 18),
                  label: Text(
                    'Book Session',
                    style: TextStyle(
                      fontFamily: profile.fontFamily,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _scoreColor(double score) {
    if (score >= 75) return const Color(0xFF4CAF50);
    if (score >= 50) return const Color(0xFFFFA726);
    return const Color(0xFFEF5350);
  }

  Widget _infoChip(NeuroProfile profile, IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: profile.textColor.withValues(alpha: 0.4)),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(
            fontFamily: profile.fontFamily,
            fontSize: 11,
            color: profile.textColor.withValues(alpha: 0.6),
          ),
        ),
      ],
    );
  }

  // =============================================
  // Detail Sheet
  // =============================================
  void _showDetailSheet(BuildContext context, NeuroProfile profile) {
    showModalBottomSheet(
      context: context,
      backgroundColor: profile.cardColor,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.4,
          maxChildSize: 0.92,
          expand: false,
          builder: (_, scrollController) {
            return SingleChildScrollView(
              controller: scrollController,
              padding: const EdgeInsets.all(24),
              child: Column(
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
                  Row(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: _typeColor.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(_typeIcon, color: _typeColor, size: 28),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              resource.name,
                              style: TextStyle(
                                fontFamily: profile.fontFamily,
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: profile.textColor,
                              ),
                            ),
                            Text(
                              resource.typeLabel,
                              style: TextStyle(
                                fontFamily: profile.fontFamily,
                                fontSize: 13,
                                color: _typeColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _detailRow(profile, 'Score', '${resource.score.toInt()}%'),
                  _detailRow(profile, 'Category',
                      resource.category[0].toUpperCase() + resource.category.substring(1)),
                  if (resource.distanceKm != null)
                    _detailRow(profile, 'Distance',
                        '${resource.distanceKm!.toStringAsFixed(1)} km'),
                  _detailRow(profile, 'Availability', resource.availability),
                  if (resource.priceRange != null)
                    _detailRow(profile, 'Price Range', resource.priceRange!),
                  if (resource.location != null)
                    _detailRow(profile, 'Location', resource.location!),
                  if (resource.contact != null)
                    _detailRow(profile, 'Contact', resource.contact!),
                  if (resource.email != null)
                    _detailRow(profile, 'Email', resource.email!),
                  if (resource.timings != null)
                    _detailRow(profile, 'Timings', resource.timings!),
                  if (resource.accessibilityNotes != null)
                    _detailRow(
                        profile, 'Accessibility', resource.accessibilityNotes!),
                  _detailRow(
                      profile, 'Languages', resource.languages.join(', ')),
                  if (resource.services.isNotEmpty)
                    _detailRow(
                        profile, 'Services', resource.services.join(', ')),
                  const SizedBox(height: 16),
                  Text(
                    '💡 Why recommended',
                    style: TextStyle(
                      fontFamily: profile.fontFamily,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: profile.textColor,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    resource.reason,
                    style: TextStyle(
                      fontFamily: profile.fontFamily,
                      fontSize: 13,
                      color: profile.textColor.withValues(alpha: 0.65),
                      height: 1.5,
                    ),
                  ),
                  if (resource.bookingAvailable) ...[
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _showBookingSheet(context, profile);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: profile.accentColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                        icon: const Icon(Icons.calendar_month_rounded),
                        label: Text(
                          'Book a Session',
                          style: TextStyle(
                            fontFamily: profile.fontFamily,
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _detailRow(NeuroProfile profile, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                fontFamily: profile.fontFamily,
                fontSize: 13,
                color: profile.textColor.withValues(alpha: 0.45),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontFamily: profile.fontFamily,
                fontSize: 13,
                color: profile.textColor.withValues(alpha: 0.85),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // =============================================
  // Booking Sheet
  // =============================================
  void _showBookingSheet(BuildContext context, NeuroProfile profile) {
    final notesController = TextEditingController();
    DateTime selectedDate = DateTime.now().add(const Duration(days: 1));
    TimeOfDay selectedTime = const TimeOfDay(hour: 10, minute: 0);
    bool isBooking = false;

    showModalBottomSheet(
      context: context,
      backgroundColor: profile.cardColor,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                24,
                24,
                24,
                MediaQuery.of(context).viewInsets.bottom + 24,
              ),
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
                    'Book Session',
                    style: TextStyle(
                      fontFamily: profile.fontFamily,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: profile.textColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    resource.name,
                    style: TextStyle(
                      fontFamily: profile.fontFamily,
                      fontSize: 14,
                      color: profile.accentColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Date picker
                  GestureDetector(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: selectedDate,
                        firstDate: DateTime.now(),
                        lastDate:
                            DateTime.now().add(const Duration(days: 180)),
                      );
                      if (picked != null) {
                        setModalState(() => selectedDate = picked);
                      }
                    },
                    child: _fieldTile(
                      profile,
                      icon: Icons.calendar_today_rounded,
                      label: 'Date',
                      value:
                          '${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}',
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Time picker
                  GestureDetector(
                    onTap: () async {
                      final picked = await showTimePicker(
                        context: context,
                        initialTime: selectedTime,
                      );
                      if (picked != null) {
                        setModalState(() => selectedTime = picked);
                      }
                    },
                    child: _fieldTile(
                      profile,
                      icon: Icons.access_time_rounded,
                      label: 'Time',
                      value:
                          '${selectedTime.hour.toString().padLeft(2, '0')}:${selectedTime.minute.toString().padLeft(2, '0')}',
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Notes
                  TextField(
                    controller: notesController,
                    maxLines: 2,
                    style: TextStyle(
                      fontFamily: profile.fontFamily,
                      fontSize: 14,
                      color: profile.textColor,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Notes (optional)',
                      hintStyle: TextStyle(
                        fontFamily: profile.fontFamily,
                        color: profile.textColor.withValues(alpha: 0.35),
                      ),
                      filled: true,
                      fillColor: profile.backgroundColor.withValues(alpha: 0.5),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: isBooking
                          ? null
                          : () async {
                              setModalState(() => isBooking = true);

                              final userId =
                                  FirebaseService.currentUserId ?? 'anon';
                              final dateStr =
                                  '${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}';
                              final timeStr =
                                  '${selectedTime.hour.toString().padLeft(2, '0')}:${selectedTime.minute.toString().padLeft(2, '0')}';

                              final bp = Provider.of<BookingProvider>(
                                  context,
                                  listen: false);

                              final booking =
                                  await bp.createBooking(
                                resourceId: resource.id,
                                resourceName: resource.name,
                                resourceType: resource.type,
                                category: resource.category,
                                date: dateStr,
                                time: timeStr,
                                location: resource.location,
                                notes: notesController.text.isNotEmpty
                                    ? notesController.text
                                    : null,
                                providerName: resource.name,
                              );

                              if (!context.mounted) return;
                              Navigator.pop(ctx);

                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    booking != null
                                        ? '✅ Booked ${resource.name} for $dateStr at $timeStr'
                                        : '❌ Booking failed. Please try again.',
                                    style: TextStyle(
                                        fontFamily: profile.fontFamily),
                                  ),
                                  backgroundColor: booking != null
                                      ? const Color(0xFF4CAF50)
                                      : Colors.red.shade700,
                                ),
                              );
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: profile.accentColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      child: isBooking
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : Text(
                              'Confirm Booking',
                              style: TextStyle(
                                fontFamily: profile.fontFamily,
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _fieldTile(
    NeuroProfile profile, {
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: profile.backgroundColor.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: profile.accentColor),
          const SizedBox(width: 12),
          Text(
            '$label: ',
            style: TextStyle(
              fontFamily: profile.fontFamily,
              fontSize: 14,
              color: profile.textColor.withValues(alpha: 0.5),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontFamily: profile.fontFamily,
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: profile.textColor,
            ),
          ),
          const Spacer(),
          Icon(Icons.edit_rounded,
              size: 16, color: profile.textColor.withValues(alpha: 0.3)),
        ],
      ),
    );
  }
}
