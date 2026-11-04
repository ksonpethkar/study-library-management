import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:study_library/core/security/audit_logger.dart';
import 'package:study_library/models/payment_model.dart';
import 'package:study_library/models/receipt_model.dart';
import 'package:study_library/models/student_model.dart';
import 'package:study_library/core/utils/error_formatter.dart';

class EditPaymentScreen extends ConsumerStatefulWidget {
  final PaymentModel payment;
  final StudentModel student;
  final String libraryId;
  final String? receiptNumber;

  const EditPaymentScreen({
    super.key,
    required this.payment,
    required this.student,
    required this.libraryId,
    this.receiptNumber,
  });

  @override
  ConsumerState<EditPaymentScreen> createState() => _EditPaymentScreenState();
}

class _EditPaymentScreenState extends ConsumerState<EditPaymentScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _amountController;
  late TextEditingController _refController;
  late TextEditingController _notesController;
  late TextEditingController _bankNameController;

  late DateTime _selectedDate;
  late PaymentStatus _selectedStatus;
  late String _selectedMethod;
  bool _syncReceipt = true;
  bool _isSaving = false;

  final List<String> _availableMethods = [
    'Cash / Pay at Reception',
    'UPI / QR Code',
    'Debit / Credit Card',
    'Bank Transfer (NEFT/IMPS)',
    'Cheque / DD',
  ];

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(text: widget.payment.amount.toStringAsFixed(0));
    _refController = TextEditingController(text: widget.payment.referenceNumber ?? '');
    _notesController = TextEditingController(text: widget.payment.notes ?? '');
    _bankNameController = TextEditingController(text: widget.payment.methodDetails ?? '');
    _selectedDate = widget.payment.date;
    _selectedStatus = widget.payment.status;

    _selectedMethod = widget.payment.method.isNotEmpty
        ? widget.payment.method
        : 'Cash / Pay at Reception';

    // Normalize match
    if (!_availableMethods.contains(_selectedMethod)) {
      if (_selectedMethod.toLowerCase() == 'cash') {
        _selectedMethod = 'Cash / Pay at Reception';
      } else if (_selectedMethod.toLowerCase().contains('upi')) {
        _selectedMethod = 'UPI / QR Code';
      } else {
        _availableMethods.add(_selectedMethod);
      }
    }

    _loadPaymentMethods();
  }

  Future<void> _loadPaymentMethods() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('libraries')
          .doc(widget.libraryId)
          .collection('settings')
          .doc('payment_methods')
          .get();

      if (doc.exists && mounted) {
        final data = doc.data()?['methods'] as List<dynamic>?;
        if (data != null && data.isNotEmpty) {
          final loaded = data
              .cast<Map<String, dynamic>>()
              .where((m) => m['active'] as bool? ?? true)
              .map((m) => m['name'] as String? ?? '')
              .where((name) => name.isNotEmpty)
              .toList();

          if (loaded.isNotEmpty) {
            setState(() {
              for (final m in loaded) {
                final normalized = m.toLowerCase() == 'cash'
                    ? 'Cash / Pay at Reception'
                    : (m.toLowerCase().contains('upi') ? 'UPI / QR Code' : m);
                if (!_availableMethods.contains(normalized)) {
                  _availableMethods.add(normalized);
                }
              }
            });
          }
        }
      }
    } catch (_) { /* intentionally silent */ }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _refController.dispose();
    _notesController.dispose();
    _bankNameController.dispose();
    super.dispose();
  }

  double get _currentAmount => double.tryParse(_amountController.text.trim()) ?? widget.payment.amount;
  double get _amountDelta => _currentAmount - widget.payment.amount;

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;
    if (_isSaving) return;

    setState(() => _isSaving = true);

    try {
      final newAmount = _currentAmount;
      final newRef = _refController.text.trim();
      final newNotes = _notesController.text.trim();
      final newBank = _bankNameController.text.trim();
      final delta = _amountDelta;

      // 1. Calculate updated remaining due
      double? updatedDue = widget.payment.remainingDue;
      if (updatedDue != null) {
        updatedDue = (updatedDue - delta).clamp(0.0, double.infinity);
      }

      final Map<String, dynamic> updateData = {
        'amount': newAmount,
        'method': _selectedMethod,
        'paymentMethod': _selectedMethod,
        'date': Timestamp.fromDate(_selectedDate),
        'paymentDate': Timestamp.fromDate(_selectedDate),
        if (newBank.isNotEmpty) 'methodDetails': newBank,
        'referenceNumber': newRef.isNotEmpty ? newRef : null,
        'notes': newNotes.isNotEmpty ? newNotes : null,
        'status': _selectedStatus.name,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (updatedDue != null) {
        updateData['remainingDue'] = updatedDue;
      }

      // Update payment record in Firestore
      await FirebaseFirestore.instance
          .collection('libraries')
          .doc(widget.libraryId)
          .collection('payments')
          .doc(widget.payment.id)
          .update(updateData);

      // 2. Sync with Receipt doc if enabled
      final targetReceiptId = widget.payment.receiptId;
      if (_syncReceipt && targetReceiptId != null && targetReceiptId.isNotEmpty) {
        final receiptUpdate = <String, dynamic>{
          'amount': newAmount,
          'paidAmount': newAmount,
          'paymentMethod': _selectedMethod,
          'updatedAt': FieldValue.serverTimestamp(),
        };

        if (_selectedStatus == PaymentStatus.voided ||
            _selectedStatus == PaymentStatus.cancelled ||
            _selectedStatus == PaymentStatus.refunded) {
          receiptUpdate['status'] = ReceiptStatus.voided.name;
        } else if (_selectedStatus == PaymentStatus.paid ||
            _selectedStatus == PaymentStatus.partial) {
          receiptUpdate['status'] = ReceiptStatus.active.name;
        }

        if (updatedDue != null) {
          receiptUpdate['remainingDue'] = updatedDue;
        }

        // Try direct doc ID match first
        final receiptDoc = FirebaseFirestore.instance
            .collection('libraries')
            .doc(widget.libraryId)
            .collection('receipts')
            .doc(targetReceiptId);

        final receiptExists = (await receiptDoc.get()).exists;
        if (receiptExists) {
          await receiptDoc.update(receiptUpdate);
        } else {
          // Fallback: match by receiptNumber
          final snap = await FirebaseFirestore.instance
              .collection('libraries')
              .doc(widget.libraryId)
              .collection('receipts')
              .where('receiptNumber', isEqualTo: targetReceiptId)
              .limit(1)
              .get();
          if (snap.docs.isNotEmpty) {
            await snap.docs.first.reference.update(receiptUpdate);
          }
        }
      }

      // 3. Recalculate Student Balance
      final paymentsSnap = await FirebaseFirestore.instance
          .collection('libraries')
          .doc(widget.libraryId)
          .collection('payments')
          .where('studentId', isEqualTo: widget.student.id)
          .get();

      double activePaidSum = 0.0;
      for (final doc in paymentsSnap.docs) {
        final d = doc.data();
        final st = (d['status'] as String? ?? 'paid').toLowerCase();
        if (st != 'refunded' && st != 'voided' && st != 'cancelled') {
          activePaidSum += (d['amount'] as num?)?.toDouble() ?? 0.0;
        }
      }

      double? planFee = widget.payment.totalPlanFee;
      if (planFee == null || planFee <= 0) {
        if (widget.student.planId != null && widget.student.planId!.isNotEmpty) {
          final pDoc = await FirebaseFirestore.instance
              .collection('libraries')
              .doc(widget.libraryId)
              .collection('plans')
              .doc(widget.student.planId)
              .get();
          if (pDoc.exists) {
            planFee = (pDoc.data()?['price'] as num?)?.toDouble();
          }
        }
      }

      if (planFee != null && planFee > 0) {
        final newStudentDue = (planFee - activePaidSum).clamp(0.0, double.infinity);
        await FirebaseFirestore.instance
            .collection('libraries')
            .doc(widget.libraryId)
            .collection('students')
            .doc(widget.student.id)
            .update({
          'pendingDueBalance': newStudentDue,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      // 4. Audit Log Entry
      AuditLogger().log(
        action: AuditAction.updated,
        entityType: AuditEntity.payment,
        libraryId: widget.libraryId,
        entityId: widget.payment.id,
        details: {
          'event': 'payment_edited',
          'oldAmount': widget.payment.amount,
          'newAmount': newAmount,
          'method': _selectedMethod,
          'studentId': widget.student.id,
        },
      ).ignore();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Text('Payment details updated successfully!'),
              ],
            ),
            backgroundColor: Color(0xFF15803D),
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        AppErrorFormatter.showErrorSnackBar(context, e, actionContext: 'payment');
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Widget _buildCard({
    required ThemeData theme,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required List<Widget> children,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(icon, color: iconColor, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                    Text(subtitle, style: TextStyle(fontSize: 11.5, color: theme.colorScheme.onSurfaceVariant)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isPayingCash = _selectedMethod.toLowerCase().contains('cash');
    final isPayingUPI = _selectedMethod.toLowerCase().contains('upi') || _selectedMethod.toLowerCase().contains('qr');
    final isPayingCard = _selectedMethod.toLowerCase().contains('card');
    final isPayingCheque = _selectedMethod.toLowerCase().contains('cheque') || _selectedMethod.toLowerCase().contains('dd');

    final displayReceiptNum = widget.receiptNumber ??
        widget.payment.receiptNumber ??
        (widget.payment.receiptId != null && widget.payment.receiptId!.startsWith('REC-')
            ? widget.payment.receiptId
            : (widget.payment.receiptId != null && widget.payment.receiptId!.length >= 8
                ? '#${widget.payment.receiptId!.substring(0, 8).toUpperCase()}'
                : widget.payment.receiptId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Payment Details'),
        elevation: 0,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
              children: [
                // 1. Student Identity Header Banner
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: theme.colorScheme.primary,
                        child: Text(
                          widget.student.name.isNotEmpty ? widget.student.name[0].toUpperCase() : 'S',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.student.name,
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${widget.student.membershipNumber ?? "Student"} • ${widget.student.phone}',
                              style: TextStyle(fontSize: 12.5, color: theme.colorScheme.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                      if (displayReceiptNum != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surface,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.3)),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.03),
                                blurRadius: 4,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.receipt_long_rounded, size: 14, color: theme.colorScheme.primary),
                              const SizedBox(width: 5),
                              Text(
                                'Receipt: $displayReceiptNum',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),

                // 2. Financial Amount & Date Card
                _buildCard(
                  theme: theme,
                  icon: Icons.currency_rupee_rounded,
                  iconColor: const Color(0xFF047857),
                  title: 'Payment Amount & Date',
                  subtitle: 'Amount collected and verified calendar date of payment',
                  children: [
                    // Payment Date Selector
                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _selectedDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                        );
                        if (picked != null) {
                          setState(() => _selectedDate = picked);
                        }
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Payment Date *',
                          prefixIcon: Icon(Icons.calendar_month_rounded),
                          border: OutlineInputBorder(),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              DateFormat('dd MMMM yyyy').format(_selectedDate),
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                            ),
                            const Icon(Icons.arrow_drop_down, color: Colors.grey),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Amount Field
                    TextFormField(
                      controller: _amountController,
                      decoration: const InputDecoration(
                        labelText: 'Paid Amount (₹) *',
                        prefixIcon: Icon(Icons.currency_rupee_rounded),
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      onChanged: (_) => setState(() {}),
                      validator: (val) {
                        final p = double.tryParse(val ?? '');
                        if (p == null || p <= 0) return 'Please enter a valid amount';
                        return null;
                      },
                    ),

                    // Dues delta indicator
                    if (_amountDelta.abs() >= 1.0) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: _amountDelta > 0 ? const Color(0xFFF0FDF4) : const Color(0xFFFEF3C7),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: _amountDelta > 0 ? const Color(0xFF86EFAC) : const Color(0xFFFDE68A),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _amountDelta > 0 ? Icons.trending_down_rounded : Icons.trending_up_rounded,
                              color: _amountDelta > 0 ? const Color(0xFF15803D) : const Color(0xFFB45309),
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _amountDelta > 0
                                    ? 'Amount increased by ₹${_amountDelta.toStringAsFixed(0)}. Student pending dues will decrease by ₹${_amountDelta.toStringAsFixed(0)}.'
                                    : 'Amount reduced by ₹${(-_amountDelta).toStringAsFixed(0)}. Student pending dues will increase by ₹${(-_amountDelta).toStringAsFixed(0)}.',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: _amountDelta > 0 ? const Color(0xFF15803D) : const Color(0xFFB45309),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),

                // 3. Status & Method Card
                _buildCard(
                  theme: theme,
                  icon: Icons.payment_rounded,
                  iconColor: theme.colorScheme.primary,
                  title: 'Payment Mode & Settlement Status',
                  subtitle: 'Instrument method used and current ledger status',
                  children: [
                    DropdownButtonFormField<PaymentStatus>(
                      initialValue: _selectedStatus,
                      decoration: const InputDecoration(
                        labelText: 'Settlement Status *',
                        prefixIcon: Icon(Icons.check_circle_outline_rounded),
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        const DropdownMenuItem(value: PaymentStatus.paid, child: Text('Paid (Full Settlement)')),
                        const DropdownMenuItem(value: PaymentStatus.partial, child: Text('Partial / Installment')),
                        const DropdownMenuItem(value: PaymentStatus.voided, child: Text('Voided / Cancelled')),
                        const DropdownMenuItem(value: PaymentStatus.refunded, child: Text('Refunded')),
                      ],
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedStatus = val);
                      },
                    ),
                    const SizedBox(height: 14),

                    DropdownButtonFormField<String>(
                      initialValue: _availableMethods.contains(_selectedMethod)
                          ? _selectedMethod
                          : _availableMethods.first,
                      decoration: const InputDecoration(
                        labelText: 'Payment Method *',
                        prefixIcon: Icon(Icons.account_balance_wallet_outlined),
                        border: OutlineInputBorder(),
                      ),
                      items: _availableMethods.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedMethod = val);
                      },
                    ),
                    const SizedBox(height: 14),

                    if (isPayingCash) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0FDF4),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFF86EFAC)),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.payments_outlined, color: Color(0xFF15803D), size: 20),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Cash Payment: Verified & collected in person at library desk.',
                                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500, color: Color(0xFF15803D)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else if (isPayingUPI) ...[
                      TextFormField(
                        controller: _refController,
                        decoration: const InputDecoration(
                          labelText: 'UPI Reference / 12-Digit UTR Number *',
                          hintText: 'e.g. 429182910281 or Txn Reference ID',
                          prefixIcon: Icon(Icons.qr_code_2_rounded),
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter UPI reference number' : null,
                      ),
                    ] else if (isPayingCard) ...[
                      TextFormField(
                        controller: _refController,
                        decoration: const InputDecoration(
                          labelText: 'Card Last 4 Digits / POS Auth Code',
                          hintText: 'e.g. 4821 or TXN-9821',
                          prefixIcon: Icon(Icons.credit_card_rounded),
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ] else if (isPayingCheque) ...[
                      TextFormField(
                        controller: _refController,
                        decoration: const InputDecoration(
                          labelText: 'Cheque / DD Number *',
                          hintText: 'e.g. 000492',
                          prefixIcon: Icon(Icons.receipt_rounded),
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter Cheque or DD number' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _bankNameController,
                        decoration: const InputDecoration(
                          labelText: 'Issuing Bank Name & Branch *',
                          hintText: 'e.g. SBI Main Branch',
                          prefixIcon: Icon(Icons.account_balance_rounded),
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter issuing bank name' : null,
                      ),
                    ] else ...[
                      TextFormField(
                        controller: _refController,
                        decoration: const InputDecoration(
                          labelText: 'Transaction Reference / UTR Number',
                          hintText: 'e.g. IMPS/NEFT Ref #',
                          prefixIcon: Icon(Icons.tag_rounded),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _bankNameController,
                        decoration: const InputDecoration(
                          labelText: 'Bank Name & Branch',
                          hintText: 'e.g. HDFC Bank',
                          prefixIcon: Icon(Icons.account_balance_rounded),
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                  ],
                ),

                // 4. Notes & Receipt Parity
                _buildCard(
                  theme: theme,
                  icon: Icons.receipt_long_rounded,
                  iconColor: const Color(0xFFD97706),
                  title: 'Remarks & Official Receipt Parity',
                  subtitle: 'Internal notes and automatic synchronization with student invoice',
                  children: [
                    TextFormField(
                      controller: _notesController,
                      decoration: const InputDecoration(
                        labelText: 'Admin Remarks / Notes (Optional)',
                        hintText: 'e.g. Cleared pending dues for October',
                        prefixIcon: Icon(Icons.note_alt_outlined),
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 2,
                    ),
                    if (displayReceiptNum != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4)),
                        ),
                        child: SwitchListTile.adaptive(
                          contentPadding: EdgeInsets.zero,
                          value: _syncReceipt,
                          title: Text(
                            'Sync changes with Receipt $displayReceiptNum',
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            'Updates official PDF receipt amount, date, and status in real-time.',
                            style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant),
                          ),
                          onChanged: (v) => setState(() => _syncReceipt = v),
                        ),
                      ),
                    ],
                  ],
                ),

                const SizedBox(height: 10),

                // 5. Save Button
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton.icon(
                    onPressed: _isSaving ? null : _saveChanges,
                    icon: _isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.save_rounded, size: 20),
                    label: Text(
                      _isSaving ? 'Saving Changes...' : 'Save Payment Changes',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                    style: FilledButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 2,
                    ),
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
