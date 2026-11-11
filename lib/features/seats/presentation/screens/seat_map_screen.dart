import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:study_library/services/seat_allocation_pdf_service.dart';
import 'package:study_library/core/widgets/loading_skeleton.dart';
import 'package:study_library/core/widgets/staggered_list_item.dart';
import 'package:study_library/core/utils/error_formatter.dart';

import '../providers/seat_providers.dart';
import '../widgets/seat_grid_widget.dart';
import 'add_section_screen.dart';
import 'section_detail_screen.dart';

import 'package:study_library/core/providers/library_provider.dart';
import 'package:study_library/models/seat_model.dart';
import 'package:study_library/models/section_model.dart';

class SeatMapScreen extends ConsumerWidget {
  /// When true, shows admin actions (add/edit/delete sections, bulk select).
  /// When false (student view), shows read-only seat availability.
  final bool isAdminView;

  const SeatMapScreen({super.key, this.isAdminView = true});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sectionsAsync = ref.watch(sectionsProvider);
    final selectedSeats = ref.watch(selectedSeatsProvider);
    final libraryId = ref.watch(currentLibraryIdProvider) ?? '';
    final isSelecting = selectedSeats.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        leading: isSelecting
            ? IconButton(
                icon: const Icon(Icons.close),
                tooltip: 'Exit Selection',
                onPressed: () {
                  ref.read(selectedSeatsProvider.notifier).clearSelection();
                },
              )
            : null,
        title: Text(
          isSelecting ? '${selectedSeats.length} Selected' : 'Seat Map',
        ),
        actions: [
          if (!isSelecting && isAdminView)
            IconButton(
              icon: const Icon(Icons.add_rounded),
              tooltip: 'Add Section',
              onPressed: () => _navigateToAddSection(context, libraryId),
            ),
          IconButton(
            icon: const Icon(Icons.print_rounded),
            tooltip: 'Print Seating Chart',
            onPressed: () async {
              final libraryId = ref.read(currentLibraryIdProvider) ?? '';
              // Load library name
              final libDoc = await FirebaseFirestore.instance.collection('libraries').doc(libraryId).get();
              final libraryName = libDoc.data()?['name'] as String? ?? 'Library';
              if (context.mounted) {
                await SeatAllocationPdfService.generateAndShare(
                  libraryId: libraryId,
                  libraryName: libraryName,
                  context: context,
                );
              }
            },
          ),
          if (isSelecting)
            TextButton(
              onPressed: () {
                ref.read(selectedSeatsProvider.notifier).clearSelection();
              },
              child: const Text('Clear', style: TextStyle(color: Colors.white)),
            )
          else if (sectionsAsync.value != null && sectionsAsync.value!.length > 1)
            IconButton(
              icon: const Icon(Icons.swap_vert_rounded),
              tooltip: 'Reorder Sections',
              onPressed: () => _showReorderSectionsSheet(
                context,
                ref,
                sectionsAsync.value!,
                libraryId,
              ),
            ),
        ],
      ),
      body: sectionsAsync.when(
        data: (sections) {
          if (sections.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.event_seat_outlined,
                    size: 64,
                    color: Colors.grey,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No sections found.',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isAdminView
                        ? 'Add a section to manage seats.'
                        : 'Seat map is not configured yet.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  if (isAdminView) ...[
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: () => _navigateToAddSection(context, libraryId),
                      icon: const Icon(Icons.add),
                      label: const Text('Add Section'),
                    ),
                  ],
                ],
              ),
            );
          }

          return Column(
            children: [
              _buildSeatMapLegend(context),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () async {
                    // ignore: unused_result
                    ref.refresh(sectionsProvider);
                  },
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
                    itemCount: sections.length,
                    itemBuilder: (context, index) {
                      final section = sections[index];
                      final hasSelectedInSection = selectedSeats.values.contains(
                        section.id,
                      );

                      final sectionColor = Color(section.color != 0 ? section.color : 0xFF5D4037);
                      return StaggeredListItem(
                        index: index,
                        child: Card(
                        margin: const EdgeInsets.only(bottom: 16),
                  elevation: hasSelectedInSection ? 3 : 1,
                  clipBehavior: Clip.antiAlias,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: hasSelectedInSection
                        ? BorderSide(
                            color: Theme.of(context).colorScheme.primary,
                            width: 2,
                          )
                        : BorderSide(
                            color: sectionColor.withValues(alpha: 0.35),
                            width: 1.5,
                          ),
                  ),
                  child: ExpansionTile(
                    initiallyExpanded: index == 0,
                    leading: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: sectionColor,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: sectionColor.withValues(alpha: 0.35),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.meeting_room_rounded,
                        size: 16,
                        color: Colors.white,
                      ),
                    ),
                    title: Row(
                      children: [
                        Expanded(
                          child: Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                section.name,
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              if (section.sectionType != 'normal') ...[
                                const SizedBox(width: 8),
                                Chip(
                                  label: Text(_sectionTypeLabel(section.sectionType), style: const TextStyle(fontSize: 11)),
                                  backgroundColor: _sectionTypeColor(section.sectionType),
                                  padding: EdgeInsets.zero,
                                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                              ],
                            ],
                          ),
                        ),
                        if (!section.isActive)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.amber.shade100,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.amber.shade400,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.build_circle,
                                  size: 12,
                                  color: Colors.amber.shade900,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Maintenance',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.amber.shade900,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    subtitle: _SectionSubtitle(section: section),
                    trailing: IconButton(
                      icon: const Icon(Icons.more_vert, size: 20),
                      tooltip: 'Section Options',
                      onPressed: () => _showSectionOptionsSheet(
                        context,
                        ref,
                        libraryId,
                        section,
                        hasSelectedInSection,
                      ),
                    ),
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 32.0),
                        child: SeatGridWidget(
                          libraryId: libraryId,
                          sectionId: section.id,
                          rows: section.rows,
                          cols: section.cols,
                          sectionColor: section.color,
                        ),
                      ),
                    ],
                  ),
                ),
                );
              },
            ),
          ),
        ),
      ],
    );
        },
        loading: () => const SeatGridSkeleton(count: 12),
        error: (err, stack) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.meeting_room_outlined, size: 48, color: Colors.orange),
                const SizedBox(height: 12),
                Text(
                  AppErrorFormatter.toUserFriendly(err, actionContext: 'section'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                FilledButton.tonal(
                  onPressed: () => ref.invalidate(sectionsProvider),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: (isAdminView && !isSelecting && MediaQuery.of(context).size.width >= 700)
          ? FloatingActionButton.extended(
              heroTag: 'add_section_fab',
              onPressed: () => _navigateToAddSection(context, libraryId),
              tooltip: 'Add Section',
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add Section'),
            )
          : null,
      bottomNavigationBar: isSelecting
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 8,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: SafeArea(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Theme.of(context).primaryColor
                                .withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            '${selectedSeats.length} Selected',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).primaryColor,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        TextButton(
                          onPressed: () {
                            ref
                                .read(selectedSeatsProvider.notifier)
                                .clearSelection();
                          },
                          child: const Text('Deselect All'),
                        ),
                      ],
                    ),
                    FilledButton.icon(
                      onPressed: () => _showBulkActionSheet(
                        context,
                        ref,
                        libraryId,
                        selectedSeats,
                      ),
                      icon: const Icon(Icons.tune_rounded, size: 18),
                      label: const Text('Bulk Actions'),
                    ),
                  ],
                ),
              ),
            )
          : null,
    );
  }

  void _showSectionOptionsSheet(
    BuildContext context,
    WidgetRef ref,
    String libraryId,
    SectionModel section,
    bool hasSelectedInSection,
  ) {
    final seatRepo = ref.read(seatRepositoryProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sectionColor = Color(section.color != 0 ? section.color : 0xFF5D4037);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetCtx) => Container(
        constraints: const BoxConstraints(maxWidth: 550),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          boxShadow: const [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 16,
              offset: Offset(0, -4),
            ),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: sectionColor.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.meeting_room_rounded,
                    color: sectionColor,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        section.name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${section.capacity} Desks',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(sheetCtx),
                ),
              ],
            ),
            const Divider(height: 24),
            ListTile(
              leading: const Icon(Icons.check_circle_outline, color: Color(0xFF10B981)),
              title: const Text('Reset All Desks to Any / Unisex'),
              subtitle: const Text('Remove Boys/Girls badges and allow all students'),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              onTap: () async {
                Navigator.pop(sheetCtx);
                try {
                  final seats = await seatRepo.getSeatsOnce(libraryId, section.id);
                  final realSeatIds = seats.where((s) => !s.id.startsWith('missing_')).map((s) => s.id).toList();
                  if (realSeatIds.isNotEmpty) {
                    await seatRepo.bulkAssignGender(libraryId, section.id, realSeatIds, GenderRestriction.any);
                    await seatRepo.updateSection(
                      libraryId: libraryId,
                      section: section.copyWith(genderRestriction: 'any'),
                    );
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('All ${realSeatIds.length} desks reset to Any / Unisex!'),
                          backgroundColor: const Color(0xFF10B981),
                        ),
                      );
                    }
                  }
                } catch (e) {
                  if (context.mounted) {
                    AppErrorFormatter.showErrorSnackBar(context, e, actionContext: 'seat');
                  }
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Edit Section'),
              subtitle: const Text('Change name, rows, columns, or color'),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              onTap: () {
                Navigator.pop(sheetCtx);
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
            ListTile(
              leading: const Icon(Icons.dashboard_outlined),
              title: const Text('Section Details'),
              subtitle: const Text('Occupancy breakdown and statistics'),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              onTap: () {
                Navigator.pop(sheetCtx);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => SectionDetailScreen(sectionId: section.id),
                  ),
                );
              },
            ),
            ListTile(
              leading: Icon(
                section.isActive ? Icons.build_circle_outlined : Icons.check_circle_outline,
                color: section.isActive ? Colors.amber.shade800 : Colors.green,
              ),
              title: Text(section.isActive ? 'Set Maintenance Mode' : 'Restore Active Mode'),
              subtitle: Text(section.isActive ? 'Mark entire hall under maintenance' : 'Hall is ready for study'),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              onTap: () {
                Navigator.pop(sheetCtx);
                _toggleSectionStatus(context, ref, libraryId, section);
              },
            ),
            ListTile(
              leading: const Icon(Icons.copy_rounded),
              title: const Text('Duplicate Section'),
              subtitle: const Text('Clone this hall layout into a new section'),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              onTap: () {
                Navigator.pop(sheetCtx);
                _showDuplicateSectionDialog(context, ref, libraryId, section);
              },
            ),
            ListTile(
              leading: Icon(hasSelectedInSection ? Icons.deselect : Icons.select_all_rounded),
              title: Text(hasSelectedInSection ? 'Deselect Section' : 'Select All Desks in Section'),
              subtitle: Text(hasSelectedInSection ? 'Clear selection in this section' : 'Select all desks for bulk operations'),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              onTap: () async {
                Navigator.pop(sheetCtx);
                if (hasSelectedInSection) {
                  final seats = await seatRepo.getSeatsOnce(libraryId, section.id);
                  ref.read(selectedSeatsProvider.notifier).deselectMultiple(seats.map((s) => s.id));
                } else {
                  final seats = await seatRepo.getSeatsOnce(libraryId, section.id);
                  final map = {
                    for (final s in seats)
                      if (!s.id.startsWith('missing_')) s.id: section.id,
                  };
                  ref.read(selectedSeatsProvider.notifier).selectMultiple(map);
                }
              },
            ),
            const Divider(height: 16),
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded, color: Colors.red),
              title: const Text('Delete Section', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
              subtitle: const Text('Permanently remove this hall and seats'),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              onTap: () {
                Navigator.pop(sheetCtx);
                _confirmDeleteSection(context, ref, libraryId, section);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSeatMapLegend(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    Widget legendPill(String label, Color color) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
            ),
          ),
        ],
      );
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 6, 16, 2),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey.shade900 : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
          width: 0.8,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          legendPill('Available', const Color(0xFF4CAF50)),
          legendPill('Occupied', const Color(0xFFE53935)),
          legendPill('Reserved', const Color(0xFFFFB300)),
          legendPill('Maintenance', Colors.grey.shade500),
        ],
      ),
    );
  }

  Map<String, List<String>> _groupSeatsBySection(
    Map<String, String> selectedSeats,
  ) {
    final map = <String, List<String>>{};
    selectedSeats.forEach((seatId, sectionId) {
      map.putIfAbsent(sectionId, () => []).add(seatId);
    });
    return map;
  }

  void _showBulkActionSheet(
    BuildContext context,
    WidgetRef ref,
    String libraryId,
    Map<String, String> selectedSeats,
  ) {
    final seatRepo = ref.read(seatRepositoryProvider);
    final count = selectedSeats.length;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.tune_rounded, color: Colors.brown),
                        const SizedBox(width: 8),
                        Text(
                          'Bulk Actions ($count Seats)',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Text(
                  'CHANGE STATUS',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.check_circle, color: Colors.green),
                title: const Text('Mark as Available'),
                onTap: () async {
                  Navigator.pop(ctx);
                  try {
                    final grouped = _groupSeatsBySection(selectedSeats);
                    for (final entry in grouped.entries) {
                      await seatRepo.bulkUpdateStatus(
                        libraryId,
                        entry.key,
                        entry.value,
                        SeatStatus.available,
                      );
                    }
                    ref.read(selectedSeatsProvider.notifier).clearSelection();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Marked $count seats as Available.'),
                        ),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      AppErrorFormatter.showErrorSnackBar(context, e, actionContext: 'seat');
                    }
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.bookmark, color: Colors.amber),
                title: const Text('Mark as Reserved'),
                onTap: () async {
                  Navigator.pop(ctx);
                  try {
                    final grouped = _groupSeatsBySection(selectedSeats);
                    for (final entry in grouped.entries) {
                      await seatRepo.bulkUpdateStatus(
                        libraryId,
                        entry.key,
                        entry.value,
                        SeatStatus.reserved,
                      );
                    }
                    ref.read(selectedSeatsProvider.notifier).clearSelection();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Marked $count seats as Reserved.'),
                        ),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      AppErrorFormatter.showErrorSnackBar(context, e, actionContext: 'seat');
                    }
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.build, color: Colors.grey),
                title: const Text('Mark as Maintenance'),
                onTap: () async {
                  Navigator.pop(ctx);
                  try {
                    final grouped = _groupSeatsBySection(selectedSeats);
                    for (final entry in grouped.entries) {
                      await seatRepo.bulkUpdateStatus(
                        libraryId,
                        entry.key,
                        entry.value,
                        SeatStatus.maintenance,
                      );
                    }
                    ref.read(selectedSeatsProvider.notifier).clearSelection();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Marked $count seats as Maintenance.'),
                        ),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      AppErrorFormatter.showErrorSnackBar(context, e, actionContext: 'seat');
                    }
                  }
                },
              ),
              const Divider(height: 1),
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Text(
                  'GENDER RESTRICTION',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.people_outline, color: Colors.brown),
                title: const Text('Allow Any Gender'),
                onTap: () async {
                  Navigator.pop(ctx);
                  try {
                    final grouped = _groupSeatsBySection(selectedSeats);
                    for (final entry in grouped.entries) {
                      await seatRepo.bulkAssignGender(
                        libraryId,
                        entry.key,
                        entry.value,
                        GenderRestriction.any,
                      );
                    }
                    ref.read(selectedSeatsProvider.notifier).clearSelection();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Updated gender restriction for $count seats to Any.',
                          ),
                        ),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      AppErrorFormatter.showErrorSnackBar(context, e, actionContext: 'seat');
                    }
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.male, color: Colors.blue),
                title: const Text('Male Only'),
                onTap: () async {
                  Navigator.pop(ctx);
                  try {
                    final grouped = _groupSeatsBySection(selectedSeats);
                    for (final entry in grouped.entries) {
                      await seatRepo.bulkAssignGender(
                        libraryId,
                        entry.key,
                        entry.value,
                        GenderRestriction.male,
                      );
                    }
                    ref.read(selectedSeatsProvider.notifier).clearSelection();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Updated gender restriction for $count seats to Male Only.',
                          ),
                        ),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      AppErrorFormatter.showErrorSnackBar(context, e, actionContext: 'seat');
                    }
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.female, color: Colors.pink),
                title: const Text('Female Only'),
                onTap: () async {
                  Navigator.pop(ctx);
                  try {
                    final grouped = _groupSeatsBySection(selectedSeats);
                    for (final entry in grouped.entries) {
                      await seatRepo.bulkAssignGender(
                        libraryId,
                        entry.key,
                        entry.value,
                        GenderRestriction.female,
                      );
                    }
                    ref.read(selectedSeatsProvider.notifier).clearSelection();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Updated gender restriction for $count seats to Female Only.',
                          ),
                        ),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      AppErrorFormatter.showErrorSnackBar(context, e, actionContext: 'seat');
                    }
                  }
                },
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text(
                  'Delete Selected Seats',
                  style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                onTap: () async {
                  Navigator.pop(ctx);
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (dCtx) => AlertDialog(
                      title: Text('Delete $count Seats?'),
                      content: const Text(
                        'Occupied seats will not be deleted. Are you sure you want to proceed?',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(dCtx, false),
                          child: const Text('Cancel'),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.pop(dCtx, true),
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.red,
                          ),
                          child: const Text('Delete'),
                        ),
                      ],
                    ),
                  );

                  if (confirm == true && context.mounted) {
                    try {
                      final grouped = _groupSeatsBySection(selectedSeats);
                      for (final entry in grouped.entries) {
                        await seatRepo.bulkDeleteSeats(
                          libraryId,
                          entry.key,
                          entry.value,
                        );
                      }
                      ref.read(selectedSeatsProvider.notifier).clearSelection();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Successfully deleted $count seats.'),
                          ),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        AppErrorFormatter.showErrorSnackBar(context, e, actionContext: 'seat');
                      }
                    }
                  }
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  void _navigateToAddSection(BuildContext context, String libraryId) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => AddSectionScreen(libraryId: libraryId),
      ),
    );
  }

  void _showDuplicateSectionDialog(
    BuildContext context,
    WidgetRef ref,
    String libraryId,
    SectionModel section,
  ) {
    final controller = TextEditingController(text: '${section.name} (Copy)');
    showDialog(
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
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final newName = controller.text.trim();
              if (newName.isEmpty) return;
              Navigator.pop(ctx);
              try {
                final repo = ref.read(seatRepositoryProvider);
                await repo.duplicateSection(
                  libraryId: libraryId,
                  sourceSectionId: section.id,
                  newSectionName: newName,
                );
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Section duplicated as "$newName"')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  AppErrorFormatter.showErrorSnackBar(context, e, actionContext: 'section');
                }
              }
            },
            child: const Text('Duplicate'),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleSectionStatus(
    BuildContext context,
    WidgetRef ref,
    String libraryId,
    SectionModel section,
  ) async {
    final newStatus = !section.isActive;
    try {
      final repo = ref.read(seatRepositoryProvider);
      await repo.toggleSectionActive(libraryId, section.id, newStatus);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              newStatus
                  ? 'Section "${section.name}" marked as Active.'
                  : 'Section "${section.name}" set to Maintenance.',
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        AppErrorFormatter.showErrorSnackBar(context, e, actionContext: 'section');
      }
    }
  }

  Future<void> _confirmDeleteSection(
    BuildContext context,
    WidgetRef ref,
    String libraryId,
    SectionModel section,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Section?'),
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

    try {
      final repo = ref.read(seatRepositoryProvider);
      await repo.deleteSection(libraryId, section.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Section "${section.name}" deleted successfully.'),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        AppErrorFormatter.showErrorSnackBar(context, e, actionContext: 'section');
      }
    }
  }

  void _showReorderSectionsSheet(
    BuildContext context,
    WidgetRef ref,
    List<SectionModel> sections,
    String libraryId,
  ) {
    List<SectionModel> reorderedList = List.from(sections);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
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
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.swap_vert_rounded, color: Colors.blue),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Reorder Sections',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Drag and drop items to reorder how sections appear on the seat map.',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ),
                const SizedBox(height: 12),
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.5,
                  ),
                  child: ReorderableListView.builder(
                    shrinkWrap: true,
                    itemCount: reorderedList.length,
                    onReorderItem: (oldIndex, newIndex) {
                      setModalState(() {
                        final item = reorderedList.removeAt(oldIndex);
                        reorderedList.insert(newIndex, item);
                      });
                    },
                    itemBuilder: (context, index) {
                      final s = reorderedList[index];
                      return ListTile(
                        key: ValueKey(s.id),
                        leading: CircleAvatar(
                          radius: 14,
                          backgroundColor: Color(s.color),
                          child: Text(
                            '${index + 1}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        title: Text(
                          s.name,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: _SectionSubtitle(section: s),
                        trailing: const Icon(
                          Icons.drag_handle_rounded,
                          color: Colors.grey,
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    icon: const Icon(Icons.check_rounded),
                    label: const Text('Save Order'),
                    onPressed: () async {
                      Navigator.pop(ctx);
                      final ids = reorderedList.map((e) => e.id).toList();
                      try {
                        await ref.read(seatRepositoryProvider).reorderSections(libraryId, ids);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Sections reordered successfully.'),
                              behavior: SnackBarBehavior.floating,
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          AppErrorFormatter.showErrorSnackBar(context, e, actionContext: 'section');
                        }
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String _sectionTypeLabel(String type) {
  switch (type) {
    case 'window': return '🪟 Window';
    case 'ac': return '❄️ AC Zone';
    case 'premium': return '🌟 Premium';
    default: return 'Normal';
  }
}

Color _sectionTypeColor(String type) {
  switch (type) {
    case 'window': return Colors.blue.shade100;
    case 'ac': return Colors.cyan.shade100;
    case 'premium': return Colors.amber.shade100;
    default: return Colors.grey.shade200;
  }
}

class _SectionSubtitle extends ConsumerWidget {
  final SectionModel section;
  const _SectionSubtitle({required this.section});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final seatsAsync = ref.watch(seatsProvider(section.id));
    final liveCount = seatsAsync.value?.where((s) => !s.id.startsWith('missing_')).length;
    final count = liveCount ?? section.capacity;

    // Auto-heal: If live count is resolved and differs from registered capacity (e.g. 59 physical desks vs 120 capacity)
    // quietly sync Firestore section totalSeats so entire app (occupancy, posters, dashboard) is 100% accurate.
    if (liveCount != null && liveCount > 0 && liveCount != section.capacity) {
      Future.microtask(() {
        final libId = ref.read(currentLibraryIdProvider);
        if (libId != null && libId.isNotEmpty) {
          ref.read(seatRepositoryProvider).updateSection(
            libraryId: libId,
            section: section.copyWith(
              totalSeats: liveCount,
              rows: (liveCount <= 10) ? 1 : (liveCount / 10).ceil(),
              cols: 10,
              updatedAt: DateTime.now(),
            ),
          ).ignore();
        }
      });
    }

    return Text(
      '$count seats',
      style: TextStyle(
        color: Colors.grey.shade600,
        fontSize: 12,
      ),
    );
  }
}


