/// NeuroSpace — Image Service
/// Fetches relevant contextual images using Unsplash API based on the topic.

import 'dart:convert';
import 'package:http/http.dart' as http;

class ImageService {
  // Free demo client ID for Unsplash (replace with real one for prod)
  // For demo purposes, we can also use a fallback placeholder if API fails or rate limits.
  static const String _clientId = 'YOUR_UNSPLASH_CLIENT_ID'; 
  
  static Future<String?> fetchImageUrl(String query) async {
    try {
      final uri = Uri.parse(
          'https://api.unsplash.com/search/photos?query=${Uri.encodeComponent(query)}&per_page=1&orientation=landscape');

      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Client-ID $_clientId',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['results'] != null && data['results'].isNotEmpty) {
          return data['results'][0]['urls']['regular'];
        }
      }
    } catch (e) {
      print('Warning: Image fetch failed: $e');
    }
    
    // Fallback placeholder image when API fails or is unconfigured
    return 'https://source.unsplash.com/featured/800x600/?${Uri.encodeComponent(query)}';
  }
}
