import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:study_library/core/providers/library_provider.dart';
import 'package:go_router/go_router.dart';
import 'package:study_library/core/router/app_router.dart';
import 'package:study_library/core/utils/seat_helper.dart';
import 'package:study_library/services/badge_service.dart';
import 'package:study_library/services/app_notification_service.dart';
import 'package:study_library/services/student_provisioning_service.dart';
import 'package:study_library/features/requests/presentation/providers/request_providers.dart';
import 'package:study_library/core/utils/error_formatter.dart';

/// Data representation of a student request from raw Firestore data.
class StudentRequestItem {
  final String id;
  final String type;
  final String message;
  final String studentName;
  final String studentId;
  final String? studentPhone;
  final String? studentEmail;
  final String? membershipNumber;
  final String? currentSeatLabel;
  final String? currentSectionName;
  final String? targetSeatLabel;
  final String? targetSectionName;
  final String? reason;
  final String status;
  final DateTime? createdAt;
  final String? rejectionReason;
  final String? requestedPlanName;
  final String? requestedPlanId;
  final double? amount;
  final String? paymentMethod;
  final String? paymentModeLabel;
  final String? referenceNumber;
  final String? studentUserId;
  final DateTime? cycleStartDate;
  final DateTime? cycleEndDate;

  bool get isPending {
    final s = status.toLowerCase().trim();
    return s == 'pending' ||
        s == 'desk_payment_pending' ||
        s == 'payment_pending' ||
        s == 'submitted' ||
        s == 'open' ||
        s.contains('pending');
  }

  const StudentRequestItem({
    required this.id,
    required this.type,
    required this.message,
    required this.studentName,
    required this.studentId,
    this.studentPhone,
    this.studentEmail,
    this.membershipNumber,
    this.currentSeatLabel,
    this.currentSectionName,
    this.targetSeatLabel,
    this.targetSectionName,
    this.reason,
    required this.status,
    this.createdAt,
    this.rejectionReason,
    this.requestedPlanName,
    this.requestedPlanId,
    this.amount,
    this.paymentMethod,
    this.paymentModeLabel,
    this.referenceNumber,
    this.studentUserId,
    this.cycleStartDate,
    this.cycleEndDate,
  });

  factory StudentRequestItem.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};
    final studentData = (data['studentData'] as Map<String, dynamic>?) ?? {};

    // Support both direct fields and nested studentData fallback
    String studentName = 'Student';
    if (data['studentName'] is String && (data['studentName'] as String).trim().isNotEmpty) {
      studentName = (data['studentName'] as String).trim();
    } else if (studentData['name'] != null && studentData['name'].toString().trim().isNotEmpty) {
      studentName = studentData['name'].toString().trim();
    }

    final rawCurrentSeat = (data['currentSeatLabel'] ?? data['currentSeatId'] ?? studentData['currentSeatId']) as String?;
    final rawTargetSeat = (data['targetSeatLabel'] ?? data['targetSeatId'] ?? data['seatId'] ?? studentData['targetSeatId']) as String?;

    return StudentRequestItem(
      id: doc.id,
      type: data['type'] as String? ?? 'General Request',
      message: (data['message'] ?? data['reason'] ?? '') as String? ?? '',
      studentName: studentName,
      studentId: data['studentId'] as String? ?? '',
      studentPhone: (data['studentPhone'] ?? studentData['phone']) as String?,
      studentEmail: (data['studentEmail'] ?? studentData['email']) as String?,
      membershipNumber: (data['membershipNumber'] ?? studentData['membershipNumber']) as String?,
      currentSeatLabel: rawCurrentSeat != null ? SeatHelper.formatSeatLabel(rawLabel: rawCurrentSeat) : null,
      currentSectionName: (data['currentSectionName'] ?? studentData['currentSectionName']) as String?,
      targetSeatLabel: rawTargetSeat != null ? SeatHelper.formatSeatLabel(rawLabel: rawTargetSeat) : null,
      targetSectionName: (data['targetSectionName'] ?? studentData['targetSectionName']) as String?,
      reason: (data['reason'] ?? data['message']) as String?,
      status: (data['status'] as String? ?? 'pending').trim().toLowerCase(),
      createdAt: _parseDate(data['createdAt']),
      rejectionReason: (data['rejectionReason'] ?? data['rejectReason']) as String?,
      requestedPlanName: (data['requestedPlanName'] ?? studentData['requestedPlanName'] ?? data['planName']) as String?,
      requestedPlanId: (data['requestedPlanId'] ?? data['planId']) as String?,
      amount: (data['amount'] as num?)?.toDouble() ?? (studentData['amount'] as num?)?.toDouble(),
      paymentMethod: (data['paymentMethod'] ?? data['method']) as String?,
      paymentModeLabel: data['paymentModeLabel'] as String?,
      referenceNumber: (data['referenceNumber'] ?? data['reference']) as String?,
      studentUserId: (data['studentUserId'] ?? data['userId'] ?? studentData['userId']) as String?,
      cycleStartDate: _parseDate(data['cycleStartDate']),
      cycleEndDate: _parseDate(data['cycleEndDate']),
    );
  }

  static DateTime? _parseDate(dynamic date) {
    if (date == null) return null;
    if (date is Timestamp) return date.toDate();
    if (date is DateTime) return date;
    if (date is int) return DateTime.fromMillisecondsSinceEpoch(date);
    if (date is String) return DateTime.tryParse(date);
    return null;
  }
}

/// Stream provider for student requests, sorted in Dart (newest first).
final requestsStreamProvider = StreamProvider.autoDispose<List<StudentRequestItem>>((ref) {
  final libraryId = ref.watch(currentLibraryIdProvider);
  if (libraryId == null || libraryId.isEmpty) {
    return Stream.value([]);
  }

  return FirebaseFirestore.instance
      .collection('libraries')
      .doc(libraryId)
      .collection('requests')
      .snapshots()
      .map((snapshot) {
    final list = snapshot.docs
        .map((doc) => StudentRequestItem.fromFirestore(doc))
        .toList();

    // Sort in Dart by createdAt descending (no composite index needed)
    list.sort((a, b) {
      final aDate = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bDate = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bDate.compareTo(aDate);
    });

    return list;
  });
});

/// Screen to view and manage student requests with module-based categorization.
class RequestListScreen extends ConsumerStatefulWidget {
  final String? initialCategory;
  const RequestListScreen({super.key, this.initialCategory});

  @override
  ConsumerState<RequestListScreen> createState() => _RequestListScreenState();
}

class _RequestListScreenState extends ConsumerState<RequestListScreen> {
  late String _selectedCategory;

  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.initialCategory ?? 'all';
  }

  @override
  void didUpdateWidget(covariant RequestListScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialCategory != null && widget.initialCategory != oldWidget.initialCategory) {
      _selectedCategory = widget.initialCategory!;
    }
  }

  String _categoryLabel(String cat) {
    switch (cat.toLowerCase()) {
      case 'registration':
      case 'admissions':
        return 'Admissions';
      case 'seat_change':
      case 'seats':
        return 'Seat Shifts';
      case 'renewal':
      case 'renewals':
        return 'Plan Renewals';
      case 'profile_update':
      case 'profile':
        return 'Profile Edits';
      default:
        return 'All Types';
    }
  }

  List<StudentRequestItem> _filterByCategory(List<StudentRequestItem> list) {
    if (_selectedCategory == 'all') return list;
    return list.where((item) {
      final t = item.type.toLowerCase().trim();
      switch (_selectedCategory) {
        case 'registration':
        case 'admissions':
          return t == 'registration' || t == 'newregistration';
        case 'seat_change':
        case 'seats':
          return t == 'seat_change' || t == 'seatchange';
        case 'renewal':
        case 'renewals':
          return t == 'renewal' || t == 'plan_renewal';
        case 'profile_update':
        case 'profile':
          return t == 'profile_update';
        default:
          return true;
      }
    }).toList();
  }

  Widget _buildCategoryChip({
    required String label,
    required int count,
    required bool isSelected,
    required VoidCallback onTap,
    IconData? icon,
    Color? color,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final activeColor = color ?? theme.colorScheme.primary;

    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected
              ? activeColor.withValues(alpha: isDark ? 0.3 : 0.15)
              : (isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFF1F5F9)),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? activeColor : (isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: isSelected ? activeColor : theme.colorScheme.onSurfaceVariant),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                color: isSelected ? activeColor : theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
              decoration: BoxDecoration(
                color: isSelected ? activeColor : (isDark ? Colors.white12 : const Color(0xFFE2E8F0)),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? Colors.white : theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCrossModuleChip({
    required BuildContext context,
    required String label,
    required IconData icon,
    required int count,
    required Color color,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: count > 0 ? color.withValues(alpha: 0.5) : (isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: theme.colorScheme.onSurface),
            ),
            if (count > 0) ...[
              const SizedBox(width: 5),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(8)),
                child: Text('$count', style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            ],
            const SizedBox(width: 4),
            Icon(Icons.arrow_outward_rounded, size: 11, color: theme.colorScheme.outline),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryChips(BuildContext context, List<StudentRequestItem> requests, RequestModuleCounts counts) {
    final theme = Theme.of(context);
    final total = requests.length;
    final admissions = requests.where((r) => r.type.toLowerCase() == 'registration' || r.type.toLowerCase() == 'newregistration').length;
    final seatChanges = requests.where((r) => r.type.toLowerCase() == 'seat_change' || r.type.toLowerCase() == 'seatchange').length;
    final renewals = requests.where((r) => r.type.toLowerCase() == 'renewal' || r.type.toLowerCase() == 'plan_renewal').length;
    final profile = requests.where((r) => r.type.toLowerCase() == 'profile_update').length;

    return Container(
      width: double.infinity,
      color: theme.colorScheme.surface,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: [
            _buildCategoryChip(
              label: 'All Modules',
              count: total,
              isSelected: _selectedCategory == 'all',
              onTap: () => setState(() => _selectedCategory = 'all'),
            ),
            const SizedBox(width: 8),
            _buildCategoryChip(
              label: 'Admissions',
              icon: Icons.school_rounded,
              count: admissions,
              color: const Color(0xFF2563EB),
              isSelected: _selectedCategory == 'registration' || _selectedCategory == 'admissions',
              onTap: () => setState(() => _selectedCategory = 'registration'),
            ),
            const SizedBox(width: 8),
            _buildCategoryChip(
              label: 'Seat Shifts',
              icon: Icons.event_seat_rounded,
              count: seatChanges,
              color: const Color(0xFFD97706),
              isSelected: _selectedCategory == 'seat_change' || _selectedCategory == 'seats',
              onTap: () => setState(() => _selectedCategory = 'seat_change'),
            ),
            const SizedBox(width: 8),
            _buildCategoryChip(
              label: 'Plan Renewals',
              icon: Icons.autorenew_rounded,
              count: renewals,
              color: const Color(0xFF059669),
              isSelected: _selectedCategory == 'renewal' || _selectedCategory == 'renewals',
              onTap: () => setState(() => _selectedCategory = 'renewal'),
            ),
            if (profile > 0 || _selectedCategory == 'profile_update') ...[
              const SizedBox(width: 8),
              _buildCategoryChip(
                label: 'Profile Edits',
                icon: Icons.person_outline_rounded,
                count: profile,
                color: const Color(0xFF7C3AED),
                isSelected: _selectedCategory == 'profile_update',
                onTap: () => setState(() => _selectedCategory = 'profile_update'),
              ),
            ],
            // Cross-module quick jump shortcuts to Feedback & Waiting List
            const SizedBox(width: 12),
            Container(width: 1, height: 20, color: theme.dividerColor.withValues(alpha: 0.4)),
            const SizedBox(width: 12),
            _buildCrossModuleChip(
              context: context,
              label: 'Feedback',
              icon: Icons.feedback_outlined,
              count: counts.openFeedbackCount,
              color: const Color(0xFF7C3AED),
              onTap: () => context.push(Routes.adminFeedback),
            ),
            const SizedBox(width: 8),
            _buildCrossModuleChip(
              context: context,
              label: 'Waiting List',
              icon: Icons.hourglass_top_rounded,
              count: counts.waitingListCount,
              color: const Color(0xFF6366F1),
              onTap: () => context.push(Routes.adminWaitingList),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModuleBreakdownBanner(BuildContext context, RequestModuleCounts counts) {
    if (counts.totalPending == 0) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFF2563EB).withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.hub_rounded, size: 16, color: Color(0xFF2563EB)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${counts.totalPending} Requests Across Modules',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    Text(
                      'Tap a module pill below to focus on specific request types',
                      style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              if (counts.admissionsPending > 0)
                _buildBreakdownPill(
                  label: '${counts.admissionsPending} Admissions',
                  icon: Icons.school_rounded,
                  color: const Color(0xFF2563EB),
                  onTap: () => setState(() => _selectedCategory = 'registration'),
                ),
              if (counts.seatChangesPending > 0)
                _buildBreakdownPill(
                  label: '${counts.seatChangesPending} Seat Shifts',
                  icon: Icons.event_seat_rounded,
                  color: const Color(0xFFD97706),
                  onTap: () => setState(() => _selectedCategory = 'seat_change'),
                ),
              if (counts.renewalsPending > 0)
                _buildBreakdownPill(
                  label: '${counts.renewalsPending} Plan Renewals',
                  icon: Icons.autorenew_rounded,
                  color: const Color(0xFF059669),
                  onTap: () => setState(() => _selectedCategory = 'renewal'),
                ),
              if (counts.profileUpdatesPending > 0)
                _buildBreakdownPill(
                  label: '${counts.profileUpdatesPending} Profile Edits',
                  icon: Icons.person_outline_rounded,
                  color: const Color(0xFF7C3AED),
                  onTap: () => setState(() => _selectedCategory = 'profile_update'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBreakdownPill({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 5),
            Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Clear badge when admin opens requests screen (they're seeing the requests)
    BadgeService.clearBadge();

    final libraryId = ref.watch(currentLibraryIdProvider);
    final requestsAsync = ref.watch(requestsStreamProvider);
    final moduleCounts = ref.watch(requestModuleCountsProvider);

    Widget buildBackButton() {
      return IconButton(
        icon: const Icon(Icons.arrow_back),
        tooltip: 'Back',
        onPressed: () {
          if (context.canPop()) {
            context.pop();
          } else {
            context.go(Routes.adminHome);
          }
        },
      );
    }

    return requestsAsync.when(
      loading: () => Scaffold(
        appBar: AppBar(
          leading: buildBackButton(),
          title: const Text('Requests Hub'),
        ),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => Scaffold(
        appBar: AppBar(
          leading: buildBackButton(),
          title: const Text('Requests Hub'),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.error_outline_rounded,
                  size: 56,
                  color: Theme.of(context).colorScheme.error,
                ),
                const SizedBox(height: 16),
                Text(
                  'Failed to load requests',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  error.toString(),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: () => ref.refresh(requestsStreamProvider),
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      ),
      data: (requests) {
        final pending = requests.where((r) => r.isPending).toList();
        final approved = requests.where((r) => r.status == 'approved').toList();
        final rejected = requests.where((r) => r.status == 'rejected' || r.status == 'superseded' || r.status == 'cancelled').toList();

        return PopScope(
          canPop: context.canPop(),
          onPopInvokedWithResult: (didPop, result) {
            if (!didPop) {
              context.go(Routes.adminHome);
            }
          },
          child: DefaultTabController(
            length: 4,
            child: Scaffold(
              appBar: AppBar(
                leading: buildBackButton(),
                title: const Text('Requests Hub'),
                bottom: TabBar(
                  isScrollable: false,
                  tabs: [
                    Tab(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('Pending'),
                          if (pending.isNotEmpty) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.error,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '${pending.length}',
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.onError,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const Tab(text: 'Approved'),
                    const Tab(text: 'Rejected'),
                    const Tab(text: 'All'),
                  ],
                ),
              ),
              body: Column(
                children: [
                  // 1. Module Category Filter Ribbon
                  _buildCategoryChips(context, requests, moduleCounts),
                  const Divider(height: 1),

                  // 2. Active Filter indicator (if not 'all')
                  if (_selectedCategory != 'all')
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.35),
                      child: Row(
                        children: [
                          Icon(Icons.filter_alt_rounded, size: 14, color: Theme.of(context).colorScheme.primary),
                          const SizedBox(width: 6),
                          Text(
                            'Filtered by Module: ${_categoryLabel(_selectedCategory)}',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                          const Spacer(),
                          InkWell(
                            onTap: () {
                              HapticFeedback.lightImpact();
                              setState(() => _selectedCategory = 'all');
                            },
                            child: Row(
                              children: [
                                Text(
                                  'Clear Filter',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(context).colorScheme.primary,
                                  ),
                                ),
                                const SizedBox(width: 2),
                                Icon(Icons.close_rounded, size: 14, color: Theme.of(context).colorScheme.primary),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                  // 3. Tab Contents
                  Expanded(
                    child: TabBarView(
                      children: [
                        _buildRequestList(
                          context,
                          ref,
                          libraryId,
                          pending,
                          isPendingTab: true,
                          moduleCounts: moduleCounts,
                          emptyTitle: 'All caught up! 🎉',
                          emptySubtitle: 'There are no pending requests for this filter.',
                          emptyIcon: Icons.check_circle_outline_rounded,
                        ),
                        _buildRequestList(
                          context,
                          ref,
                          libraryId,
                          approved,
                          moduleCounts: moduleCounts,
                          emptyTitle: 'No approved requests',
                          emptySubtitle: 'Approved requests will appear here.',
                          emptyIcon: Icons.task_alt_rounded,
                        ),
                        _buildRequestList(
                          context,
                          ref,
                          libraryId,
                          rejected,
                          moduleCounts: moduleCounts,
                          emptyTitle: 'No rejected requests',
                          emptySubtitle: 'Rejected requests will appear here.',
                          emptyIcon: Icons.cancel_outlined,
                        ),
                        _buildRequestList(
                          context,
                          ref,
                          libraryId,
                          requests,
                          moduleCounts: moduleCounts,
                          emptyTitle: 'No requests yet',
                          emptySubtitle: 'Student requests across modules will appear here.',
                          emptyIcon: Icons.inbox_outlined,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildRequestList(
    BuildContext context,
    WidgetRef ref,
    String? libraryId,
    List<StudentRequestItem> rawItems, {
    required String emptyTitle,
    required String emptySubtitle,
    required IconData emptyIcon,
    bool isPendingTab = false,
    required RequestModuleCounts moduleCounts,
  }) {
    final items = _filterByCategory(rawItems);

    if (items.isEmpty) {
      return RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(requestsStreamProvider);
          await Future.delayed(const Duration(milliseconds: 500));
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.4),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      emptyIcon,
                      size: 56,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    _selectedCategory != 'all' && rawItems.isNotEmpty
                        ? 'No ${_categoryLabel(_selectedCategory)} Requests'
                        : emptyTitle,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _selectedCategory != 'all' && rawItems.isNotEmpty
                        ? 'There are no requests matching "${_categoryLabel(_selectedCategory)}" in this tab.'
                        : emptySubtitle,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                  if (_selectedCategory != 'all' && rawItems.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: () => setState(() => _selectedCategory = 'all'),
                      icon: const Icon(Icons.clear_all_rounded),
                      label: const Text('Show All Requests'),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(requestsStreamProvider);
        await Future.delayed(const Duration(milliseconds: 500));
      },
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        itemCount: (isPendingTab && _selectedCategory == 'all' && items.isNotEmpty)
            ? items.length + 1
            : items.length,
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          // If pending tab with 'all' filter, inject module breakdown banner at top
          if (isPendingTab && _selectedCategory == 'all' && items.isNotEmpty) {
            if (index == 0) {
              return _buildModuleBreakdownBanner(context, moduleCounts);
            }
            final item = items[index - 1];
            return _buildDismissibleCard(context, libraryId, item);
          }

          final item = items[index];
          return _buildDismissibleCard(context, libraryId, item);
        },
      ),
    );
  }

  Widget _buildDismissibleCard(BuildContext context, String? libraryId, StudentRequestItem item) {
    final card = _RequestCard(
      request: item,
      onApprove: () => _updateRequestStatus(context, libraryId, item.id, 'approved', requestItem: item),
      onReject: () => _promptReject(context, libraryId, item),
      onDelete: () => _confirmDelete(context, libraryId, item.id),
    );

    if (!item.isPending) {
      return card;
    }

    return Dismissible(
      key: ValueKey('req_dismiss_${item.id}'),
      direction: DismissDirection.horizontal,
      background: Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: Colors.green.shade600,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Row(
          children: [
            Icon(Icons.check_circle_rounded, color: Colors.white, size: 26),
            SizedBox(width: 8),
            Text('Quick Approve', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
          ],
        ),
      ),
      secondaryBackground: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: Colors.red.shade600,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text('Reject Request', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
            SizedBox(width: 8),
            Icon(Icons.cancel_rounded, color: Colors.white, size: 26),
          ],
        ),
      ),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          HapticFeedback.mediumImpact();
          await _updateRequestStatus(context, libraryId, item.id, 'approved', requestItem: item);
        } else if (direction == DismissDirection.endToStart) {
          HapticFeedback.lightImpact();
          await _promptReject(context, libraryId, item);
        }
        return false; // Retain card state until Firestore stream updates the list
      },
      child: card,
    );
  }

  Future<void> _updateRequestStatus(
    BuildContext context,
    String? libraryId,
    String requestId,
    String newStatus, {
    String? reason,
    StudentRequestItem? requestItem,
  }) async {
    if (libraryId == null || libraryId.isEmpty) return;

    if (newStatus == 'approved') {
      final isRenewal = requestItem != null &&
          (requestItem.type.toLowerCase() == 'renewal' || requestItem.type.toLowerCase() == 'plan_renewal');
      final amount = requestItem?.amount ?? 0.0;
      final planName = requestItem?.requestedPlanName ?? 'Standard Plan';
      final studentName = requestItem?.studentName ?? 'Student';
      String selectedPaymentMethod = requestItem?.paymentMethod ?? 'Cash';

      final confirmed = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setModalState) => Container(
            decoration: BoxDecoration(
              color: Theme.of(ctx).colorScheme.surface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom + MediaQuery.of(ctx).viewPadding.bottom + 16,
              left: 20,
              right: 20,
              top: 12,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Theme.of(ctx).colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.check_circle_rounded, color: Colors.green, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        isRenewal ? 'Collect Payment & Approve Renewal' : 'Approve Request',
                        style: Theme.of(ctx).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                if (isRenewal) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(ctx).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Theme.of(ctx).colorScheme.outlineVariant.withValues(alpha: 0.5)),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Student:', style: TextStyle(color: Theme.of(ctx).colorScheme.onSurfaceVariant, fontSize: 13)),
                            Text(studentName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Plan:', style: TextStyle(color: Theme.of(ctx).colorScheme.onSurfaceVariant, fontSize: 13)),
                            Text(planName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          ],
                        ),
                        if (amount > 0) ...[
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Amount to Collect:', style: TextStyle(color: Theme.of(ctx).colorScheme.onSurfaceVariant, fontSize: 13)),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.green.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '₹${amount.toStringAsFixed(0)}',
                                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 14),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    initialValue: selectedPaymentMethod,
                    decoration: const InputDecoration(
                      labelText: 'Payment Method Received',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'Cash', child: Text('Cash at Desk')),
                      DropdownMenuItem(value: 'UPI', child: Text('UPI / QR Code')),
                      DropdownMenuItem(value: 'Bank Transfer', child: Text('Bank Transfer (NEFT/IMPS)')),
                      DropdownMenuItem(value: 'Cheque', child: Text('Cheque / DD')),
                      DropdownMenuItem(value: 'Other', child: Text('Other')),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setModalState(() => selectedPaymentMethod = val);
                      }
                    },
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Confirming will collect fee, issue digital receipt, and renew membership immediately.',
                    style: Theme.of(ctx).textTheme.bodySmall?.copyWith(color: Theme.of(ctx).colorScheme.onSurfaceVariant),
                  ),
                ] else ...[
                  Text(
                    'Are you sure you want to approve this request? The student will be provisioned and assigned accordingly.',
                    style: Theme.of(ctx).textTheme.bodyMedium,
                  ),
                ],
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(ctx).pop(false),
                        style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 13)),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.green.shade700,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                        ),
                        onPressed: () {
                          if (isRenewal && selectedPaymentMethod != requestItem.paymentMethod) {
                            FirebaseFirestore.instance
                                .collection('libraries')
                                .doc(libraryId)
                                .collection('requests')
                                .doc(requestId)
                                .update({'paymentMethod': selectedPaymentMethod}).ignore();
                          }
                          Navigator.of(ctx).pop(true);
                        },
                        child: Text(isRenewal ? 'Collect & Approve' : 'Approve'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );

      if (confirmed != true) return;
    }

    if (!context.mounted) return;

    try {
      if (newStatus == 'approved') {
        // Complete Provisioning: Creates student, assigns seat, links user, and updates request
        await StudentProvisioningService.approveAndProvisionRequest(
          libraryId: libraryId,
          requestId: requestId,
        );
      } else {
        final updateData = <String, dynamic>{
          'status': newStatus,
          'processedAt': FieldValue.serverTimestamp(),
        };
        if (reason != null && reason.trim().isNotEmpty) {
          updateData['rejectionReason'] = reason.trim();
        }

        await FirebaseFirestore.instance
            .collection('libraries')
            .doc(libraryId)
            .collection('requests')
            .doc(requestId)
            .update(updateData);

        // Notify student of rejection/update
        if (requestItem != null) {
          final target = (requestItem.studentId.isNotEmpty && requestItem.studentId != 'pending')
              ? requestItem.studentId
              : (requestItem.studentUserId ?? '');
          if (target.isNotEmpty) {
            final reasonText = reason != null && reason.trim().isNotEmpty
                ? ': "$reason"'
                : '';
            final reqTitle = switch (requestItem.type.toLowerCase()) {
              'registration' || 'newregistration' => 'Admission Application',
              'seat_change' || 'seatchange' => 'Seat Change Request',
              'renewal' || 'plan_renewal' => 'Plan Renewal',
              'profile_update' => 'Profile Update',
              _ => 'Request',
            };
            AppNotificationService.sendNotification(
              libraryId: libraryId,
              title: '$reqTitle Update',
              body: 'Your $reqTitle could not be approved$reasonText. Please visit reception for details.',
              type: 'admission',
              targetRole: 'student',
              targetUserId: target,
              actionRoute: Routes.studentHome,
            ).ignore();
          }
        }
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              newStatus == 'approved'
                  ? 'Request approved successfully'
                  : 'Request rejected',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        AppErrorFormatter.showErrorSnackBar(context, e, actionContext: 'request');
      }
    }
  }

  Future<void> _promptReject(
    BuildContext context,
    String? libraryId,
    StudentRequestItem request,
  ) async {
    final reasonController = TextEditingController();

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: Theme.of(ctx).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom + MediaQuery.of(ctx).viewPadding.bottom + 16,
          left: 20,
          right: 20,
          top: 12,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(ctx).colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.cancel_rounded, color: Colors.red, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Reject Request',
                    style: Theme.of(ctx).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(ctx).pop(false),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Are you sure you want to reject this request from ${request.studentName}?',
              style: Theme.of(ctx).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Rejection Reason (optional)',
                hintText: 'e.g. Seat unavailable, invalid plan...',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(ctx).pop(false),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 13),
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: Theme.of(ctx).colorScheme.error,
                      foregroundColor: Theme.of(ctx).colorScheme.onError,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                    ),
                    onPressed: () => Navigator.of(ctx).pop(true),
                    child: const Text('Reject Request'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );

    if (confirmed == true && context.mounted) {
      await _updateRequestStatus(
        context,
        libraryId,
        request.id,
        'rejected',
        reason: reasonController.text,
      );
    }
  }

  Future<void> _confirmDelete(
    BuildContext context,
    String? libraryId,
    String requestId,
  ) async {
    if (libraryId == null || libraryId.isEmpty) return;

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: Theme.of(ctx).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewPadding.bottom + 16,
          left: 20,
          right: 20,
          top: 12,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(ctx).colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Delete Request Record',
                    style: Theme.of(ctx).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'Are you sure you want to delete this request record? This action cannot be undone.',
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(ctx).pop(false),
                    style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 13)),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: Theme.of(ctx).colorScheme.error,
                      foregroundColor: Theme.of(ctx).colorScheme.onError,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                    ),
                    onPressed: () => Navigator.of(ctx).pop(true),
                    child: const Text('Delete'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );

    if (confirmed == true && context.mounted) {
      try {
        await FirebaseFirestore.instance
            .collection('libraries')
            .doc(libraryId)
            .collection('requests')
            .doc(requestId)
            .delete();

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Request deleted successfully'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          AppErrorFormatter.showErrorSnackBar(context, e, actionContext: 'request');
        }
      }
    }
  }
}

class _RequestCard extends StatelessWidget {
  final StudentRequestItem request;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final VoidCallback onDelete;

  const _RequestCard({
    required this.request,
    required this.onApprove,
    required this.onReject,
    required this.onDelete,
  });

  String _formatDate(DateTime? date) {
    if (date == null) return 'Recently';
    return DateFormat('MMM dd, yyyy • hh:mm a').format(date);
  }

  String _formatType(String type) {
    switch (type.toLowerCase()) {
      case 'seat_change':
      case 'seatchange':
        return 'Seat Change';
      case 'newregistration':
        return 'New Registration';
      case 'renewal':
        return 'Plan Renewal';
      default:
        if (type.isEmpty) return 'General';
        return type[0].toUpperCase() + type.substring(1);
    }
  }

  IconData _getTypeIcon(String type) {
    switch (type.toLowerCase()) {
      case 'seat_change':
      case 'seatchange':
        return Icons.event_seat_rounded;
      case 'renewal':
        return Icons.autorenew_rounded;
      case 'newregistration':
        return Icons.person_add_rounded;
      default:
        return Icons.assignment_outlined;
    }
  }

  Widget _buildModuleTag(BuildContext context, String type) {
    final t = type.toLowerCase().trim();
    String moduleName;
    Color color;
    IconData icon;

    if (t == 'seat_change' || t == 'seatchange') {
      moduleName = 'Seats';
      color = const Color(0xFFD97706);
      icon = Icons.event_seat_rounded;
    } else if (t == 'registration' || t == 'newregistration') {
      moduleName = 'Admissions';
      color = const Color(0xFF2563EB);
      icon = Icons.school_rounded;
    } else if (t == 'renewal' || t == 'plan_renewal') {
      moduleName = 'Plans';
      color = const Color(0xFF059669);
      icon = Icons.autorenew_rounded;
    } else if (t == 'profile_update') {
      moduleName = 'Profile';
      color = const Color(0xFF7C3AED);
      icon = Icons.person_rounded;
    } else {
      moduleName = 'General';
      color = const Color(0xFF64748B);
      icon = Icons.assignment_outlined;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 4),
          Text(
            'Module: $moduleName',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(BuildContext context, String status) {
    Color bg;
    Color fg;
    IconData icon;
    String label;

    switch (status) {
      case 'approved':
        bg = Colors.green.withValues(alpha: 0.12);
        fg = Colors.green.shade800;
        icon = Icons.check_circle_rounded;
        label = 'Approved';
        break;
      case 'rejected':
        bg = Colors.red.withValues(alpha: 0.12);
        fg = Colors.red.shade800;
        icon = Icons.cancel_rounded;
        label = 'Rejected';
        break;
      case 'superseded':
        bg = Colors.grey.withValues(alpha: 0.15);
        fg = Colors.grey.shade700;
        icon = Icons.history_rounded;
        label = 'Superseded';
        break;
      default:
        bg = Colors.amber.withValues(alpha: 0.15);
        fg = Colors.amber.shade900;
        icon = Icons.schedule_rounded;
        label = 'Pending';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: fg),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isPending = request.isPending;

    final isSeatChange = (request.type.toLowerCase() == 'seat_change' || request.type.toLowerCase() == 'seatchange');
    final isRenewal = (request.type.toLowerCase() == 'renewal' || request.type.toLowerCase() == 'plan_renewal');

    return Card(
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isPending
              ? theme.colorScheme.primary.withValues(alpha: 0.4)
              : theme.colorScheme.outlineVariant.withValues(alpha: 0.7),
          width: isPending ? 1.5 : 1,
        ),
      ),
      child: InkWell(
        onTap: () => context.push('${Routes.adminRequests}/${request.id}'),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Row: Type chip, Status chip, and Overflow menu
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isSeatChange
                          ? const Color(0xFFFEF3C7)
                          : (isRenewal
                              ? const Color(0xFFE0F2FE)
                              : theme.colorScheme.secondaryContainer.withValues(alpha: 0.7)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _getTypeIcon(request.type),
                          size: 15,
                          color: isSeatChange
                              ? const Color(0xFFB45309)
                              : (isRenewal
                                  ? const Color(0xFF0369A1)
                                  : theme.colorScheme.onSecondaryContainer),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _formatType(request.type),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isSeatChange
                                ? const Color(0xFF78350F)
                                : (isRenewal
                                    ? const Color(0xFF0C4A6E)
                                    : theme.colorScheme.onSecondaryContainer),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  _buildModuleTag(context, request.type),
                  const Spacer(),
                  _buildStatusBadge(context, request.status),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert_rounded, size: 20),
                    padding: EdgeInsets.zero,
                    tooltip: 'Request options',
                    onSelected: (value) {
                      if (value == 'view') {
                        context.push('${Routes.adminRequests}/${request.id}');
                      } else if (value == 'approve') {
                        onApprove();
                      } else if (value == 'reject') {
                        onReject();
                      } else if (value == 'delete') {
                        onDelete();
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'view',
                        child: Row(
                          children: [
                            Icon(Icons.visibility_outlined, color: Colors.blue, size: 18),
                            SizedBox(width: 8),
                            Text('View Details'),
                          ],
                        ),
                      ),
                      if (isPending) ...[
                        const PopupMenuItem(
                          value: 'approve',
                          child: Row(
                            children: [
                              Icon(Icons.check_circle_outline_rounded, color: Colors.green, size: 18),
                              SizedBox(width: 8),
                              Text('Approve Request', style: TextStyle(color: Colors.green)),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'reject',
                          child: Row(
                            children: [
                              Icon(Icons.cancel_outlined, color: Colors.orange, size: 18),
                              SizedBox(width: 8),
                              Text('Reject Request', style: TextStyle(color: Colors.orange)),
                            ],
                          ),
                        ),
                      ],
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete_outline_rounded, color: Colors.red, size: 18),
                            SizedBox(width: 8),
                            Text('Delete', style: TextStyle(color: Colors.red)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Student Info & Date
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: theme.colorScheme.primaryContainer,
                    foregroundColor: theme.colorScheme.onPrimaryContainer,
                    child: const Icon(Icons.person_rounded, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          request.studentName,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Wrap(
                          spacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            if (request.membershipNumber != null && request.membershipNumber!.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.primaryContainer.withValues(alpha: 0.5),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'Member ID: ${request.membershipNumber}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: theme.colorScheme.primary,
                                  ),
                                ),
                              )
                            else if (request.studentPhone != null && request.studentPhone!.isNotEmpty)
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.phone_rounded, size: 12, color: theme.colorScheme.onSurfaceVariant),
                                  const SizedBox(width: 4),
                                  Text(
                                    request.studentPhone!,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            if (request.studentEmail != null && request.studentEmail!.isNotEmpty)
                              Text(
                                request.studentEmail!,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: theme.colorScheme.outline,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Text(
                    _formatDate(request.createdAt),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),

              // Highlighted Seat Change Transfer Card (For Seat Change Requests)
              if (isSeatChange && request.targetSeatLabel != null) ...[
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isPending
                          ? const Color(0xFFF59E0B).withValues(alpha: 0.5)
                          : theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          // Current Seat
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'CURRENT SEAT',
                                  style: TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.bold,
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  request.currentSeatLabel ?? 'No Seat Assigned',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                                ),
                                if (request.currentSectionName != null && request.currentSectionName!.isNotEmpty)
                                  Text(
                                    request.currentSectionName!,
                                    style: TextStyle(fontSize: 11, color: theme.colorScheme.outline),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.all(6),
                            margin: const EdgeInsets.symmetric(horizontal: 8),
                            decoration: BoxDecoration(
                              color: Colors.green.withValues(alpha: 0.12),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.arrow_forward_rounded, color: Colors.green, size: 18),
                          ),
                          // Target Seat
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                const Text(
                                  'REQUESTED SEAT',
                                  style: TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  request.targetSeatLabel!,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: Colors.green),
                                ),
                                if (request.targetSectionName != null && request.targetSectionName!.isNotEmpty)
                                  Text(
                                    request.targetSectionName!,
                                    style: TextStyle(fontSize: 11, color: theme.colorScheme.outline),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (request.reason != null && request.reason!.trim().isNotEmpty) ...[
                        const SizedBox(height: 8),
                        const Divider(height: 1),
                        const SizedBox(height: 6),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.notes_rounded, size: 14, color: theme.colorScheme.outline),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Reason: "${request.reason!}"',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontStyle: FontStyle.italic,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],

              // Highlighted Plan Renewal Details Card (For Renewal Requests)
              if (isRenewal) ...[
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isPending
                          ? const Color(0xFF0284C7).withValues(alpha: 0.5)
                          : theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
                    ),
                  ),
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
                                  'REQUESTED PLAN',
                                  style: TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.bold,
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  request.requestedPlanName ?? 'Standard Plan',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                                ),
                              ],
                            ),
                          ),
                          if (request.amount != null && request.amount! > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.green.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                              ),
                              child: Text(
                                '₹${request.amount!.toStringAsFixed(0)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: Colors.green,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Divider(height: 1),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.payment_rounded, size: 14, color: theme.colorScheme.outline),
                          const SizedBox(width: 6),
                          Text(
                            'Mode: ${request.paymentModeLabel ?? request.paymentMethod ?? 'Pay at Desk'}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          if (request.referenceNumber != null && request.referenceNumber!.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            Text('•', style: TextStyle(color: theme.colorScheme.outline)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Ref: ${request.referenceNumber!}',
                                style: TextStyle(fontSize: 11.5, color: theme.colorScheme.outline),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (request.cycleStartDate != null && request.cycleEndDate != null) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(Icons.calendar_month_rounded, size: 14, color: theme.colorScheme.outline),
                            const SizedBox(width: 6),
                            Text(
                              'Cycle: ${_formatDate(request.cycleStartDate)} – ${_formatDate(request.cycleEndDate)}',
                              style: TextStyle(fontSize: 11.5, color: theme.colorScheme.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],

              // Message Body (for other request types)
              if (!isSeatChange && !isRenewal && request.message.trim().isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    request.message,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      height: 1.35,
                    ),
                  ),
                ),
              ],

            // Rejection reason note if rejected
            if (request.status == 'rejected' &&
                request.rejectionReason != null &&
                request.rejectionReason!.trim().isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.info_outline_rounded, color: Colors.red, size: 16),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Reason: ${request.rejectionReason}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.red.shade900,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

              // Contextual Module Shortcut Action
              if (isPending) ...[
                if (isSeatChange) ...[
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFD97706),
                        side: BorderSide(color: const Color(0xFFD97706).withValues(alpha: 0.5)),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        visualDensity: VisualDensity.compact,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: const Icon(Icons.chair_rounded, size: 14),
                      label: const Text(
                        'Inspect Target Desk in Seat Radar ↗',
                        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                      ),
                      onPressed: () => context.push(Routes.adminSeats),
                    ),
                  ),
                ] else if (isRenewal && request.studentId.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF059669),
                        side: BorderSide(color: const Color(0xFF059669).withValues(alpha: 0.5)),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        visualDensity: VisualDensity.compact,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: const Icon(Icons.person_search_rounded, size: 14),
                      label: const Text(
                        'Check Student Profile & Dues ↗',
                        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                      ),
                      onPressed: () => context.push('/admin/students/${request.studentId}'),
                    ),
                  ),
                ],
              ],

            // Action Buttons
            const SizedBox(height: 14),
            const Divider(height: 1),
            const SizedBox(height: 10),
            if (isPending)
              Row(
                children: [
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: theme.colorScheme.error,
                      side: BorderSide(color: theme.colorScheme.error.withValues(alpha: 0.7)),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: onReject,
                    icon: const Icon(Icons.close_rounded, size: 16),
                    label: const Text('Reject', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.green.shade700,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: onApprove,
                      icon: const Icon(Icons.check_circle_rounded, size: 16),
                      label: Text(
                        isRenewal && (request.amount != null && request.amount! > 0)
                            ? 'Collect ₹${request.amount!.toStringAsFixed(0)} & Approve'
                            : (isSeatChange ? 'Approve Seat' : 'Approve Request'),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  IconButton(
                    tooltip: 'View Details',
                    icon: Icon(Icons.arrow_forward_rounded, size: 18, color: theme.colorScheme.primary),
                    onPressed: () => context.push('${Routes.adminRequests}/${request.id}'),
                  ),
                ],
              )
            else
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        request.status == 'approved' ? Icons.check_circle_outline_rounded : Icons.cancel_outlined,
                        size: 15,
                        color: request.status == 'approved' ? Colors.green : Colors.red,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        request.status == 'approved' ? 'Request Approved' : 'Request Resolved',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: request.status == 'approved' ? Colors.green.shade800 : Colors.red.shade800,
                        ),
                      ),
                    ],
                  ),
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      visualDensity: VisualDensity.compact,
                    ),
                    icon: const Icon(Icons.open_in_new_rounded, size: 14),
                    label: const Text('View Details', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    onPressed: () => context.push('${Routes.adminRequests}/${request.id}'),
                  ),
                ],
              ),
          ],
        ),
      ),
      ),
    );
  }
}
