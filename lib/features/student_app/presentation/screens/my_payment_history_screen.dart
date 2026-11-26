import 'package:go_router/go_router.dart';
import 'package:study_library/core/router/app_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:study_library/core/providers/library_provider.dart';
import 'package:study_library/features/students/presentation/providers/student_providers.dart';
import 'package:study_library/features/plans/presentation/providers/plan_providers.dart';
import 'package:study_library/features/receipts/presentation/screens/receipt_preview_screen.dart';
import 'package:study_library/models/student_model.dart';
import 'package:study_library/models/receipt_model.dart';
import 'package:study_library/models/plan_model.dart';
import 'package:study_library/core/error/error_handler.dart';
import 'package:study_library/core/utils/secure_screen_mixin.dart';
import 'package:study_library/core/utils/student_ledger_helper.dart';

class MyPaymentHistoryScreen extends ConsumerStatefulWidget {
  const MyPaymentHistoryScreen({super.key});

  @override
  ConsumerState<MyPaymentHistoryScreen> createState() => _MyPaymentHistoryScreenState();
}

class _MyPaymentHistoryScreenState extends ConsumerState<MyPaymentHistoryScreen> with SecureScreenMixin {
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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back to Home',
          onPressed: () => context.canPop() ? context.pop() : context.go(Routes.studentHome),
        ),
        title: const Text('Payment History'),
        centerTitle: true,
      ),
      body: studentAsync.when(
        data: (student) {
          if (student == null || libraryId.isEmpty) {
            return const Center(child: Text('Student profile not found'));
          }

          final authUid = FirebaseAuth.instance.currentUser?.uid ?? '';
          final effectiveUid = student.userId?.isNotEmpty == true ? student.userId! : authUid;

          // Zero-index single-field queries (never use Filter.or which breaks without composite indexes)
          final receiptQuery = FirebaseFirestore.instance
              .collection('libraries')
              .doc(libraryId)
              .collection('receipts')
              .where('studentId', isEqualTo: student.id);

          final paymentQuery = FirebaseFirestore.instance
              .collection('libraries')
              .doc(libraryId)
              .collection('payments')
              .where('studentId', isEqualTo: student.id);

          final Stream<QuerySnapshot<Map<String, dynamic>>?> uidReceiptStream =
              (effectiveUid.isNotEmpty && effectiveUid != student.id)
                  ? FirebaseFirestore.instance
                      .collection('libraries')
                      .doc(libraryId)
                      .collection('receipts')
                      .where('studentUserId', isEqualTo: effectiveUid)
                      .snapshots()
                      .cast<QuerySnapshot<Map<String, dynamic>>?>()
                  : Stream.value(null);

          final Stream<QuerySnapshot<Map<String, dynamic>>?> uidPaymentStream =
              (effectiveUid.isNotEmpty && effectiveUid != student.id)
                  ? FirebaseFirestore.instance
                      .collection('libraries')
                      .doc(libraryId)
                      .collection('payments')
                      .where('studentUserId', isEqualTo: effectiveUid)
                      .snapshots()
                      .cast<QuerySnapshot<Map<String, dynamic>>?>()
                  : Stream.value(null);

          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: receiptQuery.snapshots(),
            builder: (context, receiptSnap) {
              return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: paymentQuery.snapshots(),
                builder: (context, paymentSnap) {
                  return StreamBuilder<QuerySnapshot<Map<String, dynamic>>?>(
                    stream: uidReceiptStream,
                    builder: (context, uidReceiptSnap) {
                      return StreamBuilder<QuerySnapshot<Map<String, dynamic>>?>(
                        stream: uidPaymentStream,
                        builder: (context, uidPaymentSnap) {
                  if (receiptSnap.connectionState == ConnectionState.waiting &&
                      paymentSnap.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final receiptMap = <String, Map<String, dynamic>>{};
                  for (final d in receiptSnap.data?.docs ?? []) {
                    receiptMap[d.id] = {...d.data(), 'id': d.id};
                  }
                  for (final d in uidReceiptSnap.data?.docs ?? []) {
                    receiptMap.putIfAbsent(d.id, () => {...d.data(), 'id': d.id});
                  }

                  final paymentMap = <String, Map<String, dynamic>>{};
                  for (final d in paymentSnap.data?.docs ?? []) {
                    paymentMap[d.id] = {...d.data(), 'id': d.id};
                  }
                  for (final d in uidPaymentSnap.data?.docs ?? []) {
                    paymentMap.putIfAbsent(d.id, () => {...d.data(), 'id': d.id});
                  }

                  final transactions = StudentLedgerHelper.buildTransactionsLedger(
                    libraryId: libraryId,
                    student: student,
                    receiptDocs: receiptMap.values.toList(),
                    paymentDocs: paymentMap.values.toList(),
                    plans: plansAsync.value ?? [],
                    effectiveUid: effectiveUid,
                  );

                  if (transactions.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.receipt_long_outlined, size: 64, color: Colors.grey.shade300),
                            const SizedBox(height: 16),
                            Text(
                              student.membershipStatus == MembershipStatus.inactive
                                  ? 'Admission Approved • Payment Pending at Desk'
                                  : 'No payments recorded yet',
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.grey, fontSize: 16, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  final totalPaid = StudentLedgerHelper.computeTotalPaid(transactions);

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
                              child: Icon(Icons.account_balance_wallet_rounded, color: theme.colorScheme.onPrimary, size: 24),
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
                            final rawStatus = (item['status'] ?? 'paid').toString().toLowerCase();
                            final isVoided = rawStatus == 'voided' ||
                                rawStatus == 'void' ||
                                rawStatus == 'cancelled' ||
                                rawStatus == 'canceled' ||
                                rawStatus == 'refunded';
                            final isPaid = StudentLedgerHelper.isConfirmedPaidStatus(rawStatus);

                            return Card(
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                                side: BorderSide(
                                  color: isVoided
                                      ? Colors.red.withValues(alpha: 0.35)
                                      : theme.colorScheme.outlineVariant,
                                ),
                              ),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: isVoided
                                      ? Colors.red.withValues(alpha: 0.12)
                                      : (isPaid
                                          ? Colors.green.withValues(alpha: 0.12)
                                          : Colors.orange.withValues(alpha: 0.12)),
                                  child: Icon(
                                    isVoided
                                        ? Icons.cancel_rounded
                                        : (isPaid ? Icons.check_circle_rounded : Icons.pending_rounded),
                                    color: isVoided
                                        ? Colors.red.shade700
                                        : (isPaid ? Colors.green.shade700 : Colors.orange.shade700),
                                    size: 22,
                                  ),
                                ),
                                title: Text(
                                  title,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                ),
                                subtitle: Text(
                                  '$method  •  ${dateFormat.format(date)}${isVoided ? " (${rawStatus.toUpperCase()})" : ""}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isVoided ? Colors.red.shade700 : Colors.grey.shade600,
                                  ),
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      currencyFmt.format(amount),
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: isVoided
                                            ? Colors.red.shade700
                                            : (isPaid ? Colors.green.shade700 : Colors.orange.shade700),
                                        decoration: isVoided ? TextDecoration.lineThrough : null,
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
                                        final rModel = item['receiptModel'] as ReceiptModel?;
                                        final pModel = item['planModel'] as PlanModel?;
                                        Navigator.of(context, rootNavigator: true).push(
                                          MaterialPageRoute(
                                            builder: (_) => ReceiptPreviewScreen(
                                              receiptId: receiptId,
                                              preloadedReceipt: rModel,
                                              preloadedStudent: student,
                                              preloadedPlan: pModel,
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
