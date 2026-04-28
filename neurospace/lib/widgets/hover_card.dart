/// NeuroSpace — Hover/Info Card Widget
/// Desktop: Appears on hover using MouseRegion + OverlayEntry.
/// Mobile: Appears on long-press with a bottom sheet.
/// Shows title, summary, and action buttons (TTS, Simplify, Easy Read, Wiki, Expand).
/// Enhanced with: API-driven summarization, Wikipedia links, and bubble integration.

import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/neuro_profile.dart';
import '../providers/bubble_provider.dart';
import '../services/search_service.dart';

class HoverInfoCard extends StatefulWidget {
  final Widget child;
  final String title;
  final String summary;
  final String? audioScript;
  final String? simplifiedText;
  final NeuroProfile profile;
  final VoidCallback? onExpand;
  final VoidCallback? onFullScreen;

  const HoverInfoCard({
    super.key,
    required this.child,
    required this.title,
    required this.summary,
    this.audioScript,
    this.simplifiedText,
    required this.profile,
    this.onExpand,
    this.onFullScreen,
  });

  @override
  State<HoverInfoCard> createState() => _HoverInfoCardState();
}

class _HoverInfoCardState extends State<HoverInfoCard> {
  OverlayEntry? _overlayEntry;
  final LayerLink _layerLink = LayerLink();
  bool _isHovering = false;
  bool _isOverCard = false;
  List<Map<String, String>> _wikiLinks = [];
  bool _loadingWiki = false;

  void _showOverlay() {
    if (_overlayEntry != null) return;

    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        width: 320,
        child: CompositedTransformFollower(
          link: _layerLink,
          targetAnchor: Alignment.bottomCenter,
          followerAnchor: Alignment.topCenter,
          offset: const Offset(0, 8),
          child: MouseRegion(
            onEnter: (_) => _isOverCard = true,
            onExit: (_) {
              _isOverCard = false;
              Future.delayed(const Duration(milliseconds: 300), () {
                if (!_isHovering && !_isOverCard) _hideOverlay();
              });
            },
            child: Material(
              color: Colors.transparent,
              child: _buildHoverCard(),
            ),
          ),
        ),
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);

    // Load Wikipedia links in background
    _loadWikiLinks();
  }

  void _hideOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  Future<void> _loadWikiLinks() async {
    if (_loadingWiki || _wikiLinks.isNotEmpty) return;
    _loadingWiki = true;
    try {
      final links = await SearchService.getWikiLinks(widget.title);
      if (mounted) {
        setState(() {
          _wikiLinks = links;
          _loadingWiki = false;
        });
        // Rebuild overlay to show wiki links
        _overlayEntry?.markNeedsBuild();
      }
    } catch (_) {
      _loadingWiki = false;
    }
  }

  void _showMobileSheet() {
    // Load wiki links when sheet opens
    _loadWikiLinks();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _buildMobileSheet(),
    );
  }

  @override
  void dispose() {
    _hideOverlay();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: MouseRegion(
        opaque: false,
        hitTestBehavior: HitTestBehavior.translucent,
        onEnter: (_) {
          _isHovering = true;
          _showOverlay();
        },
        onExit: (_) {
          _isHovering = false;
          Future.delayed(const Duration(milliseconds: 300), () {
            if (!_isHovering && !_isOverCard) _hideOverlay();
          });
        },
        child: GestureDetector(
          onLongPress: _showMobileSheet,
          child: widget.child,
        ),
      ),
    );
  }

  Widget _buildHoverCard() {
    final p = widget.profile;
    return Container(
      constraints: const BoxConstraints(maxHeight: 420),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: p.cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: p.accentColor.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: p.accentColor.withValues(alpha: 0.05),
            blurRadius: 30,
            spreadRadius: -5,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          Text(
            widget.title,
            style: TextStyle(
              fontFamily: p.fontFamily,
              fontSize: p.fontSize,
              fontWeight: FontWeight.w700,
              color: p.textColor,
            ),
          ),
          const SizedBox(height: 8),
          // Scrollable summary
          Flexible(
            child: Scrollbar(
              thumbVisibility: true,
              thickness: 3,
              radius: const Radius.circular(4),
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _FormattedSummaryText(
                      text: widget.summary,
                      profile: p,
                    ),

                    // Wikipedia Links
                    if (_wikiLinks.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: _wikiLinks.take(2).map((link) {
                          return GestureDetector(
                            onTap: () async {
                              final uri = Uri.parse(link['url'] ?? '');
                              if (await canLaunchUrl(uri)) {
                                await launchUrl(uri,
                                    mode: LaunchMode.externalApplication);
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFF448AFF).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color:
                                      const Color(0xFF448AFF).withValues(alpha: 0.2),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.language_rounded,
                                      color: Color(0xFF448AFF), size: 12),
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: Text(
                                      link['title'] ?? '',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF448AFF),
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          _buildActionButtons(p),
        ],
      ),
    );
  }

  Widget _buildMobileSheet() {
    final p = widget.profile;
    return DraggableScrollableSheet(
      initialChildSize: 0.5,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      builder: (context, scrollController) {
        return Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          decoration: BoxDecoration(
            color: p.cardColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Drag handle
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 4),
                decoration: BoxDecoration(
                  color: p.textColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Text(
                'Swipe up for more',
                style: TextStyle(
                  fontSize: 10,
                  color: p.textColor.withValues(alpha: 0.3),
                ),
              ),
              const SizedBox(height: 10),

              // Scrollable content area
              Expanded(
                child: Scrollbar(
                  thumbVisibility: true,
                  thickness: 3,
                  radius: const Radius.circular(4),
                  controller: scrollController,
                  child: ListView(
                    controller: scrollController,
                    padding: EdgeInsets.zero,
                    children: [
                      // Title
                      Text(
                        widget.title,
                        style: TextStyle(
                          fontFamily: p.fontFamily,
                          fontSize: p.fontSize + 2,
                          fontWeight: FontWeight.w700,
                          color: p.textColor,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Formatted summary — full content, scrollable
                      _FormattedSummaryText(
                        text: widget.summary,
                        profile: p,
                      ),

                      // Wikipedia links
                      if (_wikiLinks.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Text(
                          'Related Articles',
                          style: TextStyle(
                            fontFamily: p.fontFamily,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: p.textColor.withValues(alpha: 0.5),
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ...(_wikiLinks.map((link) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: GestureDetector(
                              onTap: () async {
                                final uri = Uri.parse(link['url'] ?? '');
                                if (await canLaunchUrl(uri)) {
                                  await launchUrl(uri,
                                      mode: LaunchMode.externalApplication);
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 10),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF448AFF)
                                      .withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: const Color(0xFF448AFF)
                                        .withValues(alpha: 0.15),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.open_in_browser_rounded,
                                        color: Color(0xFF448AFF), size: 16),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        link['title'] ?? '',
                                        style: TextStyle(
                                          fontFamily: p.fontFamily,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: const Color(0xFF448AFF),
                                        ),
                                      ),
                                    ),
                                    Icon(Icons.arrow_forward_ios_rounded,
                                        color: const Color(0xFF448AFF).withValues(alpha: 0.4),
                                        size: 12),
                                  ],
                                ),
                              ),
                            ),
                          );
                        })),
                      ],

                      const SizedBox(height: 20),
                      _buildActionButtons(p),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildActionButtons(NeuroProfile p) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        // TTS
        _actionButton(
          icon: Icons.volume_up_rounded,
          label: 'Read',
          color: const Color(0xFF00BCD4),
          profile: p,
          onTap: () async {
            final tts = FlutterTts();
            await tts.setSpeechRate(p.ttsSpeed * 0.5);
            await tts.speak(widget.audioScript ?? widget.summary);
          },
        ),

        // Summarize via API (uses Bubble)
        _actionButton(
          icon: Icons.auto_awesome_rounded,
          label: 'Summarize',
          color: const Color(0xFF7C4DFF),
          profile: p,
          onTap: () {
            _hideOverlay();
            Navigator.of(context).maybePop(); // close sheet if open
            try {
              final bubble =
                  Provider.of<BubbleProvider>(context, listen: false);
              bubble.handleSummarize(
                text: widget.summary.isNotEmpty
                    ? widget.summary
                    : widget.title,
                profile: p.profileType.name,
              );
              bubble.show();
            } catch (_) {
              // Bubble not in tree
            }
          },
        ),

        // Easy Read
        _actionButton(
          icon: Icons.format_size_rounded,
          label: 'Easy Read',
          color: const Color(0xFF4CAF50),
          profile: p,
          onTap: () {
            _hideOverlay();
            Navigator.of(context).maybePop();
            try {
              final bubble =
                  Provider.of<BubbleProvider>(context, listen: false);
              bubble.handleEasyRead(
                text: widget.simplifiedText ?? widget.summary,
              );
              bubble.show();
            } catch (_) {}
          },
        ),

        // Expand
        if (widget.onExpand != null)
          _actionButton(
            icon: Icons.read_more_rounded,
            label: 'Expand',
            color: const Color(0xFFFFA726),
            profile: p,
            onTap: () {
              _hideOverlay();
              widget.onExpand!();
            },
          ),

        // Full Screen
        if (widget.onFullScreen != null)
          _actionButton(
            icon: Icons.fullscreen_rounded,
            label: 'Full',
            color: const Color(0xFF2196F3),
            profile: p,
            onTap: () {
              _hideOverlay();
              widget.onFullScreen!();
            },
          ),
      ],
    );
  }

  Widget _actionButton({
    required IconData icon,
    required String label,
    required Color color,
    required NeuroProfile profile,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.2)),
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
}

/// Renders summary text with smart formatting:
/// - Splits into paragraphs on double newlines
/// - Detects bullet points (•, -, *) and formats them
/// - Detects headings (lines ending with :) and bolds them
/// - Proper line spacing for readability
class _FormattedSummaryText extends StatelessWidget {
  final String text;
  final NeuroProfile profile;

  const _FormattedSummaryText({
    required this.text,
    required this.profile,
  });

  @override
  Widget build(BuildContext context) {
    final paragraphs = _parseParagraphs(text);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: paragraphs.map((block) {
        if (block.type == _BlockType.heading) {
          return Padding(
            padding: const EdgeInsets.only(top: 10, bottom: 4),
            child: Text(
              block.text,
              style: TextStyle(
                fontFamily: profile.fontFamily,
                fontSize: profile.fontSize,
                fontWeight: FontWeight.w700,
                color: profile.textColor,
                height: 1.4,
              ),
            ),
          );
        }

        if (block.type == _BlockType.bullet) {
          return Padding(
            padding: const EdgeInsets.only(left: 4, top: 3, bottom: 3),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '•  ',
                  style: TextStyle(
                    fontFamily: profile.fontFamily,
                    fontSize: profile.fontSize - 1,
                    fontWeight: FontWeight.w700,
                    color: profile.accentColor,
                    height: 1.6,
                  ),
                ),
                Expanded(
                  child: Text(
                    block.text,
                    style: TextStyle(
                      fontFamily: profile.fontFamily,
                      fontSize: profile.fontSize - 1,
                      color: profile.textColor.withValues(alpha: 0.75),
                      height: 1.6,
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        // Regular paragraph
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            block.text,
            style: TextStyle(
              fontFamily: profile.fontFamily,
              fontSize: profile.fontSize - 1,
              color: profile.textColor.withValues(alpha: 0.7),
              height: 1.65,
            ),
          ),
        );
      }).toList(),
    );
  }

  List<_TextBlock> _parseParagraphs(String raw) {
    final blocks = <_TextBlock>[];
    // Split on double newlines or single newlines
    final lines = raw.split(RegExp(r'\n'));

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;

      // Detect bullet points
      if (trimmed.startsWith('• ') ||
          trimmed.startsWith('- ') ||
          trimmed.startsWith('* ') ||
          RegExp(r'^\d+[\.\)]\s').hasMatch(trimmed)) {
        // Strip the bullet prefix
        final bulletText = trimmed
            .replaceFirst(RegExp(r'^[•\-\*]\s*'), '')
            .replaceFirst(RegExp(r'^\d+[\.\)]\s*'), '');
        blocks.add(_TextBlock(bulletText, _BlockType.bullet));
        continue;
      }

      // Detect headings (lines ending with : or ALL CAPS short lines)
      if ((trimmed.endsWith(':') && trimmed.length < 80) ||
          (trimmed.length < 50 && trimmed == trimmed.toUpperCase() && trimmed.contains(RegExp(r'[A-Z]')))) {
        blocks.add(_TextBlock(trimmed, _BlockType.heading));
        continue;
      }

      blocks.add(_TextBlock(trimmed, _BlockType.paragraph));
    }

    return blocks;
  }
}

enum _BlockType { paragraph, bullet, heading }

class _TextBlock {
  final String text;
  final _BlockType type;
  const _TextBlock(this.text, this.type);
}
