import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:study_library/core/utils/error_formatter.dart';
import 'package:study_library/core/utils/seat_helper.dart';
import 'package:study_library/core/constants/amenity_catalog.dart';
import 'package:study_library/core/providers/library_provider.dart';
import 'package:study_library/features/seats/presentation/providers/seat_providers.dart';
import 'package:study_library/features/students/presentation/providers/student_providers.dart';
import 'package:study_library/models/seat_model.dart';
import 'package:study_library/models/section_model.dart';
import 'package:study_library/models/student_model.dart';
import 'package:study_library/core/security/audit_logger.dart';
import 'package:study_library/services/message_template_service.dart';

/// Full-fidelity visual Seat Map assignment and desk-change bottom sheet.
/// Renders true 2D room floor plans according to section grid columns and rows,
/// displaying live status, spatial orientation, current desk highlights,
/// atomic vacant desk allocation, and direct occupant seat-swapping.
class SeatAssignmentMapSheet extends ConsumerStatefulWidget {
  final String libraryId;
  final String studentId;
  final String studentName;
  final String? currentSeatId;
  final String? currentSectionId;
  final VoidCallback onSeatAssigned;
  final List<SectionModel>? preloadedSections;
  final List<SeatModel>? preloadedSeats;
  final List<StudentModel>? preloadedStudents;

  const SeatAssignmentMapSheet({
    super.key,
    required this.libraryId,
    required this.studentId,
    required this.studentName,
    this.currentSeatId,
    this.currentSectionId,
    required this.onSeatAssigned,
    this.preloadedSections,
    this.preloadedSeats,
    this.preloadedStudents,
  });

  static Future<void> show(
    BuildContext context, {
    required String libraryId,
    required String studentId,
    required String studentName,
    String? currentSeatId,
    String? currentSectionId,
    VoidCallback? onSeatAssigned,
    List<SectionModel>? preloadedSections,
    List<SeatModel>? preloadedSeats,
    List<StudentModel>? preloadedStudents,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SeatAssignmentMapSheet(
        libraryId: libraryId,
        studentId: studentId,
        studentName: studentName,
        currentSeatId: currentSeatId,
        currentSectionId: currentSectionId,
        onSeatAssigned: onSeatAssigned ?? () {},
        preloadedSections: preloadedSections,
        preloadedSeats: preloadedSeats,
        preloadedStudents: preloadedStudents,
      ),
    );
  }

  @override
  ConsumerState<SeatAssignmentMapSheet> createState() => _SeatAssignmentMapSheetState();
}

class _SeatAssignmentMapSheetState extends ConsumerState<SeatAssignmentMapSheet> {
  String? _selectedSectionId;
  SeatModel? _selectedTargetSeat;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _selectedSectionId = widget.currentSectionId;
  }

  Future<void> _confirmUnassign() async {
    final curSeat = widget.currentSeatId;
    if (_isSubmitting || curSeat == null || curSeat.isEmpty) return;
    setState(() => _isSubmitting = true);
    HapticFeedback.mediumImpact();

    try {
      final seatRepo = ref.read(seatRepositoryProvider);
      var secId = widget.currentSectionId ?? '';
      if (secId.isEmpty) {
        final found = await seatRepo.findSeatInLibrary(widget.libraryId, curSeat);
        secId = found?.sectionId ?? '';
      }
      if (secId.isEmpty) {
        throw Exception('Could not locate section for current desk.');
      }
      await seatRepo.unassignStudent(
        libraryId: widget.libraryId,
        sectionId: secId,
        seatId: curSeat,
        studentId: widget.studentId,
      );
      if (mounted) {
        Navigator.pop(context);
        widget.onSeatAssigned();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Removed desk from ${MessageTemplateService.toTitleCase(widget.studentName)}'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        AppErrorFormatter.showErrorSnackBar(context, e);
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _confirmAssignment(SectionModel section, SeatModel targetSeat) async {
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);
    HapticFeedback.mediumImpact();

    try {
      final seatRepo = ref.read(seatRepositoryProvider);
      await seatRepo.assignStudent(
        widget.libraryId,
        section.id,
        targetSeat.id,
        widget.studentId,
      );

      AuditLogger().log(
        action: AuditAction.updated,
        entityType: AuditEntity.student,
        libraryId: widget.libraryId,
        entityId: widget.studentId,
        details: {
          'action': 'desk_assigned_via_seat_map',
          'studentName': widget.studentName,
          'previousSeatId': widget.currentSeatId,
          'newSeatId': targetSeat.id,
          'newSeatLabel': targetSeat.label,
          'sectionId': section.id,
          'sectionName': section.name,
        },
      ).ignore();

      if (mounted) {
        Navigator.pop(context);
        widget.onSeatAssigned();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${SeatHelper.formatDeskLabel(rawLabel: targetSeat.label)} allocated to ${widget.studentName} ✓',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF059669),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        AppErrorFormatter.showErrorSnackBar(context, e, actionContext: 'seat');
      }
    }
  }

  Future<void> _confirmSwap(SectionModel section, SeatModel targetSeat, StudentModel occupant) async {
    if (_isSubmitting) return;

    if (widget.currentSeatId == null || widget.currentSeatId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot swap: Student has no current desk to swap with.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dlgCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.swap_horiz_rounded, color: Color(0xFF8B5CF6)),
            SizedBox(width: 8),
            Text('Confirm Desk Swap', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Swap desks between two active students:',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.purple.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.purple.shade200),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(Icons.person, size: 16, color: Color(0xFF6D28D9)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '${widget.studentName} ➔ ${SeatHelper.formatDeskLabel(rawLabel: targetSeat.label)}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.person, size: 16, color: Color(0xFF6D28D9)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '${MessageTemplateService.toTitleCase(occupant.name)} ➔ ${SeatHelper.formatDeskLabel(seatId: widget.currentSeatId)}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dlgCtx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dlgCtx, true),
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF8B5CF6)),
            child: const Text('Confirm Swap'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isSubmitting = true);
    HapticFeedback.mediumImpact();

    try {
      final seatRepo = ref.read(seatRepositoryProvider);
      final sourceSectionId = widget.currentSectionId ?? section.id;

      await seatRepo.swapStudents(
        libraryId: widget.libraryId,
        seatAId: widget.currentSeatId!,
        sectionAId: sourceSectionId,
        studentAId: widget.studentId,
        seatBId: targetSeat.id,
        sectionBId: section.id,
        studentBId: occupant.id,
      );

      if (mounted) {
        Navigator.pop(context);
        widget.onSeatAssigned();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Desks swapped successfully between ${widget.studentName} and ${occupant.name} ✓'),
            backgroundColor: const Color(0xFF8B5CF6),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        AppErrorFormatter.showErrorSnackBar(context, e, actionContext: 'seat');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final sectionsAsync = ref.watch(sectionsProvider);
    final studentsAsync = ref.watch(studentsStreamProvider);
    final studentList = widget.preloadedStudents ?? studentsAsync.value ?? <StudentModel>[];
    final Map<String, StudentModel> studentMap = {
      for (final s in studentList) s.id: s,
    };

    final availableSections = widget.preloadedSections ?? sectionsAsync.value;
    final currentActiveSection = (availableSections != null && availableSections.isNotEmpty)
        ? availableSections.firstWhere(
            (s) => s.id == _selectedSectionId,
            orElse: () => availableSections.first,
          )
        : null;

    return DraggableScrollableSheet(
      initialChildSize: 0.88,
      minChildSize: 0.5,
      maxChildSize: 0.96,
      expand: false,
      builder: (sheetCtx, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0F172A) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: const [
              BoxShadow(color: Colors.black26, blurRadius: 20, spreadRadius: 4),
            ],
          ),
          child: Column(
            children: [
              // 1. Drag Handle
              Container(
                margin: const EdgeInsets.only(top: 10, bottom: 6),
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // 2. Sheet Header with Student Summary & Close Button
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.event_seat_rounded, color: theme.colorScheme.primary, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.currentSeatId != null && widget.currentSeatId!.isNotEmpty
                                ? 'Change Desk Allocation'
                                : 'Assign Seat to Student',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              fontSize: 17,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Text(
                                MessageTemplateService.toTitleCase(widget.studentName),
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                width: 4,
                                height: 4,
                                decoration: BoxDecoration(
                                  color: isDark ? Colors.white38 : Colors.grey.shade400,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  widget.currentSeatId != null && widget.currentSeatId!.isNotEmpty
                                      ? 'Current: ${SeatHelper.formatDeskLabel(seatId: widget.currentSeatId)}'
                                      : 'No desk allocated',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark ? Colors.white60 : Colors.grey.shade600,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (widget.currentSeatId != null && widget.currentSeatId!.isNotEmpty)
                      TextButton.icon(
                        onPressed: _isSubmitting ? null : _confirmUnassign,
                        icon: const Icon(Icons.link_off_rounded, size: 16),
                        label: const Text('Remove'),
                        style: TextButton.styleFrom(
                          foregroundColor: theme.colorScheme.error,
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      tooltip: 'Close',
                      onPressed: () => Navigator.pop(sheetCtx),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),

              // 3. Sections Content
              Expanded(
                child: widget.preloadedSections != null
                    ? _buildSectionLayout(
                        context: context,
                        sections: widget.preloadedSections!,
                        studentMap: studentMap,
                        scrollController: scrollController,
                        isDark: isDark,
                        theme: theme,
                      )
                    : sectionsAsync.when(
                        loading: () => const Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircularProgressIndicator(),
                              SizedBox(height: 12),
                              Text('Loading library seat map...'),
                            ],
                          ),
                        ),
                        error: (err, _) => Center(
                          child: Padding(
                            padding: const EdgeInsets.all(20.0),
                            child: Text(
                              AppErrorFormatter.toUserFriendly(err, actionContext: 'section'),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                        data: (sections) => _buildSectionLayout(
                          context: context,
                          sections: sections,
                          studentMap: studentMap,
                          scrollController: scrollController,
                          isDark: isDark,
                          theme: theme,
                        ),
                      ),
              ),

              // 4. Interactive Bottom Action Card
              if (_selectedTargetSeat != null && currentActiveSection != null) ...[
                _buildActionBottomBar(
                  theme: theme,
                  isDark: isDark,
                  activeSection: currentActiveSection,
                  targetSeat: _selectedTargetSeat!,
                  occupant: _selectedTargetSeat!.studentId != null ? studentMap[_selectedTargetSeat!.studentId] : null,
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildSectionLayout({
    required BuildContext context,
    required List<SectionModel> sections,
    required Map<String, StudentModel> studentMap,
    required ScrollController scrollController,
    required bool isDark,
    required ThemeData theme,
  }) {
    if (sections.isEmpty) {
      return const Center(child: Text('No study hall sections configured.'));
    }

    final activeSection = sections.firstWhere(
      (s) => s.id == _selectedSectionId,
      orElse: () => sections.first,
    );

    final List<SeatModel> sortedSeats;
    final AsyncValue<List<SeatModel>>? seatsAsync;
    if (widget.preloadedSeats != null && widget.preloadedSeats!.isNotEmpty) {
      final filtered = widget.preloadedSeats!.where((s) => s.sectionId == activeSection.id).toList();
      sortedSeats = [...filtered]..sort(SeatHelper.compareSeats);
      seatsAsync = null;
    } else {
      final asyncVal = ref.watch(seatsProvider(activeSection.id));
      seatsAsync = asyncVal;
      final sectionSeats = asyncVal.value ?? <SeatModel>[];
      sortedSeats = [...sectionSeats]..sort(SeatHelper.compareSeats);
    }

    int availableCount = 0;
    int occupiedCount = 0;
    int holdCount = 0;
    for (final s in sortedSeats) {
      final isCurrent = s.id == widget.currentSeatId;
      if (isCurrent) continue;
      final occupant = s.studentId != null ? studentMap[s.studentId] : null;
      final status = s.effectiveStatus;
      final isOccupied = status == SeatStatus.occupied || (occupant != null);
      if (isOccupied) {
        occupiedCount++;
      } else if (status == SeatStatus.reserved || status == SeatStatus.maintenance) {
        holdCount++;
      } else if (status == SeatStatus.available) {
        availableCount++;
      }
    }

    return Column(
      children: [
        // Section Tabs (if multiple sections exist)
        if (sections.length > 1) ...[
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: sections.map((sec) {
                final isSelected = sec.id == activeSection.id;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(sec.name),
                    selected: isSelected,
                    onSelected: (selected) {
                      if (selected) {
                        setState(() {
                          _selectedSectionId = sec.id;
                          _selectedTargetSeat = null;
                        });
                      }
                    },
                  ),
                );
              }).toList(),
            ),
          ),
        ],

        // Status Legend & Summary Ribbon
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: isDark ? Colors.white.withValues(alpha: 0.03) : const Color(0xFFF8FAFC),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Wrap(
                spacing: 12,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _buildLegendItem(const Color(0xFF10B981), 'Vacant ($availableCount)'),
                  _buildLegendItem(const Color(0xFFEF4444), 'Occupied ($occupiedCount)'),
                  if (widget.currentSeatId != null && widget.currentSeatId!.isNotEmpty)
                    _buildLegendItem(const Color(0xFF8B5CF6), 'Current Desk'),
                  _buildLegendItem(const Color(0xFFF59E0B), holdCount > 0 ? 'Hold / Maint. ($holdCount)' : 'Hold / Maint.'),
                ],
              ),
            ],
          ),
        ),

        // True 2D Floor Plan Grid
        Expanded(
          child: seatsAsync != null
              ? seatsAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (err, _) => Center(
                    child: Text(AppErrorFormatter.toUserFriendly(err, actionContext: 'seat')),
                  ),
                  data: (seats) => _buildFloorPlanGrid(
                    activeSection: activeSection,
                    sortedSeats: [...seats]..sort(SeatHelper.compareSeats),
                    studentMap: studentMap,
                    scrollController: scrollController,
                    isDark: isDark,
                    theme: theme,
                  ),
                )
              : _buildFloorPlanGrid(
                  activeSection: activeSection,
                  sortedSeats: sortedSeats,
                  studentMap: studentMap,
                  scrollController: scrollController,
                  isDark: isDark,
                  theme: theme,
                ),
        ),
      ],
    );
  }

  Widget _buildFloorPlanGrid({
    required SectionModel activeSection,
    required List<SeatModel> sortedSeats,
    required Map<String, StudentModel> studentMap,
    required ScrollController scrollController,
    required bool isDark,
    required ThemeData theme,
  }) {
    if (sortedSeats.isEmpty) {
      return const Center(child: Text('No desks found in this section.'));
    }

    final crossAxisCount = activeSection.cols > 0 ? activeSection.cols : 10;
    final minGridWidth = math.max(360.0, crossAxisCount * 54.0);
    final library = ref.watch(currentLibraryProvider).value;
    final resolvedAmenities = AmenityCatalog.resolveEffectiveAmenities(
      library: library,
      section: activeSection,
    );
    final badgeAmenity = resolvedAmenities.isNotEmpty ? resolvedAmenities.first : null;
    final hasSilenceZone = resolvedAmenities.any((a) => a.id == 'silence');
    final rearBannerText = (activeSection.notes?.trim().isNotEmpty ?? false)
        ? activeSection.notes!.trim()
        : (hasSilenceZone ? 'Quiet Study Zone • Rear Area' : 'Rear Study Area');

    return SingleChildScrollView(
      controller: scrollController,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Top Spatial Orientation Banner (Front Entrance / Reception)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: isDark ? Colors.white12 : const Color(0xFFE2E8F0)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.door_front_door_outlined, size: 15, color: theme.colorScheme.primary),
                    const SizedBox(width: 6),
                    Text(
                      'Front Reception & Main Entrance',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white70 : const Color(0xFF334155),
                      ),
                    ),
                  ],
                ),
                if (badgeAmenity != null)
                  Row(
                    children: [
                      Icon(badgeAmenity.icon, size: 14, color: const Color(0xFF10B981)),
                      const SizedBox(width: 4),
                      Text(
                        badgeAmenity.shortLabel,
                        style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: Color(0xFF059669)),
                      ),
                    ],
                  ),
              ],
            ),
          ),

          // 2D Scrollable Grid matching the exact section layout
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: minGridWidth),
              child: SizedBox(
                width: minGridWidth,
                child: GridView.builder(
                  key: ValueKey('grid_${activeSection.id}_${sortedSeats.length}'),
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: sortedSeats.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    childAspectRatio: 0.8,
                  ),
                  itemBuilder: (context, index) {
                    final seat = sortedSeats[index];
                    final isCurrent = seat.id == widget.currentSeatId;
                    final isSelectedTarget = _selectedTargetSeat?.id == seat.id;
                    final occupant = seat.studentId != null ? studentMap[seat.studentId] : null;

                    return _buildSeatMapTile(
                      seat: seat,
                      isCurrent: isCurrent,
                      isSelectedTarget: isSelectedTarget,
                      occupant: occupant,
                      isDark: isDark,
                      theme: theme,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() {
                          _selectedTargetSeat = seat;
                        });
                      },
                    );
                  },
                ),
              ),
            ),
          ),

          // Bottom Spatial Orientation Banner (Back Silent Zone)
          Container(
            margin: const EdgeInsets.only(top: 12),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withValues(alpha: 0.03) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
            ),
            child: Center(
              child: Text(
                rearBannerText,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
                ),
              ),
            ),
          ),
          const SizedBox(height: 90), // Bottom sheet button clearance
        ],
      ),
    );
  }

  static String _formatTileName(String fullName) {
    final clean = MessageTemplateService.toTitleCase(fullName).trim();
    if (clean.isEmpty) return '';
    final parts = clean.split(RegExp(r'\s+'));
    if (parts.length == 1) return parts[0];
    return '${parts[0]} ${parts[1][0]}.';
  }

  Widget _buildSeatMapTile({
    required SeatModel seat,
    required bool isCurrent,
    required bool isSelectedTarget,
    required StudentModel? occupant,
    required bool isDark,
    required ThemeData theme,
    required VoidCallback onTap,
  }) {
    final status = seat.effectiveStatus;
    final isOccupied = status == SeatStatus.occupied || (occupant != null && !isCurrent);
    final isAvailable = status == SeatStatus.available && !isOccupied && !isCurrent;
    final isReserved = status == SeatStatus.reserved;
    final isMaintenance = status == SeatStatus.maintenance;

    Color bgColor;
    Color borderColor;
    Color textColor;
    double borderWidth = 1.0;

    if (isSelectedTarget) {
      bgColor = isAvailable
          ? const Color(0xFF059669)
          : (isCurrent ? const Color(0xFF7C3AED) : const Color(0xFFDC2626));
      borderColor = Colors.amberAccent;
      borderWidth = 2.5;
      textColor = Colors.white;
    } else if (isCurrent) {
      bgColor = isDark ? const Color(0xFF3B0764) : const Color(0xFFEDE9FE);
      borderColor = const Color(0xFF8B5CF6);
      borderWidth = 2.0;
      textColor = isDark ? const Color(0xFFDDD6FE) : const Color(0xFF6D28D9);
    } else if (isOccupied) {
      bgColor = isDark ? const Color(0xFF450A0A) : const Color(0xFFFEE2E2);
      borderColor = isDark ? const Color(0xFF7F1D1D) : const Color(0xFFFCA5A5);
      textColor = isDark ? const Color(0xFFFCA5A5) : const Color(0xFFB91C1C);
    } else if (isReserved) {
      bgColor = isDark ? const Color(0xFF451A03) : const Color(0xFFFEF3C7);
      borderColor = isDark ? const Color(0xFF78350F) : const Color(0xFFFCD34D);
      textColor = isDark ? const Color(0xFFFCD34D) : const Color(0xFFB45309);
    } else if (isMaintenance) {
      bgColor = isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9);
      borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1);
      textColor = isDark ? Colors.white38 : Colors.grey.shade500;
    } else {
      // Available / Vacant
      bgColor = isDark ? const Color(0xFF064E3B) : const Color(0xFFECFDF5);
      borderColor = isDark ? const Color(0xFF065F46) : const Color(0xFFA7F3D0);
      textColor = isDark ? const Color(0xFFA7F3D0) : const Color(0xFF047857);
    }

    final deskLabel = SeatHelper.formatSeatNumberOnly(rawLabel: seat.label);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: borderColor, width: borderWidth),
          boxShadow: isSelectedTarget
              ? [
                  BoxShadow(
                    color: borderColor.withValues(alpha: 0.5),
                    blurRadius: 6,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isCurrent)
                const Icon(Icons.star_rounded, size: 13, color: Color(0xFF8B5CF6))
              else if (isOccupied)
                const Icon(Icons.person, size: 12, color: Color(0xFFEF4444))
              else if (isReserved)
                const Icon(Icons.lock_clock, size: 12, color: Color(0xFFF59E0B))
              else if (isMaintenance)
                const Icon(Icons.build_circle, size: 12, color: Colors.grey)
              else
                const Icon(Icons.event_seat_rounded, size: 12, color: Color(0xFF10B981)),
              const SizedBox(height: 2),
              Text(
                deskLabel,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12.5,
                  color: textColor,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (isCurrent)
                const Text(
                  'CURRENT',
                  style: TextStyle(
                    fontSize: 7.0,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF8B5CF6),
                    letterSpacing: 0.5,
                  ),
                )
              else if (isOccupied && (occupant != null || (seat.studentName != null && seat.studentName!.isNotEmpty)))
                Text(
                  _formatTileName(occupant?.name ?? seat.studentName ?? ''),
                  style: TextStyle(
                    fontSize: 7.5,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionBottomBar({
    required ThemeData theme,
    required bool isDark,
    required SectionModel activeSection,
    required SeatModel targetSeat,
    required StudentModel? occupant,
  }) {
    final isCurrent = targetSeat.id == widget.currentSeatId;
    final isOccupied = targetSeat.effectiveStatus == SeatStatus.occupied || (occupant != null && !isCurrent);
    final isAvailable = targetSeat.effectiveStatus == SeatStatus.available && !isOccupied && !isCurrent;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, -3)),
        ],
        border: Border(top: BorderSide(color: isDark ? Colors.white12 : Colors.grey.shade200)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: isAvailable
                      ? const Color(0xFFECFDF5)
                      : (isCurrent ? const Color(0xFFEDE9FE) : const Color(0xFFFEE2E2)),
                  child: Icon(
                    isAvailable
                        ? Icons.check_circle_rounded
                        : (isCurrent ? Icons.star_rounded : Icons.swap_horiz_rounded),
                    color: isAvailable
                        ? const Color(0xFF059669)
                        : (isCurrent ? const Color(0xFF7C3AED) : const Color(0xFFDC2626)),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Selected: ${SeatHelper.formatDeskLabel(rawLabel: targetSeat.label)} (${activeSection.name})',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isCurrent
                            ? 'Currently assigned to ${MessageTemplateService.toTitleCase(widget.studentName)}'
                            : (isAvailable
                                ? (widget.currentSeatId != null && widget.currentSeatId!.isNotEmpty
                                    ? 'Moving from ${SeatHelper.formatDeskLabel(seatId: widget.currentSeatId)} ➔ ${SeatHelper.formatDeskLabel(rawLabel: targetSeat.label)}'
                                    : 'Available for immediate allocation')
                                : (occupant != null
                                    ? 'Occupied by ${MessageTemplateService.toTitleCase(occupant.name)} (${occupant.phone})'
                                    : (targetSeat.studentName != null && targetSeat.studentName!.isNotEmpty
                                        ? 'Occupied by ${MessageTemplateService.toTitleCase(targetSeat.studentName!)}'
                                        : 'Desk is currently occupied / reserved'))),
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white60 : Colors.grey.shade600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (isCurrent) ...[
              FilledButton.tonal(
                onPressed: null,
                child: const Text('Already Assigned to This Desk'),
              ),
            ] else if (isAvailable) ...[
              FilledButton.icon(
                onPressed: _isSubmitting ? null : () => _confirmAssignment(activeSection, targetSeat),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF059669),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: _isSubmitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.check_rounded),
                label: Text(
                  widget.currentSeatId != null ? 'Confirm Desk Transfer ➔' : 'Confirm Desk Allocation ➔',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5),
                ),
              ),
            ] else if (isOccupied && occupant != null) ...[
              FilledButton.icon(
                onPressed: _isSubmitting ? null : () => _confirmSwap(activeSection, targetSeat, occupant),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF8B5CF6),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.swap_horiz_rounded),
                label: Text(
                  'Swap Desks with ${occupant.name.split(' ').first} (A ⇄ B)',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5),
                ),
              ),
            ] else ...[
              OutlinedButton(
                onPressed: () => setState(() => _selectedTargetSeat = null),
                child: const Text('Desk Unavailable • Choose Another'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2.5)),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}
