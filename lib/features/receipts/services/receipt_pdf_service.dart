import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';

class ReceiptPdfService {
  /// Load NotoSans font from assets for full Unicode support (₹ symbol etc.)
  static Future<pw.Font> _loadFont() async {
    final fontData = await rootBundle.load('assets/fonts/NotoSans-Regular.ttf');
    return pw.Font.ttf(fontData);
  }

  static Future<Uint8List> generateReceipt({
    required String receiptNumber,
    required String libraryName,
    required String libraryAddress,
    required String libraryPhone,
    String? logoUrl,
    required String studentName,
    required String studentPhone,
    required String planName,
    required double amount,
    required String paymentMethod,
    required DateTime paymentDate,
    required DateTime? validFrom,
    required DateTime? validTo,
    String? notes,
  }) async {
    final pdf = pw.Document();
    final dateFormat = DateFormat('dd MMM yyyy');
    // Use Rs. prefix as fallback in case font glyph missing; NotoSans supports ₹
    final currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

    // Load Unicode-capable font
    pw.Font notoSans;
    try {
      notoSans = await _loadFont();
    } catch (_) {
      notoSans = pw.Font.helvetica();
    }

    final baseStyle = pw.TextStyle(font: notoSans, fontSize: 12);

    pw.ImageProvider? logoImage;
    if (logoUrl != null && logoUrl.isNotEmpty) {
      try {
        if (logoUrl.startsWith('data:image')) {
          final b64 = logoUrl.contains(',') ? logoUrl.split(',')[1] : logoUrl;
          logoImage = pw.MemoryImage(base64Decode(b64));
        } else {
          logoImage = await networkImage(logoUrl);
        }
      } catch (_) {}
    }

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        theme: pw.ThemeData.withFont(base: notoSans),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(20),
                decoration: pw.BoxDecoration(
                  color: PdfColor.fromHex('#8B4513'),
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    if (logoImage != null) ...[
                      pw.Container(
                        width: 48,
                        height: 48,
                        decoration: const pw.BoxDecoration(
                          color: PdfColors.white,
                          shape: pw.BoxShape.circle,
                        ),
                        child: pw.ClipOval(
                          child: pw.Image(logoImage, fit: pw.BoxFit.cover),
                        ),
                      ),
                      pw.SizedBox(width: 16),
                    ],
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            libraryName,
                            style: pw.TextStyle(
                              font: notoSans,
                              fontSize: 22,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.white,
                            ),
                          ),
                          pw.SizedBox(height: 4),
                          if (libraryAddress.isNotEmpty)
                            pw.Text(
                              libraryAddress,
                              style: pw.TextStyle(font: notoSans, fontSize: 10, color: PdfColors.white),
                            ),
                          if (libraryPhone.isNotEmpty)
                            pw.Text(
                              'Phone: $libraryPhone',
                              style: pw.TextStyle(font: notoSans, fontSize: 10, color: PdfColors.white),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 20),

              // Receipt title & number
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'PAYMENT RECEIPT',
                    style: pw.TextStyle(font: notoSans, fontSize: 20, fontWeight: pw.FontWeight.bold),
                  ),
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: PdfColor.fromHex('#8B4513'), width: 2),
                      borderRadius: pw.BorderRadius.circular(4),
                    ),
                    child: pw.Text(
                      receiptNumber,
                      style: pw.TextStyle(font: notoSans, fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#8B4513')),
                    ),
                  ),
                ],
              ),

              pw.SizedBox(height: 8),
              pw.Text('Date: ${dateFormat.format(paymentDate)}', style: baseStyle),

              pw.SizedBox(height: 20),
              pw.Divider(color: PdfColors.grey400),
              pw.SizedBox(height: 12),

              // Student details
              pw.Text('STUDENT DETAILS', style: pw.TextStyle(font: notoSans, fontSize: 13, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700)),
              pw.SizedBox(height: 8),
              _buildRow('Name', studentName, notoSans),
              if (studentPhone.isNotEmpty) _buildRow('Phone', studentPhone, notoSans),

              pw.SizedBox(height: 16),
              pw.Divider(color: PdfColors.grey400),
              pw.SizedBox(height: 12),

              // Payment details
              pw.Text('PAYMENT DETAILS', style: pw.TextStyle(font: notoSans, fontSize: 13, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700)),
              pw.SizedBox(height: 8),
              _buildRow('Plan', planName, notoSans),
              _buildRow('Amount Paid', currencyFormat.format(amount), notoSans),
              _buildRow('Payment Method', paymentMethod, notoSans),
              if (validFrom != null) _buildRow('Valid From', dateFormat.format(validFrom), notoSans),
              if (validTo != null) _buildRow('Valid To', dateFormat.format(validTo), notoSans),
              if (notes != null && notes.isNotEmpty) _buildRow('Notes', notes, notoSans),

              pw.SizedBox(height: 20),
              pw.Divider(color: PdfColors.grey400),
              pw.SizedBox(height: 12),

              // Amount box
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(16),
                decoration: pw.BoxDecoration(
                  color: PdfColor.fromHex('#FFF8F0'),
                  border: pw.Border.all(color: PdfColor.fromHex('#8B4513')),
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('TOTAL PAID', style: pw.TextStyle(font: notoSans, fontSize: 16, fontWeight: pw.FontWeight.bold)),
                    pw.Text(
                      currencyFormat.format(amount),
                      style: pw.TextStyle(font: notoSans, fontSize: 22, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#8B4513')),
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 30),

              // Status badge
              pw.Center(
                child: pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  decoration: pw.BoxDecoration(
                    color: PdfColor.fromHex('#2ECC71'),
                    borderRadius: pw.BorderRadius.circular(20),
                  ),
                  child: pw.Text(
                    'PAID',
                    style: pw.TextStyle(font: notoSans, fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                  ),
                ),
              ),

              pw.Spacer(),

              // Footer
              pw.Divider(color: PdfColors.grey300),
              pw.SizedBox(height: 8),
              pw.Center(
                child: pw.Text(
                  'This is a computer-generated receipt and does not require a signature.',
                  style: pw.TextStyle(font: notoSans, fontSize: 10, color: PdfColors.grey),
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Center(
                child: pw.Text(
                  'Generated by Cozy Corner App',
                  style: pw.TextStyle(font: notoSans, fontSize: 9, color: PdfColors.grey),
                ),
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  static pw.Widget _buildRow(String label, String value, pw.Font font) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 3),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 130,
            child: pw.Text(label, style: pw.TextStyle(font: font, fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700)),
          ),
          pw.Text(': ', style: pw.TextStyle(font: font, fontSize: 12)),
          pw.Expanded(child: pw.Text(value, style: pw.TextStyle(font: font, fontSize: 12))),
        ],
      ),
    );
  }
}
