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
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:study_library/core/widgets/loading_skeleton.dart';
import 'package:study_library/core/utils/seat_helper.dart';

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
  Set<String> _selectedStudentIds = {};
  final Set<String> _swipeThresholdReached = {};
  bool _isSelectionMode = false;
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
    return all.where((s) {
      final q = _searchQuery;
      return s.name.toLowerCase().contains(q) ||
          s.phone.contains(q) ||
          (s.membershipNumber?.toLowerCase().contains(q) ?? false) ||
          s.email.toLowerCase().contains(q);
    }).toList();
  }

  Future<void> _runSearch(String query) async {
    if (query.isEmpty) {
      setState(() { _searchResults = null; _isSearching = false; });
      return;
    }
    setState(() => _isSearching = true);
    final libraryId = ref.read(currentLibraryIdProvider) ?? '';
    if (libraryId.isEmpty) return;
    
    try {
      final snap = await FirebaseFirestore.instance
          .collection('libraries').doc(libraryId)
          .collection('students')
          .orderBy('name')
          .startAt([query])
          .endAt(['$query\uf8ff'])
          .limit(20)
          .get();
      final results = snap.docs.map((d) => StudentModel.fromJson({...d.data(), 'id': d.id})).toList();
      
      final snap2 = await FirebaseFirestore.instance
          .collection('libraries').doc(libraryId)
          .collection('students')
          .where('membershipNumber', isGreaterThanOrEqualTo: query.toUpperCase())
          .where('membershipNumber', isLessThanOrEqualTo: '${query.toUpperCase()}\uf8ff')
          .limit(5)
          .get();
      final results2 = snap2.docs.map((d) => StudentModel.fromJson({...d.data(), 'id': d.id})).toList();
      
      final snap3 = await FirebaseFirestore.instance
          .collection('libraries').doc(libraryId)
          .collection('students')
          .where('phone', isGreaterThanOrEqualTo: query)
          .where('phone', isLessThanOrEqualTo: '$query\uf8ff')
          .limit(5)
          .get();
      final results3 = snap3.docs.map((d) => StudentModel.fromJson({...d.data(), 'id': d.id})).toList();
      
      final seen = <String>{};
      final merged = [...results, ...results2, ...results3].where((s) => seen.add(s.id)).toList();
      if (mounted) {
        setState(() { _searchResults = merged; _isSearching = false; });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isSearching = false);
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
      body: Column(
        children: [
          if (!_isSelectionMode)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search by name, phone or ID...',
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
          if (!_isSelectionMode)
            SingleChildScrollView(
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
            ),
          Expanded(
            child: Builder(
              builder: (context) {
                // Prefer full real-time stream for accurate filtering across all students; fallback to paginated
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

                if (students.isEmpty) {
                  return Center(
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
                  );
                }

                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search_off_rounded, size: 64, color: theme.colorScheme.outline),
                        const SizedBox(height: 16),
                        Text(_selectedFilter == 'Due Soon' ? 'No students expiring in the next 14 days' : (_selectedFilter == 'Has Dues' ? 'No students with pending dues' : 'No matching students'), style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
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
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async {
                    await ref.read(studentPageProvider.notifier).loadFirst();
                  },
                  child: ListView.builder(
                    controller: _scrollController,
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
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: !_isSelectionMode ? FloatingActionButton(
        onPressed: () => _navigateToAddStudent(context),
        child: const Icon(Icons.person_add),
      ) : null,
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
    
    final buf = StringBuffer();
    buf.writeln('Name,Phone,Email,Membership ID,Plan,Status,Seat,Joined');
    for (final s in selected) {
      buf.writeln('"${s.name}","${s.phone}","${s.email}","${s.membershipNumber ?? ''}","${s.planId ?? ''}","${s.membershipStatus.name}","${s.seatId ?? ''}","${s.createdAt?.toIso8601String() ?? ''}"');
    }
    
    try {
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/students_export_${DateTime.now().millisecondsSinceEpoch}.csv');
      await file.writeAsString(buf.toString());
      await SharePlus.instance.share(ShareParams(files: [XFile(file.path)], text: 'Students Export'));
      if (mounted) setState(() { _isSelectionMode = false; _selectedStudentIds.clear(); });
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Export failed: $e')));
    }
  }

  Future<void> _bulkAnnounce() async {
    String? message;
    await showDialog(
      context: context,
      builder: (ctx) {
        final ctrl = TextEditingController();
        return AlertDialog(
          title: Text('Announce to ${_selectedStudentIds.length} students'),
          content: TextFormField(
            controller: ctrl,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: 'Enter your message...',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                message = ctrl.text.trim();
                Navigator.pop(ctx);
              },
              child: const Text('Send via WhatsApp'),
            ),
          ],
        );
      },
    );
    
    if (message == null || message!.isEmpty) return;
    
    final pageState = ref.read(studentPageProvider);
    final selected = pageState.students.where((s) => _selectedStudentIds.contains(s.id)).toList();
    
    if (!mounted) return;
    final phones = selected.where((s) => s.phone.isNotEmpty).map((s) => s.phone).toList();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Message prepared for ${phones.length} students. Opening WhatsApp...'),
        duration: const Duration(seconds: 3),
      ),
    );
    
    if (phones.isNotEmpty) {
      final encoded = Uri.encodeComponent(message!);
      final url = Uri.parse('https://wa.me/${phones.first.replaceAll(RegExp(r'[^0-9]'), '')}?text=$encoded');
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
    
    setState(() { _isSelectionMode = false; _selectedStudentIds.clear(); });
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
                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.primaryContainer.withValues(alpha: 0.5),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.chair_outlined, size: 10, color: theme.colorScheme.primary),
                                        const SizedBox(width: 2),
                                        Text(
                                          SeatHelper.formatSeatLabel(seatId: student.seatId, includePrefix: false),
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: theme.colorScheme.primary,
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
                            if ((student.pendingDueBalance ?? 0) > 0 ||
                                student.membershipStatus == MembershipStatus.grace ||
                                student.isExpired ||
                                _selectedFilter == 'Due Soon') ...[
                              IconButton(
                                icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18, color: Color(0xFF25D366)),
                                tooltip: 'WhatsApp Reminder',
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                onPressed: () {
                                  HapticFeedback.selectionClick();
                                  _sendWhatsAppNudge(student);
                                },
                              ),
                              const SizedBox(width: 4),
                            ],
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
