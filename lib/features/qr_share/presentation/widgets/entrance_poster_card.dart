import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:study_library/features/seats/presentation/providers/seat_providers.dart';
import 'package:study_library/models/library_model.dart';
import 'package:study_library/services/image_service.dart';
import 'package:study_library/services/poster_config_service.dart';

class EntrancePosterCard extends ConsumerWidget {
  final LibraryModel? library;
  final String libraryId;
  final List<Map<String, dynamic>> amenities;
  final String? urgencyText;
  final PosterLayoutConfig config;

  const EntrancePosterCard({
    super.key,
    required this.library,
    required this.libraryId,
    required this.amenities,
    this.urgencyText,
    this.config = const PosterLayoutConfig(),
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

  Widget _buildFallbackLogo(Color color, {double size = 22}) {
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
          size: 18,
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

    final tagline = PosterLayoutConfig.resolveTagline(library?.tagline ?? '', libName);

    final brandPrimary = (library?.accentColor != null && library!.accentColor != 0)
        ? Color(library!.accentColor)
        : const Color(0xFF5D4037);

    final hsl = HSLColor.fromColor(brandPrimary);
    final brandDark = hsl.withLightness((hsl.lightness * 0.56).clamp(0.0, 1.0)).toColor();
    final brandRich = hsl.withLightness((hsl.lightness * 0.85).clamp(0.18, 0.42)).toColor();
    const goldAccent = Color(0xFFF59E0B);
    const goldText = Color(0xFFFCD34D);

    final logoProvider = (library != null && library!.logoUrl.isNotEmpty)
        ? ImageService.getImageProvider(library!.logoUrl)
        : null;

    final activeAmenities = amenities.where((a) => a['enabled'] == true).toList();
    final displayAmenities = activeAmenities.take(config.maxAmenities).toList();
    final amenityCols = PosterLayoutConfig.resolveAmenityColumns(displayAmenities.length);
    final hasThreeAmenityRows = amenityCols == 3 && displayAmenities.length > 6;

    // Budget-aware QR size guarantees generous whitespace & zero clipping even with 9 amenities + 3 steps
    final double baseQr = config.qrSizeMode == 'large' ? 172.0 : 152.0;
    final double qrBonus = (!hasThreeAmenityRows ? 16.0 : 0.0) +
        (!config.showHowToSteps ? 14.0 : 0.0) +
        (displayAmenities.length <= 3 ? 12.0 : 0.0);
    final qrSize = (baseQr + qrBonus).clamp(148.0, 204.0);

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
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: brandDark.withValues(alpha: 0.22),
            blurRadius: 32,
            offset: const Offset(0, 14),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: brandPrimary, width: 2.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── 1. 3D Layered Institutional Brand Header ───────────────────────
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [brandRich, brandPrimary, brandDark],
                stops: const [0.0, 0.48, 1.0],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border(
                bottom: BorderSide(color: goldAccent.withValues(alpha: 0.75), width: 2.0),
              ),
              boxShadow: [
                BoxShadow(
                  color: brandDark.withValues(alpha: 0.28),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Subtle 3D top spotlight glow behind crest
                Positioned(
                  top: -36,
                  child: Container(
                    width: 240,
                    height: 110,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          Colors.white.withValues(alpha: 0.14),
                          Colors.white.withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 11, 22, 11),
                  child: Column(
                    children: [
                      // 1. Floating 3D Medallion Crest
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2.4),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.32),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                            BoxShadow(
                              color: goldAccent.withValues(alpha: 0.25),
                              blurRadius: 8,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: ClipOval(
                          child: logoProvider != null
                              ? Image(
                                  image: logoProvider,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) => _buildFallbackLogo(brandPrimary, size: 22),
                                )
                              : _buildFallbackLogo(brandPrimary, size: 22),
                        ),
                      ),
                      const SizedBox(height: 6),

                      // 2. Warm Golden-Amber 3D Bevelled "WELCOME TO" Pill
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFFDE68A).withValues(alpha: 0.8), width: 0.9),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.26),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Text(
                          'WELCOME TO',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 8.6,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.5,
                            shadows: [
                              Shadow(color: Colors.black26, offset: Offset(0, 1), blurRadius: 2),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),

                      // 3. 3D Extruded Institutional Title
                      Text(
                        libName.toUpperCase(),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17.5,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.6,
                          shadows: [
                            Shadow(color: Colors.black54, offset: Offset(0, 2.5), blurRadius: 5),
                            Shadow(color: Colors.black26, offset: Offset(0, 1), blurRadius: 1),
                          ],
                        ),
                      ),

                      if (config.showTagline && tagline.isNotEmpty) ...[
                        const SizedBox(height: 2.5),
                        Text(
                          tagline,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: goldText,
                            fontSize: 9.8,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.25,
                            shadows: [
                              Shadow(color: Colors.black38, offset: Offset(0, 1), blurRadius: 2),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 2.5),
                      Text(
                        libAddress,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 9.2,
                          height: 1.25,
                        ),
                      ),

                      if (config.showHours) ...[
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 3.5),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.28),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: goldAccent.withValues(alpha: 0.85), width: 1.1),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.18),
                                blurRadius: 4,
                                offset: const Offset(0, 1.5),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.schedule_rounded, size: 11, color: goldText),
                              const SizedBox(width: 5),
                              Text(
                                'HOURS: $operatingHours',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 9.0,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.35,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── 2. Spacious 3D Canvas Body ─────────────────────────────────────
          Expanded(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFFFFFDF9), Colors.white, Color(0xFFFAFBFD)],
                  stops: [0.0, 0.55, 1.0],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              padding: const EdgeInsets.fromLTRB(22, 12, 22, 10),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Top Status Pills + Headline Block
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if ((config.showLiveSeatCount && hasOccupancyData) || config.showUrgency) ...[
                        Wrap(
                          alignment: WrapAlignment.center,
                          spacing: 10,
                          runSpacing: 6,
                          children: [
                            if (config.showLiveSeatCount && hasOccupancyData)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4.5),
                                decoration: BoxDecoration(
                                  color: availableSeats == 0
                                      ? Colors.red.shade50
                                      : const Color(0xFFECFDF5),
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(
                                    color: availableSeats == 0
                                        ? Colors.red.shade300
                                        : const Color(0xFF10B981),
                                    width: 1.1,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: (availableSeats == 0 ? Colors.red : const Color(0xFF10B981))
                                          .withValues(alpha: 0.14),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      availableSeats == 0
                                          ? Icons.event_busy_rounded
                                          : Icons.event_seat_rounded,
                                      size: 13,
                                      color: availableSeats == 0
                                          ? Colors.red.shade900
                                          : const Color(0xFF047857),
                                    ),
                                    const SizedBox(width: 5),
                                    Text(
                                      availableSeats == 0
                                          ? 'Full Capacity (Join Waiting List)'
                                          : '$availableSeats of $totalSeats Desks Open Live',
                                      style: TextStyle(
                                        color: availableSeats == 0
                                            ? Colors.red.shade900
                                            : const Color(0xFF065F46),
                                        fontSize: 9.8,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            if (config.showUrgency &&
                                !(config.showLiveSeatCount && hasOccupancyData && availableSeats == 0))
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4.5),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFFFEF3C7), Color(0xFFFDE68A)],
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                  ),
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(color: const Color(0xFFF59E0B), width: 1.1),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFFF59E0B).withValues(alpha: 0.16),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.bolt_rounded, size: 13, color: Color(0xFFD97706)),
                                    const SizedBox(width: 4),
                                    Text(
                                      urgencyText?.trim().isNotEmpty == true
                                          ? urgencyText!.trim()
                                          : config.urgencyText,
                                      style: const TextStyle(
                                        color: Color(0xFF92400E),
                                        fontSize: 9.8,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 0.25,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 10),
                      ],
                      Text(
                        'Scan To Check Live Available Seats',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: const Color(0xFF0F172A),
                          fontSize: 16.5,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.2,
                          shadows: [
                            Shadow(
                              color: brandPrimary.withValues(alpha: 0.12),
                              offset: const Offset(0, 1.5),
                              blurRadius: 3,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 3),
                      const Text(
                        'Point your smartphone camera at this QR code to view vacant seats in real-time before entering.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 9.8,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),

                  // ── Hero 3D Floating QR Pedestal ──────────────────────────
                  Container(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 11),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: brandPrimary.withValues(alpha: 0.22), width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: brandDark.withValues(alpha: 0.14),
                          blurRadius: 24,
                          offset: const Offset(0, 10),
                        ),
                        BoxShadow(
                          color: const Color(0xFF0F172A).withValues(alpha: 0.06),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            QrImageView(
                              data: seatMapUrl,
                              version: QrVersions.auto,
                              size: qrSize,
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
                            Container(
                              width: 38,
                              height: 38,
                              padding: const EdgeInsets.all(2.5),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: brandPrimary.withValues(alpha: 0.5),
                                  width: 2.0,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.18),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
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
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3.5),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                brandPrimary.withValues(alpha: 0.08),
                                brandPrimary.withValues(alpha: 0.14),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: brandPrimary.withValues(alpha: 0.15)),
                          ),
                          child: Text(
                            'NO APP REQUIRED • INSTANT LIVE SEAT MAP',
                            style: TextStyle(
                              fontSize: 7.8,
                              fontWeight: FontWeight.w800,
                              color: brandDark,
                              letterSpacing: 0.7,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ── 3-Step Walk-In Guide (Compact 3D Pill Strip) ──────────
                  if (config.showHowToSteps)
                    Row(
                      children: [
                        _buildStepTile(
                          step: '1',
                          title: 'Scan QR Code',
                          subtitle: 'Any phone camera',
                          accent: brandPrimary,
                        ),
                        const SizedBox(width: 9),
                        _buildStepTile(
                          step: '2',
                          title: 'Pick Vacant Desk',
                          subtitle: 'Live hall map',
                          accent: brandPrimary,
                        ),
                        const SizedBox(width: 9),
                        _buildStepTile(
                          step: '3',
                          title: 'Apply Online',
                          subtitle: 'Instant admission',
                          accent: brandPrimary,
                        ),
                      ],
                    ),

                  // ── 3. Adaptive 3D Amenities Grid (Zero Clipping) ──────────
                  if (displayAmenities.isNotEmpty)
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(width: 24, height: 1, color: const Color(0xFFCBD5E1)),
                            const SizedBox(width: 8),
                            const Text(
                              'LIBRARY AMENITIES & FACILITIES',
                              style: TextStyle(
                                color: Color(0xFF64748B),
                                fontSize: 9.0,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.1,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(width: 24, height: 1, color: const Color(0xFFCBD5E1)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: displayAmenities.length,
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: amenityCols,
                            childAspectRatio: amenityCols == 1
                                ? 5.8
                                : (amenityCols == 2
                                    ? 4.1
                                    : (hasThreeAmenityRows ? 3.35 : 3.0)),
                            crossAxisSpacing: 9,
                            mainAxisSpacing: 7,
                          ),
                          itemBuilder: (context, idx) {
                            final item = displayAmenities[idx];
                            final id = item['id']?.toString().toLowerCase() ?? '';
                            const defaultDescriptions = {
                              'ac': 'Fully Air-Conditioned',
                              'wifi': 'High-Speed Optical Fiber',
                              'silence': 'Pindrop Quiet Zone',
                              'ro_water': 'Chilled & Normal RO',
                              'power': 'Personal Desk Socket',
                              'desk_lamp': 'Individual Study Lamp',
                              'open_24_7': 'Round-The-Clock',
                              'cctv': '24/7 Security',
                              'chairs': 'Ergonomic Seating',
                              'locker': 'Private Lockers',
                              'power_backup': 'Uninterrupted Inverter',
                              'parking': 'Dedicated Parking',
                              'pantry': 'Tea & Refreshments',
                              'newspapers': 'Daily Newspapers',
                              'natural_light': 'Ventilated Seating',
                            };
                            final desc = defaultDescriptions[id] ?? 'Admin Verified Facility';
                            final iconColor = _getAmenityIconColor(id, item['label']?.toString() ?? '');

                            return Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(11),
                                border: Border.all(color: const Color(0xFFE2E8F0), width: 1.0),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF0F172A).withValues(alpha: 0.05),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2.5),
                                  ),
                                ],
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                              child: Row(
                                children: [
                                  Container(
                                    width: 24,
                                    height: 24,
                                    decoration: BoxDecoration(
                                      color: iconColor.withValues(alpha: 0.12),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      _getAmenityIconData(id, item['label']?.toString() ?? ''),
                                      size: 13,
                                      color: iconColor,
                                    ),
                                  ),
                                  const SizedBox(width: 7),
                                  Expanded(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item['label']?.toString() ?? '',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: Color(0xFF1E293B),
                                            fontSize: 8.8,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                        const SizedBox(height: 1),
                                        Text(
                                          desc,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: Color(0xFF64748B),
                                            fontSize: 7.4,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
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

          // ── 4. Elevated Institutional Footer (Always Visible) ──────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 9),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              border: const Border(
                top: BorderSide(color: Color(0xFFE2E8F0), width: 1.2),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 6,
                  offset: const Offset(0, -2),
                ),
              ],
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
                          Icon(Icons.phone_in_talk_rounded, size: 12, color: brandPrimary),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              libContact,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xFF0F172A),
                                fontSize: 10.5,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (library?.email.isNotEmpty == true) ...[
                        const SizedBox(height: 1.5),
                        Text(
                          library!.email,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 8.0,
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
                      'study-lib-mgmt-2026.web.app/seats',
                      style: TextStyle(
                        color: Color(0xFF4F46E5),
                        fontSize: 9.2,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE2E8F0),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: const Text(
                        'Instant Mobile Access',
                        style: TextStyle(
                          fontSize: 7.0,
                          color: Color(0xFF475569),
                          fontWeight: FontWeight.w700,
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

  Widget _buildStepTile({
    required String step,
    required String title,
    required String subtitle,
    required Color accent,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6.5),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(11),
          border: Border.all(color: accent.withValues(alpha: 0.16)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0F172A).withValues(alpha: 0.05),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 21,
              height: 21,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [accent, Color.lerp(accent, Colors.black, 0.22)!],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: accent.withValues(alpha: 0.28),
                    blurRadius: 4,
                    offset: const Offset(0, 1.5),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: Text(
                step,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 9.8,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(width: 7),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF0F172A),
                      fontSize: 8.8,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 7.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
