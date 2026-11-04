import 'package:study_library/services/pdf_font_service.dart';
import 'package:study_library/core/utils/file_download_helper.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:study_library/models/library_model.dart';
import 'package:study_library/services/poster_config_service.dart';

/// Professional Full-Page A4 Poster & Standee PDF Service.
///
/// Designed specifically for standard A4 (210mm x 297mm) print paper:
/// - Spans the full printable width of the A4 page (zero large side margins).
/// - Displays high-urgency callout: "⚡ HURRY! LIMITED SEATS LEFT" instead of static seat numbers.
/// - Crisp 1200 DPI vector optical QR code with centered logo emblem.
/// - Full-width institutional header, amenities grid, and helpline footer.
class A4EntrancePosterPdfService {
  static String _formatHelpline(String raw) {
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.length == 10) {
      return '+91 ${digits.substring(0, 5)} ${digits.substring(5)}';
    } else if (digits.length == 12 && digits.startsWith('91')) {
      return '+91 ${digits.substring(2, 7)} ${digits.substring(7)}';
    }
    return raw.trim().isNotEmpty ? raw.trim() : 'Reception Desk';
  }

  /// Builds the complete Full-Bleed A4 Poster Document
  static Future<pw.Document> generateA4PosterDoc({
    required String libraryId,
    LibraryModel? library,
    required String seatMapUrl,
    List<Map<String, dynamic>>? customAmenities,
    String? urgencyText,
  }) async {
    final libName = library?.name.isNotEmpty == true ? library!.name : 'Study Centre';
    final libAddress = library?.address.isNotEmpty == true
        ? library!.address
        : 'Study Centre Locality & Address';

    final rawPhone = (library?.contact.isNotEmpty == true
            ? library!.contact
            : (library?.helplineNumber.isNotEmpty == true
                ? library!.helplineNumber
                : (library?.whatsappNumber ?? '')))
        .trim();
    final libPhone = _formatHelpline(rawPhone);
    final libEmail = library?.email ?? '';

    final operatingHours = library?.operatingHours.isNotEmpty == true
        ? library!.operatingHours
        : '06:00 AM – 11:00 PM (Daily)';
    final safeOperatingHours = operatingHours.replaceAll('–', '-').replaceAll('—', '-');
    final tagline = library?.tagline.isNotEmpty == true
        ? library!.tagline
        : 'Smart Study Center & Silent Reading Hall';

    final brandPrimaryInt = (library?.accentColor != null && library!.accentColor != 0)
        ? library.accentColor
        : 0xFF5D4037;
    final brandColor = PdfColor.fromInt(brandPrimaryInt);

    // Fetch amenities if not supplied
    final amenities = customAmenities ?? await PosterConfigService.fetchAmenities(libraryId);
    final activeAmenities = amenities.where((a) => a['enabled'] == true).toList();

    // Load logo image safely (supports base64 and network URLs)
    pw.ImageProvider? logoImage;
    if (library != null && library.logoUrl.isNotEmpty) {
      try {
        if (library.logoUrl.startsWith('data:image')) {
          final b64 = library.logoUrl.contains(',')
              ? library.logoUrl.split(',')[1]
              : library.logoUrl;
          logoImage = pw.MemoryImage(base64Decode(b64));
        } else {
          logoImage = await networkImage(library.logoUrl);
        }
      } catch (_) {
        logoImage = null;
      }
    }

    final pdf = pw.Document();
    final universalTheme = await PdfFontService.getUniversalTheme();

    final rawUrgency = (urgencyText != null && urgencyText.trim().isNotEmpty)
        ? urgencyText.trim()
        : 'HURRY! LIMITED SEATS LEFT';
    final cleanUrgency = rawUrgency
        .replaceAll(RegExp(r'[^\x20-\x7E\u0900-\u097F]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    final effectiveUrgency = cleanUrgency.isNotEmpty ? cleanUrgency : 'HURRY! LIMITED SEATS LEFT';

    String getAmenitySvg(String idOrLabel) {
      final l = idOrLabel.toLowerCase();
      if (l.contains('wi-fi') || l.contains('wifi')) {
        return '<svg viewBox="0 0 24 24" width="13" height="13"><path d="M12 18c1.1 0 2-.9 2-2s-.9-2-2-2-2 .9-2 2 .9 2 2 2zm-4.9-4.9l1.4 1.4C9.6 13.4 10.7 13 12 13s2.4.4 3.5 1.5l1.4-1.4C15.4 11.6 13.8 11 12 11s-3.4.6-4.9 2.1zm-3.5-3.5l1.4 1.4C6.8 9.2 9.3 8 12 8s5.2 1.2 7 3l1.4-1.4C18.2 7.4 15.2 6 12 6S5.8 7.4 3.6 9.6z" fill="#0284C7"/></svg>';
      }
      if (l.contains('silence') || l.contains('quiet') || l.contains('zone')) {
        return '<svg viewBox="0 0 24 24" width="13" height="13"><path d="M4.34 2.93L2.93 4.34 7.29 8.7 7 9H3v6h4l5 5v-6.59l4.18 4.18c-.65.49-1.38.88-2.18 1.11v2.06c1.34-.3 2.57-.92 3.61-1.75l2.05 2.05 1.41-1.41L4.34 2.93zM12 4L9.91 6.09 12 8.18V4z" fill="#D97706"/></svg>';
      }
      if (l.contains('water') || l.contains('ro')) {
        return '<svg viewBox="0 0 24 24" width="13" height="13"><path d="M12 2.69l5.66 5.66a8 8 0 1 1-11.31 0z" fill="#0284C7"/></svg>';
      }
      if (l.contains('power') || l.contains('outlet') || l.contains('socket') || l.contains('plug')) {
        return '<svg viewBox="0 0 24 24" width="13" height="13"><path d="M16 7V3h-2v4h-4V3H8v4H6v6c0 3.31 2.69 6 6 6v3h2v-3c3.31 0 6-2.69 6-6V7h-4z" fill="#475569"/></svg>';
      }
      if (l.contains('backup') || l.contains('battery') || l.contains('inverter') || l.contains('generator')) {
        return '<svg viewBox="0 0 24 24" width="13" height="13"><path d="M15.67 4H14V2h-4v2H8.33C7.6 4 7 4.6 7 5.33v15.33C7 21.4 7.6 22 8.33 22h7.33c.74 0 1.34-.6 1.34-1.33V5.33C17 4.6 16.4 4 15.67 4zM11 20v-5.5H9L13 7v5.5h2L11 20z" fill="#16A34A"/></svg>';
      }
      if (l.contains('cctv') || l.contains('surveillance') || l.contains('camera') || l.contains('security')) {
        return '<svg viewBox="0 0 24 24" width="13" height="13"><path d="M17 10.5V7c0-.55-.45-1-1-1H4c-.55 0-1 .45-1 1v10c0 .55.45 1 1 1h12c.55 0 1-.45 1-1v-3.5l4 4v-11l-4 4z" fill="#4F46E5"/></svg>';
      }
      if (l.contains('ac') || l.contains('air') || l.contains('cool') || l.contains('climate')) {
        return '<svg viewBox="0 0 24 24" width="13" height="13"><path d="M19.35 10.04C18.67 6.59 15.64 4 12 4 9.11 4 6.6 5.64 5.35 8.04 2.34 8.36 0 10.91 0 14c0 3.31 2.69 6 6 6h13c2.76 0 5-2.24 5-5 0-2.64-2.05-4.78-4.65-4.96z" fill="#0284C7"/></svg>';
      }
      if (l.contains('24/7') || l.contains('hour') || l.contains('time') || l.contains('open')) {
        return '<svg viewBox="0 0 24 24" width="13" height="13"><path d="M11.99 2C6.47 2 2 6.48 2 12s4.47 10 9.99 10C17.52 22 22 17.52 22 12S17.52 2 11.99 2zM12 20c-4.42 0-8-3.58-8-8s3.58-8 8-8 8 3.58 8 8-3.58 8-8 8zm.5-13H11v6l5.25 3.15.75-1.23-4.5-2.67z" fill="#D97706"/></svg>';
      }
      if (l.contains('chair') || l.contains('desk') || l.contains('seat')) {
        return '<svg viewBox="0 0 24 24" width="13" height="13"><path d="M19 13v-2c0-1.1-.9-2-2-2H7c-1.1 0-2 .9-2 2v2H3v6h2v-2h14v2h2v-6h-2zm-2-2H7V9h10v2z" fill="#78350F"/></svg>';
      }
      if (l.contains('parking')) {
        return '<svg viewBox="0 0 24 24" width="13" height="13"><path d="M13.2 11H10V7h3.2c1.1 0 2 .9 2 2s-.9 2-2 2zm-3.2 9h2v-6h1.2c2.2 0 4-1.8 4-4s-1.8-4-4-4H8v14h2z" fill="#2563EB"/></svg>';
      }
      if (l.contains('locker') || l.contains('storage')) {
        return '<svg viewBox="0 0 24 24" width="13" height="13"><path d="M18 8h-1V6c0-2.76-2.24-5-5-5S7 3.24 7 6v2H6c-1.1 0-2 .9-2 2v10c0 1.1.9 2 2 2h12c1.1 0 2-.9 2-2V10c0-1.1-.9-2-2-2zm-6 9c-1.1 0-2-.9-2-2s.9-2 2-2 2 .9 2 2-.9 2-2 2zm3.1-9H8.9V6c0-1.71 1.39-3.1 3.1-3.1 1.71 0 3.1 1.39 3.1 3.1v2z" fill="#0D9488"/></svg>';
      }
      return '<svg viewBox="0 0 24 24" width="13" height="13"><path d="M12 1L3 5v6c0 5.55 3.84 10.74 9 12 5.16-1.26 9-6.45 9-12V5l-9-4zm-2 16l-4-4 1.41-1.41L10 14.17l6.59-6.59L18 9l-8 8z" fill="#16A34A"/></svg>';
    }

    String getAmenityDesc(String label) {
      final l = label.toLowerCase();
      if (l.contains('wi-fi') || l.contains('wifi')) return 'High-Speed Optical Fiber';
      if (l.contains('silence') || l.contains('quiet')) return 'Strict Silent Ambience';
      if (l.contains('ro') || l.contains('water')) return 'Purified Chilled & Normal RO';
      if (l.contains('socket') || l.contains('power') || l.contains('outlet')) return 'Personal Socket At Desk';
      if (l.contains('backup')) return '100% Inverter & Generator';
      if (l.contains('cctv') || l.contains('surveillance')) return '24/7 Security Surveillance';
      if (l.contains('ac') || l.contains('air condition')) return 'Climate Controlled Hall';
      if (l.contains('chair')) return 'Ergonomic Cushioned Chairs';
      if (l.contains('locker')) return 'Secure Storage Lockers';
      if (l.contains('pantry') || l.contains('cafeteria')) return 'Tea, Coffee & Dining Zone';
      if (l.contains('newspaper') || l.contains('magazine')) return 'Daily Newspapers & Periodicals';
      if (l.contains('parking')) return 'Safe Covered Parking';
      if (l.contains('24/7') || l.contains('open')) return 'Flexible Extended Timings';
      return 'Dedicated Study Facility';
    }

    pw.Widget buildAmenityCard(Map<String, dynamic> item) {
      final rawLabel = item['label']?.toString() ?? '';
      final cleanLabel = rawLabel
          .replaceAll(RegExp(r'[\u{1F600}-\u{1F64F}\u{1F300}-\u{1F5FF}\u{1F680}-\u{1F6FF}\u{1F700}-\u{1F77F}\u{1F780}-\u{1F7FF}\u{1F800}-\u{1F8FF}\u{1F900}-\u{1F9FF}\u{1FA00}-\u{1FA6F}\u{1FA70}-\u{1FAFF}\u{2600}-\u{26FF}\u{2700}-\u{27BF}\u{2300}-\u{23FF}\u{2B50}]', unicode: true), '')
          .replaceAll(RegExp(r'^[^\w\u0900-\u097F]+'), '')
          .trim();
      final label = cleanLabel.isNotEmpty ? cleanLabel : rawLabel.trim();
      final itemId = item['id']?.toString() ?? label;
      final svgIcon = getAmenitySvg('$itemId $label');
      final rawDesc = (item['description']?.toString() ?? '').isNotEmpty
          ? item['description']!.toString()
          : getAmenityDesc(label);
      final desc = rawDesc
          .replaceAll(RegExp(r'[\u{1F600}-\u{1F64F}\u{1F300}-\u{1F5FF}\u{1F680}-\u{1F6FF}\u{1F700}-\u{1F77F}\u{1F780}-\u{1F7FF}\u{1F800}-\u{1F8FF}\u{1F900}-\u{1F9FF}\u{1FA00}-\u{1FA6F}\u{1FA70}-\u{1FAFF}\u{2600}-\u{26FF}\u{2700}-\u{27BF}\u{2300}-\u{23FF}\u{2B50}]', unicode: true), '')
          .trim();

      return pw.Expanded(
        child: pw.Container(
          margin: const pw.EdgeInsets.symmetric(horizontal: 4),
          padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          decoration: pw.BoxDecoration(
            color: const PdfColor.fromInt(0xFFF8FAFC),
            borderRadius: pw.BorderRadius.circular(8),
            border: pw.Border.all(
              color: const PdfColor.fromInt(0xFFE2E8F0),
              width: 1,
            ),
          ),
          child: pw.Column(
            mainAxisAlignment: pw.MainAxisAlignment.center,
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.center,
                children: [
                  pw.SvgImage(
                    svg: svgIcon,
                    width: 11,
                    height: 11,
                  ),
                  pw.SizedBox(width: 4),
                  pw.Text(
                    label,
                    textAlign: pw.TextAlign.center,
                    style: pw.TextStyle(
                      fontSize: 8.5,
                      fontWeight: pw.FontWeight.bold,
                      color: const PdfColor.fromInt(0xFF1E293B),
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 2),
              pw.Text(
                desc,
                textAlign: pw.TextAlign.center,
                style: const pw.TextStyle(
                  fontSize: 6.8,
                  color: PdfColor.fromInt(0xFF64748B),
                ),
              ),
            ],
          ),
        ),
      );
    }

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        theme: universalTheme,
        margin: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        build: (pw.Context ctx) {
          return pw.Container(
            width: double.infinity,
            height: double.infinity,
            decoration: pw.BoxDecoration(
              color: PdfColors.white,
              border: pw.Border.all(color: brandColor, width: 2.5),
              borderRadius: pw.BorderRadius.circular(16),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                // ── 1. Full-Width Institutional Header Banner ───────────────
                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  decoration: pw.BoxDecoration(
                    color: brandColor,
                    borderRadius: const pw.BorderRadius.vertical(
                      top: pw.Radius.circular(13.5),
                    ),
                  ),
                  child: pw.Column(
                    children: [
                      // Centered Logo Crest
                      if (logoImage != null) ...[
                        pw.Container(
                          width: 56,
                          height: 56,
                          decoration: pw.BoxDecoration(
                            shape: pw.BoxShape.circle,
                            color: PdfColors.white,
                            border: pw.Border.all(color: PdfColors.white, width: 2.5),
                          ),
                          child: pw.ClipOval(
                            child: pw.Image(logoImage, fit: pw.BoxFit.cover),
                          ),
                        ),
                        pw.SizedBox(height: 8),
                      ],

                      // Golden "WELCOME TO" Pill Badge
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 4.5),
                        decoration: pw.BoxDecoration(
                          color: const PdfColor.fromInt(0xFFD97706),
                          borderRadius: pw.BorderRadius.circular(14),
                        ),
                        child: pw.Text(
                          'WELCOME TO',
                          style: pw.TextStyle(
                            color: PdfColors.white,
                            fontSize: 10,
                            fontWeight: pw.FontWeight.bold,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ),
                      pw.SizedBox(height: 10),

                      // Institutional Name
                      pw.Text(
                        libName.toUpperCase(),
                        textAlign: pw.TextAlign.center,
                        style: pw.TextStyle(
                          color: PdfColors.white,
                          fontSize: 22,
                          fontWeight: pw.FontWeight.bold,
                          letterSpacing: 0.8,
                        ),
                      ),

                      // Tagline / Mission
                      if (tagline.isNotEmpty) ...[
                        pw.SizedBox(height: 3),
                        pw.Text(
                          tagline,
                          textAlign: pw.TextAlign.center,
                          style: pw.TextStyle(
                            color: const PdfColor.fromInt(0xFFFDE68A),
                            fontSize: 11,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ],

                      // Address
                      if (libAddress.isNotEmpty) ...[
                        pw.SizedBox(height: 4),
                        pw.Text(
                          libAddress,
                          textAlign: pw.TextAlign.center,
                          style: const pw.TextStyle(color: PdfColors.white, fontSize: 10),
                        ),
                      ],

                      pw.SizedBox(height: 8),

                      // Operating Hours Badge
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 5),
                        decoration: pw.BoxDecoration(
                          color: const PdfColor(0.20, 0.12, 0.08),
                          borderRadius: pw.BorderRadius.circular(16),
                          border: pw.Border.all(
                            color: const PdfColor(0.95, 0.65, 0.20),
                            width: 1.2,
                          ),
                        ),
                        child: pw.Row(
                          mainAxisSize: pw.MainAxisSize.min,
                          children: [
                            pw.Text(
                              'HOURS: $safeOperatingHours',
                              style: pw.TextStyle(
                                color: const PdfColor(1.0, 0.96, 0.88),
                                fontSize: 9.5,
                                fontWeight: pw.FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // ── 2. Real-Time Seat Tracker & Optical QR Body ─────────────
                pw.Expanded(
                  child: pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    child: pw.Column(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly,
                      crossAxisAlignment: pw.CrossAxisAlignment.center,
                      children: [
                        // Urgency Callout Pill Badge (Replaces static seat count!)
                        pw.Container(
                          padding: const pw.EdgeInsets.symmetric(horizontal: 18, vertical: 6),
                          decoration: pw.BoxDecoration(
                            color: const PdfColor.fromInt(0xFFFEF3C7), // Amber 50
                            borderRadius: pw.BorderRadius.circular(16),
                            border: pw.Border.all(
                              color: const PdfColor.fromInt(0xFFF59E0B), // Amber 500
                              width: 1.2,
                            ),
                          ),
                          child: pw.Row(
                            mainAxisSize: pw.MainAxisSize.min,
                            children: [
                              pw.SvgImage(
                                svg: '<svg viewBox="0 0 24 24" width="13" height="13"><path d="M7 2v11h3v9l7-12h-4l4-8z" fill="#D97706"/></svg>',
                                width: 13,
                                height: 13,
                              ),
                              pw.SizedBox(width: 7),
                              pw.Text(
                                effectiveUrgency,
                                style: pw.TextStyle(
                                  color: const PdfColor.fromInt(0xFF92400E), // Amber 800
                                  fontSize: 11.5,
                                  fontWeight: pw.FontWeight.bold,
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Action Heading
                        pw.Column(
                          children: [
                            pw.Text(
                              'Scan To Check Live Available Seats',
                              style: pw.TextStyle(
                                fontSize: 18,
                                fontWeight: pw.FontWeight.bold,
                                color: const PdfColor.fromInt(0xFF0F172A),
                              ),
                            ),
                            pw.SizedBox(height: 4),
                            pw.Text(
                              'Point your smartphone camera at this QR code to view vacant seats in real-time before entering.',
                              textAlign: pw.TextAlign.center,
                              style: const pw.TextStyle(
                                fontSize: 10.5,
                                color: PdfColor.fromInt(0xFF64748B),
                              ),
                            ),
                          ],
                        ),

                        // Large Optical QR Code with Center Shield
                        pw.Container(
                          padding: const pw.EdgeInsets.all(12),
                          decoration: pw.BoxDecoration(
                            color: PdfColors.white,
                            border: pw.Border.all(
                              color: const PdfColor.fromInt(0xFFE2E8F0),
                              width: 2,
                            ),
                            borderRadius: pw.BorderRadius.circular(20),
                          ),
                          child: pw.Stack(
                            alignment: pw.Alignment.center,
                            children: [
                              pw.BarcodeWidget(
                                barcode: pw.Barcode.qrCode(),
                                data: seatMapUrl,
                                width: 200,
                                height: 200,
                                color: const PdfColor.fromInt(0xFF0F172A),
                              ),
                              if (logoImage != null)
                                pw.Container(
                                  width: 44,
                                  height: 44,
                                  decoration: pw.BoxDecoration(
                                    color: PdfColors.white,
                                    shape: pw.BoxShape.circle,
                                    border: pw.Border.all(color: brandColor, width: 2.2),
                                  ),
                                  child: pw.ClipOval(
                                    child: pw.Image(logoImage, fit: pw.BoxFit.cover),
                                  ),
                                ),
                            ],
                          ),
                        ),

                        // ── 3. Full-Width Amenities Grid ───────────────────
                        pw.Column(
                          children: [
                            pw.Text(
                              'LIBRARY AMENITIES & FACILITIES',
                              style: pw.TextStyle(
                                fontSize: 10,
                                fontWeight: pw.FontWeight.bold,
                                color: const PdfColor.fromInt(0xFF64748B),
                                letterSpacing: 1.2,
                              ),
                            ),
                            pw.SizedBox(height: 8),
                            // Row 1 of amenities
                            pw.Row(
                              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                              children: [
                                for (int i = 0; i < 3; i++)
                                  if (i < activeAmenities.length)
                                    buildAmenityCard(activeAmenities[i]),
                              ],
                            ),
                            // Row 2 of amenities
                            if (activeAmenities.length > 3) ...[
                              pw.SizedBox(height: 6),
                              pw.Row(
                                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                                children: [
                                  for (int i = 3; i < 6; i++)
                                    if (i < activeAmenities.length)
                                      buildAmenityCard(activeAmenities[i]),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                // ── 4. Full-Width Institutional Footer ──────────────────────
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: const pw.BoxDecoration(
                    border: pw.Border(
                      top: pw.BorderSide(color: PdfColor.fromInt(0xFFE2E8F0), width: 1.2),
                    ),
                    color: PdfColor.fromInt(0xFFF8FAFC),
                    borderRadius: pw.BorderRadius.vertical(
                      bottom: pw.Radius.circular(13.5),
                    ),
                  ),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'Admission Helpline / WhatsApp: $libPhone',
                            style: pw.TextStyle(
                              fontSize: 9.5,
                              fontWeight: pw.FontWeight.bold,
                              color: const PdfColor.fromInt(0xFF1E293B),
                            ),
                          ),
                          if (libEmail.isNotEmpty)
                            pw.Text(
                              libEmail,
                              style: const pw.TextStyle(
                                fontSize: 8.5,
                                color: PdfColor.fromInt(0xFF64748B),
                              ),
                            ),
                        ],
                      ),
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.end,
                        children: [
                          pw.Text(
                            'Direct Live URL: study-lib-mgmt-2026.web.app',
                            style: pw.TextStyle(
                              fontSize: 9.5,
                              fontWeight: pw.FontWeight.bold,
                              color: const PdfColor.fromInt(0xFF2563EB),
                            ),
                          ),
                          pw.Container(
                            padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: pw.BoxDecoration(
                              color: const PdfColor.fromInt(0xFFE2E8F0),
                              borderRadius: pw.BorderRadius.circular(4),
                            ),
                            child: pw.Text(
                              'Instant Mobile Access',
                              style: pw.TextStyle(
                                fontSize: 7.5,
                                fontWeight: pw.FontWeight.bold,
                                color: const PdfColor.fromInt(0xFF475569),
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
        },
      ),
    );

    return pdf;
  }

  /// Triggers full-page A4 PDF printing
  static Future<void> printA4Poster({
    required BuildContext context,
    required String libraryId,
    LibraryModel? library,
    required String seatMapUrl,
    String? urgencyText,
  }) async {
    final libName = library?.name.isNotEmpty == true ? library!.name : 'Study_Library';
    final pdf = await generateA4PosterDoc(
      libraryId: libraryId,
      library: library,
      seatMapUrl: seatMapUrl,
      urgencyText: urgencyText,
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: '${libName.replaceAll(' ', '_')}_Entrance_Poster_A4.pdf',
    );
  }

  /// Downloads the full-page A4 PDF directly to device
  static Future<void> downloadA4Pdf({
    required String libraryId,
    LibraryModel? library,
    required String seatMapUrl,
    String? urgencyText,
  }) async {
    final libName = library?.name.isNotEmpty == true ? library!.name : 'Study_Library';
    final pdf = await generateA4PosterDoc(
      libraryId: libraryId,
      library: library,
      seatMapUrl: seatMapUrl,
      urgencyText: urgencyText,
    );
    final bytes = await pdf.save();
    final cleanName = libName.replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '_');
    await FileDownloadHelper.downloadFile(
      fileName: '${cleanName.isNotEmpty ? cleanName : "Study_Library"}_Entrance_Poster_A4.pdf',
      bytes: bytes,
      mimeType: 'application/pdf',
    );
  }
}
