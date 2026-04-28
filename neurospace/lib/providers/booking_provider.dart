/// NeuroSpace — Booking Provider
/// Reactive state management for bookings, dashboard stats, and session lifecycle.
/// Connects backend API ↔ UI with auto-refresh and Firebase sync.

import 'package:flutter/foundation.dart';
import '../models/resource_models.dart';
import '../services/resource_service.dart';
import '../services/firebase_service.dart';

class BookingProvider extends ChangeNotifier {
  // State
  List<BookingData> _bookings = [];
  DashboardStats _stats = const DashboardStats();
  bool _isLoading = false;
  String? _error;
  String? _userId;

  // Getters
  List<BookingData> get bookings => _bookings;
  DashboardStats get stats => _stats;
  bool get isLoading => _isLoading;
  String? get error => _error;

  List<BookingData> get upcoming => _bookings
      .where((b) =>
          b.isUpcoming &&
          b.status != 'completed' &&
          b.status != 'cancelled')
      .toList()
    ..sort((a, b) => (a.date).compareTo(b.date));

  List<BookingData> get pending =>
      _bookings.where((b) => b.status == 'pending' || b.status == 'not_confirmed').toList();

  List<BookingData> get confirmed =>
      _bookings.where((b) => b.status == 'confirmed').toList();

  List<BookingData> get inProgress =>
      _bookings.where((b) => b.status == 'in_progress').toList();

  List<BookingData> get completed =>
      _bookings.where((b) => b.status == 'completed').toList();

  List<BookingData> get cancelled =>
      _bookings.where((b) => b.status == 'cancelled').toList();

  List<BookingData> get rescheduled =>
      _bookings.where((b) => b.status == 'rescheduled').toList();

  // =============================================
  // Initialization
  // =============================================

  void setUserId(String userId) {
    _userId = userId;
  }

  String get userId => _userId ?? FirebaseService.currentUserId ?? 'anon';

  // =============================================
  // Load Data
  // =============================================

  /// Load all bookings + stats from backend, fallback to Firebase
  Future<void> loadAll() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Try backend first
      final backendBookings = await ResourceService.listBookings(userId);
      if (backendBookings.isNotEmpty) {
        _bookings = backendBookings;
      } else {
        // Fallback to Firebase
        _bookings = await ResourceService.getBookingsFromFirebase(userId);
      }

      // Load stats
      _stats = await ResourceService.getDashboardStats(userId);
    } catch (e) {
      debugPrint('BookingProvider loadAll error: $e');
      _error = 'Failed to load bookings';
      // Try Firebase fallback
      try {
        _bookings = await ResourceService.getBookingsFromFirebase(userId);
      } catch (_) {}
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Refresh stats only (lighter call)
  Future<void> refreshStats() async {
    try {
      _stats = await ResourceService.getDashboardStats(userId);
      notifyListeners();
    } catch (e) {
      debugPrint('Stats refresh error: $e');
    }
  }

  // =============================================
  // Create Booking
  // =============================================

  Future<BookingData?> createBooking({
    required String resourceId,
    required String resourceName,
    required String resourceType,
    required String category,
    required String date,
    required String time,
    String mode = 'in_person',
    String? location,
    String? notes,
    String? title,
    String? providerName,
  }) async {
    final booking = await ResourceService.createBooking(
      userId: userId,
      resourceId: resourceId,
      resourceName: resourceName,
      resourceType: resourceType,
      category: category,
      date: date,
      time: time,
      mode: mode,
      location: location,
      notes: notes,
      title: title,
      providerName: providerName,
    );

    if (booking != null) {
      // Insert at top immediately
      _bookings.insert(0, booking);
      // Refresh stats
      await refreshStats();
      notifyListeners();
    }

    return booking;
  }

  // =============================================
  // Status Transitions
  // =============================================

  Future<bool> confirmBooking(String bookingId) async {
    final result = await ResourceService.confirmBooking(bookingId);
    if (result != null) {
      _replaceBooking(result);
      await ResourceService.syncBookingToFirebase(userId, result);
      await refreshStats();
      return true;
    }
    return false;
  }

  Future<bool> startSession(String bookingId) async {
    final result = await ResourceService.startSession(bookingId);
    if (result != null) {
      _replaceBooking(result);
      await ResourceService.syncBookingToFirebase(userId, result);
      await refreshStats();
      return true;
    }
    return false;
  }

  Future<bool> completeSession(String bookingId) async {
    final result = await ResourceService.completeSession(bookingId);
    if (result != null) {
      _replaceBooking(result);
      await ResourceService.syncBookingToFirebase(userId, result);
      await refreshStats();
      return true;
    }
    return false;
  }

  Future<bool> cancelBooking(String bookingId, {String? reason}) async {
    final result =
        await ResourceService.cancelBooking(bookingId, reason: reason);
    if (result != null) {
      _replaceBooking(result);
      await ResourceService.syncBookingToFirebase(userId, result);
      await refreshStats();
      return true;
    }
    return false;
  }

  Future<bool> rescheduleBooking(
    String bookingId, {
    required String newDate,
    required String newTime,
    String? reason,
  }) async {
    final result = await ResourceService.rescheduleBooking(
      bookingId,
      newDate: newDate,
      newTime: newTime,
      reason: reason,
    );
    if (result != null) {
      _replaceBooking(result);
      await ResourceService.syncBookingToFirebase(userId, result);
      await refreshStats();
      return true;
    }
    return false;
  }

  // =============================================
  // Notes & Summary
  // =============================================

  Future<bool> addNote(String bookingId, String note) async {
    final result =
        await ResourceService.addNote(bookingId, note: note);
    if (result != null) {
      _replaceBooking(result);
      return true;
    }
    return false;
  }

  Future<bool> updateSummary(
    String bookingId, {
    String? userFeedback,
    String? nextSteps,
    String? sessionOutcome,
  }) async {
    final result = await ResourceService.updateSummary(
      bookingId,
      userFeedback: userFeedback,
      nextSteps: nextSteps,
      sessionOutcome: sessionOutcome,
    );
    if (result != null) {
      _replaceBooking(result);
      return true;
    }
    return false;
  }

  // =============================================
  // Helpers
  // =============================================

  void _replaceBooking(BookingData updated) {
    final idx = _bookings.indexWhere((b) => b.bookingId == updated.bookingId);
    if (idx >= 0) {
      _bookings[idx] = updated;
    } else {
      _bookings.insert(0, updated);
    }
    notifyListeners();
  }

  BookingData? getById(String bookingId) {
    try {
      return _bookings.firstWhere((b) => b.bookingId == bookingId);
    } catch (_) {
      return null;
    }
  }

  /// Search bookings by title or provider name
  List<BookingData> search(String query) {
    if (query.isEmpty) return _bookings;
    final q = query.toLowerCase();
    return _bookings.where((b) {
      return b.title.toLowerCase().contains(q) ||
          b.resourceName.toLowerCase().contains(q) ||
          (b.providerName?.toLowerCase().contains(q) ?? false) ||
          b.category.toLowerCase().contains(q) ||
          b.resourceType.toLowerCase().contains(q);
    }).toList();
  }

  /// Filter bookings by status
  List<BookingData> filterByStatus(String? status) {
    if (status == null || status.isEmpty || status == 'all') return _bookings;
    return _bookings.where((b) => b.status == status).toList();
  }

  /// Filter by category
  List<BookingData> filterByCategory(String? category) {
    if (category == null || category.isEmpty || category == 'all') {
      return _bookings;
    }
    return _bookings.where((b) => b.category == category).toList();
  }
}
