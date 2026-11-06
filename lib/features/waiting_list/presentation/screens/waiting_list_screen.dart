import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:study_library/core/constants/firestore_paths.dart';
import 'package:study_library/core/providers/library_provider.dart';
import 'package:study_library/core/router/app_router.dart';
import 'package:study_library/models/library_model.dart';
import 'package:study_library/models/waiting_list_model.dart';
import 'package:study_library/models/seat_model.dart';
import 'package:study_library/models/section_model.dart';
import 'package:study_library/features/waiting_list/data/repositories/waiting_list_repository.dart';
import 'package:study_library/features/seats/presentation/providers/seat_providers.dart';
import 'package:study_library/core/utils/error_formatter.dart';
import 'package:study_library/core/utils/seat_helper.dart';
import 'package:study_library/services/whatsapp_service.dart';

class WaitingListScreen extends ConsumerStatefulWidget {
  final int initialTab;

  const WaitingListScreen({
    super.key,
    this.initialTab = 0,
  });

  @override
  ConsumerState<WaitingListScreen> createState() => _WaitingListScreenState();
}

class _WaitingListScreenState extends ConsumerState<WaitingListScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _queueFilter = 'all'; // 'all', 'ready', 'notified'
  String? _selectedSectionFilter;

  // Policy Tab Form State
  String _policyMode = 'waitingList';
  int _holdingHours = 24;
  bool _autoNotify = true;
  final TextEditingController _notificationTemplateController = TextEditingController();
  bool _isSavingPolicy = false;
  bool _policyInitialized = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTab.clamp(0, 1),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _notificationTemplateController.dispose();
    super.dispose();
  }

  void _initPolicyFromLibrary(LibraryModel? library) {
    if (_policyInitialized || library == null) return;
    _policyMode = library.waitingListMode.name;
    _holdingHours = library.waitingListHoldingHours;
    _autoNotify = library.waitingListAutoNotify;
    _notificationTemplateController.text = library.waitingListNotificationTemplate.isNotEmpty
        ? library.waitingListNotificationTemplate
        : 'Hello {studentName}, exciting news! Seat {seatLabel} has just become available for you at {libraryName}. Your position on the waiting list has arrived! Please visit or contact us to confirm your admission.';
    _policyInitialized = true;
  }

  Future<void> _savePolicySettings() async {
    final libraryId = ref.read(currentLibraryIdProvider);
    if (libraryId == null || libraryId.isEmpty) return;

    setState(() => _isSavingPolicy = true);

    try {
      await FirebaseFirestore.instance.collection('libraries').doc(libraryId).update({
        'waitingListMode': _policyMode,
        'waitingListHoldingHours': _holdingHours,
        'waitingListAutoNotify': _autoNotify,
        'waitingListNotificationTemplate': _notificationTemplateController.text.trim(),
        'updatedAt': DateTime.now().toIso8601String(),
      });

      ref.invalidate(currentLibraryProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Expanded(child: Text('Capacity policies saved successfully!')),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save policies: $e'),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSavingPolicy = false);
    }
  }

  void _showAddDialog(List<SectionModel> sections) {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    String? selectedSectionId;
    String genderPref = 'none';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.person_add_rounded, color: Colors.brown),
              SizedBox(width: 8),
              Text('Add to Waiting List'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Student Name *',
                    prefixIcon: Icon(Icons.person),
                  ),
                  autofocus: true,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Phone Number *',
                    prefixIcon: Icon(Icons.phone),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String?>(
                  initialValue: selectedSectionId,
                  decoration: const InputDecoration(
                    labelText: 'Preferred Section',
                    prefixIcon: Icon(Icons.meeting_room),
                  ),
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('Any Section'),
                    ),
                    ...sections.map(
                      (s) => DropdownMenuItem(
                        value: s.id,
                        child: Text(s.name),
                      ),
                    ),
                  ],
                  onChanged: (val) => setDialogState(() => selectedSectionId = val),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: genderPref,
                  decoration: const InputDecoration(
                    labelText: 'Gender Preference',
                    prefixIcon: Icon(Icons.wc),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'none', child: Text('No Preference')),
                    DropdownMenuItem(value: 'male', child: Text('Male')),
                    DropdownMenuItem(value: 'female', child: Text('Female')),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setDialogState(() => genderPref = val);
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                final name = nameController.text.trim();
                final phone = phoneController.text.trim();
                if (name.isEmpty || phone.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Name and phone are required')),
                  );
                  return;
                }

                final libraryId = ref.read(currentLibraryIdProvider);
                if (libraryId == null) return;

                Navigator.pop(ctx);
                final entry = WaitingListEntry(
                  id: '',
                  libraryId: libraryId,
                  studentId: '',
                  studentName: name,
                  studentPhone: phone,
                  preferredSectionId: selectedSectionId,
                  genderPreference: genderPref,
                  position: 0,
                  createdAt: DateTime.now(),
                );

                await ref.read(waitingListRepositoryProvider).addToWaitingList(
                      libraryId,
                      entry,
                    );

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('$name added to waiting list'),
                      backgroundColor: Colors.green,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              },
              child: const Text('Add Candidate'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAssignSeatSheet(WaitingListEntry entry) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _WaitingListSeatAssignSheet(
        entry: entry,
        onSeatAssigned: () {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  '${entry.studentName} has been assigned a seat and removed from the queue.',
                ),
                backgroundColor: Colors.green,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        },
      ),
    );
  }

  Future<void> _callPhone(String phone) async {
    final clean = phone.replaceAll(RegExp(r'\D'), '');
    if (clean.isEmpty) return;
    final uri = Uri.parse('tel:$clean');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  Future<void> _notifyViaWhatsApp(WaitingListEntry entry) async {
    final libraryId = ref.read(currentLibraryIdProvider);
    final library = ref.read(currentLibraryProvider).value;
    final libraryName = library?.name.isNotEmpty == true ? library!.name : 'Study Library';
    final seatLabel = entry.suggestedSeatLabel ?? 'Available Desk';
    final adminTemplate = library?.waitingListNotificationTemplate;

    final sent = await ref.read(whatsappServiceProvider).sendWaitingListPromotion(
      phone: entry.studentPhone,
      studentName: entry.studentName,
      libraryName: libraryName,
      seatLabel: seatLabel,
      sectionName: entry.preferredSectionId ?? 'Main Hall',
      planName: null,
      libraryHelpline: library?.phone,
      libraryAddress: library?.address,
      adminTemplate: adminTemplate,
      context: context,
    );

    if (sent && libraryId != null) {
      await ref.read(waitingListRepositoryProvider).notifyEntry(libraryId, entry.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Notified ${entry.studentName} via WhatsApp ✓'),
            backgroundColor: Colors.green.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _registerStudent(WaitingListEntry entry) {
    context.push(
      Routes.adminStudentAdd,
      extra: {
        'name': entry.studentName,
        'phone': entry.studentPhone,
        'sectionId': entry.preferredSectionId,
        'gender': entry.genderPreference,
      },
    );
  }

  Future<void> _removeEntry(WaitingListEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove from Queue'),
        content: Text('Remove ${entry.studentName} from the waiting list?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    final libraryId = ref.read(currentLibraryIdProvider);
    if (libraryId == null) return;

    await ref
        .read(waitingListRepositoryProvider)
        .removeFromWaitingList(libraryId, entry.id);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${entry.studentName} removed from queue'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final waitingListAsync = ref.watch(waitingListStreamProvider);
    final sectionsAsync = ref.watch(sectionsProvider);
    final sections = sectionsAsync.value ?? [];
    final libraryAsync = ref.watch(currentLibraryProvider);
    final library = libraryAsync.value;
    final libraryName = library?.name.isNotEmpty == true ? library!.name : 'the study center';

    _initPolicyFromLibrary(library);

    final entries = waitingListAsync.value ?? [];
    final readyCount = entries.where((e) => e.suggestedSeatId != null).length;
    final notifiedCount = entries.where((e) => e.notifiedAt != null).length;

    // Filter queue entries
    List<WaitingListEntry> filteredEntries = entries;
    if (_queueFilter == 'ready') {
      filteredEntries = filteredEntries.where((e) => e.suggestedSeatId != null).toList();
    } else if (_queueFilter == 'notified') {
      filteredEntries = filteredEntries.where((e) => e.notifiedAt != null).toList();
    }
    if (_selectedSectionFilter != null) {
      filteredEntries = filteredEntries.where((e) => e.preferredSectionId == _selectedSectionFilter).toList();
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back',
          onPressed: () => context.canPop() ? context.pop() : context.go(Routes.adminHome),
        ),
        title: const Text('Waiting List & Capacity Hub'),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(
              icon: const Icon(Icons.queue_play_next_rounded),
              text: 'Active Queue (${entries.length})',
            ),
            const Tab(
              icon: Icon(Icons.tune_rounded),
              text: 'Capacity Policies & Rules',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // ── TAB 1: ACTIVE LIVE QUEUE ──
          Column(
            children: [
              // Top Metric Strip
              _buildTopMetricsStrip(
                totalCount: entries.length,
                readyCount: readyCount,
                library: library,
              ),

              // Filter Chips Strip
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    FilterChip(
                      selected: _queueFilter == 'all' && _selectedSectionFilter == null,
                      label: Text('All (${entries.length})'),
                      onSelected: (_) {
                        setState(() {
                          _queueFilter = 'all';
                          _selectedSectionFilter = null;
                        });
                      },
                    ),
                    const SizedBox(width: 8),
                    FilterChip(
                      selected: _queueFilter == 'ready',
                      label: Text('Seat Ready ($readyCount)'),
                      avatar: const Icon(Icons.event_seat_rounded, size: 14, color: Colors.amber),
                      onSelected: (_) {
                        setState(() {
                          _queueFilter = _queueFilter == 'ready' ? 'all' : 'ready';
                        });
                      },
                    ),
                    const SizedBox(width: 8),
                    FilterChip(
                      selected: _queueFilter == 'notified',
                      label: Text('Notified ($notifiedCount)'),
                      avatar: const Icon(Icons.check_circle_rounded, size: 14, color: Colors.green),
                      onSelected: (_) {
                        setState(() {
                          _queueFilter = _queueFilter == 'notified' ? 'all' : 'notified';
                        });
                      },
                    ),
                    if (sections.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      ...sections.map((sec) => Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: FilterChip(
                              selected: _selectedSectionFilter == sec.id,
                              label: Text(sec.name),
                              onSelected: (val) {
                                setState(() {
                                  _selectedSectionFilter = val ? sec.id : null;
                                });
                              },
                            ),
                          )),
                    ],
                  ],
                ),
              ),

              const Divider(height: 1),

              // Candidate Cards List
              Expanded(
                child: waitingListAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (err, _) => Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Text(
                        AppErrorFormatter.toUserFriendly(err, actionContext: 'request'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ),
                  ),
                  data: (_) {
                    if (filteredEntries.isEmpty) {
                      return RefreshIndicator(
                        onRefresh: () async {
                          ref.invalidate(waitingListStreamProvider);
                          await Future.delayed(const Duration(milliseconds: 500));
                        },
                        child: ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(32.0),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.queue_outlined,
                                    size: 64,
                                    color: Colors.grey.shade400,
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    _queueFilter != 'all' || _selectedSectionFilter != null
                                        ? 'No Candidates Match Filter'
                                        : 'Waiting List is Empty',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'When library seats reach capacity, candidates will automatically queue here or you can add them manually.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                                  ),
                                  const SizedBox(height: 20),
                                  FilledButton.icon(
                                    onPressed: () => _showAddDialog(sections),
                                    icon: const Icon(Icons.person_add),
                                    label: const Text('Add Candidate to Queue'),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    return RefreshIndicator(
                      onRefresh: () async {
                        ref.invalidate(waitingListStreamProvider);
                        await Future.delayed(const Duration(milliseconds: 500));
                      },
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
                        itemCount: filteredEntries.length,
                        itemBuilder: (ctx, index) {
                          final entry = filteredEntries[index];
                          final preferredSection = sections
                              .where((s) => s.id == entry.preferredSectionId)
                              .firstOrNull;

                          final hasPromotedSeat = entry.suggestedSeatLabel != null &&
                              entry.suggestedSeatLabel!.isNotEmpty;

                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                              side: hasPromotedSeat
                                  ? BorderSide(color: Colors.amber.shade600, width: 1.5)
                                  : BorderSide.none,
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(14.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      CircleAvatar(
                                        radius: 18,
                                        backgroundColor: hasPromotedSeat
                                            ? Colors.amber.shade100
                                            : Theme.of(context).primaryColor.withValues(alpha: 0.15),
                                        child: Text(
                                          '#${index + 1}',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                            color: hasPromotedSeat
                                                ? Colors.amber.shade900
                                                : Theme.of(context).primaryColor,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              entry.studentName,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 15,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            InkWell(
                                              onTap: () => _callPhone(entry.studentPhone),
                                              borderRadius: BorderRadius.circular(4),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  const Icon(
                                                    Icons.phone,
                                                    size: 13,
                                                    color: Colors.green,
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    entry.studentPhone,
                                                    style: TextStyle(
                                                      color: Colors.grey.shade700,
                                                      fontSize: 12.5,
                                                      fontWeight: FontWeight.w500,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.delete_outline_rounded,
                                          color: Colors.red,
                                          size: 20,
                                        ),
                                        tooltip: 'Remove',
                                        onPressed: () => _removeEntry(entry),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 4,
                                    children: [
                                      if (hasPromotedSeat)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: Colors.amber.shade50,
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(color: Colors.amber.shade400),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.event_seat_rounded, size: 13, color: Colors.amber.shade900),
                                              const SizedBox(width: 4),
                                              Text(
                                                'SEAT READY: ${entry.suggestedSeatLabel}',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.amber.shade900,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      if (preferredSection != null)
                                        Chip(
                                          avatar: const Icon(Icons.meeting_room, size: 13),
                                          label: Text('Pref: ${preferredSection.name}', style: const TextStyle(fontSize: 11)),
                                          visualDensity: VisualDensity.compact,
                                        ),
                                      if (entry.genderPreference != 'none')
                                        Chip(
                                          avatar: const Icon(Icons.wc, size: 13),
                                          label: Text(entry.genderPreference.toUpperCase(), style: const TextStyle(fontSize: 11)),
                                          visualDensity: VisualDensity.compact,
                                        ),
                                      if (entry.notifiedAt != null)
                                        Chip(
                                          backgroundColor: Colors.green.shade50,
                                          avatar: const Icon(Icons.check_circle_rounded, size: 13, color: Colors.green),
                                          label: Text(
                                            'Notified ${DateFormat('hh:mm a').format(entry.notifiedAt!)}',
                                            style: TextStyle(fontSize: 11, color: Colors.green.shade800, fontWeight: FontWeight.bold),
                                          ),
                                          visualDensity: VisualDensity.compact,
                                        ),
                                      if (entry.createdAt != null &&
                                          DateTime.now().difference(entry.createdAt!).inDays >= 30)
                                        Chip(
                                          backgroundColor: Colors.orange.shade50,
                                          avatar: const Icon(Icons.hourglass_bottom_rounded, size: 13, color: Colors.orange),
                                          label: Text(
                                            'Stale (${DateTime.now().difference(entry.createdAt!).inDays}d in queue)',
                                            style: TextStyle(fontSize: 11, color: Colors.orange.shade900, fontWeight: FontWeight.bold),
                                          ),
                                          visualDensity: VisualDensity.compact,
                                        ),
                                      if (entry.createdAt != null)
                                        Chip(
                                          avatar: const Icon(Icons.access_time, size: 13),
                                          label: Text(
                                            DateFormat('dd MMM, hh:mm a').format(entry.createdAt!),
                                            style: const TextStyle(fontSize: 11),
                                          ),
                                          visualDensity: VisualDensity.compact,
                                        ),
                                    ],
                                  ),
                                  const Divider(height: 20),
                                  Row(
                                    children: [
                                      IconButton.filledTonal(
                                        icon: const Icon(Icons.chat_bubble_rounded, color: Color(0xFF25D366), size: 18),
                                        tooltip: 'Notify via WhatsApp',
                                        onPressed: () => _notifyViaWhatsApp(entry),
                                      ),
                                      const SizedBox(width: 4),
                                      IconButton.filledTonal(
                                        icon: const Icon(Icons.phone, color: Colors.green, size: 18),
                                        tooltip: 'Call Phone',
                                        onPressed: () => _callPhone(entry.studentPhone),
                                      ),
                                      const Spacer(),
                                      OutlinedButton.icon(
                                        onPressed: () => _registerStudent(entry),
                                        icon: const Icon(Icons.person_add_outlined, size: 15),
                                        label: const Text('Register', style: TextStyle(fontSize: 12)),
                                        style: OutlinedButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                                          visualDensity: VisualDensity.compact,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      FilledButton.icon(
                                        onPressed: () => _showAssignSeatSheet(entry),
                                        icon: const Icon(Icons.chair_alt, size: 15),
                                        label: Text(
                                          hasPromotedSeat ? 'Assign ${entry.suggestedSeatLabel}' : 'Assign Seat',
                                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                        ),
                                        style: FilledButton.styleFrom(
                                          backgroundColor: hasPromotedSeat ? Colors.amber.shade800 : null,
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                                          visualDensity: VisualDensity.compact,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
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

          // ── TAB 2: CAPACITY POLICIES & AUTOMATION RULES ──
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 820),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Full Capacity Allocation Policy',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Text(
                  'Define what action the system takes when all study desks in $libraryName are 100% occupied.',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 16),

                // Capacity Action Mode Radios
                RadioGroup<String>(
                  groupValue: _policyMode,
                  onChanged: (v) {
                    if (v != null) setState(() => _policyMode = v);
                  },
                  child: Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    child: Column(
                      children: [
                        RadioListTile<String>(
                          title: const Text('Enable Digital Waiting List (Recommended)', style: TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: const Text('Students can join a queue and are automatically notified when a desk becomes free.'),
                          value: 'waitingList',
                        ),
                        const Divider(height: 1),
                        RadioListTile<String>(
                          title: const Text('Show "Library Full" Notice', style: TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: const Text('Students see a standard library full message without joining a queue.'),
                          value: 'noSeatsMessage',
                        ),
                        const Divider(height: 1),
                        RadioListTile<String>(
                          title: const Text('Prompt Contact Administrator', style: TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: const Text('Students are prompted to message or call library management directly on WhatsApp.'),
                          value: 'contactAdmin',
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),
                const Text(
                  'Seat Reservation Holding Window',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Text(
                  'How long a freed seat is held exclusively for the notified candidate before passing to candidate #2.',
                  style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 10),
                SegmentedButton<int>(
                  segments: const [
                    ButtonSegment(value: 12, label: Text('12 Hours')),
                    ButtonSegment(value: 24, label: Text('24 Hours (Std)')),
                    ButtonSegment(value: 48, label: Text('48 Hours')),
                  ],
                  selected: {_holdingHours},
                  onSelectionChanged: (set) => setState(() => _holdingHours = set.first),
                ),

                const SizedBox(height: 24),
                const Text(
                  'Auto-Promotion & Vacancy Cascade',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: SwitchListTile(
                    title: const Text('Auto-Cascade Vacant Desks', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    subtitle: const Text(
                      'When expired plans are swept nightly, automatically tag the next matching waitlist candidate with suggested seat details.',
                      style: TextStyle(fontSize: 12),
                    ),
                    value: _autoNotify,
                    onChanged: (val) => setState(() => _autoNotify = val),
                  ),
                ),

                const SizedBox(height: 24),
                const Text(
                  'WhatsApp Notification Message Template',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Text(
                  'Variables available: {studentName}, {seatLabel}, {libraryName}',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontStyle: FontStyle.italic),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _notificationTemplateController,
                  maxLines: 4,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    hintText: 'Enter custom WhatsApp message...',
                  ),
                ),

                const SizedBox(height: 24),
                const Text('Student View Preview:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                Card(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Center(
                      child: Text(
                        _policyMode == 'waitingList'
                            ? '🏛️ $libraryName is currently at 100% capacity.\nJoin the Waiting List (#4 in line) to reserve your priority desk!'
                            : _policyMode == 'noSeatsMessage'
                                ? '⚠️ All study desks are currently occupied. Please check back later.'
                                : '💬 All desks are occupied. Please contact library management directly on WhatsApp for priority admission.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(height: 1.4, fontSize: 13),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _isSavingPolicy ? null : _savePolicySettings,
                    icon: _isSavingPolicy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.save_rounded),
                    label: Text(_isSavingPolicy ? 'Saving Policies...' : 'Save Capacity Policies'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
        ],
      ),
      floatingActionButton: _tabController.index == 0
          ? FloatingActionButton.extended(
              onPressed: () => _showAddDialog(sections),
              icon: const Icon(Icons.person_add_rounded),
              label: const Text('Add Candidate'),
            )
          : null,
    );
  }

  Widget _buildTopMetricsStrip({
    required int totalCount,
    required int readyCount,
    required LibraryModel? library,
  }) {
    final policyName = library?.waitingListMode == WaitingListMode.waitingList
        ? 'Auto-Queue Active'
        : (library?.waitingListMode == WaitingListMode.noSeatsMessage ? 'Full Notice Only' : 'Direct Inquiry');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.4),
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildMetricItem(
            label: 'IN QUEUE',
            value: '$totalCount',
            color: Colors.amber.shade700,
          ),
          _buildMetricItem(
            label: 'SEAT READY',
            value: '$readyCount',
            color: Colors.green.shade700,
          ),
          _buildMetricItem(
            label: 'POLICY',
            value: policyName,
            color: Theme.of(context).colorScheme.primary,
            isSmall: true,
          ),
        ],
      ),
    );
  }

  Widget _buildMetricItem({
    required String label,
    required String value,
    required Color color,
    bool isSmall = false,
  }) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 9.5,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.8,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: isSmall ? 12 : 18,
            fontWeight: FontWeight.w900,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _WaitingListSeatAssignSheet extends ConsumerStatefulWidget {
  final WaitingListEntry entry;
  final VoidCallback onSeatAssigned;

  const _WaitingListSeatAssignSheet({
    required this.entry,
    required this.onSeatAssigned,
  });

  @override
  ConsumerState<_WaitingListSeatAssignSheet> createState() =>
      _WaitingListSeatAssignSheetState();
}

class _WaitingListSeatAssignSheetState
    extends ConsumerState<_WaitingListSeatAssignSheet> {
  bool _isSaving = false;

  Future<void> _assignSeat(SeatModel seat, SectionModel section) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Seat Assignment'),
        content: Text(
          'Assign Seat ${seat.label} in "${section.name}" to ${widget.entry.studentName} and remove from waiting list?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Assign'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final libraryId = ref.read(currentLibraryIdProvider);
    if (libraryId == null) return;

    setState(() => _isSaving = true);
    try {
      final firestore = FirebaseFirestore.instance;
      final batch = firestore.batch();

      String studentId = widget.entry.studentId;

      if (studentId.isEmpty) {
        final existingStudentQuery = await firestore
            .collection(FirestorePaths.libraries)
            .doc(libraryId)
            .collection(FirestorePaths.students)
            .where('phone', isEqualTo: widget.entry.studentPhone)
            .limit(1)
            .get();

        if (existingStudentQuery.docs.isNotEmpty) {
          studentId = existingStudentQuery.docs.first.id;
          batch.update(existingStudentQuery.docs.first.reference, {
            'seatId': seat.id,
            'sectionId': section.id,
            'status': 'active',
            'updatedAt': FieldValue.serverTimestamp(),
          });
        } else {
          final newStudentRef = firestore
              .collection(FirestorePaths.libraries)
              .doc(libraryId)
              .collection(FirestorePaths.students)
              .doc();
          studentId = newStudentRef.id;

          batch.set(newStudentRef, {
            'id': studentId,
            'name': widget.entry.studentName,
            'phone': widget.entry.studentPhone,
            'seatId': seat.id,
            'sectionId': section.id,
            'status': 'active',
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      } else {
        final studentRef = firestore
            .collection(FirestorePaths.libraries)
            .doc(libraryId)
            .collection(FirestorePaths.students)
            .doc(studentId);
        batch.update(studentRef, {
          'seatId': seat.id,
          'sectionId': section.id,
          'status': 'active',
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      final sectionsSnap = await firestore
          .collection(FirestorePaths.libraries)
          .doc(libraryId)
          .collection(FirestorePaths.sections)
          .get();

      for (final sec in sectionsSnap.docs) {
        final occupiedSeats = await sec.reference
            .collection(FirestorePaths.seats)
            .where('studentId', isEqualTo: studentId)
            .get();

        for (final oldSeat in occupiedSeats.docs) {
          if (oldSeat.id != seat.id) {
            batch.update(oldSeat.reference, {
              'status': SeatStatus.available.name,
              'studentId': null,
              'updatedAt': FieldValue.serverTimestamp(),
            });
          }
        }
      }

      final seatRef = firestore
          .collection(FirestorePaths.libraries)
          .doc(libraryId)
          .collection(FirestorePaths.sections)
          .doc(section.id)
          .collection(FirestorePaths.seats)
          .doc(seat.id);

      batch.update(seatRef, {
        'status': SeatStatus.occupied.name,
        'studentId': studentId,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      final waitRef = firestore
          .collection(FirestorePaths.libraries)
          .doc(libraryId)
          .collection(FirestorePaths.waitingList)
          .doc(widget.entry.id);
      batch.delete(waitRef);

      await batch.commit();

      if (mounted) {
        Navigator.pop(context);
        widget.onSeatAssigned();
      }
    } catch (e) {
      if (mounted) {
        AppErrorFormatter.showErrorSnackBar(context, e, actionContext: 'seat');
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sectionsAsync = ref.watch(sectionsProvider);

    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade400,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  const Icon(Icons.chair_alt, color: Colors.brown),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Select Seat to Assign',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Assigning to: ${widget.entry.studentName}',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(),
            if (_isSaving)
              const Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('Assigning seat and updating records...'),
                    ],
                  ),
                ),
              )
            else
              Expanded(
                child: sectionsAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (err, _) => Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                        AppErrorFormatter.toUserFriendly(err, actionContext: 'section'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ),
                  ),
                  data: (sections) {
                    if (sections.isEmpty) {
                      return const Center(
                        child: Text('No sections available.'),
                      );
                    }
                    return ListView.builder(
                      controller: scrollController,
                      itemCount: sections.length,
                      itemBuilder: (ctx, index) {
                        final section = sections[index];
                        return _AvailableSeatsSectionTile(
                          section: section,
                          onSeatSelected: (seat) => _assignSeat(seat, section),
                        );
                      },
                    );
                  },
                ),
              ),
          ],
        );
      },
    );
  }
}

class _AvailableSeatsSectionTile extends ConsumerWidget {
  final SectionModel section;
  final ValueChanged<SeatModel> onSeatSelected;

  const _AvailableSeatsSectionTile({
    required this.section,
    required this.onSeatSelected,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final seatsAsync = ref.watch(seatsProvider(section.id));

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: ExpansionTile(
        initiallyExpanded: true,
        leading: Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: Color(section.color),
            shape: BoxShape.circle,
          ),
        ),
        title: Text(
          section.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: seatsAsync.when(
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(8.0),
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
              error: (err, _) => Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  AppErrorFormatter.toUserFriendly(err, actionContext: 'seat'),
                  style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
                ),
              ),
              data: (seats) {
                final availableSeats = seats
                    .where((s) =>
                        s.status == SeatStatus.available &&
                        !s.id.startsWith('missing_'))
                    .toList()
                  ..sort(SeatHelper.compareSeats);

                if (availableSeats.isEmpty) {
                  return const Text(
                    'No available seats in this section.',
                    style: TextStyle(
                      fontSize: 13,
                      fontStyle: FontStyle.italic,
                      color: Colors.grey,
                    ),
                  );
                }

                return Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: availableSeats.map((seat) {
                    return ActionChip(
                      avatar: const Icon(
                        Icons.chair,
                        size: 16,
                        color: Colors.green,
                      ),
                      label: Text(
                        seat.label,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      onPressed: () => onSeatSelected(seat),
                    );
                  }).toList(),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
