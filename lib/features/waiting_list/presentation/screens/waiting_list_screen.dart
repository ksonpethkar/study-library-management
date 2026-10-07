import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:study_library/core/constants/firestore_paths.dart';
import 'package:study_library/core/providers/library_provider.dart';
import 'package:study_library/core/router/app_router.dart';
import 'package:study_library/models/waiting_list_model.dart';
import 'package:study_library/models/seat_model.dart';
import 'package:study_library/models/section_model.dart';
import 'package:study_library/features/waiting_list/data/repositories/waiting_list_repository.dart';
import 'package:study_library/features/seats/presentation/providers/seat_providers.dart';

class WaitingListScreen extends ConsumerStatefulWidget {
  const WaitingListScreen({super.key});

  @override
  ConsumerState<WaitingListScreen> createState() => _WaitingListScreenState();
}

class _WaitingListScreenState extends ConsumerState<WaitingListScreen> {
  void _showAddDialog(List<SectionModel> sections) {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    String? selectedSectionId;
    String genderPref = 'none';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add to Waiting List'),
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

                final messenger = ScaffoldMessenger.of(context);
                await ref.read(waitingListRepositoryProvider).addToWaitingList(
                      libraryId,
                      entry,
                    );

                messenger.showSnackBar(
                  SnackBar(content: Text('$name added to waiting list')),
                );
              },
              child: const Text('Add'),
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
              ),
            );
          }
        },
      ),
    );
  }

  Future<void> _notifyEntry(WaitingListEntry entry) async {
    final libraryId = ref.read(currentLibraryIdProvider);
    if (libraryId == null) return;

    await ref
        .read(waitingListRepositoryProvider)
        .notifyEntry(libraryId, entry.id);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Notified ${entry.studentName}')),
      );
    }
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
        SnackBar(content: Text('${entry.studentName} removed from queue')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final waitingListAsync = ref.watch(waitingListStreamProvider);
    final sectionsAsync = ref.watch(sectionsProvider);
    final sections = sectionsAsync.value ?? [];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Waiting List Queue'),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune),
            tooltip: 'Queue Settings',
            onPressed: () => context.push(Routes.adminWaitingList),
          ),
        ],
      ),
      body: waitingListAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(child: Text('Error: $err')),
              data: (entries) {
                if (entries.isEmpty) {
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
                                size: 72,
                                color: Colors.grey.shade400,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Waiting List is Empty',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleLarge
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Students will appear here when the library reaches capacity, or you can add them manually.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.grey.shade600),
                              ),
                              const SizedBox(height: 24),
                              FilledButton.icon(
                                onPressed: () => _showAddDialog(sections),
                                icon: const Icon(Icons.person_add),
                                label: const Text('Add to Queue'),
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
                  itemCount: entries.length,
                  itemBuilder: (ctx, index) {
                    final entry = entries[index];
                    final preferredSection = sections
                        .where((s) => s.id == entry.preferredSectionId)
                        .firstOrNull;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                CircleAvatar(
                                  radius: 20,
                                  backgroundColor: Theme.of(context)
                                      .primaryColor
                                      .withValues(alpha: 0.15),
                                  child: Text(
                                    '#${index + 1}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Theme.of(context).primaryColor,
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
                                          fontSize: 16,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Row(
                                        children: [
                                          const Icon(
                                            Icons.phone,
                                            size: 14,
                                            color: Colors.grey,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            entry.studentPhone,
                                            style: TextStyle(
                                              color: Colors.grey.shade600,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    color: Colors.red,
                                    size: 20,
                                  ),
                                  tooltip: 'Remove',
                                  onPressed: () => _removeEntry(entry),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              children: [
                                if (preferredSection != null)
                                  Chip(
                                    avatar: const Icon(
                                      Icons.meeting_room,
                                      size: 14,
                                    ),
                                    label: Text(
                                      'Pref: ${preferredSection.name}',
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                if (entry.genderPreference != 'none')
                                  Chip(
                                    avatar: const Icon(Icons.wc, size: 14),
                                    label: Text(
                                      entry.genderPreference.toUpperCase(),
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                if (entry.createdAt != null)
                                  Chip(
                                    avatar: const Icon(
                                      Icons.access_time,
                                      size: 14,
                                    ),
                                    label: Text(
                                      DateFormat('dd MMM, hh:mm a')
                                          .format(entry.createdAt!),
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                if (entry.notifiedAt != null)
                                  Chip(
                                    backgroundColor: Colors.green.shade50,
                                    avatar: const Icon(
                                      Icons.check_circle,
                                      size: 14,
                                      color: Colors.green,
                                    ),
                                    label: Text(
                                      'Notified ${DateFormat('hh:mm a').format(entry.notifiedAt!)}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.green.shade800,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    visualDensity: VisualDensity.compact,
                                  ),
                              ],
                            ),
                            const Divider(height: 24),
                            Row(
                              children: [
                                OutlinedButton.icon(
                                  onPressed: () => _notifyEntry(entry),
                                  icon: const Icon(
                                    Icons.notifications_active_outlined,
                                    size: 16,
                                  ),
                                  label: const Text('Notify'),
                                ),
                                const Spacer(),
                                FilledButton.icon(
                                  onPressed: () => _showAssignSeatSheet(entry),
                                  icon: const Icon(Icons.chair_alt, size: 16),
                                  label: const Text('Assign Seat'),
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddDialog(sections),
        icon: const Icon(Icons.person_add),
        label: const Text('Add to Queue'),
      ),
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

      // If no studentId exists in waiting entry, check if student already exists by phone
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
          // Create student record
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

      // Mark seat occupied
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

      // Remove from waiting list
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to assign seat: $e')),
        );
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
                  const Icon(Icons.chair_alt, color: Colors.indigo),
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
                  error: (err, _) =>
                      Center(child: Text('Error loading sections: $err')),
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
              error: (err, _) => Text('Failed to load seats: $err'),
              data: (seats) {
                final availableSeats = seats
                    .where((s) =>
                        s.status == SeatStatus.available &&
                        !s.id.startsWith('missing_'))
                    .toList();

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
