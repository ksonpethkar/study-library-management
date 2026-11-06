import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import 'package:study_library/core/utils/seat_helper.dart';
import 'package:study_library/services/pdf_font_service.dart';

class SeatAllocationPdfService {
  /// Generates and previews/prints a printable seating chart PDF.
  /// Structure: For each Section → list seats with student names.
  static Future<void> generateAndShare({
    required String libraryId,
    required String libraryName,
    required BuildContext context,
  }) async {
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text('Generating seating chart...'),
          ],
        ),
      ),
    );

    try {
      // 0. Load library profile details (Address, Phone, Email)
      final libDoc = await FirebaseFirestore.instance
          .collection('libraries')
          .doc(libraryId)
          .get();
      final libData = libDoc.data() ?? {};
      final address = (libData['address'] as String?)?.trim() ?? '';
      final phone = (libData['contactPhone'] ?? libData['phone'] ?? libData['helplineNumber'] as String?)?.toString().trim() ?? '';
      final email = (libData['contactEmail'] ?? libData['email'] as String?)?.toString().trim() ?? '';

      // 1. Load all sections and sort in-memory (avoids Firestore composite index requirement!)
      final sectionsSnap = await FirebaseFirestore.instance
          .collection('libraries')
          .doc(libraryId)
          .collection('sections')
          .get();

      final activeSections = sectionsSnap.docs
          .where((doc) => (doc.data()['isActive'] as bool?) != false)
          .toList()
        ..sort((a, b) {
          final oA = (a.data()['order'] as num?)?.toInt() ?? 0;
          final oB = (b.data()['order'] as num?)?.toInt() ?? 0;
          return oA.compareTo(oB);
        });

      // 2. Load all students with active seat assignments
      final studentsSnap = await FirebaseFirestore.instance
          .collection('libraries')
          .doc(libraryId)
          .collection('students')
          .where('membershipStatus', isEqualTo: 'active')
          .get();

      // Map seatId → studentName
      final seatToStudent = <String, String>{};
      for (final doc in studentsSnap.docs) {
        final data = doc.data();
        final seatId = data['seatId'] as String?;
        final name = data['name'] as String? ?? 'Unknown';
        if (seatId != null && seatId.isNotEmpty) {
          seatToStudent[seatId] = name;
        }
      }

      // 3. Build PDF
      final pdf = pw.Document();
      final universalTheme = await PdfFontService.getUniversalTheme();
      final dateStr = DateFormat('dd MMMM yyyy, hh:mm a').format(DateTime.now());

      for (final sectionDoc in activeSections) {
        final sectionData = sectionDoc.data();
        final sectionName = sectionData['name'] as String? ?? 'Section';
        final sectionType = sectionData['sectionType'] as String? ?? 'normal';
        final sectionColor = sectionData['color'] as int? ?? 0xFF1565C0;
        final rows = sectionData['rows'] as int? ?? 0;
        final cols = sectionData['cols'] as int? ?? 0;

        // Load seats for this section and sort in-memory
        final seatsSnap = await FirebaseFirestore.instance
            .collection('libraries')
            .doc(libraryId)
            .collection('sections')
            .doc(sectionDoc.id)
            .collection('seats')
            .get();

        final seats = seatsSnap.docs.map((d) => {...d.data(), 'id': d.id}).toList();
        seats.sort(SeatHelper.compareSeatMaps);

        // Strip emoji icons to prevent Helvetica fallback tofu boxes in PDF
        final typeLabel = switch (sectionType) {
          'window' => 'Window Seat',
          'ac' => 'AC Zone',
          'premium' => 'Premium Zone',
          _ => 'Standard Zone',
        };

        // Build rows data for table
        final tableData = <List<String>>[];
        tableData.add(['Seat', 'Student', 'Status']); // header
        for (final seat in seats) {
          final seatId = seat['id'] as String;
          final rawLabel = seat['label'] as String? ?? '';
          final label = rawLabel.trim().isNotEmpty ? rawLabel.trim() : seatId;
          final status = seat['status'] as String? ?? 'available';
          final studentName = seatToStudent[seatId] ?? '';
          tableData.add([
            label,
            studentName.isEmpty ? 'Available' : studentName,
            status == 'occupied' ? 'Occupied' : 'Available',
          ]);
        }

        final sectionPdfColor = PdfColor.fromInt(sectionColor);
        final occupiedCount = seats.where((s) => s['status'] == 'occupied').length;
        final availableCount = seats.length - occupiedCount;
        final occupancyPct = seats.isNotEmpty ? ((occupiedCount / seats.length) * 100).toStringAsFixed(0) : '0';

        pdf.addPage(
          pw.MultiPage(
            pageFormat: PdfPageFormat.a4,
            theme: universalTheme,
            header: (ctx) => pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            libraryName.toUpperCase(),
                            style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo900),
                          ),
                          if (address.isNotEmpty)
                            pw.Text(
                              address,
                              style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey700),
                            ),
                          if (phone.isNotEmpty || email.isNotEmpty)
                            pw.Text(
                              [
                                if (phone.isNotEmpty) 'Phone: $phone',
                                if (email.isNotEmpty) 'Email: $email',
                              ].join(' | '),
                              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
                            ),
                        ],
                      ),
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text(
                          'OFFICIAL SEATING CHART',
                          style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.grey800),
                        ),
                        pw.Text(
                          'Generated: $dateStr',
                          style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
                        ),
                      ],
                    ),
                  ],
                ),
                pw.SizedBox(height: 6),
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: pw.BoxDecoration(
                    color: sectionPdfColor,
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                  ),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        '$sectionName | $typeLabel | ${rows}R x ${cols}C | ${seats.length} Total Seats',
                        style: pw.TextStyle(
                          color: PdfColors.white,
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                      pw.Text(
                        'Occupied: $occupiedCount | Vacant: $availableCount ($occupancyPct%)',
                        style: pw.TextStyle(
                          color: PdfColors.white,
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 8),
              ],
            ),
            build: (ctx) => [
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
                columnWidths: {
                  0: const pw.FixedColumnWidth(60),
                  1: const pw.FlexColumnWidth(),
                  2: const pw.FixedColumnWidth(75),
                },
                children: tableData.asMap().entries.map((entry) {
                  final isHeader = entry.key == 0;
                  final row = entry.value;
                  final isOccupied = !isHeader && row[2] == 'Occupied';
                  return pw.TableRow(
                    decoration: pw.BoxDecoration(
                      color: isHeader
                          ? PdfColors.grey200
                          : isOccupied
                              ? PdfColors.red50
                              : PdfColors.green50,
                    ),
                    children: row
                        .map(
                          (cell) => pw.Padding(
                            padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                            child: pw.Text(
                              cell,
                              style: pw.TextStyle(
                                fontSize: 11,
                                fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
                                color: isHeader
                                    ? PdfColors.black
                                    : (isOccupied ? PdfColors.red900 : PdfColors.green900),
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  );
                }).toList(),
              ),
            ],
          ),
        );
      }

      // Save PDF bytes
      final bytes = await pdf.save();

      // Dismiss loading dialog
      if (context.mounted) Navigator.of(context, rootNavigator: true).pop();

      // Open print/PDF preview dialog across Web, Android, iOS, Windows, macOS
      final safeTitle = libraryName.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
      await Printing.layoutPdf(
        onLayout: (format) async => bytes,
        name: 'Seating_Chart_$safeTitle',
      );
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop(); // close loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to generate seating chart: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
