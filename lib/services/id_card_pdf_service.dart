import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:study_library/models/library_model.dart';
import 'package:study_library/models/student_model.dart';
import 'package:study_library/models/id_card_template_model.dart';

enum IdCardPrintFormat {
  a4CutAndFold, // Single A4 sheet with Front and Back side-by-side with cut & fold guides (Default)
  cr80Direct,   // 2 separate pages sized exactly for CR80 card printers (Evolis/Zebra)
}

class IdCardPdfService {
  // Standard CR80 dimensions in points (72 points per inch)
  // 85.6mm = 242.6 pt, 53.98mm = 153.0 pt
  static const double cardWidth = 242.6;
  static const double cardHeight = 153.0;

  /// Alias for generateIdCard to support generateIdCardPdf
  static Future<Uint8List> generateIdCardPdf({
    required StudentModel student,
    required LibraryModel library,
    String? seatLabel,
    String? sectionName,
    String? planName,
    IdCardTemplateSettings settings = const IdCardTemplateSettings(),
    IdCardPrintFormat format = IdCardPrintFormat.a4CutAndFold,
  }) => generateIdCard(
    student: student,
    library: library,
    seatLabel: seatLabel,
    sectionName: sectionName,
    planName: planName,
    settings: settings,
    format: format,
  );

  /// Generates a student ID card PDF.
  /// Defaults to [IdCardPrintFormat.a4CutAndFold] to print both Front and Back on ONE sheet
  /// with smart cutouts (✂) and center fold line.
  static Future<Uint8List> generateIdCard({
    required StudentModel student,
    required LibraryModel library,
    String? seatLabel,
    String? sectionName,
    String? planName,
    IdCardTemplateSettings settings = const IdCardTemplateSettings(),
    IdCardPrintFormat format = IdCardPrintFormat.a4CutAndFold,
  }) async {
    final pdf = pw.Document();
    final dateFormat = DateFormat('dd/MM/yyyy');

    // Load custom fields configured for ID card display
    List<Map<String, dynamic>> customFields = [];
    try {
      final configDoc = await FirebaseFirestore.instance
          .collection('libraries').doc(library.id)
          .collection('settings').doc('form_config').get();
      if (configDoc.exists) {
        final data = configDoc.data()?['fields'] as List<dynamic>? ?? [];
        customFields = data
            .whereType<Map>()
            .map((f) => Map<String, dynamic>.from(f))
            .where((f) =>
                !(f['builtin'] as bool? ?? false) && // only custom fields
                (f['showOnIdCard'] as bool? ?? false) && // only those enabled for ID card
                (f['visible'] as bool? ?? true))
            .toList();
      }
    } catch (_) {}

    // Fetch images asynchronously
    pw.ImageProvider? photoImage;
    if (student.photoUrl.isNotEmpty && settings.showPhoto) {
      try {
        if (student.photoUrl.startsWith('data:image')) {
          final b64 = student.photoUrl.contains(',') ? student.photoUrl.split(',')[1] : student.photoUrl;
          photoImage = pw.MemoryImage(base64Decode(b64));
        } else {
          photoImage = await networkImage(student.photoUrl);
        }
      } catch (e) {
        debugPrint('Could not load student photo for ID card: $e');
      }
    }

    pw.ImageProvider? logoImage;
    if (library.logoUrl.isNotEmpty) {
      try {
        if (library.logoUrl.startsWith('data:image')) {
          final b64 = library.logoUrl.contains(',') ? library.logoUrl.split(',')[1] : library.logoUrl;
          logoImage = pw.MemoryImage(base64Decode(b64));
        } else {
          logoImage = await networkImage(library.logoUrl);
        }
      } catch (e) {
        debugPrint('Could not load library logo for ID card: $e');
      }
    }

    final primaryColor = PdfColor.fromInt(library.accentColor != 0 ? library.accentColor : 0xFF4F46E5);
    final validTo = student.planEndDate != null ? dateFormat.format(student.planEndDate!) : 'N/A';
    final validFrom = student.planStartDate != null ? dateFormat.format(student.planStartDate!) : dateFormat.format(DateTime.now());

    final seatText = (seatLabel != null && seatLabel.isNotEmpty)
        ? seatLabel
        : (student.seatId != null && student.seatId!.isNotEmpty ? student.seatId! : 'Unassigned');

    final secText = (sectionName != null && sectionName.isNotEmpty) ? ' ($sectionName)' : '';

    if (format == IdCardPrintFormat.a4CutAndFold) {
      // ── SINGLE PAGE A4 WITH SMART CUTOUTS (ATM CARD SIZE) ────────────────
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                // Top Header / Print Guide
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.grey100,
                    borderRadius: pw.BorderRadius.circular(6),
                    border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
                  ),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'OFFICIAL STUDENT ID CARD — ATM / CR-80 STANDARD (85.6 mm × 54.0 mm)',
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8.5, color: PdfColors.grey800),
                          ),
                          pw.SizedBox(height: 2),
                          pw.Text(
                            '1. Cut along the outer dashed line (✂)   2. Fold along the center fold line   3. Insert into standard card pouch or laminate',
                            style: const pw.TextStyle(fontSize: 6.5, color: PdfColors.grey600),
                          ),
                        ],
                      ),
                      pw.Text(
                        library.name,
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8, color: primaryColor),
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 28),

                // Cut & Fold Card Unit
                _buildCardCutoutUnit(
                  student: student,
                  library: library,
                  logoImage: logoImage,
                  photoImage: photoImage,
                  primaryColor: primaryColor,
                  validTo: validTo,
                  validFrom: validFrom,
                  seatText: seatText,
                  secText: secText,
                  planName: planName,
                  settings: settings,
                  customFields: customFields,
                ),

                pw.Spacer(),

                // Bottom Footer Guide
                pw.Text(
                  'Generated via Cozy Corner Study Hub Management • High Resolution 300 DPI Vector Output',
                  style: const pw.TextStyle(fontSize: 6.5, color: PdfColors.grey500),
                ),
              ],
            );
          },
        ),
      );
    } else {
      // ── DIRECT CR80 CARD PRINTER FORMAT (PAGE 1 FRONT, PAGE 2 BACK) ──────
      pdf.addPage(
        pw.Page(
          pageFormat: const PdfPageFormat(cardWidth, cardHeight, marginAll: 0),
          build: (context) => _buildCardFront(
            student: student,
            library: library,
            logoImage: logoImage,
            photoImage: photoImage,
            primaryColor: primaryColor,
            validTo: validTo,
            seatText: seatText,
            secText: secText,
            planName: planName,
            settings: settings,
            customFields: customFields,
          ),
        ),
      );

      pdf.addPage(
        pw.Page(
          pageFormat: const PdfPageFormat(cardWidth, cardHeight, marginAll: 0),
          build: (context) => _buildCardBack(
            student: student,
            library: library,
            primaryColor: primaryColor,
            validFrom: validFrom,
            seatText: seatText,
            secText: secText,
            settings: settings,
          ),
        ),
      );
    }

    return pdf.save();
  }

  /// Bulk Student ID Card Generator:
  /// Packs up to 4 complete student card pairs (Front + Back) per A4 sheet!
  /// Saves massive amounts of paper while retaining high resolution and smart cutout guides.
  static Future<Uint8List> generateBulkIdCards({
    required List<StudentModel> students,
    required LibraryModel library,
    Map<String, String>? studentSeats,
    Map<String, String>? studentSections,
    Map<String, String>? studentPlans,
    IdCardTemplateSettings settings = const IdCardTemplateSettings(),
  }) async {
    final pdf = pw.Document();
    final dateFormat = DateFormat('dd/MM/yyyy');
    final primaryColor = PdfColor.fromInt(library.accentColor != 0 ? library.accentColor : 0xFF4F46E5);

    // Load custom fields configured for ID card display
    List<Map<String, dynamic>> customFields = [];
    try {
      final configDoc = await FirebaseFirestore.instance
          .collection('libraries').doc(library.id)
          .collection('settings').doc('form_config').get();
      if (configDoc.exists) {
        final data = configDoc.data()?['fields'] as List<dynamic>? ?? [];
        customFields = data
            .whereType<Map>()
            .map((f) => Map<String, dynamic>.from(f))
            .where((f) =>
                !(f['builtin'] as bool? ?? false) &&
                (f['showOnIdCard'] as bool? ?? false) &&
                (f['visible'] as bool? ?? true))
            .toList();
      }
    } catch (_) {}

    // Preload library logo
    pw.ImageProvider? logoImage;
    if (library.logoUrl.isNotEmpty) {
      try {
        if (library.logoUrl.startsWith('data:image')) {
          final b64 = library.logoUrl.contains(',') ? library.logoUrl.split(',')[1] : library.logoUrl;
          logoImage = pw.MemoryImage(base64Decode(b64));
        } else {
          logoImage = await networkImage(library.logoUrl);
        }
      } catch (_) {}
    }

    // Chunk into 4 students per A4 sheet
    const int perPage = 4;
    for (int i = 0; i < students.length; i += perPage) {
      final pageStudents = students.skip(i).take(perPage).toList();

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      '${library.name.toUpperCase()} — BATCH STUDENT ID CARDS',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8, color: primaryColor),
                    ),
                    pw.Text(
                      'Page ${(i ~/ perPage) + 1} of ${((students.length - 1) ~/ perPage) + 1} • 4 Cards / Page',
                      style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600),
                    ),
                  ],
                ),
                pw.SizedBox(height: 12),
                pw.Expanded(
                  child: pw.Column(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly,
                    children: pageStudents.map((stu) {
                      final seat = studentSeats?[stu.id] ?? stu.seatId ?? 'Unassigned';
                      final sec = studentSections?[stu.id] != null ? ' (${studentSections![stu.id]})' : '';
                      final plan = studentPlans?[stu.id];
                      final validTo = stu.planEndDate != null ? dateFormat.format(stu.planEndDate!) : 'N/A';
                      final validFrom = stu.planStartDate != null ? dateFormat.format(stu.planStartDate!) : 'N/A';

                      return _buildCardCutoutUnit(
                        student: stu,
                        library: library,
                        logoImage: logoImage,
                        photoImage: null, // photos skipped in large bulk for high speed & memory safety
                        primaryColor: primaryColor,
                        validTo: validTo,
                        validFrom: validFrom,
                        seatText: seat,
                        secText: sec,
                        planName: plan,
                        settings: settings,
                        customFields: customFields,
                      );
                    }).toList(),
                  ),
                ),
              ],
            );
          },
        ),
      );
    }

    return pdf.save();
  }

  /// Builds a combined unit: [FRONT] + [FOLD LINE] + [BACK] with outer dotted cut guides & scissors
  static pw.Widget _buildCardCutoutUnit({
    required StudentModel student,
    required LibraryModel library,
    required pw.ImageProvider? logoImage,
    required pw.ImageProvider? photoImage,
    required PdfColor primaryColor,
    required String validTo,
    required String validFrom,
    required String seatText,
    required String secText,
    required String? planName,
    required IdCardTemplateSettings settings,
    List<Map<String, dynamic>> customFields = const [],
  }) {
    return pw.Container(
      margin: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Column(
        mainAxisSize: pw.MainAxisSize.min,
        children: [
          // Top cut guide indicator
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('✂ - - - - - - - - - - - - - - - - - - - - - - - - - -', style: const pw.TextStyle(fontSize: 6, color: PdfColors.grey500)),
              pw.Text('CUT & FOLD (ATM SIZE)', style: const pw.TextStyle(fontSize: 6, color: PdfColors.grey600)),
              pw.Text('- - - - - - - - - - - - - - - - - - - - - - - - - - ✂', style: const pw.TextStyle(fontSize: 6, color: PdfColors.grey500)),
            ],
          ),
          pw.SizedBox(height: 2),

          // Side-by-side card pair
          pw.Container(
            width: cardWidth * 2,
            height: cardHeight,
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey400, width: 0.5, style: pw.BorderStyle.dashed),
            ),
            child: pw.Row(
              children: [
                // FRONT
                pw.SizedBox(
                  width: cardWidth,
                  height: cardHeight,
                  child: _buildCardFront(
                    student: student,
                    library: library,
                    logoImage: logoImage,
                    photoImage: photoImage,
                    primaryColor: primaryColor,
                    validTo: validTo,
                    seatText: seatText,
                    secText: secText,
                    planName: planName,
                    settings: settings,
                    customFields: customFields,
                  ),
                ),

                // CENTER FOLD LINE
                pw.Container(
                  width: 0.8,
                  height: cardHeight,
                  color: PdfColors.grey400,
                  child: pw.Center(
                    child: pw.Container(
                      color: PdfColors.white,
                      padding: const pw.EdgeInsets.symmetric(vertical: 4),
                      child: pw.Text(
                        '| FOLD |',
                        style: const pw.TextStyle(fontSize: 4.5, color: PdfColors.grey600),
                      ),
                    ),
                  ),
                ),

                // BACK
                pw.SizedBox(
                  width: cardWidth,
                  height: cardHeight,
                  child: _buildCardBack(
                    student: student,
                    library: library,
                    primaryColor: primaryColor,
                    validFrom: validFrom,
                    seatText: seatText,
                    secText: secText,
                    settings: settings,
                  ),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 2),
          pw.Text('✂ - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - ✂', style: const pw.TextStyle(fontSize: 6, color: PdfColors.grey500)),
        ],
      ),
    );
  }

  /// Builds the FRONT side of the ID card
  static pw.Widget _buildCardFront({
    required StudentModel student,
    required LibraryModel library,
    required pw.ImageProvider? logoImage,
    required pw.ImageProvider? photoImage,
    required PdfColor primaryColor,
    required String validTo,
    required String seatText,
    required String secText,
    required String? planName,
    required IdCardTemplateSettings settings,
    List<Map<String, dynamic>> customFields = const [],
  }) {
    // Dynamic name font size to prevent ANY truncation
    final nameLen = student.name.length;
    final double nameFontSize = nameLen > 24 ? 7.5 : (nameLen > 16 ? 8.5 : 9.5);

    return pw.Container(
      width: cardWidth,
      height: cardHeight,
      color: PdfColors.white,
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          // Header Bar
          pw.Container(
            color: primaryColor,
            padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 3.5),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                if (logoImage != null) ...[
                  pw.Container(
                    width: 16,
                    height: 16,
                    decoration: pw.BoxDecoration(
                      color: PdfColors.white,
                      borderRadius: pw.BorderRadius.circular(8),
                    ),
                    child: pw.ClipOval(child: pw.Image(logoImage, fit: pw.BoxFit.cover)),
                  ),
                  pw.SizedBox(width: 4),
                ],
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    mainAxisSize: pw.MainAxisSize.min,
                    children: [
                      pw.Text(
                        library.name.toUpperCase(),
                        maxLines: 1,
                        style: pw.TextStyle(
                          color: PdfColors.white,
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 8.5,
                        ),
                      ),
                      pw.Text(
                        'STUDENT MEMBERSHIP CARD',
                        style: const pw.TextStyle(
                          color: PdfColors.white,
                          fontSize: 4.5,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 1.5),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.white,
                    borderRadius: pw.BorderRadius.circular(2),
                  ),
                  child: pw.Text(
                    'MEMBER',
                    style: pw.TextStyle(
                      color: primaryColor,
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 4.5,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Card Body
          pw.Expanded(
            child: pw.Padding(
              padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // Photo & ID
                  if (settings.showPhoto) ...[
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.center,
                      children: [
                        pw.Container(
                          width: 44,
                          height: 52,
                          decoration: pw.BoxDecoration(
                            color: PdfColors.grey200,
                            borderRadius: pw.BorderRadius.circular(3),
                            border: pw.Border.all(color: primaryColor, width: 0.8),
                          ),
                          child: photoImage != null
                              ? pw.ClipRRect(
                                  horizontalRadius: 2,
                                  verticalRadius: 2,
                                  child: pw.Image(photoImage, fit: pw.BoxFit.cover),
                                )
                              : pw.Center(
                                  child: pw.Text(
                                    student.name.isNotEmpty ? student.name[0].toUpperCase() : 'S',
                                    style: pw.TextStyle(
                                      fontSize: 18,
                                      fontWeight: pw.FontWeight.bold,
                                      color: primaryColor,
                                    ),
                                  ),
                                ),
                        ),
                        pw.SizedBox(height: 2),
                        pw.Text(
                          'ID: ${student.id.length > 8 ? student.id.substring(0, 8).toUpperCase() : student.id.toUpperCase()}',
                          style: pw.TextStyle(fontSize: 5, fontWeight: pw.FontWeight.bold, color: PdfColors.grey800),
                        ),
                      ],
                    ),
                    pw.SizedBox(width: 6),
                  ],

                  // Student Details
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        // Full Name with dynamic wrap
                        pw.Text(
                          student.name,
                          maxLines: 2,
                          style: pw.TextStyle(
                            fontSize: nameFontSize,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.grey900,
                          ),
                        ),
                        pw.SizedBox(height: 2),
                        _buildInfoRow('Phone', student.phone),
                        if (settings.showSeat) _buildInfoRow('Seat', '$seatText$secText'),
                        if (settings.showPlan && planName != null && planName.isNotEmpty)
                          _buildInfoRow('Plan', planName),
                        if (settings.showValidTill)
                          _buildInfoRow('Valid Till', validTo, isHighlight: true),
                        // Custom fields
                        if (customFields.isNotEmpty) ...[
                          for (final field in customFields) ...[
                            if (((student.customFields[field['id'] as String? ?? ''])?.toString() ?? '').isNotEmpty)
                              _buildInfoRow(
                                field['label'] as String? ?? (field['id'] as String? ?? ''),
                                student.customFields[field['id'] as String? ?? '']!.toString(),
                              ),
                          ],
                        ],
                      ],
                    ),
                  ),

                  // QR Code
                  if (settings.showQrCode) ...[
                    pw.SizedBox(width: 4),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.center,
                      mainAxisAlignment: pw.MainAxisAlignment.center,
                      children: [
                        pw.Container(
                          padding: const pw.EdgeInsets.all(1.5),
                          decoration: pw.BoxDecoration(
                            border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
                            borderRadius: pw.BorderRadius.circular(2),
                          ),
                          child: pw.BarcodeWidget(
                            barcode: pw.Barcode.qrCode(),
                            data: '${student.id}||${library.id}',
                            width: 38,
                            height: 38,
                          ),
                        ),
                        pw.SizedBox(height: 1.5),
                        pw.Text('SCAN TO VERIFY', style: const pw.TextStyle(fontSize: 3.5, color: PdfColors.grey600)),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),

          // Footer
          if (settings.showAddress || settings.showHelpline)
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              color: PdfColors.grey100,
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  if (settings.showAddress)
                    pw.Expanded(
                      child: pw.Text(
                        library.address,
                        maxLines: 1,
                        style: const pw.TextStyle(fontSize: 4.5, color: PdfColors.grey700),
                      ),
                    ),
                  if (settings.showHelpline && library.contact.isNotEmpty) ...[
                    pw.SizedBox(width: 4),
                    pw.Text(
                      'Helpline: ${library.contact}',
                      style: const pw.TextStyle(fontSize: 4.5, color: PdfColors.grey700),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// Builds the BACK side of the ID card
  static pw.Widget _buildCardBack({
    required StudentModel student,
    required LibraryModel library,
    required PdfColor primaryColor,
    required String validFrom,
    required String seatText,
    required String secText,
    required IdCardTemplateSettings settings,
  }) {
    return pw.Container(
      width: cardWidth,
      height: cardHeight,
      color: PdfColors.white,
      padding: const pw.EdgeInsets.all(6),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          // Header
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'TERMS & GUIDELINES',
                style: pw.TextStyle(color: primaryColor, fontWeight: pw.FontWeight.bold, fontSize: 7),
              ),
              pw.Text('Issued: $validFrom', style: const pw.TextStyle(fontSize: 4.5, color: PdfColors.grey600)),
            ],
          ),
          pw.Divider(thickness: 0.5, color: primaryColor, height: 4),

          // Father name & Blood group row
          if (settings.showFatherName && student.fatherName.isNotEmpty)
            _buildRuleLine('• Guardian: ${student.fatherName}'),

          // Rules
          if (settings.showRules) ...[
            if (settings.customRulesText.isNotEmpty)
              ...settings.customRulesText.split('\n').where((l) => l.trim().isNotEmpty).map((l) => _buildRuleLine('• $l'))
            else ...[
              _buildRuleLine('• Non-transferable; must be produced upon entry.'),
              _buildRuleLine('• Maintain complete silence inside study zones.'),
              _buildRuleLine('• Assigned Seat: $seatText$secText only.'),
              _buildRuleLine('• Loss of card must be reported immediately.'),
            ],
          ],

          pw.Spacer(),

          // Emergency Contact Badge
          if (settings.showEmergencyContact && student.emergencyContact.isNotEmpty)
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              decoration: pw.BoxDecoration(
                color: PdfColors.amber50,
                borderRadius: pw.BorderRadius.circular(2),
                border: pw.Border.all(color: PdfColors.amber300, width: 0.5),
              ),
              child: pw.Row(
                children: [
                  pw.Text('EMERGENCY: ', style: pw.TextStyle(fontSize: 4.5, fontWeight: pw.FontWeight.bold, color: PdfColors.amber900)),
                  pw.Text(student.emergencyContact, style: const pw.TextStyle(fontSize: 4.5, color: PdfColors.amber900)),
                ],
              ),
            ),
          pw.SizedBox(height: 3),

          // Signature & Stamp
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Authorized Signature & Stamp', style: const pw.TextStyle(fontSize: 4.5, color: PdfColors.grey600)),
              pw.Container(width: 55, height: 0.8, color: PdfColors.grey500),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildInfoRow(String label, String value, {bool isHighlight = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 1.5),
      child: pw.Row(
        children: [
          pw.SizedBox(
            width: 34,
            child: pw.Text(
              '$label:',
              style: const pw.TextStyle(fontSize: 5, color: PdfColors.grey700),
            ),
          ),
          pw.Expanded(
            child: pw.Text(
              value,
              maxLines: 1,
              style: pw.TextStyle(
                fontSize: 5.5,
                fontWeight: isHighlight ? pw.FontWeight.bold : pw.FontWeight.normal,
                color: isHighlight ? PdfColors.red800 : PdfColors.black,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildRuleLine(String rule) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 1.5),
      child: pw.Text(
        rule,
        maxLines: 1,
        style: const pw.TextStyle(fontSize: 4.5, color: PdfColors.grey800),
      ),
    );
  }
}
