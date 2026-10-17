import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:study_library/models/payment_model.dart';
import 'package:study_library/models/receipt_model.dart';
import 'package:study_library/features/payments/data/repositories/payment_repository.dart';
import 'package:study_library/features/receipts/data/repositories/receipt_repository.dart';
import 'package:study_library/core/widgets/validated_text_field.dart';
import 'package:study_library/core/providers/library_provider.dart';
import 'package:study_library/features/receipts/presentation/screens/receipt_preview_screen.dart';
import 'package:study_library/services/messaging_hub_service.dart';
import 'package:study_library/services/whatsapp_service.dart';

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
  final _notesController = TextEditingController();

  String _paymentMethod = 'Cash';
  bool _isLoading = false;
  bool _isPartialPayment = false;
  List<String> _paymentMethods = ['Cash', 'UPI / QR', 'Debit / Credit Card', 'Bank Transfer', 'Cheque / DD'];

  double get _effectiveTotalFee {
    final parsed = double.tryParse(_totalFeeController.text);
    if (parsed != null && parsed > 0) return parsed;
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
    } catch (_) {}
  }

  @override
  void dispose() {
    _amountController.dispose();
    _totalFeeController.dispose();
    _referenceController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final amount = _payingAmount;
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
            content: const Text('A similar payment was just recorded. Continue anyway?'),
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

      // 2. Fetch student details to get active plan and phone if not provided
      String resolvedPhone = widget.studentPhone;
      String resolvedPlanId = '';
      DateTime validFrom = DateTime.now();
      DateTime validTo = DateTime.now().add(const Duration(days: 30));

      final studentDoc = await FirebaseFirestore.instance
          .collection('libraries')
          .doc(libraryId)
          .collection('students')
          .doc(widget.studentId)
          .get();

      if (studentDoc.exists && studentDoc.data() != null) {
        final sData = studentDoc.data()!;
        if (resolvedPhone.isEmpty) {
          resolvedPhone = sData['phone'] as String? ?? '';
        }
        resolvedPlanId = sData['planId'] as String? ?? '';
        final endDateRaw = sData['planEndDate'];
        if (endDateRaw is Timestamp) {
          validTo = endDateRaw.toDate();
        } else if (endDateRaw is String) {
          validTo = DateTime.tryParse(endDateRaw) ?? validTo;
        }
      }

      // 3. Atomically Generate Official Receipt
      final receiptRepo = ReceiptRepository();
      final receiptNumber = await receiptRepo.getNextReceiptNumber(libraryId);

      final newReceipt = ReceiptModel(
        id: '',
        libraryId: libraryId,
        receiptNumber: receiptNumber,
        studentId: widget.studentId,
        planId: resolvedPlanId,
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
          if (_notesController.text.trim().isNotEmpty) 'notes': _notesController.text.trim(),
          if (_isPartialPayment) 'isInstalment': true,
        },
        status: ReceiptStatus.active,
        createdAt: DateTime.now(),
      );

      final createdReceiptId = await receiptRepo.generateReceipt(libraryId, newReceipt);

      // 4. Save Payment Record linked to receipt
      final payment = PaymentModel(
        id: '',
        studentId: widget.studentId,
        amount: amount,
        totalPlanFee: totalFee,
        remainingDue: remainingDue,
        installmentNumber: _isPartialPayment ? 1 : null,
        method: _paymentMethod,
        date: DateTime.now(),
        referenceNumber: _referenceController.text.trim().isNotEmpty ? _referenceController.text.trim() : null,
        notes: _notesController.text.trim().isNotEmpty ? _notesController.text.trim() : null,
        receiptId: createdReceiptId,
        status: _isPartialPayment && remainingDue > 0 ? PaymentStatus.partial : PaymentStatus.paid,
        createdAt: DateTime.now(),
      );

      await repo.recordPayment(libraryId, widget.studentId, payment);

      // 5. Update Student's Pending Due Balance in Firestore
      await FirebaseFirestore.instance
          .collection('libraries')
          .doc(libraryId)
          .collection('students')
          .doc(widget.studentId)
          .set({'pendingDueBalance': remainingDue}, SetOptions(merge: true));

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

      // 7. Dispatch Unified Free Notifications (SMS, Telegram, Local Bridge, Webhook)
      final library = ref.read(currentLibraryProvider).value;
      final libraryName = library?.name ?? 'Study Library';

      final hub = ref.read(messagingHubServiceProvider);
      await hub.dispatchPaymentConfirmation(
        libraryId: libraryId,
        studentName: widget.studentName,
        studentPhone: resolvedPhone,
        libraryName: libraryName,
        amount: amount,
        receiptNumber: receiptNumber,
        paymentMethod: _paymentMethod,
        remainingDue: remainingDue,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Payment & Receipt #$receiptNumber recorded successfully! ✅'),
            duration: const Duration(seconds: 4),
            action: resolvedPhone.isNotEmpty
                ? SnackBarAction(
                    label: 'WhatsApp',
                    onPressed: () {
                      ref.read(whatsappServiceProvider).sendPaymentConfirmation(
                        resolvedPhone,
                        widget.studentName,
                        libraryName,
                        amount,
                        receiptNumber,
                      );
                    },
                  )
                : null,
          ),
        );

        // Open official receipt preview immediately
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => ReceiptPreviewScreen(receiptId: createdReceiptId),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error recording payment: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Record Payment'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Student Info Card
                    Card(
                      elevation: 0,
                      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(14.0),
                        child: Row(
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
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Partial Payment / Instalment Toggle
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

                    if (_isPartialPayment) ...[
                      ValidatedTextField(
                        label: 'Total Plan Fee (₹) *',
                        controller: _totalFeeController,
                        keyboardType: TextInputType.number,
                        onChanged: (_) => setState(() {}),
                        validator: (val) {
                          final num = double.tryParse(val ?? '');
                          if (num == null || num <= 0) return 'Enter valid total fee';
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                    ],

                    ValidatedTextField(
                      label: _isPartialPayment ? 'Paying Now (₹) *' : 'Amount Paid (₹) *',
                      controller: _amountController,
                      keyboardType: TextInputType.number,
                      onChanged: (_) => setState(() {}),
                      validator: (val) {
                        if (val == null || val.isEmpty) return 'Required';
                        final num = double.tryParse(val);
                        if (num == null || num <= 0) return 'Invalid amount';
                        if (_isPartialPayment && num > _effectiveTotalFee) {
                          return 'Paying amount cannot exceed total fee';
                        }
                        return null;
                      },
                    ),

                    if (_isPartialPayment) ...[
                      const SizedBox(height: 8),
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

                    // Dynamic Payment Methods (Connected to Settings)
                    DropdownButtonFormField<String>(
                      initialValue: _paymentMethods.contains(_paymentMethod)
                          ? _paymentMethod
                          : (_paymentMethods.isNotEmpty ? _paymentMethods.first : null),
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
                    const SizedBox(height: 16),

                    ValidatedTextField(
                      label: _paymentMethod.toLowerCase().contains('upi')
                          ? 'UPI Reference / UTR Number'
                          : 'Reference / Cheque Number (Optional)',
                      controller: _referenceController,
                      prefixIcon: const Icon(Icons.tag_rounded),
                    ),
                    const SizedBox(height: 16),

                    ValidatedTextField(
                      label: 'Admin Notes (Optional)',
                      controller: _notesController,
                      prefixIcon: const Icon(Icons.note_alt_outlined),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 24),

                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: FilledButton.icon(
                        onPressed: _save,
                        icon: const Icon(Icons.receipt_long_rounded),
                        label: Text(
                          _isPartialPayment
                              ? 'Record Instalment & Generate Receipt'
                              : 'Record Payment & Generate Receipt',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
