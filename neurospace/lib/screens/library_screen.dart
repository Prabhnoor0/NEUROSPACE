import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../providers/neuro_theme_provider.dart';
import '../services/firebase_service.dart';
import 'reader_screen.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  List<Map<String, dynamic>> _lessons = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLessons();
  }

  Future<void> _loadLessons() async {
    setState(() => _isLoading = true);

    try {
      final userId = FirebaseService.currentUserId;
      if (userId != null) {
        final lessons = await FirebaseService.getLessons(userId);
        if (mounted) {
          setState(() {
            _lessons = lessons;
            _isLoading = false;
          });
        }
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint('Failed to load lessons: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteLesson(String lessonId) async {
    final userId = FirebaseService.currentUserId;
    if (userId == null) return;

    await FirebaseService.deleteLesson(userId, lessonId);
    _loadLessons();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lesson deleted'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = Provider.of<NeuroThemeProvider>(context).activeProfile;

    return Scaffold(
      backgroundColor: profile.backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: profile.textColor),
        title: Text(
          'Neuro Library',
          style: TextStyle(
            fontFamily: profile.fontFamily,
            color: profile.textColor,
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh_rounded,
                color: profile.textColor.withValues(alpha: 0.5)),
            onPressed: _loadLessons,
          ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(color: profile.accentColor),
            )
          : _lessons.isEmpty
              ? _buildEmptyState(profile)
              : _buildLessonList(profile),
    );
  }

  Widget _buildEmptyState(dynamic profile) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: profile.accentColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.auto_stories_rounded,
              size: 64,
              color: profile.accentColor.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'No saved lessons yet',
            style: TextStyle(
              fontFamily: profile.fontFamily,
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: profile.textColor,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 48),
            child: Text(
              'Search for a topic on the dashboard to generate your first lesson. You can save it here!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: profile.fontFamily,
                fontSize: 14,
                color: profile.textColor.withValues(alpha: 0.5),
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 500.ms);
  }

  Widget _buildLessonList(dynamic profile) {
    return RefreshIndicator(
      onRefresh: _loadLessons,
      color: profile.accentColor,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        itemCount: _lessons.length,
        itemBuilder: (context, index) {
          final lesson = _lessons[index];
          final title = lesson['title'] ?? 'Untitled Lesson';
          final topic = lesson['topic'] ?? '';
          final profileUsed = lesson['profileUsed'] ?? 'ADHD';
          final createdAt = lesson['createdAt'] ?? '';
          final summary = lesson['summary'] ?? '';

          // Format date
          String dateStr = '';
          try {
            final date = DateTime.parse(createdAt);
            final diff = DateTime.now().difference(date);
            if (diff.inMinutes < 60) {
              dateStr = '${diff.inMinutes}m ago';
            } else if (diff.inHours < 24) {
              dateStr = '${diff.inHours}h ago';
            } else {
              dateStr = '${diff.inDays}d ago';
            }
          } catch (_) {}

          return Dismissible(
            key: Key(lesson['id'] ?? index.toString()),
            direction: DismissDirection.endToStart,
            background: Container(
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 24),
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.redAccent.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(Icons.delete_outline_rounded,
                  color: Colors.redAccent, size: 28),
            ),
            confirmDismiss: (_) async {
              return await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  backgroundColor: profile.cardColor,
                  title: Text('Delete Lesson?',
                      style: TextStyle(color: profile.textColor)),
                  content: Text('This can\'t be undone.',
                      style: TextStyle(
                          color: profile.textColor.withValues(alpha: 0.7))),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: Text('Cancel',
                          style: TextStyle(
                              color:
                                  profile.textColor.withValues(alpha: 0.5))),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.redAccent),
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Delete',
                          style: TextStyle(color: Colors.white)),
                    ),
                  ],
                ),
              );
            },
            onDismissed: (_) {
              if (lesson['id'] != null) {
                _deleteLesson(lesson['id']);
              }
            },
            child: GestureDetector(
              onTap: () {
                // Get modules content for the reader
                final modules = lesson['modules'];
                String content = summary;
                if (modules is List) {
                  content = modules
                      .map((m) => m is Map ? (m['content'] ?? '') : '')
                      .where((c) => c.toString().isNotEmpty)
                      .join('\n\n');
                }

                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ReaderScreen(
                      title: title,
                      content: content,
                    ),
                  ),
                );
              },
              child: Container(
                margin: const EdgeInsets.only(bottom: 20),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: profile.cardColor,
                  borderRadius: BorderRadius.circular(24),
                  border: profile.focusBordersEnabled
                      ? Border.all(
                          color:
                              profile.accentColor.withValues(alpha: 0.3),
                          width: 1.5)
                      : null,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    )
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color:
                                profile.accentColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            profileUsed.toUpperCase(),
                            style: TextStyle(
                              fontFamily: profile.fontFamily,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: profile.accentColor,
                              letterSpacing: 2,
                            ),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          dateStr,
                          style: TextStyle(
                            fontFamily: profile.fontFamily,
                            fontSize: 11,
                            color:
                                profile.textColor.withValues(alpha: 0.3),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      title,
                      style: TextStyle(
                        fontFamily: profile.fontFamily,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: profile.textColor,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (summary.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        summary,
                        style: TextStyle(
                          fontFamily: profile.fontFamily,
                          fontSize: 14,
                          color: profile.textColor.withValues(alpha: 0.5),
                          height: 1.4,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          )
              .animate()
              .fadeIn(
                  delay: Duration(milliseconds: 100 * index), duration: 400.ms)
              .slideX(
                  begin: 0.05,
                  end: 0,
                  delay: Duration(milliseconds: 100 * index));
        },
      ),
    );
  }
}
