/// NeuroSpace — Search Service
/// Fetches search results from Wikipedia API and DuckDuckGo Instant Answer API.
/// Both APIs are free and require no API keys.

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/search_result.dart';

class SearchService {
  // =============================================
  // Wikipedia Search API
  // =============================================

  /// Search Wikipedia for articles matching the query.
  /// Returns a list of search results with titles and snippets.
  static Future<List<SearchResult>> searchWikipedia(String query) async {
    if (query.trim().isEmpty) return [];

    try {
      final uri = Uri.parse(
        'https://en.wikipedia.org/w/api.php'
        '?action=query&list=search'
        '&srsearch=${Uri.encodeComponent(query)}'
        '&srlimit=8'
        '&format=json'
        '&origin=*',
      );

      final response = await http.get(uri).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final results = data['query']?['search'] as List? ?? [];

        return results
            .map((r) =>
                SearchResult.fromWikipediaSearch(Map<String, dynamic>.from(r)))
            .toList();
      }
    } catch (e) {
      debugPrint('Wikipedia search error: $e');
    }

    return [];
  }

  // =============================================
  // Wikipedia Summary API (Page Summary)
  // =============================================

  /// Get a detailed summary for a specific Wikipedia article title.
  /// Returns the extract, thumbnail, and content URL.
  static Future<SearchResult?> getWikipediaSummary(String title) async {
    if (title.trim().isEmpty) return null;

    try {
      final encodedTitle =
          Uri.encodeComponent(title.replaceAll(' ', '_'));
      final uri = Uri.parse(
        'https://en.wikipedia.org/api/rest_v1/page/summary/$encodedTitle',
      );

      final response = await http.get(
        uri,
        headers: {
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return SearchResult.fromWikipediaSummary(data);
      }
    } catch (e) {
      debugPrint('Wikipedia summary error: $e');
    }

    return null;
  }

  // =============================================
  // DuckDuckGo Instant Answer API
  // =============================================

  /// Get instant answers from DuckDuckGo.
  /// Returns abstract text and related topics.
  static Future<List<SearchResult>> searchDuckDuckGo(String query) async {
    if (query.trim().isEmpty) return [];

    try {
      final uri = Uri.parse(
        'https://api.duckduckgo.com/'
        '?q=${Uri.encodeComponent(query)}'
        '&format=json'
        '&no_html=1'
        '&skip_disambig=1',
      );

      final response = await http.get(uri).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final results = <SearchResult>[];

        // Abstract (main answer)
        final abstractText = data['AbstractText'] ?? '';
        final abstractUrl = data['AbstractURL'] ?? '';
        if (abstractText.toString().isNotEmpty) {
          results.add(SearchResult(
            title: data['Heading'] ?? query,
            snippet: abstractText,
            url: abstractUrl,
            source: 'duckduckgo',
            thumbnailUrl: data['Image']?.toString().isNotEmpty == true
                ? data['Image']
                : null,
          ));
        }

        // Related topics
        final relatedTopics = data['RelatedTopics'] as List? ?? [];
        for (final topic in relatedTopics.take(5)) {
          if (topic is Map && topic['Text'] != null) {
            results.add(SearchResult.fromDuckDuckGo(
                Map<String, dynamic>.from(topic)));
          }
        }

        return results;
      }
    } catch (e) {
      debugPrint('DuckDuckGo search error: $e');
    }

    return [];
  }

  // =============================================
  // Combined Search (Wikipedia + DuckDuckGo)
  // =============================================

  /// Search both Wikipedia and DuckDuckGo in parallel.
  /// Returns combined results with Wikipedia results first.
  static Future<Map<String, List<SearchResult>>> searchAll(
      String query) async {
    if (query.trim().isEmpty) {
      return {'wikipedia': [], 'web': []};
    }

    // Run both searches in parallel
    final results = await Future.wait([
      searchWikipedia(query),
      searchDuckDuckGo(query),
    ]);

    return {
      'wikipedia': results[0],
      'web': results[1],
    };
  }

  // =============================================
  // Get Wikipedia Links for a Topic
  // =============================================

  /// For a given topic, return a list of relevant Wikipedia article URLs.
  /// Used by lesson screens and hover cards.
  static Future<List<Map<String, String>>> getWikiLinks(String topic) async {
    final results = await searchWikipedia(topic);
    return results
        .take(3)
        .map((r) => {
              'title': r.title,
              'url': r.url,
            })
        .toList();
  }
}
