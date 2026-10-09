import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:printing/printing.dart';
import 'package:study_library/core/providers/library_provider.dart';
import 'package:study_library/services/pdf_service.dart';
import 'package:study_library/models/student_model.dart';
import 'package:study_library/models/plan_model.dart';
import 'package:study_library/models/library_model.dart';
import 'package:study_library/features/receipts/data/repositories/receipt_repository.dart';
import 'package:study_library/models/receipt_model.dart';
import 'package:study_library/core/security/audit_logger.dart';
import 'package:study_library/core/utils/sequence_counter.dart';

class GenerateReceiptScreen extends ConsumerStatefulWidget {
  final String studentId;
  final String? studentUserId;
  final String studentName;
  final String studentPhone;
  final double amount;
  final String paymentMethod;
  final String? planName;
  final String? notes;

  const GenerateReceiptScreen({super.key, 
    required this.studentId,
    this.studentUserId,
    required this.studentName,
    required this.studentPhone,
    required this.amount,
    required this.paymentMethod,
    this.planName,
    this.notes,
  });

  @override
  ConsumerState<GenerateReceiptScreen> createState() => _GenerateReceiptScreenState();
}

class _GenerateReceiptScreenState extends ConsumerState<GenerateReceiptScreen> {
  bool _isGenerating = false;
  bool _isGenerated = false;
  String _receiptNumber = '';

  @override
  void initState() {
    super.initState();
    _generateReceipt();
  }

  Future<void> _generateReceipt() async {
    setState(() => _isGenerating = true);

    try {
      final libraryId = ref.read(currentLibraryIdProvider);
      if (libraryId == null || libraryId.isEmpty) {
        throw Exception('Library not found');
      }

      // Get receipt number sequentially
      final receiptNumber = await SequenceCounter.nextReceiptNumber(libraryId);
      _receiptNumber = receiptNumber;

      String fetchedStudentUserId = widget.studentUserId ?? '';
      if (fetchedStudentUserId.isEmpty) {
        final studentDoc = await FirebaseFirestore.instance.collection('libraries').doc(libraryId).collection('students').doc(widget.studentId).get();
        fetchedStudentUserId = studentDoc.data()?['userId'] ?? '';
      }

      // Save receipt to Firestore
      final receipt = ReceiptModel(
        id: '',
        libraryId: libraryId,
        receiptNumber: _receiptNumber,
        studentId: widget.studentId,
        studentUserId: fetchedStudentUserId,
        planId: '',
        amount: widget.amount,
        paymentMethod: widget.paymentMethod,
        validFrom: DateTime.now(),
        validTo: DateTime.now().add(const Duration(days: 30)),
        customFields: {},
        status: ReceiptStatus.active,
      );
      final receiptRepo = ReceiptRepository();
      final receiptId = await receiptRepo.generateReceipt(libraryId, receipt);

      AuditLogger().log(
        action: AuditAction.created,
        entityType: AuditEntity.receipt,
        libraryId: libraryId,
        entityId: receiptId,
        details: {'studentId': widget.studentId, 'amount': widget.amount},
      ).ignore();

      setState(() {
        _isGenerating = false;
        _isGenerated = true;
      });
    } catch (e) {
      setState(() => _isGenerating = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _shareOrPrint() async {
    final libraryId = ref.read(currentLibraryIdProvider);
    if (libraryId == null) return;

    // Fetch library info
    final libDoc = await FirebaseFirestore.instance
        .collection('libraries')
        .doc(libraryId)
        .get();
    final libData = libDoc.data() ?? {};

    final templateDoc = await FirebaseFirestore.instance
        .collection('libraries')
        .doc(libraryId)
        .collection('settings')
        .doc('receipt_template')
        .get();
    final templateData = templateDoc.exists ? templateDoc.data() : null;

    final studentDoc = await FirebaseFirestore.instance.collection('libraries').doc(libraryId).collection('students').doc(widget.studentId).get();
    final fetchedStudentUserId = widget.studentUserId ?? studentDoc.data()?['userId'] ?? '';

    final receipt = ReceiptModel(
      id: '',
      libraryId: libraryId,
      receiptNumber: _receiptNumber,
      studentId: widget.studentId,
      studentUserId: fetchedStudentUserId,
      planId: '',
      amount: widget.amount,
      paymentMethod: widget.paymentMethod,
      validFrom: DateTime.now(),
      validTo: DateTime.now().add(const Duration(days: 30)),
      customFields: widget.notes != null ? {'notes': widget.notes} : {},
      status: ReceiptStatus.active,
      createdAt: DateTime.now(),
    );

    final student = StudentModel.fromJson({
      'id': widget.studentId,
      'name': widget.studentName,
      'phone': widget.studentPhone,
    });

    final plan = PlanModel(
      id: '',
      libraryId: libraryId,
      name: widget.planName ?? 'N/A',
      price: widget.amount,
      duration: 30,
      durationUnit: DurationUnit.days,
      description: '',
      gracePeriodDays: 0,
      isActive: true,
      isFeatured: false,
      displayOrder: 0,
    );

    final library = LibraryModel.fromJson({...libData, 'id': libraryId});

    final pdfBytes = await PdfService().generateReceiptPdf(
      receipt,
      student,
      plan,
      library,
      templateData,
    );

    await Printing.sharePdf(bytes: pdfBytes, filename: 'receipt_$_receiptNumber.pdf');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Payment Receipt')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: _isGenerating
            ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Generating receipt...'),
                  ],
                ),
              )
            : _isGenerated
                ? Column(
                    children: [
                      const Icon(Icons.check_circle, size: 80, color: Colors.green),
                      const SizedBox(height: 16),
                      Text('Receipt Generated!', style: theme.textTheme.headlineSmall),
                      const SizedBox(height: 8),
                      Text(_receiptNumber, style: theme.textTheme.titleLarge?.copyWith(color: theme.colorScheme.primary)),

                      const SizedBox(height: 32),

                      // Receipt summary card
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _infoRow('Student', widget.studentName),
                              _infoRow('Amount', '₹${widget.amount.toStringAsFixed(0)}'),
                              _infoRow('Method', widget.paymentMethod),
                              if (widget.planName != null) _infoRow('Plan', widget.planName!),
                              _infoRow('Date', DateTime.now().toString().split(' ')[0]),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 32),

                      // Share/Print button
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _shareOrPrint,
                          icon: const Icon(Icons.share),
                          label: const Text('Share / Print Receipt'),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Done'),
                        ),
                      ),
                    ],
                  )
                : Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, size: 64, color: Colors.red),
                        const SizedBox(height: 16),
                        const Text('Failed to generate receipt'),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _generateReceipt,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
