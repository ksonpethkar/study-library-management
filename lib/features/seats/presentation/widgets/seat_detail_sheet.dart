import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:study_library/models/seat_model.dart';
import 'package:study_library/models/section_model.dart';
import 'package:study_library/core/providers/library_provider.dart';

import '../providers/seat_providers.dart';

class SeatDetailSheet extends ConsumerStatefulWidget {
  final SeatModel seat;
  final String sectionId;

  const SeatDetailSheet({
    super.key,
    required this.seat,
    required this.sectionId,
  });

  @override
  ConsumerState<SeatDetailSheet> createState() => _SeatDetailSheetState();
}

class _SeatDetailSheetState extends ConsumerState<SeatDetailSheet> {
  String? studentName;
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.seat.studentId != null &&
        widget.seat.status == SeatStatus.occupied) {
      _loadStudentName();
    }
  }

  Future<void> _loadStudentName() async {
    final libraryId = ref.read(currentLibraryIdProvider);
    if (libraryId == null) return;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('libraries')
          .doc(libraryId)
          .collection('students')
          .doc(widget.seat.studentId)
          .get();
      if (doc.exists && mounted) {
        setState(() => studentName = doc.data()?['name'] ?? 'Unknown');
      }
    } catch (_) {}
  }

  void _showRenameSeatDialog() {
    final controller = TextEditingController(text: widget.seat.label);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename Seat'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Seat Name / Number',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final newName = controller.text.trim();
              if (newName.isEmpty) return;
              final libraryId = ref.read(currentLibraryIdProvider);
              if (libraryId == null) return;

              await FirebaseFirestore.instance
                  .collection('libraries')
                  .doc(libraryId)
                  .collection('sections')
                  .doc(widget.sectionId)
                  .collection('seats')
                  .doc(widget.seat.id)
                  .update({
                    'label': newName,
                    'updatedAt': FieldValue.serverTimestamp(),
                  });

              if (ctx.mounted) Navigator.pop(ctx);
              if (mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Seat renamed to "$newName"')),
                );
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _changeStatus(SeatStatus newStatus) async {
    setState(() => isLoading = true);
    final libraryId = ref.read(currentLibraryIdProvider);
    if (libraryId == null) return;

    try {
      final updates = <String, dynamic>{'status': newStatus.name};

      // If changing from occupied to anything else, clear studentId
      if (widget.seat.status == SeatStatus.occupied &&
          newStatus != SeatStatus.occupied) {
        updates['studentId'] = null;

        // Also clear the student's seatId
        if (widget.seat.studentId != null) {
          await FirebaseFirestore.instance
              .collection('libraries')
              .doc(libraryId)
              .collection('students')
              .doc(widget.seat.studentId)
              .update({'seatId': null, 'sectionId': null});
        }
      }

      await FirebaseFirestore.instance
          .collection('libraries')
          .doc(libraryId)
          .collection('sections')
          .doc(widget.sectionId)
          .collection('seats')
          .doc(widget.seat.id)
          .update(updates);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Seat ${widget.seat.label} → ${newStatus.name}'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
    if (mounted) setState(() => isLoading = false);
  }

  Future<void> _vacateSeat() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Vacate Seat'),
        content: Text(
          'Remove ${studentName ?? "student"} from seat ${widget.seat.label}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Vacate'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await _changeStatus(SeatStatus.available);
    }
  }

  void _showTransferSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _SeatTransferSheet(
        sourceSeat: widget.seat,
        sourceSectionId: widget.sectionId,
        studentName: studentName,
        onTransferred: () {
          if (mounted) {
            Navigator.pop(context);
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 16,
        right: 16,
        top: 24,
      ),
      child: isLoading
          ? const SizedBox(
              height: 100,
              child: Center(child: CircularProgressIndicator()),
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: _getStatusColor(widget.seat.status)
                                .withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.event_seat,
                            color: _getStatusColor(widget.seat.status),
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  'Seat ${widget.seat.label}',
                                  style: theme.textTheme.headlineSmall
                                      ?.copyWith(fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(width: 4),
                                IconButton(
                                  icon: const Icon(
                                    Icons.edit_outlined,
                                    size: 18,
                                  ),
                                  tooltip: 'Rename Seat',
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  onPressed: _showRenameSeatDialog,
                                ),
                              ],
                            ),
                            Text(
                              'Row ${widget.seat.row + 1}, Column ${widget.seat.col + 1}',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Chip(
                      label: Text(
                        widget.seat.status.name.toUpperCase(),
                        style: TextStyle(
                          color: _getStatusColor(widget.seat.status),
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                      backgroundColor: _getStatusColor(widget.seat.status)
                          .withValues(alpha: 0.15),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Student info (if occupied)
                if (widget.seat.status == SeatStatus.occupied) ...[
                  Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        child: Text(
                          studentName != null
                              ? studentName![0].toUpperCase()
                              : '?',
                        ),
                      ),
                      title: Text(
                        studentName ?? 'Loading...',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: const Text('Currently assigned'),
                      trailing: TextButton(
                        onPressed: () {
                          Navigator.pop(context);
                          context.go(
                            '/admin/students/${widget.seat.studentId}',
                          );
                        },
                        child: const Text('View'),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                // Actions
                const Text(
                  'Actions',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 8),

                // Change Status
                ListTile(
                  leading: const Icon(Icons.swap_horiz_rounded),
                  title: const Text('Change Status'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () => _showStatusPicker(),
                ),

                ListTile(
                  leading: const Icon(
                    Icons.checklist_rounded,
                    color: Colors.indigo,
                  ),
                  title: const Text('Select for Bulk Actions'),
                  trailing: const Icon(Icons.check_box_outline_blank, size: 16),
                  onTap: () {
                    Navigator.pop(context);
                    ref
                        .read(selectedSeatsProvider.notifier)
                        .toggleSelection(widget.seat.id, widget.sectionId);
                  },
                ),

                if (widget.seat.status == SeatStatus.occupied) ...[
                  ListTile(
                    leading: const Icon(
                      Icons.drive_file_move_outline,
                      color: Colors.teal,
                    ),
                    title: const Text('Transfer to Another Seat'),
                    subtitle: const Text('Move student to an available seat'),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: _showTransferSheet,
                  ),
                  ListTile(
                    leading: Icon(
                      Icons.person_remove_rounded,
                      color: theme.colorScheme.error,
                    ),
                    title: Text(
                      'Vacate Seat',
                      style: TextStyle(color: theme.colorScheme.error),
                    ),
                    onTap: _vacateSeat,
                  ),
                ],

                if (widget.seat.status == SeatStatus.available)
                  ListTile(
                    leading: const Icon(Icons.person_add_rounded),
                    title: const Text('Assign Student'),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () {
                      Navigator.pop(context);
                      // Navigate to students list — user picks a student and assigns from detail
                      context.go('/admin/students');
                    },
                  ),

                const SizedBox(height: 24),
              ],
            ),
    );
  }

  void _showStatusPicker() {
    showDialog(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Change Status'),
        children: SeatStatus.values.map((status) {
          final isCurrentStatus = status == widget.seat.status;
          return SimpleDialogOption(
            onPressed: isCurrentStatus
                ? null
                : () {
                    Navigator.pop(ctx);
                    _changeStatus(status);
                  },
            child: Row(
              children: [
                Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: _getStatusColor(status),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  status.name.toUpperCase(),
                  style: TextStyle(
                    fontWeight: isCurrentStatus
                        ? FontWeight.bold
                        : FontWeight.normal,
                    color: isCurrentStatus ? Colors.grey : null,
                  ),
                ),
                if (isCurrentStatus) ...[
                  const SizedBox(width: 8),
                  const Text(
                    '(current)',
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ],
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Color _getStatusColor(SeatStatus status) {
    switch (status) {
      case SeatStatus.available:
        return Colors.green;
      case SeatStatus.occupied:
        return Colors.red;
      case SeatStatus.reserved:
        return Colors.amber;
      case SeatStatus.maintenance:
        return Colors.grey;
    }
  }
}

class _SeatTransferSheet extends ConsumerStatefulWidget {
  final SeatModel sourceSeat;
  final String sourceSectionId;
  final String? studentName;
  final VoidCallback onTransferred;

  const _SeatTransferSheet({
    required this.sourceSeat,
    required this.sourceSectionId,
    required this.studentName,
    required this.onTransferred,
  });

  @override
  ConsumerState<_SeatTransferSheet> createState() => _SeatTransferSheetState();
}

class _SeatTransferSheetState extends ConsumerState<_SeatTransferSheet> {
  bool _isTransferring = false;

  Future<void> _transferTo(SeatModel targetSeat, SectionModel targetSection) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Transfer'),
        content: Text(
          'Transfer ${widget.studentName ?? "student"} from Seat ${widget.sourceSeat.label} to Seat ${targetSeat.label} in ${targetSection.name}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Transfer'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final libraryId = ref.read(currentLibraryIdProvider);
    if (libraryId == null || widget.sourceSeat.studentId == null) return;

    setState(() => _isTransferring = true);
    try {
      final batch = FirebaseFirestore.instance.batch();

      final sourceSeatRef = FirebaseFirestore.instance
          .collection('libraries')
          .doc(libraryId)
          .collection('sections')
          .doc(widget.sourceSectionId)
          .collection('seats')
          .doc(widget.sourceSeat.id);

      final targetSeatRef = FirebaseFirestore.instance
          .collection('libraries')
          .doc(libraryId)
          .collection('sections')
          .doc(targetSection.id)
          .collection('seats')
          .doc(targetSeat.id);

      final studentRef = FirebaseFirestore.instance
          .collection('libraries')
          .doc(libraryId)
          .collection('students')
          .doc(widget.sourceSeat.studentId!);

      batch.update(sourceSeatRef, {
        'status': SeatStatus.available.name,
        'studentId': null,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      batch.update(targetSeatRef, {
        'status': SeatStatus.occupied.name,
        'studentId': widget.sourceSeat.studentId,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      batch.update(studentRef, {
        'seatId': targetSeat.id,
        'sectionId': targetSection.id,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();

      if (mounted) {
        Navigator.pop(context);
        widget.onTransferred();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Transferred to Seat ${targetSeat.label} (${targetSection.name})',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Transfer failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isTransferring = false);
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
                  const Icon(Icons.swap_horiz, color: Colors.teal),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Transfer to Available Seat',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Student: ${widget.studentName ?? "Assigned Student"} (Current: ${widget.sourceSeat.label})',
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
            if (_isTransferring)
              const Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('Transferring seat...'),
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
                        child: Text('No sections configured.'),
                      );
                    }
                    return ListView.builder(
                      controller: scrollController,
                      itemCount: sections.length,
                      itemBuilder: (ctx, index) {
                        final section = sections[index];
                        return _TransferSectionTile(
                          section: section,
                          sourceSeatId: widget.sourceSeat.id,
                          onSeatSelected: (seat) => _transferTo(seat, section),
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

class _TransferSectionTile extends ConsumerWidget {
  final SectionModel section;
  final String sourceSeatId;
  final ValueChanged<SeatModel> onSeatSelected;

  const _TransferSectionTile({
    required this.section,
    required this.sourceSeatId,
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
                        s.id != sourceSeatId &&
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
                        Icons.event_seat,
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
