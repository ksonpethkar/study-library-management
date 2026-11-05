import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:study_library/core/router/app_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:study_library/models/payment_model.dart';
import 'package:study_library/models/plan_model.dart';
import 'package:study_library/models/receipt_model.dart';
import 'package:study_library/features/payments/data/repositories/payment_repository.dart';
import 'package:study_library/features/receipts/data/repositories/receipt_repository.dart';
import 'package:study_library/features/plans/presentation/providers/plan_providers.dart';
import 'package:study_library/core/widgets/validated_text_field.dart';
import 'package:study_library/core/utils/app_validators.dart';
import 'package:study_library/core/providers/library_provider.dart';
import 'package:study_library/services/messaging_hub_service.dart';
import 'package:study_library/services/whatsapp_service.dart';
import 'package:study_library/services/plan_calculator_service.dart';
import 'package:study_library/services/app_notification_service.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:study_library/services/ocr_service.dart';
import 'package:study_library/core/utils/error_formatter.dart';
import 'package:study_library/services/upi_ocr_parser.dart';
import 'package:study_library/features/seats/presentation/providers/seat_providers.dart';
import 'package:study_library/core/utils/seat_helper.dart';

class RecordPaymentScreen extends ConsumerStatefulWidget {
  final String studentId;
  final String studentName;
  final String studentPhone;
  final double planPrice;
  final double? pendingDue;

  const RecordPaymentScreen({
    super.key,
    required this.studentId,
    required this.studentName,
    this.studentPhone = '',
    required this.planPrice,
    this.pendingDue,
  });

  @override
  ConsumerState<RecordPaymentScreen> createState() => _RecordPaymentScreenState();
}

class _RecordPaymentScreenState extends ConsumerState<RecordPaymentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _totalFeeController = TextEditingController();
  final _referenceController = TextEditingController();
  final _bankNameController = TextEditingController();
  final _notesController = TextEditingController();
  final _customPlanNameController = TextEditingController(text: 'Custom Plan');
  final _dailyRateController = TextEditingController(text: '25');
  final _discountReasonController = TextEditingController();
  bool _isStickyCustomPrice = false;

  String _paymentMethod = 'Cash';
  bool _isLoading = false;
  bool _isScanningScreenshot = false;
  bool _isPartialPayment = false;
  bool _generateReceipt = true;
  bool _extendValidity = true;
  final String _validityCycle = 'calendar_month';

  String? _selectedPlanId;
  String? _selectedPlanName;

  // Custom Plan configuration
  int _customDurationDays = 30; // default 30 days
  DateTime? _customStartDate; // if admin overrides start date
  DateTime? _customCustomExpiryDate; // if admin picked a specific date via calendar

  DateTime? _studentPlanStartDate;
  DateTime? _studentPlanEndDate;
  String? _studentMembershipStatus;
  String? _studentSeatId;
  String? _studentSectionId;
  String? _studentPreviousSeatId;
  String? _studentPreviousSectionId;
  String? _studentNotes;
  String? _studentUserId;
  bool _isLoadingStudent = true;

  List<String> _paymentMethods = ['Cash', 'UPI / QR', 'Debit / Credit Card', 'Bank Transfer', 'Cheque / DD'];

  double get _effectiveTotalFee {
    final parsed = double.tryParse(_totalFeeController.text);
    if (parsed != null && parsed > 0) return parsed;
    if (_selectedPlanId == 'custom') {
      final amountParsed = double.tryParse(_amountController.text);
      if (amountParsed != null && amountParsed > 0) return amountParsed;
    }
    if (widget.pendingDue != null && widget.pendingDue! > 0) return widget.pendingDue!;
    return widget.planPrice;
  }

  double get _payingAmount => double.tryParse(_amountController.text) ?? 0.0;

  double get _calculatedRemainingDue {
    final diff = _effectiveTotalFee - _payingAmount;
    return diff > 0 ? diff : 0.0;
  }

  @override
  void initState() {
    super.initState();
    final initialTotal = (widget.pendingDue != null && widget.pendingDue! > 0)
        ? widget.pendingDue!
        : widget.planPrice;
    _totalFeeController.text = initialTotal > 0 ? initialTotal.toStringAsFixed(0) : '';
    _amountController.text = initialTotal > 0 ? initialTotal.toStringAsFixed(0) : '';
    _loadPaymentMethods();
    _loadStudentDetails();
  }

  Future<void> _loadStudentDetails() async {
    try {
      final libraryId = ref.read(currentLibraryIdProvider) ?? '';
      if (libraryId.isEmpty) return;

      final doc = await FirebaseFirestore.instance
          .collection('libraries')
          .doc(libraryId)
          .collection('students')
          .doc(widget.studentId)
          .get();

      if (doc.exists && mounted) {
        final data = doc.data()!;
        final startRaw = data['planStartDate'];
        final endRaw = data['planEndDate'];
        final pId = data['planId'] as String?;
        final status = data['membershipStatus'] as String?;

        DateTime? start;
        if (startRaw is Timestamp) {
          start = startRaw.toDate();
        } else if (startRaw is String) {
          start = DateTime.tryParse(startRaw);
        }

        DateTime? end;
        if (endRaw is Timestamp) {
          end = endRaw.toDate();
        } else if (endRaw is String) {
          end = DateTime.tryParse(endRaw);
        }

        final due = (data['pendingDueBalance'] as num?)?.toDouble() ?? 0.0;
        final hasActivePlanDue = due > 0 && end != null && end.isAfter(DateTime.now().subtract(const Duration(days: 30)));
        final seatId = data['seatId'] as String?;
        final sectionId = data['sectionId'] as String?;
        final prevSeatId = data['previousSeatId'] as String?;
        final prevSectionId = data['previousSectionId'] as String?;

        setState(() {
          _studentPlanStartDate = start;
          _studentPlanEndDate = end;
          _selectedPlanId = pId;
          _studentMembershipStatus = status;
          _studentSeatId = seatId;
          _studentSectionId = sectionId;
          _studentPreviousSeatId = prevSeatId;
          _studentPreviousSectionId = prevSectionId;
          _studentNotes = data['notes'] as String?;
          _studentUserId = (data['userId'] ?? data['studentUserId']) as String?;
          if (data['customPlanName'] != null) {
            _customPlanNameController.text = data['customPlanName'] as String;
            _selectedPlanName = data['customPlanName'] as String;
          }
          if (data['customPlanFee'] != null && _totalFeeController.text.isEmpty) {
            final cFee = (data['customPlanFee'] as num).toDouble();
            _totalFeeController.text = cFee.toStringAsFixed(0);
            if (!_isPartialPayment) _amountController.text = cFee.toStringAsFixed(0);
          }
          if (data['isStickyCustomPrice'] == true) {
            _isStickyCustomPrice = true;
          }
          if (data['customDiscountReason'] != null) {
            _discountReasonController.text = data['customDiscountReason'] as String;
          }
          if (hasActivePlanDue) {
            _extendValidity = false; // Paying current plan due does not advance expiry
          }
          _isLoadingStudent = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingStudent = false);
    }
  }

  Future<void> _loadPaymentMethods() async {
    try {
      final libraryId = ref.read(currentLibraryIdProvider) ?? '';
      if (libraryId.isEmpty) return;

      final doc = await FirebaseFirestore.instance
          .collection('libraries')
          .doc(libraryId)
          .collection('settings')
          .doc('payment_methods')
          .get();

      if (doc.exists && mounted) {
        final data = doc.data()?['methods'] as List<dynamic>?;
        if (data != null && data.isNotEmpty) {
          final methods = data
              .cast<Map<String, dynamic>>()
              .where((m) => m['active'] as bool? ?? true)
              .map((m) => m['name'] as String? ?? '')
              .where((name) => name.isNotEmpty)
              .toList();
          if (methods.isNotEmpty && mounted) {
            setState(() {
              _paymentMethods = methods;
              if (!_paymentMethods.contains(_paymentMethod)) {
                _paymentMethod = methods.first;
              }
            });
          }
        }
      }
    } catch (_) { /* intentionally silent */ }
  }

  Future<void> _scanUpiScreenshot() async {
    final picker = ImagePicker();
    final picked = await showModalBottomSheet<XFile?>(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Select UPI Payment Screenshot', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(Icons.photo_library_rounded, color: Colors.blue),
                title: const Text('Choose from Gallery'),
                subtitle: const Text('Pick screenshot sent by student on WhatsApp/Email'),
                onTap: () async {
                  final file = await picker.pickImage(source: ImageSource.gallery, maxWidth: 1600);
                  if (ctx.mounted) Navigator.pop(ctx, file);
                },
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt_rounded, color: Colors.green),
                title: const Text('Take Photo with Camera'),
                subtitle: const Text('Photograph student phone screen at counter'),
                onTap: () async {
                  final file = await picker.pickImage(source: ImageSource.camera, maxWidth: 1600);
                  if (ctx.mounted) Navigator.pop(ctx, file);
                },
              ),
            ],
          ),
        ),
      ),
    );

    if (picked == null || !mounted) return;

    setState(() => _isScanningScreenshot = true);
    try {
      final bytes = await picked.readAsBytes();
      final ocrService = OcrService();
      final rawText = await ocrService.processImageBytes(bytes);
      final result = UpiPaymentOcrParser.parse(rawText);

      if (!mounted) return;

      if (result.hasValidData) {
        if (result.utr != null && result.utr!.isNotEmpty) {
          _referenceController.text = result.utr!;
        }
        if (result.amount != null && result.amount! > 0) {
          _amountController.text = result.amount!.toStringAsFixed(0);
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Extracted from ${result.appName ?? "Screenshot"}: '
                    '${result.utr != null ? "UTR ${result.utr} " : ""}'
                    '${result.amount != null ? "(₹${result.amount!.toStringAsFixed(0)})" : ""}',
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.green.shade700,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not find 12-digit UTR or amount in screenshot. Please verify or enter manually.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        AppErrorFormatter.showErrorSnackBar(context, e, actionContext: 'camera');
      }
    } finally {
      if (mounted) setState(() => _isScanningScreenshot = false);
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _totalFeeController.dispose();
    _referenceController.dispose();
    _bankNameController.dispose();
    _notesController.dispose();
    _customPlanNameController.dispose();
    _dailyRateController.dispose();
    _discountReasonController.dispose();
    super.dispose();
  }

  DateTime _getEffectiveStartDate() {
    if (_customStartDate != null) {
      return _customStartDate!;
    }
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    if (_studentPlanEndDate == null) return today;

    // Model A: Strict Continuous Coverage / Fixed Calendar Cycle
    // When renewing an active plan, renewing during grace, or renewing within 30 days of expiry,
    // the new cycle strictly starts the day after previous plan expiry (_studentPlanEndDate + 1 day).
    // This ensures the desk occupied during grace is accounted for and the monthly cycle does not drift.
    final daysSinceExpiry = today.difference(DateTime(_studentPlanEndDate!.year, _studentPlanEndDate!.month, _studentPlanEndDate!.day)).inDays;
    final isContinuityEligible = _studentPlanEndDate!.isAfter(now) ||
        _studentMembershipStatus == 'grace' ||
        daysSinceExpiry <= 30;

    if (isContinuityEligible) {
      return DateTime(
        _studentPlanEndDate!.year,
        _studentPlanEndDate!.month,
        _studentPlanEndDate!.day + 1,
      );
    }

    // Long-lapsed (> 30 days) rejoin starts from today
    return today;
  }

  DateTime _calculateNewExpiryDate(List<PlanModel> plans) {
    final effectiveStart = _getEffectiveStartDate();

    if (_selectedPlanId != null && _selectedPlanId != 'custom') {
      final matching = plans.where((p) => p.id == _selectedPlanId);
      if (matching.isNotEmpty) {
        final plan = matching.first;
        final smartCalc = PlanCalculatorService.calculateSmartPlan(
          plan: plan,
          fromDate: effectiveStart,
        );
        return smartCalc.endDate;
      }
    }

    // Custom Plan Date Calculation: strictly capped at current month end
    final nextMonthFirst = DateTime(effectiveStart.year, effectiveStart.month + 1, 1);
    final monthEnd = DateTime(nextMonthFirst.year, nextMonthFirst.month, 0, 23, 59, 59, 999);

    if (_customCustomExpiryDate != null) {
      final picked = DateTime(
        _customCustomExpiryDate!.year,
        _customCustomExpiryDate!.month,
        _customCustomExpiryDate!.day,
        23, 59, 59, 999,
      );
      return picked.isBefore(monthEnd) ? picked : monthEnd;
    }

    if (_customDurationDays > 0) {
      final target = DateTime(
        effectiveStart.year,
        effectiveStart.month,
        effectiveStart.day + _customDurationDays - 1,
        23, 59, 59, 999,
      );
      return target.isBefore(monthEnd) ? target : monthEnd;
    }

    // Snap to current calendar month end if duration is 0
    return monthEnd;
  }

  int _calculateCustomDays(List<PlanModel> plans) {
    final start = _getEffectiveStartDate();
    final end = _calculateNewExpiryDate(plans);
    final startDay = DateTime(start.year, start.month, start.day);
    final endDay = DateTime(end.year, end.month, end.day);
    return (endDay.difference(startDay).inDays + 1).clamp(1, 1000);
  }

  void _recalculateCustomFeeFromDailyRate(List<PlanModel> plans) {
    final dailyRate = double.tryParse(_dailyRateController.text) ?? 0.0;
    final days = _calculateCustomDays(plans);
    if (dailyRate > 0 && days > 0) {
      final total = (days * dailyRate).roundToDouble();
      _totalFeeController.text = total.toStringAsFixed(0);
      if (!_isPartialPayment) {
        _amountController.text = total.toStringAsFixed(0);
      }
    }
  }

  void _recalculateDailyRateFromTotalFee(List<PlanModel> plans) {
    final total = double.tryParse(_totalFeeController.text) ?? 0.0;
    final days = _calculateCustomDays(plans);
    if (total > 0 && days > 0) {
      final dailyRate = total / days;
      _dailyRateController.text = dailyRate.toStringAsFixed(1);
    }
  }

  void _save(List<PlanModel> plans) async {
    if (_isLoading) return; // L2 FIX: Prevent concurrent/duplicate executions
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final amount = _payingAmount;
      // L5 FIX: Disallow zero, negative, or unreasonable payment amounts
      if (amount <= 0 || amount > 99999) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Payment amount must be between ₹1 and ₹99,999.')),
          );
        }
        setState(() => _isLoading = false);
        return;
      }
      final totalFee = _effectiveTotalFee;
      final remainingDue = _isPartialPayment ? _calculatedRemainingDue : 0.0;

      final repo = ref.read(paymentRepositoryProvider);
      final libraryId = ref.read(currentLibraryIdProvider) ?? '';

      // 1. Duplicate check
      final isDup = await repo.checkDuplicatePayment(libraryId, widget.studentId, amount);
      if (!mounted) return;
      if (isDup) {
        final confirm = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Duplicate Payment Warning'),
            content: const Text('A similar payment was recorded recently. Continue anyway?'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
              FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Continue')),
            ],
          ),
        );
        if (confirm != true) {
          setState(() => _isLoading = false);
          return;
        }
      }

      // 2. Resolve validity dates (Continuous queueing if renewing in advance, like Jio)
      final now = DateTime.now();
      final isAdvance = _extendValidity && _studentPlanEndDate != null && _studentPlanEndDate!.isAfter(now);
      DateTime validFrom = _studentPlanStartDate ?? now;
      DateTime validTo = _studentPlanEndDate ?? now;

      SmartPlanCalculation? activeSmartCalc;
      if (_extendValidity) {
        validFrom = _getEffectiveStartDate();
        validTo = _calculateNewExpiryDate(plans);

        if (_selectedPlanId != null && _selectedPlanId != 'custom' && _validityCycle == 'calendar_month') {
          final matching = plans.where((p) => p.id == _selectedPlanId);
          if (matching.isNotEmpty) {
            activeSmartCalc = PlanCalculatorService.calculateSmartPlan(
              plan: matching.first,
              fromDate: validFrom,
            );
          }
        }
      }

      // Compute clean, customer-facing plan name (custom or catalog)
      final effectivePlanName = (_selectedPlanId == 'custom')
          ? (_customPlanNameController.text.trim().isNotEmpty
              ? _customPlanNameController.text.trim()
              : 'Custom Plan')
          : (_selectedPlanName ?? 'Standard Plan');

      // 3. Atomically Generate Official Receipt (if enabled)
      String? createdReceiptId;
      String receiptNumber = 'REC-${DateTime.now().year}-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
      if (_generateReceipt) {
        final receiptRepo = ReceiptRepository();
        receiptNumber = await receiptRepo.getNextReceiptNumber(libraryId);

        final newReceipt = ReceiptModel(
          id: '',
          libraryId: libraryId,
          receiptNumber: receiptNumber,
          studentId: widget.studentId,
          studentUserId: _studentUserId,
          planId: _selectedPlanId ?? 'custom',
          amount: amount,
          totalFee: totalFee,
          paidAmount: amount,
          remainingDue: remainingDue,
          installmentNumber: _isPartialPayment ? 1 : null,
          paymentMethod: _paymentMethod,
          validFrom: validFrom,
          validTo: validTo,
          customFields: {
            if (_referenceController.text.trim().isNotEmpty) 'reference': _referenceController.text.trim(),
            if (_bankNameController.text.trim().isNotEmpty) 'bankName': _bankNameController.text.trim(),
            if (_notesController.text.trim().isNotEmpty) 'notes': _notesController.text.trim(),
            if (_isPartialPayment) 'isInstalment': true,
            'planName': effectivePlanName,
            if (_selectedPlanId == 'custom') ...{
              'isCustomPlan': true,
              'customDailyRate': double.tryParse(_dailyRateController.text) ?? 25.0,
              'customDurationDays': _calculateCustomDays(plans),
              'pricingFormula': '${_calculateCustomDays(plans)} days × ₹${_dailyRateController.text}/day',
            },
            if (isAdvance) 'isAdvanceRenewal': true,
            if (isAdvance) 'advanceCycle': '${DateFormat('dd MMM yyyy').format(validFrom)} to ${DateFormat('dd MMM yyyy').format(validTo)}',
            if (activeSmartCalc != null && activeSmartCalc.isProrated) ...{
              'isProrated': true,
              'proratedDays': activeSmartCalc.daysRemaining,
              'fullCatalogPrice': activeSmartCalc.fullPrice,
            },
          },
          status: ReceiptStatus.active,
          createdAt: DateTime.now(),
        );

        createdReceiptId = await receiptRepo.generateReceipt(
          libraryId,
          newReceipt,
          recordMatchingPayment: false,
        );
      }

      // 4. Save Payment Record linked to receipt
      String? paymentNotes;
      if (isAdvance) {
        paymentNotes = '${_notesController.text.trim().isNotEmpty ? "${_notesController.text.trim()} • " : ""}⚡ Advance Plan Renewal: ${DateFormat('dd MMM yyyy').format(validFrom)} – ${DateFormat('dd MMM yyyy').format(validTo)}';
      } else if (activeSmartCalc != null && activeSmartCalc.isProrated) {
        paymentNotes = '${_notesController.text.trim().isNotEmpty ? "${_notesController.text.trim()} • " : ""}⚡ Fair Mid-Cycle Prorated (${activeSmartCalc.daysRemaining}d rate to ${DateFormat('dd MMM yyyy').format(validTo)})';
      } else if (_selectedPlanId == 'custom') {
        paymentNotes = '${_notesController.text.trim().isNotEmpty ? "${_notesController.text.trim()} • " : ""}✨ $effectivePlanName (${_calculateCustomDays(plans)}d @ ₹${_dailyRateController.text}/day)';
      } else {
        paymentNotes = _notesController.text.trim().isNotEmpty ? _notesController.text.trim() : null;
      }

      final payment = PaymentModel(
        id: '',
        studentId: widget.studentId,
        studentUserId: _studentUserId,
        amount: amount,
        totalPlanFee: totalFee,
        remainingDue: remainingDue,
        installmentNumber: _isPartialPayment ? 1 : null,
        method: _paymentMethod,
        methodDetails: _bankNameController.text.trim().isNotEmpty ? _bankNameController.text.trim() : null,
        date: DateTime.now(),
        referenceNumber: _referenceController.text.trim().isNotEmpty ? _referenceController.text.trim() : null,
        notes: paymentNotes,
        receiptId: createdReceiptId,
        receiptNumber: _generateReceipt ? receiptNumber : null,
        status: _isPartialPayment && remainingDue > 0 ? PaymentStatus.partial : PaymentStatus.paid,
        createdAt: DateTime.now(),
      );

      await repo.recordPayment(libraryId, widget.studentId, payment);

      // 5. Update Student in Firestore (Due balance & validity)
      final studentUpdates = <String, dynamic>{
        'pendingDueBalance': remainingDue,
        'membershipStatus': 'active',
        'graceEndDate': FieldValue.delete(), // Clear stale grace period from previous cycle
        'remindedStages': FieldValue.delete(), // Reset notification stages for new cycle
      };

      // Auto-clean stale pending fee notes & raw database IDs upon receiving payment
      final currentNotes = _studentNotes;
      if (remainingDue <= 0 && currentNotes != null && currentNotes.isNotEmpty) {
        var cleanedNotes = currentNotes;
        // Remove raw request ID if present, e.g. (Gjq8iLM9sZ7W1y2OlZ2S)
        cleanedNotes = cleanedNotes.replaceAll(RegExp(r'\s*\([A-Za-z0-9_-]{15,}\)'), '');
        // Strip out pending fee disclaimers
        cleanedNotes = cleanedNotes
            .replaceAll(RegExp(r'\s*—\s*Pending Fee Payment', caseSensitive: false), '')
            .replaceAll(RegExp(r'\s*Pending Fee Payment', caseSensitive: false), '')
            .replaceAll(RegExp(r'\s*—\s*Pay at Reception', caseSensitive: false), '')
            .replaceAll(RegExp(r'\s*Pay at Reception', caseSensitive: false), '')
            .replaceAll(RegExp(r'\s*—\s*Pending Desk Payment', caseSensitive: false), '')
            .replaceAll(RegExp(r'\s*Pending Desk Payment', caseSensitive: false), '')
            .replaceAll(RegExp(r'\s*—\s*Desk Payment Selected', caseSensitive: false), '')
            .replaceAll(RegExp(r'\s*Desk Payment Selected', caseSensitive: false), '')
            .trim();

        // Also clean up any trailing or leading dashes / bullet points left over
        cleanedNotes = cleanedNotes.replaceAll(RegExp(r'^[\s—•-]+|[\s—•-]+$'), '').trim();

        if (cleanedNotes != currentNotes) {
          studentUpdates['notes'] = cleanedNotes.isEmpty ? FieldValue.delete() : cleanedNotes;
        }
      }
      if (_selectedPlanId != null && _selectedPlanId != 'custom') {
        studentUpdates['planId'] = _selectedPlanId;
        studentUpdates['customPlanName'] = FieldValue.delete();
        studentUpdates['customPlanFee'] = FieldValue.delete();
        studentUpdates['isStickyCustomPrice'] = FieldValue.delete();
        studentUpdates['customDiscountReason'] = FieldValue.delete();
        studentUpdates['customDailyRate'] = FieldValue.delete();
      } else {
        studentUpdates['planId'] = 'custom';
        studentUpdates['customPlanName'] = effectivePlanName;
        studentUpdates['customPlanFee'] = totalFee;
        studentUpdates['isStickyCustomPrice'] = _isStickyCustomPrice;
        if (_discountReasonController.text.trim().isNotEmpty) {
          studentUpdates['customDiscountReason'] = _discountReasonController.text.trim();
        } else {
          studentUpdates['customDiscountReason'] = FieldValue.delete();
        }
        studentUpdates['customDailyRate'] = double.tryParse(_dailyRateController.text) ?? 25.0;
      }
      if (_extendValidity) {
        if (!isAdvance) {
          studentUpdates['planStartDate'] = Timestamp.fromDate(validFrom);
        }
        studentUpdates['planEndDate'] = Timestamp.fromDate(validTo);
        if (isAdvance) {
          studentUpdates['advanceRenewalActive'] = true;
          studentUpdates['advanceStartDate'] = Timestamp.fromDate(validFrom);
          studentUpdates['advanceEndDate'] = Timestamp.fromDate(validTo);
        }

        // Auto-retain / reassign existing or previous desk if free
        final effectiveSeatId = _studentSeatId ?? _studentPreviousSeatId;
        var effectiveSecId = _studentSectionId ?? _studentPreviousSectionId;
        if (effectiveSeatId != null && effectiveSeatId.isNotEmpty) {
          if (effectiveSecId == null || effectiveSecId.isEmpty) {
            try {
              final secSnap = await FirebaseFirestore.instance
                  .collection('libraries').doc(libraryId)
                  .collection('sections').get();
              for (final sec in secSnap.docs) {
                final seatDoc = await sec.reference.collection('seats').doc(effectiveSeatId).get();
                if (seatDoc.exists) {
                  effectiveSecId = sec.id;
                  break;
                }
              }
            } catch (_) {}
          }

          if (effectiveSecId != null && effectiveSecId.isNotEmpty) {
            try {
              final seatRef = FirebaseFirestore.instance
                  .collection('libraries').doc(libraryId)
                  .collection('sections').doc(effectiveSecId)
                  .collection('seats').doc(effectiveSeatId);
              final seatSnap = await seatRef.get();
              if (seatSnap.exists) {
                final seatData = seatSnap.data() ?? {};
                final occupant = seatData['studentId'] as String?;
                final status = seatData['status'] as String? ?? 'available';
                if (occupant == null || occupant.isEmpty || occupant == widget.studentId || status == 'available') {
                  final seatRepo = ref.read(seatRepositoryProvider);
                  await seatRepo.assignStudent(libraryId, effectiveSecId, effectiveSeatId, widget.studentId);
                  studentUpdates['seatId'] = effectiveSeatId;
                  studentUpdates['sectionId'] = effectiveSecId;
                }
              }
            } catch (e) {
              debugPrint('Failed to auto-reassign seat on payment: $e');
            }
          }
        }
      }

      await FirebaseFirestore.instance
          .collection('libraries')
          .doc(libraryId)
          .collection('students')
          .doc(widget.studentId)
          .set(studentUpdates, SetOptions(merge: true));

      // 6. Update Monthly Revenue Aggregate
      final month = DateTime.now().toIso8601String().substring(0, 7);
      FirebaseFirestore.instance
          .collection('libraries')
          .doc(libraryId)
          .collection('settings')
          .doc('revenue_aggregate')
          .set({
            'totalRevenue': FieldValue.increment(amount),
            'totalPayments': FieldValue.increment(1),
            'monthlyRevenue.$month': FieldValue.increment(amount),
            'lastUpdated': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true))
          .catchError((e) => debugPrint('Aggregate error: $e'));

      // 7. Dispatch Free Confirmation Notifications
      final library = ref.read(currentLibraryProvider).value;
      final libraryName = library?.name ?? 'Study Library';

      // Real-Time Notification (In-App Unread Dot + Android Heads-Up Notification)
      AppNotificationService.sendNotification(
        libraryId: libraryId,
        title: 'Payment Received • ₹${amount.toStringAsFixed(0)}',
        body: 'Receipt #$receiptNumber generated for ${widget.studentName}. Your membership is confirmed active!',
        type: 'payment',
        targetRole: 'student',
        targetUserId: widget.studentId,
        actionRoute: '/student/receipts',
      ).ignore();

      final hub = ref.read(messagingHubServiceProvider);
      await hub.dispatchPaymentConfirmation(
        libraryId: libraryId,
        studentName: widget.studentName,
        studentPhone: widget.studentPhone,
        libraryName: libraryName,
        amount: amount,
        receiptNumber: receiptNumber,
        paymentMethod: _paymentMethod,
        remainingDue: remainingDue,
      );

      HapticFeedback.heavyImpact();
      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();

        // Show clean modal dialog to share via WhatsApp or proceed to receipt
        if (widget.studentPhone.isNotEmpty) {
          final shouldShare = await showDialog<bool>(
            context: context,
            barrierDismissible: false,
            builder: (dlgCtx) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Row(
                children: [
                  Icon(Icons.check_circle_rounded, color: Colors.green, size: 28),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Payment Recorded! 🎉',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.green.withValues(alpha: 0.25)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Receipt #$receiptNumber',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Student: ${widget.studentName}',
                          style: const TextStyle(fontSize: 13),
                        ),
                        Text(
                          'Amount: ₹${amount.toStringAsFixed(0)} ($_paymentMethod)',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.green),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Would you like to share the official fee receipt with the student via WhatsApp?',
                    style: TextStyle(fontSize: 13.5),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dlgCtx, false),
                  child: const Text('Cancel / View Receipt'),
                ),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF25D366),
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () => Navigator.pop(dlgCtx, true),
                  icon: const Icon(Icons.chat_rounded, size: 18),
                  label: const Text('Share via WhatsApp'),
                ),
              ],
            ),
          );

          if (shouldShare == true && mounted) {
            final fromStr = DateFormat('dd MMM yyyy').format(validFrom);
            final toStr = DateFormat('dd MMM yyyy').format(validTo);
            ref.read(whatsappServiceProvider).sendPaymentConfirmation(
              widget.studentPhone,
              widget.studentName,
              libraryName,
              amount,
              receiptNumber,
              planName: _selectedPlanName ?? 'Library Membership',
              validFromDate: fromStr,
              expiryDate: toStr,
              paymentMethod: _paymentMethod,
              remainingDue: remainingDue,
              libraryHelpline: library?.phone,
              adminTemplate: library?.effectiveReceiptTemplate,
              context: context,
            );
          }
        }

        if (!mounted) return;

        if (createdReceiptId != null) {
          // P8: Track payment success in Analytics
          if (!kIsWeb) {
            FirebaseAnalytics.instance.logEvent(
              name: 'payment_recorded',
              parameters: {
                'amount': amount.toInt(),
                'student_id': widget.studentId,
              },
            ).ignore();
          }
          context.pushReplacement('/admin/receipts/$createdReceiptId');
        } else {
          context.pop(true);
        }
      }
    } catch (e, stack) {
      HapticFeedback.heavyImpact();
      // S9: Report payment errors to Crashlytics
      if (!kIsWeb) {
        FirebaseCrashlytics.instance.recordError(e, stack, reason: 'record_payment_failed', fatal: false);
      }
      if (mounted) {
        AppErrorFormatter.showErrorSnackBar(context, e, actionContext: 'payment');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final plansAsync = ref.watch(plansStreamProvider);
    final allPlans = plansAsync.value ?? [];
    final activePlans = allPlans.where((p) => p.deletedAt == null && p.isActive).toList();
    final plans = activePlans.isNotEmpty ? activePlans : allPlans.where((p) => p.deletedAt == null).toList();

    // Auto-sync plan selection
    if (_selectedPlanId == null && !_isLoadingStudent) {
      if (plans.isNotEmpty) {
        final match = plans.where((p) => p.id == _studentSeatId); // or first
        final initialPlan = match.isNotEmpty ? match.first : plans.first;
        _selectedPlanId = initialPlan.id;
        _selectedPlanName = initialPlan.name;
        if (_totalFeeController.text.isEmpty || _totalFeeController.text == '0') {
          _totalFeeController.text = initialPlan.price.toStringAsFixed(0);
          _amountController.text = initialPlan.price.toStringAsFixed(0);
        }
      } else {
        _selectedPlanId = 'custom';
      }
    } else if (_selectedPlanId != null && _selectedPlanId != 'custom') {
      final matching = plans.where((p) => p.id == _selectedPlanId);
      if (matching.isNotEmpty && (_selectedPlanName == null || _totalFeeController.text.isEmpty || _totalFeeController.text == '0')) {
        _selectedPlanName = matching.first.name;
        if (_totalFeeController.text.isEmpty || _totalFeeController.text == '0') {
          _totalFeeController.text = matching.first.price.toStringAsFixed(0);
          _amountController.text = matching.first.price.toStringAsFixed(0);
        }
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Record Payment'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_suggest_rounded),
            tooltip: 'Payment Settings',
            onPressed: () => _openSettingsSheet(context),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                16,
                16,
                16,
                48 + MediaQuery.of(context).viewPadding.bottom,
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Student Info & Expiry Banner Card
                    Card(
                      elevation: 0,
                      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(14.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.15),
                                  child: Text(
                                    widget.studentName.isNotEmpty ? widget.studentName[0].toUpperCase() : 'S',
                                    style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(widget.studentName, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                                      if (widget.studentPhone.isNotEmpty)
                                        Text('📞 ${widget.studentPhone}', style: theme.textTheme.bodySmall),
                                      Text('Base Plan Fee: ₹${widget.planPrice.toStringAsFixed(0)}', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.primary)),
                                    ],
                                  ),
                                ),
                                if (widget.pendingDue != null && widget.pendingDue! > 0)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: Colors.amber.shade100,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: Colors.amber.shade700),
                                    ),
                                    child: Text(
                                      'Due: ₹${widget.pendingDue!.toStringAsFixed(0)}',
                                      style: TextStyle(color: Colors.amber.shade900, fontWeight: FontWeight.bold, fontSize: 12),
                                    ),
                                  ),
                              ],
                            ),

                            // Prominently Highlighted Expiry Date Status Banner
                            if (_studentPlanEndDate != null)
                              Builder(builder: (context) {
                                final now = DateTime.now();
                                final days = _studentPlanEndDate!.difference(now).inDays;
                                final isInGrace = _studentMembershipStatus == 'grace';
                                final isExpired = !isInGrace && (days < 0 || _studentMembershipStatus == 'expired');
                                final isExpiringSoon = !isExpired && !isInGrace && days <= 7;
                                final bannerBg = isInGrace
                                    ? Colors.purple.shade900.withValues(alpha: 0.15)
                                    : (isExpired
                                        ? Colors.red.shade900.withValues(alpha: 0.15)
                                        : (isExpiringSoon ? Colors.orange.shade900.withValues(alpha: 0.15) : Colors.green.shade900.withValues(alpha: 0.15)));
                                final bannerBorder = isInGrace
                                    ? Colors.purple.shade400
                                    : (isExpired
                                        ? Colors.red.shade400
                                        : (isExpiringSoon ? Colors.orange.shade400 : Colors.green.shade400));
                                final bannerTextColor = isInGrace
                                    ? Colors.purple.shade300
                                    : (isExpired
                                        ? Colors.red.shade400
                                        : (isExpiringSoon ? Colors.orange.shade400 : Colors.green.shade500));
                                final icon = isInGrace
                                    ? Icons.hourglass_top_rounded
                                    : (isExpired ? Icons.warning_rounded : (isExpiringSoon ? Icons.alarm_rounded : Icons.verified_user_rounded));

                                return Container(
                                  margin: const EdgeInsets.only(top: 12),
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                  decoration: BoxDecoration(
                                    color: bannerBg,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: bannerBorder, width: 1.5),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(icon, color: bannerTextColor, size: 20),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              isInGrace
                                                  ? 'IN GRACE PERIOD • SEAT HELD'
                                                  : (isExpired ? 'MEMBERSHIP EXPIRED' : (isExpiringSoon ? 'EXPIRING SOON' : 'ACTIVE MEMBERSHIP')),
                                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: bannerTextColor, letterSpacing: 0.8),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: bannerTextColor.withValues(alpha: 0.15),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              isInGrace
                                                  ? 'Grace Active'
                                                  : (isExpired ? "Expired ${-days}d ago" : (days == 1 ? "1 day remaining" : "$days days remaining")),
                                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: bannerTextColor),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        'Plan End Date: ${DateFormat('dd MMMM yyyy').format(_studentPlanEndDate!)}',
                                        style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                                      ),
                                      if (_extendValidity && _studentPlanEndDate != null) ...[
                                        const SizedBox(height: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                                          decoration: BoxDecoration(
                                            color: Colors.blue.withValues(alpha: 0.15),
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(color: Colors.blue.shade400, width: 0.8),
                                          ),
                                          child: Row(
                                            children: [
                                              const Icon(Icons.bolt_rounded, color: Colors.blue, size: 16),
                                              const SizedBox(width: 6),
                                              Expanded(
                                                child: Text(
                                                  'Continuous Coverage: Queued from ${DateFormat('dd MMM yyyy').format(_getEffectiveStartDate())} → ${DateFormat('dd MMM yyyy').format(_calculateNewExpiryDate(plans))} (Covers grace days • Fixed billing cycle)',
                                                  style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Colors.blue),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                );
                              })
                            else if (!_isLoadingStudent)
                              Container(
                                margin: const EdgeInsets.only(top: 12),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                decoration: BoxDecoration(
                                  color: Colors.amber.shade900.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: Colors.amber.shade500, width: 1.5),
                                ),
                                child: const Row(
                                  children: [
                                    Icon(Icons.info_outline_rounded, color: Colors.amber, size: 20),
                                    SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text('MEMBERSHIP VALIDITY NOT ACTIVE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.amber, letterSpacing: 0.8)),
                                          SizedBox(height: 2),
                                          Text('Recording payment will automatically activate membership from today.', style: TextStyle(fontSize: 12)),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Plan Selector Dropdown
                    Builder(
                      builder: (ctx) {
                        final bool isKnownPlan = plans.any((p) => p.id == _selectedPlanId);
                        final String? dropdownValue = isKnownPlan
                            ? _selectedPlanId
                            : (_selectedPlanId == 'custom' ? 'custom' : (plans.isNotEmpty ? plans.first.id : 'custom'));

                        return DropdownButtonFormField<String>(
                          initialValue: dropdownValue,
                          decoration: const InputDecoration(
                            labelText: 'Membership Plan *',
                            prefixIcon: Icon(Icons.card_membership_rounded),
                            border: OutlineInputBorder(),
                            helperText: 'Select plan from catalog or configure custom plan',
                          ),
                          items: [
                            ...plans.map((p) {
                              return DropdownMenuItem(
                                value: p.id,
                                child: Text('${p.name} — ₹${p.price.toStringAsFixed(0)} (${p.duration} ${p.durationUnit.name})'),
                              );
                            }),
                            const DropdownMenuItem(
                              value: 'custom',
                              child: Row(
                                children: [
                                  Icon(Icons.tune_rounded, size: 18, color: Colors.indigo),
                                  SizedBox(width: 8),
                                  Text('Custom Plan (Custom Pricing & Duration)', style: TextStyle(fontWeight: FontWeight.w600)),
                                ],
                              ),
                            ),
                          ],
                          onChanged: (val) {
                            if (val == null) return;
                            setState(() {
                              _selectedPlanId = val;
                              if (val != 'custom') {
                                final matching = plans.where((p) => p.id == val);
                                if (matching.isNotEmpty) {
                                  final p = matching.first;
                                  _selectedPlanName = p.name;
                                  _totalFeeController.text = p.price.toStringAsFixed(0);
                                  if (!_isPartialPayment) {
                                    _amountController.text = p.price.toStringAsFixed(0);
                                  }
                                }
                              } else {
                                _selectedPlanName = _customPlanNameController.text.trim().isNotEmpty
                                    ? _customPlanNameController.text.trim()
                                    : 'Custom Plan';
                                _recalculateCustomFeeFromDailyRate(plans);
                              }
                            });
                          },
                        );
                      },
                    ),

                    // Smart Proration Banner for Catalog Plans
                    if (_selectedPlanId != null && _selectedPlanId != 'custom')
                      Builder(
                        builder: (ctx) {
                          final matching = plans.where((p) => p.id == _selectedPlanId);
                          if (matching.isEmpty) return const SizedBox.shrink();
                          final plan = matching.first;
                          final start = _getEffectiveStartDate();
                          final smartCalc = PlanCalculatorService.calculateSmartPlan(
                            plan: plan,
                            fromDate: start,
                          );

                          if (!smartCalc.isProrated) return const SizedBox.shrink();

                          final proratedStr = smartCalc.proratedPrice.toStringAsFixed(0);
                          final isApplied = _totalFeeController.text == proratedStr;

                          return Container(
                            margin: const EdgeInsets.only(top: 10),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.green.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.auto_awesome_rounded, size: 20, color: Colors.green),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _studentPlanEndDate == null
                                            ? '⚡ New Admission: ${smartCalc.daysRemaining} days in ${DateFormat('MMMM').format(smartCalc.endDate)}'
                                            : '⚡ Re-Admission Fresh Start: ${smartCalc.daysRemaining} days in ${DateFormat('MMMM').format(smartCalc.endDate)}',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: Colors.green),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        _studentPlanEndDate == null
                                            ? 'First-Time Joiner • Full: ₹${plan.price.toStringAsFixed(0)} • Fair Prorated: ₹$proratedStr (${smartCalc.formattedDailyRate})'
                                            : 'Returning After Gap • Full: ₹${plan.price.toStringAsFixed(0)} • Fair Prorated: ₹$proratedStr (${smartCalc.formattedDailyRate})',
                                        style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.green.shade800,
                                    side: BorderSide(color: isApplied ? Colors.green : Colors.green.shade400),
                                    backgroundColor: isApplied ? Colors.green.withValues(alpha: 0.15) : null,
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                  icon: Icon(isApplied ? Icons.check_circle_rounded : Icons.check_rounded, size: 14),
                                  label: Text(
                                    isApplied ? 'Applied' : 'Use ₹$proratedStr',
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                  ),
                                  onPressed: () {
                                    HapticFeedback.selectionClick();
                                    setState(() {
                                      _totalFeeController.text = proratedStr;
                                      if (!_isPartialPayment) {
                                        _amountController.text = proratedStr;
                                      }
                                    });
                                  },
                                ),
                              ],
                            ),
                          );
                        },
                      ),

                    // Custom Plan Configuration Studio (Inspired by leading SaaS membership apps)
                    if (_selectedPlanId == 'custom') ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primaryContainer.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: theme.colorScheme.primary.withValues(alpha: 0.35),
                            width: 1.2,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 1. Studio Header Banner
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.primary,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(Icons.tune_rounded, color: Colors.white, size: 16),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Custom Plan Studio',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                          color: theme.colorScheme.primary,
                                        ),
                                      ),
                                      Text(
                                        'Flexible validity, per-day rate & dynamic fee calculation',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: theme.colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.primary.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Text(
                                    'Dynamic Pricing',
                                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),

                            // 2. Custom Plan Name with Quick Presets
                            ValidatedTextField(
                              label: 'Custom Plan Name *',
                              controller: _customPlanNameController,
                              hint: 'e.g. 15-Day Exam Pass, Weekend Study Pass, Custom Monthly',
                              prefixIcon: const Icon(Icons.label_outline_rounded),
                              onChanged: (val) {
                                setState(() {
                                  _selectedPlanName = val.trim().isNotEmpty ? val.trim() : 'Custom Plan';
                                });
                              },
                              validator: (val) => (val == null || val.trim().isEmpty)
                                  ? 'Please enter a name for this custom plan'
                                  : null,
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children: [
                                '15-Day Revision Pass',
                                '30-Day Flex Pass',
                                'Exam Sprint',
                                'Weekend Pass',
                              ].map((preset) {
                                final isSelected = _customPlanNameController.text == preset;
                                return ActionChip(
                                  visualDensity: VisualDensity.compact,
                                  label: Text(
                                    preset,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: isSelected ? theme.colorScheme.primary : null,
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                    ),
                                  ),
                                  backgroundColor: isSelected ? theme.colorScheme.primary.withValues(alpha: 0.15) : null,
                                  onPressed: () {
                                    setState(() {
                                      _customPlanNameController.text = preset;
                                      _selectedPlanName = preset;
                                    });
                                  },
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 14),

                            // 3. Start Date Selection & Queue Row
                            Builder(
                              builder: (ctx) {
                                final effectiveStart = _getEffectiveStartDate();
                                final now = DateTime.now();
                                final isAdvance = _studentPlanEndDate != null && _studentPlanEndDate!.isAfter(now);
                                final isOverridden = _customStartDate != null;

                                return Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.surface,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.7)),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(Icons.calendar_month_rounded, size: 18, color: theme.colorScheme.primary),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                const Text(
                                                  'Start Date (Active From)',
                                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey),
                                                ),
                                                Text(
                                                  DateFormat('dd MMMM yyyy (EEEE)').format(effectiveStart),
                                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                                                ),
                                              ],
                                            ),
                                          ),
                                          OutlinedButton.icon(
                                            style: OutlinedButton.styleFrom(
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                              visualDensity: VisualDensity.compact,
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                            ),
                                            icon: const Icon(Icons.edit_calendar_rounded, size: 14),
                                            label: const Text('Change', style: TextStyle(fontSize: 11)),
                                            onPressed: () async {
                                              final picked = await showDatePicker(
                                                context: context,
                                                initialDate: effectiveStart,
                                                firstDate: DateTime(2024, 1, 1),
                                                lastDate: DateTime(2030, 12, 31),
                                              );
                                              if (picked != null) {
                                                setState(() {
                                                  _customStartDate = picked;
                                                  _recalculateCustomFeeFromDailyRate(plans);
                                                });
                                              }
                                            },
                                          ),
                                          if (isOverridden) ...[
                                            const SizedBox(width: 4),
                                            IconButton(
                                              tooltip: 'Reset to automatic start date',
                                              icon: const Icon(Icons.restart_alt_rounded, size: 18, color: Colors.redAccent),
                                              visualDensity: VisualDensity.compact,
                                              onPressed: () {
                                                setState(() {
                                                  _customStartDate = null;
                                                  _recalculateCustomFeeFromDailyRate(plans);
                                                });
                                              },
                                            ),
                                          ],
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        isOverridden
                                            ? '⚡ Manual start date override active'
                                            : (isAdvance
                                                ? '🔄 Continuous Queue: Auto-starts after active plan ends (${DateFormat('dd MMM yyyy').format(_studentPlanEndDate!)})'
                                                : '🟢 Immediate Activation: Starts today (${DateFormat('dd MMM yyyy').format(now)})'),
                                        style: TextStyle(
                                          fontSize: 10.5,
                                          color: isOverridden ? Colors.deepOrange : (isAdvance ? Colors.blue.shade700 : Colors.green.shade700),
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: 14),

                            // 4. Validity Duration Presets (User Requested: Today, Till Month End, or Capped Specific Date)
                            Text(
                              'Validity Duration (Max: Current Month End)',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Builder(
                              builder: (ctx) {
                                final effectiveStart = _getEffectiveStartDate();
                                final nextMonthFirst = DateTime(effectiveStart.year, effectiveStart.month + 1, 1);
                                final monthEnd = DateTime(nextMonthFirst.year, nextMonthFirst.month, 0);
                                final remainingDaysInMonth = monthEnd.difference(effectiveStart).inDays + 1;

                                return Wrap(
                                  spacing: 8,
                                  runSpacing: 6,
                                  children: [
                                    // 1. Today Only (1 Day Pass)
                                    ChoiceChip(
                                      avatar: const Icon(Icons.wb_sunny_rounded, size: 16),
                                      label: const Text('Today Only (1 Day)'),
                                      selected: _customDurationDays == 1 && _customCustomExpiryDate == null,
                                      onSelected: (selected) {
                                        if (selected) {
                                          setState(() {
                                            _customDurationDays = 1;
                                            _customCustomExpiryDate = null;
                                            _recalculateCustomFeeFromDailyRate(plans);
                                          });
                                        }
                                      },
                                    ),
                                    // 2. Till Month End (Snap to last calendar day of current month)
                                    ChoiceChip(
                                      avatar: const Icon(Icons.event_available_rounded, size: 16),
                                      label: Text('Till Month End ($remainingDaysInMonth Days)'),
                                      selected: _customDurationDays == 0 && _customCustomExpiryDate == null,
                                      onSelected: (selected) {
                                        if (selected) {
                                          setState(() {
                                            _customDurationDays = 0;
                                            _customCustomExpiryDate = null;
                                            _recalculateCustomFeeFromDailyRate(plans);
                                          });
                                        }
                                      },
                                    ),
                                    // 3. Intermediate chips if they fit within current month
                                    if (remainingDaysInMonth >= 7 && remainingDaysInMonth != 7)
                                      ChoiceChip(
                                        label: const Text('7 Days'),
                                        selected: _customDurationDays == 7 && _customCustomExpiryDate == null,
                                        onSelected: (selected) {
                                          if (selected) {
                                            setState(() {
                                              _customDurationDays = 7;
                                              _customCustomExpiryDate = null;
                                              _recalculateCustomFeeFromDailyRate(plans);
                                            });
                                          }
                                        },
                                      ),
                                    if (remainingDaysInMonth >= 15 && remainingDaysInMonth != 15)
                                      ChoiceChip(
                                        label: const Text('15 Days'),
                                        selected: _customDurationDays == 15 && _customCustomExpiryDate == null,
                                        onSelected: (selected) {
                                          if (selected) {
                                            setState(() {
                                              _customDurationDays = 15;
                                              _customCustomExpiryDate = null;
                                              _recalculateCustomFeeFromDailyRate(plans);
                                            });
                                          }
                                        },
                                      ),
                                    // 4. Pick Specific Date... (Strictly capped at current month end)
                                    ChoiceChip(
                                      avatar: const Icon(Icons.event_rounded, size: 16),
                                      label: Text(
                                        _customCustomExpiryDate != null
                                            ? DateFormat('dd MMM yyyy').format(_customCustomExpiryDate!)
                                            : 'Pick Specific Date...',
                                      ),
                                      selected: _customCustomExpiryDate != null,
                                      onSelected: (_) async {
                                        final picked = await showDatePicker(
                                          context: context,
                                          initialDate: _customCustomExpiryDate ?? monthEnd,
                                          firstDate: effectiveStart,
                                          lastDate: monthEnd,
                                          helpText: 'VALIDITY CAPPED TILL MONTH END',
                                        );
                                        if (picked != null) {
                                          setState(() {
                                            _customCustomExpiryDate = picked;
                                            _customDurationDays = picked.difference(effectiveStart).inDays + 1;
                                            _recalculateCustomFeeFromDailyRate(plans);
                                          });
                                        }
                                      },
                                    ),
                                  ],
                                );
                              },
                            ),
                            const SizedBox(height: 14),

                            // Sticky Concession / Recurring Override Container
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.surface,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.7)),
                              ),
                              child: Column(
                                children: [
                                  SwitchListTile.adaptive(
                                    contentPadding: EdgeInsets.zero,
                                    value: _isStickyCustomPrice,
                                    title: const Text('Recurring Concession for Monthly Renewals', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                                    subtitle: Text(
                                      _isStickyCustomPrice
                                          ? 'Student will be allowed to renew each month at this pre-approved ₹${_totalFeeController.text.isEmpty ? "0" : _totalFeeController.text} rate.'
                                          : 'One-time ad-hoc validity. After this custom plan ends, student renews on standard catalog plans.',
                                      style: const TextStyle(fontSize: 11),
                                    ),
                                    onChanged: (v) => setState(() => _isStickyCustomPrice = v),
                                  ),
                                  if (_isStickyCustomPrice) ...[
                                    const SizedBox(height: 8),
                                    ValidatedTextField(
                                      label: 'Concession / Approval Reason (Optional)',
                                      controller: _discountReasonController,
                                      hint: 'e.g. Scholarship, Hardship, Staff Ward',
                                      prefixIcon: const Icon(Icons.verified_user_outlined),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(height: 14),

                            // 5. Intelligent Per-Day Rate & Total Fee Studio
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Per Day Rate Field
                                Expanded(
                                  flex: 5,
                                  child: ValidatedTextField(
                                    label: 'Per-Day Rate (₹/day) *',
                                    controller: _dailyRateController,
                                    hint: '25',
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    prefixIcon: const Icon(Icons.speed_rounded),
                                    suffixText: '/ day',
                                    onChanged: (_) {
                                      setState(() {
                                        _recalculateCustomFeeFromDailyRate(plans);
                                      });
                                    },
                                    validator: (val) {
                                      final parsed = double.tryParse(val ?? '');
                                      if (parsed == null || parsed <= 0) return 'Invalid rate';
                                      if (parsed > 5000) return 'Max ₹5000/d';
                                      return null;
                                    },
                                  ),
                                ),
                                const SizedBox(width: 12),
                                // Total Plan Fee Field (Bidirectional sync)
                                Expanded(
                                  flex: 6,
                                  child: ValidatedTextField(
                                    label: 'Total Plan Fee (₹) *',
                                    controller: _totalFeeController,
                                    hint: 'Auto-calculated fee',
                                    keyboardType: TextInputType.number,
                                    inputFormatters: AppValidators.amountFormatters,
                                    prefixIcon: const Icon(Icons.currency_rupee_rounded),
                                    onChanged: (val) {
                                      setState(() {
                                        _recalculateDailyRateFromTotalFee(plans);
                                        if (!_isPartialPayment) {
                                          _amountController.text = val;
                                        }
                                      });
                                    },
                                    validator: (val) => AppValidators.amount(
                                      val,
                                      required: true,
                                      min: 1.0,
                                      max: 99999.0,
                                      label: 'Total fee',
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),

                            // Preset Rate Chips
                            Builder(
                              builder: (ctx) {
                                double? catalogMonthlyDailyRate;
                                for (final p in plans) {
                                  if (p.durationUnit == DurationUnit.months && p.duration == 1 ||
                                      p.name.toLowerCase().contains('month')) {
                                    if (p.price > 0) {
                                      catalogMonthlyDailyRate = p.price / 30.0;
                                      break;
                                    }
                                  }
                                }

                                final currentRate = double.tryParse(_dailyRateController.text) ?? 0.0;

                                return Wrap(
                                  spacing: 6,
                                  runSpacing: 4,
                                  children: [
                                    if (catalogMonthlyDailyRate != null)
                                      ActionChip(
                                        visualDensity: VisualDensity.compact,
                                        avatar: const Icon(Icons.storefront_rounded, size: 14),
                                        label: Text(
                                          'Base (₹${catalogMonthlyDailyRate.toStringAsFixed(1)}/d)',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: (currentRate - catalogMonthlyDailyRate).abs() < 0.2 ? theme.colorScheme.primary : null,
                                          ),
                                        ),
                                        backgroundColor: (currentRate - catalogMonthlyDailyRate).abs() < 0.2
                                            ? theme.colorScheme.primary.withValues(alpha: 0.15)
                                            : null,
                                        onPressed: () {
                                          setState(() {
                                            _dailyRateController.text = catalogMonthlyDailyRate!.toStringAsFixed(1);
                                            _recalculateCustomFeeFromDailyRate(plans);
                                          });
                                        },
                                      ),
                                    ...[20.0, 25.0, 30.0, 50.0].map((rate) {
                                      final isSelected = (currentRate - rate).abs() < 0.1;
                                      return ActionChip(
                                        visualDensity: VisualDensity.compact,
                                        label: Text(
                                          '₹${rate.toStringAsFixed(0)}/d${rate == 25.0 ? " (Standard)" : ""}',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                            color: isSelected ? theme.colorScheme.primary : null,
                                          ),
                                        ),
                                        backgroundColor: isSelected ? theme.colorScheme.primary.withValues(alpha: 0.15) : null,
                                        onPressed: () {
                                          setState(() {
                                            _dailyRateController.text = rate.toStringAsFixed(0);
                                            _recalculateCustomFeeFromDailyRate(plans);
                                          });
                                        },
                                      );
                                    }),
                                  ],
                                );
                              },
                            ),
                            const SizedBox(height: 12),

                            // 6. Live Validity & Pricing Formula Breakdown Banner
                            Builder(
                              builder: (ctx) {
                                final start = _getEffectiveStartDate();
                                final exp = _calculateNewExpiryDate(plans);
                                final diffDays = _calculateCustomDays(plans);
                                final dailyRate = double.tryParse(_dailyRateController.text) ?? 0.0;
                                final totalFee = _effectiveTotalFee;

                                return Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.surface,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: theme.colorScheme.outlineVariant),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          const Icon(Icons.auto_awesome_rounded, size: 16, color: Colors.orange),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              'Calculated Validity: ${DateFormat('dd MMM yyyy').format(start)} → ${DateFormat('dd MMM yyyy').format(exp)} ($diffDays days)',
                                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.green.withValues(alpha: 0.08),
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(color: Colors.green.withValues(alpha: 0.2)),
                                        ),
                                        child: Text(
                                          'Formula: $diffDays days × ₹${dailyRate.toStringAsFixed(1)}/day = ₹${totalFee.toStringAsFixed(0)} total fee',
                                          style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Colors.green),
                                        ),
                                      ),
                                      if (_isPartialPayment) ...[
                                        const SizedBox(height: 6),
                                        Text(
                                          'Partial Deposit: Paying ₹${_payingAmount.toStringAsFixed(0)} • Remaining Due: ₹${_calculatedRemainingDue.toStringAsFixed(0)}',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: _calculatedRemainingDue > 0 ? Colors.deepOrange : Colors.green,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ] else ...[
                      // Catalog Plan Summary Banner
                      Builder(
                        builder: (ctx) {
                          final matching = plans.where((p) => p.id == _selectedPlanId);
                          if (matching.isEmpty) return const SizedBox.shrink();
                          final p = matching.first;
                          final exp = _calculateNewExpiryDate(plans);
                          return Container(
                            margin: const EdgeInsets.only(top: 8),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: theme.dividerColor.withValues(alpha: 0.15)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.verified_rounded, size: 18, color: Color(0xFF059669)),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    '${p.name} • Standard Fee: ₹${p.price.toStringAsFixed(0)} • Expiry: ${DateFormat('dd MMM yyyy').format(exp)}',
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                    const SizedBox(height: 16),

                    // Partial Payment Toggle
                    SwitchListTile.adaptive(
                      title: const Text('Partial Payment / Instalment'),
                      subtitle: const Text('Record initial deposit and carry forward pending due'),
                      value: _isPartialPayment,
                      contentPadding: EdgeInsets.zero,
                      onChanged: (val) {
                        setState(() {
                          _isPartialPayment = val;
                          if (!val) {
                            _amountController.text = _effectiveTotalFee.toStringAsFixed(0);
                          }
                        });
                      },
                    ),
                    const SizedBox(height: 8),

                    if (_isPartialPayment && _selectedPlanId != 'custom') ...[
                      ValidatedTextField(
                        label: 'Total Plan Fee (₹) *',
                        controller: _totalFeeController,
                        keyboardType: TextInputType.number,
                        inputFormatters: AppValidators.amountFormatters,
                        prefixIcon: const Icon(Icons.receipt_outlined),
                        onChanged: (_) => setState(() {}),
                        validator: (val) => AppValidators.amount(
                          val,
                          required: true,
                          min: 1.0,
                          max: 99999.0,
                          label: 'Total fee',
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],

                    ValidatedTextField(
                      label: _isPartialPayment ? 'Paying Now (₹) *' : 'Amount Paid (₹) *',
                      controller: _amountController,
                      keyboardType: TextInputType.number,
                      inputFormatters: AppValidators.amountFormatters,
                      prefixIcon: const Icon(Icons.currency_rupee_rounded),
                      onChanged: (_) => setState(() {}),
                      validator: (val) {
                        final err = AppValidators.amount(
                          val,
                          required: true,
                          min: 1.0,
                          max: 99999.0,
                          label: 'Paying amount',
                        );
                        if (err != null) return err;
                        final num = double.tryParse(val!);
                        if (_isPartialPayment && num != null && num > _effectiveTotalFee) {
                          return 'Paying amount cannot exceed total fee';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 6),

                    // 1-Tap Quick Amount Chips
                    Wrap(
                      spacing: 8,
                      children: [
                        ActionChip(
                          avatar: const Icon(Icons.done_all_rounded, size: 16),
                          label: Text('Full: ₹${_effectiveTotalFee.toStringAsFixed(0)}'),
                          onPressed: () {
                            setState(() {
                              _amountController.text = _effectiveTotalFee.toStringAsFixed(0);
                            });
                          },
                        ),
                        ActionChip(
                          avatar: const Icon(Icons.pie_chart_outline_rounded, size: 16),
                          label: Text('50%: ₹${(_effectiveTotalFee / 2).toStringAsFixed(0)}'),
                          onPressed: () {
                            setState(() {
                              _isPartialPayment = true;
                              _amountController.text = (_effectiveTotalFee / 2).toStringAsFixed(0);
                            });
                          },
                        ),
                      ],
                    ),

                    if (_isPartialPayment) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.amber.shade400),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Remaining Due Balance:', style: TextStyle(fontWeight: FontWeight.w600)),
                            Text(
                              '₹${_calculatedRemainingDue.toStringAsFixed(0)}',
                              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.amber.shade900, fontSize: 16),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 16),

                    // Dynamic Payment Method Dropdown
                    DropdownButtonFormField<String>(
                      initialValue: _paymentMethods.contains(_paymentMethod) ? _paymentMethod : (_paymentMethods.isNotEmpty ? _paymentMethods.first : null),
                      decoration: const InputDecoration(
                        labelText: 'Payment Method *',
                        prefixIcon: Icon(Icons.payment_rounded),
                        border: OutlineInputBorder(),
                      ),
                      items: _paymentMethods.map((m) {
                        return DropdownMenuItem(value: m, child: Text(m));
                      }).toList(),
                      onChanged: (val) => setState(() => _paymentMethod = val!),
                      validator: (val) => val == null || val.isEmpty ? 'Select a payment method' : null,
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: () async {
                          await context.push(Routes.adminPaymentMethods);
                          _loadPaymentMethods();
                        },
                        icon: const Icon(Icons.settings_outlined, size: 14),
                        label: const Text('Manage Payment Modes', style: TextStyle(fontSize: 12)),
                      ),
                    ),
                    const SizedBox(height: 6),

                    // Dynamic Reference Details Based On Payment Method
                    if (_paymentMethod.toLowerCase() == 'cash')
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.green.shade400),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.payments_outlined, color: Colors.green.shade700),
                            const SizedBox(width: 10),
                            const Expanded(
                              child: Text(
                                '💵 Cash Payment: Verified & collected in person at reception.',
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                              ),
                            ),
                          ],
                        ),
                      )
                    else if (_paymentMethod.toLowerCase().contains('upi') || _paymentMethod.toLowerCase().contains('qr'))
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          ValidatedTextField(
                            label: 'UPI Reference / 12-Digit UTR Number *',
                            hint: 'e.g. 429182910281 or Txn Reference ID',
                            controller: _referenceController,
                            prefixIcon: const Icon(Icons.qr_code_2_rounded),
                            inputFormatters: AppValidators.utrFormatters,
                            validator: (v) => AppValidators.utr(v, required: true, label: 'UPI Reference / UTR'),
                          ),
                          const SizedBox(height: 8),
                          OutlinedButton.icon(
                            onPressed: _isScanningScreenshot ? null : _scanUpiScreenshot,
                            icon: _isScanningScreenshot
                                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                                : const Icon(Icons.document_scanner_rounded, size: 18),
                            label: Text(_isScanningScreenshot ? 'Scanning Screenshot with OCR...' : 'Auto-Fill from UPI Screenshot (OCR)'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Theme.of(context).colorScheme.primary,
                              side: BorderSide(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.4)),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                          ),
                        ],
                      )
                    else if (_paymentMethod.toLowerCase().contains('card'))
                      ValidatedTextField(
                        label: 'Card Last 4 Digits / POS Auth Code',
                        hint: 'e.g. 4821 or TXN-9821',
                        controller: _referenceController,
                        prefixIcon: const Icon(Icons.credit_card_rounded),
                        inputFormatters: AppValidators.utrFormatters,
                      )
                    else if (_paymentMethod.toLowerCase().contains('cheque') || _paymentMethod.toLowerCase().contains('dd'))
                      Column(
                        children: [
                          ValidatedTextField(
                            label: 'Cheque / DD Number *',
                            hint: 'e.g. 000492',
                            controller: _referenceController,
                            prefixIcon: const Icon(Icons.receipt_rounded),
                            keyboardType: TextInputType.number,
                            inputFormatters: AppValidators.chequeFormatters,
                            validator: (v) => AppValidators.chequeNumber(v, required: true),
                          ),
                          const SizedBox(height: 12),
                          ValidatedTextField(
                            label: 'Bank Name & Branch *',
                            hint: 'e.g. SBI Main Branch',
                            controller: _bankNameController,
                            prefixIcon: const Icon(Icons.account_balance_rounded),
                            textCapitalization: TextCapitalization.words,
                            validator: (v) => AppValidators.name(v, required: true, label: 'Bank Name'),
                          ),
                        ],
                      )
                    else
                      ValidatedTextField(
                        label: 'Transaction Reference / UTR Number',
                        hint: 'e.g. IMPS/NEFT Ref #',
                        controller: _referenceController,
                        inputFormatters: AppValidators.utrFormatters,
                        prefixIcon: const Icon(Icons.tag_rounded),
                      ),

                    const SizedBox(height: 16),

                    // Extend Validity Switch & Calendar Month Option
                    Builder(builder: (context) {
                      final isAdvance = _studentPlanEndDate != null && _studentPlanEndDate!.isAfter(DateTime.now());

                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SwitchListTile.adaptive(
                              title: const Text('Update & Extend Membership Validity', style: TextStyle(fontWeight: FontWeight.w600)),
                              subtitle: Text(
                                _extendValidity
                                    ? 'New expiry date: ${DateFormat('dd MMMM yyyy').format(_calculateNewExpiryDate(plans))}${isAdvance ? " (⚡ Continuous queue from ${DateFormat('dd MMM yyyy').format(_studentPlanEndDate!.add(const Duration(days: 1)))})" : ""}'
                                    : 'Paying current plan due — current cycle remains active till ${DateFormat('dd MMM yyyy').format(_studentPlanEndDate ?? DateTime.now())}. (Turn ON to extend validity)',
                              ),
                              value: _extendValidity,
                              contentPadding: EdgeInsets.zero,
                              onChanged: (val) => setState(() => _extendValidity = val),
                            ),
                            if (_extendValidity) ...[
                              Builder(builder: (context) {
                                final effectiveDesk = _studentSeatId ?? _studentPreviousSeatId;
                                if (effectiveDesk == null || effectiveDesk.isEmpty) return const SizedBox.shrink();
                                return Column(
                                  children: [
                                    const Divider(height: 16),
                                    Row(
                                      children: [
                                        Icon(Icons.chair_rounded, size: 16, color: theme.colorScheme.primary),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            _studentSeatId != null
                                                ? 'Seat Continuity: Retains Seat ${SeatHelper.formatSeatLabel(seatId: _studentSeatId)} ✓'
                                                : 'Seat Recovery: Will auto-reclaim previous Seat ${SeatHelper.formatSeatLabel(seatId: _studentPreviousSeatId)} if free ✓',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: theme.colorScheme.primary,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                );
                              }),
                            ],
                          ],
                        ),
                      );
                    }),
                    const SizedBox(height: 16),

                    ValidatedTextField(
                      label: 'Admin Notes (Optional)',
                      controller: _notesController,
                      prefixIcon: const Icon(Icons.note_alt_outlined),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 16),

                    // Receipt Generation Toggle
                    SwitchListTile.adaptive(
                      title: const Text('Generate Official Receipt'),
                      subtitle: const Text('Issues sequential receipt number and PDF record'),
                      value: _generateReceipt,
                      contentPadding: EdgeInsets.zero,
                      onChanged: (val) => setState(() => _generateReceipt = val),
                    ),
                    const SizedBox(height: 24),

                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: FilledButton.icon(
                        onPressed: _isLoading ? null : () => _save(plans),
                        icon: _isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.receipt_long_rounded),
                        label: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            _isLoading
                                ? 'Recording Payment...'
                                : (_generateReceipt
                                    ? (_isPartialPayment
                                        ? 'Record Instalment & Generate Receipt'
                                        : 'Record Payment & Generate Receipt')
                                    : (_isPartialPayment
                                        ? 'Record Instalment (No Receipt)'
                                        : 'Record Payment (No Receipt)')),
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  void _openSettingsSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
                child: Row(
                  children: [
                    const Icon(Icons.settings_suggest_rounded),
                    const SizedBox(width: 8),
                    Text('Payment & Receipt Settings', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.receipt_long_rounded, color: Colors.indigo),
                title: const Text('Customize Receipt Template'),
                subtitle: const Text('Configure official stamp, watermark, custom terms & footer'),
                onTap: () {
                  Navigator.pop(ctx);
                  context.push(Routes.adminReceiptTemplate);
                },
              ),
              ListTile(
                leading: const Icon(Icons.payment_rounded, color: Colors.teal),
                title: const Text('Manage Payment Modes'),
                subtitle: const Text('Enable / disable payment modes or add custom payment types'),
                onTap: () async {
                  Navigator.pop(ctx);
                  await context.push(Routes.adminPaymentMethods);
                  _loadPaymentMethods();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
