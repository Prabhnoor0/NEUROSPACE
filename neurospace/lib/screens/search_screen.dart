/// NeuroSpace — Search Screen
/// Full search engine with Wikipedia + web results.
/// Each result has quick-action icons for TTS, Summarize, and Learn.
/// Adapts to the active NeuroProfile (font, colors, spacing).

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/neuro_theme_provider.dart';
import '../providers/bubble_provider.dart';
import '../models/neuro_profile.dart';
import '../models/search_result.dart';
import '../services/search_service.dart';
import 'lesson_screen.dart';

class SearchScreen extends StatefulWidget {
  final String? initialQuery;

  const SearchScreen({super.key, this.initialQuery});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FlutterTts _tts = FlutterTts();

  List<SearchResult> _wikiResults = [];
  List<SearchResult> _webResults = [];
  SearchResult? _featuredResult;
  bool _isSearching = false;
  bool _hasSearched = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialQuery != null && widget.initialQuery!.isNotEmpty) {
      _searchController.text = widget.initialQuery!;
      _performSearch(widget.initialQuery!);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tts.stop();
    super.dispose();
  }

  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty) return;

    setState(() {
      _isSearching = true;
      _hasSearched = true;
    });

    // Run searches in parallel
    final results = await SearchService.searchAll(query);

    // Get featured summary for top wiki result
    SearchResult? featured;
    if (results['wikipedia']!.isNotEmpty) {
      featured = await SearchService.getWikipediaSummary(
          results['wikipedia']!.first.title);
    }

    if (mounted) {
      setState(() {
        _wikiResults = results['wikipedia'] ?? [];
        _webResults = results['web'] ?? [];
        _featuredResult = featured;
        _isSearching = false;
      });
    }
  }

  Future<void> _speakText(String text) async {
    await _tts.setSpeechRate(0.45);
    await _tts.speak(text);
  }

  @override
  Widget build(BuildContext context) {
    final profile =
        Provider.of<NeuroThemeProvider>(context).activeProfile;

    return Scaffold(
      backgroundColor: profile.backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: profile.textColor),
        title: Text(
          'Search',
          style: TextStyle(
            fontFamily: profile.fontFamily,
            fontSize: profile.fontSize + 2,
            fontWeight: FontWeight.w800,
            color: profile.textColor,
          ),
        ),
      ),
      body: Column(
        children: [
          // ── Search Bar ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Container(
              decoration: BoxDecoration(
                color: profile.cardColor,
                borderRadius: BorderRadius.circular(20),
                border: profile.focusBordersEnabled
                    ? Border.all(
                        color: profile.accentColor.withOpacity(0.25),
                        width: 1.5,
                      )
                    : null,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: TextField(
                controller: _searchController,
                autofocus: widget.initialQuery == null,
                onSubmitted: _performSearch,
                style: TextStyle(
                  fontFamily: profile.fontFamily,
                  fontSize: profile.fontSize,
                  color: profile.textColor,
                  letterSpacing: profile.letterSpacing,
                ),
                decoration: InputDecoration(
                  hintText: 'Search Wikipedia, topics, anything...',
                  hintStyle: TextStyle(
                    fontFamily: profile.fontFamily,
                    color: profile.textColor.withOpacity(0.35),
                  ),
                  prefixIcon: Padding(
                    padding: const EdgeInsets.only(left: 16, right: 8),
                    child: Icon(Icons.search_rounded,
                        color: profile.accentColor.withOpacity(0.6), size: 24),
                  ),
                  suffixIcon: _isSearching
                      ? Padding(
                          padding: const EdgeInsets.all(14),
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: profile.accentColor,
                            ),
                          ),
                        )
                      : IconButton(
                          icon: Icon(Icons.send_rounded,
                              color: profile.accentColor),
                          onPressed: () =>
                              _performSearch(_searchController.text),
                        ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          ),

          // ── Results ──
          Expanded(
            child: _isSearching
                ? _buildLoadingState(profile)
                : !_hasSearched
                    ? _buildEmptyState(profile)
                    : _buildResults(profile),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState(NeuroProfile profile) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: profile.accentColor),
          const SizedBox(height: 16),
          Text(
            'Searching...',
            style: TextStyle(
              fontFamily: profile.fontFamily,
              color: profile.textColor.withOpacity(0.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(NeuroProfile profile) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.travel_explore_rounded,
              color: profile.accentColor.withOpacity(0.3), size: 64),
          const SizedBox(height: 16),
          Text(
            'Search anything to learn about',
            style: TextStyle(
              fontFamily: profile.fontFamily,
              fontSize: profile.fontSize,
              color: profile.textColor.withOpacity(0.4),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Wikipedia • Web • AI Lessons',
            style: TextStyle(
              fontFamily: profile.fontFamily,
              fontSize: 12,
              color: profile.accentColor.withOpacity(0.5),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResults(NeuroProfile profile) {
    final noResults = _wikiResults.isEmpty && _webResults.isEmpty;

    if (noResults) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off_rounded,
                color: profile.textColor.withOpacity(0.3), size: 48),
            const SizedBox(height: 12),
            Text(
              'No results found',
              style: TextStyle(
                fontFamily: profile.fontFamily,
                fontSize: profile.fontSize,
                color: profile.textColor.withOpacity(0.5),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        LessonScreen(topic: _searchController.text),
                  ),
                );
              },
              icon: const Icon(Icons.auto_stories_rounded),
              label: const Text('Generate AI Lesson Instead'),
              style: ElevatedButton.styleFrom(
                backgroundColor: profile.accentColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 14),
              ),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Generate AI Lesson button ──
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      LessonScreen(topic: _searchController.text),
                ),
              );
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    profile.accentColor.withOpacity(0.15),
                    profile.accentColor.withOpacity(0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: profile.accentColor.withOpacity(0.2),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: profile.accentColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.auto_stories_rounded,
                        color: profile.accentColor, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '🧠 Generate AI Lesson',
                          style: TextStyle(
                            fontFamily: profile.fontFamily,
                            fontSize: profile.fontSize,
                            fontWeight: FontWeight.w700,
                            color: profile.textColor,
                          ),
                        ),
                        Text(
                          'Learn "${_searchController.text}" adapted for you',
                          style: TextStyle(
                            fontFamily: profile.fontFamily,
                            fontSize: 12,
                            color: profile.textColor.withOpacity(0.5),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.arrow_forward_ios_rounded,
                      color: profile.accentColor.withOpacity(0.5), size: 16),
                ],
              ),
            ),
          ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.1),

          // ── Featured Wikipedia Summary ──
          if (_featuredResult != null) ...[
            _buildFeaturedCard(profile, _featuredResult!),
            const SizedBox(height: 20),
          ],

          // ── Wikipedia Results ──
          if (_wikiResults.isNotEmpty) ...[
            _buildSectionHeader(
                profile, '📚 Wikipedia', Icons.menu_book_rounded),
            const SizedBox(height: 12),
            ...List.generate(_wikiResults.length, (i) {
              return _buildSearchResultCard(
                profile,
                _wikiResults[i],
                delay: 100 + (i * 80),
              );
            }),
            const SizedBox(height: 20),
          ],

          // ── Web Results ──
          if (_webResults.isNotEmpty) ...[
            _buildSectionHeader(
                profile, '🌐 Web Results', Icons.language_rounded),
            const SizedBox(height: 12),
            ...List.generate(_webResults.length, (i) {
              return _buildSearchResultCard(
                profile,
                _webResults[i],
                delay: 300 + (i * 80),
              );
            }),
          ],

          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(
      NeuroProfile profile, String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: profile.accentColor, size: 18),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontFamily: profile.fontFamily,
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: profile.accentColor,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  Widget _buildFeaturedCard(NeuroProfile profile, SearchResult result) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: profile.cardColor,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: profile.accentColor.withOpacity(0.15),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (result.thumbnailUrl != null) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    result.thumbnailUrl!,
                    width: 60,
                    height: 60,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: profile.accentColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.image_rounded,
                          color: profile.accentColor.withOpacity(0.5)),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      result.title,
                      style: TextStyle(
                        fontFamily: profile.fontFamily,
                        fontSize: profile.fontSize + 2,
                        fontWeight: FontWeight.w800,
                        color: profile.textColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Wikipedia',
                      style: TextStyle(
                        fontFamily: profile.fontFamily,
                        fontSize: 11,
                        color: profile.accentColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            result.fullSummary ?? result.snippet,
            style: TextStyle(
              fontFamily: profile.fontFamily,
              fontSize: profile.fontSize,
              color: profile.textColor.withOpacity(0.8),
              height: profile.lineHeight,
              letterSpacing: profile.letterSpacing,
            ),
            maxLines: 6,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 16),
          // Action buttons
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildActionChip(
                profile,
                icon: Icons.volume_up_rounded,
                label: 'Read',
                color: const Color(0xFF00BCD4),
                onTap: () =>
                    _speakText(result.fullSummary ?? result.snippet),
              ),
              _buildActionChip(
                profile,
                icon: Icons.open_in_browser_rounded,
                label: 'Wiki',
                color: const Color(0xFF448AFF),
                onTap: () async {
                  final uri = Uri.parse(result.url);
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri,
                        mode: LaunchMode.externalApplication);
                  }
                },
              ),
              _buildActionChip(
                profile,
                icon: Icons.auto_stories_rounded,
                label: 'Learn',
                color: const Color(0xFF7C4DFF),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => LessonScreen(topic: result.title),
                    ),
                  );
                },
              ),
              _buildActionChip(
                profile,
                icon: Icons.auto_awesome_rounded,
                label: 'Simplify',
                color: const Color(0xFF4CAF50),
                onTap: () {
                  final bubble =
                      Provider.of<BubbleProvider>(context, listen: false);
                  bubble.handleSummarize(
                    text: result.fullSummary ?? result.snippet,
                    profile: profile.profileType.name,
                  );
                  bubble.show();
                },
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.08);
  }

  Widget _buildSearchResultCard(
    NeuroProfile profile,
    SearchResult result, {
    int delay = 0,
  }) {
    final isWiki = result.source == 'wikipedia';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: profile.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: profile.accentColor.withOpacity(0.08),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      result.title,
                      style: TextStyle(
                        fontFamily: profile.fontFamily,
                        fontSize: profile.fontSize,
                        fontWeight: FontWeight.w700,
                        color: profile.textColor,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      result.snippet,
                      style: TextStyle(
                        fontFamily: profile.fontFamily,
                        fontSize: profile.fontSize - 2,
                        color: profile.textColor.withOpacity(0.6),
                        height: profile.lineHeight,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (isWiki)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF448AFF).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Wiki',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF448AFF),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          // Quick actions row
          Row(
            children: [
              _buildSmallAction(
                icon: Icons.volume_up_rounded,
                color: const Color(0xFF00BCD4),
                onTap: () => _speakText(result.snippet),
              ),
              const SizedBox(width: 8),
              if (isWiki)
                _buildSmallAction(
                  icon: Icons.open_in_browser_rounded,
                  color: const Color(0xFF448AFF),
                  onTap: () async {
                    final uri = Uri.parse(result.url);
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri,
                          mode: LaunchMode.externalApplication);
                    }
                  },
                ),
              const SizedBox(width: 8),
              _buildSmallAction(
                icon: Icons.auto_stories_rounded,
                color: const Color(0xFF7C4DFF),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => LessonScreen(topic: result.title),
                    ),
                  );
                },
              ),
              const Spacer(),
              Text(
                result.source == 'wikipedia' ? 'Wikipedia' : 'Web',
                style: TextStyle(
                  fontSize: 10,
                  color: profile.textColor.withOpacity(0.3),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    )
        .animate()
        .fadeIn(delay: Duration(milliseconds: delay), duration: 300.ms)
        .slideY(begin: 0.05);
  }

  Widget _buildActionChip(
    NeuroProfile profile, {
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontFamily: profile.fontFamily,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSmallAction({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: color, size: 16),
      ),
    );
  }
}
