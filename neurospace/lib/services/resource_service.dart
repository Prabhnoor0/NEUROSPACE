/// NeuroSpace — Resource Allocation Service
/// HTTP client for recommendation, booking, NGO, and help request APIs.
/// Also handles Firebase persistence for bookings and help requests.

import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_service.dart';
import 'firebase_service.dart';
import '../models/resource_models.dart';

class ResourceService {
  // =============================================
  // Recommendations
  // =============================================

  /// Get AI-scored resource recommendations
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
          .timeout(const Duration(seconds: 20));

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
  // Booking
  // =============================================

  /// Create a booking via the backend API and persist to Firebase
  static Future<BookingData?> createBooking({
    required String userId,
    required String resourceId,
    required String resourceName,
    required String resourceType,
    required String category,
    required String date,
    required String time,
    String? location,
    String? notes,
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
        'location': location,
        'notes': notes,
      };

      final response = await http
          .post(
            Uri.parse('${ApiService.baseUrl}/api/resources/book'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode(body),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final booking = BookingData.fromJson(data);

        // Persist to Firebase
        await _saveBookingToFirebase(userId, booking);

        return booking;
      }
      debugPrint('Booking failed: ${response.statusCode}');
      return null;
    } catch (e) {
      debugPrint('Booking error: $e');
      return null;
    }
  }

  /// Update a booking status
  static Future<BookingData?> updateBooking({
    required String bookingId,
    String? status,
    String? date,
    String? time,
    String? notes,
  }) async {
    try {
      final body = <String, dynamic>{};
      if (status != null) body['status'] = status;
      if (date != null) body['date'] = date;
      if (time != null) body['time'] = time;
      if (notes != null) body['notes'] = notes;

      final response = await http
          .patch(
            Uri.parse('${ApiService.baseUrl}/api/resources/booking/$bookingId'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode(body),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return BookingData.fromJson(data);
      }
      return null;
    } catch (e) {
      debugPrint('Update booking error: $e');
      return null;
    }
  }

  // =============================================
  // NGO Discovery
  // =============================================

  /// Get nearby NGOs
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
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> items = data['ngos'] ?? [];
        return items
            .map((e) => NGOData.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      debugPrint('NGO fetch failed: ${response.statusCode}');
      return [];
    } catch (e) {
      debugPrint('NGO fetch error: $e');
      return [];
    }
  }

  // =============================================
  // Help Requests
  // =============================================

  /// Send a help request to an NGO
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
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final helpReq = HelpRequestData.fromJson(data);

        // Persist to Firebase
        await _saveHelpRequestToFirebase(userId, helpReq);

        return helpReq;
      }
      debugPrint('Help request failed: ${response.statusCode}');
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

  /// Get all bookings from Firebase for a user
  static Future<List<BookingData>> getBookingsFromFirebase(
    String userId,
  ) async {
    try {
      final bookings = await FirebaseService.getBookings(userId);
      return bookings
          .map((e) => BookingData.fromJson(e))
          .toList();
    } catch (e) {
      debugPrint('Firebase bookings fetch error: $e');
      return [];
    }
  }

  /// Get all help requests from Firebase for a user
  static Future<List<HelpRequestData>> getHelpRequestsFromFirebase(
    String userId,
  ) async {
    try {
      final requests = await FirebaseService.getHelpRequests(userId);
      return requests
          .map((e) => HelpRequestData.fromJson(e))
          .toList();
    } catch (e) {
      debugPrint('Firebase help requests fetch error: $e');
      return [];
    }
  }
}
