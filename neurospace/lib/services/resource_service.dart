/// NeuroSpace — Resource Service (Full Lifecycle)
/// HTTP client for recommendations, booking CRUD, status transitions,
/// summaries, notes, dashboard stats, NGOs, and help requests.
/// Also handles Firebase persistence.

import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_service.dart';
import 'firebase_service.dart';
import '../models/resource_models.dart';

class ResourceService {
  static const _timeout = Duration(seconds: 20);

  // =============================================
  // Recommendations
  // =============================================

  static Future<List<RecommendedResource>> getRecommendations({
    String? diagnosis,
    String? difficultyLevel,
    String urgency = 'medium',
    String? ageGroup,
    String? language,
    String? budget,
    double? latitude,
    double? longitude,
    double distanceRadiusKm = 25.0,
    String deliveryMode = 'both',
    String category = 'education',
    String? sensoryNeeds,
    String? accessibilityNeeds,
  }) async {
    try {
      final body = <String, dynamic>{
        'urgency': urgency,
        'distance_radius_km': distanceRadiusKm,
        'delivery_mode': deliveryMode,
        'category': category,
      };
      if (diagnosis != null) body['diagnosis'] = diagnosis;
      if (difficultyLevel != null) body['difficulty_level'] = difficultyLevel;
      if (ageGroup != null) body['age_group'] = ageGroup;
      if (language != null) body['language'] = language;
      if (budget != null) body['budget'] = budget;
      if (latitude != null) body['latitude'] = latitude;
      if (longitude != null) body['longitude'] = longitude;
      if (sensoryNeeds != null) body['sensory_needs'] = sensoryNeeds;
      if (accessibilityNeeds != null) body['accessibility_needs'] = accessibilityNeeds;

      final response = await http
          .post(
            Uri.parse('${ApiService.baseUrl}/api/resources/recommend'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode(body),
          )
          .timeout(_timeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> items = data['recommendations'] ?? [];
        return items
            .map((e) => RecommendedResource.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      debugPrint('Recommendations failed: ${response.statusCode}');
      return [];
    } catch (e) {
      debugPrint('Recommendations error: $e');
      return [];
    }
  }

  // =============================================
  // Booking CRUD
  // =============================================

  /// Create a booking — returns full BookingData with timeline
  static Future<BookingData?> createBooking({
    required String userId,
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
    String? description,
    String? providerName,
  }) async {
    try {
      final body = {
        'user_id': userId,
        'resource_id': resourceId,
        'resource_name': resourceName,
        'resource_type': resourceType,
        'category': category,
        'date': date,
        'time': time,
        'mode': mode,
        'location': location,
        'notes': notes,
        'title': title,
        'description': description,
        'provider_name': providerName,
      };

      final response = await http
          .post(
            Uri.parse('${ApiService.baseUrl}/api/resources/book'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode(body),
          )
          .timeout(_timeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final booking = BookingData.fromJson(data);

        // Persist to Firebase
        await _saveBookingToFirebase(userId, booking);

        return booking;
      }
      debugPrint('Booking failed: ${response.statusCode} ${response.body}');
      return null;
    } catch (e) {
      debugPrint('Booking error: $e');
      return null;
    }
  }

  /// Get a single booking by ID (from backend)
  static Future<BookingData?> getBookingById(String bookingId) async {
    try {
      final response = await http
          .get(Uri.parse('${ApiService.baseUrl}/api/resources/booking/$bookingId'))
          .timeout(_timeout);

      if (response.statusCode == 200) {
        return BookingData.fromJson(json.decode(response.body));
      }
      return null;
    } catch (e) {
      debugPrint('Get booking error: $e');
      return null;
    }
  }

  /// List all bookings for a user (from backend)
  static Future<List<BookingData>> listBookings(String userId) async {
    try {
      final response = await http
          .get(Uri.parse('${ApiService.baseUrl}/api/resources/bookings/$userId'))
          .timeout(_timeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final items = data['bookings'] as List<dynamic>? ?? [];
        return items
            .map((e) => BookingData.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      return [];
    } catch (e) {
      debugPrint('List bookings error: $e');
      return [];
    }
  }

  /// Update booking fields (status, date, time, notes, mode, location)
  static Future<BookingData?> updateBooking({
    required String bookingId,
    String? status,
    String? date,
    String? time,
    String? notes,
    String? mode,
    String? location,
  }) async {
    try {
      final body = <String, dynamic>{};
      if (status != null) body['status'] = status;
      if (date != null) body['date'] = date;
      if (time != null) body['time'] = time;
      if (notes != null) body['notes'] = notes;
      if (mode != null) body['mode'] = mode;
      if (location != null) body['location'] = location;

      final response = await http
          .patch(
            Uri.parse('${ApiService.baseUrl}/api/resources/booking/$bookingId'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode(body),
          )
          .timeout(_timeout);

      if (response.statusCode == 200) {
        return BookingData.fromJson(json.decode(response.body));
      }
      return null;
    } catch (e) {
      debugPrint('Update booking error: $e');
      return null;
    }
  }

  // =============================================
  // Status Transition Shortcuts
  // =============================================

  static Future<BookingData?> confirmBooking(String bookingId) async {
    try {
      final response = await http
          .post(Uri.parse(
              '${ApiService.baseUrl}/api/resources/booking/$bookingId/confirm'))
          .timeout(_timeout);
      if (response.statusCode == 200) {
        return BookingData.fromJson(json.decode(response.body));
      }
      return null;
    } catch (e) {
      debugPrint('Confirm error: $e');
      return null;
    }
  }

  static Future<BookingData?> startSession(String bookingId) async {
    try {
      final response = await http
          .post(Uri.parse(
              '${ApiService.baseUrl}/api/resources/booking/$bookingId/start'))
          .timeout(_timeout);
      if (response.statusCode == 200) {
        return BookingData.fromJson(json.decode(response.body));
      }
      return null;
    } catch (e) {
      debugPrint('Start error: $e');
      return null;
    }
  }

  static Future<BookingData?> completeSession(String bookingId) async {
    try {
      final response = await http
          .post(Uri.parse(
              '${ApiService.baseUrl}/api/resources/booking/$bookingId/complete'))
          .timeout(_timeout);
      if (response.statusCode == 200) {
        return BookingData.fromJson(json.decode(response.body));
      }
      return null;
    } catch (e) {
      debugPrint('Complete error: $e');
      return null;
    }
  }

  static Future<BookingData?> cancelBooking(String bookingId,
      {String? reason}) async {
    try {
      final uri = Uri.parse(
          '${ApiService.baseUrl}/api/resources/booking/$bookingId/cancel'
          '${reason != null ? "?reason=${Uri.encodeComponent(reason)}" : ""}');
      final response = await http.post(uri).timeout(_timeout);
      if (response.statusCode == 200) {
        return BookingData.fromJson(json.decode(response.body));
      }
      return null;
    } catch (e) {
      debugPrint('Cancel error: $e');
      return null;
    }
  }

  static Future<BookingData?> rescheduleBooking(
    String bookingId, {
    required String newDate,
    required String newTime,
    String? reason,
  }) async {
    try {
      final body = {
        'new_date': newDate,
        'new_time': newTime,
        if (reason != null) 'reason': reason,
      };
      final response = await http
          .post(
            Uri.parse(
                '${ApiService.baseUrl}/api/resources/booking/$bookingId/reschedule'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode(body),
          )
          .timeout(_timeout);
      if (response.statusCode == 200) {
        return BookingData.fromJson(json.decode(response.body));
      }
      return null;
    } catch (e) {
      debugPrint('Reschedule error: $e');
      return null;
    }
  }

  // =============================================
  // Summary & Notes
  // =============================================

  static Future<BookingData?> updateSummary(
    String bookingId, {
    String? title,
    String? shortSummary,
    String? fullSummary,
    String? providerRemarks,
    String? userFeedback,
    String? nextSteps,
    String? followUpDate,
    String? sessionOutcome,
  }) async {
    try {
      final body = <String, dynamic>{};
      if (title != null) body['title'] = title;
      if (shortSummary != null) body['short_summary'] = shortSummary;
      if (fullSummary != null) body['full_summary'] = fullSummary;
      if (providerRemarks != null) body['provider_remarks'] = providerRemarks;
      if (userFeedback != null) body['user_feedback'] = userFeedback;
      if (nextSteps != null) body['next_steps'] = nextSteps;
      if (followUpDate != null) body['follow_up_date'] = followUpDate;
      if (sessionOutcome != null) body['session_outcome'] = sessionOutcome;

      final response = await http
          .patch(
            Uri.parse(
                '${ApiService.baseUrl}/api/resources/booking/$bookingId/summary'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode(body),
          )
          .timeout(_timeout);
      if (response.statusCode == 200) {
        return BookingData.fromJson(json.decode(response.body));
      }
      return null;
    } catch (e) {
      debugPrint('Summary update error: $e');
      return null;
    }
  }

  static Future<BookingData?> addNote(
    String bookingId, {
    required String note,
    String author = 'user',
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse(
                '${ApiService.baseUrl}/api/resources/booking/$bookingId/note'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({'note': note, 'author': author}),
          )
          .timeout(_timeout);
      if (response.statusCode == 200) {
        return BookingData.fromJson(json.decode(response.body));
      }
      return null;
    } catch (e) {
      debugPrint('Add note error: $e');
      return null;
    }
  }

  // =============================================
  // Dashboard Stats
  // =============================================

  static Future<DashboardStats> getDashboardStats(String userId) async {
    try {
      final response = await http
          .get(Uri.parse(
              '${ApiService.baseUrl}/api/resources/dashboard/$userId'))
          .timeout(_timeout);

      if (response.statusCode == 200) {
        return DashboardStats.fromJson(json.decode(response.body));
      }
      return const DashboardStats();
    } catch (e) {
      debugPrint('Dashboard stats error: $e');
      return const DashboardStats();
    }
  }

  // =============================================
  // NGO Discovery
  // =============================================

  static Future<List<NGOData>> getNearbyNGOs({
    required double latitude,
    required double longitude,
    double radiusKm = 15.0,
  }) async {
    try {
      final response = await http
          .get(Uri.parse(
            '${ApiService.baseUrl}/api/resources/ngos'
            '?lat=$latitude&lng=$longitude&radius_km=$radiusKm',
          ))
          .timeout(_timeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> items = data['ngos'] ?? [];
        return items
            .map((e) => NGOData.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      return [];
    } catch (e) {
      debugPrint('NGO fetch error: $e');
      return [];
    }
  }

  // =============================================
  // Help Requests
  // =============================================

  static Future<HelpRequestData?> sendHelpRequest({
    required String userId,
    required String ngoId,
    required String ngoName,
    required String message,
    String contactPreference = 'any',
  }) async {
    try {
      final body = {
        'user_id': userId,
        'ngo_id': ngoId,
        'ngo_name': ngoName,
        'message': message,
        'contact_preference': contactPreference,
      };

      final response = await http
          .post(
            Uri.parse('${ApiService.baseUrl}/api/resources/help-request'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode(body),
          )
          .timeout(_timeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final helpReq = HelpRequestData.fromJson(data);
        await _saveHelpRequestToFirebase(userId, helpReq);
        return helpReq;
      }
      return null;
    } catch (e) {
      debugPrint('Help request error: $e');
      return null;
    }
  }

  // =============================================
  // Firebase Persistence
  // =============================================

  static Future<void> _saveBookingToFirebase(
    String userId,
    BookingData booking,
  ) async {
    try {
      await FirebaseService.saveBooking(
        userId: userId,
        bookingData: booking.toJson(),
      );
    } catch (e) {
      debugPrint('Firebase booking save error: $e');
    }
  }

  static Future<void> _saveHelpRequestToFirebase(
    String userId,
    HelpRequestData helpReq,
  ) async {
    try {
      await FirebaseService.saveHelpRequest(
        userId: userId,
        helpData: helpReq.toJson(),
      );
    } catch (e) {
      debugPrint('Firebase help request save error: $e');
    }
  }

  /// Sync booking status to Firebase after a backend update
  static Future<void> syncBookingToFirebase(
    String userId,
    BookingData booking,
  ) async {
    try {
      final fbBookings = await FirebaseService.getBookings(userId);
      for (final fb in fbBookings) {
        if (fb['booking_id'] == booking.bookingId) {
          final key = fb['firebase_key'] as String?;
          if (key != null) {
            await FirebaseService.updateBookingStatus(
              userId: userId,
              firebaseKey: key,
              status: booking.status,
            );
          }
          break;
        }
      }
    } catch (e) {
      debugPrint('Firebase sync error: $e');
    }
  }

  static Future<List<BookingData>> getBookingsFromFirebase(
      String userId) async {
    try {
      final bookings = await FirebaseService.getBookings(userId);
      return bookings.map((e) => BookingData.fromJson(e)).toList();
    } catch (e) {
      debugPrint('Firebase bookings fetch error: $e');
      return [];
    }
  }

  static Future<List<HelpRequestData>> getHelpRequestsFromFirebase(
      String userId) async {
    try {
      final requests = await FirebaseService.getHelpRequests(userId);
      return requests.map((e) => HelpRequestData.fromJson(e)).toList();
    } catch (e) {
      debugPrint('Firebase help requests fetch error: $e');
      return [];
    }
  }
}
