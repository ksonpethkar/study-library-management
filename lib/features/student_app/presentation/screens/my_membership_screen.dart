import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:study_library/core/providers/library_provider.dart';
import 'package:study_library/core/router/app_router.dart';
import 'package:study_library/features/students/presentation/providers/student_providers.dart';
import 'package:study_library/features/plans/presentation/providers/plan_providers.dart';
import 'package:study_library/models/payment_model.dart';

class MyMembershipScreen extends ConsumerWidget {
  const MyMembershipScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final studentAsync = ref.watch(currentStudentProvider);
    final plansAsync = ref.watch(plansStreamProvider);
    final libraryId = ref.watch(currentLibraryIdProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Membership'),
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
                    Icon(Icons.badge_outlined, size: 72, color: theme.colorScheme.outline),
                    const SizedBox(height: 16),
                    Text(
                      'No Active Membership Found',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Your account is not linked to an active student membership yet. Please register or contact your library administrator.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 24),
                    StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('libraries')
                          .doc(libraryId)
                          .collection('requests')
                          .where('studentId', isEqualTo: FirebaseAuth.instance.currentUser?.uid)
                          .where('status', isEqualTo: 'pending')
                          .limit(1)
                          .snapshots(),
                      builder: (context, snap) {
                        final hasPending = snap.data?.docs.isNotEmpty ?? false;
                        if (hasPending) {
                          return Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(children: const [
                                Icon(Icons.hourglass_top_rounded, color: Colors.orange, size: 48),
                                SizedBox(height: 8),
                                Text('Request Pending', style: TextStyle(fontWeight: FontWeight.bold)),
                                SizedBox(height: 4),
                                Text('Your seat request is waiting for admin approval.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
                              ]),
                            ),
                          );
                        }
                        return FilledButton.icon(
                          icon: const Icon(Icons.app_registration_rounded),
                          label: const Text('Register for Seat'),
                          onPressed: () => context.push(Routes.studentRegister),
                        );
                      },
                    ),
                  ],
                ),
              ),
            );
          }

          // Match plan
          final plans = plansAsync.value ?? [];
          final currentPlan = plans.where((p) => p.id == student.planId).firstOrNull;
          final planName = currentPlan?.name ?? (student.planId != null ? 'Study Plan' : 'No Plan Assigned');
          final planPrice = currentPlan != null ? '₹${currentPlan.price.toStringAsFixed(0)}' : '';

          // Dates
          final startDate = student.planStartDate;
          final endDate = student.planEndDate;
          final dateFormat = DateFormat('dd MMM yyyy');

          final now = DateTime.now();
          final daysRemaining = endDate != null ? endDate.difference(now).inDays : 0;
          final totalDays = (startDate != null && endDate != null)
              ? endDate.difference(startDate).inDays
              : 30;
          final progress = totalDays > 0
              ? (daysRemaining / totalDays).clamp(0.0, 1.0)
              : 0.0;

          final isExpired = daysRemaining <= 0;
          final isExpiringSoon = !isExpired && daysRemaining <= 5;

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(currentStudentProvider);
              ref.invalidate(plansStreamProvider);
            },
            child: ListView(
              padding: const EdgeInsets.all(16.0),
              children: [
                // Active Plan Card
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    planName,
                                    style: theme.textTheme.headlineSmall?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: theme.colorScheme.primary,
                                    ),
                                  ),
                                  if (planPrice.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      planPrice,
                                      style: theme.textTheme.titleMedium?.copyWith(
                                        color: theme.colorScheme.onSurfaceVariant,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 8),
                                  Builder(
                                    builder: (context) {
                                      final status = student.membershipStatus.name;
                                      return Chip(
                                        label: Text(status.toUpperCase()),
                                        backgroundColor: status == 'active' ? Colors.green.shade100 
                                          : status == 'grace' ? Colors.orange.shade100 
                                          : status == 'expired' ? Colors.red.shade100
                                          : Colors.grey.shade100,
                                        labelStyle: TextStyle(
                                          color: status == 'active' ? Colors.green.shade800
                                            : status == 'grace' ? Colors.orange.shade800
                                            : status == 'expired' ? Colors.red.shade800
                                            : Colors.grey.shade800,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      );
                                    }
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: isExpired
                                    ? Colors.red.withValues(alpha: 0.12)
                                    : (isExpiringSoon
                                        ? Colors.orange.withValues(alpha: 0.12)
                                        : Colors.green.withValues(alpha: 0.12)),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                isExpired ? 'Expired' : (isExpiringSoon ? 'Expiring Soon' : 'Active'),
                                style: TextStyle(
                                  color: isExpired ? Colors.red : (isExpiringSoon ? Colors.orange : Colors.green),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),

                        // Progress Bar
                        LinearProgressIndicator(
                          value: progress,
                          minHeight: 8,
                          borderRadius: BorderRadius.circular(4),
                          backgroundColor: theme.colorScheme.surfaceContainerHighest,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            isExpired ? Colors.red : (isExpiringSoon ? Colors.orange : theme.colorScheme.primary),
                          ),
                        ),
                        const SizedBox(height: 12),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              isExpired ? '0 Days Remaining' : '$daysRemaining Days Remaining',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: isExpired ? Colors.red : (isExpiringSoon ? Colors.orange : theme.colorScheme.onSurface),
                              ),
                            ),
                            if (totalDays > 0)
                              Text(
                                'Total $totalDays days',
                                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
                              ),
                          ],
                        ),
                        const Divider(height: 28),

                        // Start & End Dates
                        Row(
                          children: [
                            Expanded(
                              child: _DateBlock(
                                label: 'Start Date',
                                date: startDate != null ? dateFormat.format(startDate) : 'N/A',
                                icon: Icons.calendar_today_rounded,
                              ),
                            ),
                            Expanded(
                              child: _DateBlock(
                                label: 'Valid Until',
                                date: endDate != null ? dateFormat.format(endDate) : 'N/A',
                                icon: Icons.event_available_rounded,
                              ),
                            ),
                          ],
                        ),
                        if (student.seatId != null) ...[
                          const SizedBox(height: 12),
                          FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                            future: (libraryId != null && student.sectionId != null)
                                ? FirebaseFirestore.instance
                                    .collection('libraries')
                                    .doc(libraryId)
                                    .collection('sections')
                                    .doc(student.sectionId)
                                    .collection('seats')
                                    .doc(student.seatId)
                                    .get()
                                : null,
                            builder: (context, seatSnap) {
                              final seatData = seatSnap.data?.data();
                              final seatLabel = seatData?['label'] ?? 'Seat #${student.seatId}';
                              return Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.primaryContainer.withValues(alpha: 0.4),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.chair_rounded, color: theme.colorScheme.primary),
                                    const SizedBox(width: 10),
                                    Text('Assigned Seat: ', style: theme.textTheme.bodyMedium),
                                    Text(
                                      seatLabel,
                                      style: theme.textTheme.bodyMedium?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: theme.colorScheme.primary,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => context.push(Routes.studentRenew),
                        icon: const Icon(Icons.autorenew_rounded),
                        label: const Text('Renew Plan'),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => context.push(Routes.studentIdCard),
                        icon: const Icon(Icons.badge_rounded),
                        label: const Text('Digital ID Card'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),

                // Payment History Section
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Payment History', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                    TextButton(
                      onPressed: () => context.push(Routes.studentReceipts),
                      child: const Text('View All Receipts'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                if (libraryId != null)
                  StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: FirebaseFirestore.instance
                        .collection('libraries')
                        .doc(libraryId)
                        .collection('payments')
                        .where('studentId', isEqualTo: student.id)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()));
                      }

                      final docs = snapshot.data?.docs ?? [];
                      if (docs.isEmpty) {
                        return Card(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          child: Padding(
                            padding: const EdgeInsets.all(24.0),
                            child: Center(
                              child: Column(
                                children: [
                                  Icon(Icons.receipt_long_outlined, size: 40, color: theme.colorScheme.outline),
                                  const SizedBox(height: 8),
                                  Text('No payment records found', style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.outline)),
                                ],
                              ),
                            ),
                          ),
                        );
                      }

                      // Parse and sort by date descending
                      final payments = docs.map((d) => PaymentModel.fromJson({...d.data(), 'id': d.id})).toList()
                        ..sort((a, b) => b.date.compareTo(a.date));

                      return ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: payments.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final payment = payments[index];
                          final isPaid = payment.status == PaymentStatus.paid;

                          return Card(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: isPaid ? Colors.green.withValues(alpha: 0.12) : Colors.orange.withValues(alpha: 0.12),
                                child: Icon(
                                  isPaid ? Icons.check_circle_outline : Icons.pending_outlined,
                                  color: isPaid ? Colors.green : Colors.orange,
                                ),
                              ),
                              title: Text(
                                '₹${payment.amount.toStringAsFixed(0)}',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              subtitle: Text(
                                '${payment.method} • ${dateFormat.format(payment.date)}',
                              ),
                              trailing: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: isPaid ? Colors.green.withValues(alpha: 0.12) : Colors.orange.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  payment.status.name.toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: isPaid ? Colors.green : Colors.orange,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.red),
                const SizedBox(height: 12),
                Text('Error loading membership: $err', textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DateBlock extends StatelessWidget {
  final String label;
  final String date;
  final IconData icon;

  const _DateBlock({required this.label, required this.date, required this.icon});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 20, color: theme.colorScheme.outline),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline)),
            const SizedBox(height: 2),
            Text(date, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
          ],
        ),
      ],
    );
  }
}
