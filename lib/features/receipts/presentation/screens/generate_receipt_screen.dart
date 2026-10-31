import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:printing/printing.dart';
import 'package:go_router/go_router.dart';
import 'package:study_library/core/providers/library_provider.dart';
import 'package:study_library/services/pdf_service.dart';
import 'package:study_library/models/student_model.dart';
import 'package:study_library/models/plan_model.dart';
import 'package:study_library/models/section_model.dart';
import 'package:study_library/models/library_model.dart';
import 'package:study_library/features/receipts/data/repositories/receipt_repository.dart';
import 'package:study_library/models/receipt_model.dart';
import 'package:study_library/core/security/audit_logger.dart';
import 'package:study_library/core/utils/sequence_counter.dart';
import 'package:study_library/core/error/error_handler.dart';

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
  String? _createdReceiptId;

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

      final studentDoc = await FirebaseFirestore.instance.collection('libraries').doc(libraryId).collection('students').doc(widget.studentId).get();
      final studentData = studentDoc.data() ?? {};
      final fetchedStudentUserId = widget.studentUserId ?? studentData['userId'] as String? ?? '';
      final fetchedPlanId = studentData['planId'] as String? ?? '';
      final parsedPlanEnd = StudentModel.parseDateStatic(studentData['planEndDate']);
      final validToDate = parsedPlanEnd ?? DateTime(DateTime.now().year, DateTime.now().month + 1, 0, 23, 59, 59);

      // Save receipt to Firestore
      final receipt = ReceiptModel(
        id: '',
        libraryId: libraryId,
        receiptNumber: _receiptNumber,
        studentId: widget.studentId,
        studentUserId: fetchedStudentUserId,
        planId: fetchedPlanId,
        amount: widget.amount,
        paymentMethod: widget.paymentMethod,
        validFrom: DateTime.now(),
        validTo: validToDate,
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
        _createdReceiptId = receiptId;
        _isGenerating = false;
        _isGenerated = true;
      });
    } catch (e) {
      setState(() => _isGenerating = false);
      if (mounted) {
        AppSnackbar.showError(context, e);
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
    final studentData = studentDoc.data() ?? {};
    final fetchedStudentUserId = widget.studentUserId ?? studentData['userId'] as String? ?? '';
    final fetchedPlanId = studentData['planId'] as String? ?? '';
    final parsedPlanEnd = StudentModel.parseDateStatic(studentData['planEndDate']);
    final now = DateTime.now();
    final validToDate = parsedPlanEnd ?? DateTime(now.year, now.month + 1, 0, 23, 59, 59);

    final receipt = ReceiptModel(
      id: '',
      libraryId: libraryId,
      receiptNumber: _receiptNumber,
      studentId: widget.studentId,
      studentUserId: fetchedStudentUserId,
      planId: fetchedPlanId,
      amount: widget.amount,
      paymentMethod: widget.paymentMethod,
      validFrom: DateTime.now(),
      validTo: validToDate,
      customFields: widget.notes != null ? {'notes': widget.notes} : {},
      status: ReceiptStatus.active,
      createdAt: DateTime.now(),
    );

    // Look up real student, plan, and section for accurate active services
    Map<String, dynamic> studentData = {};
    try {
      final sDoc = await FirebaseFirestore.instance
          .collection('libraries')
          .doc(libraryId)
          .collection('students')
          .doc(widget.studentId)
          .get();
      studentData = sDoc.data() ?? {};
    } catch (_) {}

    final student = StudentModel.fromJson({
      'id': widget.studentId,
      'name': widget.studentName,
      'phone': widget.studentPhone,
      ...studentData,
    });

    PlanModel? resolvedPlan;
    final planId = studentData['planId'] as String?;
    if (planId != null && planId.isNotEmpty) {
      try {
        final pDoc = await FirebaseFirestore.instance
            .collection('libraries')
            .doc(libraryId)
            .collection('plans')
            .doc(planId)
            .get();
        if (pDoc.exists) {
          resolvedPlan = PlanModel.fromJson({...pDoc.data()!, 'id': pDoc.id});
        }
      } catch (_) {}
    }

    final plan = resolvedPlan ?? PlanModel(
      id: planId ?? '',
      libraryId: libraryId,
      name: widget.planName ?? 'Membership',
      price: widget.amount,
      duration: 1,
      durationUnit: DurationUnit.months,
      description: '',
      gracePeriodDays: 0,
      isActive: true,
      isFeatured: false,
      displayOrder: 0,
    );

    SectionModel? section;
    String? resolvedSeatLabel;
    int? cols;
    final seatId = studentData['seatId'] as String?;
    final sectionId = studentData['sectionId'] as String?;
    if (seatId != null && seatId.isNotEmpty) {
      try {
        final seatDoc = await FirebaseFirestore.instance
            .collection('libraries')
            .doc(libraryId)
            .collection('seats')
            .doc(seatId)
            .get();
        if (seatDoc.exists) {
          resolvedSeatLabel = seatDoc.data()?['label'] as String?;
          final derivedSecId = sectionId ?? (seatDoc.data()?['sectionId'] as String?);
          if (derivedSecId != null && derivedSecId.isNotEmpty) {
            final secDoc = await FirebaseFirestore.instance
                .collection('libraries')
                .doc(libraryId)
                .collection('sections')
                .doc(derivedSecId)
                .get();
            if (secDoc.exists) {
              cols = (secDoc.data()?['cols'] as num?)?.toInt();
              section = SectionModel.fromJson({...secDoc.data()!, 'id': secDoc.id});
            }
          }
        }
      } catch (_) {}
    }

    final library = LibraryModel.fromJson({...libData, 'id': libraryId});

    final pdfBytes = await PdfService().generateReceiptPdf(
      receipt,
      student,
      plan,
      library,
      templateData,
      seatLabel: resolvedSeatLabel,
      cols: cols,
      section: section,
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

                      // View & Share actions
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: () {
                            if (_createdReceiptId != null && _createdReceiptId!.isNotEmpty) {
                              context.pushReplacement('/admin/receipts/$_createdReceiptId');
                            } else {
                              _shareOrPrint();
                            }
                          },
                          icon: const Icon(Icons.picture_as_pdf_rounded),
                          label: const Text('View Official Receipt Preview'),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _shareOrPrint,
                          icon: const Icon(Icons.share),
                          label: const Text('Share / Print PDF'),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: TextButton(
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
