import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../models/neuro_profile.dart';
import '../models/resource_models.dart';
import '../providers/neuro_theme_provider.dart';
import '../providers/booking_provider.dart';

class SessionDetailScreen extends StatefulWidget {
  final String bookingId;
  const SessionDetailScreen({super.key, required this.bookingId});

  @override
  State<SessionDetailScreen> createState() => _SessionDetailScreenState();
}

class _SessionDetailScreenState extends State<SessionDetailScreen> {
  bool _actionLoading = false;

  @override
  Widget build(BuildContext context) {
    final profile = Provider.of<NeuroThemeProvider>(context).activeProfile;
    final provider = Provider.of<BookingProvider>(context);
    final booking = provider.getById(widget.bookingId);

    if (booking == null) {
      return Scaffold(
        backgroundColor: profile.backgroundColor,
        body: Center(child: Text('Session not found', style: TextStyle(color: profile.textColor))),
      );
    }

    return Scaffold(
      backgroundColor: profile.backgroundColor,
      body: SafeArea(
        child: RefreshIndicator(
          color: profile.accentColor,
          onRefresh: () => provider.loadAll(),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _header(profile, booking),
                const SizedBox(height: 20),
                _statusCard(profile, booking),
                const SizedBox(height: 16),
                _infoCard(profile, booking),
                const SizedBox(height: 16),
                if (booking.summary.shortSummary != null || booking.summary.fullSummary != null)
                  _summaryCard(profile, booking),
                if (booking.summary.shortSummary != null || booking.summary.fullSummary != null)
                  const SizedBox(height: 16),
                if (booking.notes != null && booking.notes!.isNotEmpty)
                  _notesCard(profile, booking),
                if (booking.notes != null && booking.notes!.isNotEmpty)
                  const SizedBox(height: 16),
                _timelineCard(profile, booking),
                const SizedBox(height: 20),
                _actionButtons(profile, booking, provider),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _header(NeuroProfile p, BookingData b) {
    return Row(
      children: [
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: p.cardColor, shape: BoxShape.circle),
            child: Icon(Icons.arrow_back_ios_new_rounded, color: p.textColor, size: 18),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(b.title, style: TextStyle(fontFamily: p.fontFamily, fontSize: 20, fontWeight: FontWeight.w800, color: p.textColor), maxLines: 2, overflow: TextOverflow.ellipsis),
              Text('ID: ${b.bookingId}', style: TextStyle(fontFamily: p.fontFamily, fontSize: 11, color: p.textColor.withValues(alpha: 0.4))),
            ],
          ),
        ),
      ],
    ).animate().fadeIn(duration: 400.ms);
  }

  Widget _statusCard(NeuroProfile p, BookingData b) {
    final st = b.statusType;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: st.color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(16), border: Border.all(color: st.color.withValues(alpha: 0.3))),
      child: Row(
        children: [
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(color: st.color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
            child: Icon(st.icon, color: st.color, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(st.label, style: TextStyle(fontFamily: p.fontFamily, fontSize: 18, fontWeight: FontWeight.w800, color: st.color)),
                const SizedBox(height: 2),
                Text(st.explanation, style: TextStyle(fontFamily: p.fontFamily, fontSize: 12, color: p.textColor.withValues(alpha: 0.6))),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 100.ms, duration: 400.ms);
  }

  Widget _infoCard(NeuroProfile p, BookingData b) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: p.cardColor, borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          _row(p, Icons.calendar_today_rounded, 'Date', b.date),
          _row(p, Icons.access_time_rounded, 'Time', b.time),
          _row(p, Icons.person_rounded, 'Provider', b.providerName ?? b.resourceName),
          _row(p, Icons.category_rounded, 'Category', b.category),
          _row(p, Icons.medical_services_rounded, 'Type', b.typeLabel),
          _row(p, Icons.devices_rounded, 'Mode', b.modeLabel),
          if (b.location != null) _row(p, Icons.location_on_rounded, 'Location', b.location!),
          _row(p, Icons.event_note_rounded, 'Created', _fmtDate(b.createdAt)),
          _row(p, Icons.update_rounded, 'Updated', _fmtDate(b.updatedAt)),
        ],
      ),
    ).animate().fadeIn(delay: 200.ms, duration: 400.ms);
  }

  Widget _row(NeuroProfile p, IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, size: 16, color: p.textColor.withValues(alpha: 0.4)),
          const SizedBox(width: 10),
          SizedBox(width: 80, child: Text(label, style: TextStyle(fontFamily: p.fontFamily, fontSize: 12, color: p.textColor.withValues(alpha: 0.5), fontWeight: FontWeight.w600))),
          Expanded(child: Text(value, style: TextStyle(fontFamily: p.fontFamily, fontSize: 13, color: p.textColor.withValues(alpha: 0.85)))),
        ],
      ),
    );
  }

  Widget _summaryCard(NeuroProfile p, BookingData b) {
    final s = b.summary;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: p.cardColor, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('📋 Session Summary', style: TextStyle(fontFamily: p.fontFamily, fontSize: 15, fontWeight: FontWeight.w700, color: p.textColor)),
          const SizedBox(height: 10),
          if (s.shortSummary != null) Text(s.shortSummary!, style: TextStyle(fontFamily: p.fontFamily, fontSize: 13, color: p.textColor.withValues(alpha: 0.7), height: 1.5)),
          if (s.fullSummary != null) ...[const SizedBox(height: 8), Text(s.fullSummary!, style: TextStyle(fontFamily: p.fontFamily, fontSize: 13, color: p.textColor.withValues(alpha: 0.65), height: 1.5))],
          if (s.statusNote != null) ...[const SizedBox(height: 8), Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: p.accentColor.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(10)), child: Text(s.statusNote!, style: TextStyle(fontFamily: p.fontFamily, fontSize: 12, color: p.accentColor, fontStyle: FontStyle.italic)))],
          if (s.sessionOutcome != null) ...[const SizedBox(height: 8), _summaryField(p, 'Outcome', s.sessionOutcome!)],
          if (s.nextSteps != null) _summaryField(p, 'Next Steps', s.nextSteps!),
          if (s.followUpDate != null) _summaryField(p, 'Follow-up', s.followUpDate!),
          if (s.providerRemarks != null) _summaryField(p, 'Provider', s.providerRemarks!),
          if (s.userFeedback != null) _summaryField(p, 'Your Feedback', s.userFeedback!),
        ],
      ),
    ).animate().fadeIn(delay: 300.ms, duration: 400.ms);
  }

  Widget _summaryField(NeuroProfile p, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(width: 90, child: Text(label, style: TextStyle(fontFamily: p.fontFamily, fontSize: 11, color: p.textColor.withValues(alpha: 0.45), fontWeight: FontWeight.w600))),
        Expanded(child: Text(value, style: TextStyle(fontFamily: p.fontFamily, fontSize: 12, color: p.textColor.withValues(alpha: 0.7)))),
      ]),
    );
  }

  Widget _notesCard(NeuroProfile p, BookingData b) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: p.cardColor, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('📝 Notes', style: TextStyle(fontFamily: p.fontFamily, fontSize: 15, fontWeight: FontWeight.w700, color: p.textColor)),
          const SizedBox(height: 8),
          Text(b.notes!, style: TextStyle(fontFamily: p.fontFamily, fontSize: 13, color: p.textColor.withValues(alpha: 0.65), height: 1.5)),
        ],
      ),
    );
  }

  Widget _timelineCard(NeuroProfile p, BookingData b) {
    if (b.timeline.isEmpty) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: p.cardColor, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('🕐 Status Timeline', style: TextStyle(fontFamily: p.fontFamily, fontSize: 15, fontWeight: FontWeight.w700, color: p.textColor)),
          const SizedBox(height: 12),
          ...b.timeline.reversed.map((e) {
            final st = BookingStatusType.fromString(e.status);
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(children: [
                    Container(width: 10, height: 10, decoration: BoxDecoration(color: st.color, shape: BoxShape.circle)),
                    if (b.timeline.first != e) Container(width: 2, height: 30, color: st.color.withValues(alpha: 0.2)),
                  ]),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(e.title, style: TextStyle(fontFamily: p.fontFamily, fontSize: 13, fontWeight: FontWeight.w700, color: p.textColor)),
                        if (e.description != null) Text(e.description!, style: TextStyle(fontFamily: p.fontFamily, fontSize: 11, color: p.textColor.withValues(alpha: 0.55), height: 1.4)),
                        Text('${_fmtDate(e.timestamp)} · ${e.actor}', style: TextStyle(fontFamily: p.fontFamily, fontSize: 10, color: p.textColor.withValues(alpha: 0.35))),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    ).animate().fadeIn(delay: 400.ms, duration: 400.ms);
  }

  Widget _actionButtons(NeuroProfile p, BookingData b, BookingProvider prov) {
    final actions = <Widget>[];

    if (b.canConfirm) actions.add(_actionBtn(p, 'Confirm', Icons.check_circle_rounded, const Color(0xFF4CAF50), () => _doAction(() => prov.confirmBooking(b.bookingId))));
    if (b.canStart) actions.add(_actionBtn(p, 'Start Session', Icons.play_circle_rounded, const Color(0xFF42A5F5), () => _doAction(() => prov.startSession(b.bookingId))));
    if (b.canComplete) actions.add(_actionBtn(p, 'Complete', Icons.task_alt_rounded, const Color(0xFF26A69A), () => _doAction(() => prov.completeSession(b.bookingId))));
    if (b.canReschedule) actions.add(_actionBtn(p, 'Reschedule', Icons.update_rounded, const Color(0xFF7C4DFF), () => _showReschedule(p, b, prov)));
    if (b.canCancel) actions.add(_actionBtn(p, 'Cancel', Icons.cancel_rounded, const Color(0xFFEF5350), () => _doAction(() => prov.cancelBooking(b.bookingId))));

    actions.add(_actionBtn(p, 'Add Note', Icons.note_add_rounded, p.accentColor, () => _showAddNote(p, b, prov)));

    if (b.status == 'completed') {
      actions.add(_actionBtn(p, 'Add Feedback', Icons.rate_review_rounded, const Color(0xFFFFA726), () => _showFeedback(p, b, prov)));
    }

    return Wrap(spacing: 10, runSpacing: 10, children: actions);
  }

  Widget _actionBtn(NeuroProfile p, String label, IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: _actionLoading ? null : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withValues(alpha: 0.3))),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Text(label, style: TextStyle(fontFamily: p.fontFamily, fontSize: 13, fontWeight: FontWeight.w700, color: color)),
        ]),
      ),
    );
  }

  Future<void> _doAction(Future<bool> Function() action) async {
    setState(() => _actionLoading = true);
    final ok = await action();
    if (mounted) {
      setState(() => _actionLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ok ? '✅ Updated successfully' : '❌ Action failed'),
        backgroundColor: ok ? const Color(0xFF4CAF50) : Colors.red.shade700,
      ));
    }
  }

  void _showReschedule(NeuroProfile p, BookingData b, BookingProvider prov) async {
    DateTime date = DateTime.now().add(const Duration(days: 1));
    TimeOfDay time = const TimeOfDay(hour: 10, minute: 0);
    final pickedDate = await showDatePicker(context: context, initialDate: date, firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 180)));
    if (pickedDate == null || !mounted) return;
    date = pickedDate;
    final pickedTime = await showTimePicker(context: context, initialTime: time);
    if (pickedTime == null || !mounted) return;
    time = pickedTime;
    final ds = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    final ts = '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    _doAction(() => prov.rescheduleBooking(b.bookingId, newDate: ds, newTime: ts));
  }

  void _showAddNote(NeuroProfile p, BookingData b, BookingProvider prov) {
    final ctrl = TextEditingController();
    showModalBottomSheet(
      context: context, backgroundColor: p.cardColor, isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Add Note', style: TextStyle(fontFamily: p.fontFamily, fontSize: 18, fontWeight: FontWeight.w800, color: p.textColor)),
          const SizedBox(height: 12),
          TextField(controller: ctrl, maxLines: 3, style: TextStyle(fontFamily: p.fontFamily, color: p.textColor),
            decoration: InputDecoration(hintText: 'Write your note...', hintStyle: TextStyle(color: p.textColor.withValues(alpha: 0.35)), filled: true, fillColor: p.backgroundColor, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none))),
          const SizedBox(height: 16),
          SizedBox(width: double.infinity, child: ElevatedButton(
            onPressed: () { Navigator.pop(ctx); if (ctrl.text.trim().isNotEmpty) _doAction(() => prov.addNote(b.bookingId, ctrl.text.trim())); },
            style: ElevatedButton.styleFrom(backgroundColor: p.accentColor, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(vertical: 14)),
            child: Text('Save Note', style: TextStyle(fontFamily: p.fontFamily, fontWeight: FontWeight.w700)),
          )),
        ]),
      ),
    );
  }

  void _showFeedback(NeuroProfile p, BookingData b, BookingProvider prov) {
    final ctrl = TextEditingController();
    showModalBottomSheet(
      context: context, backgroundColor: p.cardColor, isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Session Feedback', style: TextStyle(fontFamily: p.fontFamily, fontSize: 18, fontWeight: FontWeight.w800, color: p.textColor)),
          const SizedBox(height: 12),
          TextField(controller: ctrl, maxLines: 3, style: TextStyle(fontFamily: p.fontFamily, color: p.textColor),
            decoration: InputDecoration(hintText: 'How was your session?', hintStyle: TextStyle(color: p.textColor.withValues(alpha: 0.35)), filled: true, fillColor: p.backgroundColor, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none))),
          const SizedBox(height: 16),
          SizedBox(width: double.infinity, child: ElevatedButton(
            onPressed: () { Navigator.pop(ctx); if (ctrl.text.trim().isNotEmpty) _doAction(() => prov.updateSummary(b.bookingId, userFeedback: ctrl.text.trim())); },
            style: ElevatedButton.styleFrom(backgroundColor: p.accentColor, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(vertical: 14)),
            child: Text('Submit Feedback', style: TextStyle(fontFamily: p.fontFamily, fontWeight: FontWeight.w700)),
          )),
        ]),
      ),
    );
  }

  String _fmtDate(String iso) {
    try {
      final d = DateTime.parse(iso);
      return '${d.day}/${d.month}/${d.year} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    } catch (_) { return iso; }
  }
}
