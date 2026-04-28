/// NeuroSpace — Resource Allocation Models
/// Full lifecycle models: recommendations, bookings with timeline/summary,
/// NGOs, help requests, and dashboard stats.

import 'package:flutter/material.dart';

// ============================================
// Booking Status Enum
// ============================================

enum BookingStatusType {
  pending,
  notConfirmed,
  confirmed,
  rescheduled,
  inProgress,
  completed,
  cancelled;

  String get value {
    switch (this) {
      case BookingStatusType.pending:
        return 'pending';
      case BookingStatusType.notConfirmed:
        return 'not_confirmed';
      case BookingStatusType.confirmed:
        return 'confirmed';
      case BookingStatusType.rescheduled:
        return 'rescheduled';
      case BookingStatusType.inProgress:
        return 'in_progress';
      case BookingStatusType.completed:
        return 'completed';
      case BookingStatusType.cancelled:
        return 'cancelled';
    }
  }

  String get label {
    switch (this) {
      case BookingStatusType.pending:
        return 'Pending';
      case BookingStatusType.notConfirmed:
        return 'Not Confirmed';
      case BookingStatusType.confirmed:
        return 'Confirmed';
      case BookingStatusType.rescheduled:
        return 'Rescheduled';
      case BookingStatusType.inProgress:
        return 'In Progress';
      case BookingStatusType.completed:
        return 'Completed';
      case BookingStatusType.cancelled:
        return 'Cancelled';
    }
  }

  Color get color {
    switch (this) {
      case BookingStatusType.pending:
        return const Color(0xFFFFA726);
      case BookingStatusType.notConfirmed:
        return const Color(0xFFFF7043);
      case BookingStatusType.confirmed:
        return const Color(0xFF4CAF50);
      case BookingStatusType.rescheduled:
        return const Color(0xFF7C4DFF);
      case BookingStatusType.inProgress:
        return const Color(0xFF42A5F5);
      case BookingStatusType.completed:
        return const Color(0xFF26A69A);
      case BookingStatusType.cancelled:
        return const Color(0xFFEF5350);
    }
  }

  IconData get icon {
    switch (this) {
      case BookingStatusType.pending:
        return Icons.hourglass_top_rounded;
      case BookingStatusType.notConfirmed:
        return Icons.help_outline_rounded;
      case BookingStatusType.confirmed:
        return Icons.check_circle_rounded;
      case BookingStatusType.rescheduled:
        return Icons.update_rounded;
      case BookingStatusType.inProgress:
        return Icons.play_circle_rounded;
      case BookingStatusType.completed:
        return Icons.task_alt_rounded;
      case BookingStatusType.cancelled:
        return Icons.cancel_rounded;
    }
  }

  String get explanation {
    switch (this) {
      case BookingStatusType.pending:
        return 'Awaiting confirmation from provider';
      case BookingStatusType.notConfirmed:
        return 'Provider has not responded yet';
      case BookingStatusType.confirmed:
        return 'Session confirmed — be there on time!';
      case BookingStatusType.rescheduled:
        return 'Session moved to a new date/time';
      case BookingStatusType.inProgress:
        return 'Your session is happening now';
      case BookingStatusType.completed:
        return 'Session completed — check summary';
      case BookingStatusType.cancelled:
        return 'This booking has been cancelled';
    }
  }

  static BookingStatusType fromString(String? s) {
    switch (s) {
      case 'pending':
        return BookingStatusType.pending;
      case 'not_confirmed':
        return BookingStatusType.notConfirmed;
      case 'confirmed':
        return BookingStatusType.confirmed;
      case 'rescheduled':
        return BookingStatusType.rescheduled;
      case 'in_progress':
        return BookingStatusType.inProgress;
      case 'completed':
        return BookingStatusType.completed;
      case 'cancelled':
        return BookingStatusType.cancelled;
      default:
        return BookingStatusType.pending;
    }
  }
}

// ============================================
// Timeline Event
// ============================================

class TimelineEvent {
  final String timestamp;
  final String status;
  final String title;
  final String? description;
  final String actor;

  const TimelineEvent({
    required this.timestamp,
    required this.status,
    required this.title,
    this.description,
    this.actor = 'system',
  });

  factory TimelineEvent.fromJson(Map<String, dynamic> json) => TimelineEvent(
        timestamp: json['timestamp'] as String? ?? '',
        status: json['status'] as String? ?? '',
        title: json['title'] as String? ?? '',
        description: json['description'] as String?,
        actor: json['actor'] as String? ?? 'system',
      );

  Map<String, dynamic> toJson() => {
        'timestamp': timestamp,
        'status': status,
        'title': title,
        'description': description,
        'actor': actor,
      };

  DateTime? get dateTime {
    try {
      return DateTime.parse(timestamp);
    } catch (_) {
      return null;
    }
  }
}

// ============================================
// Session Summary
// ============================================

class SessionSummary {
  final String? title;
  final String? shortSummary;
  final String? fullSummary;
  final String? statusNote;
  final String? providerRemarks;
  final String? userFeedback;
  final String? supportGiven;
  final String? nextSteps;
  final String? followUpDate;
  final String? sessionOutcome;
  final String? resourceRecommendation;
  final String? attendance;

  const SessionSummary({
    this.title,
    this.shortSummary,
    this.fullSummary,
    this.statusNote,
    this.providerRemarks,
    this.userFeedback,
    this.supportGiven,
    this.nextSteps,
    this.followUpDate,
    this.sessionOutcome,
    this.resourceRecommendation,
    this.attendance,
  });

  factory SessionSummary.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const SessionSummary();
    return SessionSummary(
      title: json['title'] as String?,
      shortSummary: json['short_summary'] as String?,
      fullSummary: json['full_summary'] as String?,
      statusNote: json['status_note'] as String?,
      providerRemarks: json['provider_remarks'] as String?,
      userFeedback: json['user_feedback'] as String?,
      supportGiven: json['support_given'] as String?,
      nextSteps: json['next_steps'] as String?,
      followUpDate: json['follow_up_date'] as String?,
      sessionOutcome: json['session_outcome'] as String?,
      resourceRecommendation: json['resource_recommendation'] as String?,
      attendance: json['attendance'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'title': title,
        'short_summary': shortSummary,
        'full_summary': fullSummary,
        'status_note': statusNote,
        'provider_remarks': providerRemarks,
        'user_feedback': userFeedback,
        'support_given': supportGiven,
        'next_steps': nextSteps,
        'follow_up_date': followUpDate,
        'session_outcome': sessionOutcome,
        'resource_recommendation': resourceRecommendation,
        'attendance': attendance,
      };

  bool get isEmpty =>
      shortSummary == null &&
      fullSummary == null &&
      statusNote == null &&
      providerRemarks == null;
}

// ============================================
// Booking Data (full lifecycle)
// ============================================

class BookingData {
  final String bookingId;
  final String userId;
  final String resourceId;
  final String resourceName;
  final String resourceType;
  final String category;
  final String title;
  final String? description;
  final String? providerName;
  final String date;
  final String time;
  final String mode;
  final String? location;
  final String? notes;
  final String status;
  final String createdAt;
  final String updatedAt;
  final SessionSummary summary;
  final List<TimelineEvent> timeline;

  const BookingData({
    required this.bookingId,
    required this.userId,
    required this.resourceId,
    required this.resourceName,
    required this.resourceType,
    required this.category,
    required this.title,
    this.description,
    this.providerName,
    required this.date,
    required this.time,
    this.mode = 'in_person',
    this.location,
    this.notes,
    this.status = 'pending',
    required this.createdAt,
    required this.updatedAt,
    this.summary = const SessionSummary(),
    this.timeline = const [],
  });

  BookingStatusType get statusType => BookingStatusType.fromString(status);

  String get statusLabel => statusType.label;
  Color get statusColor => statusType.color;
  IconData get statusIcon => statusType.icon;

  String get modeLabel {
    switch (mode) {
      case 'online':
        return 'Online';
      case 'in_person':
        return 'In Person';
      case 'phone':
        return 'Phone';
      case 'home_visit':
        return 'Home Visit';
      default:
        return mode.replaceAll('_', ' ');
    }
  }

  String get typeLabel => resourceType
      .replaceAll('_', ' ')
      .split(' ')
      .map((w) => w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : '')
      .join(' ');

  DateTime? get appointmentDate {
    try {
      return DateTime.parse(date);
    } catch (_) {
      return null;
    }
  }

  bool get isUpcoming {
    final d = appointmentDate;
    if (d == null) return false;
    return d.isAfter(DateTime.now().subtract(const Duration(days: 1))) &&
        status != 'cancelled' &&
        status != 'completed';
  }

  bool get canCancel =>
      status == 'pending' ||
      status == 'confirmed' ||
      status == 'rescheduled' ||
      status == 'not_confirmed';

  bool get canReschedule =>
      status == 'pending' ||
      status == 'confirmed' ||
      status == 'not_confirmed';

  bool get canConfirm => status == 'pending' || status == 'not_confirmed';

  bool get canComplete => status == 'confirmed' || status == 'in_progress';

  bool get canStart => status == 'confirmed';

  factory BookingData.fromJson(Map<String, dynamic> json) {
    return BookingData(
      bookingId: json['booking_id'] as String? ?? '',
      userId: json['user_id'] as String? ?? '',
      resourceId: json['resource_id'] as String? ?? '',
      resourceName: json['resource_name'] as String? ?? '',
      resourceType: json['resource_type'] as String? ?? '',
      category: json['category'] as String? ?? '',
      title: json['title'] as String? ?? json['resource_name'] as String? ?? '',
      description: json['description'] as String?,
      providerName: json['provider_name'] as String?,
      date: json['date'] as String? ?? '',
      time: json['time'] as String? ?? '',
      mode: json['mode'] as String? ?? 'in_person',
      location: json['location'] as String?,
      notes: json['notes'] as String?,
      status: json['status'] as String? ?? 'pending',
      createdAt: json['created_at'] as String? ?? '',
      updatedAt: json['updated_at'] as String? ?? json['created_at'] as String? ?? '',
      summary: SessionSummary.fromJson(
          json['summary'] as Map<String, dynamic>?),
      timeline: (json['timeline'] as List<dynamic>?)
              ?.map((e) => TimelineEvent.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() => {
        'booking_id': bookingId,
        'user_id': userId,
        'resource_id': resourceId,
        'resource_name': resourceName,
        'resource_type': resourceType,
        'category': category,
        'title': title,
        'description': description,
        'provider_name': providerName,
        'date': date,
        'time': time,
        'mode': mode,
        'location': location,
        'notes': notes,
        'status': status,
        'created_at': createdAt,
        'updated_at': updatedAt,
        'summary': summary.toJson(),
        'timeline': timeline.map((e) => e.toJson()).toList(),
      };
}

// ============================================
// Dashboard Stats
// ============================================

class DashboardStats {
  final int totalBookings;
  final int pending;
  final int confirmed;
  final int inProgress;
  final int completed;
  final int cancelled;
  final int rescheduled;
  final int notConfirmed;
  final int upcomingCount;
  final BookingData? nextSession;
  final List<TimelineEvent> recentActivity;

  const DashboardStats({
    this.totalBookings = 0,
    this.pending = 0,
    this.confirmed = 0,
    this.inProgress = 0,
    this.completed = 0,
    this.cancelled = 0,
    this.rescheduled = 0,
    this.notConfirmed = 0,
    this.upcomingCount = 0,
    this.nextSession,
    this.recentActivity = const [],
  });

  factory DashboardStats.fromJson(Map<String, dynamic> json) {
    return DashboardStats(
      totalBookings: json['total_bookings'] as int? ?? 0,
      pending: json['pending'] as int? ?? 0,
      confirmed: json['confirmed'] as int? ?? 0,
      inProgress: json['in_progress'] as int? ?? 0,
      completed: json['completed'] as int? ?? 0,
      cancelled: json['cancelled'] as int? ?? 0,
      rescheduled: json['rescheduled'] as int? ?? 0,
      notConfirmed: json['not_confirmed'] as int? ?? 0,
      upcomingCount: json['upcoming_count'] as int? ?? 0,
      nextSession: json['next_session'] != null
          ? BookingData.fromJson(json['next_session'] as Map<String, dynamic>)
          : null,
      recentActivity: (json['recent_activity'] as List<dynamic>?)
              ?.map((e) => TimelineEvent.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

// ============================================
// Recommended Resource (unchanged)
// ============================================

class RecommendedResource {
  final String id;
  final String name;
  final String type;
  final String category;
  final double? distanceKm;
  final String availability;
  final String? priceRange;
  final String? location;
  final double? latitude;
  final double? longitude;
  final String? contact;
  final String? email;
  final String? accessibilityNotes;
  final double score;
  final String reason;
  final bool bookingAvailable;
  final List<String> languages;
  final String? timings;
  final List<String> services;

  const RecommendedResource({
    required this.id,
    required this.name,
    required this.type,
    required this.category,
    this.distanceKm,
    this.availability = 'Available',
    this.priceRange,
    this.location,
    this.latitude,
    this.longitude,
    this.contact,
    this.email,
    this.accessibilityNotes,
    required this.score,
    required this.reason,
    this.bookingAvailable = true,
    this.languages = const ['English'],
    this.timings,
    this.services = const [],
  });

  factory RecommendedResource.fromJson(Map<String, dynamic> json) {
    return RecommendedResource(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'Unknown',
      type: json['type'] as String? ?? 'hospital',
      category: json['category'] as String? ?? 'medical',
      distanceKm: (json['distance_km'] as num?)?.toDouble(),
      availability: json['availability'] as String? ?? 'Available',
      priceRange: json['price_range'] as String?,
      location: json['location'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      contact: json['contact'] as String?,
      email: json['email'] as String?,
      accessibilityNotes: json['accessibility_notes'] as String?,
      score: (json['score'] as num?)?.toDouble() ?? 0.0,
      reason: json['reason'] as String? ?? '',
      bookingAvailable: json['booking_available'] as bool? ?? true,
      languages: (json['languages'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          ['English'],
      timings: json['timings'] as String?,
      services: (json['services'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'type': type,
        'category': category,
        'distance_km': distanceKm,
        'availability': availability,
        'price_range': priceRange,
        'location': location,
        'latitude': latitude,
        'longitude': longitude,
        'contact': contact,
        'email': email,
        'accessibility_notes': accessibilityNotes,
        'score': score,
        'reason': reason,
        'booking_available': bookingAvailable,
        'languages': languages,
        'timings': timings,
        'services': services,
      };

  String get typeLabel => type
      .replaceAll('_', ' ')
      .split(' ')
      .map((w) => w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : '')
      .join(' ');
}

// ============================================
// NGO Data (unchanged)
// ============================================

class NGOData {
  final String id;
  final String name;
  final double? distanceKm;
  final List<String> services;
  final String? contact;
  final String? whatsapp;
  final String? email;
  final List<String> languages;
  final String? timings;
  final String? areaServed;
  final double? latitude;
  final double? longitude;

  const NGOData({
    required this.id,
    required this.name,
    this.distanceKm,
    this.services = const [],
    this.contact,
    this.whatsapp,
    this.email,
    this.languages = const ['English'],
    this.timings,
    this.areaServed,
    this.latitude,
    this.longitude,
  });

  factory NGOData.fromJson(Map<String, dynamic> json) {
    return NGOData(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'Unknown NGO',
      distanceKm: (json['distance_km'] as num?)?.toDouble(),
      services: (json['services'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      contact: json['contact'] as String?,
      whatsapp: json['whatsapp'] as String?,
      email: json['email'] as String?,
      languages: (json['languages'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          ['English'],
      timings: json['timings'] as String?,
      areaServed: json['area_served'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'distance_km': distanceKm,
        'services': services,
        'contact': contact,
        'whatsapp': whatsapp,
        'email': email,
        'languages': languages,
        'timings': timings,
        'area_served': areaServed,
        'latitude': latitude,
        'longitude': longitude,
      };
}

// ============================================
// Help Request (unchanged)
// ============================================

class HelpRequestData {
  final String requestId;
  final String userId;
  final String ngoId;
  final String ngoName;
  final String message;
  final String contactPreference;
  final String status;
  final String createdAt;

  const HelpRequestData({
    required this.requestId,
    required this.userId,
    required this.ngoId,
    required this.ngoName,
    required this.message,
    this.contactPreference = 'any',
    this.status = 'sent',
    required this.createdAt,
  });

  factory HelpRequestData.fromJson(Map<String, dynamic> json) {
    return HelpRequestData(
      requestId: json['request_id'] as String? ?? '',
      userId: json['user_id'] as String? ?? '',
      ngoId: json['ngo_id'] as String? ?? '',
      ngoName: json['ngo_name'] as String? ?? '',
      message: json['message'] as String? ?? '',
      contactPreference: json['contact_preference'] as String? ?? 'any',
      status: json['status'] as String? ?? 'sent',
      createdAt: json['created_at'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'request_id': requestId,
        'user_id': userId,
        'ngo_id': ngoId,
        'ngo_name': ngoName,
        'message': message,
        'contact_preference': contactPreference,
        'status': status,
        'created_at': createdAt,
      };
}
