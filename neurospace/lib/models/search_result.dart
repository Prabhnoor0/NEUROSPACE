/// NeuroSpace — Search Result Model
/// Unified data model for search results from Wikipedia and web sources.

class SearchResult {
  final String title;
  final String snippet;
  final String url;
  final String source; // 'wikipedia', 'web', 'duckduckgo'
  final String? thumbnailUrl;
  final String? fullSummary;
  final int? pageId;

  const SearchResult({
    required this.title,
    required this.snippet,
    required this.url,
    required this.source,
    this.thumbnailUrl,
    this.fullSummary,
    this.pageId,
  });

  factory SearchResult.fromWikipediaSearch(Map<String, dynamic> json) {
    final title = json['title'] ?? '';
    // Remove HTML tags from snippet
    final rawSnippet = json['snippet'] ?? '';
    final cleanSnippet = rawSnippet
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll('&quot;', '"')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>');

    return SearchResult(
      title: title,
      snippet: cleanSnippet,
      url: 'https://en.wikipedia.org/wiki/${Uri.encodeComponent(title.replaceAll(' ', '_'))}',
      source: 'wikipedia',
      pageId: json['pageid'] as int?,
    );
  }

  factory SearchResult.fromWikipediaSummary(Map<String, dynamic> json) {
    return SearchResult(
      title: json['title'] ?? '',
      snippet: json['extract'] ?? json['description'] ?? '',
      url: json['content_urls']?['desktop']?['page'] ?? '',
      source: 'wikipedia',
      thumbnailUrl: json['thumbnail']?['source'],
      fullSummary: json['extract'],
      pageId: json['pageid'] as int?,
    );
  }

  factory SearchResult.fromDuckDuckGo(Map<String, dynamic> json) {
    return SearchResult(
      title: json['Text'] ?? json['FirstURL']?.toString().split('/').last ?? '',
      snippet: json['Text'] ?? '',
      url: json['FirstURL'] ?? '',
      source: 'duckduckgo',
    );
  }
}
