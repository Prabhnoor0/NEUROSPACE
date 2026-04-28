/// NeuroSpace — Firebase Service
/// Handles Firebase Auth (anonymous) and Realtime Database operations.
/// Manages user profiles, saved lessons, and study sessions.

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

class FirebaseService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseDatabase _db = FirebaseDatabase.instance;

  // =============================================
  // Authentication
  // =============================================

  /// Get current user ID, or sign in anonymously if needed
  static Future<String> ensureAuthenticated() async {
    User? user = _auth.currentUser;
    if (user == null) {
      final credential = await _auth.signInAnonymously();
      user = credential.user;
    }
    return user!.uid;
  }

  /// Get current user ID (null if not signed in)
  static String? get currentUserId => _auth.currentUser?.uid;

  /// Check if user is signed in
  static bool get isSignedIn => _auth.currentUser != null;

  // =============================================
  // User Profile
  // =============================================

  /// Save the user's neuro-profile to Firebase
  static Future<void> saveProfile({
    required String userId,
    required Map<String, dynamic> profileData,
  }) async {
    profileData['updatedAt'] = DateTime.now().toIso8601String();
    await _db.ref('users/$userId/profile').set(profileData);
  }

  /// Get the user's profile from Firebase
  static Future<Map<String, dynamic>?> getProfile(String userId) async {
    final snapshot = await _db.ref('users/$userId/profile').get();
    if (snapshot.exists && snapshot.value != null) {
      return Map<String, dynamic>.from(snapshot.value as Map);
    }
    return null;
  }

  // =============================================
  // Lessons (Library)
  // =============================================

  /// Save a generated lesson to the user's library
  static Future<String> saveLesson({
    required String userId,
    required Map<String, dynamic> lessonData,
  }) async {
    lessonData['createdAt'] = DateTime.now().toIso8601String();

    final ref = _db.ref('users/$userId/lessons').push();
    await ref.set(lessonData);
    return ref.key!;
  }

  /// Get all saved lessons for a user
  static Future<List<Map<String, dynamic>>> getLessons(String userId) async {
    final snapshot = await _db
        .ref('users/$userId/lessons')
        .orderByChild('createdAt')
        .get();

    if (!snapshot.exists || snapshot.value == null) {
      return [];
    }

    final lessonsMap = Map<String, dynamic>.from(snapshot.value as Map);
    final lessons = <Map<String, dynamic>>[];

    lessonsMap.forEach((key, value) {
      final lesson = Map<String, dynamic>.from(value as Map);
      lesson['id'] = key;
      lessons.add(lesson);
    });

    // Sort by createdAt descending (most recent first)
    lessons.sort((a, b) {
      final aDate = a['createdAt'] ?? '';
      final bDate = b['createdAt'] ?? '';
      return bDate.compareTo(aDate);
    });

    return lessons;
  }

  /// Get a single lesson by ID
  static Future<Map<String, dynamic>?> getLesson(
      String userId, String lessonId) async {
    final snapshot = await _db.ref('users/$userId/lessons/$lessonId').get();
    if (snapshot.exists && snapshot.value != null) {
      final lesson = Map<String, dynamic>.from(snapshot.value as Map);
      lesson['id'] = lessonId;
      return lesson;
    }
    return null;
  }

  /// Delete a lesson by ID
  static Future<void> deleteLesson(String userId, String lessonId) async {
    await _db.ref('users/$userId/lessons/$lessonId').remove();
  }

  // =============================================
  // Study Sessions (Focus Timer)
  // =============================================

  /// Log a completed focus/study session
  static Future<String> logStudySession({
    required String userId,
    required int durationMinutes,
    String? topic,
    String? energyBefore,
    String? energyAfter,
  }) async {
    final sessionData = {
      'durationMinutes': durationMinutes,
      'topic': topic,
      'energyBefore': energyBefore,
      'energyAfter': energyAfter,
      'completedAt': DateTime.now().toIso8601String(),
      'dayOfWeek': DateTime.now().weekday,
      'hourOfDay': DateTime.now().hour,
    };

    final ref = _db.ref('users/$userId/studySessions').push();
    await ref.set(sessionData);
    return ref.key!;
  }

  /// Get recent study sessions (for analytics)
  static Future<List<Map<String, dynamic>>> getStudySessions(
    String userId, {
    int limit = 50,
  }) async {
    final snapshot = await _db
        .ref('users/$userId/studySessions')
        .orderByChild('completedAt')
        .limitToLast(limit)
        .get();

    if (!snapshot.exists || snapshot.value == null) {
      return [];
    }

    final sessionsMap = Map<String, dynamic>.from(snapshot.value as Map);
    final sessions = <Map<String, dynamic>>[];

    sessionsMap.forEach((key, value) {
      final session = Map<String, dynamic>.from(value as Map);
      session['id'] = key;
      sessions.add(session);
    });

    sessions.sort((a, b) {
      final aDate = a['completedAt'] ?? '';
      final bDate = b['completedAt'] ?? '';
      return bDate.compareTo(aDate);
    });

    return sessions;
  }

  /// Get total study minutes (lifetime)
  static Future<int> getTotalStudyMinutes(String userId) async {
    final sessions = await getStudySessions(userId);
    int total = 0;
    for (final session in sessions) {
      total += (session['durationMinutes'] as int? ?? 0);
    }
    return total;
  }

  // =============================================
  // Resource Bookings
  // =============================================

  /// Save a resource booking
  static Future<String> saveBooking({
    required String userId,
    required Map<String, dynamic> bookingData,
  }) async {
    bookingData['savedAt'] = DateTime.now().toIso8601String();
    final ref = _db.ref('users/$userId/bookings').push();
    await ref.set(bookingData);
    return ref.key!;
  }

  /// Get all bookings for a user
  static Future<List<Map<String, dynamic>>> getBookings(String userId) async {
    final snapshot = await _db
        .ref('users/$userId/bookings')
        .orderByChild('date')
        .get();

    if (!snapshot.exists || snapshot.value == null) return [];

    final bookingsMap = Map<String, dynamic>.from(snapshot.value as Map);
    final bookings = <Map<String, dynamic>>[];

    bookingsMap.forEach((key, value) {
      final booking = Map<String, dynamic>.from(value as Map);
      booking['firebase_key'] = key;
      bookings.add(booking);
    });

    bookings.sort((a, b) {
      final aDate = a['date'] ?? '';
      final bDate = b['date'] ?? '';
      return bDate.compareTo(aDate);
    });

    return bookings;
  }

  /// Update a booking status in Firebase
  static Future<void> updateBookingStatus({
    required String userId,
    required String firebaseKey,
    required String status,
  }) async {
    await _db.ref('users/$userId/bookings/$firebaseKey/status').set(status);
  }

  // =============================================
  // Help Requests
  // =============================================

  /// Save a help request
  static Future<String> saveHelpRequest({
    required String userId,
    required Map<String, dynamic> helpData,
  }) async {
    helpData['savedAt'] = DateTime.now().toIso8601String();
    final ref = _db.ref('users/$userId/helpRequests').push();
    await ref.set(helpData);
    return ref.key!;
  }

  /// Get all help requests for a user
  static Future<List<Map<String, dynamic>>> getHelpRequests(
      String userId) async {
    final snapshot = await _db
        .ref('users/$userId/helpRequests')
        .orderByChild('created_at')
        .get();

    if (!snapshot.exists || snapshot.value == null) return [];

    final requestsMap = Map<String, dynamic>.from(snapshot.value as Map);
    final requests = <Map<String, dynamic>>[];

    requestsMap.forEach((key, value) {
      final request = Map<String, dynamic>.from(value as Map);
      request['firebase_key'] = key;
      requests.add(request);
    });

    requests.sort((a, b) {
      final aDate = a['created_at'] ?? '';
      final bDate = b['created_at'] ?? '';
      return bDate.compareTo(aDate);
    });

    return requests;
  }
}

