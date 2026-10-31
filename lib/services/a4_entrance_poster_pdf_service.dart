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

    final effectiveUrgency = (urgencyText != null && urgencyText.trim().isNotEmpty)
        ? urgencyText.trim()
        : '⚡  HURRY! LIMITED SEATS LEFT';

    
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
      final rawIcon = item['icon']?.toString() ?? '';
      final icon = (rawIcon.isNotEmpty && rawIcon.codeUnits.every((c) => c < 10000)) ? rawIcon : '✓';
      final label = item['label']?.toString() ?? '';
      final desc = (item['description']?.toString() ?? '').isNotEmpty
          ? item['description']!.toString()
          : getAmenityDesc(label);

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
                  pw.Text(icon, style: const pw.TextStyle(fontSize: 10)),
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
                              pw.Container(
                                width: 7,
                                height: 7,
                                decoration: const pw.BoxDecoration(
                                  color: PdfColor.fromInt(0xFFD97706),
                                  shape: pw.BoxShape.circle,
                                ),
                              ),
                              pw.SizedBox(width: 8),
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
