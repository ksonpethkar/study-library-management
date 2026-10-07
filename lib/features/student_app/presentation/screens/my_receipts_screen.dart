import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:study_library/core/providers/library_provider.dart';
import 'package:study_library/features/students/presentation/providers/student_providers.dart';
import 'package:study_library/features/receipts/presentation/screens/receipt_preview_screen.dart';
import 'package:study_library/models/receipt_model.dart';
import 'package:study_library/models/payment_model.dart';

class MyReceiptsScreen extends ConsumerStatefulWidget {
  const MyReceiptsScreen({super.key});

  @override
  ConsumerState<MyReceiptsScreen> createState() => _MyReceiptsScreenState();
}

class _MyReceiptsScreenState extends ConsumerState<MyReceiptsScreen> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final studentAsync = ref.watch(currentStudentProvider);
    final libraryId = ref.watch(currentLibraryIdProvider);
    final dateFormat = DateFormat('dd MMM yyyy');

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Receipts & Invoices'),
        centerTitle: true,
      ),
      body: studentAsync.when(
        data: (student) {
          if (student == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.receipt_long_outlined, size: 72, color: theme.colorScheme.outline),
                    const SizedBox(height: 16),
                    Text(
                      'No Receipts Found',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Please ensure you are signed in with your registered student account.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            );
          }

          if (libraryId == null || libraryId.isEmpty) {
            return const Center(child: Text('No library selected'));
          }

          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('libraries')
                .doc(libraryId)
                .collection('receipts')
                .where('studentId', isEqualTo: student.id)
                .snapshots(),
            builder: (context, receiptSnapshot) {
              if (receiptSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final receiptDocs = receiptSnapshot.data?.docs ?? [];
              final receipts = receiptDocs
                  .map((d) => ReceiptModel.fromJson({...d.data(), 'id': d.id}))
                  .where((r) => r.deletedAt == null)
                  .toList()
                ..sort((a, b) => (b.createdAt ?? DateTime(2000)).compareTo(a.createdAt ?? DateTime(2000)));

              if (receipts.isEmpty) {
                // Check if there are raw payments
                return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection('libraries')
                      .doc(libraryId)
                      .collection('payments')
                      .where('studentId', isEqualTo: student.id)
                      .snapshots(),
                  builder: (context, paymentSnapshot) {
                    if (paymentSnapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final paymentDocs = paymentSnapshot.data?.docs ?? [];
                    if (paymentDocs.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32.0),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.receipt_long_outlined, size: 64, color: theme.colorScheme.outline),
                              const SizedBox(height: 16),
                              Text('No Receipts Available', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                              const SizedBox(height: 8),
                              Text(
                                'Once your fee payment is verified, your official receipt with tax breakdown and validity dates will appear here.',
                                textAlign: TextAlign.center,
                                style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    final payments = paymentDocs
                        .map((d) => PaymentModel.fromJson({...d.data(), 'id': d.id}))
                        .toList()
                      ..sort((a, b) => b.date.compareTo(a.date));

                    return RefreshIndicator(
                      onRefresh: () async {
                        setState(() {});
                        await Future.delayed(const Duration(milliseconds: 500));
                      },
                      child: ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: payments.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final payment = payments[index];
                          return Card(
                            elevation: 1,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              leading: CircleAvatar(
                                backgroundColor: theme.colorScheme.primaryContainer,
                                child: Icon(Icons.payment_rounded, color: theme.colorScheme.primary),
                              ),
                              title: Text(
                                'Payment ₹${payment.amount.toStringAsFixed(0)}',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              subtitle: Text('${payment.method} • ${dateFormat.format(payment.date)}'),
                              trailing: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.green.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  payment.status.name.toUpperCase(),
                                  style: const TextStyle(
                                    color: Colors.green,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    );
                },
                );
              }

              return RefreshIndicator(
                onRefresh: () async {
                  setState(() {});
                  await Future.delayed(const Duration(milliseconds: 500));
                },
                child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: receipts.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final receipt = receipts[index];
                  final createdDate = receipt.createdAt ?? DateTime.now();

                  return Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => ReceiptPreviewScreen(receiptId: receipt.id),
                          ),
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: theme.colorScheme.primaryContainer,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Icon(Icons.receipt_rounded, color: theme.colorScheme.primary, size: 24),
                                    ),
                                    const SizedBox(width: 12),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          receipt.receiptNumber,
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                        ),
                                        Text(
                                          dateFormat.format(createdDate),
                                          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                Text(
                                  '₹${receipt.amount.toStringAsFixed(0)}',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: theme.colorScheme.primary,
                                  ),
                                ),
                              ],
                            ),
                            const Divider(height: 24),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Payment Mode', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline)),
                                    const SizedBox(height: 2),
                                    Text(receipt.paymentMethod, style: const TextStyle(fontWeight: FontWeight.w600)),
                                  ],
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text('Valid Until', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline)),
                                    const SizedBox(height: 2),
                                    Text(dateFormat.format(receipt.validTo), style: const TextStyle(fontWeight: FontWeight.w600)),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                FilledButton.tonalIcon(
                                  icon: const Icon(Icons.picture_as_pdf_rounded, size: 18),
                                  label: const Text('View & Download PDF'),
                                  onPressed: () async {
                                    final confirmed = await showDialog<bool>(
                                      context: context,
                                      builder: (ctx) => AlertDialog(
                                        title: const Text('Download Receipt'),
                                        content: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Text('Receipt will include:'),
                                            const SizedBox(height: 12),
                                            _previewRow(Icons.confirmation_number, 'Receipt Number', receipt.receiptNumber),
                                            _previewRow(Icons.person, 'Student', student.name),
                                            _previewRow(Icons.currency_rupee, 'Amount', '₹${receipt.amount.toStringAsFixed(0)}'),
                                            _previewRow(Icons.payment, 'Payment', receipt.paymentMethod),
                                            _previewRow(Icons.calendar_today, 'Date', dateFormat.format(receipt.createdAt ?? DateTime.now())),
                                            const SizedBox(height: 8),
                                            const Text('Download as PDF?', style: TextStyle(fontWeight: FontWeight.bold)),
                                          ],
                                        ),
                                        actions: [
                                          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                                          FilledButton.icon(
                                            onPressed: () => Navigator.pop(ctx, true),
                                            icon: const Icon(Icons.download),
                                            label: const Text('Download PDF'),
                                          ),
                                        ],
                                      ),
                                    );
                                    if (confirmed == true && context.mounted) {
                                      Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) => ReceiptPreviewScreen(receiptId: receipt.id),
                                        ),
                                      );
                                    }
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            );
          },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error loading receipts: $err')),
      ),
    );
  }
}

Widget _previewRow(IconData icon, String label, String value) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey),
        const SizedBox(width: 8),
        Text('$label: ', style: const TextStyle(color: Colors.grey, fontSize: 13)),
        Expanded(child: Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
      ],
    ),
  );
}
