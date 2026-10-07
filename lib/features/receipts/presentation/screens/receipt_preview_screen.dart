import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:printing/printing.dart';
import 'package:study_library/core/providers/library_provider.dart';
import 'package:study_library/services/pdf_service.dart';
import 'package:study_library/models/student_model.dart';
import 'package:study_library/models/plan_model.dart';
import 'package:study_library/models/library_model.dart';
import 'package:study_library/models/receipt_model.dart';
import 'package:study_library/core/utils/secure_screen_mixin.dart';

class ReceiptPreviewScreen extends ConsumerStatefulWidget {
  final String receiptId;

  const ReceiptPreviewScreen({super.key, required this.receiptId});

  @override
  ConsumerState<ReceiptPreviewScreen> createState() => _ReceiptPreviewScreenState();
}

class _ReceiptPreviewScreenState extends ConsumerState<ReceiptPreviewScreen> with SecureScreenMixin {
  @override
  Widget build(BuildContext context) {
    final libraryId = ref.watch(currentLibraryIdProvider) ?? '';

    if (libraryId.isEmpty || widget.receiptId.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Receipt Preview')),
        body: const Center(child: Text('Receipt not found')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Receipt Preview')),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _fetchData(libraryId, widget.receiptId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return Center(child: Text('Failed to load receipt: ${snapshot.error ?? "Not found"}'));
          }

          final data = snapshot.data!;
          final receipt = data['receipt'] as ReceiptModel;
          final libraryData = data['library'] as Map<String, dynamic>;
          final studentData = data['student'] as Map<String, dynamic>;
          final template = data['template'] as Map<String, dynamic>?;

          final student = StudentModel.fromJson({...studentData, 'id': receipt.studentId});
          final plan = PlanModel(
            id: receipt.planId,
            libraryId: libraryId,
            name: data['planName'] ?? 'Membership',
            price: receipt.amount,
            duration: 30,
            durationUnit: DurationUnit.days,
            description: '',
            gracePeriodDays: 0,
            isActive: true,
            isFeatured: false,
            displayOrder: 0,
          );
          final library = LibraryModel.fromJson({...libraryData, 'id': libraryId});

          return PdfPreview(
            build: (format) => PdfService().generateReceiptPdf(
              receipt,
              student,
              plan,
              library,
              template,
            ),
            canChangeOrientation: false,
            canChangePageFormat: false,
            allowSharing: true,
            allowPrinting: true,
          );
        },
      ),
    );
  }

  Future<Map<String, dynamic>> _fetchData(String libraryId, String receiptId) async {
    final firestore = FirebaseFirestore.instance;

    final receiptDoc = await firestore
        .collection('libraries')
        .doc(libraryId)
        .collection('receipts')
        .doc(receiptId)
        .get();

    if (!receiptDoc.exists) {
      throw Exception('Receipt document not found');
    }

    final receipt = ReceiptModel.fromJson({...receiptDoc.data()!, 'id': receiptDoc.id});

    final libDoc = await firestore.collection('libraries').doc(libraryId).get();
    final libData = libDoc.data() ?? {};

    Map<String, dynamic> studentData = {};
    if (receipt.studentId.isNotEmpty) {
      final sDoc = await firestore
          .collection('libraries')
          .doc(libraryId)
          .collection('students')
          .doc(receipt.studentId)
          .get();
      if (sDoc.exists) {
        studentData = sDoc.data() ?? {};
      }
    }

    String planName = 'Membership';
    if (receipt.planId.isNotEmpty) {
      final pDoc = await firestore
          .collection('libraries')
          .doc(libraryId)
          .collection('plans')
          .doc(receipt.planId)
          .get();
      if (pDoc.exists) {
        planName = pDoc.data()?['name'] ?? 'Membership';
      }
    }

    final templateDoc = await firestore
        .collection('libraries')
        .doc(libraryId)
        .collection('settings')
        .doc('receipt_template')
        .get();
    final templateData = templateDoc.exists ? templateDoc.data() : null;

    return {
      'receipt': receipt,
      'library': libData,
      'student': studentData,
      'planName': planName,
      'template': templateData,
    };
  }
}
