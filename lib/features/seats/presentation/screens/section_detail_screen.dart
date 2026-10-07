import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:study_library/core/constants/firestore_paths.dart';
import 'package:study_library/core/providers/library_provider.dart';
import 'package:study_library/models/section_model.dart';
import 'package:study_library/models/seat_model.dart';

import '../providers/seat_providers.dart';
import '../widgets/seat_grid_widget.dart';
import 'add_section_screen.dart';

class SectionDetailScreen extends ConsumerStatefulWidget {
  final String sectionId;

  const SectionDetailScreen({super.key, required this.sectionId});

  @override
  ConsumerState<SectionDetailScreen> createState() =>
      _SectionDetailScreenState();
}

class _SectionDetailScreenState extends ConsumerState<SectionDetailScreen> {
  bool _isDeleting = false;

  Future<void> _deleteSection(
    SectionModel section,
    List<SeatModel> seats,
  ) async {
    final occupiedSeats = seats
        .where((s) => s.status == SeatStatus.occupied)
        .toList();
    if (occupiedSeats.isNotEmpty) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Cannot Delete Section'),
            content: Text(
              'This section has ${occupiedSeats.length} student${occupiedSeats.length > 1 ? 's' : ''} currently seated. Please reassign them to other sections first, then try deleting.',
            ),
            actions: [
              FilledButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Understood'),
              ),
            ],
          ),
        );
      }
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Section'),
        content: Text(
          'Are you sure you want to delete "${section.name}" and all its seats?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final libraryId = ref.read(currentLibraryIdProvider);
    if (libraryId == null || libraryId.isEmpty) return;

    setState(() => _isDeleting = true);
    try {
      final repo = ref.read(seatRepositoryProvider);
      await repo.deleteSection(libraryId, widget.sectionId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Section deleted successfully.')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isDeleting = false);
    }
  }

  Future<void> _duplicateSection(SectionModel section) async {
    final controller = TextEditingController(text: '${section.name} (Copy)');
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Duplicate Section'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Create a duplicate of this section with the same dimensions and seating layout:',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'New Section Name',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Duplicate'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    final newName = controller.text.trim();
    if (newName.isEmpty) return;

    final libraryId = ref.read(currentLibraryIdProvider);
    if (libraryId == null || libraryId.isEmpty) return;

    setState(() => _isDeleting = true);
    try {
      final repo = ref.read(seatRepositoryProvider);
      await repo.duplicateSection(
        libraryId: libraryId,
        sourceSectionId: widget.sectionId,
        newSectionName: newName,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Section duplicated as "$newName"')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isDeleting = false);
    }
  }

  Future<void> _toggleSectionStatus(SectionModel section) async {
    final libraryId = ref.read(currentLibraryIdProvider);
    if (libraryId == null || libraryId.isEmpty) return;

    final newStatus = !section.isActive;
    setState(() => _isDeleting = true);
    try {
      final repo = ref.read(seatRepositoryProvider);
      await repo.toggleSectionActive(libraryId, widget.sectionId, newStatus);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              newStatus
                  ? 'Section marked as Active.'
                  : 'Section placed in Maintenance mode.',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isDeleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final libraryId = ref.watch(currentLibraryIdProvider) ?? '';
    final theme = Theme.of(context);

    if (libraryId.isEmpty || widget.sectionId.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/admin/seats');
              }
            },
          ),
          title: const Text('Section Details'),
        ),
        body: const Center(child: Text('Section not found')),
      );
    }

    final sectionDocStream = FirebaseFirestore.instance
        .collection(FirestorePaths.libraries)
        .doc(libraryId)
        .collection(FirestorePaths.sections)
        .doc(widget.sectionId)
        .snapshots();

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: sectionDocStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (!snapshot.hasData || !snapshot.data!.exists) {
          return Scaffold(
            appBar: AppBar(
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    context.go('/admin/seats');
                  }
                },
              ),
              title: const Text('Section Details'),
            ),
            body: const Center(child: Text('Section not found or removed.')),
          );
        }

        final section = SectionModel.fromJson({
          ...snapshot.data!.data()!,
          'id': snapshot.data!.id,
        });

        final seatsAsync = ref.watch(seatsProvider(widget.sectionId));

        return Scaffold(
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () {
                if (context.canPop()) {
                  context.pop();
                } else {
                  context.go('/admin/seats');
                }
              },
            ),
            title: Text(section.name),
            actions: [
              IconButton(
                icon: const Icon(Icons.copy_rounded),
                tooltip: 'Duplicate Section',
                onPressed:
                    _isDeleting ? null : () => _duplicateSection(section),
              ),
              IconButton(
                icon: Icon(
                  section.isActive
                      ? Icons.build_circle_outlined
                      : Icons.check_circle_outline,
                  color: section.isActive
                      ? Colors.amber.shade700
                      : Colors.green,
                ),
                tooltip:
                    section.isActive ? 'Set to Maintenance' : 'Set to Active',
                onPressed:
                    _isDeleting ? null : () => _toggleSectionStatus(section),
              ),
              IconButton(
                icon: const Icon(Icons.edit_outlined),
                tooltip: 'Edit Section',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AddSectionScreen(
                        libraryId: libraryId,
                        section: section,
                      ),
                    ),
                  );
                },
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                tooltip: 'Delete Section',
                onPressed: _isDeleting
                    ? null
                    : () {
                        final currentSeats = seatsAsync.value ?? [];
                        _deleteSection(section, currentSeats);
                      },
              ),
            ],
          ),
          body: _isDeleting
              ? const Center(child: CircularProgressIndicator())
              : seatsAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) =>
                      Center(child: Text('Error loading seats: $e')),
                  data: (seats) {
                    final totalSeats = seats.length;
                    final occupied = seats
                        .where((s) => s.status == SeatStatus.occupied)
                        .length;
                    final available = seats
                        .where((s) => s.status == SeatStatus.available)
                        .length;
                    final maintenance = totalSeats - occupied - available;

                    return SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (!section.isActive) ...[
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.amber.shade100,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.amber.shade400),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.warning_amber_rounded,
                                    color: Colors.amber.shade900,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      'This section is under maintenance. New bookings and allocations are temporarily disabled.',
                                      style: TextStyle(
                                        color: Colors.amber.shade900,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],
                          // Stats row
                          Row(
                            children: [
                              _StatBadge(
                                label: 'Total',
                                value: '$totalSeats',
                                color: Colors.blueGrey,
                              ),
                              const SizedBox(width: 8),
                              _StatBadge(
                                label: 'Occupied',
                                value: '$occupied',
                                color: Colors.red,
                              ),
                              const SizedBox(width: 8),
                              _StatBadge(
                                label: 'Available',
                                value: '$available',
                                color: Colors.green,
                              ),
                              if (maintenance > 0) ...[
                                const SizedBox(width: 8),
                                _StatBadge(
                                  label: 'Other',
                                  value: '$maintenance',
                                  color: Colors.amber,
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Notes if any
                          if (section.notes != null &&
                              section.notes!.isNotEmpty) ...[
                            Card(
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.info_outline,
                                      size: 20,
                                      color: Colors.blue,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        section.notes!,
                                        style: theme.textTheme.bodyMedium,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],

                          // Grid
                          Text(
                            'Seat Layout (${section.rows} rows × ${section.cols} cols)',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),

                          SeatGridWidget(
                            libraryId: libraryId,
                            sectionId: widget.sectionId,
                            rows: section.rows,
                            cols: section.cols,
                          ),
                        ],
                      ),
                    );
                  },
                ),
        );
      },
    );
  }
}

class _StatBadge extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatBadge({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(fontSize: 12, color: color)),
          ],
        ),
      ),
    );
  }
}
