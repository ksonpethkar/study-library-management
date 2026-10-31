import 'package:intl/intl.dart';
import 'package:study_library/services/whatsapp_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:printing/printing.dart';
import 'package:study_library/services/pdf_service.dart';
import 'package:study_library/models/student_model.dart';
import 'package:study_library/models/plan_model.dart';
import 'package:study_library/models/library_model.dart';
import 'package:study_library/models/receipt_model.dart';
import 'package:study_library/core/utils/secure_screen_mixin.dart';
import 'package:study_library/features/auth/presentation/providers/auth_provider.dart';
import 'package:go_router/go_router.dart';
import 'package:study_library/core/router/app_router.dart';

class ReceiptPreviewScreen extends ConsumerStatefulWidget {
  final String receiptId;
  final ReceiptModel? preloadedReceipt;
  final StudentModel? preloadedStudent;
  final PlanModel? preloadedPlan;
  final bool? isStudent;

  const ReceiptPreviewScreen({
    super.key,
    required this.receiptId,
    this.preloadedReceipt,
    this.preloadedStudent,
    this.preloadedPlan,
    this.isStudent,
  });

  @override
  ConsumerState<ReceiptPreviewScreen> createState() => _ReceiptPreviewScreenState();
}

class _ReceiptPreviewScreenState extends ConsumerState<ReceiptPreviewScreen> with SecureScreenMixin {
  Future<Map<String, dynamic>>? _dataFuture;
  String? _initializedLibId;

  @override
  Widget build(BuildContext context) {
    final libraryId = ref.watch(currentLibraryIdProvider) ?? '';

    Widget buildBackLeading() {
      return IconButton(
        icon: const Icon(Icons.arrow_back_rounded),
        tooltip: 'Back',
        onPressed: () {
          if (context.canPop()) {
            context.pop();
          } else {
            final isStudent = widget.isStudent ?? (ref.read(userRoleProvider) == AppUserRole.student);
            if (isStudent) {
              context.go(Routes.studentReceipts);
            } else {
              context.go(Routes.adminReceipts);
            }
          }
        },
      );
    }

    if (libraryId.isEmpty || widget.receiptId.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Receipt Preview'),
          leading: buildBackLeading(),
        ),
        body: const Center(child: Text('Receipt not found')),
      );
    }

    // Cache the future so rebuilds don't re-trigger network fetches
    if (_dataFuture == null || _initializedLibId != libraryId) {
      _initializedLibId = libraryId;
      _dataFuture = _fetchData(libraryId, widget.receiptId);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Receipt Preview'),
        leading: buildBackLeading(),
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _dataFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    width: 36,
                    height: 36,
                    child: CircularProgressIndicator(strokeWidth: 3),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Generating Receipt Preview...',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Loading official layout and details',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                  ),
                ],
              ),
            );
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
            duration: 1,
            durationUnit: DurationUnit.months,
            description: '',
            gracePeriodDays: 0,
            isActive: true,
            isFeatured: false,
            displayOrder: 0,
          );
          final library = LibraryModel.fromJson({...libraryData, 'id': libraryId});
          final currentUserRole = ref.watch(userRoleProvider);
          final isStudentUser = widget.isStudent ?? (currentUserRole == AppUserRole.student);

          return PdfPreview(
            build: (format) => PdfService().generateReceiptPdf(
              receipt,
              student,
              plan,
              library,
              template,
              seatLabel: data['seatLabel'] as String?,
              cols: data['cols'] as int?,
            ),
            canChangeOrientation: false,
            canChangePageFormat: false,
            allowPrinting: !isStudentUser,
            allowSharing: true,
            actions: [
              PdfPreviewAction(
                icon: const Icon(Icons.chat_rounded, color: Color(0xFF25D366)),
                onPressed: (ctx, build, pageFormat) async {
                  final phone = student.phone;
                  final libName = library.name;
                  await WhatsAppService().sendPaymentConfirmation(
                    phone,
                    student.name,
                    libName,
                    receipt.amount,
                    receipt.receiptNumber,
                    planName: plan.name,
                    seatLabel: data['seatLabel'] as String?,
                    validFromDate: DateFormat('dd MMM yyyy').format(receipt.validFrom),
                    expiryDate: DateFormat('dd MMM yyyy').format(receipt.validTo),
                    paymentMethod: receipt.paymentMethod,
                    remainingDue: receipt.remainingDue,
                    libraryHelpline: library.phone,
                    context: context,
                  );
                },
              ),
              PdfPreviewAction(
                icon: const Icon(Icons.share_rounded),
                onPressed: (ctx, build, pageFormat) async {
                  final bytes = await build(pageFormat);
                  final filename = 'Receipt_${receipt.receiptNumber}.pdf';
                  await Printing.sharePdf(bytes: bytes, filename: filename);
                },
              ),
            ],
          );
        },
      ),
    );
  }

  Future<Map<String, dynamic>> _fetchData(String libraryId, String receiptId) async {
    final firestore = FirebaseFirestore.instance;

    ReceiptModel receipt;
    if (widget.preloadedReceipt != null) {
      receipt = widget.preloadedReceipt!;
    } else {
      final receiptDoc = await firestore
          .collection('libraries')
          .doc(libraryId)
          .collection('receipts')
          .doc(receiptId)
          .get();

      if (!receiptDoc.exists) {
        throw Exception('Receipt document not found');
      }

      receipt = ReceiptModel.fromJson({...receiptDoc.data()!, 'id': receiptDoc.id});
    }

    final effectiveLibId = receipt.libraryId.isNotEmpty ? receipt.libraryId : libraryId;
    final studentDataPreloaded = widget.preloadedStudent?.toJson() ?? {};
    final planPreloaded = widget.preloadedPlan;

    // Concurrently fetch library, student, plan, and receipt template
    final libDocFuture = firestore.collection('libraries').doc(effectiveLibId).get();

    final studentDocFuture = (studentDataPreloaded.isEmpty && receipt.studentId.isNotEmpty)
        ? firestore.collection('libraries').doc(effectiveLibId).collection('students').doc(receipt.studentId).get()
        : null;

    final planDocFuture = (planPreloaded == null && receipt.planId.isNotEmpty)
        ? firestore.collection('libraries').doc(effectiveLibId).collection('plans').doc(receipt.planId).get()
        : null;

    final templateDocFuture = firestore
        .collection('libraries')
        .doc(effectiveLibId)
        .collection('settings')
        .doc('receipt_template')
        .get();

    final results = await Future.wait([
      libDocFuture.catchError((_) => null as dynamic),
      if (studentDocFuture != null) studentDocFuture.catchError((_) => null as dynamic) else Future.value(null),
      if (planDocFuture != null) planDocFuture.catchError((_) => null as dynamic) else Future.value(null),
      templateDocFuture.catchError((_) => null as dynamic),
    ]);

    final libDoc = results[0];
    final sDoc = results[1];
    final pDoc = results[2];
    final templateDoc = results[3];

    final libData = libDoc?.data() ?? {};
    final studentData = studentDataPreloaded.isNotEmpty
        ? studentDataPreloaded
        : (sDoc?.data() ?? <String, dynamic>{});
    final planName = planPreloaded?.name ?? (pDoc?.data()?['name'] as String?) ?? 'Membership';
    final templateData = templateDoc?.exists == true ? templateDoc!.data() : null;

    // Resolve seat and section concurrently if attached to student
    String? resolvedSeatLabel;
    int? sectionCols;
    final seatId = studentData['seatId'] as String?;
    final sectionId = studentData['sectionId'] as String?;

    if (seatId != null && seatId.isNotEmpty) {
      final secDocFuture = (sectionId != null && sectionId.isNotEmpty)
          ? firestore.collection('libraries').doc(effectiveLibId).collection('sections').doc(sectionId).get()
          : null;
      final seatDocFuture = firestore.collection('libraries').doc(effectiveLibId).collection('seats').doc(seatId).get();

      final seatResults = await Future.wait([
        if (secDocFuture != null) secDocFuture.catchError((_) => null as dynamic) else Future.value(null),
        seatDocFuture.catchError((_) => null as dynamic),
      ]);

      final secDoc = seatResults[0];
      final seatDoc = seatResults[1];

      if (secDoc?.exists == true) {
        sectionCols = (secDoc!.data()?['cols'] as num?)?.toInt();
      }
      if (seatDoc?.exists == true) {
        resolvedSeatLabel = seatDoc!.data()?['label'] as String?;
      }
    }

    return {
      'receipt': receipt,
      'library': libData,
      'student': studentData,
      'planName': planName,
      'template': templateData,
      'seatLabel': resolvedSeatLabel,
      'cols': sectionCols,
    };
  }
}
