import 'dart:convert';
import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:study_library/core/providers/library_provider.dart';
import 'package:study_library/features/students/presentation/providers/student_providers.dart';
import 'package:study_library/features/plans/presentation/providers/plan_providers.dart';
import 'package:study_library/models/plan_model.dart';
import 'package:study_library/models/student_model.dart';
import 'package:study_library/services/expiry_scheduler_service.dart';
import 'package:study_library/services/plan_calculator_service.dart';
import 'package:study_library/core/utils/seat_helper.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:study_library/core/error/error_handler.dart';
import 'package:study_library/core/widgets/pressable_scale.dart';
import 'package:study_library/services/image_service.dart';
import 'package:study_library/core/router/app_router.dart';
import 'package:study_library/services/app_notification_service.dart';
import 'package:study_library/core/utils/error_formatter.dart';
import 'package:study_library/core/utils/file_download_helper.dart';

enum RenewalTiming { advance, continuousGrace, immediate }
enum RenewalPaymentMode { upi, bank, deskCash }

class RenewPlanScreen extends ConsumerStatefulWidget {
  const RenewPlanScreen({super.key});

  @override
  ConsumerState<RenewPlanScreen> createState() => _RenewPlanScreenState();
}

class _RenewPlanScreenState extends ConsumerState<RenewPlanScreen> with WidgetsBindingObserver {
  String? _selectedPlanId;
  bool _keepSeat = true;
  bool _isBridgeSelected = false;
  RenewalTiming _timingMode = RenewalTiming.advance;
  RenewalPaymentMode _paymentMode = RenewalPaymentMode.upi;
  bool _forceLockedQr = false;

  final _notesController = TextEditingController();
  final _transactionRefController = TextEditingController();
  bool _isSubmitting = false;
  String? _paymentProofDataUrl;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Restore draft if user was interrupted or switched to UPI app
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _restoreDraft();
      _checkClipboardForUtr();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _notesController.dispose();
    _transactionRefController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Auto-detect UTR when student returns from Google Pay, PhonePe, or Bank app
      _checkClipboardForUtr();
    } else if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      // Auto-save draft before Android process suspension / app switch
      _saveDraft();
    }
  }

  Future<void> _saveDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final draft = {
        'selectedPlanId': _selectedPlanId,
        'keepSeat': _keepSeat,
        'isBridgeSelected': _isBridgeSelected,
        'paymentMode': _paymentMode.name,
        'notes': _notesController.text,
        'transactionRef': _transactionRefController.text,
        'savedAt': DateTime.now().millisecondsSinceEpoch,
      };
      await prefs.setString('renewal_draft_cache', jsonEncode(draft));
    } catch (_) {}
  }

  Future<void> _restoreDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('renewal_draft_cache');
      if (raw == null || raw.isEmpty) return;

      final draft = jsonDecode(raw) as Map<String, dynamic>;
      final savedAt = draft['savedAt'] as int?;
      // Expire draft if older than 24 hours
      if (savedAt != null && DateTime.now().millisecondsSinceEpoch - savedAt > 86400000) {
        await prefs.remove('renewal_draft_cache');
        return;
      }

      if (mounted) {
        setState(() {
          if (draft['selectedPlanId'] != null) {
            _selectedPlanId = draft['selectedPlanId'].toString();
          }
          if (draft['keepSeat'] is bool) {
            _keepSeat = draft['keepSeat'] as bool;
          }
          if (draft['isBridgeSelected'] is bool) {
            _isBridgeSelected = draft['isBridgeSelected'] as bool;
          }
          if (draft['paymentMode'] != null) {
            _paymentMode = RenewalPaymentMode.values.firstWhere(
              (m) => m.name == draft['paymentMode'],
              orElse: () => RenewalPaymentMode.upi,
            );
          }
          if (draft['notes'] != null && _notesController.text.isEmpty) {
            _notesController.text = draft['notes'].toString();
          }
          if (draft['transactionRef'] != null && _transactionRefController.text.isEmpty) {
            _transactionRefController.text = draft['transactionRef'].toString();
          }
        });
      }
    } catch (_) {}
  }

  Future<void> _clearDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('renewal_draft_cache');
    } catch (_) {}
  }

  Future<void> _checkClipboardForUtr({bool showFeedbackIfEmpty = false}) async {
    try {
      final clipData = await Clipboard.getData(Clipboard.kTextPlain);
      final text = clipData?.text?.trim() ?? '';
      if (text.isEmpty) {
        if (showFeedbackIfEmpty && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Clipboard is empty. Copy the 12-digit UTR from your UPI or Bank app.'),
              behavior: SnackBarBehavior.floating,
              duration: Duration(seconds: 2),
            ),
          );
        }
        return;
      }

      // Check for 12 numeric digits (Standard NPCI UPI UTR format)
      final match = RegExp(r'\b\d{12}\b').firstMatch(text);
      if (match != null) {
        final utr = match.group(0)!;
        if (_transactionRefController.text.trim() != utr) {
          setState(() {
            _transactionRefController.text = utr;
          });
          HapticFeedback.mediumImpact();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text('✨ Auto-detected & applied 12-digit UTR: $utr'),
                    ),
                  ],
                ),
                backgroundColor: const Color(0xFF0D9488),
                behavior: SnackBarBehavior.floating,
                duration: const Duration(seconds: 4),
              ),
            );
          }
        } else if (showFeedbackIfEmpty && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('UTR $utr is already applied in the field.'),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } else if (showFeedbackIfEmpty && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No 12-digit UPI UTR found on clipboard.'),
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (_) {}
  }

  Future<void> _saveQrImage(String qrData, String amount) async {
    try {
      final painter = QrPainter(
        data: qrData,
        version: QrVersions.auto,
        gapless: true,
        eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: Color(0xFF000000)),
        dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: Color(0xFF000000)),
      );
      final byteData = await painter.toImageData(600);
      if (byteData != null) {
        final bytes = byteData.buffer.asUint8List();
        await FileDownloadHelper.downloadFile(
          fileName: 'cozy_corner_payment_qr.png',
          bytes: bytes,
          mimeType: 'image/png',
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('QR Code saved to Gallery / Downloads! Open PhonePe -> Scanner -> Gallery icon to pay.'),
              backgroundColor: Color(0xFF059669),
              behavior: SnackBarBehavior.floating,
              duration: Duration(seconds: 4),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save QR: ${AppErrorFormatter.toUserFriendly(e, actionContext: "payment")}'),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _submitRenewal({
    required String libraryId,
    required StudentModel student,
    required PlanModel selectedPlan,
    required RenewalCalculation renewalCalc,
    required double? origPrice,
    required bool hasDiscount,
    RenewalPaymentMode? activePaymentMode,
  }) async {
    final mode = activePaymentMode ?? _paymentMode;
    if (mode == RenewalPaymentMode.upi) {
      final utr = _transactionRefController.text.trim();
      if (utr.isEmpty) {
        HapticFeedback.lightImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please enter your 12-digit UPI UTR / Transaction Reference number'),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
      if (!RegExp(r'^\d{12}$').hasMatch(utr)) {
        HapticFeedback.lightImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Invalid UTR format: UPI UTR must be exactly 12 numeric digits (e.g. 431289567123).'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
    } else if (mode == RenewalPaymentMode.bank && _transactionRefController.text.trim().isEmpty) {
      HapticFeedback.lightImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter your Bank Transfer UTR / Transaction Reference number'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final refNumberStr = mode == RenewalPaymentMode.deskCash
          ? 'Desk Cash Payment Requested'
          : _transactionRefController.text.trim();

      // Guard: Duplicate UTR Check (Guards against reused or duplicate payment references)
      if (mode == RenewalPaymentMode.upi || (mode == RenewalPaymentMode.bank && refNumberStr.isNotEmpty)) {
        // 1. Check if UTR already exists in completed payments
        final dupPaymentSnap = await FirebaseFirestore.instance
            .collection('libraries')
            .doc(libraryId)
            .collection('payments')
            .where('referenceNumber', isEqualTo: refNumberStr)
            .limit(1)
            .get();

        if (dupPaymentSnap.docs.isNotEmpty) {
          if (mounted) {
            HapticFeedback.heavyImpact();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('⚠️ This UTR has already been recorded on a previous payment. Please verify your transaction reference number.'),
                backgroundColor: Colors.redAccent,
                behavior: SnackBarBehavior.floating,
                duration: Duration(seconds: 5),
              ),
            );
          }
          return;
        }

        // 2. Check if UTR is already in another pending renewal or admission request
        final dupReqSnap = await FirebaseFirestore.instance
            .collection('libraries')
            .doc(libraryId)
            .collection('requests')
            .where('referenceNumber', isEqualTo: refNumberStr)
            .limit(2)
            .get();

        for (final doc in dupReqSnap.docs) {
          final reqStatus = (doc.data()['status'] ?? '').toString().toLowerCase();
          if (reqStatus == 'pending' || reqStatus == 'approved') {
            if (mounted) {
              HapticFeedback.heavyImpact();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('⚠️ A renewal or admission request with this UTR is already under review or approved. Please verify your reference number.'),
                  backgroundColor: Colors.redAccent,
                  behavior: SnackBarBehavior.floating,
                  duration: Duration(seconds: 5),
                ),
              );
            }
            return;
          }
        }
      }

      final startDate = renewalCalc.startDate;
      final endDate = renewalCalc.endDate;
      final carriedDue = (student.pendingDueBalance != null && student.pendingDueBalance! > 0)
          ? student.pendingDueBalance!
          : 0.0;
      final amount = renewalCalc.price + carriedDue;
      final isAdvance = renewalCalc.type == RenewalType.advance;
      final isContinuousGrace = renewalCalc.type == RenewalType.backdatedGrace;
      final isGapRenewal = renewalCalc.type == RenewalType.gapRenewal;

      final paymentMethodStr = mode == RenewalPaymentMode.upi
          ? 'upi'
          : (mode == RenewalPaymentMode.bank ? 'bank' : 'desk_cash');
      final paymentLabelStr = mode == RenewalPaymentMode.upi
          ? 'UPI / QR Code'
          : (mode == RenewalPaymentMode.bank
              ? 'Direct Bank Transfer (NEFT/IMPS)'
              : 'Pay at Desk / Reception');
      final statusStr = mode == RenewalPaymentMode.deskCash
          ? 'desk_payment_pending'
          : 'pending';

      await FirebaseFirestore.instance
          .collection('libraries')
          .doc(libraryId)
          .collection('requests')
          .add({
        'type': 'renewal',
        'studentId': student.id,
        'studentName': student.name,
        'studentPhone': student.phone,
        'studentUserId': student.userId ?? FirebaseAuth.instance.currentUser?.uid ?? '',
        'userId': FirebaseAuth.instance.currentUser?.uid ?? student.userId ?? '',
        'requestedPlanId': selectedPlan.id,
        'requestedPlanName': selectedPlan.name,
        'amount': amount,
        'basePlanPrice': renewalCalc.price,
        'pendingDueAmount': carriedDue,
        'clearedDue': carriedDue > 0,
        'planOriginalPrice': selectedPlan.price,
        'originalPrice': origPrice,
        'discountAmount': hasDiscount && origPrice != null ? (origPrice - selectedPlan.price) : 0.0,
        'currentSeatId': student.seatId ?? student.previousSeatId,
        'currentSectionId': student.sectionId ?? student.previousSectionId,
        'keepSeat': _keepSeat,
        'retainSeat': _keepSeat,
        'isAdvanceRenewal': isAdvance,
        'isContinuousGraceRenewal': isContinuousGrace,
        'isGapRenewal': isGapRenewal,
        'isBridgeBundle': _isBridgeSelected,
        'renewalType': renewalCalc.type.name,
        'renewalExplanation': renewalCalc.explanation,
        'cycleStartDate': Timestamp.fromDate(startDate),
        'cycleEndDate': Timestamp.fromDate(endDate),
        'paymentMethod': paymentMethodStr,
        'paymentModeLabel': paymentLabelStr,
        'referenceNumber': refNumberStr,
        'paymentProofUrl': _paymentProofDataUrl,
        'notes': _notesController.text.trim(),
        'status': statusStr,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Dispatch admin in-app notification
      AppNotificationService.sendNotification(
        libraryId: libraryId,
        title: 'Plan Renewal Submitted • ₹${amount.toStringAsFixed(0)}',
        body: '${student.name} requested renewal for ${selectedPlan.name} ($paymentLabelStr).',
        type: 'renewal',
        targetRole: 'admin',
        actionRoute: Routes.adminRequests,
      ).ignore();

      // Cancel local expiry reminders until renewed cycle begins
      ExpirySchedulerService.cancelExpiryReminders().ignore();

      if (mounted) {
        HapticFeedback.heavyImpact();
        final successMsg = mode == RenewalPaymentMode.deskCash
            ? 'Desk payment renewal registered! Please deposit fee at the reception counter to activate.'
            : (mode == RenewalPaymentMode.bank
                ? 'Bank transfer renewal request submitted! Library admin will verify your payment and activate your seat.'
                : 'Renewal request submitted! Library admin will verify your payment and activate your membership.');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(successMsg),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 4),
          ),
        );
        await _clearDraft();
        if (mounted) Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        AppErrorFormatter.showErrorSnackBar(context, e, actionContext: 'request');
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final studentAsync = ref.watch(currentStudentProvider);
    final plansAsync = ref.watch(plansStreamProvider);
    final libraryId = ref.watch(currentLibraryIdProvider);
    final dateFormat = DateFormat('dd MMM yyyy');

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back',
          onPressed: () => context.canPop() ? context.pop() : context.go(Routes.studentHome),
        ),
        title: const Text('Renew Membership'),
        centerTitle: true,
      ),
      body: studentAsync.when(
        data: (student) {
          if (student == null || libraryId == null) {
            return const Center(child: Text('Student profile not found. Please log in again.'));
          }

          return plansAsync.when(
            data: (plans) {
              final List<PlanModel> activePlans = [
                if (student.isStickyCustomPrice && student.customPlanFee != null)
                  PlanModel(
                    id: 'custom',
                    libraryId: libraryId,
                    name: student.customPlanName?.isNotEmpty == true
                        ? student.customPlanName!
                        : 'Approved Concession',
                    price: student.customPlanFee!,
                    duration: 1,
                    durationUnit: DurationUnit.months,
                    description: student.customDiscountReason?.isNotEmpty == true
                        ? 'Approved Concession: ${student.customDiscountReason}'
                        : 'Pre-approved special recurring concession rate',
                    gracePeriodDays: 0,
                    isActive: true,
                    isFeatured: true,
                    displayOrder: 0,
                  ),
                ...plans.where((p) => p.isActive),
              ];

              if (_selectedPlanId == null && activePlans.isNotEmpty) {
                // Default to approved sticky custom plan if active, or current plan, else first active plan
                final hasStickyCustom = student.isStickyCustomPrice && student.customPlanFee != null;
                if (hasStickyCustom) {
                  _selectedPlanId = 'custom';
                } else {
                  final currentMatches = activePlans.any((p) => p.id == student.planId);
                  _selectedPlanId = currentMatches ? student.planId : activePlans.first.id;
                }
              }

              final selectedPlan = activePlans.where((p) => p.id == _selectedPlanId).firstOrNull ??
                  (activePlans.isNotEmpty ? activePlans.first : null);

              final baseMonthly = PlanCalculatorService.getBaseMonthlyPrice(activePlans);

              final isCurrentPlanActive = student.planEndDate != null && student.planEndDate!.isAfter(DateTime.now());
              final isInGrace = student.effectiveMembershipStatus == MembershipStatus.grace;
              if (!isCurrentPlanActive && _timingMode == RenewalTiming.advance) {
                _timingMode = RenewalTiming.continuousGrace;
              } else if (isCurrentPlanActive && _timingMode == RenewalTiming.continuousGrace) {
                _timingMode = RenewalTiming.advance;
              }

              final renewalCalc = selectedPlan != null
                  ? PlanCalculatorService.calculateRenewal(
                      student: student,
                      plan: selectedPlan,
                      chooseBridgeBundle: _isBridgeSelected,
                    )
                  : null;
              final startDate = renewalCalc?.startDate ?? DateTime.now();
              final endDate = renewalCalc?.endDate ?? DateTime.now();
              final baseRenewalPrice = renewalCalc?.price ?? (selectedPlan?.price ?? 0.0);
              final carriedDueBalance = (student.pendingDueBalance != null && student.pendingDueBalance! > 0)
                  ? student.pendingDueBalance!
                  : 0.0;
              final effectivePrice = baseRenewalPrice + carriedDueBalance;
              final effectiveDeskId = student.seatId ?? student.previousSeatId;
              final isReclaiming = student.seatId == null && student.previousSeatId != null;

              return ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                children: [
                  // Current Plan Status Summary
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isCurrentPlanActive
                          ? Colors.teal.withValues(alpha: 0.08)
                          : (isInGrace ? Colors.purple.withValues(alpha: 0.08) : Colors.orange.withValues(alpha: 0.08)),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isCurrentPlanActive
                            ? Colors.teal.withValues(alpha: 0.3)
                            : (isInGrace ? Colors.purple.withValues(alpha: 0.3) : Colors.orange.withValues(alpha: 0.3)),
                      ),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: isCurrentPlanActive
                              ? Colors.teal
                              : (isInGrace ? Colors.purple : Colors.orange),
                          radius: 20,
                          child: Icon(
                            isCurrentPlanActive
                                ? Icons.verified_rounded
                                : (isInGrace ? Icons.hourglass_top_rounded : Icons.history_rounded),
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isCurrentPlanActive
                                    ? 'Current Membership Active'
                                    : (isInGrace ? 'Membership in Grace Period (Seat Held)' : 'Membership Expired'),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: isCurrentPlanActive
                                      ? Colors.teal.shade800
                                      : (isInGrace ? Colors.purple.shade900 : Colors.orange.shade900),
                                ),
                              ),
                              if (student.planEndDate != null)
                                Text(
                                  isCurrentPlanActive
                                      ? 'Valid until ${dateFormat.format(student.planEndDate!)} • ${SeatHelper.formatSeatLabel(seatId: student.seatId)}'
                                      : (isInGrace
                                          ? 'Plan ended on ${dateFormat.format(student.planEndDate!)} • Desk held during grace'
                                          : 'Expired on ${dateFormat.format(student.planEndDate!)}'),
                                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (carriedDueBalance > 0) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.amber.shade400),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.account_balance_wallet_rounded, color: Colors.amber.shade900, size: 24),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Previous Pending Dues: ₹${carriedDueBalance.toStringAsFixed(0)}',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: Colors.amber.shade900),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Plan Fee (₹${baseRenewalPrice.toStringAsFixed(0)}) + Carried Due (₹${carriedDueBalance.toStringAsFixed(0)}) = Total ₹${effectivePrice.toStringAsFixed(0)}. Past balance will be settled upon approval.',
                                  style: TextStyle(fontSize: 12, color: Colors.amber.shade900.withValues(alpha: 0.9), height: 1.3),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (effectiveDeskId != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFF0F766E).withValues(alpha: 0.12),
                            const Color(0xFF0D9488).withValues(alpha: 0.05),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFF14B8A6).withValues(alpha: 0.35)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0D9488).withValues(alpha: 0.18),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.shield_rounded, color: Color(0xFF0D9488), size: 22),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        '🔒 ${SeatHelper.formatSeatLabel(seatId: effectiveDeskId)} Held For You',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F766E)),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF0D9488).withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: const Text(
                                        'Guaranteed',
                                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF0D9488)),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  isReclaiming
                                      ? 'Reclaim your previous seat immediately upon renewal with zero disruption.'
                                      : 'Your dedicated desk is protected. Renewing keeps this exact spot without paperwork.',
                                  style: TextStyle(fontSize: 11.5, color: Colors.grey.shade700, height: 1.3),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),

                  // Section Header: Available Plans
                  Row(
                    children: [
                      Icon(Icons.stars_rounded, color: theme.colorScheme.primary, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Select Renewal Plan',
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  if (activePlans.isEmpty)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(24.0),
                        child: Center(child: Text('No active study plans configured by library.')),
                      ),
                    )
                  else
                    ...activePlans.map((plan) {
                      final isSelected = _selectedPlanId == plan.id;
                      final origPrice = plan.getEffectiveOriginalPrice(baseMonthlyPrice: baseMonthly);
                      final discPercent = plan.getDiscountPercent(baseMonthlyPrice: baseMonthly);
                      final savings = plan.getSavingsAmount(baseMonthlyPrice: baseMonthly);
                      final hasDiscount = origPrice != null && origPrice > plan.price;
                      final dailyRate = PlanCalculatorService.getDailyRate(plan);

                      return PressableScale(
                        scaleFactor: 0.97,
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() => _selectedPlanId = plan.id);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 240),
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? theme.colorScheme.primaryContainer.withValues(alpha: 0.28)
                                : theme.colorScheme.surface,
                            gradient: isSelected
                                ? LinearGradient(
                                    colors: [
                                      theme.colorScheme.primaryContainer.withValues(alpha: 0.38),
                                      theme.colorScheme.surface,
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  )
                                : null,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isSelected ? theme.colorScheme.primary : theme.colorScheme.outlineVariant,
                              width: isSelected ? 2 : 1,
                            ),
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: theme.colorScheme.primary.withValues(alpha: 0.2),
                                      blurRadius: 12,
                                      spreadRadius: 1,
                                      offset: const Offset(0, 3),
                                    )
                                  ]
                                : [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.02),
                                      blurRadius: 4,
                                      offset: const Offset(0, 1),
                                    ),
                                  ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Custom Animated Radio Check Indicator
                                  Padding(
                                    padding: const EdgeInsets.only(top: 2, right: 8),
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 200),
                                      width: 22,
                                      height: 22,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: isSelected ? theme.colorScheme.primary : Colors.transparent,
                                        border: Border.all(
                                          color: isSelected ? theme.colorScheme.primary : theme.colorScheme.outlineVariant,
                                          width: isSelected ? 2 : 1.5,
                                        ),
                                      ),
                                      child: isSelected
                                          ? const Center(
                                              child: Icon(Icons.check_rounded, size: 14, color: Colors.white),
                                            )
                                          : null,
                                    ),
                                  ),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Text(
                                              plan.displayName,
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16,
                                                color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurface,
                                              ),
                                            ),
                                            if (plan.isFeatured) ...[
                                              const SizedBox(width: 8),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  gradient: const LinearGradient(
                                                    colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
                                                  ),
                                                  borderRadius: BorderRadius.circular(6),
                                                  boxShadow: [
                                                    BoxShadow(
                                                      color: Colors.amber.withValues(alpha: 0.3),
                                                      blurRadius: 4,
                                                      offset: const Offset(0, 1),
                                                    ),
                                                  ],
                                                ),
                                                child: const Text(
                                                  'POPULAR',
                                                  style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '${plan.duration} ${plan.durationUnit.name} • ₹${dailyRate.toStringAsFixed(1)}/day',
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: Colors.grey.shade700,
                                            fontFeatures: const [FontFeature.tabularFigures()],
                                          ),
                                        ),
                                        if (plan.description.isNotEmpty) ...[
                                          const SizedBox(height: 4),
                                          Text(
                                            plan.description,
                                            style: TextStyle(fontSize: 12, color: theme.colorScheme.outline),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),

                                  // Pricing display with MRP Strikethrough & Discount %
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      if (hasDiscount) ...[
                                        Text(
                                          '₹${origPrice.toStringAsFixed(0)}',
                                          style: TextStyle(
                                            decoration: TextDecoration.lineThrough,
                                            decorationColor: Colors.grey.shade500,
                                            color: Colors.grey.shade500,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                            fontFeatures: const [FontFeature.tabularFigures()],
                                          ),
                                        ),
                                        const SizedBox(height: 1),
                                      ],
                                      Text(
                                        '₹${plan.price.toStringAsFixed(0)}',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 18,
                                          color: hasDiscount ? Colors.green.shade800 : theme.colorScheme.onSurface,
                                          fontFeatures: const [FontFeature.tabularFigures()],
                                        ),
                                      ),
                                      if (hasDiscount && discPercent != null) ...[
                                        const SizedBox(height: 3),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.green.shade50,
                                            border: Border.all(color: Colors.green.shade600, width: 0.8),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            '$discPercent% OFF',
                                            style: TextStyle(
                                              color: Colors.green.shade800,
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              fontFeatures: const [FontFeature.tabularFigures()],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                              if (hasDiscount && savings != null && savings > 0) ...[
                                const SizedBox(height: 8),
                                Padding(
                                  padding: const EdgeInsets.only(left: 30),
                                  child: Text(
                                    (plan.durationUnit == DurationUnit.months && plan.duration > 1) ||
                                            (plan.durationUnit == DurationUnit.days && plan.duration > 31)
                                        ? '🎉 Save ₹${savings.toStringAsFixed(0)} compared to paying monthly'
                                        : '🎉 Save ₹${savings.toStringAsFixed(0)} with special library discount',
                                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.green.shade700),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    }),
                  const SizedBox(height: 16),

                  // Smart Calendar Schedule & Continuity Guarantee
                  if (renewalCalc != null) ...[
                    Row(
                      children: [
                        Icon(Icons.bolt_rounded, color: theme.colorScheme.primary, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Renewal Schedule',
                          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: BorderSide(
                          color: renewalCalc.type == RenewalType.advance
                              ? Colors.teal.withValues(alpha: 0.4)
                              : (renewalCalc.type == RenewalType.backdatedGrace
                                  ? Colors.purple.withValues(alpha: 0.4)
                                  : Colors.orange.withValues(alpha: 0.4)),
                        ),
                      ),
                      color: renewalCalc.type == RenewalType.advance
                          ? Colors.teal.withValues(alpha: 0.05)
                          : (renewalCalc.type == RenewalType.backdatedGrace
                              ? Colors.purple.withValues(alpha: 0.05)
                              : Colors.orange.withValues(alpha: 0.05)),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CircleAvatar(
                              backgroundColor: renewalCalc.type == RenewalType.advance
                                  ? Colors.teal
                                  : (renewalCalc.type == RenewalType.backdatedGrace
                                      ? Colors.purple
                                      : Colors.orange),
                              radius: 18,
                              child: Icon(
                                renewalCalc.type == RenewalType.advance
                                    ? Icons.verified_rounded
                                    : (renewalCalc.type == RenewalType.backdatedGrace
                                        ? Icons.hourglass_top_rounded
                                        : Icons.replay_rounded),
                                color: Colors.white,
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    renewalCalc.type == RenewalType.advance
                                        ? 'Seamless Renewal (Continuous Access)'
                                        : (renewalCalc.type == RenewalType.backdatedGrace
                                            ? 'Courtesy Retention Period (Seat Protected)'
                                            : (renewalCalc.type == RenewalType.gapRenewal
                                                ? 'Fresh Start (After Study Break)'
                                                : 'New Membership Period')),
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: renewalCalc.type == RenewalType.advance
                                          ? Colors.teal.shade900
                                          : (renewalCalc.type == RenewalType.backdatedGrace
                                              ? Colors.purple.shade900
                                              : Colors.orange.shade900),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    renewalCalc.explanation,
                                    style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Bridge Bundle Toggle (Triggered when joining on/after Day 20 for gap or fresh renewals)
                    if (renewalCalc.smartCalc.hasBridgeOption) ...[
                      Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: BorderSide(
                            color: _isBridgeSelected ? Colors.deepOrange : theme.colorScheme.outlineVariant,
                            width: _isBridgeSelected ? 2 : 1,
                          ),
                        ),
                        color: _isBridgeSelected ? Colors.deepOrange.withValues(alpha: 0.08) : theme.cardColor,
                        child: SwitchListTile(
                          secondary: CircleAvatar(
                            backgroundColor: _isBridgeSelected ? Colors.deepOrange : Colors.grey.shade200,
                            radius: 18,
                            child: Icon(
                              Icons.auto_awesome_rounded,
                              color: _isBridgeSelected ? Colors.white : Colors.grey.shade600,
                              size: 18,
                            ),
                          ),
                          title: const Text(
                            'Month-End Combined Pass (Available from Day 20)',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                          ),
                          subtitle: Text(
                            'Pay for remaining days of this month (${renewalCalc.smartCalc.daysRemaining}d) + full next month together (${renewalCalc.smartCalc.formattedBridgePrice}). Enjoy non-stop access without renewing again on the 1st!',
                            style: const TextStyle(fontSize: 11.5),
                          ),
                          value: _isBridgeSelected,
                          onChanged: (val) {
                            HapticFeedback.selectionClick();
                            setState(() => _isBridgeSelected = val);
                          },
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                  ],

                  // Calculated New Membership Cycle Banner
                  if (selectedPlan != null)
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: theme.colorScheme.outlineVariant),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.date_range_rounded, color: theme.colorScheme.primary),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('New Membership Period', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                Text(
                                  '${dateFormat.format(startDate)}  →  ${dateFormat.format(endDate)}',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                              ],
                            ),
                          ),
                          Builder(
                            builder: (context) {
                              final actualDays = endDate.difference(startDate).inDays + 1;
                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.primaryContainer,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '$actualDays days',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: theme.colorScheme.onPrimaryContainer,
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 16),

                  // Keep or Reclaim Seat Toggle
                  if (effectiveDeskId != null)
                    Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: BorderSide(color: theme.colorScheme.outlineVariant),
                      ),
                      child: SwitchListTile(
                        title: Text(
                          isReclaiming
                              ? 'Reclaim Previous ${SeatHelper.formatSeatLabel(seatId: effectiveDeskId)}'
                              : 'Keep My Allocated ${SeatHelper.formatSeatLabel(seatId: effectiveDeskId)}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          isReclaiming
                              ? 'Request to restore your previously allocated desk upon renewal approval'
                              : 'Retain your desk upon renewal approval',
                        ),
                        value: _keepSeat,
                        onChanged: (val) {
                          HapticFeedback.selectionClick();
                          setState(() => _keepSeat = val);
                        },
                      ),
                    ),
                  const SizedBox(height: 20),

                  // Dynamic Payment Data Stream & Capability-Gated Payment Switcher
                  StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                    stream: FirebaseFirestore.instance
                        .collection('libraries')
                        .doc(libraryId)
                        .collection('settings')
                        .doc('payment_methods')
                        .snapshots(),
                    builder: (context, paySnap) {
                      final library = ref.watch(currentLibraryProvider).value;
                      final payData = paySnap.data?.data() ?? {};

                      final planPriceStr = effectivePrice.toStringAsFixed(0);

                      // Merchant Contact Info
                      final rawContactPhone = (library?.contact.isNotEmpty == true
                              ? library!.contact
                              : (library?.whatsappNumber ?? ''))
                          .replaceAll(RegExp(r'\D'), '');
                      final merchantPhone = (payData['upiPhone']?.toString().isNotEmpty == true)
                          ? payData['upiPhone'].toString()
                          : rawContactPhone;

                      // Bank details map
                      final bankDetails = payData['bankDetails'] is Map
                          ? Map<String, dynamic>.from(payData['bankDetails'] as Map)
                          : <String, dynamic>{};
                      final bankName = bankDetails['bankName']?.toString().trim() ?? '';
                      final accNo = bankDetails['accountNumber']?.toString().trim() ?? '';
                      final ifsc = bankDetails['ifscCode']?.toString().trim() ?? '';
                      final accHolder = bankDetails['accountHolder']?.toString().trim() ?? (library?.name ?? 'Study Library');
                      final branch = bankDetails['branch']?.toString().trim() ?? '';
                      final hasBankConfigured = bankName.isNotEmpty && accNo.isNotEmpty && ifsc.isNotEmpty && accNo.length >= 8;

                      // Cash details map
                      final cashDetails = payData['cashDetails'] is Map
                          ? Map<String, dynamic>.from(payData['cashDetails'] as Map)
                          : <String, dynamic>{};
                      final deskTimings = cashDetails['timings']?.toString().isNotEmpty == true
                          ? cashDetails['timings'].toString()
                          : '8:00 AM – 10:00 PM (Daily)';
                      final deskInstructions = cashDetails['instructions']?.toString().isNotEmpty == true
                          ? cashDetails['instructions'].toString()
                          : 'You can pay in cash or swipe/scan directly when you visit the library. Submitting this renewal reserves your seat and study plan. The admin will confirm your payment at the reception desk.';

                      // Policies
                      final policies = payData['policies'] is Map
                          ? Map<String, dynamic>.from(payData['policies'] as Map)
                          : <String, dynamic>{};
                      final refundPolicy = policies['refundPolicy']?.toString() ?? '';

                      // UPI checks
                      final customUpi = payData['upiId']?.toString().trim();
                      final libUpi = library?.upiId.trim();
                      final upiId = (customUpi != null && customUpi.isNotEmpty)
                          ? customUpi
                          : ((libUpi != null && libUpi.isNotEmpty)
                              ? libUpi
                              : (rawContactPhone.isNotEmpty ? '$rawContactPhone@upi' : 'library@upi'));
                      final hasUpiConfigured = upiId.isNotEmpty;

                      // Dynamic active status evaluation - Single Source of Truth
                      final libEnabled = library?.enabledPaymentMethods ?? const ['cash', 'upi'];
                      final methodsList = (payData['methods'] is List)
                          ? (payData['methods'] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList()
                          : <Map<String, dynamic>>[];

                      final isUpiActive = methodsList.isNotEmpty
                          ? ((methodsList.firstWhere((m) => m['id'] == 'upi', orElse: () => {'active': true})['active'] == true) && hasUpiConfigured)
                          : (libEnabled.contains('upi') && hasUpiConfigured);

                      final isBankActive = methodsList.isNotEmpty
                          ? ((methodsList.firstWhere((m) => m['id'] == 'bank', orElse: () => {'active': false})['active'] == true) && hasBankConfigured)
                          : (libEnabled.contains('bank') && hasBankConfigured);

                      final isCashActive = methodsList.isNotEmpty
                          ? (methodsList.firstWhere((m) => m['id'] == 'cash', orElse: () => {'active': true})['active'] == true)
                          : libEnabled.contains('cash');

                      final availableModes = <RenewalPaymentMode>[];
                      if (isUpiActive) availableModes.add(RenewalPaymentMode.upi);
                      if (isBankActive) availableModes.add(RenewalPaymentMode.bank);
                      if (isCashActive) availableModes.add(RenewalPaymentMode.deskCash);

                      final effectiveAvailable = availableModes.isNotEmpty
                          ? availableModes
                          : [RenewalPaymentMode.deskCash];

                      final activeMode = effectiveAvailable.contains(_paymentMode)
                          ? _paymentMode
                          : effectiveAvailable.first;

                      Widget paymentCard;
                      if (activeMode == RenewalPaymentMode.deskCash) {
                        paymentCard = Card(
                          elevation: 1,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          child: Padding(
                            padding: const EdgeInsets.all(18.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    CircleAvatar(
                                      backgroundColor: Colors.green.shade100,
                                      radius: 20,
                                      child: Icon(Icons.storefront_rounded, color: Colors.green.shade800),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'Pay at Reception Desk',
                                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                          ),
                                          Text(
                                            'Desk Hours: $deskTimings',
                                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 14),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text('Fee to deposit at counter:', style: TextStyle(fontSize: 13)),
                                      AnimatedRollingPrice(
                                        targetPrice: selectedPlan?.price ?? 0,
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.green),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  deskInstructions,
                                  style: TextStyle(fontSize: 13, color: Colors.grey.shade700, height: 1.4),
                                ),
                              ],
                            ),
                          ),
                        );
                      } else if (activeMode == RenewalPaymentMode.bank) {
                        paymentCard = Card(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 1,
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF00796B).withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: const Icon(Icons.account_balance_rounded, color: Color(0xFF00796B)),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'Direct Bank Transfer (NEFT / IMPS)',
                                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                          ),
                                          Text(
                                            'Transfer ₹$planPriceStr directly to library bank account',
                                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 14),

                                if (hasBankConfigured) ...[
                                  Container(
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: theme.colorScheme.outlineVariant),
                                    ),
                                    child: Column(
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text('Bank Name', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                                                Text(bankName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                              ],
                                            ),
                                            Column(
                                              crossAxisAlignment: CrossAxisAlignment.end,
                                              children: [
                                                Text('Account Holder', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                                                Text(accHolder, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                              ],
                                            ),
                                          ],
                                        ),
                                        const Divider(height: 16),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text('Account Number', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                                                Text(accNo, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, fontFamily: 'monospace')),
                                              ],
                                            ),
                                            TactileCopyButton(
                                              copyText: accNo,
                                              successMessage: 'Account number copied!',
                                            ),
                                          ],
                                        ),
                                        const Divider(height: 16),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text('IFSC Code', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                                                Text(ifsc, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, fontFamily: 'monospace')),
                                              ],
                                            ),
                                            Row(
                                              children: [
                                                if (branch.isNotEmpty)
                                                  Padding(
                                                    padding: const EdgeInsets.only(right: 6.0),
                                                    child: Text('($branch)', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                                                  ),
                                                TactileCopyButton(
                                                  copyText: ifsc,
                                                  successMessage: 'IFSC code copied!',
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 10),

                                  // Action buttons row: Copy all details & WhatsApp screenshot share
                                  Row(
                                    children: [
                                      Expanded(
                                        child: TactileCopyButton(
                                          copyText: 'Bank: $bankName\nAccount Holder: $accHolder\nA/C No: $accNo\nIFSC: $ifsc${branch.isNotEmpty ? "\nBranch: $branch" : ""}\nAmount: ₹$planPriceStr',
                                          successMessage: 'Full bank details copied to clipboard!',
                                          label: 'Copy Bank Details',
                                          icon: Icons.copy_all_rounded,
                                        ),
                                      ),
                                      if (merchantPhone.isNotEmpty) ...[
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: FilledButton.tonalIcon(
                                            icon: const Icon(Icons.share_rounded, size: 16),
                                            label: const Text('Share Receipt'),
                                            style: FilledButton.styleFrom(
                                              padding: const EdgeInsets.symmetric(vertical: 10),
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                            ),
                                            onPressed: () async {
                                              final cleanPhone = merchantPhone.replaceAll(RegExp(r'\D'), '');
                                              final targetPhone = cleanPhone.length == 10 ? '91$cleanPhone' : cleanPhone;
                                              final waMsg = Uri.encodeComponent(
                                                'Hi, I have transferred ₹$planPriceStr for membership renewal.\nName: ${student.name}\nPlan: ${selectedPlan?.name ?? "Renewal"}\nUTR: ${_transactionRefController.text.trim()}',
                                              );
                                              final waUrl = Uri.parse('https://wa.me/$targetPhone?text=$waMsg');
                                              try {
                                                await launchUrl(waUrl, mode: LaunchMode.externalApplication);
                                              } catch (_) {}
                                            },
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ] else ...[
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.amber.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: Colors.amber.shade300),
                                    ),
                                    child: const Row(
                                      children: [
                                        Icon(Icons.info_outline_rounded, color: Colors.orange, size: 20),
                                        SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            'Bank details have not been set by library admin yet. Please pay via UPI QR or at desk.',
                                            style: TextStyle(fontSize: 12),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 14),

                                // Bank UTR Reference Field
                                TextField(
                                  controller: _transactionRefController,
                                  decoration: InputDecoration(
                                    labelText: 'Bank Transfer UTR / Ref No. *',
                                    hintText: 'e.g. 423589123456 or IMPS12345',
                                    prefixIcon: const Icon(Icons.tag_rounded),
                                    suffixIcon: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (_transactionRefController.text.isNotEmpty)
                                          IconButton(
                                            icon: const Icon(Icons.clear_rounded, size: 18),
                                            tooltip: 'Clear',
                                            onPressed: () => setState(() => _transactionRefController.clear()),
                                          ),
                                        IconButton(
                                          icon: const Icon(Icons.content_paste_go_rounded, color: Color(0xFF0D9488)),
                                          tooltip: 'Paste from Clipboard',
                                          onPressed: () => _checkClipboardForUtr(showFeedbackIfEmpty: true),
                                        ),
                                      ],
                                    ),
                                    border: const OutlineInputBorder(),
                                    helperText: 'Auto-detects from clipboard or enter reference from bank app',
                                  ),
                                ),
                                _buildPaymentProofAttachmentWidget(theme),
                              ],
                            ),
                          ),
                        );
                      } else {
                        // Default: RenewalPaymentMode.upi
                        final customUpi = payData['upiId']?.toString();
                        final libUpi = library?.upiId;
                        final upiId = (customUpi != null && customUpi.isNotEmpty)
                            ? customUpi
                            : ((libUpi != null && libUpi.isNotEmpty)
                                ? libUpi
                                : (rawContactPhone.isNotEmpty ? '$rawContactPhone@upi' : 'library@upi'));

                        final payeeName = payData['payeeName']?.toString().isNotEmpty == true
                            ? payData['payeeName'].toString()
                            : (library?.name.isNotEmpty == true ? library!.name : 'Study Library');

                        final isMerchant = payData['accountType'] == 'merchant';
                        final mcc = payData['mcc']?.toString() ?? (isMerchant ? '8299' : null);
                        final mccParam = (mcc != null && mcc.isNotEmpty) ? '&mc=$mcc' : '';
                        final isAboveLimit = effectivePrice >= 2000 && !isMerchant;

                        final cleanStudentName = student.name.replaceAll(RegExp(r'[^a-zA-Z0-9 ]'), '').trim();
                        final sanitizedNote = cleanStudentName.isNotEmpty
                            ? (cleanStudentName.length > 20 ? cleanStudentName.substring(0, 20) : cleanStudentName)
                            : 'CozyCorner';
                        final tnParam = '&tn=${Uri.encodeComponent("Renewal $sanitizedNote")}';

                        // Smart URI Routing:
                        // NPCI & PhonePe block pre-filled collect deep links (&am=) on personal savings (P2P) VPAs.
                        // For amounts >= ₹2,000 or any P2P account with collect restrictions,
                        // default to Open-Amount Intent (Payee pre-filled, student enters amount) to eliminate bank/app rejection.
                        final lockedUpiUri = 'upi://pay?pa=$upiId&pn=${Uri.encodeComponent(payeeName)}$mccParam&am=$planPriceStr&cu=INR$tnParam';
                        final openUpiUri = 'upi://pay?pa=$upiId&pn=${Uri.encodeComponent(payeeName)}$mccParam&cu=INR$tnParam';

                        final activeUpiUri = (isAboveLimit && !_forceLockedQr) ? openUpiUri : lockedUpiUri;

                        paymentCard = Card(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 1,
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.qr_code_2_rounded, color: theme.colorScheme.primary),
                                  const SizedBox(width: 8),
                                  Text('Scan & Pay via UPI', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: theme.colorScheme.outlineVariant),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.04),
                                      blurRadius: 8,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  children: [
                                    QrImageView(
                                      data: activeUpiUri,
                                      version: QrVersions.auto,
                                      size: 160.0,
                                      backgroundColor: Colors.white,
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          (isAboveLimit && !_forceLockedQr) ? 'Pay ' : 'Pay ',
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87),
                                        ),
                                        AnimatedRollingPrice(
                                          targetPrice: effectivePrice,
                                          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: Colors.black87),
                                        ),
                                        Text(
                                          ' to $payeeName',
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87),
                                        ),
                                      ],
                                    ),
                                    Text(
                                      'Google Pay • PhonePe • Paytm • BHIM • Any UPI',
                                      style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                                    ),
                                    const SizedBox(height: 4),
                                    TextButton.icon(
                                      onPressed: () => _saveQrImage(activeUpiUri, effectivePrice.toStringAsFixed(0)),
                                      icon: const Icon(Icons.download_rounded, size: 15),
                                      label: const Text('Save QR to Photos / Downloads', style: TextStyle(fontSize: 11.5)),
                                      style: TextButton.styleFrom(
                                        visualDensity: VisualDensity.compact,
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      ),
                                    ),
                                    if (isAboveLimit) ...[
                                      const SizedBox(height: 6),
                                      InkWell(
                                        onTap: () => setState(() => _forceLockedQr = !_forceLockedQr),
                                        borderRadius: BorderRadius.circular(6),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          child: Text(
                                            _forceLockedQr
                                                ? 'Switch to Open-Amount QR (Prevents Bank ₹2k Limit)'
                                                : 'Lock ₹$planPriceStr in QR',
                                            style: TextStyle(
                                              fontSize: 10.5,
                                              color: theme.colorScheme.primary,
                                              fontWeight: FontWeight.w600,
                                              decoration: TextDecoration.underline,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),

                              // Bank Security Notice for > ₹2,000 on Personal P2P VPAs
                              if (isAboveLimit) ...[
                                const SizedBox(height: 12),
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFEF3C7).withValues(alpha: 0.8),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.5)),
                                  ),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Icon(Icons.shield_outlined, size: 18, color: Color(0xFFB45309)),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Text(
                                              'Bank Security Notice (> ₹2,000)',
                                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF92400E)),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              'Per NPCI bank rules on deep links above ₹2,000, your UPI app will open with Payee pre-selected. Please enter ₹$planPriceStr and your UPI PIN to complete payment without limit errors.',
                                              style: const TextStyle(fontSize: 11, color: Color(0xFF78350F), height: 1.35),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],

                              const SizedBox(height: 12),

                              // 1-Tap Copy Action Chips
                              Wrap(
                                spacing: 8,
                                runSpacing: 6,
                                alignment: WrapAlignment.center,
                                children: [
                                  ActionChip(
                                    avatar: const Icon(Icons.currency_rupee_rounded, size: 14),
                                    label: Text('Copy ₹$planPriceStr', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5)),
                                    onPressed: () {
                                      Clipboard.setData(ClipboardData(text: planPriceStr));
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('Amount ₹$planPriceStr copied to clipboard!'),
                                          behavior: SnackBarBehavior.floating,
                                        ),
                                      );
                                    },
                                  ),
                                  ActionChip(
                                    avatar: const Icon(Icons.copy_rounded, size: 14),
                                    label: Text('Copy UPI ID ($upiId)', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 11.5)),
                                    onPressed: () {
                                      Clipboard.setData(ClipboardData(text: upiId));
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('UPI ID $upiId copied to clipboard!'),
                                          behavior: SnackBarBehavior.floating,
                                        ),
                                      );
                                    },
                                  ),
                                  ActionChip(
                                    avatar: const Icon(Icons.download_rounded, size: 14),
                                    label: const Text('Save QR to Photos', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 11.5)),
                                    onPressed: () => _saveQrImage(lockedUpiUri, planPriceStr),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),

                              // Pay via UPI Native App Button
                              FilledButton.icon(
                                icon: const Icon(Icons.flash_on_rounded),
                                label: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(isAboveLimit ? 'Open UPI App & Pay ' : 'Pay '),
                                    AnimatedRollingPrice(
                                      targetPrice: effectivePrice,
                                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                                    ),
                                    Text(isAboveLimit ? '' : ' via UPI App'),
                                  ],
                                ),
                                style: FilledButton.styleFrom(
                                  backgroundColor: const Color(0xFF00796B),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                                onPressed: () async {
                                  // Auto-copy exact amount to clipboard for seamless user convenience
                                  await Clipboard.setData(ClipboardData(text: planPriceStr));

                                  final uri = Uri.parse(activeUpiUri);
                                  try {
                                    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
                                    if (context.mounted) {
                                      if (isAboveLimit && launched) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text('UPI App opened! Amount ₹$planPriceStr copied. Enter amount & UPI PIN to pay.'),
                                            backgroundColor: const Color(0xFF0D9488),
                                            behavior: SnackBarBehavior.floating,
                                            duration: const Duration(seconds: 4),
                                          ),
                                        );
                                      } else if (!launched) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            content: Text('Could not launch UPI app directly. Please scan the QR code above or copy the UPI ID.'),
                                            backgroundColor: Colors.orange,
                                          ),
                                        );
                                      }
                                    }
                                  } catch (e) {
                                    if (context.mounted) {
                                      AppErrorFormatter.showErrorSnackBar(context, e, actionContext: 'payment');
                                    }
                                  }
                                },
                              ),

                              // PhonePe & GPay Direct Pay Card
                              Container(
                                margin: const EdgeInsets.only(top: 12),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Row(
                                      children: [
                                        Icon(Icons.help_outline_rounded, size: 16, color: Color(0xFF475569)),
                                        SizedBox(width: 6),
                                        Text(
                                          'PhonePe / GPay Troubleshooting',
                                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF1E293B)),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    const Text(
                                      'If PhonePe blocks direct payment with "cannot be completed through this mode":\n'
                                      '1. Tap "Copy UPI" below ➔ open PhonePe ➔ tap "To UPI ID" ➔ paste & pay.\n'
                                      '2. OR tap "Save QR" below ➔ open PhonePe Scanner ➔ tap Gallery icon ➔ select QR.',
                                      style: TextStyle(fontSize: 11, color: Color(0xFF475569), height: 1.35),
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: OutlinedButton.icon(
                                            icon: const Icon(Icons.copy_rounded, size: 13),
                                            label: const Text('1. Copy UPI ID', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                            style: OutlinedButton.styleFrom(
                                              visualDensity: VisualDensity.compact,
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                                            ),
                                            onPressed: () {
                                              Clipboard.setData(ClipboardData(text: upiId));
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                SnackBar(
                                                  content: Text('UPI ID $upiId copied! In PhonePe, select "To UPI ID" and paste.'),
                                                  backgroundColor: const Color(0xFF0F172A),
                                                  behavior: SnackBarBehavior.floating,
                                                ),
                                              );
                                            },
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: OutlinedButton.icon(
                                            icon: const Icon(Icons.download_rounded, size: 13),
                                            label: const Text('2. Save QR Image', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                            style: OutlinedButton.styleFrom(
                                              visualDensity: VisualDensity.compact,
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                                            ),
                                            onPressed: () => _saveQrImage(lockedUpiUri, planPriceStr),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),

                              // UTR Reference Input Field with Auto-Paste Suffix
                              TextField(
                                controller: _transactionRefController,
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                  LengthLimitingTextInputFormatter(12),
                                ],
                                decoration: InputDecoration(
                                  labelText: 'UTR / Transaction Reference No. *',
                                  hintText: 'e.g. 423589123456',
                                  prefixIcon: const Icon(Icons.tag_rounded),
                                  suffixIcon: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (_transactionRefController.text.isNotEmpty)
                                        IconButton(
                                          icon: const Icon(Icons.clear_rounded, size: 18),
                                          tooltip: 'Clear',
                                          onPressed: () => setState(() => _transactionRefController.clear()),
                                        ),
                                      IconButton(
                                        icon: const Icon(Icons.content_paste_go_rounded, color: Color(0xFF0D9488)),
                                        tooltip: 'Paste from Clipboard',
                                        onPressed: () => _checkClipboardForUtr(showFeedbackIfEmpty: true),
                                      ),
                                    ],
                                  ),
                                  border: const OutlineInputBorder(),
                                  helperText: 'Auto-detects on resume or tap paste icon to insert 12-digit UTR',
                                ),
                              ),
                              _buildPaymentProofAttachmentWidget(theme),

                              if (refundPolicy.isNotEmpty) ...[
                                const SizedBox(height: 12),
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Icons.info_outline_rounded, size: 14, color: theme.colorScheme.outline),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          refundPolicy,
                                          style: TextStyle(fontSize: 10, color: theme.colorScheme.outline),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    }

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Section Header: Payment Mode Selection
                          Row(
                            children: [
                              Icon(Icons.payments_rounded, color: theme.colorScheme.primary, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                'Payment Option',
                                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),

                          if (effectiveAvailable.length > 1)
                            SegmentedButton<RenewalPaymentMode>(
                              segments: [
                                if (effectiveAvailable.contains(RenewalPaymentMode.upi))
                                  const ButtonSegment(
                                    value: RenewalPaymentMode.upi,
                                    icon: Icon(Icons.qr_code_2_rounded),
                                    label: Text('UPI / QR'),
                                  ),
                                if (effectiveAvailable.contains(RenewalPaymentMode.bank))
                                  const ButtonSegment(
                                    value: RenewalPaymentMode.bank,
                                    icon: Icon(Icons.account_balance_rounded),
                                    label: Text('Bank Transfer'),
                                  ),
                                if (effectiveAvailable.contains(RenewalPaymentMode.deskCash))
                                  const ButtonSegment(
                                    value: RenewalPaymentMode.deskCash,
                                    icon: Icon(Icons.storefront_rounded),
                                    label: Text('Pay at Desk'),
                                  ),
                              ],
                              selected: {activeMode},
                              onSelectionChanged: (newSelection) {
                                HapticFeedback.selectionClick();
                                setState(() => _paymentMode = newSelection.first);
                              },
                            )
                          else
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primaryContainer.withValues(alpha: 0.35),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.2)),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    activeMode == RenewalPaymentMode.upi
                                        ? Icons.qr_code_2_rounded
                                        : (activeMode == RenewalPaymentMode.bank
                                            ? Icons.account_balance_rounded
                                            : Icons.storefront_rounded),
                                    color: theme.colorScheme.primary,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      activeMode == RenewalPaymentMode.upi
                                          ? 'Accepted Payment Mode: UPI / QR Code'
                                          : (activeMode == RenewalPaymentMode.bank
                                              ? 'Accepted Payment Mode: Direct Bank Transfer'
                                              : 'Accepted Payment Mode: Pay at Reception Desk'),
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                        color: theme.colorScheme.onSurface,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          const SizedBox(height: 14),

                          paymentCard,
                          const SizedBox(height: 16),

                          // Special Note / Desk Request
                          TextField(
                            controller: _notesController,
                            maxLines: 2,
                            decoration: InputDecoration(
                              labelText: activeMode == RenewalPaymentMode.deskCash
                                  ? 'Note for Reception Desk (Optional)'
                                  : 'Special Note / Requests (Optional)',
                              hintText: 'e.g. Prefer morning shift, paid cash at desk, etc.',
                              border: const OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Submit Button
                          PressableScale(
                            scaleFactor: 0.96,
                            child: SizedBox(
                              width: double.infinity,
                              child: FilledButton.icon(
                                icon: _isSubmitting
                                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                    : const Icon(Icons.send_rounded),
                                label: _isSubmitting
                                    ? const Text('Submitting...', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))
                                    : Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            effectiveDeskId != null && _keepSeat
                                                ? '🔒 Lock In ${SeatHelper.formatSeatLabel(seatId: effectiveDeskId)} ('
                                                : (activeMode == RenewalPaymentMode.deskCash
                                                    ? 'Submit Desk Renewal ('
                                                    : (activeMode == RenewalPaymentMode.bank
                                                        ? 'Submit Bank Renewal ('
                                                        : 'Submit Renewal (')),
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                          ),
                                          AnimatedRollingPrice(
                                            targetPrice: effectivePrice,
                                            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Colors.white),
                                          ),
                                          const Text(')', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                        ],
                                      ),
                                style: FilledButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                onPressed: _isSubmitting || selectedPlan == null || renewalCalc == null
                                    ? null
                                    : () {
                                        final origPrice = selectedPlan.getEffectiveOriginalPrice(baseMonthlyPrice: baseMonthly);
                                        final hasDiscount = origPrice != null && origPrice > selectedPlan.price;
                                        _submitRenewal(
                                          libraryId: libraryId,
                                          student: student,
                                          selectedPlan: selectedPlan,
                                          renewalCalc: renewalCalc,
                                          origPrice: origPrice,
                                          hasDiscount: hasDiscount,
                                          activePaymentMode: activeMode,
                                        );
                                      },
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Center(
                            child: Wrap(
                              alignment: WrapAlignment.center,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 4,
                              children: [
                                Text(
                                  'By submitting renewal, you agree to the',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.75),
                                  ),
                                ),
                                InkWell(
                                  onTap: () => context.push(Routes.terms),
                                  borderRadius: BorderRadius.circular(4),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
                                    child: Text(
                                      'Terms of Service',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: theme.colorScheme.primary,
                                        decoration: TextDecoration.underline,
                                      ),
                                    ),
                                  ),
                                ),
                                Text(
                                  '•',
                                  style: TextStyle(fontSize: 11, color: theme.colorScheme.outlineVariant),
                                ),
                                InkWell(
                                  onTap: () => context.push(Routes.privacyPolicy),
                                  borderRadius: BorderRadius.circular(4),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
                                    child: Text(
                                      'Privacy Policy',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: theme.colorScheme.primary,
                                        decoration: TextDecoration.underline,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                        ],
                      );
                    },
                  ),
                ],
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  ErrorHandler.handleError(err),
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                ),
              ),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              ErrorHandler.handleError(err),
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPaymentProofAttachmentWidget(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        Text(
          'Payment Screenshot / Receipt (Optional)',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 6),
        if (_paymentProofDataUrl == null)
          OutlinedButton.icon(
            onPressed: () async {
              final source = await ImageService.showSourcePicker(context);
              if (source != null) {
                final dataUrl = await ImageService.pickImageAsDataUrl(
                  source: source,
                  maxWidth: 600,
                  quality: 75,
                );
                if (dataUrl != null && mounted) {
                  setState(() {
                    _paymentProofDataUrl = dataUrl;
                  });
                }
              }
            },
            icon: const Icon(Icons.add_photo_alternate_outlined, size: 18),
            label: const Text('Upload Payment Screenshot / Slip'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 44),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          )
        else
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () {
                    ImageService.showImageViewer(
                      context,
                      imageUrl: _paymentProofDataUrl,
                      title: 'Payment Proof Screenshot',
                    );
                  },
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(
                      width: 52,
                      height: 52,
                      child: ImageService.buildImageWidget(
                        _paymentProofDataUrl!,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.check_circle_rounded, color: Colors.green, size: 16),
                          const SizedBox(width: 4),
                          const Text(
                            'Payment Proof Attached',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.green),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Admin can verify this receipt directly',
                        style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 20),
                  tooltip: 'Remove Screenshot',
                  onPressed: () {
                    setState(() {
                      _paymentProofDataUrl = null;
                    });
                  },
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// A smooth, high-precision price counter that rolls numbers with authentic spring
/// interpolation and tabular figures when the user toggles between membership plans.
class AnimatedRollingPrice extends StatefulWidget {
  final double targetPrice;
  final TextStyle? style;
  final String prefix;

  const AnimatedRollingPrice({
    super.key,
    required this.targetPrice,
    this.style,
    this.prefix = '₹',
  });

  @override
  State<AnimatedRollingPrice> createState() => _AnimatedRollingPriceState();
}

class _AnimatedRollingPriceState extends State<AnimatedRollingPrice> {
  late double _oldPrice;

  @override
  void initState() {
    super.initState();
    _oldPrice = widget.targetPrice;
  }

  @override
  void didUpdateWidget(covariant AnimatedRollingPrice oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.targetPrice != widget.targetPrice) {
      _oldPrice = oldWidget.targetPrice;
    }
  }

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      key: ValueKey(widget.targetPrice),
      tween: Tween<double>(begin: _oldPrice, end: widget.targetPrice),
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Text(
          '${widget.prefix}${value.round()}',
          style: (widget.style ?? const TextStyle()).copyWith(
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        );
      },
    );
  }
}

/// A tactile button that triggers micro-haptic feedback and morphs the copy icon
/// into an animated green checkmark with ripple confirmation.
class TactileCopyButton extends StatefulWidget {
  final String copyText;
  final String successMessage;
  final String? label;
  final IconData icon;

  const TactileCopyButton({
    super.key,
    required this.copyText,
    required this.successMessage,
    this.label,
    this.icon = Icons.copy_rounded,
  });

  @override
  State<TactileCopyButton> createState() => _TactileCopyButtonState();
}

class _TactileCopyButtonState extends State<TactileCopyButton> {
  bool _copied = false;

  void _onCopy() {
    HapticFeedback.lightImpact();
    Clipboard.setData(ClipboardData(text: widget.copyText));
    setState(() => _copied = true);

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.greenAccent, size: 20),
            const SizedBox(width: 8),
            Text(widget.successMessage),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(milliseconds: 2000),
      ),
    );

    Future.delayed(const Duration(milliseconds: 1800), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.label != null) {
      return PressableScale(
        scaleFactor: 0.95,
        onTap: _onCopy,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: _copied ? Colors.green.withValues(alpha: 0.15) : null,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: _copied ? Colors.green : Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Icon(
                  _copied ? Icons.check_rounded : widget.icon,
                  key: ValueKey(_copied),
                  size: 16,
                  color: _copied ? Colors.green.shade700 : null,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                _copied ? 'Copied!' : widget.label!,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: _copied ? Colors.green.shade700 : null,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return PressableScale(
      scaleFactor: 0.88,
      onTap: _onCopy,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: _copied ? Colors.green.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: Icon(
            _copied ? Icons.check_rounded : widget.icon,
            key: ValueKey(_copied),
            size: 18,
            color: _copied ? Colors.green.shade700 : Theme.of(context).colorScheme.primary,
          ),
        ),
      ),
    );
  }
}
