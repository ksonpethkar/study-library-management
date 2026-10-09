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

class PdfService {
  Future<Uint8List> generateReceiptPdf(
    ReceiptModel receipt,
    StudentModel student,
    PlanModel plan,
    LibraryModel library,
    Map<String, dynamic>? template,
  ) async {
    final pdf = pw.Document();

    // Load NotoSans for full Unicode support (₹ symbol)
    pw.Font notoSans;
    try {
      final fontData = await rootBundle.load('assets/fonts/NotoSans-Regular.ttf');
      notoSans = pw.Font.ttf(fontData);
    } catch (_) {
      notoSans = pw.Font.helvetica();
    }

    // ── Preload Images (Logo & Official Stamp) ──────────────────────────────
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
        debugPrint('Receipt logo load error: $e');
      }
    }

    final stampUrl = template?['stampUrl'] as String?;
    final stampEnabled = (template?['stampEnabled'] as bool?) ?? (stampUrl != null && stampUrl.isNotEmpty);
    pw.ImageProvider? stampImage;
    if (stampEnabled && stampUrl != null && stampUrl.isNotEmpty) {
      try {
        if (stampUrl.startsWith('data:image')) {
          final b64 = stampUrl.contains(',') ? stampUrl.split(',')[1] : stampUrl;
          stampImage = pw.MemoryImage(base64Decode(b64));
        } else {
          stampImage = await networkImage(stampUrl);
        }
      } catch (e) {
        debugPrint('Receipt stamp load error: $e');
      }
    }

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

    final watermarkEnabled = (template?['watermarkEnabled'] as bool?) ?? false;
    final watermarkOpacity = ((template?['watermarkOpacity'] as num?)?.toDouble() ?? 0.12).clamp(0.02, 0.6);
    final headerFontSize = ((template?['headerFontSize'] as num?)?.toDouble() ?? 24.0).clamp(16.0, 32.0);
    final stampRotation = ((template?['stampRotation'] as num?)?.toDouble() ?? -12.0);
    final stampScale = ((template?['stampScale'] as num?)?.toDouble() ?? 1.0).clamp(0.5, 1.8);
    final customTerms = template?['customTerms'] as String? ?? '';
    
    final footerText = (template?['footerText'] as String?) ?? '';
    final resolvedFooter = footerText.isNotEmpty 
        ? MessageTemplateService.substitute(footerText, libraryName: library.name)
        : MessageTemplateService.substitute(MessageTemplateService.defaultReceiptFooter, libraryName: library.name);

    final receiptStyle = (template?['receiptStyle'] as String?) ?? 'classic';
    final pageSizeStr = (template?['pageSize'] as String?) ?? 'A4';
    final pageFormat = pageSizeStr.toLowerCase() == 'a5' ? PdfPageFormat.a5 : PdfPageFormat.a4;
    final primaryColorHex = (template?['primaryColor'] as String?) ?? '';
    final primaryColor = primaryColorHex.isNotEmpty
        ? PdfColor.fromHex('#$primaryColorHex')
        : PdfColor.fromHex('#8B4513');
    final currencyFmt = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

    pdf.addPage(
      pw.Page(
        pageFormat: pageFormat,
        margin: const pw.EdgeInsets.all(36),
        theme: pw.ThemeData.withFont(base: notoSans),
        build: (pw.Context context) {
          return pw.Stack(
            children: [
              // ── Watermark Layer ──────────────────────────────────────────
              // Uses pw.Stack with Positioned.fill so the watermark truly
              // overlays as a background across the entire page area.
              if (watermarkEnabled && logoImage != null)
                pw.Positioned.fill(
                  child: pw.Center(
                    child: pw.Opacity(
                      opacity: watermarkOpacity,
                      child: pw.Image(
                        logoImage,
                        width: 280,
                        height: 280,
                        fit: pw.BoxFit.contain,
                      ),
                    ),
                  ),
                ),


              // ── Main Receipt Content ──────────────────────────────────────
              receiptStyle == 'compact'
              ? pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Container(
                      color: primaryColor,
                      padding: const pw.EdgeInsets.all(16),
                      child: pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text(library.name, style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
                              pw.Text(library.contact, style: const pw.TextStyle(fontSize: 10, color: PdfColors.white)),
                            ],
                          ),
                          pw.Text('RECEIPT', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
                        ]
                      )
                    ),
                    pw.SizedBox(height: 16),
                    pw.Text('Receipt No: ${receipt.receiptNumber}', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                    pw.Text('Student: ${student.name}', style: const pw.TextStyle(fontSize: 11)),
                    pw.Text('Plan: ${plan.name}', style: const pw.TextStyle(fontSize: 11)),
                    pw.Text('Amount: ${currencyFmt.format(receipt.amount)}', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: primaryColor)),
                    pw.Spacer(),
                    pw.Center(
                      child: pw.Text(resolvedFooter, style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: PdfColors.grey600)),
                    ),
                  ]
                )
              : pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    // Header
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Row(
                          crossAxisAlignment: pw.CrossAxisAlignment.center,
                          children: [
                            if (showLogo && logoImage != null) ...[
                              pw.Container(
                                width: 50,
                                height: 50,
                                margin: const pw.EdgeInsets.only(right: 12),
                                child: pw.Image(logoImage, fit: pw.BoxFit.contain),
                              ),
                            ],
                            pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              children: [
                                if (showOrgName)
                                  pw.Text(
                                    library.name,
                                    style: pw.TextStyle(
                                      fontSize: headerFontSize,
                                      fontWeight: pw.FontWeight.bold,
                                    ),
                                  ),
                                if (showAddress)
                                  pw.Text(library.address, style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                                if (showContact)
                                  pw.Text('Phone: ${library.contact}', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                                if (showTagline && library.welcomeMessage.isNotEmpty)
                                  pw.Text('"${library.welcomeMessage}"', style: pw.TextStyle(fontSize: 9, fontStyle: pw.FontStyle.italic, color: PdfColors.grey600)),
                              ],
                            ),
                          ],
                        ),
                        pw.Container(
                          padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: pw.BoxDecoration(
                            color: PdfColors.grey200,
                            borderRadius: pw.BorderRadius.circular(4),
                          ),
                          child: pw.Text(
                            'FEE RECEIPT',
                            style: pw.TextStyle(
                              fontSize: 14,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.grey800,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                    pw.SizedBox(height: 12),
                    pw.Divider(thickness: 1.5, color: PdfColors.grey400),
                    pw.SizedBox(height: 16),
  
                    // Metadata Row
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            if (showReceiptNo)
                              pw.Text('Receipt No: ${receipt.receiptNumber}', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                            if (showDate)
                              pw.Text('Date: ${receipt.createdAt != null ? "${receipt.createdAt!.day.toString().padLeft(2, '0')}/${receipt.createdAt!.month.toString().padLeft(2, '0')}/${receipt.createdAt!.year}" : ""}', style: const pw.TextStyle(fontSize: 10)),
                          ],
                        ),
                        pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.end,
                          children: [
                            if (showStudentName) ...[
                              pw.Text('Student Name: ${student.name}', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                              pw.Text('Mobile: ${student.phone}', style: const pw.TextStyle(fontSize: 10)),
                            ],
                          ],
                        ),
                      ],
                    ),
                    pw.SizedBox(height: 24),
  
                    // Payment Table
                    pw.TableHelper.fromTextArray(
                      headers: ['Description', 'Validity Period', 'Payment Mode', 'Amount'],
                      data: [
                        [
                          plan.name,
                          '${receipt.validFrom.day}/${receipt.validFrom.month}/${receipt.validFrom.year} to ${receipt.validTo.day}/${receipt.validTo.month}/${receipt.validTo.year}',
                          receipt.paymentMethod,
                          currencyFmt.format(receipt.amount),
                        ],
                      ],
                      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10, color: PdfColors.white),
                      headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey800),
                      cellHeight: 28,
                      cellStyle: const pw.TextStyle(fontSize: 9.5),
                      cellAlignments: {
                        0: pw.Alignment.centerLeft,
                        1: pw.Alignment.center,
                        2: pw.Alignment.center,
                        3: pw.Alignment.centerRight,
                      },
                    ),
                    pw.SizedBox(height: 10),
  
                    // Total Row
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.end,
                      children: [
                        pw.Container(
                          padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                          decoration: pw.BoxDecoration(
                            color: PdfColors.grey100,
                            borderRadius: pw.BorderRadius.circular(4),
                            border: pw.Border.all(color: PdfColors.grey300),
                          ),
                          child: pw.Row(
                            children: [
                              pw.Text('Total Paid: ', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                              pw.Text(currencyFmt.format(receipt.amount), style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: PdfColors.green800)),
                            ],
                          ),
                        ),
                      ],
                    ),
  
                    pw.Spacer(),
  
                    // Terms & Policies
                    if (showTerms) ...[
                      pw.Container(
                        padding: const pw.EdgeInsets.all(8),
                        decoration: pw.BoxDecoration(
                          color: PdfColors.grey50,
                          borderRadius: pw.BorderRadius.circular(4),
                          border: pw.Border.all(color: PdfColors.grey200),
                        ),
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text('Terms & Conditions:', style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: PdfColors.grey800)),
                            pw.SizedBox(height: 2),
                            if (customTerms.isNotEmpty)
                              pw.Text(customTerms, style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey600))
                            else
                              pw.Text('• Fees once paid are non-refundable and non-transferable.\n• Please preserve this receipt for library entry and membership renewal.\n• Follow library rules and maintain discipline at all times.', style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey600)),
                          ],
                        ),
                      ),
                      pw.SizedBox(height: 16),
                    ],
  
                    // Footer: QR Code + Official Stamp + Authorized Signature
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        // QR Code for verification
                        pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.BarcodeWidget(
                              barcode: pw.Barcode.qrCode(),
                              data: 'RECEIPT:${receipt.receiptNumber}:${receipt.amount}:${student.id}',
                              width: 55,
                              height: 55,
                            ),
                            pw.SizedBox(height: 2),
                            pw.Text('Scan to verify receipt', style: const pw.TextStyle(fontSize: 6.5, color: PdfColors.grey600)),
                          ],
                        ),
  
                        // Stamp & Signature Column
                        pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.center,
                          children: [
                            // Stamp (if enabled, freely positioned and rotated)
                            if (stampImage != null)
                              pw.Transform.rotate(
                                angle: stampRotation * 3.14159 / 180,
                                child: pw.Image(
                                  stampImage,
                                  width: 55 * stampScale,
                                  height: 55 * stampScale,
                                  fit: pw.BoxFit.contain,
                                ),
                              )
                            else
                              pw.SizedBox(height: 35),
  
                            if (showSignature) ...[
                              pw.Container(width: 140, height: 1, color: PdfColors.grey700),
                              pw.SizedBox(height: 4),
                              pw.Text('Authorized Signatory & Stamp', style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: PdfColors.grey800)),
                            ],
                          ],
                        ),
                      ],
                    ),
                    pw.SizedBox(height: 12),
                    pw.Center(
                      child: pw.Text(resolvedFooter, style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: PdfColors.grey600)),
                    ),
                  ],
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
