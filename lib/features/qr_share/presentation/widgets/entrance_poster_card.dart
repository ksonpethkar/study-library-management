import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:study_library/features/seats/presentation/providers/seat_providers.dart';
import 'package:study_library/models/library_model.dart';
import 'package:study_library/services/image_service.dart';

class EntrancePosterCard extends ConsumerWidget {
  final LibraryModel? library;
  final String libraryId;
  final List<Map<String, dynamic>> amenities;
  final String? urgencyText;

  const EntrancePosterCard({
    super.key,
    required this.library,
    required this.libraryId,
    required this.amenities,
    this.urgencyText,
  });

  String get seatMapUrl => 'https://study-lib-mgmt-2026.web.app/seats?lib=$libraryId';

  String _formatHelpline(String raw) {
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.length == 10) {
      return '+91 ${digits.substring(0, 5)} ${digits.substring(5)}';
    } else if (digits.length == 12 && digits.startsWith('91')) {
      return '+91 ${digits.substring(2, 7)} ${digits.substring(7)}';
    }
    return raw.trim().isNotEmpty ? raw.trim() : 'Reception Desk';
  }

  Widget _buildFallbackLogo(Color color, {double size = 26}) {
    return Container(
      color: Colors.white,
      child: Center(
        child: Icon(
          Icons.account_balance_rounded,
          color: color,
          size: size,
        ),
      ),
    );
  }

  Widget _buildFallbackCenterShield(Color color) {
    return Container(
      color: Colors.white,
      child: Center(
        child: Icon(
          Icons.local_library_rounded,
          color: color,
          size: 20,
        ),
      ),
    );
  }

  IconData _getAmenityIconData(String id, String label) {
    final l = '$id $label'.toLowerCase();
    if (l.contains('wifi') || l.contains('wi-fi')) return Icons.wifi_rounded;
    if (l.contains('silence') || l.contains('quiet')) return Icons.volume_off_rounded;
    if (l.contains('water') || l.contains('ro')) return Icons.water_drop_rounded;
    if (l.contains('power') || l.contains('socket') || l.contains('outlet')) return Icons.power_rounded;
    if (l.contains('backup') || l.contains('inverter') || l.contains('battery')) return Icons.battery_charging_full_rounded;
    if (l.contains('cctv') || l.contains('camera') || l.contains('surveillance')) return Icons.videocam_rounded;
    if (l.contains('ac') || l.contains('cool') || l.contains('air')) return Icons.ac_unit_rounded;
    if (l.contains('chair') || l.contains('seat')) return Icons.chair_rounded;
    if (l.contains('24/7') || l.contains('hour') || l.contains('time')) return Icons.schedule_rounded;
    if (l.contains('parking')) return Icons.local_parking_rounded;
    if (l.contains('locker') || l.contains('storage')) return Icons.lock_rounded;
    return Icons.verified_rounded;
  }

  Color _getAmenityIconColor(String id, String label) {
    final l = '$id $label'.toLowerCase();
    if (l.contains('wifi') || l.contains('wi-fi')) return const Color(0xFF0284C7);
    if (l.contains('silence') || l.contains('quiet')) return const Color(0xFFD97706);
    if (l.contains('water') || l.contains('ro')) return const Color(0xFF0284C7);
    if (l.contains('power') || l.contains('socket')) return const Color(0xFF475569);
    if (l.contains('backup') || l.contains('battery')) return const Color(0xFF16A34A);
    if (l.contains('cctv') || l.contains('camera')) return const Color(0xFF4F46E5);
    if (l.contains('ac') || l.contains('air')) return const Color(0xFF0284C7);
    return const Color(0xFF16A34A);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final libName = library?.name.isNotEmpty == true ? library!.name : 'Study Centre';
    final libAddress = library?.address.isNotEmpty == true
        ? library!.address
        : 'Study Centre Locality & Address';

    final rawPhone = (library?.contact.isNotEmpty == true
            ? library!.contact
            : (library?.helplineNumber.isNotEmpty == true
                ? library!.helplineNumber
                : (library?.whatsappNumber.isNotEmpty == true
                    ? library!.whatsappNumber
                    : '')))
        .trim();
    final libContact = rawPhone.isNotEmpty ? _formatHelpline(rawPhone) : 'Contact Reception';

    final operatingHours = library?.operatingHours.isNotEmpty == true
        ? library!.operatingHours
        : '06:00 AM – 11:00 PM (Daily)';

    final tagline = library?.tagline.isNotEmpty == true
        ? library!.tagline
        : 'Smart Study Center & Silent Reading Hall';

    final brandPrimary = (library?.accentColor != null && library!.accentColor != 0)
        ? Color(library!.accentColor)
        : const Color(0xFF5D4037);

    final hsl = HSLColor.fromColor(brandPrimary);
    final brandDark = hsl.withLightness((hsl.lightness * 0.62).clamp(0.0, 1.0)).toColor();

    final logoProvider = (library != null && library!.logoUrl.isNotEmpty)
        ? ImageService.getImageProvider(library!.logoUrl)
        : null;

    final activeAmenities = amenities.where((a) => a['enabled'] == true).toList();

    // Real-Time Occupancy metrics
    final occupancy = ref.watch(occupancyProvider).value;
    final availableSeats = occupancy?['available'];
    final totalSeats = occupancy?['total'];
    final hasOccupancyData = availableSeats != null && totalSeats != null && totalSeats > 0;

    return Container(
      width: 595,
      height: 842,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.16),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
        border: Border.all(color: brandPrimary, width: 2.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── 1. Top Institutional Brand Header Banner ───────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [brandPrimary, brandDark],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              children: [
                // 1. Prominent Centered Logo Crest
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2.5),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.22),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: logoProvider != null
                        ? Image(
                            image: logoProvider,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => _buildFallbackLogo(brandPrimary, size: 26),
                          )
                        : _buildFallbackLogo(brandPrimary, size: 26),
                  ),
                ),
                const SizedBox(height: 8),

                // 2. Centered "WELCOME TO" Royal Pill Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3.5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD97706),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.16),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Text(
                    'WELCOME TO',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                // Institutional Name
                Text(
                  libName.toUpperCase(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                  ),
                ),

                // Tagline / Mission
                if (tagline.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    tagline,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFFFDE68A),
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],

                const SizedBox(height: 3),
                // Address
                Text(
                  libAddress,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 10,
                    height: 1.25,
                  ),
                ),

                const SizedBox(height: 8),
                // Operating Hours Badge (High-Contrast Cocoa Badge with Gold Border & Ivory Text)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4.5),
                  decoration: BoxDecoration(
                    color: const Color(0xFF38241A),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFF5A624), width: 1.2),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.schedule_rounded, size: 12, color: Color(0xFFFFF7ED)),
                      const SizedBox(width: 6),
                      Text(
                        'HOURS: $operatingHours',
                        style: const TextStyle(
                          color: Color(0xFFFFF7ED),
                          fontSize: 9.5,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── 2. Real-Time Seat Tracker Body ─────────────────────────────────
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Urgency Seat Pill Badge (Replaces static seat count)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4.5),
                    decoration: BoxDecoration(
                      color: hasOccupancyData && availableSeats == 0
                          ? Colors.red.shade50
                          : const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: hasOccupancyData && availableSeats == 0
                            ? Colors.red.shade300
                            : const Color(0xFFF59E0B),
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: (hasOccupancyData && availableSeats == 0 ? Colors.red : const Color(0xFFF59E0B)).withValues(alpha: 0.15),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          hasOccupancyData && availableSeats == 0
                              ? Icons.error_outline_rounded
                              : Icons.bolt_rounded,
                          size: 14,
                          color: hasOccupancyData && availableSeats == 0
                              ? Colors.red.shade900
                              : const Color(0xFFD97706),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          hasOccupancyData && availableSeats == 0
                              ? 'Full Capacity (Join Waiting List)'
                              : (urgencyText?.trim().isNotEmpty == true
                                  ? urgencyText!.trim()
                                  : 'Hurry! Limited Seats Left'),
                          style: TextStyle(
                            color: hasOccupancyData && availableSeats == 0
                                ? Colors.red.shade900
                                : const Color(0xFF92400E),
                            fontSize: 10.5,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Heading & Subtitle
                  Column(
                    children: const [
                      Text(
                        'Scan To Check Live Available Seats',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xFF0F172A),
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Point your smartphone camera at this QR code to view vacant seats in real-time before entering.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 10,
                          height: 1.25,
                        ),
                      ),
                    ],
                  ),

                  // ── High Contrast Optical QR Card with Rounded Eyes & Center Shield ───
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF64748B).withValues(alpha: 0.12),
                          blurRadius: 16,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        QrImageView(
                          data: seatMapUrl,
                          version: QrVersions.auto,
                          size: 180.0,
                          backgroundColor: Colors.white,
                          eyeStyle: QrEyeStyle(
                            eyeShape: QrEyeShape.circle,
                            color: brandPrimary,
                          ),
                          dataModuleStyle: const QrDataModuleStyle(
                            dataModuleShape: QrDataModuleShape.circle,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        // Center Emblem Shield
                        Container(
                          width: 40,
                          height: 40,
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: brandPrimary.withValues(alpha: 0.35),
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.14),
                                blurRadius: 6,
                              ),
                            ],
                          ),
                          child: ClipOval(
                            child: logoProvider != null
                                ? Image(
                                    image: logoProvider,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) => _buildFallbackCenterShield(brandPrimary),
                                  )
                                : _buildFallbackCenterShield(brandPrimary),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ── 3. Amenities Section ─────────────────────────────────────
                  Column(
                    children: [
                      const Text(
                        'LIBRARY AMENITIES & FACILITIES',
                        style: TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 9.5,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 6),
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: activeAmenities.take(6).length,
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          childAspectRatio: 2.35,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 6,
                        ),
                        itemBuilder: (context, idx) {
                          final item = activeAmenities[idx];
                          final id = item['id']?.toString().toLowerCase() ?? '';
                          String icon = item['icon']?.toString() ?? '';
                          if (icon.isEmpty) {
                            if (id == 'ac') {
                              icon = '❄️';
                            } else if (id == 'wifi') {
                              icon = '📶';
                            } else if (id == 'silence') {
                              icon = '🤫';
                            } else if (id == 'ro_water') {
                              icon = '💧';
                            } else if (id == 'power') {
                              icon = '🔌';
                            } else if (id == 'cctv') {
                              icon = '📹';
                            } else if (id == 'chairs') {
                              icon = '💺';
                            } else if (id == 'power_backup') {
                              icon = '⚡';
                            } else {
                              icon = '✨';
                            }
                          }

                          const defaultDescriptions = {
                            'ac': 'Fully Air-Conditioned Hall',
                            'wifi': 'High-Speed Optical Fiber',
                            'silence': 'Pindrop Quiet Environment',
                            'ro_water': 'Purified Chilled & Normal RO',
                            'power': 'Personal Socket At Desk',
                            'open_24_7': 'Round-The-Clock Access',
                            'cctv': '24/7 Security Surveillance',
                            'chairs': 'Comfortable Ergonomic Seating',
                            'power_backup': 'Uninterrupted Inverter',
                          };
                          final desc = defaultDescriptions[id] ?? 'Standard Premium Facility';

                          return Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFFE2E8F0), width: 1.1),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      _getAmenityIconData(id, item['label']?.toString() ?? ''),
                                      size: 13,
                                      color: _getAmenityIconColor(id, item['label']?.toString() ?? ''),
                                    ),
                                    const SizedBox(width: 4),
                                    Flexible(
                                      child: Text(
                                        item['label']?.toString() ?? '',
                                        textAlign: TextAlign.center,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: Color(0xFF1E293B),
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  desc,
                                  textAlign: TextAlign.center,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Color(0xFF64748B),
                                    fontSize: 7.2,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // ── 3. Dedicated Full-Width Institutional Footer (Always Visible at Bottom) ──
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC),
              border: Border(
                top: BorderSide(color: Color(0xFFE2E8F0), width: 1.2),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Admission Helpline / WhatsApp',
                        style: TextStyle(
                          fontSize: 8.5,
                          color: Color(0xFF64748B),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(Icons.phone_in_talk_rounded, size: 13, color: brandPrimary),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              libContact,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xFF0F172A),
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (library?.email.isNotEmpty == true) ...[
                        const SizedBox(height: 2),
                        Text(
                          library!.email,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 8.5,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Direct Live URL',
                      style: TextStyle(
                        fontSize: 8.5,
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'study-lib-mgmt-2026.web.app',
                      style: TextStyle(
                        color: Color(0xFF4338CA),
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE2E8F0),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'Instant Mobile Access',
                        style: TextStyle(
                          fontSize: 7.5,
                          color: Color(0xFF475569),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
