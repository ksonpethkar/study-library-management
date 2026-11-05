import 'package:study_library/services/whatsapp_service.dart';
import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:study_library/core/widgets/pressable_scale.dart';
import '../providers/student_providers.dart';
import '../../../../core/providers/library_provider.dart';
import 'package:study_library/services/image_service.dart';
import 'package:study_library/models/student_model.dart';
import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:study_library/core/utils/file_download_helper.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:study_library/core/widgets/loading_skeleton.dart';
import 'package:study_library/core/utils/seat_helper.dart';
import 'student_detail_screen.dart';

enum StudentSortOrder {
  recent,
  seatNumber,
  nameAsc,
  expirySoon,
  highestDue,
}

class StudentListScreen extends ConsumerStatefulWidget {
  final String? initialFilter;
  const StudentListScreen({super.key, this.initialFilter});

  @override
  ConsumerState<StudentListScreen> createState() => _StudentListScreenState();
}

class _StudentListScreenState extends ConsumerState<StudentListScreen> {
  String _searchQuery = '';
  final _searchController = TextEditingController();
  List<StudentModel>? _searchResults;
  bool _isSearching = false;
  Timer? _debounce;
  String _selectedFilter = 'All';
  StudentSortOrder _selectedSortOrder = StudentSortOrder.recent;
  Set<String> _selectedStudentIds = {};
  final Set<String> _swipeThresholdReached = {};
  bool _isSelectionMode = false;
  String? _desktopSelectedStudentId;
  late final ScrollController _scrollController;
  
  final List<String> _filters = [
    'All',
    'Active',
    'Due Soon',
    'Has Dues',
    'Expired',
    'Grace',
    'Pending',
    'Archived',
  ];

  static String _normalizeFilter(String? raw) {
    if (raw == null || raw.isEmpty) return 'All';
    final lower = raw.toLowerCase().trim();
    if (lower == 'renewals_due' || lower == 'renew in 7d' || lower == 'due soon' || lower == 'due_soon' || lower == 'expiring') {
      return 'Due Soon';
    }
    if (lower == 'has dues' || lower == 'has_dues' || lower == 'defaulters' || lower == 'dues') {
      return 'Has Dues';
    }
    if (lower == 'active') return 'Active';
    if (lower == 'expired') return 'Expired';
    if (lower == 'grace') return 'Grace';
    if (lower == 'pending') return 'Pending';
    if (lower == 'archived' || lower == 'blocked') return 'Archived';
    return 'All';
  }

  bool _matchesFilter(StudentModel s, String filter) {
    final now = DateTime.now();
    switch (filter) {
      case 'All':
        return true;
      case 'Due Soon':
        // Students in grace period are immediately due for renewal
        if (s.membershipStatus == MembershipStatus.grace) return true;
        if (s.membershipStatus != MembershipStatus.active) return false;
        final e = s.planEndDate;
        if (e == null) return false;
        // Include active students expiring within next 14 days
        return !e.isBefore(now.subtract(const Duration(days: 1))) &&
            e.isBefore(now.add(const Duration(days: 14)));
      case 'Has Dues':
        return (s.pendingDueBalance ?? 0) > 0;
      case 'Active':
        return s.membershipStatus == MembershipStatus.active;
      case 'Expired':
        return s.membershipStatus == MembershipStatus.expired;
      case 'Grace':
        return s.membershipStatus == MembershipStatus.grace;
      case 'Pending':
        return s.membershipStatus == MembershipStatus.pending;
      case 'Archived':
        return s.membershipStatus == MembershipStatus.archived || s.membershipStatus == MembershipStatus.blocked;
      default:
        return s.membershipStatus.name.toLowerCase() == filter.toLowerCase();
    }
  }

  @override
  void initState() {
    super.initState();
    if (widget.initialFilter != null && widget.initialFilter!.isNotEmpty) {
      _selectedFilter = _normalizeFilter(widget.initialFilter);
    }
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);
  }

  @override
  void didUpdateWidget(covariant StudentListScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialFilter != null && widget.initialFilter != oldWidget.initialFilter) {
      setState(() {
        _selectedFilter = _normalizeFilter(widget.initialFilter);
      });
    }
  }

  void _onScroll() {
    if (_scrollController.hasClients &&
        _scrollController.position.pixels >= 
        _scrollController.position.maxScrollExtent - 200) {
      ref.read(studentPageProvider.notifier).loadMore();
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  List<StudentModel> _filteredStudents(List<StudentModel> all) {
    if (_searchQuery.isEmpty) return all;
    final q = _searchQuery.toLowerCase().trim();
    return all.where((s) {
      final nameMatch = s.name.toLowerCase().contains(q);
      final phoneMatch = s.phone.contains(q);
      final idMatch = s.membershipNumber?.toLowerCase().contains(q) ?? false;
      final emailMatch = s.email.toLowerCase().contains(q);

      final seatRaw = s.seatId?.toLowerCase() ?? '';
      final seatLabel = SeatHelper.formatSeatLabel(seatId: s.seatId, includePrefix: false).toLowerCase();
      final seatMatch = seatRaw.contains(q) ||
          seatLabel == q ||
          '#$seatLabel' == q ||
          'seat $seatLabel'.contains(q) ||
          'desk $seatLabel'.contains(q);

      return nameMatch || phoneMatch || idMatch || emailMatch || seatMatch;
    }).toList();
  }

  void _applySort(List<StudentModel> list) {
    switch (_selectedSortOrder) {
      case StudentSortOrder.recent:
        break;
      case StudentSortOrder.nameAsc:
        list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        break;
      case StudentSortOrder.seatNumber:
        list.sort((a, b) {
          if (a.seatId == null && b.seatId == null) return 0;
          if (a.seatId == null) return 1;
          if (b.seatId == null) return -1;
          final aNum = int.tryParse(SeatHelper.formatSeatLabel(seatId: a.seatId, includePrefix: false).replaceAll(RegExp(r'\D'), ''));
          final bNum = int.tryParse(SeatHelper.formatSeatLabel(seatId: b.seatId, includePrefix: false).replaceAll(RegExp(r'\D'), ''));
          if (aNum != null && bNum != null) return aNum.compareTo(bNum);
          return (a.seatId ?? '').compareTo(b.seatId ?? '');
        });
        break;
      case StudentSortOrder.expirySoon:
        list.sort((a, b) {
          if (a.planEndDate == null && b.planEndDate == null) return 0;
          if (a.planEndDate == null) return 1;
          if (b.planEndDate == null) return -1;
          return a.planEndDate!.compareTo(b.planEndDate!);
        });
        break;
      case StudentSortOrder.highestDue:
        list.sort((a, b) {
          final aDue = a.pendingDueBalance ?? 0.0;
          final bDue = b.pendingDueBalance ?? 0.0;
          return bDue.compareTo(aDue);
        });
        break;
    }
  }

  Future<void> _runSearch(String query) async {
    final cleanQ = query.trim();
    if (cleanQ.isEmpty) {
      setState(() {
        _searchResults = null;
        _isSearching = false;
      });
      return;
    }
    setState(() => _isSearching = true);
    final libraryId = ref.read(currentLibraryIdProvider) ?? '';
    if (libraryId.isEmpty) {
      setState(() => _isSearching = false);
      return;
    }

    try {
      final localLoaded = ref.read(studentPageProvider).students;
      final localMatches = _filteredStudents(localLoaded);
      final List<StudentModel> serverResults = [];

      // Query 1: Exact / prefix on name in TitleCase format (e.g. "Ashish" if user typed "ashish")
      final titleQuery = cleanQ.length > 1
          ? cleanQ[0].toUpperCase() + cleanQ.substring(1)
          : cleanQ.toUpperCase();

      final snapTitle = await FirebaseFirestore.instance
          .collection('libraries').doc(libraryId)
          .collection('students')
          .orderBy('name')
          .startAt([titleQuery])
          .endAt(['$titleQuery\uf8ff'])
          .limit(15)
          .get();
      serverResults.addAll(snapTitle.docs.map((d) => StudentModel.fromJson({...d.data(), 'id': d.id})));

      // Query 2: Membership ID
      final snapId = await FirebaseFirestore.instance
          .collection('libraries').doc(libraryId)
          .collection('students')
          .where('membershipNumber', isGreaterThanOrEqualTo: cleanQ.toUpperCase())
          .where('membershipNumber', isLessThanOrEqualTo: '${cleanQ.toUpperCase()}\uf8ff')
          .limit(5)
          .get();
      serverResults.addAll(snapId.docs.map((d) => StudentModel.fromJson({...d.data(), 'id': d.id})));

      // Query 3: Phone number prefix
      final snapPhone = await FirebaseFirestore.instance
          .collection('libraries').doc(libraryId)
          .collection('students')
          .where('phone', isGreaterThanOrEqualTo: cleanQ)
          .where('phone', isLessThanOrEqualTo: '$cleanQ\uf8ff')
          .limit(5)
          .get();
      serverResults.addAll(snapPhone.docs.map((d) => StudentModel.fromJson({...d.data(), 'id': d.id})));

      // Merge local matches and server results without duplicates
      final seen = <String>{};
      final merged = [...localMatches, ...serverResults].where((s) => seen.add(s.id)).toList();

      if (mounted) {
        setState(() {
          _searchResults = merged;
          _isSearching = false;
        });
      }
    } catch (_) {
      if (mounted) {
        final localLoaded = ref.read(studentPageProvider).students;
        setState(() {
          _searchResults = _filteredStudents(localLoaded);
          _isSearching = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final studentState = ref.watch(studentPageProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: _isSelectionMode 
            ? Text('${_selectedStudentIds.length} Selected') 
            : const Text('Students'),
        actions: [
          if (!_isSelectionMode) ...[
            FilledButton.icon(
              style: FilledButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              ),
              icon: const Icon(Icons.person_add_rounded, size: 17),
              label: const Text('Add Student', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              onPressed: () => _navigateToAddStudent(context),
            ),
            const SizedBox(width: 4),
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              tooltip: 'Refresh',
              onPressed: () => ref.read(studentPageProvider.notifier).refresh(),
            ),
            IconButton(
              icon: const Icon(Icons.upload_file),
              tooltip: 'Import CSV',
              onPressed: () => context.push('/admin/students/import'),
            ),
            const SizedBox(width: 8),
          ],
          if (_isSelectionMode) ...[
            IconButton(
              icon: const Icon(Icons.person_off_outlined),
              tooltip: 'Deactivate selected',
              onPressed: _bulkDeactivate,
            ),
            IconButton(
              icon: const Icon(Icons.download_outlined),
              tooltip: 'Export selected as CSV',
              onPressed: _bulkExportCsv,
            ),
            IconButton(
              icon: const Icon(Icons.campaign_outlined),
              tooltip: 'Send announcement',
              onPressed: _bulkAnnounce,
            ),
            IconButton(
              icon: const Icon(Icons.select_all_rounded),
              tooltip: 'Select All',
              onPressed: () {
                final allStudents = studentState.students;
                setState(() {
                  _selectedStudentIds = allStudents.map((s) => s.id).toSet();
                });
              },
            ),
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              tooltip: 'Delete Selected',
              onPressed: _bulkDelete,
            ),
            IconButton(
              icon: const Icon(Icons.clear),
              tooltip: 'Cancel',
              onPressed: () => setState(() {
                _isSelectionMode = false;
                _selectedStudentIds.clear();
              }),
            ),
          ]
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isSplitDesktop = constraints.maxWidth >= 1024;
          final streamStudents = ref.watch(studentsStreamProvider).value;
          final students = (streamStudents != null && streamStudents.isNotEmpty)
              ? streamStudents
              : (studentState.students.isNotEmpty ? studentState.students : (streamStudents ?? []));

          if (studentState.isLoading && students.isEmpty && !_isSearching) {
            return const StudentListSkeleton(count: 6);
          }
          if (studentState.error != null && students.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Error: ${studentState.error}'),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () => ref.read(studentPageProvider.notifier).refresh(),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          final searchResults = _searchResults ?? _filteredStudents(students);
          var filtered = searchResults.where((s) => _matchesFilter(s, _selectedFilter)).toList();
          _applySort(filtered);

          // If on wide desktop workbench (>= 1024px)
          if (isSplitDesktop) {
            if (filtered.isNotEmpty &&
                (_desktopSelectedStudentId == null ||
                    !filtered.any((s) => s.id == _desktopSelectedStudentId))) {
              _desktopSelectedStudentId = filtered.first.id;
            }

            return Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Left 380px Workbench Rail
                SizedBox(
                  width: 380,
                  child: Column(
                    children: [
                      if (!_isSelectionMode) ...[
                        _buildSearchBar(theme),
                        _buildFilterChips(),
                      ],
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.25),
                          border: Border(bottom: BorderSide(color: theme.dividerColor, width: 0.5)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${filtered.length} Scholars',
                              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5, color: theme.colorScheme.primary),
                            ),
                            Text(
                              'Sort: ${_getSortLabel(_selectedSortOrder)}',
                              style: const TextStyle(fontSize: 11.5, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: filtered.isEmpty
                            ? Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.search_off_rounded, size: 40, color: theme.colorScheme.outline),
                                      const SizedBox(height: 8),
                                      const Text('No matching students', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                      const SizedBox(height: 4),
                                      Text('Try changing your search or filter', style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600)),
                                    ],
                                  ),
                                ),
                              )
                            : RefreshIndicator(
                                onRefresh: () async {
                                  await ref.read(studentPageProvider.notifier).loadFirst();
                                },
                                child: ListView.builder(
                                  controller: _scrollController,
                                  padding: const EdgeInsets.only(top: 4, bottom: 96),
                                  itemCount: filtered.length,
                                  itemBuilder: (context, index) {
                                    final student = filtered[index];
                                    final isMultiSelected = _selectedStudentIds.contains(student.id);
                                    final isFocused = student.id == _desktopSelectedStudentId;

                                    return PressableScale(
                                      scaleFactor: 0.99,
                                      onTap: () {
                                        if (_isSelectionMode) {
                                          HapticFeedback.selectionClick();
                                          setState(() {
                                            isMultiSelected
                                                ? _selectedStudentIds.remove(student.id)
                                                : _selectedStudentIds.add(student.id);
                                            if (_selectedStudentIds.isEmpty) _isSelectionMode = false;
                                          });
                                        } else {
                                          HapticFeedback.selectionClick();
                                          setState(() {
                                            _desktopSelectedStudentId = student.id;
                                          });
                                        }
                                      },
                                      onLongPress: () {
                                        HapticFeedback.heavyImpact();
                                        setState(() {
                                          _isSelectionMode = true;
                                          _selectedStudentIds.add(student.id);
                                        });
                                      },
                                      child: _buildDesktopRosterCard(
                                        student: student,
                                        isFocused: isFocused,
                                        isMultiSelected: isMultiSelected,
                                        theme: theme,
                                      ),
                                    );
                                  },
                                ),
                              ),
                      ),
                    ],
                  ),
                ),

                // Vertical Divider Rail
                VerticalDivider(width: 1, thickness: 1, color: theme.dividerColor.withValues(alpha: 0.5)),

                // Right Pane: Active Student Detail Dossier or Empty State
                Expanded(
                  child: _desktopSelectedStudentId != null
                      ? StudentDetailScreen(
                          key: ValueKey(_desktopSelectedStudentId),
                          studentId: _desktopSelectedStudentId!,
                          isEmbeddedInSplitView: true,
                        )
                      : _buildDesktopEmptyWorkbench(theme),
                ),
              ],
            );
          }

          // Otherwise: Mobile (<720) or Tablet Grid (720-1023)
          return Column(
            children: [
              if (!_isSelectionMode) ...[
                _buildSearchBar(theme),
                _buildFilterChips(),
              ],
              Expanded(
                child: students.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.people_outline, size: 64, color: theme.colorScheme.outline),
                            const SizedBox(height: 16),
                            Text('No students yet', style: theme.textTheme.titleLarge),
                            const SizedBox(height: 8),
                            Text('Add your first student to get started', style: theme.textTheme.bodyMedium),
                            const SizedBox(height: 24),
                            ElevatedButton.icon(
                              onPressed: () => _navigateToAddStudent(context),
                              icon: const Icon(Icons.person_add),
                              label: const Text('Add Student'),
                            ),
                          ],
                        ),
                      )
                    : filtered.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.search_off_rounded, size: 64, color: theme.colorScheme.outline),
                                const SizedBox(height: 16),
                                Text(
                                  _selectedFilter == 'Due Soon'
                                      ? 'No students expiring in the next 14 days'
                                      : (_selectedFilter == 'Has Dues'
                                          ? 'No students with pending dues'
                                          : 'No matching students'),
                                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                                ),
                                if (_selectedFilter != 'All') ...[
                                  const SizedBox(height: 12),
                                  FilledButton.tonalIcon(
                                    onPressed: () => setState(() => _selectedFilter = 'All'),
                                    icon: const Icon(Icons.people_alt_rounded),
                                    label: const Text('Show All Students'),
                                  ),
                                ],
                                const SizedBox(height: 8),
                                Text('Try changing your search or filter', style: theme.textTheme.bodyMedium),
                              ],
                            ),
                          )
                        : constraints.maxWidth >= 720
                            ? RefreshIndicator(
                                onRefresh: () async {
                                  await ref.read(studentPageProvider.notifier).loadFirst();
                                },
                                child: GridView.builder(
                                  controller: _scrollController,
                                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 2,
                                    childAspectRatio: 2.85,
                                    crossAxisSpacing: 12,
                                    mainAxisSpacing: 8,
                                  ),
                                  itemCount: filtered.length,
                                  itemBuilder: (context, index) {
                                    final student = filtered[index];
                                    final isSelected = _selectedStudentIds.contains(student.id);

                                    return PressableScale(
                                      scaleFactor: 0.98,
                                      onTap: () {
                                        if (_isSelectionMode) {
                                          HapticFeedback.selectionClick();
                                          setState(() {
                                            isSelected
                                                ? _selectedStudentIds.remove(student.id)
                                                : _selectedStudentIds.add(student.id);
                                            if (_selectedStudentIds.isEmpty) _isSelectionMode = false;
                                          });
                                        } else {
                                          HapticFeedback.lightImpact();
                                          context.go('/admin/students/${student.id}');
                                        }
                                      },
                                      onLongPress: () {
                                        HapticFeedback.heavyImpact();
                                        setState(() {
                                          _isSelectionMode = true;
                                          _selectedStudentIds.add(student.id);
                                        });
                                      },
                                      child: _buildStudentCardContent(student, isSelected, theme),
                                    );
                                  },
                                ),
                              )
                            : RefreshIndicator(
                      onRefresh: () async {
                        await ref.read(studentPageProvider.notifier).loadFirst();
                      },
                      child: ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.only(bottom: 96),
                        itemCount: filtered.length + 1,
                        itemBuilder: (context, index) {
                          if (index == filtered.length) {
                            if (studentState.isLoading && studentState.students.isNotEmpty) {
                              return const Padding(
                                padding: EdgeInsets.symmetric(vertical: 16.0),
                                child: Center(
                                  child: SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(strokeWidth: 2.5),
                                  ),
                                ),
                              );
                            }
                            if (!studentState.hasMore) {
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 16.0),
                                child: Center(
                                  child: Text(
                                    'No more students',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: theme.colorScheme.outline,
                                    ),
                                  ),
                                ),
                              );
                            }
                            return const SizedBox.shrink();
                          }

                          final student = filtered[index];
                          final isSelected = _selectedStudentIds.contains(student.id);

                          return _isSelectionMode
                              ? PressableScale(
                                  scaleFactor: 0.98,
                                  onTap: () {
                                    HapticFeedback.selectionClick();
                                    setState(() {
                                      isSelected
                                          ? _selectedStudentIds.remove(student.id)
                                          : _selectedStudentIds.add(student.id);
                                      if (_selectedStudentIds.isEmpty) _isSelectionMode = false;
                                    });
                                  },
                                  onLongPress: () {
                                    HapticFeedback.selectionClick();
                                    setState(() {
                                      _selectedStudentIds.add(student.id);
                                    });
                                  },
                                  child: _buildStudentCardContent(student, isSelected, theme),
                                )
                              : Dismissible(
                                  key: ValueKey('student_swipe_${student.id}'),
                                  direction: DismissDirection.horizontal,
                                  dismissThresholds: const {
                                    DismissDirection.startToEnd: 0.35,
                                    DismissDirection.endToStart: 0.35,
                                  },
                                  onUpdate: (details) {
                                    if (details.reached && !_swipeThresholdReached.contains(student.id)) {
                                      _swipeThresholdReached.add(student.id);
                                      HapticFeedback.lightImpact();
                                    } else if (!details.reached && _swipeThresholdReached.contains(student.id)) {
                                      _swipeThresholdReached.remove(student.id);
                                    }
                                  },
                                  confirmDismiss: (direction) async {
                                    _swipeThresholdReached.remove(student.id);
                                    if (direction == DismissDirection.startToEnd) {
                                      HapticFeedback.mediumImpact();
                                      _showQuickContactSheet(student);
                                      return false;
                                    } else if (direction == DismissDirection.endToStart) {
                                      HapticFeedback.mediumImpact();
                                      _showFastActionsSheet(student);
                                      return false;
                                    }
                                    return false;
                                  },
                                  background: Container(
                                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(16),
                                      gradient: const LinearGradient(
                                        colors: [Color(0xFF059669), Color(0xFF10B981)],
                                      ),
                                    ),
                                    alignment: Alignment.centerLeft,
                                    padding: const EdgeInsets.only(left: 20),
                                    child: const Row(
                                      children: [
                                        Icon(Icons.phone_forwarded_rounded, color: Colors.white, size: 22),
                                        SizedBox(width: 8),
                                        Text(
                                          'Call / WhatsApp',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  secondaryBackground: Container(
                                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(16),
                                      gradient: const LinearGradient(
                                        colors: [Color(0xFF6366F1), Color(0xFF4F46E5)],
                                      ),
                                    ),
                                    alignment: Alignment.centerRight,
                                    padding: const EdgeInsets.only(right: 20),
                                    child: const Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        Text(
                                          'Quick Actions',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                          ),
                                        ),
                                        SizedBox(width: 8),
                                        Icon(Icons.bolt_rounded, color: Colors.white, size: 24),
                                      ],
                                    ),
                                  ),
                                  child: PressableScale(
                                    scaleFactor: 0.98,
                                    onTap: () {
                                      HapticFeedback.lightImpact();
                                      context.go('/admin/students/${student.id}');
                                    },
                                    onLongPress: () {
                                      HapticFeedback.heavyImpact();
                                      setState(() {
                                        _isSelectionMode = true;
                                        _selectedStudentIds.add(student.id);
                                      });
                                    },
                                    child: _buildStudentCardContent(student, isSelected, theme),
                                  ),
                                );
                        },
                      ),
                    ),
              ),
            ],
          );
        },
      ),
    floatingActionButton: !_isSelectionMode
          ? Container(
              margin: const EdgeInsets.only(bottom: 72),
              child: FloatingActionButton.extended(
                heroTag: 'student_list_add_fab',
                onPressed: () => _navigateToAddStudent(context),
                icon: const Icon(Icons.person_add_rounded),
                label: const Text('Add Student', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            )
          : null,
    );
  }

  void _navigateToAddStudent(BuildContext context) {
    context.go('/admin/students/add');
  }

  Future<void> _bulkDelete() async {
    final libraryId = ref.read(currentLibraryIdProvider);
    if (libraryId == null || _selectedStudentIds.isEmpty) return;

    final count = _selectedStudentIds.length;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete $count Students?'),
        content: Text('Are you sure you want to delete $count selected students? This will remove them from the active list.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      try {
        final repo = ref.read(studentRepositoryProvider);
        await repo.bulkDelete(libraryId, _selectedStudentIds.toList());
        setState(() {
          _isSelectionMode = false;
          _selectedStudentIds.clear();
        });
        ref.read(studentPageProvider.notifier).refresh();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Successfully deleted $count students.')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete students: $e')),
          );
        }
      }
    }
  }

  Future<void> _bulkDeactivate() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Deactivate Students'),
        content: Text('Deactivate ${_selectedStudentIds.length} selected student(s)?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Deactivate')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    
    final libraryId = ref.read(currentLibraryIdProvider) ?? '';
    final repo = ref.read(studentRepositoryProvider);
    int success = 0;
    for (final id in _selectedStudentIds) {
      try {
        await repo.deactivateStudent(libraryId, id);
        success++;
      } catch (_) {}
    }
    if (!mounted) return;
    setState(() { _isSelectionMode = false; _selectedStudentIds.clear(); });
    ref.read(studentPageProvider.notifier).refresh();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$success student(s) deactivated'), backgroundColor: Colors.orange),
    );
  }

  Future<void> _bulkExportCsv() async {
    final pageState = ref.read(studentPageProvider);
    final selected = pageState.students.where((s) => _selectedStudentIds.contains(s.id)).toList();
    if (selected.isEmpty) return;

    final buf = StringBuffer();
    buf.writeln('Name,Phone,Email,Membership ID,Plan,Status,Seat,Joined');
    for (final s in selected) {
      final seatStr = SeatHelper.formatSeatLabel(seatId: s.seatId, includePrefix: false);
      buf.writeln('"${s.name}","${s.phone}","${s.email}","${s.membershipNumber ?? ''}","${s.planId ?? ''}","${s.membershipStatus.name}","$seatStr","${s.createdAt?.toIso8601String() ?? ''}"');
    }

    try {
      final fileName = 'students_export_${DateTime.now().millisecondsSinceEpoch}.csv';
      final bytes = utf8.encode(buf.toString());
      await FileDownloadHelper.downloadFile(
        fileName: fileName,
        bytes: bytes,
        mimeType: 'text/csv',
      );
      if (mounted) {
        setState(() {
          _isSelectionMode = false;
          _selectedStudentIds.clear();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Successfully exported ${selected.length} students to $fileName')),
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Export failed: $e')));
    }
  }

  Future<void> _bulkAnnounce() async {
    final pageState = ref.read(studentPageProvider);
    final selected = pageState.students.where((s) => _selectedStudentIds.contains(s.id)).toList();
    if (selected.isEmpty) return;

    final ctrl = TextEditingController();
    await showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              const Icon(Icons.campaign_rounded, color: Color(0xFF25D366)),
              const SizedBox(width: 10),
              Text('Message ${selected.length} Students'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Send a notice or payment reminder to the selected students.',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: ctrl,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: 'e.g. Dear students, please note that...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFF25D366)),
              icon: const Icon(Icons.send_rounded, size: 16),
              label: const Text('Send via WhatsApp'),
              onPressed: () {
                final message = ctrl.text.trim();
                if (message.isNotEmpty) {
                  Navigator.pop(ctx);
                  if (selected.length == 1) {
                    final cleanPhone = selected.first.phone.replaceAll(RegExp(r'[^0-9]'), '');
                    final encoded = Uri.encodeComponent(message);
                    launchUrl(Uri.parse('https://wa.me/$cleanPhone?text=$encoded'), mode: LaunchMode.externalApplication);
                    setState(() {
                      _isSelectionMode = false;
                      _selectedStudentIds.clear();
                    });
                  } else {
                    _showWhatsAppBroadcastQueue(context, selected, message);
                  }
                }
              },
            ),
          ],
        );
      },
    );
  }

  void _showWhatsAppBroadcastQueue(BuildContext context, List<StudentModel> students, String message) {
    final sentIds = <String>{};
    final encoded = Uri.encodeComponent(message);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (sheetCtx, setSheetState) {
            return DraggableScrollableSheet(
              initialChildSize: 0.7,
              minChildSize: 0.5,
              maxChildSize: 0.92,
              expand: false,
              builder: (_, scrollCtrl) {
                return Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade400,
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
                              color: const Color(0xFF25D366).withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.campaign_rounded, color: Color(0xFF25D366), size: 22),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'WhatsApp Broadcast Queue',
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  '${sentIds.length} / ${students.length} dispatched',
                                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                ),
                              ],
                            ),
                          ),
                          IconButton.filledTonal(
                            tooltip: 'Copy Message',
                            icon: const Icon(Icons.copy_rounded, size: 18),
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: message));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Message copied to clipboard!')),
                              );
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5)),
                        ),
                        child: Text(
                          message,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12.5),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Expanded(
                        child: ListView.separated(
                          controller: scrollCtrl,
                          itemCount: students.length,
                          separatorBuilder: (_, _) => const Divider(height: 1),
                          itemBuilder: (c, idx) {
                            final s = students[idx];
                            final cleanPhone = s.phone.replaceAll(RegExp(r'[^0-9]'), '');
                            final isSent = sentIds.contains(s.id);

                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                              leading: CircleAvatar(
                                radius: 18,
                                child: Text(s.name.isNotEmpty ? s.name[0].toUpperCase() : '?'),
                              ),
                              title: Text(s.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                              subtitle: Text(
                                '${s.phone}${s.seatId != null ? ' • Seat #${SeatHelper.formatSeatLabel(seatId: s.seatId, includePrefix: false)}' : ''}',
                                style: const TextStyle(fontSize: 12),
                              ),
                              trailing: isSent
                                  ? const Chip(
                                      avatar: Icon(Icons.check_circle_rounded, color: Colors.green, size: 16),
                                      label: Text('Sent', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 11)),
                                    )
                                  : FilledButton.tonalIcon(
                                      style: FilledButton.styleFrom(
                                        visualDensity: VisualDensity.compact,
                                        backgroundColor: const Color(0xFF25D366).withValues(alpha: 0.15),
                                        foregroundColor: const Color(0xFF166534),
                                      ),
                                      icon: const Icon(Icons.send_rounded, size: 14),
                                      label: const Text('Send', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                      onPressed: () async {
                                        setSheetState(() => sentIds.add(s.id));
                                        final url = Uri.parse('https://wa.me/$cleanPhone?text=$encoded');
                                        await launchUrl(url, mode: LaunchMode.externalApplication);
                                      },
                                    ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Color _getStatusColor(MembershipStatus status) {
    switch (status) {
      case MembershipStatus.active:
        return const Color(0xFF10B981);
      case MembershipStatus.grace:
        return const Color(0xFFF59E0B);
      case MembershipStatus.expired:
        return const Color(0xFFEF4444);
      case MembershipStatus.blocked:
        return const Color(0xFF7C3AED);
      case MembershipStatus.pending:
        return const Color(0xFF0284C7);
      default:
        return const Color(0xFF64748B);
    }
  }

  void _showQuickContactSheet(StudentModel student) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundImage: ImageService.getImageProvider(student.photoUrl),
                    child: ImageService.getImageProvider(student.photoUrl) == null
                        ? Text(student.name.isNotEmpty ? student.name[0].toUpperCase() : '?')
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(student.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        Text(student.phone, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 8),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.phone_rounded, color: Colors.green),
                ),
                title: const Text('Direct Phone Call', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text('Call ${student.phone}'),
                onTap: () async {
                  Navigator.pop(ctx);
                  final uri = Uri.parse('tel:${student.phone}');
                  if (await canLaunchUrl(uri)) await launchUrl(uri);
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF25D366).withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.chat_bubble_outline_rounded, color: Color(0xFF25D366)),
                ),
                title: const Text('WhatsApp Message', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Open WhatsApp reminder / chat'),
                onTap: () async {
                  Navigator.pop(ctx);
                  if (context.mounted) {
                    await _sendWhatsAppNudge(student);
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _sendWhatsAppNudge(StudentModel student) async {
    final lib = ref.read(currentLibraryProvider).value;
    final libName = lib?.name.isNotEmpty == true ? lib!.name : 'The Cozy Corner';
    String message;
    if ((student.pendingDueBalance ?? 0) > 0) {
      message = 'Dear ${student.name},\n\nYou have a pending fee of ₹${student.pendingDueBalance!.toStringAsFixed(0)} for your study library membership at $libName. Kindly clear it at your earliest convenience.\n\nThank you,\n$libName';
    } else if (student.isExpired || student.membershipStatus == MembershipStatus.grace) {
      final expStr = student.planEndDate != null ? DateFormat('dd MMM yyyy').format(student.planEndDate!) : 'recently';
      message = 'Dear ${student.name},\n\nYour library membership expired on $expStr. Please renew your plan to continue using your study seat.\n\nThank you,\n$libName';
    } else if (student.planEndDate != null) {
      final expStr = DateFormat('dd MMM yyyy').format(student.planEndDate!);
      message = 'Dear ${student.name},\n\nThis is a friendly reminder that your library membership is expiring soon on $expStr. Please visit the reception or use the app to renew in advance.\n\nThank you,\n$libName';
    } else {
      message = 'Hello ${student.name},\n\nGreetings from $libName!\n\nBest regards,\n$libName';
    }

    await WhatsAppService().sendMessage(
      student.phone,
      message,
      recipientName: student.name,
      title: 'Message ${student.name}',
      context: context,
    );
  }

  void _showFastActionsSheet(StudentModel student) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundImage: ImageService.getImageProvider(student.photoUrl),
                    child: ImageService.getImageProvider(student.photoUrl) == null
                        ? Text(student.name.isNotEmpty ? student.name[0].toUpperCase() : '?')
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(student.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        Text('Status: ${student.membershipStatus.name.toUpperCase()}', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 8),
              ListTile(
                leading: const Icon(Icons.person_outline_rounded, color: Colors.blue),
                title: const Text('View Full Profile & Dossier'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.pop(ctx);
                  context.go('/admin/students/${student.id}');
                },
              ),
              ListTile(
                leading: const Icon(Icons.payment_rounded, color: Colors.teal),
                title: const Text('Record Payment / Collect Due'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.pop(ctx);
                  context.push('/admin/payments/record/${student.id}');
                },
              ),
              ListTile(
                leading: const Icon(Icons.badge_outlined, color: Colors.purple),
                title: const Text('View Digital Pass / ID Card'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.pop(ctx);
                  context.push('/admin/id-cards/preview/${student.id}');
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStudentCardContent(StudentModel student, bool isSelected, ThemeData theme) {
    final statusColor = _getStatusColor(student.membershipStatus);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: isSelected
            ? theme.colorScheme.primaryContainer.withValues(alpha: isDark ? 0.3 : 0.4)
            : theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected
              ? theme.colorScheme.primary
              : (isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE2E8F0)),
          width: isSelected ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 5,
                decoration: BoxDecoration(
                  color: statusColor,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(15),
                    bottomLeft: Radius.circular(15),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Row(
                    children: [
                      Hero(
                        tag: 'student-avatar-${student.id}',
                        child: Stack(
                          children: [
                            CircleAvatar(
                              radius: 22,
                              backgroundColor: theme.colorScheme.surfaceContainerHighest,
                              backgroundImage: ImageService.getImageProvider(student.photoUrl),
                              child: ImageService.getImageProvider(student.photoUrl) == null
                                  ? Text(
                                      student.name.isNotEmpty ? student.name[0].toUpperCase() : '?',
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                    )
                                  : null,
                            ),
                            Positioned(
                              right: 0,
                              bottom: 0,
                              child: Container(
                                width: 11,
                                height: 11,
                                decoration: BoxDecoration(
                                  color: statusColor,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: theme.cardColor,
                                    width: 2,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Hero(
                              tag: 'student-name-${student.id}',
                              child: Material(
                                type: MaterialType.transparency,
                                child: Text(
                                  student.name,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: -0.2,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                            const SizedBox(height: 3),
                            Wrap(
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 6,
                              runSpacing: 4,
                              children: [
                                if (student.membershipNumber != null && student.membershipNumber!.isNotEmpty)
                                  Text(
                                    '#${student.membershipNumber}',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w600,
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                Text(
                                  student.phone,
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                if (student.seatId != null && student.seatId!.isNotEmpty)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.primaryContainer.withValues(alpha: 0.6),
                                      borderRadius: BorderRadius.circular(5),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.chair_rounded, size: 11, color: theme.colorScheme.primary),
                                        const SizedBox(width: 3),
                                        Text(
                                          'Desk #${SeatHelper.formatSeatLabel(seatId: student.seatId, includePrefix: false)}',
                                          style: TextStyle(
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.bold,
                                            color: theme.colorScheme.primary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                else
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(5),
                                      border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.chair_outlined, size: 11, color: Colors.grey.shade600),
                                        const SizedBox(width: 3),
                                        Text(
                                          'No Desk',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (_isSelectionMode)
                        Icon(
                          isSelected ? Icons.check_circle_rounded : Icons.circle_outlined,
                          color: isSelected ? theme.colorScheme.primary : theme.colorScheme.outline,
                          size: 24,
                        )
                      else
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.phone_outlined, size: 18, color: Color(0xFF2563EB)),
                              tooltip: 'Call ${student.name}',
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                              onPressed: () async {
                                HapticFeedback.selectionClick();
                                final uri = Uri.parse('tel:${student.phone}');
                                if (await canLaunchUrl(uri)) await launchUrl(uri);
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18, color: Color(0xFF25D366)),
                              tooltip: 'WhatsApp ${student.name}',
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                              onPressed: () {
                                HapticFeedback.selectionClick();
                                _sendWhatsAppNudge(student);
                              },
                            ),
                            const SizedBox(width: 4),
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                if ((student.pendingDueBalance ?? 0) > 0) ...[
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.red.withValues(alpha: 0.12),
                                      border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      'Due ₹${student.pendingDueBalance!.toStringAsFixed(0)}',
                                      style: const TextStyle(
                                        color: Colors.red,
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.bold,
                                        fontFeatures: [FontFeature.tabularFigures()],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                ],
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: statusColor.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    student.membershipStatus.name.toUpperCase(),
                                    style: TextStyle(
                                      color: statusColor,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by name, phone, ID, or desk...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchQuery = '';
                            _searchResults = null;
                          });
                        },
                      )
                    : null,
                border: const OutlineInputBorder(),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              onChanged: (v) {
                setState(() => _searchQuery = v.toLowerCase().trim());
                _debounce?.cancel();
                _debounce = Timer(const Duration(milliseconds: 400), () => _runSearch(v.trim()));
              },
            ),
          ),
          const SizedBox(width: 8),
          PopupMenuButton<StudentSortOrder>(
            tooltip: 'Sort Students',
            icon: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: theme.colorScheme.outlineVariant),
              ),
              child: Icon(Icons.sort_rounded, size: 20, color: theme.colorScheme.primary),
            ),
            onSelected: (order) => setState(() => _selectedSortOrder = order),
            itemBuilder: (ctx) => [
              PopupMenuItem(
                value: StudentSortOrder.recent,
                child: Row(
                  children: [
                    Icon(Icons.history_rounded, size: 18, color: _selectedSortOrder == StudentSortOrder.recent ? theme.colorScheme.primary : null),
                    const SizedBox(width: 8),
                    const Text('Recent Admissions First'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: StudentSortOrder.seatNumber,
                child: Row(
                  children: [
                    Icon(Icons.chair_rounded, size: 18, color: _selectedSortOrder == StudentSortOrder.seatNumber ? theme.colorScheme.primary : null),
                    const SizedBox(width: 8),
                    const Text('Desk Number (1 → 100)'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: StudentSortOrder.nameAsc,
                child: Row(
                  children: [
                    Icon(Icons.sort_by_alpha_rounded, size: 18, color: _selectedSortOrder == StudentSortOrder.nameAsc ? theme.colorScheme.primary : null),
                    const SizedBox(width: 8),
                    const Text('Name (A → Z)'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: StudentSortOrder.expirySoon,
                child: Row(
                  children: [
                    Icon(Icons.event_busy_rounded, size: 18, color: _selectedSortOrder == StudentSortOrder.expirySoon ? theme.colorScheme.primary : null),
                    const SizedBox(width: 8),
                    const Text('Expiring Soonest First'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: StudentSortOrder.highestDue,
                child: Row(
                  children: [
                    Icon(Icons.money_off_rounded, size: 18, color: _selectedSortOrder == StudentSortOrder.highestDue ? theme.colorScheme.primary : null),
                    const SizedBox(width: 8),
                    const Text('Highest Dues / Defaulters'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
      child: Row(
        children: _filters.map((f) => Padding(
          padding: const EdgeInsets.only(right: 8.0),
          child: ChoiceChip(
            label: Text(f),
            selected: _selectedFilter == f,
            onSelected: (s) {
              if (s) setState(() => _selectedFilter = f);
            },
          ),
        )).toList(),
      ),
    );
  }

  String _getSortLabel(StudentSortOrder order) {
    switch (order) {
      case StudentSortOrder.recent:
        return 'Recent';
      case StudentSortOrder.seatNumber:
        return 'Desk #';
      case StudentSortOrder.nameAsc:
        return 'Name';
      case StudentSortOrder.expirySoon:
        return 'Expiring';
      case StudentSortOrder.highestDue:
        return 'Dues';
    }
  }

  Widget _buildDesktopRosterCard({
    required StudentModel student,
    required bool isFocused,
    required bool isMultiSelected,
    required ThemeData theme,
  }) {
    final statusColor = _getStatusColor(student.membershipStatus);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 3.5),
      decoration: BoxDecoration(
        color: isFocused
            ? theme.colorScheme.primaryContainer.withValues(alpha: isDark ? 0.35 : 0.45)
            : (isMultiSelected
                ? theme.colorScheme.secondaryContainer.withValues(alpha: 0.3)
                : theme.cardColor),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isFocused
              ? theme.colorScheme.primary
              : (isMultiSelected
                  ? theme.colorScheme.secondary
                  : (isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE2E8F0))),
          width: isFocused ? 1.8 : 1.0,
        ),
        boxShadow: isFocused
            ? [
                BoxShadow(
                  color: theme.colorScheme.primary.withValues(alpha: isDark ? 0.25 : 0.12),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(11),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 4,
                decoration: BoxDecoration(
                  color: statusColor,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(11),
                    bottomLeft: Radius.circular(11),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  child: Row(
                    children: [
                      Stack(
                        children: [
                          CircleAvatar(
                            radius: 18,
                            backgroundColor: theme.colorScheme.surfaceContainerHighest,
                            backgroundImage: ImageService.getImageProvider(student.photoUrl),
                            child: ImageService.getImageProvider(student.photoUrl) == null
                                ? Text(
                                    student.name.isNotEmpty ? student.name[0].toUpperCase() : '?',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                  )
                                : null,
                          ),
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: Container(
                              width: 9,
                              height: 9,
                              decoration: BoxDecoration(
                                color: statusColor,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: theme.cardColor,
                                  width: 1.5,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              student.name,
                              style: TextStyle(
                                fontWeight: isFocused ? FontWeight.w800 : FontWeight.w700,
                                fontSize: 13,
                                color: isFocused ? theme.colorScheme.primary : null,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                if (student.seatId != null && student.seatId!.isNotEmpty) ...[
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.primaryContainer.withValues(alpha: 0.6),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      'Desk #${SeatHelper.formatSeatLabel(seatId: student.seatId, includePrefix: false)}',
                                      style: TextStyle(
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.bold,
                                        color: theme.colorScheme.primary,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 5),
                                ],
                                Text(
                                  student.phone,
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      if (_isSelectionMode)
                        Icon(
                          isMultiSelected ? Icons.check_circle_rounded : Icons.circle_outlined,
                          color: isMultiSelected ? theme.colorScheme.primary : theme.colorScheme.outline,
                          size: 20,
                        )
                      else ...[
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            if ((student.pendingDueBalance ?? 0) > 0) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: Colors.red.withValues(alpha: 0.12),
                                  border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'Due ₹${student.pendingDueBalance!.toStringAsFixed(0)}',
                                  style: const TextStyle(
                                    color: Colors.red,
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 2),
                            ],
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: statusColor.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                student.membershipStatus.name.toUpperCase(),
                                style: TextStyle(
                                  color: statusColor,
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (isFocused) ...[
                          const SizedBox(width: 4),
                          Icon(Icons.chevron_right_rounded, size: 16, color: theme.colorScheme.primary),
                        ],
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopEmptyWorkbench(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.space_dashboard_rounded, size: 56, color: theme.colorScheme.primary),
          ),
          const SizedBox(height: 20),
          Text(
            'Reception Student Workbench',
            style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: 360,
            child: Text(
              'Select any scholar on the left roster to view their live dossier, collect dues, allocate desks, or issue digital passes.',
              textAlign: TextAlign.center,
              style: TextStyle(color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7), fontSize: 13.5, height: 1.4),
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () => _navigateToAddStudent(context),
            icon: const Icon(Icons.person_add_rounded, size: 18),
            label: const Text('Add New Student'),
          ),
        ],
      ),
    );
  }
}

/// Quick add student form — inline for now
class _AddStudentQuickForm extends ConsumerStatefulWidget {
  final String libraryId;
  const _AddStudentQuickForm({required this.libraryId});

  @override
  ConsumerState<_AddStudentQuickForm> createState() => _AddStudentQuickFormState();
}

class _AddStudentQuickFormState extends ConsumerState<_AddStudentQuickForm> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _addressController = TextEditingController();
  String _gender = 'male';
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _saveStudent() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final repo = ref.read(studentRepositoryProvider);
      await repo.addStudent(
        libraryId: widget.libraryId,
        name: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
        email: _emailController.text.trim(),
        address: _addressController.text.trim(),
        gender: _gender,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Student added successfully!')),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString().replaceAll("Exception: ", "")}')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Student')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Full Name *',
                        prefixIcon: Icon(Icons.person),
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Name is required' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _phoneController,
                      decoration: const InputDecoration(
                        labelText: 'Phone Number *',
                        prefixIcon: Icon(Icons.phone),
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.phone,
                      validator: (v) => (v == null || v.trim().length < 10) ? 'Valid phone required' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _emailController,
                      decoration: const InputDecoration(
                        labelText: 'Email (Optional)',
                        prefixIcon: Icon(Icons.email),
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _addressController,
                      decoration: const InputDecoration(
                        labelText: 'Address (Optional)',
                        prefixIcon: Icon(Icons.location_on),
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: _gender,
                      decoration: const InputDecoration(
                        labelText: 'Gender',
                        prefixIcon: Icon(Icons.people),
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'male', child: Text('Male')),
                        DropdownMenuItem(value: 'female', child: Text('Female')),
                        DropdownMenuItem(value: 'other', child: Text('Other')),
                      ],
                      onChanged: (v) => setState(() => _gender = v ?? 'male'),
                    ),
                    const SizedBox(height: 32),
                    FilledButton.icon(
                      onPressed: _saveStudent,
                      icon: const Icon(Icons.save),
                      label: const Text('Save Student'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
