/// NeuroSpace — Nearby NGOs Screen
/// Discover NGOs, view services, contact them, and send help requests.

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/neuro_profile.dart';
import '../models/resource_models.dart';
import '../providers/neuro_theme_provider.dart';
import '../services/firebase_service.dart';
import '../services/resource_service.dart';

class ResourceNGOsScreen extends StatefulWidget {
  final double latitude;
  final double longitude;

  const ResourceNGOsScreen({
    super.key,
    required this.latitude,
    required this.longitude,
  });

  @override
  State<ResourceNGOsScreen> createState() => _ResourceNGOsScreenState();
}

class _ResourceNGOsScreenState extends State<ResourceNGOsScreen> {
  List<NGOData> _ngos = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadNGOs();
  }

  Future<void> _loadNGOs() async {
    setState(() => _isLoading = true);
    final ngos = await ResourceService.getNearbyNGOs(
      latitude: widget.latitude,
      longitude: widget.longitude,
    );
    if (mounted) {
      setState(() {
        _ngos = ngos;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = Provider.of<NeuroThemeProvider>(context).activeProfile;

    return Scaffold(
      backgroundColor: profile.backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(profile),
            Expanded(
              child: _isLoading
                  ? Center(
                      child:
                          CircularProgressIndicator(color: profile.accentColor))
                  : _ngos.isEmpty
                      ? _buildEmpty(profile)
                      : ListView.separated(
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(16, 10, 16, 30),
                          itemCount: _ngos.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 12),
                          itemBuilder: (ctx, i) {
                            return _NGOCard(ngo: _ngos[i])
                                .animate()
                                .fadeIn(
                                    delay: Duration(milliseconds: 100 * i),
                                    duration: 400.ms)
                                .slideY(
                                    begin: 0.08,
                                    end: 0,
                                    delay: Duration(milliseconds: 100 * i),
                                    duration: 400.ms);
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(NeuroProfile profile) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: profile.cardColor,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.arrow_back_ios_new_rounded,
                  color: profile.textColor, size: 18),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Nearby NGOs',
                  style: TextStyle(
                    fontFamily: profile.fontFamily,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: profile.textColor,
                  ),
                ),
                Text(
                  'Organizations that can help',
                  style: TextStyle(
                    fontFamily: profile.fontFamily,
                    fontSize: 12,
                    color: profile.textColor.withValues(alpha: 0.55),
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: _loadNGOs,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: profile.cardColor,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.refresh_rounded,
                  color: profile.accentColor, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty(NeuroProfile profile) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.volunteer_activism_rounded,
                size: 56,
                color: profile.textColor.withValues(alpha: 0.3)),
            const SizedBox(height: 16),
            Text(
              'No NGOs found nearby',
              style: TextStyle(
                fontFamily: profile.fontFamily,
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: profile.textColor.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Try expanding your search area.',
              style: TextStyle(
                fontFamily: profile.fontFamily,
                fontSize: 13,
                color: profile.textColor.withValues(alpha: 0.45),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================
// NGO Card
// =============================================

class _NGOCard extends StatelessWidget {
  final NGOData ngo;

  const _NGOCard({required this.ngo});

  @override
  Widget build(BuildContext context) {
    final profile = Provider.of<NeuroThemeProvider>(context).activeProfile;
    const color = Color(0xFFFF7043);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: profile.cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.volunteer_activism_rounded,
                    color: color, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ngo.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: profile.fontFamily,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: profile.textColor,
                      ),
                    ),
                    if (ngo.distanceKm != null)
                      Text(
                        '${ngo.distanceKm!.toStringAsFixed(1)} km away',
                        style: TextStyle(
                          fontFamily: profile.fontFamily,
                          fontSize: 12,
                          color: profile.textColor.withValues(alpha: 0.5),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Services
          if (ngo.services.isNotEmpty) ...[
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: ngo.services.map((s) {
                return Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    s,
                    style: TextStyle(
                      fontFamily: profile.fontFamily,
                      fontSize: 11,
                      color: color,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
          ],

          // Info rows
          if (ngo.timings != null)
            _infoRow(profile, Icons.schedule_rounded, ngo.timings!),
          if (ngo.languages.isNotEmpty)
            _infoRow(
                profile, Icons.language_rounded, ngo.languages.join(', ')),
          if (ngo.areaServed != null)
            _infoRow(profile, Icons.location_on_rounded, ngo.areaServed!),

          const SizedBox(height: 14),

          // Action buttons
          Row(
            children: [
              if (ngo.contact != null)
                Expanded(
                  child: _actionButton(
                    profile,
                    icon: Icons.call_rounded,
                    label: 'Call',
                    color: const Color(0xFF4CAF50),
                    onTap: () => _launchUrl('tel:${ngo.contact}'),
                  ),
                ),
              if (ngo.contact != null && ngo.whatsapp != null)
                const SizedBox(width: 8),
              if (ngo.whatsapp != null)
                Expanded(
                  child: _actionButton(
                    profile,
                    icon: Icons.chat_rounded,
                    label: 'WhatsApp',
                    color: const Color(0xFF25D366),
                    onTap: () =>
                        _launchUrl('https://wa.me/${ngo.whatsapp}'),
                  ),
                ),
              if ((ngo.contact != null || ngo.whatsapp != null))
                const SizedBox(width: 8),
              Expanded(
                child: _actionButton(
                  profile,
                  icon: Icons.help_outline_rounded,
                  label: 'Ask Help',
                  color: profile.accentColor,
                  onTap: () => _showHelpRequestSheet(context, profile),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _infoRow(NeuroProfile profile, IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(icon,
              size: 14, color: profile.textColor.withValues(alpha: 0.4)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontFamily: profile.fontFamily,
                fontSize: 12,
                color: profile.textColor.withValues(alpha: 0.6),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionButton(
    NeuroProfile profile, {
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontFamily: profile.fontFamily,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _launchUrl(String url) async {
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  // =============================================
  // Help Request Sheet
  // =============================================
  void _showHelpRequestSheet(BuildContext context, NeuroProfile profile) {
    final msgController = TextEditingController();
    String contactPref = 'any';
    bool isSending = false;

    showModalBottomSheet(
      context: context,
      backgroundColor: profile.cardColor,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                24,
                24,
                24,
                MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: profile.textColor.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Ask for Help',
                    style: TextStyle(
                      fontFamily: profile.fontFamily,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: profile.textColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Send a request to ${ngo.name}',
                    style: TextStyle(
                      fontFamily: profile.fontFamily,
                      fontSize: 13,
                      color: profile.accentColor,
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: msgController,
                    maxLines: 3,
                    style: TextStyle(
                      fontFamily: profile.fontFamily,
                      fontSize: 14,
                      color: profile.textColor,
                    ),
                    decoration: InputDecoration(
                      hintText:
                          'Describe what help you need...',
                      hintStyle: TextStyle(
                        fontFamily: profile.fontFamily,
                        color: profile.textColor.withValues(alpha: 0.35),
                      ),
                      filled: true,
                      fillColor:
                          profile.backgroundColor.withValues(alpha: 0.5),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Preferred contact method',
                    style: TextStyle(
                      fontFamily: profile.fontFamily,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: profile.textColor.withValues(alpha: 0.6),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: ['Any', 'Call', 'WhatsApp', 'Email'].map((opt) {
                      final val = opt.toLowerCase();
                      final isSelected = contactPref == val;
                      return GestureDetector(
                        onTap: () =>
                            setModalState(() => contactPref = val),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? profile.accentColor
                                    .withValues(alpha: 0.15)
                                : profile.backgroundColor
                                    .withValues(alpha: 0.4),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isSelected
                                  ? profile.accentColor
                                      .withValues(alpha: 0.5)
                                  : Colors.transparent,
                            ),
                          ),
                          child: Text(
                            opt,
                            style: TextStyle(
                              fontFamily: profile.fontFamily,
                              fontSize: 13,
                              fontWeight: isSelected
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: isSelected
                                  ? profile.accentColor
                                  : profile.textColor
                                      .withValues(alpha: 0.5),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: isSending || msgController.text.trim().isEmpty
                          ? null
                          : () async {
                              setModalState(() => isSending = true);

                              final userId =
                                  FirebaseService.currentUserId ?? 'anon';

                              final result =
                                  await ResourceService.sendHelpRequest(
                                userId: userId,
                                ngoId: ngo.id,
                                ngoName: ngo.name,
                                message: msgController.text.trim(),
                                contactPreference: contactPref,
                              );

                              if (!context.mounted) return;
                              Navigator.pop(ctx);

                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    result != null
                                        ? '✅ Help request sent to ${ngo.name}'
                                        : '❌ Failed to send. Please try again.',
                                    style: TextStyle(
                                        fontFamily: profile.fontFamily),
                                  ),
                                  backgroundColor: result != null
                                      ? const Color(0xFF4CAF50)
                                      : Colors.red.shade700,
                                ),
                              );
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: profile.accentColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                        disabledBackgroundColor:
                            profile.accentColor.withValues(alpha: 0.3),
                      ),
                      icon: isSending
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.send_rounded),
                      label: Text(
                        isSending ? 'Sending...' : 'Send Help Request',
                        style: TextStyle(
                          fontFamily: profile.fontFamily,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
