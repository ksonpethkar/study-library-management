import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:study_library/models/seat_model.dart';
import 'package:study_library/models/section_model.dart';
import 'package:study_library/models/student_model.dart';
import 'package:study_library/models/waiting_list_model.dart';
import 'package:study_library/services/waiting_list_promotion_service.dart';
import 'package:study_library/core/providers/library_provider.dart';
import 'package:study_library/core/error/error_handler.dart';
import 'package:study_library/core/utils/error_formatter.dart';
import 'package:study_library/features/students/presentation/providers/student_providers.dart';
import 'package:study_library/services/app_notification_service.dart';
import 'package:study_library/core/utils/seat_helper.dart';

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
    if (widget.seat.studentId != null && widget.seat.studentId!.isNotEmpty) {
      _loadStudentName();
    } else {
      _lookupStudentBySeat();
    }
  }

  Future<void> _lookupStudentBySeat() async {
    final libraryId = ref.read(currentLibraryIdProvider);
    if (libraryId == null) return;

    try {
      final snap = await FirebaseFirestore.instance
          .collection('libraries')
          .doc(libraryId)
          .collection('students')
          .where('seatId', isEqualTo: widget.seat.id)
          .limit(1)
          .get();
      if (snap.docs.isNotEmpty && mounted) {
        final doc = snap.docs.first;
        setState(() {
          studentName = doc.data()['name'] ?? 'Unknown';
        });
      }
    } catch (_) {}
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
      final updates = <String, dynamic>{
        'status': newStatus.name,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (newStatus == SeatStatus.available) {
        updates['studentId'] = null;
        updates['studentName'] = FieldValue.delete();
        updates['assignedAt'] = FieldValue.delete();
        updates['vacatedAt'] = FieldValue.serverTimestamp();
        updates['reservationType'] = FieldValue.delete();
        updates['reservedCandidateId'] = FieldValue.delete();
        updates['reservedCandidateName'] = FieldValue.delete();
        updates['reservationExpiresAt'] = FieldValue.delete();
      } else if (newStatus == SeatStatus.maintenance) {
        updates['reservationType'] = FieldValue.delete();
        updates['reservedCandidateId'] = FieldValue.delete();
        updates['reservedCandidateName'] = FieldValue.delete();
        updates['reservationExpiresAt'] = FieldValue.delete();
      }

      // If changing from occupied to anything else, clear studentId & preserve previousSeatId
      if (widget.seat.status == SeatStatus.occupied &&
          newStatus != SeatStatus.occupied) {
        updates['studentId'] = null;
        updates['studentName'] = FieldValue.delete();
        updates['assignedAt'] = FieldValue.delete();
        updates['vacatedAt'] = FieldValue.serverTimestamp();

        // Also clear the student's seatId and preserve previousSeatId for seamless recovery
        if (widget.seat.studentId != null) {
          final occupantId = widget.seat.studentId!;
          await FirebaseFirestore.instance
              .collection('libraries')
              .doc(libraryId)
              .collection('students')
              .doc(occupantId)
              .update({
                'seatId': null,
                'sectionId': null,
                'previousSeatId': widget.seat.id,
              });

          if (newStatus == SeatStatus.maintenance) {
            AppNotificationService.sendNotification(
              libraryId: libraryId,
              title: 'Desk Maintenance Notice',
              body: 'Seat ${widget.seat.label} has been placed under maintenance. Please visit reception for immediate temporary desk reallocation.',
              type: 'seat',
              targetRole: 'student',
              targetUserId: occupantId,
              actionRoute: '/student/home',
            );
          }
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

      WaitingListEntry? candidate;
      if (newStatus == SeatStatus.available) {
        final promoService = ref.read(waitingListPromotionServiceProvider);
        candidate = await promoService.findNextEligibleCandidate(
          libraryId: libraryId,
          sectionId: widget.sectionId,
          seatGender: widget.seat.genderRestriction.name,
        );
      }

      if (mounted) {
        if (candidate != null) {
          await _showWaitingListPromotionDialog(libraryId, candidate);
        }
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Seat ${widget.seat.label} → ${newStatus.name}'),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        AppSnackbar.showError(context, e);
      }
    }
    if (mounted) setState(() => isLoading = false);
  }

  Future<void> _showWaitingListPromotionDialog(
    String libraryId,
    WaitingListEntry candidate,
  ) async {
    final libraryAsync = ref.read(currentLibraryProvider);
    final libraryName = libraryAsync.value?.name.isNotEmpty == true ? libraryAsync.value!.name : 'Study Library';
    final promoService = ref.read(waitingListPromotionServiceProvider);

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        titlePadding: EdgeInsets.zero,
        title: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: const BoxDecoration(
            color: Color(0xFF881337),
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
            ),
          ),
          child: const Row(
            children: [
              Icon(Icons.queue_play_next, color: Colors.amber, size: 24),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Waiting List Match Found!',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Seat ${widget.seat.label} is now available. The next candidate in queue matches this seat:',
              style: const TextStyle(fontSize: 13, color: Colors.black87),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.person, size: 16, color: Color(0xFF881337)),
                      const SizedBox(width: 6),
                      Text(
                        candidate.studentName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.phone, size: 14, color: Colors.grey),
                      const SizedBox(width: 6),
                      Text(
                        candidate.studentPhone,
                        style: const TextStyle(fontSize: 12, color: Colors.black87),
                      ),
                    ],
                  ),
                  if (candidate.notes != null && candidate.notes!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Note: ${candidate.notes}',
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Would you like to assign this seat directly or alert them on WhatsApp?',
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Keep Available', style: TextStyle(color: Colors.grey)),
          ),
          OutlinedButton.icon(
            icon: const Icon(Icons.chat, size: 16, color: Color(0xFF25D366)),
            label: const Text('WhatsApp', style: TextStyle(color: Color(0xFF25D366))),
            onPressed: () async {
              await WaitingListPromotionService.launchWhatsAppNotification(
                entry: candidate,
                seatLabel: widget.seat.label,
                libraryName: libraryName,
                sectionName: widget.sectionId,
                libraryHelpline: libraryAsync.value?.phone,
                libraryAddress: libraryAsync.value?.address,
                adminTemplate: libraryAsync.value?.waitingListNotificationTemplate,
                context: context,
              );
            },
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF881337),
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.check_circle, size: 16),
            label: const Text('Assign Now'),
            onPressed: () async {
              Navigator.pop(dialogCtx);
              try {
                await promoService.assignSeatToCandidate(
                  libraryId: libraryId,
                  entry: candidate,
                  sectionId: widget.sectionId,
                  seatId: widget.seat.id,
                  seatLabel: widget.seat.label,
                );
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Seat ${widget.seat.label} assigned to ${candidate.studentName}!'),
                      backgroundColor: Colors.green[800],
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  AppErrorFormatter.showErrorSnackBar(context, e, actionContext: 'seat');
                }
              }
            },
          ),
        ],
      ),
    );
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

  void _showDirectSwapSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _SeatDirectSwapSheet(
        sourceSeat: widget.seat,
        sourceSectionId: widget.sectionId,
        studentName: studentName,
        onSwapped: () {
          if (mounted) {
            Navigator.pop(context);
          }
        },
      ),
    );
  }

  void _showAssignStudentSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _SeatAssignStudentSheet(
        seat: widget.seat,
        sectionId: widget.sectionId,
        onAssigned: () {
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

    final isOccupied = widget.seat.isOccupied || (studentName != null && studentName!.isNotEmpty);
    final effectiveStatus = isOccupied ? SeatStatus.occupied : widget.seat.effectiveStatus;

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
                            color: _getStatusColor(effectiveStatus)
                                .withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.event_seat,
                            color: _getStatusColor(effectiveStatus),
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
                        effectiveStatus.name.toUpperCase(),
                        style: TextStyle(
                          color: _getStatusColor(effectiveStatus),
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                      backgroundColor: _getStatusColor(effectiveStatus)
                          .withValues(alpha: 0.15),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Student info (if occupied)
                if (isOccupied) ...[
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
                      subtitle: widget.seat.reservationType == 'study_leave' || widget.seat.reservationType == 'freeze'
                          ? const Text('🟡 On Study Vacation / Leave (Pass Frozen)', style: TextStyle(color: Color(0xFFD97706), fontWeight: FontWeight.bold))
                          : const Text('Currently assigned'),
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
                    color: Colors.brown,
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
                      Icons.swap_horiz_rounded,
                      color: Colors.deepPurple.shade600,
                    ),
                    title: const Text('Direct Swap with Occupant (A ⇄ B)'),
                    subtitle: const Text('Exchange desks with another enrolled student'),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: _showDirectSwapSheet,
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
                    leading: const Icon(Icons.person_add_rounded, color: Color(0xFF10B981)),
                    title: const Text('Assign Student'),
                    subtitle: const Text('Pick and allocate an active student to this desk'),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: _showAssignStudentSheet,
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
        children: SeatStatus.values
            .where((status) => status != SeatStatus.occupied)
            .map((status) {
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
      await ref.read(seatRepositoryProvider).transferStudent(
        libraryId,
        widget.sourceSectionId,
        widget.sourceSeat.id,
        targetSection.id,
        targetSeat.id,
        widget.sourceSeat.studentId!,
      );

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
        AppErrorFormatter.showErrorSnackBar(context, e, actionContext: 'seat');
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

class _SeatDirectSwapSheet extends ConsumerStatefulWidget {
  final SeatModel sourceSeat;
  final String sourceSectionId;
  final String? studentName;
  final VoidCallback onSwapped;

  const _SeatDirectSwapSheet({
    required this.sourceSeat,
    required this.sourceSectionId,
    required this.studentName,
    required this.onSwapped,
  });

  @override
  ConsumerState<_SeatDirectSwapSheet> createState() => _SeatDirectSwapSheetState();
}

class _SeatDirectSwapSheetState extends ConsumerState<_SeatDirectSwapSheet> {
  bool _isSwapping = false;

  Future<void> _swapWith(SeatModel targetSeat, SectionModel targetSection, String? targetStudentName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Direct Seat Swap'),
        content: Text(
          'Directly swap desks between:\n\n'
          '• ${widget.studentName ?? "Student A"} (Seat ${widget.sourceSeat.label})\n'
          '  ⇅\n'
          '• ${targetStudentName ?? "Student B"} (Seat ${targetSeat.label} in ${targetSection.name})?\n\n'
          'Both students and seats will be updated atomically.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.deepPurple),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirm Swap'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final libraryId = ref.read(currentLibraryIdProvider);
    if (libraryId == null ||
        widget.sourceSeat.studentId == null ||
        targetSeat.studentId == null) {
      return;
    }

    setState(() => _isSwapping = true);
    try {
      await ref.read(seatRepositoryProvider).swapStudents(
        libraryId: libraryId,
        sectionAId: widget.sourceSectionId,
        seatAId: widget.sourceSeat.id,
        studentAId: widget.sourceSeat.studentId!,
        sectionBId: targetSection.id,
        seatBId: targetSeat.id,
        studentBId: targetSeat.studentId!,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Swapped Seat ${widget.sourceSeat.label} and Seat ${targetSeat.label} successfully!',
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
        widget.onSwapped();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to swap desks: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSwapping = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sectionsAsync = ref.watch(sectionsProvider);

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.3,
      maxChildSize: 0.85,
      expand: false,
      builder: (ctx, scrollController) {
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Direct Occupant Swap (A ⇄ B)',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Exchange Seat ${widget.sourceSeat.label} with another occupied desk',
                          style: const TextStyle(fontSize: 13, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(),
            if (_isSwapping)
              const Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('Executing atomic seat swap...'),
                    ],
                  ),
                ),
              )
            else
              Expanded(
                child: sectionsAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (err, _) => Center(child: Text('Error: $err')),
                  data: (sections) {
                    if (sections.isEmpty) {
                      return const Center(child: Text('No sections available.'));
                    }
                    return ListView.builder(
                      controller: scrollController,
                      itemCount: sections.length,
                      itemBuilder: (ctx, index) {
                        final section = sections[index];
                        return _SwapSectionTile(
                          section: section,
                          sourceSeatId: widget.sourceSeat.id,
                          onSeatSelected: (seat, targetName) => _swapWith(seat, section, targetName),
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

class _SwapSectionTile extends ConsumerWidget {
  final SectionModel section;
  final String sourceSeatId;
  final void Function(SeatModel seat, String? studentName) onSeatSelected;

  const _SwapSectionTile({
    required this.section,
    required this.sourceSeatId,
    required this.onSeatSelected,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final seatsAsync = ref.watch(seatsProvider(section.id));
    final studentsList = ref.watch(studentsStreamProvider).value ?? [];

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
                final occupiedSeats = seats
                    .where((s) =>
                        s.status == SeatStatus.occupied &&
                        s.id != sourceSeatId &&
                        s.studentId != null &&
                        s.studentId!.isNotEmpty &&
                        !s.id.startsWith('missing_'))
                    .toList()
                  ..sort(SeatHelper.compareSeats);

                if (occupiedSeats.isEmpty) {
                  return const Text(
                    'No other occupied seats in this section.',
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
                  children: occupiedSeats.map((seat) {
                    final student = studentsList.where((st) => st.id == seat.studentId).firstOrNull;
                    final studentName = student?.name ?? 'Student';
                    final shortName = studentName.split(' ').first;

                    return ActionChip(
                      avatar: const Icon(
                        Icons.swap_horiz_rounded,
                        size: 16,
                        color: Colors.deepPurple,
                      ),
                      label: Text(
                        '${seat.label} ($shortName)',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      onPressed: () => onSeatSelected(seat, studentName),
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

class _SeatAssignStudentSheet extends ConsumerStatefulWidget {
  final SeatModel seat;
  final String sectionId;
  final VoidCallback onAssigned;

  const _SeatAssignStudentSheet({
    required this.seat,
    required this.sectionId,
    required this.onAssigned,
  });

  @override
  ConsumerState<_SeatAssignStudentSheet> createState() => _SeatAssignStudentSheetState();
}

class _SeatAssignStudentSheetState extends ConsumerState<_SeatAssignStudentSheet> {
  String _searchQuery = '';
  bool _onlyUnassigned = true;
  bool _isAssigning = false;

  @override
  Widget build(BuildContext context) {
    final libraryId = ref.watch(currentLibraryIdProvider);
    final studentsAsync = ref.watch(studentsStreamProvider);
    final theme = Theme.of(context);

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.45,
      maxChildSize: 0.95,
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
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Row(
                children: [
                  const Icon(Icons.person_add_rounded, color: Color(0xFF10B981)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Assign Student to Desk #${widget.seat.label}',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Pick an enrolled student to allocate this seat',
                          style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Search student by name or phone...',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  isDense: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                ),
                onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _onlyUnassigned ? 'Showing unassigned students' : 'Showing all students',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  FilterChip(
                    label: const Text('Unassigned Only', style: TextStyle(fontSize: 11)),
                    selected: _onlyUnassigned,
                    onSelected: (val) => setState(() => _onlyUnassigned = val),
                  ),
                ],
              ),
            ),
            const Divider(height: 12),
            Expanded(
              child: studentsAsync.when(
                data: (allStudents) {
                  final filtered = allStudents.where((s) {
                    if (s.membershipStatus == MembershipStatus.archived ||
                        s.membershipStatus == MembershipStatus.blocked) {
                      return false;
                    }
                    if (_onlyUnassigned && (s.seatId != null && s.seatId!.isNotEmpty)) {
                      return false;
                    }
                    if (_searchQuery.isNotEmpty) {
                      final nameMatch = s.name.toLowerCase().contains(_searchQuery);
                      final phoneMatch = s.phone.contains(_searchQuery);
                      return nameMatch || phoneMatch;
                    }
                    return true;
                  }).toList();

                  if (filtered.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Text(
                          _searchQuery.isNotEmpty
                              ? 'No students found matching "$_searchQuery".'
                              : 'No unassigned students found. Toggle filter to reassign existing students.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.grey),
                        ),
                      ),
                    );
                  }

                  return ListView.separated(
                    controller: scrollController,
                    itemCount: filtered.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (ctx, idx) {
                      final student = filtered[idx];
                      final hasSeat = student.seatId != null && student.seatId!.isNotEmpty;

                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: student.gender == Gender.female
                              ? Colors.pink.shade100
                              : Colors.blue.shade100,
                          child: Text(
                            student.name.isNotEmpty ? student.name[0].toUpperCase() : '?',
                            style: TextStyle(
                              color: student.gender == Gender.female
                                  ? Colors.pink.shade800
                                  : Colors.blue.shade800,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        title: Text(student.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text(
                          '${student.phone} • ${hasSeat ? "Currently Desk #${student.seatId}" : "No desk"}',
                          style: TextStyle(
                            fontSize: 12,
                            color: hasSeat ? Colors.amber.shade800 : Colors.green.shade700,
                          ),
                        ),
                        trailing: _isAssigning
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : FilledButton.tonal(
                                onPressed: () => _assignToStudent(libraryId, student),
                                child: const Text('Assign'),
                              ),
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Error loading students: $e')),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _assignToStudent(String? libraryId, StudentModel student) async {
    if (libraryId == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Seat Assignment'),
        content: Text(
          'Assign ${student.name} to Desk #${widget.seat.label}?\n\n'
          '${(student.seatId != null && student.seatId!.isNotEmpty) ? "Note: Student will be moved from previous Desk #${student.seatId}." : ""}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirm Assignment'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isAssigning = true);
    try {
      await ref.read(seatRepositoryProvider).assignStudent(
        libraryId,
        widget.sectionId,
        widget.seat.id,
        student.id,
        studentUserId: student.userId,
      );

      if (mounted) {
        Navigator.pop(context);
        widget.onAssigned();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${student.name} assigned to Desk #${widget.seat.label}!'),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        AppErrorFormatter.showErrorSnackBar(context, e, actionContext: 'seat');
      }
    } finally {
      if (mounted) setState(() => _isAssigning = false);
    }
  }
}


