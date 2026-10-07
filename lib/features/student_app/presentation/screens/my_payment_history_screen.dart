import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:study_library/features/auth/presentation/providers/auth_provider.dart';

class MyPaymentHistoryScreen extends ConsumerStatefulWidget {
  const MyPaymentHistoryScreen({super.key});

  @override
  ConsumerState<MyPaymentHistoryScreen> createState() => _MyPaymentHistoryScreenState();
}

class _MyPaymentHistoryScreenState extends ConsumerState<MyPaymentHistoryScreen> {
  @override
  Widget build(BuildContext context) {
    final libraryId = ref.watch(currentLibraryIdProvider) ?? '';
    final user = ref.watch(currentUserProvider);
    final uid = user?.uid ?? '';
    final theme = Theme.of(context);
    final currencyFmt = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

    return Scaffold(
      appBar: AppBar(title: const Text('Payment History')),
      body: libraryId.isEmpty || uid.isEmpty
          ? const Center(child: Text('Not available'))
            : FutureBuilder<QuerySnapshot<Map<String, dynamic>>>(
                future: FirebaseFirestore.instance
                    .collection('libraries')
                    .doc(libraryId)
                    .collection('students')
                    .where('userId', isEqualTo: uid)
                    .limit(1)
                    .get(),
                builder: (context, studentSnap) {
                  if (studentSnap.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final studentDocs = studentSnap.data?.docs ?? [];
                  if (studentDocs.isEmpty) {
                    return const Center(child: Text('Student profile not found'));
                  }
                  final studentDocId = studentDocs.first.id;

                  return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: FirebaseFirestore.instance
                        .collection('libraries')
                        .doc(libraryId)
                        .collection('payments')
                        .where('studentId', isEqualTo: studentDocId)
                        .orderBy('createdAt', descending: true)
                        .snapshots(),
                    builder: (context, snap) {
                      if (snap.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final docs = snap.data?.docs ?? [];
                      if (docs.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.receipt_long_outlined, size: 64, color: Colors.grey.shade300),
                              const SizedBox(height: 16),
                              const Text('No payments yet', style: TextStyle(color: Colors.grey, fontSize: 16)),
                            ],
                          ),
                        );
                      }

                      // Calculate total
                      double total = 0;
                      for (final d in docs) {
                        total += (d.data()['amount'] as num?)?.toDouble() ?? 0;
                      }

                      return Column(
                        children: [
                          // Summary card
                          Container(
                            width: double.infinity,
                            margin: const EdgeInsets.all(16),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.account_balance_wallet_rounded,
                                    color: theme.colorScheme.onPrimaryContainer, size: 32),
                                const SizedBox(width: 12),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Total Paid',
                                        style: TextStyle(color: theme.colorScheme.onPrimaryContainer, fontSize: 12)),
                                    Text(currencyFmt.format(total),
                                        style: TextStyle(
                                            color: theme.colorScheme.onPrimaryContainer,
                                            fontSize: 24,
                                            fontWeight: FontWeight.bold)),
                                  ],
                                ),
                                const Spacer(),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text('${docs.length} transactions',
                                        style: TextStyle(color: theme.colorScheme.onPrimaryContainer, fontSize: 12)),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          // Payment list
                          Expanded(
                            child: RefreshIndicator(
                              onRefresh: () async {
                                setState(() {});
                                await Future.delayed(const Duration(milliseconds: 500));
                              },
                              child: ListView.builder(
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                itemCount: docs.length,
                                itemBuilder: (ctx, i) {
                                  final data = docs[i].data();
                                  final amount = (data['amount'] as num?)?.toDouble() ?? 0;
                                  final method = data['paymentMethod'] as String? ?? data['method'] as String? ?? 'Cash';
                                  final planName = data['planName'] as String? ?? data['planId'] as String? ?? '';
                                  final receiptNum = data['receiptNumber'] as String? ?? '#${docs[i].id.substring(0, 6).toUpperCase()}';
                                  final rawDate = data['date'] ?? data['createdAt'];
                                  DateTime? date;
                                  if (rawDate is Timestamp) date = rawDate.toDate();

                                  return Card(
                                    margin: const EdgeInsets.only(bottom: 10),
                                    child: ListTile(
                                      leading: Container(
                                        width: 44,
                                        height: 44,
                                        decoration: BoxDecoration(
                                          color: Colors.green.shade50,
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(Icons.check_circle_rounded, color: Colors.green.shade600, size: 24),
                                      ),
                                      title: Text(receiptNum,
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                      subtitle: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          if (planName.isNotEmpty) Text(planName, style: const TextStyle(fontSize: 12)),
                                          Text('$method  •  ${date != null ? DateFormat('dd MMM yyyy').format(date) : 'Date unknown'}',
                                              style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                        ],
                                      ),
                                      trailing: Text(currencyFmt.format(amount),
                                          style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: Colors.green.shade700,
                                              fontSize: 16)),
                                      isThreeLine: true,
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  );
                },
              ),
    );
  }
}
