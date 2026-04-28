/// NeuroSpace — Resource Allocation Models
/// Data models for recommendations, bookings, NGOs, and help requests.
/// Mirrors backend Pydantic schemas for type-safe serialization.

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

  /// Human-readable type label
  String get typeLabel => type.replaceAll('_', ' ').split(' ').map(
        (w) => w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : '',
      ).join(' ');
}


class BookingData {
  final String bookingId;
  final String userId;
  final String resourceId;
  final String resourceName;
  final String resourceType;
  final String category;
  final String date;
  final String time;
  final String? location;
  final String? notes;
  final String status;
  final String createdAt;

  const BookingData({
    required this.bookingId,
    required this.userId,
    required this.resourceId,
    required this.resourceName,
    required this.resourceType,
    required this.category,
    required this.date,
    required this.time,
    this.location,
    this.notes,
    this.status = 'pending',
    required this.createdAt,
  });

  factory BookingData.fromJson(Map<String, dynamic> json) {
    return BookingData(
      bookingId: json['booking_id'] as String? ?? '',
      userId: json['user_id'] as String? ?? '',
      resourceId: json['resource_id'] as String? ?? '',
      resourceName: json['resource_name'] as String? ?? '',
      resourceType: json['resource_type'] as String? ?? '',
      category: json['category'] as String? ?? '',
      date: json['date'] as String? ?? '',
      time: json['time'] as String? ?? '',
      location: json['location'] as String?,
      notes: json['notes'] as String?,
      status: json['status'] as String? ?? 'pending',
      createdAt: json['created_at'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'booking_id': bookingId,
        'user_id': userId,
        'resource_id': resourceId,
        'resource_name': resourceName,
        'resource_type': resourceType,
        'category': category,
        'date': date,
        'time': time,
        'location': location,
        'notes': notes,
        'status': status,
        'created_at': createdAt,
      };

  String get statusLabel => status[0].toUpperCase() + status.substring(1);
}


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
