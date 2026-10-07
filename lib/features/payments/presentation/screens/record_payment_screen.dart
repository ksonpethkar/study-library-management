import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:study_library/models/payment_model.dart';
import 'package:study_library/features/payments/data/repositories/payment_repository.dart';
import 'package:study_library/core/widgets/validated_text_field.dart';
import 'package:study_library/core/providers/library_provider.dart';
import 'package:study_library/features/receipts/presentation/screens/generate_receipt_screen.dart';
import 'package:study_library/services/notification_webhook_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class RecordPaymentScreen extends ConsumerStatefulWidget {
  final String studentId;
  final String studentName;
  final double planPrice;

  const RecordPaymentScreen({super.key, 
    required this.studentId,
    required this.studentName,
    required this.planPrice,
  });

  @override
  ConsumerState<RecordPaymentScreen> createState() => _RecordPaymentScreenState();
}

class _RecordPaymentScreenState extends ConsumerState<RecordPaymentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _referenceController = TextEditingController();
  final _notesController = TextEditingController();
  
  String _paymentMethod = 'Cash';
  bool _isLoading = false;
  List<String> _paymentMethods = ['Cash', 'UPI', 'Card', 'Bank Transfer', 'Cheque'];

  @override
  void initState() {
    super.initState();
    _loadPaymentMethods();
  }

  Future<void> _loadPaymentMethods() async {
    try {
      final libraryId = ref.read(currentLibraryIdProvider) ?? '';
      final doc = await FirebaseFirestore.instance
          .collection('libraries').doc(libraryId)
          .collection('settings').doc('payment_methods').get();
      if (doc.exists) {
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
              _paymentMethod = methods.first;
            });
          }
        }
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _amountController.dispose();
    _referenceController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _save() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      try {
        final amount = double.parse(_amountController.text);
        
        final repo = ref.read(paymentRepositoryProvider); 
        final libraryId = ref.read(currentLibraryIdProvider) ?? '';
        
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

        final payment = PaymentModel(
          id: '',
          studentId: widget.studentId,
          amount: amount,
          method: _paymentMethod,
          date: DateTime.now(),
          referenceNumber: _referenceController.text.trim(),
          notes: _notesController.text.trim(),
          status: PaymentStatus.paid,
          createdAt: DateTime.now(),
        );

        await repo.recordPayment(libraryId, widget.studentId, payment);

        // Revenue aggregate (free Cloud Function alternative) —————————————
        final month = DateTime.now().toIso8601String().substring(0, 7);
        FirebaseFirestore.instance
            .collection('libraries').doc(libraryId)
            .collection('settings').doc('revenue_aggregate')
            .set({
              'totalRevenue': FieldValue.increment(amount),
              'totalPayments': FieldValue.increment(1),
              'monthlyRevenue.$month': FieldValue.increment(amount),
              'lastUpdated': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true))
            .catchError((e) => debugPrint('Aggregate update (non-critical): $e'));
        // —————————————————————————————————————————————————————————————————


        ref.read(notificationWebhookServiceProvider).dispatchPaymentWebhook(
          libraryId: libraryId,
          studentName: widget.studentName,
          studentPhone: '',
          amount: amount,
          planName: 'Study Library Plan',
          receiptId: payment.id,
        );
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Payment recorded!')));
          // Navigate to receipt generation
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => GenerateReceiptScreen(
                studentId: widget.studentId,
                studentName: widget.studentName,
                studentPhone: '',
                amount: amount,
                paymentMethod: _paymentMethod,
                notes: _notesController.text.trim(),
              ),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Record Payment')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Student: ${widget.studentName}', style: Theme.of(context).textTheme.titleMedium),
                    Text('Plan Price: ₹${widget.planPrice}', style: Theme.of(context).textTheme.bodyMedium),
                    const SizedBox(height: 16),
                    ValidatedTextField(
                      label: 'Amount (₹)',
                      controller: _amountController,
                      keyboardType: TextInputType.number,
                      validator: (val) {
                        if (val == null || val.isEmpty) return 'Required';
                        final num = double.tryParse(val);
                        if (num == null || num <= 0) return 'Invalid amount';
                        return null;
                      },
                      onChanged: (val) {
                        final num = double.tryParse(val);
                        if (num != null && num > widget.planPrice) {
                          // Warning non-blocking could be shown via a state variable.
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: _paymentMethod,
                      decoration: const InputDecoration(
                        labelText: 'Payment Method *',
                        prefixIcon: Icon(Icons.payment_rounded),
                        border: OutlineInputBorder(),
                      ),
                      items: _paymentMethods.map((m) {
                        return DropdownMenuItem(value: m, child: Text(m));
                      }).toList(),
                      onChanged: (val) => setState(() => _paymentMethod = val!),
                    ),
                    const SizedBox(height: 16),
                    if (_paymentMethod == 'UPI' || _paymentMethod == 'Bank Transfer')
                      ValidatedTextField(
                        label: 'Reference Number',
                        controller: _referenceController,
                        validator: (val) => val == null || val.isEmpty ? 'Required for this method' : null,
                      ),
                    const SizedBox(height: 16),
                    ValidatedTextField(
                      label: 'Notes (Optional)',
                      controller: _notesController,
                      maxLines: 2,
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _save,
                        child: const Text('Save Payment'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
