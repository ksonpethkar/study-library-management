import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';

class SeatAllocationPdfService {
  /// Generates and saves a printable seating chart PDF.
  /// Structure: For each Section → list seats with student names.
  static Future<void> generateAndShare({
    required String libraryId,
    required String libraryName,
    required BuildContext context,
  }) async {
    // Show loading
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
      // Load all sections
      final sectionsSnap = await FirebaseFirestore.instance
          .collection('libraries').doc(libraryId)
          .collection('sections')
          .where('isActive', isEqualTo: true)
          .orderBy('order')
          .get();

      // Load all students with seat assignments
      final studentsSnap = await FirebaseFirestore.instance
          .collection('libraries').doc(libraryId)
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

      // Build PDF
      final pdf = pw.Document();
      final dateStr = DateFormat('dd MMMM yyyy, hh:mm a').format(DateTime.now());

      for (final sectionDoc in sectionsSnap.docs) {
        final sectionData = sectionDoc.data();
        final sectionName = sectionData['name'] as String? ?? 'Section';
        final sectionType = sectionData['sectionType'] as String? ?? 'normal';
        final sectionColor = sectionData['color'] as int? ?? 0xFF1565C0;
        final rows = sectionData['rows'] as int? ?? 0;
        final cols = sectionData['cols'] as int? ?? 0;

        // Load seats for this section
        final seatsSnap = await FirebaseFirestore.instance
            .collection('libraries').doc(libraryId)
            .collection('sections').doc(sectionDoc.id)
            .collection('seats')
            .orderBy('row')
            .get();

        final seats = seatsSnap.docs.map((d) => {...d.data(), 'id': d.id}).toList();
        seats.sort((a, b) {
          final rA = a['row'] as int? ?? 0;
          final rB = b['row'] as int? ?? 0;
          if (rA != rB) return rA.compareTo(rB);
          return ((a['col'] as int?) ?? 0).compareTo((b['col'] as int?) ?? 0);
        });

        final typeLabel = switch (sectionType) {
          'window' => '🪟 Window',
          'ac' => '❄️ AC Zone',
          'premium' => '🌟 Premium',
          _ => 'Normal',
        };

        // Build rows data for table
        final tableData = <List<String>>[];
        tableData.add(['Seat', 'Student', 'Status']); // header
        for (final seat in seats) {
          final seatId = seat['id'] as String;
          final label = seat['label'] as String? ?? seatId;
          final status = seat['status'] as String? ?? 'available';
          final studentName = seatToStudent[seatId] ?? '';
          tableData.add([label, studentName.isEmpty ? '— Available —' : studentName, status == 'occupied' ? 'Occupied' : 'Available']);
        }

        final sectionPdfColor = PdfColor.fromInt(sectionColor);

        pdf.addPage(
          pw.MultiPage(
            pageFormat: PdfPageFormat.a4,
            header: (ctx) => pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(libraryName, style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
                    pw.Text('Generated: $dateStr', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
                  ],
                ),
                pw.SizedBox(height: 4),
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: pw.BoxDecoration(
                    color: sectionPdfColor,
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                  ),
                  child: pw.Text(
                    '$sectionName  •  $typeLabel  •  ${rows}R × ${cols}C  •  ${seats.length} seats',
                    style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 13),
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
                  2: const pw.FixedColumnWidth(70),
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
                    children: row.map((cell) => pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      child: pw.Text(
                        cell,
                        style: pw.TextStyle(
                          fontSize: 11,
                          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
                          color: isHeader ? PdfColors.black : (isOccupied ? PdfColors.red900 : PdfColors.green900),
                        ),
                      ),
                    )).toList(),
                  );
                }).toList(),
              ),
            ],
          ),
        );
      }

      // Save and share
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/seating_chart_${DateTime.now().millisecondsSinceEpoch}.pdf');
      await file.writeAsBytes(await pdf.save());

      if (context.mounted) Navigator.of(context, rootNavigator: true).pop(); // close loading

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          text: 'Seating Chart — $libraryName',
        ),
      );
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop(); // close loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to generate PDF: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}
