import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:study_library/features/auth/presentation/providers/auth_provider.dart';
import 'package:study_library/features/dashboard/presentation/widgets/app_update_banner.dart';
import 'package:study_library/features/students/presentation/providers/student_providers.dart';
import 'package:study_library/features/announcements/presentation/screens/announcement_list_screen.dart';
import 'package:study_library/features/plans/presentation/providers/plan_providers.dart';
import 'package:study_library/models/student_model.dart';
import 'package:study_library/services/image_service.dart';
import 'package:study_library/core/router/app_router.dart';
import 'package:study_library/services/whats_new_service.dart';
import 'package:study_library/services/expiry_scheduler_service.dart';
import 'package:study_library/services/quick_actions_service.dart';

/// Real-time stream of the current student's pending registration request.
/// Returns the request document if status == 'pending', null otherwise.
/// This enables the home screen to auto-update when admin approves without restart.
final pendingRequestProvider = StreamProvider<Map<String, dynamic>?>((ref) {
  final libraryId = ref.watch(currentLibraryIdProvider);
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (libraryId == null || libraryId.isEmpty || uid == null) return Stream.value(null);

  return FirebaseFirestore.instance
      .collection('libraries')
      .doc(libraryId)
      .collection('requests')
      .where('studentId', isEqualTo: uid)
      .where('status', isEqualTo: 'pending')
      .limit(1)
      .snapshots()
      .map((snap) => snap.docs.isNotEmpty ? snap.docs.first.data() : null);
});

class StudentHomeScreen extends ConsumerStatefulWidget {
  const StudentHomeScreen({super.key});

  @override
  ConsumerState<StudentHomeScreen> createState() => _StudentHomeScreenState();
}

class _StudentHomeScreenState extends ConsumerState<StudentHomeScreen> {
  @override
  void initState() {
    super.initState();
    QuickActionsService.initializeForStudent(context, (shortcutType) {
      if (!mounted) return;
      switch (shortcutType) {
        case 'my_membership':
          context.push(Routes.studentMembership);
          break;
        case 'my_id_card':
          context.push(Routes.studentIdCard);
          break;
      }
    });
  }

  void _scheduleRemindersIfNeeded(StudentModel student, [String libraryName = 'Cozy Corner']) {
    final planEndDate = student.planEndDate;
    if (planEndDate == null) return;
    if (student.membershipStatus != MembershipStatus.active &&
        student.membershipStatus != MembershipStatus.grace) {
      return;
    }

    ExpirySchedulerService.scheduleExpiryReminders(
      expiryDate: planEndDate,
      studentName: student.name,
      libraryName: libraryName,
      reminderDays: 3,
    ).ignore();
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (context.mounted) {
        WhatsNewService.checkAndShow(context, isStudent: true);
      }
    });

    final theme = Theme.of(context);
    final libraryAsync = ref.watch(currentLibraryProvider);
    final studentAsync = ref.watch(currentStudentProvider);
    final announcementsAsync = ref.watch(announcementsStreamProvider);
    final plansAsync = ref.watch(plansStreamProvider);

    final library = libraryAsync.value;
    final libraryName = library?.name ?? 'Cozy Corner Study Library';

    ref.listen<AsyncValue<StudentModel?>>(currentStudentProvider, (_, next) {
      next.whenData((student) {
        if (student != null) _scheduleRemindersIfNeeded(student, libraryName);
      });
    });

    return Scaffold(
      appBar: AppBar(
        leading: library?.logoUrl.isNotEmpty == true
            ? Padding(
                padding: const EdgeInsets.all(8.0),
                child: CircleAvatar(
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                  backgroundImage: ImageService.getImageProvider(library!.logoUrl),
                ),
              )
            : null,
        title: Text(libraryName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () {
              ref.invalidate(currentStudentProvider);
              ref.invalidate(announcementsStreamProvider);
            },
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: studentAsync.when(
        data: (student) {
          final studentName = student?.name ?? 'Student';
          final photoUrl = student?.photoUrl ?? '';

          // Look up assigned seat & section
          final seatId = student?.seatId;
          final sectionId = student?.sectionId;
          final planId = student?.planId;

          // Look up plan details
          final plans = plansAsync.value ?? [];
          final plan = plans.where((p) => p.id == planId).firstOrNull;

          // No student doc yet — check for a pending registration request in real-time
          if (student == null) {
            final pendingAsync = ref.watch(pendingRequestProvider);
            return pendingAsync.when(
              data: (request) {
                if (request != null) {
                  // Student has a pending request — show waiting UI
                  // This view auto-disappears when admin approves (stream emits null)
                  return _buildRealTimePendingView(context, theme, request);
                }
                // No request and no student profile
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.person_off_outlined, size: 64, color: Colors.grey.shade400),
                      const SizedBox(height: 16),
                      const Text('No student profile found.', style: TextStyle(fontSize: 16)),
                      const SizedBox(height: 8),
                      const Text('Please contact the library admin.', style: TextStyle(color: Colors.grey)),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: () => ref.invalidate(currentStudentProvider),
                        icon: const Icon(Icons.refresh),
                        label: const Text('Refresh'),
                      ),
                    ],
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, s) => const Center(child: Text('Unable to load status')),
            );
          }
          if (student.membershipStatus == MembershipStatus.pending) {
            return _buildPendingApprovalView(context, theme, student);
          }
          if (student.membershipStatus == MembershipStatus.blocked) {
            return Scaffold(
              body: Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.block_rounded, size: 64, color: Colors.red),
                      const SizedBox(height: 16),
                      const Text('Account Blocked', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text(
                        student.blockedReason ?? 'Your account has been temporarily suspended. Please contact the library admin.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.grey),
                      ),
                      const SizedBox(height: 24),
                      OutlinedButton(
                        onPressed: () async {
                          await ref.read(authRepositoryProvider).signOut();
                          if (context.mounted) context.go(Routes.login);
                        },
                        child: const Text('Sign Out'),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(currentStudentProvider);
              ref.invalidate(announcementsStreamProvider);
            },
            child: ListView(
              padding: const EdgeInsets.all(16.0),
              children: [
                const AppUpdateBanner(),
                // Header Greeting
                Row(
                  children: [
                    GestureDetector(
                      onTap: () {
                        if (photoUrl.isNotEmpty) {
                          ImageService.showImageViewer(context, imageUrl: photoUrl, title: studentName);
                        }
                      },
                      child: CircleAvatar(
                        radius: 30,
                        backgroundColor: theme.colorScheme.primaryContainer,
                        backgroundImage: photoUrl.isNotEmpty ? ImageService.getImageProvider(photoUrl) : null,
                        child: photoUrl.isEmpty
                            ? Text(studentName.isNotEmpty ? studentName[0].toUpperCase() : 'S',
                                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold))
                            : null,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Welcome back,', style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey.shade600)),
                          Text(studentName, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                    Chip(
                      label: Text(student.membershipStatus.name.toUpperCase()),
                      backgroundColor: student.membershipStatus == MembershipStatus.active
                          ? Colors.green.shade100
                          : Colors.orange.shade100,
                      labelStyle: TextStyle(
                        color: student.membershipStatus == MembershipStatus.active
                            ? Colors.green.shade900
                              : Colors.orange.shade900,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 20),

                // Active Announcement Banner (if any)
                announcementsAsync.when(
                  data: (announcements) {
                    final activeAnnouncements = announcements.where((a) => a.isActive).toList();
                    if (activeAnnouncements.isEmpty) return const SizedBox.shrink();
                    final topAnnouncement = activeAnnouncements.first;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.tertiaryContainer.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: theme.colorScheme.tertiary.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.campaign_rounded, color: theme.colorScheme.tertiary, size: 28),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  topAnnouncement.title,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                    color: theme.colorScheme.onTertiaryContainer,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  topAnnouncement.message,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: theme.colorScheme.onTertiaryContainer.withValues(alpha: 0.85),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                  loading: () => const SizedBox.shrink(),
                  error: (_, _) => const SizedBox.shrink(),
                ),

                // Live Membership Card
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  color: theme.colorScheme.primaryContainer.withValues(alpha: 0.45),
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.card_membership_rounded, color: theme.colorScheme.primary),
                                const SizedBox(width: 8),
                                Text('Membership Card', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                              ],
                            ),
                            if (plan != null)
                              Text('₹${plan.price.toStringAsFixed(0)}', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: theme.colorScheme.primary)),
                          ],
                        ),
                        const Divider(height: 24),
                        if (student.planEndDate != null) ...[
                          Text(
                            plan?.name ?? 'Active Study Plan',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Valid until: ${DateFormat('dd MMM yyyy').format(student.planEndDate!)}',
                            style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                          ),
                          const SizedBox(height: 14),
                          Builder(builder: (context) {
                            final daysLeft = student.planEndDate!.difference(DateTime.now()).inDays;
                            final color = daysLeft > 7 ? Colors.green : daysLeft > 0 ? Colors.orange : Colors.red;
                            final totalDays = (student.planStartDate != null)
                                ? student.planEndDate!.difference(student.planStartDate!).inDays
                                : 30;
                            final progress = totalDays > 0 ? (daysLeft / totalDays).clamp(0.0, 1.0) : 0.0;

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      daysLeft > 0 ? '$daysLeft Days Remaining' : 'Expired ${-daysLeft} days ago',
                                      style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13),
                                    ),
                                    Text('${(progress * 100).toInt()}%', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: LinearProgressIndicator(
                                    value: progress,
                                    color: color,
                                    backgroundColor: Colors.grey.shade200,
                                    minHeight: 8,
                                  ),
                                ),
                              ],
                            );
                          }),
                        ] else ...[
                          const Text('No active membership plan assigned yet.', style: TextStyle(fontSize: 15)),
                          const SizedBox(height: 8),
                          FilledButton.tonal(
                            onPressed: () => context.push(Routes.studentRenew),
                            child: const Text('Apply / Renew Plan'),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Assigned Seat Card
                Card(
                  elevation: 1,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    leading: CircleAvatar(
                      backgroundColor: theme.colorScheme.secondaryContainer,
                      child: Icon(Icons.event_seat_rounded, color: theme.colorScheme.onSecondaryContainer),
                    ),
                    title: Text(
                      seatId != null ? 'Seat Assigned' : 'No Seat Assigned',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    subtitle: Text(
                      seatId != null
                          ? 'Section ID: $sectionId'
                          : 'Contact admin or apply for seat allocation.',
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                    ),
                    trailing: OutlinedButton(
                      onPressed: () => context.push(Routes.studentSeatMap),
                      child: const Text('Seat Map'),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Quick Action Grid
                Text('Quick Services', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 14),
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.45,
                  children: [
                    _QuickTile(
                      icon: Icons.badge_rounded,
                      title: 'My ID Card',
                      subtitle: 'Digital Pass & PDF',
                      color: const Color(0xFF2563EB),
                      onTap: () => context.push(Routes.studentIdCard),
                    ),
                    _QuickTile(
                      icon: Icons.autorenew_rounded,
                      title: 'Renew Plan',
                      subtitle: 'Extend validity',
                      color: const Color(0xFF4F46E5),
                      onTap: () => context.push(Routes.studentRenew),
                    ),
                    _QuickTile(
                      icon: Icons.receipt_long_rounded,
                      title: 'My Receipts',
                      subtitle: 'Download PDFs',
                      color: const Color(0xFF059669),
                      onTap: () => context.push(Routes.studentReceipts),
                    ),
                    _QuickTile(
                      icon: Icons.history_rounded,
                      title: 'Payment History',
                      subtitle: 'View transactions',
                      color: const Color(0xFF0284C7),
                      onTap: () => context.push(Routes.studentPaymentHistory),
                    ),
                    _QuickTile(
                      icon: Icons.rate_review_rounded,
                      title: 'Feedback',
                      subtitle: 'Rate & suggest',
                      color: const Color(0xFFD97706),
                      onTap: () => context.push(Routes.studentFeedback),
                    ),
                    _QuickTile(
                      icon: Icons.menu_book_rounded,
                      title: 'Library Rules',
                      subtitle: 'Guidelines',
                      color: const Color(0xFF7C3AED),
                      onTap: () => _showRulesDialog(context, library?.rulesText ?? '1. Maintain strict silence in reading halls.\n2. Keep mobile phones on silent.\n3. Return study materials to designated racks.\n4. Eating inside reading halls is prohibited.'),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Contact Admin Card
                if (library?.contact != null && library!.contact.isNotEmpty) ...[
                  Card(
                    color: Colors.grey.shade50,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: Color(0xFFEEF2FF),
                        child: Icon(Icons.support_agent_rounded, color: Color(0xFF4F46E5)),
                      ),
                      title: const Text('Need Help? Contact Admin', style: TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(library.contact),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.phone, color: Colors.green),
                            onPressed: () async {
                              final uri = Uri.parse('tel:${library.contact}');
                              if (await canLaunchUrl(uri)) await launchUrl(uri);
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.chat_bubble_rounded, color: Color(0xFF25D366)),
                            onPressed: () async {
                              final cleanPhone = library.contact.replaceAll(RegExp(r'\D'), '');
                              final uri = Uri.parse('https://wa.me/$cleanPhone?text=Hello%20Admin,%20I%20am%20a%20student%20at%20${Uri.encodeComponent(libraryName)}');
                              if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error loading student profile: $err')),
      ),
    );
  }

  void _showRulesDialog(BuildContext context, String rules) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.gavel_rounded, color: Color(0xFF4F46E5)),
            SizedBox(width: 8),
            Text('Library Rules'),
          ],
        ),
        content: SingleChildScrollView(
          child: Text(rules, style: const TextStyle(height: 1.5)),
        ),
        actions: [
          FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('Got it')),
        ],
      ),
    );
  }
}

class _QuickTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _QuickTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: color.withValues(alpha: 0.15),
              child: Icon(icon, size: 20, color: color),
            ),
            const SizedBox(height: 10),
            Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: color)),
            Text(subtitle, style: TextStyle(color: Colors.grey.shade600, fontSize: 11)),
          ],
        ),
      ),
    );
  }
}

Widget _buildPendingApprovalView(BuildContext context, ThemeData theme, StudentModel student) {
  return Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 88, height: 88,
            decoration: BoxDecoration(
              color: Colors.amber.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.pending_actions_rounded, size: 48, color: Colors.amber.shade700),
          ),
          const SizedBox(height: 24),
          Text(
            'Application Under Review',
            style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color: Colors.amber.shade50,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.amber.shade300),
            ),
            child: Text('⏳ Pending Admin Approval', style: TextStyle(color: Colors.amber.shade800, fontWeight: FontWeight.w600, fontSize: 13)),
          ),
          const SizedBox(height: 20),
          Text(
            'Hello ${student.name.split(' ').first}! 👋\n\nYour registration is currently being reviewed by the library administrator. You will receive a notification once your membership is confirmed.\n\nThis usually takes less than 24 hours.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant, height: 1.6),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ),
  );
}

/// Shown when student has a pending request doc but no student record yet.
/// Reacts in real-time: auto-transitions to full home when admin approves.
Widget _buildRealTimePendingView(BuildContext context, ThemeData theme, Map<String, dynamic> request) {
  final studentName = (request['studentName'] as String? ?? 'Student').split(' ').first;
  final requestId = request['id'] as String? ?? '';
  return Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 88, height: 88,
            decoration: BoxDecoration(color: Colors.amber.shade100, shape: BoxShape.circle),
            child: Icon(Icons.pending_actions_rounded, size: 48, color: Colors.amber.shade700),
          ),
          const SizedBox(height: 24),
          Text(
            'Application Under Review',
            style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color: Colors.amber.shade50,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.amber.shade300),
            ),
            child: Text('⏳ Pending Admin Approval',
                style: TextStyle(color: Colors.amber.shade800, fontWeight: FontWeight.w600, fontSize: 13)),
          ),
          const SizedBox(height: 20),
          Text(
            'Hello $studentName! 👋\n\nYour registration is being reviewed by the library administrator. You will be notified once your membership is confirmed.\n\nThis usually takes less than 24 hours.',
            style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant, height: 1.6),
            textAlign: TextAlign.center,
          ),
          if (requestId.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text('Reference: #${requestId.substring(0, 8).toUpperCase()}',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500, fontFamily: 'monospace')),
          ],
          const SizedBox(height: 8),
          const Text('🔄 This screen will update automatically when approved.',
              style: TextStyle(fontSize: 11, color: Colors.grey)),
        ],
      ),
    ),
  );
}
