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
import 'package:study_library/models/section_model.dart';
import 'package:study_library/models/receipt_model.dart';
import 'package:study_library/core/utils/secure_screen_mixin.dart';
import 'package:study_library/core/utils/file_download_helper.dart';
import 'package:study_library/features/students/presentation/providers/student_providers.dart';
import 'package:study_library/features/auth/presentation/providers/auth_provider.dart';
import 'package:go_router/go_router.dart';
import 'package:study_library/core/router/app_router.dart';
import 'package:study_library/core/utils/seat_helper.dart';
import 'package:study_library/core/utils/error_formatter.dart';

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
  final TransformationController _transformationController = TransformationController();
  Future<Map<String, dynamic>>? _dataFuture;
  String? _initializedLibId;

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  void _zoomIn() {
    final matrix = _transformationController.value.clone();
    matrix.multiply(Matrix4.diagonal3Values(1.25, 1.25, 1.0));
    _transformationController.value = matrix;
  }

  void _zoomOut() {
    final matrix = _transformationController.value.clone();
    matrix.multiply(Matrix4.diagonal3Values(0.8, 0.8, 1.0));
    _transformationController.value = matrix;
  }

  void _resetZoom() {
    _transformationController.value = Matrix4.identity();
  }

  @override
  Widget build(BuildContext context) {
    final rawLibId = ref.watch(currentLibraryIdProvider);
    final libraryId = (rawLibId != null && rawLibId.isNotEmpty)
        ? rawLibId
        : CurrentLibraryNotifier.defaultLibraryId;

    void handleBack() {
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
    }

    Widget buildBackLeading() {
      return IconButton(
        icon: const Icon(Icons.arrow_back_rounded),
        tooltip: 'Back',
        onPressed: handleBack,
      );
    }

    if (libraryId.isEmpty || widget.receiptId.isEmpty) {
      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (didPop) return;
          handleBack();
        },
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Receipt Preview'),
            leading: buildBackLeading(),
          ),
          body: const Center(child: Text('Receipt not found')),
        ),
      );
    }

    // Cache the future so rebuilds don't re-trigger network fetches
    if (_dataFuture == null || _initializedLibId != libraryId) {
      _initializedLibId = libraryId;
      _dataFuture = _fetchData(libraryId, widget.receiptId);
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        handleBack();
      },
      child: FutureBuilder<Map<String, dynamic>>(
      future: _dataFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Receipt Preview'),
              leading: buildBackLeading(),
            ),
            body: Center(
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
            ),
          );
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Receipt Preview'),
              leading: buildBackLeading(),
            ),
            body: Center(child: Text('Failed to load receipt: ${snapshot.error ?? "Not found"}')),
          );
        }

        final data = snapshot.data!;
        final receipt = data['receipt'] as ReceiptModel;
        final libraryData = data['library'] as Map<String, dynamic>;
        final studentData = data['student'] as Map<String, dynamic>;
        final template = data['template'] as Map<String, dynamic>?;

        final student = StudentModel.fromJson({...studentData, 'id': receipt.studentId});
        final plan = (data['plan'] as PlanModel?) ??
            widget.preloadedPlan ??
            PlanModel(
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
        final section = data['section'] as SectionModel?;
        final library = LibraryModel.fromJson({...libraryData, 'id': libraryId});
        final currentUserRole = ref.watch(userRoleProvider);
        final isStudentUser = widget.isStudent ?? (currentUserRole == AppUserRole.student);

        return Scaffold(
          appBar: AppBar(
            title: const FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                'Receipt Preview',
                maxLines: 1,
                softWrap: false,
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            centerTitle: false,
            titleSpacing: 0,
            leading: buildBackLeading(),
            actions: [
              IconButton(
                icon: const Icon(Icons.zoom_out_rounded),
                tooltip: 'Zoom Out',
                onPressed: _zoomOut,
              ),
              IconButton(
                icon: const Icon(Icons.restart_alt_rounded),
                tooltip: 'Reset Zoom (100%)',
                onPressed: _resetZoom,
              ),
              IconButton(
                icon: const Icon(Icons.zoom_in_rounded),
                tooltip: 'Zoom In',
                onPressed: _zoomIn,
              ),
              IconButton(
                icon: const Icon(Icons.share_rounded),
                tooltip: 'Share Receipt',
                onPressed: () => _shareReceipt(
                  context: context,
                  receipt: receipt,
                  student: student,
                  plan: plan,
                  library: library,
                  template: template,
                  data: data,
                ),
              ),
            ],
          ),
          body: InteractiveViewer(
            transformationController: _transformationController,
            minScale: 0.75,
            maxScale: 4.0,
            clipBehavior: Clip.none,
            child: PdfPreview(
              build: (format) => PdfService().generateReceiptPdf(
                receipt,
                student,
                plan,
                library,
                template,
                seatLabel: data['seatLabel'] as String?,
                cols: data['cols'] as int?,
                section: section,
              ),
              useActions: false, // Disables internal unlabeled action bar with duplicate icons
              canChangeOrientation: false,
              canChangePageFormat: false,
              canDebug: false,
              allowPrinting: false,
              allowSharing: false,
              pdfFileName: 'Receipt_${receipt.receiptNumber}.pdf',
            ),
          ),
          bottomNavigationBar: _buildBottomBar(
            context,
            receipt: receipt,
            student: student,
            plan: plan,
            library: library,
            template: template,
            data: data,
            isStudentUser: isStudentUser,
          ),
        );
      },
    ),
  );
}

  Widget _buildBottomBar(
    BuildContext context, {
    required ReceiptModel receipt,
    required StudentModel student,
    required PlanModel plan,
    required LibraryModel library,
    required Map<String, dynamic>? template,
    required Map<String, dynamic> data,
    required bool isStudentUser,
  }) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
        border: Border(
          top: BorderSide(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
      ),
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 10,
        bottom: MediaQuery.of(context).viewPadding.bottom + 10,
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            // 1. Download PDF Button (Filled, Primary)
            Expanded(
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: theme.colorScheme.onPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 1,
                  visualDensity: VisualDensity.compact,
                ),
                icon: const Icon(Icons.download_rounded, size: 16),
                label: const FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    'Download PDF',
                    maxLines: 1,
                    softWrap: false,
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
                onPressed: () => _downloadReceipt(
                  context: context,
                  receipt: receipt,
                  student: student,
                  plan: plan,
                  library: library,
                  template: template,
                  data: data,
                ),
              ),
            ),
            const SizedBox(width: 8),

            // 2. WhatsApp Button (Admin Only: Admin dispatching receipt to student)
            if (!isStudentUser) ...[
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF25D366),
                    side: const BorderSide(color: Color(0xFF25D366), width: 1.5),
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    visualDensity: VisualDensity.compact,
                  ),
                  icon: const Icon(Icons.chat_rounded, size: 16),
                  label: const FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      'WhatsApp',
                      maxLines: 1,
                      softWrap: false,
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ),
                  onPressed: () => _shareWhatsApp(
                    context: context,
                    receipt: receipt,
                    student: student,
                    plan: plan,
                    library: library,
                    data: data,
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ],

            // 3. Share Button
            if (isStudentUser)
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: theme.colorScheme.primary,
                    side: BorderSide(color: theme.colorScheme.primary, width: 1.5),
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    visualDensity: VisualDensity.compact,
                  ),
                  icon: const Icon(Icons.share_rounded, size: 16),
                  label: const FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      'Share PDF',
                      maxLines: 1,
                      softWrap: false,
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ),
                  onPressed: () => _shareReceipt(
                    context: context,
                    receipt: receipt,
                    student: student,
                    plan: plan,
                    library: library,
                    template: template,
                    data: data,
                  ),
                ),
              )
            else
              IconButton.filledTonal(
                tooltip: 'Share Receipt',
                icon: const Icon(Icons.share_rounded, size: 18),
                onPressed: () => _shareReceipt(
                  context: context,
                  receipt: receipt,
                  student: student,
                  plan: plan,
                  library: library,
                  template: template,
                  data: data,
                ),
              ),

            // 4. Print Button (if Admin)
            if (!isStudentUser) ...[
              const SizedBox(width: 8),
              IconButton.filledTonal(
                tooltip: 'Print Receipt',
                icon: const Icon(Icons.print_rounded, size: 18),
                onPressed: () => _printReceipt(
                  context: context,
                  receipt: receipt,
                  student: student,
                  plan: plan,
                  library: library,
                  template: template,
                  data: data,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _downloadReceipt({
    required BuildContext context,
    required ReceiptModel receipt,
    required StudentModel student,
    required PlanModel plan,
    required LibraryModel library,
    required Map<String, dynamic>? template,
    required Map<String, dynamic> data,
  }) async {
    try {
      final messenger = ScaffoldMessenger.of(context);
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
              SizedBox(width: 12),
              Text('Preparing receipt download...'),
            ],
          ),
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );

      final bytes = await PdfService().generateReceiptPdf(
        receipt,
        student,
        plan,
        library,
        template,
        seatLabel: data['seatLabel'] as String?,
        cols: data['cols'] as int?,
        section: data['section'] as SectionModel?,
      );

      final filename = 'Receipt_${receipt.receiptNumber}.pdf';
      await FileDownloadHelper.downloadFile(
        fileName: filename,
        bytes: bytes,
        mimeType: 'application/pdf',
      );

      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Text('Saved $filename to Downloads folder'),
            ],
          ),
          backgroundColor: Colors.green.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (context.mounted) {
        AppErrorFormatter.showErrorSnackBar(context, e, actionContext: 'receipt');
      }
    }
  }

  Future<void> _shareReceipt({
    required BuildContext context,
    required ReceiptModel receipt,
    required StudentModel student,
    required PlanModel plan,
    required LibraryModel library,
    required Map<String, dynamic>? template,
    required Map<String, dynamic> data,
  }) async {
    try {
      final bytes = await PdfService().generateReceiptPdf(
        receipt,
        student,
        plan,
        library,
        template,
        seatLabel: data['seatLabel'] as String?,
        cols: data['cols'] as int?,
        section: data['section'] as SectionModel?,
      );
      final filename = 'Receipt_${receipt.receiptNumber}.pdf';
      await Printing.sharePdf(bytes: bytes, filename: filename);
    } catch (e) {
      if (context.mounted) {
        AppErrorFormatter.showErrorSnackBar(context, e, actionContext: 'receipt');
      }
    }
  }

  Future<void> _shareWhatsApp({
    required BuildContext context,
    required ReceiptModel receipt,
    required StudentModel student,
    required PlanModel plan,
    required LibraryModel library,
    required Map<String, dynamic> data,
  }) async {
    final seat = (data['seatLabel'] as String?) ??
        (student.seatId != null && student.seatId!.isNotEmpty ? SeatHelper.formatSeatLabel(seatId: student.seatId) : null) ??
        'फ्लेक्सिबल (General Shift)';
    final receiptUrl = receipt.id.isNotEmpty
        ? 'https://study-lib-mgmt-2026.web.app/app/admin/receipts/${receipt.id}'
        : '';
    await WhatsAppService().sendPaymentConfirmation(
      student.phone,
      student.name,
      library.name,
      receipt.amount,
      receipt.receiptNumber,
      planName: plan.name,
      seatLabel: seat,
      validFromDate: DateFormat('dd MMM yyyy').format(receipt.validFrom),
      expiryDate: DateFormat('dd MMM yyyy').format(receipt.validTo),
      paymentMethod: receipt.paymentMethod,
      remainingDue: receipt.remainingDue,
      receiptUrl: receiptUrl,
      libraryHelpline: library.phone,
      adminTemplate: library.effectiveReceiptTemplate,
      context: context,
    );
  }

  Future<void> _printReceipt({
    required BuildContext context,
    required ReceiptModel receipt,
    required StudentModel student,
    required PlanModel plan,
    required LibraryModel library,
    required Map<String, dynamic>? template,
    required Map<String, dynamic> data,
  }) async {
    try {
      final bytes = await PdfService().generateReceiptPdf(
        receipt,
        student,
        plan,
        library,
        template,
        seatLabel: data['seatLabel'] as String?,
        cols: data['cols'] as int?,
        section: data['section'] as SectionModel?,
      );
      await Printing.layoutPdf(
        onLayout: (_) => bytes,
        name: 'Receipt_${receipt.receiptNumber}',
      );
    } catch (e) {
      if (context.mounted) {
        AppErrorFormatter.showErrorSnackBar(context, e, actionContext: 'receipt');
      }
    }
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

    // In-memory live stream check for instant student resolution
    Map<String, dynamic> resolvedStudentData = Map<String, dynamic>.from(studentDataPreloaded);
    if (resolvedStudentData.isEmpty && receipt.studentId.isNotEmpty) {
      final streamStudents = ref.read(studentsStreamProvider).value;
      if (streamStudents != null) {
        try {
          final sMatch = streamStudents.firstWhere((s) => s.id == receipt.studentId);
          resolvedStudentData = sMatch.toJson();
        } catch (_) {}
      }
    }

    // Concurrently fetch library, student, plan, and receipt template
    final libDocFuture = firestore.collection('libraries').doc(effectiveLibId).get();

    final studentDocFuture = (resolvedStudentData.isEmpty && receipt.studentId.isNotEmpty)
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
    final studentData = resolvedStudentData.isNotEmpty
        ? resolvedStudentData
        : (sDoc?.data() ?? <String, dynamic>{});
    PlanModel? resolvedPlan = planPreloaded;
    if (resolvedPlan == null && pDoc?.exists == true) {
      resolvedPlan = PlanModel.fromJson({...pDoc!.data()!, 'id': pDoc.id});
    } else if (resolvedPlan == null && (receipt.planId == 'custom' || studentData['planId'] == 'custom')) {
      final customName = (receipt.customFields['planName'] ??
              receipt.customFields['customPlanName'] ??
              studentData['customPlanName'] ??
              'Custom Plan')
          .toString();
      resolvedPlan = PlanModel(
        id: 'custom',
        libraryId: effectiveLibId,
        name: customName.isNotEmpty ? customName : 'Custom Plan',
        price: (studentData['customPlanFee'] as num?)?.toDouble() ?? receipt.amount,
        duration: 1,
        durationUnit: DurationUnit.months,
        description: (studentData['customDiscountReason'] ?? '').toString(),
        gracePeriodDays: 0,
        isActive: true,
        isFeatured: false,
        displayOrder: 0,
      );
    }

    final planName = resolvedPlan?.name ??
        (receipt.customFields['planName'] as String?) ??
        (studentData['customPlanName'] as String?) ??
        (pDoc?.data()?['name'] as String?) ??
        'Membership';
    final templateData = templateDoc?.exists == true ? templateDoc!.data() : null;

    // Resolve seat and section concurrently if attached to student
    String? resolvedSeatLabel;
    int? sectionCols;
    SectionModel? resolvedSection;
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

      var secDoc = seatResults[0];
      final seatDoc = seatResults[1];

      // If sectionId was missing from student, attempt to resolve via seat's sectionId
      if ((secDoc == null || secDoc.exists != true) && seatDoc?.exists == true) {
        final derivedSecId = seatDoc!.data()?['sectionId'] as String?;
        if (derivedSecId != null && derivedSecId.isNotEmpty) {
          try {
            secDoc = await firestore.collection('libraries').doc(effectiveLibId).collection('sections').doc(derivedSecId).get();
          } catch (_) {}
        }
      }

      if (secDoc?.exists == true) {
        sectionCols = (secDoc!.data()?['cols'] as num?)?.toInt();
        resolvedSection = SectionModel.fromJson({...secDoc.data()!, 'id': secDoc.id});
      }
      if (seatDoc?.exists == true) {
        resolvedSeatLabel = seatDoc!.data()?['label'] as String?;
      }
    }

    return {
      'receipt': receipt,
      'library': libData,
      'student': studentData,
      'plan': resolvedPlan,
      'planName': planName,
      'section': resolvedSection,
      'template': templateData,
      'seatLabel': resolvedSeatLabel,
      'cols': sectionCols,
    };
  }
}
