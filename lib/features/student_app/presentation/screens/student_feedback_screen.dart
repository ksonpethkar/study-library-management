import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:study_library/core/providers/library_provider.dart';
import 'package:study_library/features/students/presentation/providers/student_providers.dart';
import 'package:study_library/core/utils/error_formatter.dart';
import 'package:study_library/models/feedback_model.dart';
import 'package:study_library/core/router/app_router.dart';
import 'package:study_library/services/app_notification_service.dart';
import 'package:study_library/features/student_app/presentation/widgets/silent_reception_help_sheet.dart';

class StudentFeedbackScreen extends ConsumerStatefulWidget {
  const StudentFeedbackScreen({super.key});

  @override
  ConsumerState<StudentFeedbackScreen> createState() => _StudentFeedbackScreenState();
}

class _StudentFeedbackScreenState extends ConsumerState<StudentFeedbackScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _rating = 5;
  String _category = 'Cleanliness & Hygiene';
  final _messageController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isSubmitting = false;

  final List<String> _categories = [
    'Cleanliness & Hygiene',
    'High-Speed WiFi & Power',
    'Noise & Silence Disturbance',
    'Air Conditioning & Environment',
    'Seat Comfort & Lighting',
    'Staff / Admin Support',
    'Water & Facilities Maintenance',
    'General Suggestion / Idea',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  String _getRatingLabel(int rating) {
    switch (rating) {
      case 1:
        return 'Needs Urgent Improvement';
      case 2:
        return 'Fair (Having Issues)';
      case 3:
        return 'Good';
      case 4:
        return 'Very Good';
      case 5:
        return 'Excellent';
      default:
        return '';
    }
  }

  String _getHintText() {
    if (_category == 'General Suggestion / Idea' || _category == 'General Suggestion') {
      return 'Share your suggestions or ideas to improve the library...';
    }
    if (_rating <= 2) {
      return 'Please describe the issue or problem in detail so management can resolve it promptly...';
    }
    if (_rating >= 4) {
      return 'Tell us what you like or any ideas to make your experience even better...';
    }
    return 'Describe your study experience, feedback, or any issues in detail...';
  }

  Future<void> _submitFeedback() async {
    if (!_formKey.currentState!.validate()) return;

    final libraryId = ref.read(currentLibraryIdProvider);
    if (libraryId == null || libraryId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No library selected')),
      );
      return;
    }

    final student = ref.read(currentStudentProvider).value;
    final authUser = FirebaseAuth.instance.currentUser;

    setState(() => _isSubmitting = true);

    // Smart Auto-Classification:
    final String autoFeedbackType;
    if (_category.contains('Suggestion')) {
      autoFeedbackType = 'suggestion';
    } else if (_rating <= 2) {
      autoFeedbackType = 'issue';
    } else if (_rating == 3) {
      autoFeedbackType = 'suggestion';
    } else {
      autoFeedbackType = 'feedback';
    }

    try {
      final authUid = authUser?.uid ?? '';
      final studentDocId = student?.id ?? authUid;
      final effectiveUserId = authUid.isNotEmpty ? authUid : (student?.userId ?? '');

      await FirebaseFirestore.instance
          .collection('libraries')
          .doc(libraryId)
          .collection('feedback')
          .add({
        'rating': _rating,
        'feedbackType': autoFeedbackType,
        'category': _category,
        'message': _messageController.text.trim(),
        'libraryId': libraryId,
        'studentId': studentDocId,
        'userId': effectiveUserId,
        'studentUserId': effectiveUserId,
        'studentEmail': authUser?.email ?? student?.email ?? '',
        'studentName': student?.name ?? authUser?.displayName ?? 'Student',
        'studentPhone': student?.phone ?? '',
        'seatNumber': student?.seatId ?? '',
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });

      final studentFeedbackMsg = _messageController.text.trim();
      AppNotificationService.sendNotification(
        libraryId: libraryId,
        title: 'New Student ${autoFeedbackType == "issue" ? "Issue Report" : "Feedback"} 💬',
        body: '${student?.name ?? "A student"} submitted $_category feedback: "$studentFeedbackMsg".',
        type: 'feedback',
        targetRole: 'admin',
        actionRoute: Routes.adminFeedback,
      ).ignore();

      _messageController.clear();
      setState(() => _rating = 5);

      if (mounted) {
        final successMsg = autoFeedbackType == 'issue'
            ? 'Your issue report has been submitted to management for prompt resolution.'
            : (autoFeedbackType == 'suggestion'
                ? 'Thank you! Your suggestion has been forwarded to library administration.'
                : 'Thank you! Your feedback has been sent to library management.');

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(child: Text(successMsg, style: const TextStyle(fontWeight: FontWeight.w500))),
              ],
            ),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
        // Switch to history tab so student sees their submitted feedback immediately
        _tabController.animateTo(1);
      }
    } catch (e) {
      if (mounted) {
        final friendlyMsg = AppErrorFormatter.toUserFriendly(e, actionContext: 'feedback');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.info_outline_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    friendlyMsg,
                    style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.red.shade800,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final student = ref.watch(currentStudentProvider).value;
    final libraryId = ref.watch(currentLibraryIdProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back',
          onPressed: () => context.canPop() ? context.pop() : context.go(Routes.studentHome),
        ),
        title: const Text('Feedback & Suggestions'),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          labelColor: theme.colorScheme.primary,
          unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
          indicatorColor: theme.colorScheme.primary,
          indicatorWeight: 3,
          tabs: const [
            Tab(
              icon: Icon(Icons.rate_review_rounded),
              text: 'Send Feedback',
            ),
            Tab(
              icon: Icon(Icons.history_edu_rounded),
              text: 'My History & Replies',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // TAB 1: UNIFIED SUBMIT FEEDBACK & REPORT ISSUES
          Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(20.0),
              children: [
                // Phase 4: Silent Reception Help Action Card
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F766E).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF14B8A6).withValues(alpha: 0.35)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(9),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0D9488).withValues(alpha: 0.18),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.volume_off_rounded, color: Color(0xFF0D9488), size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Need Immediate Quiet Help?',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F766E)),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Send a discrete silent alert to Reception for noise, AC, Wi-Fi or water.',
                              style: TextStyle(fontSize: 11.5, color: theme.colorScheme.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton.tonal(
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF0D9488),
                          foregroundColor: Colors.white,
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () {
                          SilentReceptionHelpSheet.show(
                            context,
                            libraryId: libraryId ?? '',
                            student: student,
                          );
                        },
                        child: const Text('Quiet Alert', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),

                // Star Rating Header Card
                Card(
                  elevation: 0,
                  color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      children: [
                        Text('How is your study experience?',
                            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(5, (index) {
                            final starValue = index + 1;
                            return IconButton(
                              iconSize: 38,
                              icon: Icon(
                                starValue <= _rating ? Icons.star_rounded : Icons.star_outline_rounded,
                                color: _rating <= 2 ? Colors.orange.shade700 : Colors.amber,
                              ),
                              onPressed: () => setState(() => _rating = starValue),
                            );
                          }),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _getRatingLabel(_rating),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: _rating <= 2 ? Colors.red.shade700 : theme.colorScheme.primary,
                          ),
                        ),
                        if (_rating <= 2) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.red.shade200),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.report_problem_rounded, color: Colors.red.shade800, size: 14),
                                const SizedBox(width: 6),
                                Text(
                                  'Low rating will be auto-flagged as an Issue for prompt resolution',
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.red.shade900),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Category Dropdown
                Text('Topic / Category',
                    style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: _category,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.category_rounded),
                  ),
                  items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _category = val);
                  },
                ),
                const SizedBox(height: 20),

                // Message text field
                Text(
                  _rating <= 2 ? 'Issue / Problem Details' : 'Details / Comments',
                  style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _messageController,
                  maxLines: 5,
                  decoration: InputDecoration(
                    border: const OutlineInputBorder(),
                    hintText: _getHintText(),
                    alignLabelWithHint: true,
                  ),
                  validator: (v) =>
                      (v == null || v.trim().length < 5) ? 'Please enter at least 5 characters' : null,
                ),
                const SizedBox(height: 32),

                // Submit Button
                FilledButton.icon(
                  icon: _isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.send_rounded),
                  label: Text(_isSubmitting
                      ? 'Submitting...'
                      : (_rating <= 2 ? 'Submit Issue Report' : 'Submit Feedback')),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _isSubmitting ? null : _submitFeedback,
                ),
              ],
            ),
          ),

          // TAB 2: MY FEEDBACK HISTORY & ADMIN REPLIES
          _buildFeedbackHistory(context, theme, libraryId, student),
        ],
      ),
    );
  }

  Widget _buildFeedbackHistory(
    BuildContext context,
    ThemeData theme,
    String? libraryId,
    dynamic student,
  ) {
    final authUser = FirebaseAuth.instance.currentUser;
    if (libraryId == null || libraryId.isEmpty || (student == null && authUser == null)) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.history_edu_rounded, size: 64, color: theme.colorScheme.outline),
              const SizedBox(height: 16),
              const Text('No Feedback History Found', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 8),
              Text(
                'Submit your first feedback or suggestion to track responses from library management.',
                textAlign: TextAlign.center,
                style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      );
    }

    final dateFormat = DateFormat('dd MMM yyyy • hh:mm a');
    final authUid = authUser?.uid ?? '';

    Query<Map<String, dynamic>> feedbackQuery = FirebaseFirestore.instance
        .collection('libraries')
        .doc(libraryId)
        .collection('feedback');

    if (authUid.isNotEmpty) {
      feedbackQuery = feedbackQuery.where(
        Filter.or(
          Filter('studentUserId', isEqualTo: authUid),
          Filter('userId', isEqualTo: authUid),
          Filter('studentId', isEqualTo: authUid),
        ),
      );
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: feedbackQuery.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data?.docs ?? [];
        final authUid = authUser?.uid ?? '';
        final authEmail = authUser?.email?.toLowerCase().trim() ?? '';
        final studentId = (student?.id ?? '').toString();
        final studentUserId = (student?.userId ?? '').toString();
        final studentEmail = (student?.email ?? '').toString().toLowerCase().trim();
        final studentPhone = (student?.phone ?? '').toString().replaceAll(RegExp(r'\D'), '');

        // Match all submissions belonging to this student across all possible identifiers
        final userFeedback = docs.map((d) {
          final data = d.data();
          final model = FeedbackModel.fromJson({...data, 'id': d.id});
          return (model, data);
        }).where((pair) {
          final f = pair.$1;
          final d = pair.$2;
          final docUid = (d['userId'] as String? ?? '').trim();
          final docEmail = (d['studentEmail'] as String? ?? '').toLowerCase().trim();
          final docPhone = (f.studentPhone ?? '').replaceAll(RegExp(r'\D'), '');

          if (studentId.isNotEmpty && f.studentId == studentId) return true;
          if (authUid.isNotEmpty && (f.studentId == authUid || docUid == authUid)) return true;
          if (studentUserId.isNotEmpty && (f.studentId == studentUserId || docUid == studentUserId)) return true;
          if (studentPhone.isNotEmpty && docPhone.isNotEmpty && (studentPhone == docPhone || studentPhone.endsWith(docPhone) || docPhone.endsWith(studentPhone))) return true;
          if (authEmail.isNotEmpty && docEmail.isNotEmpty && authEmail == docEmail) return true;
          if (studentEmail.isNotEmpty && docEmail.isNotEmpty && studentEmail == docEmail) return true;
          return false;
        }).map((pair) => pair.$1).toList()
          ..sort((a, b) => (b.createdAt ?? DateTime(2000)).compareTo(a.createdAt ?? DateTime(2000)));

        if (userFeedback.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer.withValues(alpha: 0.4),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.rate_review_outlined, size: 48, color: theme.colorScheme.primary),
                  ),
                  const SizedBox(height: 16),
                  Text('No Previous Feedback', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(
                    'You have not submitted any feedback yet. Your suggestions and official management replies will appear here in real-time.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: theme.colorScheme.onSurfaceVariant, height: 1.3),
                  ),
                  const SizedBox(height: 20),
                  FilledButton.tonalIcon(
                    onPressed: () => _tabController.animateTo(0),
                    icon: const Icon(Icons.add_comment_rounded),
                    label: const Text('Give Feedback Now'),
                  ),
                ],
              ),
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            setState(() {});
            await Future.delayed(const Duration(milliseconds: 400));
          },
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: userFeedback.length,
            separatorBuilder: (_, _) => const SizedBox(height: 14),
            itemBuilder: (context, index) {
              final item = userFeedback[index];
              final hasReply = item.adminReply != null && item.adminReply!.trim().isNotEmpty;

              return Card(
                elevation: 1.5,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: hasReply
                        ? Colors.green.shade300
                        : theme.colorScheme.outlineVariant.withValues(alpha: 0.6),
                    width: hasReply ? 1.5 : 1,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header Row: Category & Status Badge
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (item.feedbackType == 'issue') ...[
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  margin: const EdgeInsets.only(right: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.red.shade100,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text('ISSUE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.red.shade900)),
                                ),
                              ] else if (item.feedbackType == 'suggestion') ...[
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  margin: const EdgeInsets.only(right: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.amber.shade100,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text('SUGGESTION', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.amber.shade900)),
                                ),
                              ],
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.secondaryContainer.withValues(alpha: 0.7),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  item.category ?? 'General Feedback',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: theme.colorScheme.onSecondaryContainer,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: hasReply
                                  ? Colors.green.shade50
                                  : Colors.orange.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: hasReply ? Colors.green.shade400 : Colors.orange.shade400,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  hasReply ? Icons.check_circle_rounded : Icons.schedule_rounded,
                                  size: 13,
                                  color: hasReply ? Colors.green.shade800 : Colors.orange.shade800,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  hasReply ? 'Resolved / Replied' : 'Under Review',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: hasReply ? Colors.green.shade900 : Colors.orange.shade900,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Rating & Timestamp
                      Row(
                        children: [
                          if (item.rating != null) ...[
                            ...List.generate(5, (sIndex) {
                              final isFilled = sIndex < (item.rating ?? 0);
                              return Icon(
                                isFilled ? Icons.star_rounded : Icons.star_outline_rounded,
                                size: 18,
                                color: isFilled ? Colors.amber.shade700 : Colors.grey.shade400,
                              );
                            }),
                            const SizedBox(width: 8),
                          ],
                          Text(
                            item.createdAt != null ? dateFormat.format(item.createdAt!) : 'Recently',
                            style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Student Message
                      Text(
                        item.message,
                        style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
                      ),

                      // Admin Reply Box (if replied)
                      if (hasReply) ...[
                        const SizedBox(height: 14),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.green.shade200),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Wrap(
                                alignment: WrapAlignment.spaceBetween,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                spacing: 8,
                                runSpacing: 4,
                                children: [
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.mark_email_read_rounded, size: 16, color: Colors.green.shade800),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Library Management Response',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                          color: Colors.green.shade900,
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (item.repliedAt != null)
                                    Text(
                                      '• ${DateFormat('dd MMM • hh:mm a').format(item.repliedAt!)}',
                                      style: TextStyle(fontSize: 10.5, color: Colors.green.shade800, fontWeight: FontWeight.w500),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                item.adminReply!,
                                style: TextStyle(
                                  fontSize: 13,
                                  height: 1.35,
                                  color: Colors.green.shade900,
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
            },
          ),
        );
      },
    );
  }
}
