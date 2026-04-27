/// NeuroSpace — API Service
/// Handles all HTTP communication with the FastAPI backend.
import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'dart:io' show Platform;
import 'package:http/http.dart' as http;

class ApiService {
  // Android emulator uses 10.0.2.2 to reach host; iOS simulator uses localhost
  static String get _baseUrl {
    if (Platform.isAndroid) {
      return 'http://10.0.2.2:8000';
    } else {
      return 'http://localhost:8000';
    }
  }

  static String get baseUrl => _baseUrl;

  // =============================================
  // Health Check (Step 0.3 verification)
  // =============================================

  /// Check if the backend is running
  static Future<Map<String, dynamic>> healthCheck() async {
    try {
      final response = await http
          .get(Uri.parse('$_baseUrl/health'))
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Backend returned ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Cannot reach backend: $e');
    }
  }

  // =============================================
  // Lesson Generation
  // =============================================

  /// Generate an adaptive lesson for a topic
  static Future<Map<String, dynamic>> generateLesson({
    required String topic,
    required String userProfile,
    String energyLevel = 'Medium',
    bool visualsNeeded = true,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/api/generate-lesson'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({
              'topic': topic,
              'user_profile': userProfile,
              'energy_level': energyLevel,
              'visuals_needed': visualsNeeded,
            }),
          )
          .timeout(const Duration(seconds: 60));

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Lesson generation failed: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Lesson generation error: $e');
    }
  }

  // =============================================
  // Deep Dive
  // =============================================

  /// Generate a deep-dive sub-lesson
  static Future<Map<String, dynamic>> deepDive({
    required String parentTopic,
    required String subTopic,
    required String userProfile,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/api/deep-dive'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({
              'parent_topic': parentTopic,
              'sub_topic': subTopic,
              'user_profile': userProfile,
            }),
          )
          .timeout(const Duration(seconds: 60));

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Deep dive failed: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Deep dive error: $e');
    }
  }

  // =============================================
  // Simplify Text
  // =============================================

  /// Simplify shared or pasted text
  static Future<Map<String, dynamic>> simplifyText({
    required String text,
    required String userProfile,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/api/simplify'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({
              'text': text,
              'user_profile': userProfile,
            }),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Simplification failed: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Simplification error: $e');
    }
  }

  // =============================================
  // Text-to-Speech
  // =============================================

  /// Get TTS audio bytes for text
  static Future<List<int>> textToSpeech({
    required String text,
    double speed = 1.0,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/api/text-to-speech'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({
              'text': text,
              'speed': speed,
            }),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        return response.bodyBytes;
      } else {
        throw Exception('TTS failed: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('TTS error: $e');
    }
  }

  // =============================================
  // Image Analysis (Snap-to-Understand)
  // =============================================

  /// Analyze an image and generate a lesson from it
  static Future<Map<String, dynamic>> analyzeImage({
    required String imageBase64,
    required String userProfile,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/api/analyze-image'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({
              'image_base64': imageBase64,
              'user_profile': userProfile,
            }),
          )
          .timeout(const Duration(seconds: 60));

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Image analysis failed: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Image analysis error: $e');
    }
  }

  // =============================================
  // TTS → Cloudinary URL
  // =============================================

  /// Generate TTS audio and get a persistent Cloudinary URL
  static Future<String?> textToSpeechUrl({
    required String text,
    double speed = 1.0,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/api/text-to-speech/url'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({
              'text': text,
              'speed': speed,
            }),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['audio_url'] as String?;
      }
      return null;
    } catch (e) {
      debugPrint('TTS URL error: $e');
      return null;
    }
  }

  // =============================================
  // Model Pool Status
  // =============================================

  /// Get the current status of all model pools
  static Future<Map<String, dynamic>> modelStatus() async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/model-status'))
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      return {};
    } catch (e) {
      return {};
    }
  }

  // =============================================
  // AI Theme Generation (Groq-powered)
  // =============================================

  /// Generate a personalized theme from user traits using Groq AI.
  /// Returns the full theme JSON with font, colors, spacing, etc.
  static Future<Map<String, dynamic>?> generateTheme({
    required List<String> traits,
    String energyLevel = 'medium',
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/api/generate-theme'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({
              'traits': traits,
              'energy_level': energyLevel,
            }),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['theme'] as Map<String, dynamic>?;
      }
      debugPrint('Theme generation failed: ${response.statusCode}');
      return null;
    } catch (e) {
      debugPrint('Theme generation error: $e');
      return null;
    }
  }

  // =============================================
  // Maps / Quiet Spaces
  // =============================================

  /// Fetch quiet spaces using coordinates
  static Future<List<Map<String, dynamic>>> fetchQuietSpaces(
      double lat, double lng) async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/api/quiet-spaces?lat=$lat&lng=$lng'))
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.cast<Map<String, dynamic>>();
      }
      return [];
    } catch (e) {
      debugPrint('Maps API error: $e');
      return [];
    }
  }

  // =============================================
  // Image Scan & Simplification
  // =============================================

  /// Upload an image for OCR + AI simplification.
  /// Returns a map with: extracted_text, summary, simplified, key_terms
  static Future<Map<String, dynamic>?> scanImage(
    String filePath, {
    String profile = 'ADHD',
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/api/scan-image?profile=$profile');
      final request = http.MultipartRequest('POST', uri);

      request.files.add(
        await http.MultipartFile.fromPath('image', filePath),
      );

      final streamedResponse =
          await request.send().timeout(const Duration(seconds: 30));
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      }
      debugPrint('Scan failed: ${response.statusCode} — ${response.body}');
      return null;
    } catch (e) {
      debugPrint('Scan error: $e');
      return null;
    }
  }

  // =============================================
  // Voice Command Parsing
  // =============================================

  /// Parse transcribed voice text into a structured assistant command.
  static Future<Map<String, dynamic>?> parseVoiceIntent(
    String transcription,
  ) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/api/voice/intent'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({'transcription': transcription}),
          )
          .timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      }
      debugPrint('Voice intent failed: ${response.statusCode}');
      return null;
    } catch (e) {
      debugPrint('Voice intent error: $e');
      return null;
    }
  }
}
