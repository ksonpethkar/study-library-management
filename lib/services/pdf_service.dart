import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import 'package:study_library/models/receipt_model.dart';
import 'package:study_library/models/student_model.dart';
import 'package:study_library/models/plan_model.dart';
import 'package:study_library/models/library_model.dart';
import 'package:study_library/services/id_card_pdf_service.dart';
import 'package:study_library/services/message_template_service.dart';
import 'package:study_library/services/image_transparency_service.dart';
import 'package:study_library/services/pdf_font_service.dart';
import 'package:study_library/core/utils/seat_helper.dart';

class PdfService {
  /// Convert an integer number into Indian English words (e.g. 700 -> Seven Hundred)
  static String numberToIndianWords(int n) {
    if (n == 0) return 'Zero';
    final units = [
      '', 'One', 'Two', 'Three', 'Four', 'Five', 'Six', 'Seven', 'Eight', 'Nine',
      'Ten', 'Eleven', 'Twelve', 'Thirteen', 'Fourteen', 'Fifteen', 'Sixteen',
      'Seventeen', 'Eighteen', 'Nineteen'
    ];
    final tens = [
      '', '', 'Twenty', 'Thirty', 'Forty', 'Fifty', 'Sixty', 'Seventy', 'Eighty', 'Ninety'
    ];

    String convertLessThanThousand(int num) {
      if (num == 0) return '';
      if (num < 20) return units[num];
      if (num < 100) return '${tens[num ~/ 10]}${num % 10 != 0 ? " ${units[num % 10]}" : ""}';
      return '${units[num ~/ 100]} Hundred${num % 100 != 0 ? " and ${convertLessThanThousand(num % 100)}" : ""}';
    }

    int remaining = n;
    String result = '';
    if (remaining >= 10000000) {
      result += '${convertLessThanThousand(remaining ~/ 10000000)} Crore ';
      remaining %= 10000000;
    }
    if (remaining >= 100000) {
      result += '${convertLessThanThousand(remaining ~/ 100000)} Lakh ';
      remaining %= 100000;
    }
    if (remaining >= 1000) {
      result += '${convertLessThanThousand(remaining ~/ 1000)} Thousand ';
      remaining %= 1000;
    }
    if (remaining > 0) {
      result += convertLessThanThousand(remaining);
    }
    return result.trim();
  }

  /// Strip emojis and unsupported Unicode symbols so NotoSans font never chokes or creates tofu boxes
  static String sanitizePdfText(String text) {
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

  /// In-memory cache for processed transparent images (logos, stamps, watermarks)
  static final Map<String, pw.MemoryImage> _transparentImageCache = {};

  /// Safely fetch image bytes from network or data URI and strip any opaque white paper background
  Future<pw.ImageProvider?> _loadTransparentImage(
    String url, {
    int threshold = 225,
    bool makeTransparent = true,
  }) async {
    if (url.isEmpty) return null;
    final cacheKey = '$url-$threshold-$makeTransparent';
    if (_transparentImageCache.containsKey(cacheKey)) {
      return _transparentImageCache[cacheKey];
    }

    try {
      Uint8List? rawBytes;
      if (url.startsWith('data:image')) {
        final b64 = url.contains(',') ? url.split(',')[1] : url;
        rawBytes = base64Decode(b64);
      } else {
        try {
          final bundle = NetworkAssetBundle(Uri.parse(url));
          final data = await bundle.load('').timeout(const Duration(milliseconds: 3000));
          rawBytes = data.buffer.asUint8List();
        } catch (_) {
          try {
            return await networkImage(url).timeout(const Duration(milliseconds: 3000));
          } catch (_) {
            return null;
          }
        }
      }

      if (rawBytes.isNotEmpty) {
        if (makeTransparent) {
          final cleanBytes = ImageTransparencyService.removeWhiteBackground(
            rawBytes,
            threshold: threshold,
          );
          final memImg = pw.MemoryImage(cleanBytes);
          _transparentImageCache[cacheKey] = memImg;
          return memImg;
        } else {
          final memImg = pw.MemoryImage(rawBytes);
          _transparentImageCache[cacheKey] = memImg;
          return memImg;
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Error loading transparent image for PDF: $e');
    }
    return null;
  }

  Future<Uint8List> generateReceiptPdf(
    ReceiptModel receipt,
    StudentModel student,
    PlanModel plan,
    LibraryModel library,
    Map<String, dynamic>? template, {
    String? seatLabel,
    int? cols,
  }) async {
    final pdf = pw.Document();

    // Fast-path cached base font for Unicode & Indian Rupee symbol
    final notoSans = await PdfFontService.getBaseFont();

    // ── Preload Transparent Images (Logo, Stamp & Watermark) concurrently ───
    final stampUrl = template?['stampUrl'] as String?;
    final stampEnabled = (template?['stampEnabled'] as bool?) ?? (stampUrl != null && stampUrl.isNotEmpty);

    final rawWatermarkUrl = template?['watermarkUrl'] as String?;
    final watermarkUrl = (rawWatermarkUrl != null && rawWatermarkUrl.isNotEmpty) ? rawWatermarkUrl : library.logoUrl;
    final watermarkEnabled = (template?['watermarkEnabled'] as bool?) ?? true;
    final rawOpacity = (template?['watermarkOpacity'] as num?)?.toDouble();
    final watermarkOpacity = (rawOpacity ?? 0.08).clamp(0.02, 0.35);
    final rawScale = (template?['watermarkScale'] as num?)?.toDouble();
    final watermarkScale = (rawScale ?? 0.88).clamp(0.40, 1.05);

    final imageResults = await Future.wait([
      if (library.logoUrl.isNotEmpty)
        _loadTransparentImage(library.logoUrl, threshold: 240)
      else
        Future<pw.ImageProvider?>.value(null),
      if (stampEnabled && stampUrl != null && stampUrl.isNotEmpty)
        _loadTransparentImage(stampUrl, threshold: 220)
      else
        Future<pw.ImageProvider?>.value(null),
      if (watermarkEnabled && watermarkUrl.isNotEmpty)
        _loadTransparentImage(watermarkUrl, threshold: 235)
      else
        Future<pw.ImageProvider?>.value(null),
    ]);

    final logoImage = imageResults[0];
    final stampImage = imageResults[1];
    final watermarkImage = imageResults[2];

    // Template customization settings
    final showLogo = (template?['Logo'] as bool?) ?? true;
    final showOrgName = (template?['Org Name'] as bool?) ?? true;
    final showAddress = (template?['Address'] as bool?) ?? true;
    final showContact = (template?['Contact'] as bool?) ?? true;
    final showTagline = (template?['Tagline'] as bool?) ?? false;
    final showReceiptNo = (template?['Receipt #'] as bool?) ?? true;
    final showDate = (template?['Date'] as bool?) ?? true;
    final showStudentName = (template?['Student Name'] as bool?) ?? true;
    final showTerms = (template?['Terms'] as bool?) ?? true;
    final showSignature = (template?['Signature'] as bool?) ?? true;

    final headerFontSize = ((template?['headerFontSize'] as num?)?.toDouble() ?? 22.0).clamp(16.0, 30.0);
    final stampRotation = ((template?['stampRotation'] as num?)?.toDouble() ?? -12.0);
    final stampScale = ((template?['stampScale'] as num?)?.toDouble() ?? 1.0).clamp(0.5, 1.8);
    final customTerms = template?['customTerms'] as String? ?? '';

    final footerText = (template?['footerText'] as String?) ?? '';
    final effectiveFooter = footerText.isNotEmpty
        ? footerText
        : library.receiptFooterText.isNotEmpty
            ? library.receiptFooterText
            : MessageTemplateService.defaultReceiptFooter;

    String resolvedFooter = MessageTemplateService.substitute(
      effectiveFooter,
      libraryName: library.name,
    );
    // Only append contact parts to footer if contact is not already visible in top header
    if (!showContact) {
      final contactParts = <String>[];
      if (library.email.isNotEmpty) contactParts.add(library.email);
      if (library.effectiveHelpline.isNotEmpty) contactParts.add('Helpline: ${library.effectiveHelpline}');
      if (contactParts.isNotEmpty) {
        resolvedFooter = '$resolvedFooter  |  ${contactParts.join('  |  ')}';
      }
    }
    resolvedFooter = sanitizePdfText(resolvedFooter);

    final cleanOrgName = sanitizePdfText(library.name);
    final cleanAddress = sanitizePdfText(library.address);
    final cleanContact = sanitizePdfText(library.contact);
    final cleanWelcome = sanitizePdfText(library.welcomeMessage);
    final cleanStudentName = sanitizePdfText(student.name);

    final pageFormat = PdfPageFormat.a4;
    final primaryColorHex = (template?['primaryColor'] as String?) ?? '';
    final primaryColor = primaryColorHex.isNotEmpty
        ? PdfColor.fromHex('#$primaryColorHex')
        : PdfColor.fromHex('#881337');
    final currencyFmt = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

    // Dynamic computations for professional invoice standard
    final planDesc = plan.description.trim().isNotEmpty
        ? sanitizePdfText(plan.description.trim())
        : 'AC Study Hall Access • Reserved Desk • High-Speed Wi-Fi • Power Backup';

    final dueBalance = (receipt.remainingDue ?? student.pendingDueBalance ?? 0.0);
    final isDue = dueBalance > 0.01;
    final balanceText = isDue ? '${currencyFmt.format(dueBalance)} (Due)' : '₹0.00 (Nil)';
    final balanceColor = isDue ? PdfColor.fromHex('#DC2626') : PdfColor.fromHex('#047857');

    final resolvedSeat = (seatLabel != null && seatLabel.isNotEmpty)
        ? SeatHelper.formatSeatLabel(rawLabel: seatLabel, cols: cols, includePrefix: true)
        : (student.seatId != null && student.seatId!.isNotEmpty)
            ? SeatHelper.formatSeatLabel(seatId: student.seatId, cols: cols, includePrefix: true)
            : 'Unassigned';

    final formattedDate = receipt.createdAt != null
        ? DateFormat('dd MMM yyyy').format(receipt.createdAt!)
        : DateFormat('dd MMM yyyy').format(DateTime.now());

    final startValidityStr = DateFormat('dd/MM/yyyy').format(receipt.validFrom);
    final endValidityStr = DateFormat('dd/MM/yyyy').format(receipt.validTo);

    final paymentMode = receipt.paymentMethod.isNotEmpty ? receipt.paymentMethod.toUpperCase() : 'UPI / QR';
    final isRefund = receipt.customFields['isRefund'] == true;

    final admissionId = (student.membershipNumber != null && student.membershipNumber!.isNotEmpty)
        ? student.membershipNumber!
        : 'CC-${student.id.length > 6 ? student.id.substring(0, 6).toUpperCase() : student.id.toUpperCase()}';

    final wordsText = receipt.amount > 0 ? '${numberToIndianWords(receipt.amount.toInt())} Rupees Only' : 'Zero Rupees';

    // Parse features for plan description pills
    final rawFeatures = planDesc.contains('•')
        ? planDesc.split('•')
        : planDesc.contains(',')
            ? planDesc.split(',')
            : [planDesc];
    final planFeatures = rawFeatures
        .map((f) => f.trim())
        .where((f) => f.isNotEmpty)
        .take(4)
        .toList();

    final universalTheme = await PdfFontService.getUniversalTheme(base: notoSans);

    pdf.addPage(
      pw.Page(
        pageFormat: pageFormat,
        margin: const pw.EdgeInsets.symmetric(
          horizontal: 36,
          vertical: 32,
        ),
        theme: universalTheme,
        build: (pw.Context context) {
          final pageContentWidth = context.page.pageFormat.availableWidth;
          final pageContentHeight = context.page.pageFormat.availableHeight;

          pw.Widget dualCardRow(String label, pw.Widget valueWidget) {
            return pw.Padding(
              padding: const pw.EdgeInsets.symmetric(vertical: 2.5),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.Text(label, style: pw.TextStyle(fontSize: 8.5, color: PdfColor.fromHex('#64748B'))),
                  valueWidget,
                ],
              ),
            );
          }

          pw.Widget termBullet(String text) {
            return pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 2.5),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('• ', style: pw.TextStyle(color: PdfColor.fromHex('#94A3B8'), fontSize: 8)),
                  pw.Expanded(
                    child: pw.Text(
                      text,
                      style: pw.TextStyle(fontSize: 7.5, color: PdfColor.fromHex('#475569'), lineSpacing: 1.2),
                    ),
                  ),
                ],
              ),
            );
          }

          return pw.Stack(
            fit: pw.StackFit.expand,
            children: [
              // ── Watermark Layer (100% Centered on Full Page) ──
              if (watermarkEnabled && watermarkImage != null)
                pw.Positioned.fill(
                  child: pw.Center(
                    child: pw.Opacity(
                      opacity: watermarkOpacity,
                      child: pw.Image(
                        watermarkImage,
                        width: pageContentWidth * watermarkScale,
                        height: pageContentHeight * 0.65,
                        fit: pw.BoxFit.contain,
                      ),
                    ),
                  ),
                )
              else if (watermarkEnabled)
                pw.Positioned.fill(
                  child: pw.Center(
                    child: pw.Opacity(
                      opacity: 0.04,
                      child: pw.Container(
                        width: pageContentWidth * 0.70,
                        height: pageContentWidth * 0.70,
                        decoration: pw.BoxDecoration(
                          shape: pw.BoxShape.circle,
                          border: pw.Border.all(color: primaryColor, width: 3),
                        ),
                        child: pw.Center(
                          child: pw.Container(
                            width: pageContentWidth * 0.62,
                            height: pageContentWidth * 0.62,
                            decoration: pw.BoxDecoration(
                              shape: pw.BoxShape.circle,
                              border: pw.Border.all(color: primaryColor, width: 1.5, style: pw.BorderStyle.dashed),
                            ),
                            child: pw.Column(
                              mainAxisAlignment: pw.MainAxisAlignment.center,
                              children: [
                                pw.Text(
                                  cleanOrgName.isNotEmpty ? cleanOrgName.toUpperCase() : 'STUDY LIBRARY',
                                  style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: primaryColor),
                                  textAlign: pw.TextAlign.center,
                                ),
                                pw.SizedBox(height: 6),
                                pw.Text(
                                  'स्वाध्यायेन ज्ञानवृद्धिः',
                                  style: pw.TextStyle(fontSize: 10, font: notoSans, color: primaryColor),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

              // ── Main Receipt Content (Full A4/A5 Proportional Layout) ─────────
              pw.Container(
                height: pageContentHeight,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    // ── 1. Header (Logo / Monogram + Institutional Identity + Badge) ──
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Expanded(
                          child: pw.Row(
                            crossAxisAlignment: pw.CrossAxisAlignment.center,
                            children: [
                              if (showLogo && logoImage != null)
                                pw.Container(
                                  width: 52,
                                  height: 52,
                                  margin: const pw.EdgeInsets.only(right: 14),
                                  decoration: pw.BoxDecoration(
                                    borderRadius: pw.BorderRadius.circular(12),
                                    border: pw.Border.all(color: PdfColor.fromHex('#E2E8F0'), width: 1.5),
                                  ),
                                  child: pw.ClipRRect(
                                    horizontalRadius: 10,
                                    verticalRadius: 10,
                                    child: pw.Image(logoImage, fit: pw.BoxFit.contain),
                                  ),
                                )
                              else
                                pw.Container(
                                  width: 52,
                                  height: 52,
                                  margin: const pw.EdgeInsets.only(right: 14),
                                  decoration: pw.BoxDecoration(
                                    color: primaryColor,
                                    borderRadius: pw.BorderRadius.circular(12),
                                  ),
                                  child: pw.Center(
                                    child: pw.Text(
                                      cleanOrgName.isNotEmpty
                                          ? cleanOrgName.split(' ').where((e) => e.isNotEmpty).map((e) => e[0]).take(2).join().toUpperCase()
                                          : 'CC',
                                      style: pw.TextStyle(
                                        fontSize: 18,
                                        fontWeight: pw.FontWeight.bold,
                                        color: PdfColors.white,
                                      ),
                                    ),
                                  ),
                                ),
                              pw.Expanded(
                                child: pw.Column(
                                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                                  children: [
                                    if (showOrgName)
                                      pw.Text(
                                        cleanOrgName.toUpperCase(),
                                        style: pw.TextStyle(
                                          fontSize: headerFontSize.clamp(13.0, 16.0),
                                          fontWeight: pw.FontWeight.bold,
                                          color: PdfColor.fromHex('#0F172A'),
                                          letterSpacing: 0.3,
                                        ),
                                      ),
                                    if (showAddress && cleanAddress.isNotEmpty) ...[
                                      pw.SizedBox(height: 2.5),
                                      pw.Text(
                                        cleanAddress,
                                        style: pw.TextStyle(fontSize: 8.5, color: PdfColor.fromHex('#64748B')),
                                      ),
                                    ],
                                    if (showContact) ...[
                                      pw.SizedBox(height: 2.5),
                                      pw.Text(
                                        'Helpline: ${library.effectiveHelpline.isNotEmpty ? library.effectiveHelpline : (cleanContact.isNotEmpty ? cleanContact : "Desk Reception")}${library.email.isNotEmpty ? " • Email: ${library.email}" : ""}',
                                        style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#475569')),
                                      ),
                                    ],
                                    if (showTagline && (cleanWelcome.isNotEmpty || cleanOrgName.isNotEmpty)) ...[
                                      pw.SizedBox(height: 2),
                                      pw.Text(
                                        '"${cleanWelcome.isNotEmpty ? cleanWelcome : "Welcome To $cleanOrgName"}"',
                                        style: pw.TextStyle(fontSize: 7.5, fontStyle: pw.FontStyle.italic, color: PdfColor.fromHex('#94A3B8')),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        pw.SizedBox(width: 14),
                        // Payment Confirmed Badge + Original Copy
                        pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.end,
                          children: [
                            pw.Container(
                              padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
                              decoration: pw.BoxDecoration(
                                color: isRefund ? PdfColor.fromHex('#FEF2F2') : PdfColor.fromHex('#ECFDF5'),
                                borderRadius: pw.BorderRadius.circular(16),
                                border: pw.Border.all(color: isRefund ? PdfColor.fromHex('#FECACA') : PdfColor.fromHex('#A7F3D0'), width: 1),
                              ),
                              child: pw.Row(
                                mainAxisSize: pw.MainAxisSize.min,
                                children: [
                                  pw.Container(
                                    width: 5.5,
                                    height: 5.5,
                                    decoration: pw.BoxDecoration(
                                      color: isRefund ? PdfColor.fromHex('#EF4444') : PdfColor.fromHex('#10B981'),
                                      shape: pw.BoxShape.circle,
                                    ),
                                  ),
                                  pw.SizedBox(width: 5),
                                  pw.Text(
                                    isRefund ? 'REFUND SETTLED' : 'PAYMENT CONFIRMED',
                                    style: pw.TextStyle(
                                      fontSize: 8,
                                      fontWeight: pw.FontWeight.bold,
                                      color: isRefund ? PdfColor.fromHex('#B91C1C') : PdfColor.fromHex('#047857'),
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            pw.SizedBox(height: 4),
                            pw.Text(
                              isRefund ? 'OFFICIAL EXIT VOUCHER' : 'ORIGINAL STUDENT COPY',
                              style: pw.TextStyle(
                                fontSize: 7.5,
                                fontWeight: pw.FontWeight.bold,
                                color: PdfColor.fromHex('#94A3B8'),
                                letterSpacing: 1.0,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    pw.SizedBox(height: 10),
                    pw.Divider(thickness: 1, color: PdfColor.fromHex('#E2E8F0')),
                    pw.SizedBox(height: 10),

                    // ── 2. Dual Metadata Cards (Key-Value Grid, Transparent to preserve Watermark) ──
                    pw.Row(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        // Left Card: Receipt Information
                        pw.Expanded(
                          child: pw.Container(
                            padding: const pw.EdgeInsets.all(10),
                            decoration: pw.BoxDecoration(
                              borderRadius: pw.BorderRadius.circular(8),
                              border: pw.Border.all(color: PdfColor.fromHex('#E2E8F0'), width: 1),
                            ),
                            child: pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              children: [
                                pw.Text(
                                  'RECEIPT INFORMATION',
                                  style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#94A3B8'), letterSpacing: 0.8),
                                ),
                                pw.SizedBox(height: 6),
                                if (showReceiptNo)
                                  dualCardRow(
                                    'Receipt No:',
                                    pw.Text(receipt.receiptNumber, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#0F172A'))),
                                  ),
                                if (showDate)
                                  dualCardRow(
                                    'Issue Date:',
                                    pw.Text(formattedDate, style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#1E293B'))),
                                  ),
                                dualCardRow(
                                  'Payment Mode:',
                                  pw.Container(
                                    padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: pw.BoxDecoration(
                                      borderRadius: pw.BorderRadius.circular(4),
                                      border: pw.Border.all(color: PdfColor.fromHex('#C7D2FE'), width: 0.8),
                                    ),
                                    child: pw.Text(paymentMode, style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#4338CA'))),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        pw.SizedBox(width: 12),
                        // Right Card: Student & Allocation
                        pw.Expanded(
                          child: pw.Container(
                            padding: const pw.EdgeInsets.all(10),
                            decoration: pw.BoxDecoration(
                              borderRadius: pw.BorderRadius.circular(8),
                              border: pw.Border.all(color: PdfColor.fromHex('#E2E8F0'), width: 1),
                            ),
                            child: pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              children: [
                                pw.Text(
                                  'STUDENT & ALLOCATION',
                                  style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#94A3B8'), letterSpacing: 0.8),
                                ),
                                pw.SizedBox(height: 6),
                                if (showStudentName)
                                  dualCardRow(
                                    'Student Name:',
                                    pw.Text(cleanStudentName, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#0F172A'))),
                                  ),
                                dualCardRow(
                                  'Admission ID:',
                                  pw.Text(admissionId, style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#1E293B'))),
                                ),
                                dualCardRow(
                                  'Allocated Seat:',
                                  pw.Container(
                                    padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: pw.BoxDecoration(
                                      borderRadius: pw.BorderRadius.circular(4),
                                      border: pw.Border.all(color: PdfColor.fromHex('#A7F3D0'), width: 0.8),
                                    ),
                                    child: pw.Text(resolvedSeat, style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#047857'))),
                                  ),
                                ),
                                dualCardRow(
                                  'Mobile:',
                                  pw.Text(student.phone.isNotEmpty ? student.phone : '—', style: pw.TextStyle(fontSize: 8.5, color: PdfColor.fromHex('#334155'))),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    pw.SizedBox(height: 12),

                    // ── 3. Itemized Fee Table (Enterprise 3-Column Layout, Clean & Non-Redundant) ───
                    pw.Container(
                      decoration: pw.BoxDecoration(
                        borderRadius: pw.BorderRadius.circular(8),
                        border: pw.Border.all(color: PdfColor.fromHex('#E2E8F0'), width: 1),
                      ),
                      child: pw.ClipRRect(
                        horizontalRadius: 7,
                        verticalRadius: 7,
                        child: pw.Table(
                          columnWidths: {
                            0: const pw.FlexColumnWidth(5.5),
                            1: const pw.FlexColumnWidth(2.8),
                            2: const pw.FlexColumnWidth(2.0),
                          },
                          children: [
                            // Header Row (Slate-900)
                            pw.TableRow(
                              decoration: pw.BoxDecoration(color: PdfColor.fromHex('#0F172A')),
                              children: [
                                pw.Padding(
                                  padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                                  child: pw.Text('PLAN / SERVICE DESCRIPTION', style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: PdfColors.white, letterSpacing: 0.6)),
                                ),
                                pw.Padding(
                                  padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 7),
                                  child: pw.Text('PLAN VALIDITY PERIOD', style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: PdfColors.white, letterSpacing: 0.6), textAlign: pw.TextAlign.center),
                                ),
                                pw.Padding(
                                  padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                                  child: pw.Text('AMOUNT', style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: PdfColors.white, letterSpacing: 0.6), textAlign: pw.TextAlign.right),
                                ),
                              ],
                            ),
                            // Data Row (Transparent Background to Preserve Watermark)
                            pw.TableRow(
                              children: [
                                pw.Padding(
                                  padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                  child: pw.Column(
                                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                                    children: [
                                      pw.Text(plan.name, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#0F172A'))),
                                      if (planFeatures.isNotEmpty) ...[
                                        pw.SizedBox(height: 4),
                                        pw.Wrap(
                                          spacing: 4,
                                          runSpacing: 2,
                                          children: planFeatures
                                              .map(
                                                (tag) => pw.Container(
                                                  padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
                                                  decoration: pw.BoxDecoration(
                                                    borderRadius: pw.BorderRadius.circular(3),
                                                    border: pw.Border.all(color: PdfColor.fromHex('#CBD5E1'), width: 0.6),
                                                  ),
                                                  child: pw.Text(
                                                    tag,
                                                    style: pw.TextStyle(
                                                      fontSize: 6.5,
                                                      fontWeight: pw.FontWeight.bold,
                                                      color: PdfColor.fromHex('#475569'),
                                                    ),
                                                  ),
                                                ),
                                              )
                                              .toList(),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                pw.Padding(
                                  padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 10),
                                  child: pw.Column(
                                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                                    mainAxisAlignment: pw.MainAxisAlignment.center,
                                    children: [
                                      pw.Text(
                                        startValidityStr,
                                        style: pw.TextStyle(fontSize: 8.5, color: PdfColor.fromHex('#334155')),
                                      ),
                                      pw.Text('to', style: pw.TextStyle(fontSize: 7.5, color: PdfColor.fromHex('#94A3B8'))),
                                      pw.Text(
                                        endValidityStr,
                                        style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#0F172A')),
                                      ),
                                    ],
                                  ),
                                ),
                                pw.Padding(
                                  padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                  child: pw.Align(
                                    alignment: pw.Alignment.centerRight,
                                    child: pw.Text(
                                      receipt.amount > 0 ? currencyFmt.format(receipt.amount) : '—',
                                      style: pw.TextStyle(fontSize: 11.5, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#0F172A')),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    pw.SizedBox(height: 8),

                    // ── 4. Financial Ledger Row (Transparent Background) ──
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: pw.BoxDecoration(
                        borderRadius: pw.BorderRadius.circular(8),
                        border: pw.Border.all(color: PdfColor.fromHex('#E2E8F0'), width: 1),
                      ),
                      child: pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: pw.CrossAxisAlignment.center,
                        children: [
                          // Left: Amount in Words
                          pw.Expanded(
                            child: pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              children: [
                                pw.Text('AMOUNT IN WORDS', style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#94A3B8'), letterSpacing: 0.6)),
                                pw.SizedBox(height: 2),
                                pw.Text(wordsText, style: pw.TextStyle(fontSize: 8.5, fontStyle: pw.FontStyle.italic, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#1E293B'))),
                              ],
                            ),
                          ),
                          pw.SizedBox(width: 14),
                          // Right: Balance Due & Solid Emerald Total Paid Box
                          pw.Row(
                            mainAxisSize: pw.MainAxisSize.min,
                            crossAxisAlignment: pw.CrossAxisAlignment.center,
                            children: [
                              pw.Column(
                                crossAxisAlignment: pw.CrossAxisAlignment.end,
                                children: [
                                  pw.Text('BALANCE DUE', style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#94A3B8'), letterSpacing: 0.6)),
                                  pw.SizedBox(height: 2),
                                  pw.Text(balanceText, style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: balanceColor)),
                                ],
                              ),
                              pw.SizedBox(width: 10),
                              pw.Container(
                                padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                                decoration: pw.BoxDecoration(
                                  color: isRefund ? PdfColor.fromHex('#DC2626') : PdfColor.fromHex('#047857'),
                                  borderRadius: pw.BorderRadius.circular(8),
                                ),
                                child: pw.Column(
                                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                                  children: [
                                    pw.Text(
                                      isRefund ? 'TOTAL REFUNDED' : 'TOTAL PAID',
                                      style: pw.TextStyle(
                                        fontSize: 7,
                                        fontWeight: pw.FontWeight.bold,
                                        color: isRefund ? PdfColor.fromHex('#FECACA') : PdfColor.fromHex('#A7F3D0'),
                                        letterSpacing: 0.6,
                                      ),
                                    ),
                                    pw.SizedBox(height: 2),
                                    pw.Text(
                                      receipt.amount > 0 ? currencyFmt.format(receipt.amount) : "₹0.00",
                                      style: pw.TextStyle(fontSize: 12.5, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // ── Proportional Spacer: Leaves Document Center Clean for Logo Watermark ──
                    pw.Spacer(),

                    // ── 5. Terms & Admission Policy (Just Above QR & Stamp) ──
                    if (showTerms) ...[
                      pw.Container(
                        width: double.infinity,
                        padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: pw.BoxDecoration(
                          borderRadius: pw.BorderRadius.circular(8),
                          border: pw.Border.all(color: PdfColor.fromHex('#E2E8F0'), width: 0.8),
                        ),
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text('TERMS & ADMISSION POLICY', style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#64748B'), letterSpacing: 0.6)),
                            pw.SizedBox(height: 3),
                            if (customTerms.isNotEmpty)
                              pw.Text(sanitizePdfText(customTerms), style: pw.TextStyle(fontSize: 7.2, color: PdfColor.fromHex('#475569'), lineSpacing: 1.2))
                            else ...[
                              termBullet('Fees once paid are strictly non-refundable and non-transferable under any circumstances.'),
                              termBullet('Please preserve this digital or printed fee receipt for library entry and renewal identification.'),
                              termBullet('Strict pin-drop silence and disciplined decorum must be observed inside study zones at all times.'),
                            ],
                          ],
                        ),
                      ),
                      pw.SizedBox(height: 8),
                    ],

                    // ── 6. Bottom Verification, Stamp & Signature ──────────
                          pw.Divider(thickness: 1, color: PdfColor.fromHex('#E2E8F0')),
                          pw.SizedBox(height: 8),
                          pw.Row(
                            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: pw.CrossAxisAlignment.end,
                            children: [
                              // Left: QR Code + Ledger Verification
                              pw.Row(
                                crossAxisAlignment: pw.CrossAxisAlignment.center,
                                children: [
                                  pw.Container(
                                    padding: const pw.EdgeInsets.all(3.5),
                                    decoration: pw.BoxDecoration(
                                      color: PdfColors.white,
                                      borderRadius: pw.BorderRadius.circular(6),
                                      border: pw.Border.all(color: PdfColor.fromHex('#E2E8F0'), width: 1),
                                    ),
                                    child: pw.BarcodeWidget(
                                      barcode: pw.Barcode.qrCode(),
                                      data: 'https://study-lib-mgmt-2026.web.app/verify?rec=${receipt.receiptNumber}',
                                      width: 48,
                                      height: 48,
                                    ),
                                  ),
                                  pw.SizedBox(width: 8),
                                  pw.Column(
                                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                                    children: [
                                      pw.Text('Scan to Verify Receipt', style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#0F172A'))),
                                      pw.SizedBox(height: 1.5),
                                      pw.Text(
                                        'Official digital verification via\n${cleanOrgName.isNotEmpty ? cleanOrgName : "Study Library"} Cloud Ledger',
                                        style: pw.TextStyle(fontSize: 7, color: PdfColor.fromHex('#64748B')),
                                      ),
                                    ],
                                  ),
                                ],
                              ),

                              // Right: Stamp & Signature Overlay
                              pw.Stack(
                                alignment: pw.Alignment.bottomCenter,
                                children: [
                                  if (stampImage != null)
                                    pw.Padding(
                                      padding: const pw.EdgeInsets.only(bottom: 12),
                                      child: pw.Transform.rotate(
                                        angle: stampRotation * 3.14159 / 180,
                                        child: pw.Image(
                                          stampImage,
                                          width: 62 * stampScale,
                                          height: 62 * stampScale,
                                          fit: pw.BoxFit.contain,
                                        ),
                                      ),
                                    )
                                  else
                                    pw.Padding(
                                      padding: const pw.EdgeInsets.only(bottom: 12),
                                      child: pw.Container(
                                        width: 56,
                                        height: 56,
                                        decoration: pw.BoxDecoration(
                                          shape: pw.BoxShape.circle,
                                          border: pw.Border.all(color: PdfColor.fromHex('#4338CA'), width: 1.5, style: pw.BorderStyle.dashed),
                                        ),
                                        child: pw.Transform.rotate(
                                          angle: -0.1,
                                          child: pw.Column(
                                            mainAxisAlignment: pw.MainAxisAlignment.center,
                                            children: [
                                              pw.Text('• ${cleanOrgName.length > 12 ? cleanOrgName.substring(0, 12) : cleanOrgName} •'.toUpperCase(), style: pw.TextStyle(fontSize: 5, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#3730A3'))),
                                              pw.Text('VERIFIED', style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#047857'))),
                                              pw.Text('OFFICIAL SEAL', style: pw.TextStyle(fontSize: 4, color: PdfColor.fromHex('#4338CA'))),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  if (showSignature)
                                    pw.Column(
                                      children: [
                                        pw.Container(width: 135, height: 1.2, color: PdfColor.fromHex('#334155')),
                                        pw.SizedBox(height: 3),
                                        pw.Text('Authorized Signatory & Seal', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#0F172A'))),
                                      ],
                                    ),
                                ],
                              ),
                            ],
                          ),
                          pw.SizedBox(height: 8),
                          pw.Divider(thickness: 0.5, color: PdfColor.fromHex('#F1F5F9')),
                          pw.SizedBox(height: 3),
                          pw.Center(
                            child: pw.Text(
                              resolvedFooter.isNotEmpty
                                  ? resolvedFooter
                                  : 'Thank you for choosing ${cleanOrgName.isNotEmpty ? cleanOrgName : "Study Library Center"} • This is an electronically generated receipt verified on our cloud ledger.',
                              style: pw.TextStyle(fontSize: 7.5, color: PdfColor.fromHex('#94A3B8')),
                              textAlign: pw.TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                    ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  Future<Uint8List> generateIdCardPdf(StudentModel student, LibraryModel library) async {
    return IdCardPdfService.generateIdCard(
      student: student,
      library: library,
    );
  }
}
