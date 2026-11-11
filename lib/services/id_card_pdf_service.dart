import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:study_library/models/library_model.dart';
import 'package:study_library/models/student_model.dart';
import 'package:study_library/models/id_card_template_model.dart';
import 'package:study_library/services/image_transparency_service.dart';
import 'package:study_library/services/pdf_font_service.dart';
import 'package:study_library/core/utils/seat_helper.dart';

enum IdCardPrintFormat {
  a4CutAndFold, // Single A4 sheet with Front and Back side-by-side with cut & fold guides (Default)
  cr80Direct,   // 2 separate pages sized exactly for CR80 card printers (Evolis/Zebra)
  a4DuplexSheet, // 2 pages on A4 centered for 2-sided automatic duplex printing
}

class IdCardPdfService {
  // Standard CR80 dimensions in points (72 points per inch)
  // 85.6mm = 242.6 pt, 53.98mm = 153.0 pt
  static const double cardWidth = 242.6;
  static const double cardHeight = 153.0;

  static pw.Font? _cachedFont;
  static final Map<String, pw.ImageProvider> _imageCache = {};
  static final Map<String, List<Map<String, dynamic>>> _customFieldsCache = {};

  /// Load Unicode font to ensure Indian symbols, names, and punctuation render perfectly
  static Future<pw.Font> _loadFont() async {
    if (_cachedFont != null) return _cachedFont!;
    try {
      final fontData = await rootBundle.load('assets/fonts/NotoSans-Regular.ttf');
      _cachedFont = pw.Font.ttf(fontData);
      return _cachedFont!;
    } catch (_) {
      return pw.Font.helvetica();
    }
  }

  /// Strip emojis and unsupported glyphs that NotoSans cannot render in PDF
  static String sanitizeText(String text) {
    if (text.isEmpty) return '';
    return text
        .replaceAll(
          RegExp(
            r'[\u{1F600}-\u{1F64F}\u{1F300}-\u{1F5FF}\u{1F680}-\u{1F6FF}\u{1F700}-\u{1F77F}\u{1F780}-\u{1F7FF}\u{1F800}-\u{1F8FF}\u{1F900}-\u{1F9FF}\u{1FA00}-\u{1FA6F}\u{1FA70}-\u{1FAFF}\u{2600}-\u{26FF}\u{2700}-\u{27BF}]',
            unicode: true,
          ),
          '',
        )
        .replaceAll(RegExp(r'\s{2,}'), ' ')
        .trim();
  }

  /// Safely fetch and make transparent images (logos & rubber stamps)
  static Future<pw.ImageProvider?> _loadTransparentImage(
    String url, {
    int threshold = 225,
  }) async {
    if (url.isEmpty) return null;
    if (_imageCache.containsKey(url)) return _imageCache[url];
    try {
      Uint8List? rawBytes;
      if (url.startsWith('data:image')) {
        final b64 = url.contains(',') ? url.split(',')[1] : url;
        rawBytes = base64Decode(b64);
      } else {
        try {
          final bundle = NetworkAssetBundle(Uri.parse(url));
          final data = await bundle.load('');
          rawBytes = data.buffer.asUint8List();
        } catch (_) {
          final netImg = await networkImage(url);
          _imageCache[url] = netImg;
          return netImg;
        }
      }

      final cleanBytes = ImageTransparencyService.removeWhiteBackground(
        rawBytes,
        threshold: threshold,
      );
      final memImg = pw.MemoryImage(cleanBytes);
      _imageCache[url] = memImg;
      return memImg;
    } catch (e) {
      if (kDebugMode) debugPrint('Could not load transparent image for ID card: $e');
    }
    return null;
  }

  /// Capitalizes words cleanly (e.g. "latur" -> "Latur", "pharmasist" -> "Pharmacist")
  static String formatCapitalized(String text) {
    if (text.isEmpty) return '';
    return text.trim().split(RegExp(r'\s+')).map((word) {
      if (word.isEmpty) return '';
      String prefix = '';
      String core = word;
      String suffix = '';
      if (core.startsWith('(')) {
        prefix = '(';
        core = core.substring(1);
      }
      if (core.endsWith(')')) {
        suffix = ')';
        core = core.substring(0, core.length - 1);
      }
      if (core.isEmpty) return '$prefix$suffix';
      final cap = core[0].toUpperCase() + (core.length > 1 ? core.substring(1).toLowerCase() : '');
      return '$prefix$cap$suffix';
    }).join(' ');
  }

  /// Returns theme color palette based on theme choice (supports presets and custom hex)
  static Map<String, PdfColor> getThemeColors(String themeName, int libraryAccent) {
    if (themeName.startsWith('#') || RegExp(r'^[0-9a-fA-F]{6}$').hasMatch(themeName)) {
      final hex = themeName.startsWith('#') ? themeName : '#$themeName';
      final base = PdfColor.fromHex(hex);
      return {
        'primary': base,
        'secondary': base,
        'accentLight': PdfColor.fromHex('#F8FAFC'),
      };
    }

    switch (themeName) {
      case 'royalNavy':
        return {
          'primary': PdfColor.fromHex('#1E3A8A'), // Deep Navy
          'secondary': PdfColor.fromHex('#0284C7'), // Bright Blue
          'accentLight': PdfColor.fromHex('#EFF6FF'), // Ice Blue
        };
      case 'emeraldAcademic':
        return {
          'primary': PdfColor.fromHex('#065F46'), // Forest Emerald
          'secondary': PdfColor.fromHex('#059669'), // Green
          'accentLight': PdfColor.fromHex('#ECFDF5'), // Pale Mint
        };
      case 'crimsonExecutive':
        return {
          'primary': PdfColor.fromHex('#881337'), // Deep Crimson
          'secondary': PdfColor.fromHex('#BE123C'), // Ruby
          'accentLight': PdfColor.fromHex('#FFF1F2'), // Pale Rose
        };
      case 'darkSlate':
        return {
          'primary': PdfColor.fromHex('#1E293B'), // Slate 800
          'secondary': PdfColor.fromHex('#475569'), // Slate 600
          'accentLight': PdfColor.fromHex('#F8FAFC'), // Slate 50
        };
      case 'amberClassic':
        return {
          'primary': PdfColor.fromHex('#78350F'), // Rich Leather Amber
          'secondary': PdfColor.fromHex('#B45309'), // Warm Amber Gold
          'accentLight': PdfColor.fromHex('#FFFBEB'), // Warm Cream
        };
      case 'amethystPurple':
        return {
          'primary': PdfColor.fromHex('#4C1D95'), // Deep Purple
          'secondary': PdfColor.fromHex('#7C3AED'), // Bright Violet
          'accentLight': PdfColor.fromHex('#F5F3FF'), // Pale Violet
        };
      case 'customBrand':
      default:
        final libColor = libraryAccent != 0 ? PdfColor.fromInt(libraryAccent) : PdfColor.fromHex('#1E3A8A');
        return {
          'primary': libColor,
          'secondary': PdfColor.fromHex('#0284C7'), // Accent Blue
          'accentLight': PdfColor.fromHex('#F8FAFC'), // Crisp Light
        };
    }
  }

  /// Returns 2-stop linear gradient for ultra-modern luxury card background
  static List<PdfColor> getThemeGradientColors(String themeName, int libraryAccent) {
    if (themeName.startsWith('#') || RegExp(r'^[0-9a-fA-F]{6}$').hasMatch(themeName)) {
      try {
        final hex = themeName.startsWith('#') ? themeName : '#$themeName';
        final base = PdfColor.fromHex(hex);
        return [base, const PdfColor.fromInt(0xFF0F172A)];
      } catch (_) {}
    }

    switch (themeName) {
      case 'royalNavy':
        return [const PdfColor.fromInt(0xFF1E3A8A), const PdfColor.fromInt(0xFF0F172A)];
      case 'emeraldAcademic':
        return [const PdfColor.fromInt(0xFF065F46), const PdfColor.fromInt(0xFF022C22)];
      case 'darkSlate':
        return [const PdfColor.fromInt(0xFF1E293B), const PdfColor.fromInt(0xFF0F172A)];
      case 'amberClassic':
        return [const PdfColor.fromInt(0xFF78350F), const PdfColor.fromInt(0xFF451A03)];
      case 'amethystPurple':
        return [const PdfColor.fromInt(0xFF4C1D95), const PdfColor.fromInt(0xFF1E1B4B)];
      case 'customBrand':
        final c = libraryAccent != 0 ? PdfColor.fromInt(libraryAccent) : const PdfColor.fromInt(0xFF1E3A8A);
        return [c, const PdfColor.fromInt(0xFF0F172A)];
      case 'crimsonExecutive':
      default:
        return [const PdfColor.fromInt(0xFF881337), const PdfColor.fromInt(0xFF4C0519)];
    }
  }

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

  /// Generates a student ID card PDF with smart layout, high DPI, and zero broken symbols.
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
    final notoSans = await _loadFont();
    final pageTheme = await PdfFontService.getUniversalTheme(base: notoSans);
    final dateFormat = DateFormat('dd MMM yyyy');

    // Load custom fields configured for ID card display (cached)
    List<Map<String, dynamic>> customFields = _customFieldsCache[library.id] ?? [];
    if (customFields.isEmpty) {
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
          _customFieldsCache[library.id] = customFields;
        }
      } catch (_) { /* intentionally silent */ }
    }

    // Fetch images asynchronously (with in-memory cache for instant theme rendering)
    pw.ImageProvider? photoImage;
    if (student.photoUrl.isNotEmpty && settings.showPhoto) {
      if (_imageCache.containsKey(student.photoUrl)) {
        photoImage = _imageCache[student.photoUrl];
      } else {
        try {
          if (student.photoUrl.startsWith('data:image')) {
            final b64 = student.photoUrl.contains(',') ? student.photoUrl.split(',')[1] : student.photoUrl;
            photoImage = pw.MemoryImage(base64Decode(b64));
          } else {
            photoImage = await networkImage(student.photoUrl);
          }
          _imageCache[student.photoUrl] = photoImage;
        } catch (e) {
          if (kDebugMode) debugPrint('Could not load student photo for ID card: $e');
        }
      }
    }

    pw.ImageProvider? logoImage;
    if (library.logoUrl.isNotEmpty) {
      logoImage = await _loadTransparentImage(library.logoUrl, threshold: 240);
    }

    pw.ImageProvider? stampImage;
    try {
      final receiptDoc = await FirebaseFirestore.instance
          .collection('libraries').doc(library.id)
          .collection('settings').doc('receipt_template').get();
      if (receiptDoc.exists) {
        final stampUrl = receiptDoc.data()?['stampUrl'] as String?;
        final stampEnabled = receiptDoc.data()?['stampEnabled'] as bool? ?? (stampUrl != null && stampUrl.isNotEmpty);
        if (stampEnabled && stampUrl != null && stampUrl.isNotEmpty) {
          stampImage = await _loadTransparentImage(stampUrl, threshold: 220);
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Could not load stamp for ID card: $e');
    }

    final effectiveTheme = (settings.customColorHex != null && settings.customColorHex!.isNotEmpty)
        ? settings.customColorHex!
        : settings.cardTheme;
    final colors = getThemeColors(effectiveTheme, library.accentColor);
    final gradientColors = getThemeGradientColors(effectiveTheme, library.accentColor);
    final primaryColor = colors['primary']!;
    final secondaryColor = colors['secondary']!;
    final accentLight = colors['accentLight']!;

    final validTo = student.planEndDate != null ? dateFormat.format(student.planEndDate!) : 'N/A';
    final validFrom = student.planStartDate != null ? dateFormat.format(student.planStartDate!) : dateFormat.format(student.effectiveAdmissionDate);

    final seatText = SeatHelper.formatSeatLabel(
      seatId: student.seatId,
      rawLabel: seatLabel,
      includePrefix: false,
    );

    final secText = (sectionName != null && sectionName.isNotEmpty) ? ' ($sectionName)' : '';

    if (format == IdCardPrintFormat.a4CutAndFold) {
      // ── SINGLE PAGE A4 WITH SMART CUTOUTS (CR-80 / ATM SIZE) ─────────────
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          theme: pageTheme,
          margin: const pw.EdgeInsets.symmetric(horizontal: 24, vertical: 28),
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                // Top Header / Print Guide (Clean vector text, NO broken emojis)
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 7),
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
                            'OFFICIAL STUDENT ID CARD - CR-80 STANDARD (85.6 mm x 54.0 mm)',
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8.5, color: PdfColors.grey800),
                          ),
                          pw.SizedBox(height: 2),
                          pw.Text(
                            '1. Cut along outer dashed line   2. Fold along center line   3. Insert into standard card pouch or laminate',
                            style: const pw.TextStyle(fontSize: 6.5, color: PdfColors.grey600),
                          ),
                        ],
                      ),
                      pw.Text(
                        sanitizeText(library.name).toUpperCase(),
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8, color: primaryColor),
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 24),

                // Cut & Fold Card Unit
                _buildCardCutoutUnit(
                  student: student,
                  library: library,
                  logoImage: logoImage,
                  stampImage: stampImage,
                  photoImage: photoImage,
                  gradientColors: gradientColors,
                  primaryColor: primaryColor,
                  secondaryColor: secondaryColor,
                  accentLight: accentLight,
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
                  'Generated via ${sanitizeText(library.name).isNotEmpty ? sanitizeText(library.name) : "Study Library"} | High Resolution 300 DPI Vector Output',
                  style: const pw.TextStyle(fontSize: 6.5, color: PdfColors.grey500),
                ),
              ],
            );
          },
        ),
      );
    } else if (format == IdCardPrintFormat.a4DuplexSheet) {
      // ── A4 DUPLEX (2-SIDED OFFICE PRINTER) FORMAT ──
      // Page 1: Centered Front
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          theme: pageTheme,
          margin: const pw.EdgeInsets.all(32),
          build: (context) => pw.Center(
            child: pw.Container(
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey300, width: 0.5, style: pw.BorderStyle.dashed),
              ),
              child: _buildCardFront(
                student: student,
                library: library,
                logoImage: logoImage,
                photoImage: photoImage,
                gradientColors: gradientColors,
                primaryColor: primaryColor,
                validTo: validTo,
                seatText: seatText,
                secText: secText,
                planName: planName,
                settings: settings,
                customFields: customFields,
              ),
            ),
          ),
        ),
      );

      // Page 2: Centered Back (Identical page coordinates for duplex alignment)
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          theme: pageTheme,
          margin: const pw.EdgeInsets.all(32),
          build: (context) => pw.Center(
            child: pw.Container(
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey300, width: 0.5, style: pw.BorderStyle.dashed),
              ),
              child: _buildCardBack(
                student: student,
                library: library,
                logoImage: logoImage,
                stampImage: stampImage,
                primaryColor: primaryColor,
                validFrom: validFrom,
                seatText: seatText,
                secText: secText,
                settings: settings,
              ),
            ),
          ),
        ),
      );
    } else {
      // ── DIRECT CR80 CARD PRINTER FORMAT (PAGE 1 FRONT, PAGE 2 BACK) ──────
      pdf.addPage(
        pw.Page(
          pageFormat: const PdfPageFormat(cardWidth, cardHeight, marginAll: 0),
          theme: pageTheme,
          build: (context) => _buildCardFront(
            student: student,
            library: library,
            logoImage: logoImage,
            photoImage: photoImage,
            gradientColors: gradientColors,
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
          theme: pageTheme,
          build: (context) => _buildCardBack(
            student: student,
            library: library,
            logoImage: logoImage,
            stampImage: stampImage,
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

  /// Bulk Student ID Card Generator
  static Future<Uint8List> generateBulkIdCards({
    required List<StudentModel> students,
    required LibraryModel library,
    Map<String, String>? studentSeats,
    Map<String, String>? studentSections,
    Map<String, String>? studentPlans,
    IdCardTemplateSettings settings = const IdCardTemplateSettings(),
  }) async {
    final pdf = pw.Document();
    final notoSans = await _loadFont();
    final pageTheme = await PdfFontService.getUniversalTheme(base: notoSans);
    final dateFormat = DateFormat('dd MMM yyyy');

    final effectiveTheme = (settings.customColorHex != null && settings.customColorHex!.isNotEmpty)
        ? settings.customColorHex!
        : settings.cardTheme;
    final colors = getThemeColors(effectiveTheme, library.accentColor);
    final gradientColors = getThemeGradientColors(effectiveTheme, library.accentColor);
    final primaryColor = colors['primary']!;
    final secondaryColor = colors['secondary']!;
    final accentLight = colors['accentLight']!;

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
    } catch (_) { /* intentionally silent */ }

    pw.ImageProvider? logoImage;
    if (library.logoUrl.isNotEmpty) {
      logoImage = await _loadTransparentImage(library.logoUrl, threshold: 240);
    }

    pw.ImageProvider? stampImage;
    try {
      final receiptDoc = await FirebaseFirestore.instance
          .collection('libraries').doc(library.id)
          .collection('settings').doc('receipt_template').get();
      if (receiptDoc.exists) {
        final stampUrl = receiptDoc.data()?['stampUrl'] as String?;
        final stampEnabled = receiptDoc.data()?['stampEnabled'] as bool? ?? (stampUrl != null && stampUrl.isNotEmpty);
        if (stampEnabled && stampUrl != null && stampUrl.isNotEmpty) {
          stampImage = await _loadTransparentImage(stampUrl, threshold: 220);
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Could not load stamp for batch ID cards: $e');
    }

    const int perPage = 4;
    final Map<String, pw.ImageProvider?> studentPhotos = {};
    if (settings.showPhoto) {
      for (final s in students) {
        if (s.photoUrl.isNotEmpty) {
          if (_imageCache.containsKey(s.photoUrl)) {
            studentPhotos[s.id] = _imageCache[s.photoUrl];
          } else {
            try {
              pw.ImageProvider? pImg;
              if (s.photoUrl.startsWith('data:image')) {
                final b64 = s.photoUrl.contains(',') ? s.photoUrl.split(',')[1] : s.photoUrl;
                pImg = pw.MemoryImage(base64Decode(b64));
              } else {
                pImg = await networkImage(s.photoUrl);
              }
              _imageCache[s.photoUrl] = pImg;
              studentPhotos[s.id] = pImg;
            } catch (e) {
              if (kDebugMode) debugPrint('Could not load student photo for batch ID card: $e');
            }
          }
        }
      }
    }

    for (int i = 0; i < students.length; i += perPage) {
      final pageStudents = students.skip(i).take(perPage).toList();

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          theme: pageTheme,
          margin: const pw.EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      '${library.name.toUpperCase()} - BATCH STUDENT ID CARDS',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8, color: primaryColor),
                    ),
                    pw.Text(
                      'Page ${(i ~/ perPage) + 1} of ${((students.length - 1) ~/ perPage) + 1} | 4 Cards / Page',
                      style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600),
                    ),
                  ],
                ),
                pw.SizedBox(height: 12),
                pw.Expanded(
                  child: pw.Column(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly,
                    children: pageStudents.map((stu) {
                      final seat = SeatHelper.formatSeatLabel(
                        seatId: stu.seatId,
                        rawLabel: studentSeats?[stu.id],
                        includePrefix: false,
                      );
                      final sec = studentSections?[stu.id] != null ? ' (${studentSections![stu.id]})' : '';
                      final plan = studentPlans?[stu.id];
                      final validTo = stu.planEndDate != null ? dateFormat.format(stu.planEndDate!) : 'N/A';
                      final validFrom = stu.planStartDate != null ? dateFormat.format(stu.planStartDate!) : dateFormat.format(stu.effectiveAdmissionDate);

                      return _buildCardCutoutUnit(
                        student: stu,
                        library: library,
                        logoImage: logoImage,
                        stampImage: stampImage,
                        photoImage: studentPhotos[stu.id],
                        gradientColors: gradientColors,
                        primaryColor: primaryColor,
                        secondaryColor: secondaryColor,
                        accentLight: accentLight,
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

  /// Builds a combined unit: [FRONT] + [FOLD LINE] + [BACK] with outer dotted cut guides
  static pw.Widget _buildCardCutoutUnit({
    required StudentModel student,
    required LibraryModel library,
    required pw.ImageProvider? logoImage,
    pw.ImageProvider? stampImage,
    required pw.ImageProvider? photoImage,
    required List<PdfColor> gradientColors,
    required PdfColor primaryColor,
    required PdfColor secondaryColor,
    required PdfColor accentLight,
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
          // Top cut guide indicator (NO broken emoji)
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -', style: const pw.TextStyle(fontSize: 6, color: PdfColors.grey400)),
              pw.Text('[ CUT & FOLD - CR-80 STANDARD (85.6 mm x 54.0 mm) ]', style: pw.TextStyle(fontSize: 5.5, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700)),
              pw.Text('- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -', style: const pw.TextStyle(fontSize: 6, color: PdfColors.grey400)),
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
                    gradientColors: gradientColors,
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
                    logoImage: logoImage,
                    stampImage: stampImage,
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
          pw.Text('- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -', style: const pw.TextStyle(fontSize: 5.5, color: PdfColors.grey400)),
        ],
      ),
    );
  }

  /// Builds the FRONT side of the ID card (Standard CR-80 physical print format)
  static pw.Widget _buildCardFront({
    required StudentModel student,
    required LibraryModel library,
    required pw.ImageProvider? logoImage,
    required pw.ImageProvider? photoImage,
    required List<PdfColor> gradientColors,
    required String validTo,
    required String seatText,
    required String secText,
    required String? planName,
    required IdCardTemplateSettings settings,
    List<Map<String, dynamic>> customFields = const [],
    PdfColor? primaryColor,
  }) {
    final effectivePrimary = primaryColor ?? (gradientColors.isNotEmpty ? gradientColors.first : const PdfColor.fromInt(0xFF1E3A8A));
    final formattedName = formatCapitalized(student.name);
    final nameLen = formattedName.length;
    final double nameFontSize = nameLen > 24 ? 6.8 : (nameLen > 16 ? 7.5 : 8.2);
    final idNumber = student.membershipNumber?.isNotEmpty == true
        ? student.membershipNumber!
        : (student.id.length > 8 ? student.id.substring(0, 8).toUpperCase() : student.id.toUpperCase());

    return pw.Container(
      width: cardWidth,
      height: cardHeight,
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        borderRadius: pw.BorderRadius.circular(4),
        border: pw.Border.all(color: PdfColors.grey400, width: 0.5),
      ),
      child: pw.ClipRRect(
        horizontalRadius: 4,
        verticalRadius: 4,
        child: pw.Stack(
          children: [
            // 1. Watermark: Transparent Saraswati Logo Centered in Card Body (No white background box)
            if (logoImage != null)
              pw.Positioned.fill(
                child: pw.Center(
                  child: pw.Opacity(
                    opacity: 0.14,
                    child: pw.Image(
                      logoImage,
                      width: 88,
                      height: 88,
                      fit: pw.BoxFit.contain,
                    ),
                  ),
                ),
              ),

            // 2. Entire Front Card Layout
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                // Top Header Bar
                pw.Container(
                  color: effectivePrimary,
                  padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 3.5),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Row(
                        children: [
                          // White circular logo badge
                          pw.Container(
                            width: 17,
                            height: 17,
                            decoration: const pw.BoxDecoration(
                              color: PdfColors.white,
                              shape: pw.BoxShape.circle,
                            ),
                            padding: const pw.EdgeInsets.all(1),
                            child: logoImage != null
                                ? pw.ClipOval(child: pw.Image(logoImage, fit: pw.BoxFit.cover))
                                : pw.Center(
                                    child: pw.Text(
                                      library.name.isNotEmpty ? library.name[0].toUpperCase() : 'C',
                                      style: pw.TextStyle(color: effectivePrimary, fontSize: 8, fontWeight: pw.FontWeight.bold),
                                    ),
                                  ),
                          ),
                          pw.SizedBox(width: 4.5),
                          pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text(
                                library.name.toUpperCase(),
                                maxLines: 1,
                                style: pw.TextStyle(
                                  color: PdfColors.white,
                                  fontWeight: pw.FontWeight.bold,
                                  fontSize: 6.8,
                                  letterSpacing: 0.3,
                                ),
                              ),
                              pw.Text(
                                'STUDENT SMART ACCESS CARD',
                                maxLines: 1,
                                style: const pw.TextStyle(
                                  color: PdfColors.white,
                                  fontSize: 4.2,
                                  letterSpacing: 0.2,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      // Member Badge Pill
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                        decoration: pw.BoxDecoration(
                          color: const PdfColor.fromInt(0xFF0284C7),
                          borderRadius: pw.BorderRadius.circular(6),
                        ),
                        child: pw.Text(
                          'MEMBER',
                          style: pw.TextStyle(
                            color: PdfColors.white,
                            fontSize: 4.5,
                            fontWeight: pw.FontWeight.bold,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Card Body
                pw.Expanded(
                  child: pw.Padding(
                    padding: const pw.EdgeInsets.fromLTRB(6, 4, 6, 2),
                    child: pw.Row(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        // Left: Photo + Verified
                        pw.Column(
                          children: [
                            pw.Container(
                              width: 44,
                              height: 52,
                              decoration: pw.BoxDecoration(
                                color: PdfColors.grey100,
                                borderRadius: pw.BorderRadius.circular(3),
                                border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
                              ),
                              child: photoImage != null
                                  ? pw.ClipRRect(
                                      horizontalRadius: 2.5,
                                      verticalRadius: 2.5,
                                      child: pw.Image(photoImage, fit: pw.BoxFit.cover),
                                    )
                                  : pw.Center(
                                      child: pw.Text(
                                        student.name.isNotEmpty ? student.name[0].toUpperCase() : 'S',
                                        style: pw.TextStyle(color: PdfColors.grey500, fontSize: 18, fontWeight: pw.FontWeight.bold),
                                      ),
                                    ),
                            ),
                            pw.SizedBox(height: 1.5),
                            pw.Container(
                              padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 0.6),
                              decoration: pw.BoxDecoration(
                                color: const PdfColor.fromInt(0xFFECFDF5),
                                borderRadius: pw.BorderRadius.circular(2),
                                border: pw.Border.all(color: const PdfColor.fromInt(0xFF059669), width: 0.4),
                              ),
                              child: pw.Text(
                                'VERIFIED',
                                style: pw.TextStyle(
                                  color: const PdfColor.fromInt(0xFF047857),
                                  fontSize: 3.5,
                                  fontWeight: pw.FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        pw.SizedBox(width: 5),

                        // Middle: Details
                        pw.Expanded(
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                            children: [
                              pw.Column(
                                crossAxisAlignment: pw.CrossAxisAlignment.start,
                                children: [
                                  // Name
                                  pw.Text(
                                    formattedName,
                                    maxLines: 2,
                                    style: pw.TextStyle(
                                      color: PdfColors.black,
                                      fontWeight: pw.FontWeight.bold,
                                      fontSize: nameFontSize,
                                    ),
                                  ),
                                  pw.SizedBox(height: 1),
                                  // ID Pill
                                  pw.Container(
                                    padding: const pw.EdgeInsets.symmetric(horizontal: 3.5, vertical: 0.8),
                                    decoration: pw.BoxDecoration(
                                      color: effectivePrimary,
                                      borderRadius: pw.BorderRadius.circular(2),
                                    ),
                                    child: pw.Text(
                                      'ID: $idNumber',
                                      style: pw.TextStyle(
                                        color: PdfColors.white,
                                        fontWeight: pw.FontWeight.bold,
                                        fontSize: 4.8,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              pw.SizedBox(height: 1.5),

                              // Info list
                              pw.Column(
                                crossAxisAlignment: pw.CrossAxisAlignment.start,
                                children: [
                                  if (student.fatherName.isNotEmpty)
                                    _buildCleanInfoRow('Guardian:', student.fatherName),
                                  if (student.phone.isNotEmpty)
                                    _buildCleanInfoRow('Phone:', student.phone),
                                  if (student.college.isNotEmpty)
                                    _buildCleanInfoRow('College:', student.college),
                                  if (student.course.isNotEmpty)
                                    _buildCleanInfoRow('Course:', student.course),
                                ],
                              ),
                              pw.SizedBox(height: 2),

                              // Bottom badges (Seat & Validity)
                              pw.Row(
                                children: [
                                  pw.Container(
                                    padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 0.8),
                                    decoration: pw.BoxDecoration(
                                      color: PdfColors.white,
                                      borderRadius: pw.BorderRadius.circular(2),
                                      border: pw.Border.all(color: const PdfColor.fromInt(0xFF2563EB), width: 0.4),
                                    ),
                                    child: pw.Text(
                                      'SEAT: $seatText$secText | Monthly',
                                      style: pw.TextStyle(
                                        color: const PdfColor.fromInt(0xFF1D4ED8),
                                        fontSize: 4.2,
                                        fontWeight: pw.FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  pw.SizedBox(width: 3),
                                  pw.Container(
                                    padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 0.8),
                                    decoration: pw.BoxDecoration(
                                      color: PdfColors.white,
                                      borderRadius: pw.BorderRadius.circular(2),
                                      border: pw.Border.all(color: const PdfColor.fromInt(0xFFD97706), width: 0.4),
                                    ),
                                    child: pw.Text(
                                      'VALID TILL: $validTo',
                                      style: pw.TextStyle(
                                        color: const PdfColor.fromInt(0xFFB45309),
                                        fontSize: 4.2,
                                        fontWeight: pw.FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        pw.SizedBox(width: 4),

                        // Right: QR Code + Scan to Verify
                        pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.center,
                          children: [
                            pw.SizedBox(height: 6),
                            pw.Container(
                              padding: const pw.EdgeInsets.all(1.5),
                              decoration: pw.BoxDecoration(
                                color: PdfColors.white,
                                borderRadius: pw.BorderRadius.circular(2),
                                border: pw.Border.all(color: PdfColors.grey300, width: 0.4),
                              ),
                              child: pw.BarcodeWidget(
                                barcode: pw.Barcode.qrCode(),
                                data: 'STUDENT:${student.id}:${library.id}',
                                width: 34,
                                height: 34,
                              ),
                            ),
                            pw.SizedBox(height: 2),
                            pw.Text(
                              'SCAN TO VERIFY',
                              style: pw.TextStyle(
                                fontSize: 3.5,
                                fontWeight: pw.FontWeight.bold,
                                color: PdfColors.grey600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                // Footer Bar
                pw.Container(
                  color: const PdfColor.fromInt(0xFFF8FAFC),
                  padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2.2),
                  decoration: const pw.BoxDecoration(
                    border: pw.Border(top: pw.BorderSide(color: PdfColors.grey300, width: 0.4)),
                  ),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Expanded(
                        child: pw.Text(
                          library.address.isNotEmpty ? sanitizeText(library.address) : 'Study Centre Locality & Address',
                          maxLines: 1,
                          style: const pw.TextStyle(fontSize: 4.2, color: PdfColors.grey700),
                        ),
                      ),
                      pw.SizedBox(width: 4),
                      pw.Text(
                        'Helpline: ${library.contact.isNotEmpty ? library.contact : library.helplineNumber}',
                        style: pw.TextStyle(fontSize: 4.2, fontWeight: pw.FontWeight.bold, color: PdfColors.grey900),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Builds the BACK side of the ID card (Standard CR-80 physical print format)
  static pw.Widget _buildCardBack({
    required StudentModel student,
    required LibraryModel library,
    pw.ImageProvider? logoImage,
    pw.ImageProvider? stampImage,
    required String validFrom,
    required String seatText,
    required String secText,
    required IdCardTemplateSettings settings,
    PdfColor? primaryColor,
  }) {
    final effectivePrimary = primaryColor ?? PdfColor.fromInt(library.accentColor != 0 ? library.accentColor : 0xFF1E3A8A);
    final effectiveReception = library.contact.isNotEmpty
        ? library.contact
        : library.helplineNumber;

    return pw.Container(
      width: cardWidth,
      height: cardHeight,
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        borderRadius: pw.BorderRadius.circular(4),
        border: pw.Border.all(color: PdfColors.grey400, width: 0.5),
      ),
      child: pw.ClipRRect(
        horizontalRadius: 4,
        verticalRadius: 4,
        child: pw.Stack(
          children: [
            // 1. Watermark: Transparent Saraswati Logo Centered in Body (No white background box)
            if (logoImage != null)
              pw.Positioned.fill(
                child: pw.Center(
                  child: pw.Opacity(
                    opacity: 0.12,
                    child: pw.Image(
                      logoImage,
                      width: 88,
                      height: 88,
                      fit: pw.BoxFit.contain,
                    ),
                  ),
                ),
              ),

            // 2. Back Card Content
            pw.Padding(
              padding: const pw.EdgeInsets.fromLTRB(6, 4, 6, 4),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  // Top Header
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                    children: [
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text(
                            'TERMS OF ACCESS & CONDUCT',
                            style: pw.TextStyle(
                              color: effectivePrimary,
                              fontWeight: pw.FontWeight.bold,
                              fontSize: 6.2,
                              letterSpacing: 0.3,
                            ),
                          ),
                          pw.Text(
                            'Issued: $validFrom',
                            style: const pw.TextStyle(fontSize: 4.5, color: PdfColors.grey600),
                          ),
                        ],
                      ),
                      pw.SizedBox(height: 1.5),
                      pw.Container(height: 1.2, color: effectivePrimary),
                    ],
                  ),

                  // Bullet Rules
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      _buildCleanRuleLine('• Card is non-transferable; must be produced upon entry.'),
                      _buildCleanRuleLine('• Maintain complete silence inside study zones at all times.'),
                      _buildCleanRuleLine('• Loss of ID card must be reported immediately to reception.'),
                      if (student.fatherName.isNotEmpty)
                        _buildCleanRuleLine('• Guardian: ${student.fatherName}'),
                      if (student.bloodGroup != null && student.bloodGroup!.isNotEmpty)
                        _buildCleanRuleLine('• Blood Group: ${student.bloodGroup}'),
                    ],
                  ),

                  // Emergency Bar (Light Rose container with red border)
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 4.5, vertical: 2),
                    decoration: pw.BoxDecoration(
                      color: const PdfColor.fromInt(0xFFFFF1F2),
                      borderRadius: pw.BorderRadius.circular(2),
                      border: pw.Border.all(color: const PdfColor.fromInt(0xFFFCA5A5), width: 0.4),
                    ),
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Row(
                          children: [
                            pw.Text('EMERGENCY: ', style: pw.TextStyle(fontSize: 4.5, fontWeight: pw.FontWeight.bold, color: const PdfColor.fromInt(0xFFDC2626))),
                            pw.Text(student.emergencyContact.isNotEmpty ? student.emergencyContact : student.phone, style: pw.TextStyle(fontSize: 4.5, fontWeight: pw.FontWeight.bold, color: const PdfColor.fromInt(0xFF991B1B))),
                          ],
                        ),
                        pw.Text('Reception: $effectiveReception', style: const pw.TextStyle(fontSize: 4.2, color: PdfColors.grey700)),
                      ],
                    ),
                  ),

                  // Bottom Notice & Stamp Box
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('- Card must be presented upon request.', style: const pw.TextStyle(fontSize: 3.8, color: PdfColors.grey600)),
                          pw.Text('- Official property of ${sanitizeText(library.name)}', style: const pw.TextStyle(fontSize: 3.8, color: PdfColors.grey600)),
                        ],
                      ),

                      // Dotted Signature & Rubber Stamp Container
                      pw.Container(
                        width: 72,
                        padding: const pw.EdgeInsets.all(2),
                        decoration: pw.BoxDecoration(
                          border: pw.Border.all(color: PdfColors.grey400, width: 0.5, style: pw.BorderStyle.dashed),
                          borderRadius: pw.BorderRadius.circular(2),
                        ),
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.center,
                          children: [
                            if (stampImage != null)
                              pw.Container(
                                width: 18,
                                height: 18,
                                child: pw.Image(stampImage, fit: pw.BoxFit.contain),
                              )
                            else
                              pw.Container(
                                width: 16,
                                height: 16,
                                decoration: pw.BoxDecoration(
                                  shape: pw.BoxShape.circle,
                                  border: pw.Border.all(color: effectivePrimary, width: 0.5),
                                ),
                                child: pw.Center(
                                  child: pw.Text('SEAL', style: pw.TextStyle(fontSize: 3, fontWeight: pw.FontWeight.bold, color: effectivePrimary)),
                                ),
                              ),
                            pw.SizedBox(height: 1),
                            pw.Text('Authorized Signatory / Seal', style: const pw.TextStyle(fontSize: 3.5, color: PdfColors.grey600)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static pw.Widget _buildCleanInfoRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 0.8),
      child: pw.Row(
        children: [
          pw.SizedBox(
            width: 28,
            child: pw.Text(
              label,
              style: const pw.TextStyle(fontSize: 4.2, color: PdfColors.grey600),
            ),
          ),
          pw.Expanded(
            child: pw.Text(
              value,
              maxLines: 1,
              style: pw.TextStyle(
                fontSize: 4.5,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.black,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildCleanRuleLine(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 1.2),
      child: pw.Text(
        text,
        maxLines: 1,
        style: const pw.TextStyle(fontSize: 4.5, color: PdfColors.grey800),
      ),
    );
  }
}
