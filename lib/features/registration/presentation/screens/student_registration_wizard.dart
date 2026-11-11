import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:study_library/core/router/app_router.dart';
import 'package:study_library/models/library_model.dart';
import 'package:study_library/models/student_model.dart';
import 'package:study_library/models/waiting_list_model.dart';
import 'package:study_library/features/auth/presentation/providers/auth_provider.dart';
import 'package:study_library/features/students/presentation/providers/student_providers.dart';
import 'package:study_library/features/student_app/presentation/screens/student_home_screen.dart';
import 'package:study_library/features/seats/presentation/providers/seat_providers.dart';
import 'package:study_library/features/waiting_list/data/repositories/waiting_list_repository.dart';
import '../providers/registration_provider.dart';
import 'package:study_library/services/form_config_service.dart';
import 'package:study_library/core/utils/error_formatter.dart';
import 'id_scan_screen.dart';
import 'registration_form_screen.dart';
import 'photo_upload_screen.dart';
import 'plan_selection_screen.dart';
import 'seat_selection_screen.dart';
import 'review_submit_screen.dart';

class StudentRegistrationWizard extends ConsumerStatefulWidget {
  const StudentRegistrationWizard({super.key});

  @override
  ConsumerState<StudentRegistrationWizard> createState() =>
      _StudentRegistrationWizardState();
}

class _StudentRegistrationWizardState
    extends ConsumerState<StudentRegistrationWizard> {
  bool _bypassFullCapacity = false;
  bool _isSubmittingWaitlist = false;

  // Waitlist form fields
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  String? _preferredSectionId;
  String _genderPref = 'none';
  bool _formPrepopulated = false;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _prepopulateFields() {
    if (_formPrepopulated) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      if (user.displayName != null && user.displayName!.isNotEmpty) {
        _nameController.text = user.displayName!;
      }
      if (user.phoneNumber != null && user.phoneNumber!.isNotEmpty) {
        _phoneController.text = user.phoneNumber!.replaceAll(RegExp(r'\D'), '');
      }
    }
    _formPrepopulated = true;
  }

  Future<void> _joinWaitingList(int currentQueueLength) async {
    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();

    if (name.isEmpty || phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter your full name and mobile phone number'),
          backgroundColor: Colors.amber,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final libraryId = ref.read(currentLibraryIdProvider);
    if (libraryId == null || libraryId.isEmpty) return;

    setState(() => _isSubmittingWaitlist = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      final entry = WaitingListEntry(
        id: '',
        libraryId: libraryId,
        studentId: user?.uid ?? '',
        studentName: name,
        studentPhone: phone,
        preferredSectionId: _preferredSectionId,
        genderPreference: _genderPref,
        position: currentQueueLength + 1,
        createdAt: DateTime.now(),
      );

      await ref.read(waitingListRepositoryProvider).addToWaitingList(
            libraryId,
            entry,
          );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Congratulations $name! You have been added to the Priority Waiting List at position #${currentQueueLength + 1}.',
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        AppErrorFormatter.showErrorSnackBar(context, e, actionContext: 'request');
      }
    } finally {
      if (mounted) setState(() => _isSubmittingWaitlist = false);
    }
  }

  Future<void> _openWhatsApp(String phone, String text) async {
    final clean = phone.replaceAll(RegExp(r'\D'), '');
    final withCode = clean.startsWith('91') || clean.length > 10 ? clean : '91$clean';
    final uri = Uri.parse('https://wa.me/$withCode?text=${Uri.encodeComponent(text)}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _callPhone(String phone) async {
    final clean = phone.replaceAll(RegExp(r'\D'), '');
    if (clean.isEmpty) return;
    final uri = Uri.parse('tel:$clean');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  @override
  Widget build(BuildContext context) {
    _prepopulateFields();

    final occupancyAsync = ref.watch(occupancyProvider);
    final libraryAsync = ref.watch(currentLibraryProvider);
    final waitingListAsync = ref.watch(waitingListStreamProvider);
    final queueInfoAsync = ref.watch(studentWaitingQueueProvider);
    final studentAsync = ref.watch(currentStudentProvider);
    final pendingRequestAsync = ref.watch(pendingRequestProvider);

    final library = libraryAsync.value;
    final libraryName = library?.name.isNotEmpty == true ? library!.name : 'Study Library';
    final libraryPhone = library?.phone ?? '';

    // 1. Check if user is ALREADY an enrolled student in this library
    final currentStudent = studentAsync.value;
    if (currentStudent != null && !_bypassFullCapacity) {
      return _buildAlreadyEnrolledView(currentStudent, libraryName);
    }

    // 2. Check if user ALREADY has an admission request pending approval
    final pendingRequest = pendingRequestAsync.value;
    if (pendingRequest != null && !_bypassFullCapacity) {
      return _buildPendingApplicationView(pendingRequest, libraryName, libraryPhone);
    }

    // 3. Check if user is ALREADY on the priority waiting list
    final existingQueueInfo = queueInfoAsync.value;
    if (existingQueueInfo != null && !_bypassFullCapacity) {
      return _buildExistingTicketView(existingQueueInfo, libraryName, libraryPhone);
    }

    // Capacity check: when library has desks and all available seats == 0
    final occupancy = occupancyAsync.value;
    final totalSeats = occupancy?['total'] ?? 0;
    final availableSeats = occupancy?['available'] ?? 0;
    final isFull = totalSeats > 0 && availableSeats == 0;

    if (isFull && !_bypassFullCapacity) {
      final mode = library?.waitingListMode ?? WaitingListMode.waitingList;
      switch (mode) {
        case WaitingListMode.waitingList:
          return _buildWaitingListJoinView(
            waitingListAsync.value ?? [],
            libraryName,
            libraryPhone,
          );
        case WaitingListMode.noSeatsMessage:
          return _buildNoSeatsMessageView(libraryName, libraryPhone);
        case WaitingListMode.contactAdmin:
          return _buildContactAdminView(libraryName, libraryPhone);
      }
    }

    final formConfigAsync = ref.watch(formConfigStreamProvider);
    final isGovIdVisible = FormConfigService.isFieldVisible(formConfigAsync.value ?? [], 'govId');

    // Standard registration wizard (adapts dynamically if govId is disabled)
    final step = ref.watch(registrationStepProvider);

    switch (step) {
      case 1:
        return isGovIdVisible ? const IdScanScreen() : const RegistrationFormScreen();
      case 2:
        return const RegistrationFormScreen();
      case 3:
        return const PhotoUploadScreen();
      case 4:
        return const PlanSelectionScreen();
      case 5:
        return const SeatSelectionScreen();
      case 6:
        return const ReviewSubmitScreen();
      default:
        return isGovIdVisible ? const IdScanScreen() : const RegistrationFormScreen();
    }
  }

  /// ── 0a. ALREADY ENROLLED STUDENT VIEW ──
  Widget _buildAlreadyEnrolledView(
    StudentModel student,
    String libraryName,
  ) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admission Status'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(Routes.studentHome),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.green.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.check_circle_rounded,
                    size: 48,
                    color: Colors.green.shade700,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Already Enrolled!',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Hello ${student.name}! You are already registered as an enrolled student in $libraryName.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () {
                      ref.read(userRoleProvider.notifier).setRole(AppUserRole.student);
                      context.go(Routes.studentHome);
                    },
                    icon: const Icon(Icons.badge_rounded),
                    label: const Text('Open My Student Pass & Dashboard'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// ── 0b. EXISTING PENDING APPLICATION VIEW (GHOST LOOP PREVENTION) ──
  Widget _buildPendingApplicationView(
    Map<String, dynamic> request,
    String libraryName,
    String libraryPhone,
  ) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final studentName = request['studentName']?.toString() ?? 'Student';
    final planName = request['planName']?.toString() ?? 'Selected Plan';
    final requestedSeatLabel = request['requestedSeatLabel']?.toString() ?? 'Auto-Assign';
    final requestId = request['id']?.toString() ?? '';
    final createdAt = request['createdAt'];
    String submittedDateStr = 'Recent';
    if (createdAt is Timestamp) {
      submittedDateStr = DateFormat('dd MMM yyyy, hh:mm a').format(createdAt.toDate());
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admission Status'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go(Routes.login);
            }
          },
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.amber.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.pending_actions_rounded,
                    size: 44,
                    color: Colors.amber.shade800,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Application Under Review',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.amber.shade300),
                  ),
                  child: Text(
                    '⏳ Pending Admin Approval',
                    style: TextStyle(
                      color: Colors.amber.shade900,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Card(
                  elevation: 0,
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: isDark ? Colors.white10 : Colors.black12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.person_outline_rounded, size: 20, color: Colors.brown),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                studentName,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 24),
                        _buildDetailRow('Library', libraryName),
                        const SizedBox(height: 8),
                        _buildDetailRow(
                          'Requested Desk',
                          requestedSeatLabel.toLowerCase().contains('auto')
                              ? 'Auto-Assign'
                              : 'Desk #$requestedSeatLabel',
                        ),
                        const SizedBox(height: 8),
                        _buildDetailRow('Applied Plan', planName),
                        const SizedBox(height: 8),
                        _buildDetailRow('Submitted On', submittedDateStr),
                        if (requestId.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          _buildDetailRow(
                            'Application Ref',
                            '#${requestId.length >= 8 ? requestId.substring(0, 8).toUpperCase() : requestId.toUpperCase()}',
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Hello $studentName! Your admission application has been received and is currently under review by library administration.\n\nYour digital student pass and seat will unlock automatically once approved.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () {
                      ref.read(userRoleProvider.notifier).setRole(AppUserRole.student);
                      context.go(Routes.studentHome);
                    },
                    icon: const Icon(Icons.dashboard_rounded),
                    label: const Text('Open Student Dashboard'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                if (libraryPhone.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _callPhone(libraryPhone),
                          icon: const Icon(Icons.call_rounded, size: 18),
                          label: const Text('Call Desk'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _openWhatsApp(
                            libraryPhone,
                            'Hello $libraryName, I have submitted an admission application (Ref #${requestId.length >= 8 ? requestId.substring(0, 8).toUpperCase() : requestId}). Could you please check my application status?',
                          ),
                          icon: const Icon(Icons.chat_rounded, size: 18, color: Colors.green),
                          label: const Text('WhatsApp'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13)),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
        ),
      ],
    );
  }

  /// ── 1. ACTIVE WAITING LIST TICKET VIEW ──
  Widget _buildExistingTicketView(
    StudentQueueInfo info,
    String libraryName,
    String libraryPhone,
  ) {
    final theme = Theme.of(context);
    final isSeatReady = info.isSeatReady;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admission Status'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(Routes.studentHome),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: ConstrainedBox(
            constraints: const BoxOptionConstraints(maxWidth: 500),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Top Header Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSeatReady
                        ? const Color(0xFFDCFCE7)
                        : const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSeatReady
                          ? const Color(0xFF22C55E)
                          : const Color(0xFFF59E0B),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isSeatReady
                            ? Icons.check_circle_rounded
                            : Icons.hourglass_top_rounded,
                        size: 18,
                        color: isSeatReady
                            ? const Color(0xFF15803D)
                            : const Color(0xFFB45309),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        isSeatReady
                            ? 'SEAT RESERVED FOR YOU'
                            : 'PRIORITY WAITING LIST ACTIVE',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                          color: isSeatReady
                              ? const Color(0xFF15803D)
                              : const Color(0xFFB45309),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Large Position Circle
                Container(
                  width: 110,
                  height: 110,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isSeatReady
                          ? [const Color(0xFF10B981), const Color(0xFF059669)]
                          : [const Color(0xFFF59E0B), const Color(0xFFD97706)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: (isSeatReady
                                ? const Color(0xFF10B981)
                                : const Color(0xFFF59E0B))
                            .withValues(alpha: 0.35),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '#${info.position}',
                          style: const TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          'IN LINE',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                            color: Colors.white.withValues(alpha: 0.85),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                Text(
                  isSeatReady
                      ? 'Seat Ready for Admission!'
                      : 'You Are in the Priority Queue',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  isSeatReady
                      ? 'A study desk (${info.suggestedSeatLabel}) has become vacant and has been held for you at $libraryName! Please complete your admission.'
                      : 'We are monitoring desk availability in real-time. You are candidate #${info.position} of ${info.totalInQueue} waiting.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 24),

                // Ticket Detail Card
                Card(
                  elevation: 0,
                  color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.2)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        _buildTicketRow(
                          'Applicant',
                          info.entry.studentName,
                          Icons.person_rounded,
                        ),
                        const Divider(height: 20),
                        _buildTicketRow(
                          'Mobile',
                          info.entry.studentPhone,
                          Icons.phone_rounded,
                        ),
                        const Divider(height: 20),
                        _buildTicketRow(
                          'Queued Since',
                          info.entry.createdAt != null
                              ? DateFormat('dd MMM yyyy, hh:mm a')
                                  .format(info.entry.createdAt!)
                              : 'Recent',
                          Icons.access_time_rounded,
                        ),
                        if (isSeatReady) ...[
                          const Divider(height: 20),
                          _buildTicketRow(
                            'Held Seat',
                            info.suggestedSeatLabel ?? 'Allocated Desk',
                            Icons.chair_alt_rounded,
                            isHighlight: true,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Action Buttons
                Row(
                  children: [
                    if (libraryPhone.isNotEmpty) ...[
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _openWhatsApp(
                            libraryPhone,
                            'Hello $libraryName, I am on the waiting list (Position #${info.position}) for admission. Name: ${info.entry.studentName}.',
                          ),
                          icon: const Icon(Icons.chat_bubble_rounded,
                              color: Color(0xFF25D366)),
                          label: const Text('WhatsApp Admin'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => context.go(Routes.studentHome),
                        icon: const Icon(Icons.home_rounded),
                        label: const Text('Return Home'),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => setState(() => _bypassFullCapacity = true),
                  child: const Text('Have an admin code? Proceed with form anyway'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// ── 2. FULL CAPACITY -> JOIN WAITING LIST VIEW ──
  Widget _buildWaitingListJoinView(
    List<WaitingListEntry> queue,
    String libraryName,
    String libraryPhone,
  ) {
    final theme = Theme.of(context);
    final sections = ref.watch(sectionsProvider).value ?? [];
    final queueLength = queue.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Library at Full Capacity'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(Routes.studentHome),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: ConstrainedBox(
            constraints: const BoxOptionConstraints(maxWidth: 520),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top Full Capacity Banner
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFF59E0B)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: const BoxDecoration(
                          color: Color(0xFFFDE68A),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.group_off_rounded,
                            color: Color(0xFF92400E), size: 24),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '100% Capacity Reached',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: Color(0xFF78350F),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'All study desks at $libraryName are currently occupied.',
                              style: const TextStyle(
                                fontSize: 13,
                                color: Color(0xFF92400E),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Queue Position Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: theme.colorScheme.primary.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Column(
                        children: [
                          Text(
                            '$queueLength',
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w900,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                          const Text(
                            'CURRENTLY WAITING',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.8,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                      Container(width: 1, height: 36, color: Colors.grey.shade300),
                      Column(
                        children: [
                          Text(
                            '#${queueLength + 1}',
                            style: const TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF059669),
                            ),
                          ),
                          const Text(
                            'YOUR QUEUE POSITION',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.8,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                Text(
                  'Join Priority Waiting List',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Submit your details below. The instant a seat opens up, you will be assigned priority and notified via WhatsApp.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),

                // Form
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Full Student Name *',
                    prefixIcon: Icon(Icons.person_rounded),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'WhatsApp Phone Number *',
                    prefixIcon: Icon(Icons.phone_rounded),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String?>(
                  initialValue: _preferredSectionId,
                  decoration: const InputDecoration(
                    labelText: 'Preferred Section (Optional)',
                    prefixIcon: Icon(Icons.meeting_room_rounded),
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('Any Available Section'),
                    ),
                    ...sections.map(
                      (sec) => DropdownMenuItem(
                        value: sec.id,
                        child: Text(sec.name),
                      ),
                    ),
                  ],
                  onChanged: (val) => setState(() => _preferredSectionId = val),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _genderPref,
                  decoration: const InputDecoration(
                    labelText: 'Gender Preference',
                    prefixIcon: Icon(Icons.wc_rounded),
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'none', child: Text('No Preference')),
                    DropdownMenuItem(value: 'male', child: Text('Male')),
                    DropdownMenuItem(value: 'female', child: Text('Female')),
                  ],
                  onChanged: (val) {
                    if (val != null) setState(() => _genderPref = val);
                  },
                ),
                const SizedBox(height: 24),

                FilledButton.icon(
                  onPressed: _isSubmittingWaitlist
                      ? null
                      : () => _joinWaitingList(queueLength),
                  icon: _isSubmittingWaitlist
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.queue_play_next_rounded),
                  label: Text(
                    _isSubmittingWaitlist
                        ? 'Enrolling in Queue...'
                        : 'Join Priority Waiting List (#${queueLength + 1} in line)',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
                const SizedBox(height: 16),

                Center(
                  child: TextButton(
                    onPressed: () => setState(() => _bypassFullCapacity = true),
                    child: const Text(
                      'Have an admin admission code? Proceed with form anyway',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// ── 3. NO SEATS MESSAGE VIEW ──
  Widget _buildNoSeatsMessageView(String libraryName, String libraryPhone) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admissions Notice'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(Routes.studentHome),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: ConstrainedBox(
            constraints: const BoxOptionConstraints(maxWidth: 480),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.block_rounded, size: 54, color: Colors.red.shade700),
                ),
                const SizedBox(height: 20),
                Text(
                  'Library Full — Admissions Paused',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                Text(
                  'All seats at $libraryName are currently occupied. New student admissions are temporarily paused until desks become vacant. Please check back later.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 28),
                FilledButton.icon(
                  onPressed: () => context.go(Routes.studentHome),
                  icon: const Icon(Icons.home_rounded),
                  label: const Text('Return to Home'),
                ),
                const SizedBox(height: 14),
                TextButton(
                  onPressed: () => setState(() => _bypassFullCapacity = true),
                  child: const Text('Have an admin admission code? Proceed anyway'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// ── 4. CONTACT ADMIN VIEW ──
  Widget _buildContactAdminView(String libraryName, String libraryPhone) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admissions Contact'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(Routes.studentHome),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: ConstrainedBox(
            constraints: const BoxOptionConstraints(maxWidth: 480),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.support_agent_rounded,
                      size: 54, color: Colors.blue.shade700),
                ),
                const SizedBox(height: 20),
                Text(
                  'Admissions by Direct Enquiry',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                Text(
                  'All regular desks at $libraryName are currently occupied. For upcoming vacancy schedules, custom batch timings, or special requests, please contact administration directly.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 28),
                if (libraryPhone.isNotEmpty) ...[
                  FilledButton.icon(
                    onPressed: () => _openWhatsApp(
                      libraryPhone,
                      'Hello $libraryName, I would like to inquire about desk availability and upcoming admissions.',
                    ),
                    icon: const Icon(Icons.chat_bubble_rounded,
                        color: Color(0xFF25D366)),
                    label: const Text('Contact via WhatsApp'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 14),
                    ),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: () => _callPhone(libraryPhone),
                    icon: const Icon(Icons.phone_rounded),
                    label: Text('Call Admin ($libraryPhone)'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 14),
                    ),
                  ),
                ] else ...[
                  FilledButton.icon(
                    onPressed: () => context.go(Routes.studentHome),
                    icon: const Icon(Icons.home_rounded),
                    label: const Text('Return to Home'),
                  ),
                ],
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => setState(() => _bypassFullCapacity = true),
                  child: const Text('Have an admin admission code? Proceed anyway'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTicketRow(
    String label,
    String value,
    IconData icon, {
    bool isHighlight = false,
  }) {
    return Row(
      children: [
        Icon(icon, size: 18, color: isHighlight ? Colors.amber.shade900 : Colors.grey),
        const SizedBox(width: 10),
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey.shade600,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: isHighlight ? FontWeight.bold : FontWeight.w600,
            color: isHighlight ? Colors.amber.shade900 : null,
          ),
        ),
      ],
    );
  }
}

class BoxOptionConstraints extends BoxConstraints {
  const BoxOptionConstraints({super.maxWidth = double.infinity});
}
