import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:study_library/core/providers/library_provider.dart';
import 'package:study_library/features/students/presentation/providers/student_providers.dart';
import 'package:study_library/features/plans/presentation/providers/plan_providers.dart';
import 'package:study_library/features/receipts/presentation/screens/receipt_preview_screen.dart';
import 'package:study_library/core/error/error_handler.dart';

class MyPaymentHistoryScreen extends ConsumerStatefulWidget {
  const MyPaymentHistoryScreen({super.key});

  @override
  ConsumerState<MyPaymentHistoryScreen> createState() => _MyPaymentHistoryScreenState();
}

class _MyPaymentHistoryScreenState extends ConsumerState<MyPaymentHistoryScreen> {
  @override
  Widget build(BuildContext context) {
    final libraryId = ref.watch(currentLibraryIdProvider) ?? '';
    final studentAsync = ref.watch(currentStudentProvider);
    final plansAsync = ref.watch(plansStreamProvider);
    final theme = Theme.of(context);
    final currencyFmt = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
    final dateFormat = DateFormat('dd MMM yyyy');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Payment History'),
        centerTitle: true,
      ),
      body: studentAsync.when(
        data: (student) {
          if (student == null || libraryId.isEmpty) {
            return const Center(child: Text('Student profile not found'));
          }

          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('libraries')
                .doc(libraryId)
                .collection('receipts')
                .where('studentId', isEqualTo: student.id)
                .snapshots(),
            builder: (context, receiptSnap) {
              return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('libraries')
                    .doc(libraryId)
                    .collection('payments')
                    .where('studentId', isEqualTo: student.id)
                    .snapshots(),
                builder: (context, paymentSnap) {
                  if (receiptSnap.connectionState == ConnectionState.waiting &&
                      paymentSnap.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final List<Map<String, dynamic>> transactions = [];
                  final Set<String> seenReceiptIds = {};

                  // 1. Receipts
                  for (final doc in receiptSnap.data?.docs ?? []) {
                    final data = doc.data();
                    if (data['deletedAt'] != null) continue;
                    seenReceiptIds.add(doc.id);

                    DateTime date = DateTime.now();
                    final raw = data['createdAt'] ?? data['validFrom'];
                    if (raw is Timestamp) date = raw.toDate();
                    if (raw is String) date = DateTime.tryParse(raw) ?? date;

                    transactions.add({
                      'id': doc.id,
                      'receiptId': doc.id,
                      'title': data['receiptNumber'] ?? 'Official Receipt',
                      'amount': (data['amount'] as num?)?.toDouble() ?? 0.0,
                      'date': date,
                      'method': data['paymentMethod'] ?? 'Paid',
                      'planName': data['planName'] ?? '',
                      'status': data['status'] ?? 'paid',
                    });
                  }

                  // 2. Payments
                  for (final doc in paymentSnap.data?.docs ?? []) {
                    final data = doc.data();
                    final rId = data['receiptId'] as String?;
                    if (rId != null && seenReceiptIds.contains(rId)) continue;

                    DateTime date = DateTime.now();
                    final raw = data['date'] ?? data['createdAt'];
                    if (raw is Timestamp) date = raw.toDate();
                    if (raw is String) date = DateTime.tryParse(raw) ?? date;

                    transactions.add({
                      'id': doc.id,
                      'receiptId': rId,
                      'title': data['referenceNumber']?.toString().isNotEmpty == true
                          ? 'Ref: ${data['referenceNumber']}'
                          : 'Payment #${doc.id.substring(0, 6).toUpperCase()}',
                      'amount': (data['amount'] as num?)?.toDouble() ?? 0.0,
                      'date': date,
                      'method': data['paymentMethod'] ?? data['method'] ?? 'Cash',
                      'planName': data['planName'] ?? '',
                      'status': data['status'] ?? 'paid',
                    });
                  }

                  // 3. Active plan enrollment fallback
                  if (transactions.isEmpty && student.planId != null) {
                    final plans = plansAsync.value ?? [];
                    final plan = plans.where((p) => p.id == student.planId).firstOrNull;
                    final price = plan?.price ?? 0.0;
                    final startDate = student.planStartDate ?? student.createdAt ?? DateTime.now();

                    transactions.add({
                      'id': 'plan_enrollment',
                      'receiptId': null,
                      'title': '${plan?.name ?? "Membership Plan"} Enrollment',
                      'amount': price,
                      'date': startDate,
                      'method': 'Desk / Confirmed',
                      'planName': plan?.name ?? '',
                      'status': 'active',
                    });
                  }

                  // Sort by date descending
                  transactions.sort((a, b) => (b['date'] as DateTime).compareTo(a['date'] as DateTime));

                  if (transactions.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.receipt_long_outlined, size: 64, color: Colors.grey.shade300),
                          const SizedBox(height: 16),
                          const Text('No payments recorded yet', style: TextStyle(color: Colors.grey, fontSize: 16)),
                        ],
                      ),
                    );
                  }

                  double totalPaid = 0;
                  for (final t in transactions) {
                    totalPaid += (t['amount'] as double);
                  }

                  return Column(
                    children: [
                      // Summary Card
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.all(16),
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: theme.colorScheme.primary,
                              radius: 22,
                              child: const Icon(Icons.account_balance_wallet_rounded, color: Colors.white, size: 24),
                            ),
                            const SizedBox(width: 14),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Total Paid Fees',
                                    style: TextStyle(color: theme.colorScheme.onPrimaryContainer, fontSize: 12)),
                                Text(
                                  currencyFmt.format(totalPaid),
                                  style: TextStyle(
                                    color: theme.colorScheme.onPrimaryContainer,
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.surface.withValues(alpha: 0.6),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '${transactions.length} Records',
                                style: TextStyle(
                                  color: theme.colorScheme.onSurface,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Transactions List
                      Expanded(
                        child: ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          itemCount: transactions.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 10),
                          itemBuilder: (ctx, i) {
                            final item = transactions[i];
                            final amount = item['amount'] as double;
                            final method = item['method'] as String;
                            final title = item['title'] as String;
                            final date = item['date'] as DateTime;
                            final receiptId = item['receiptId'] as String?;

                            return Card(
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                                side: BorderSide(color: theme.colorScheme.outlineVariant),
                              ),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: Colors.green.withValues(alpha: 0.12),
                                  child: Icon(Icons.check_circle_rounded, color: Colors.green.shade700, size: 22),
                                ),
                                title: Text(
                                  title,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                ),
                                subtitle: Text(
                                  '$method  •  ${dateFormat.format(date)}',
                                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      currencyFmt.format(amount),
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.green.shade700,
                                        fontSize: 16,
                                      ),
                                    ),
                                    if (receiptId != null) ...[
                                      const SizedBox(width: 8),
                                      const Icon(Icons.chevron_right_rounded, size: 20, color: Colors.grey),
                                    ],
                                  ],
                                ),
                                onTap: receiptId != null
                                    ? () {
                                        Navigator.of(context, rootNavigator: true).push(
                                          MaterialPageRoute(
                                            builder: (_) => ReceiptPreviewScreen(
                                              receiptId: receiptId,
                                              preloadedStudent: student,
                                              isStudent: true,
                                            ),
                                          ),
                                        );
                                      }
                                    : null,
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              ErrorHandler.handleError(err),
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
            ),
          ),
        ),
      ),
    );
  }
}
