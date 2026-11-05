import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:study_library/core/providers/library_provider.dart';
import 'package:study_library/core/utils/app_haptics.dart';
import 'package:study_library/core/utils/seat_helper.dart';
import 'package:study_library/features/students/presentation/providers/student_providers.dart';
import 'package:study_library/models/student_model.dart';
import 'package:study_library/services/image_service.dart';

enum _PaymentPickerFilter { all, hasDues, expiringSoon }

/// High-performance Smart Payment Selection Hub.
/// Prioritizes defaulters and upcoming renewals at the top,
/// reads from instant local cache with Firestore network fallback,
/// and supports searching across Name, Phone, and Admission ID.
class SmartPaymentPickerSheet {
  static Future<void> show(BuildContext context, WidgetRef ref) async {
    final libraryId = ref.read(currentLibraryIdProvider);
    if (libraryId == null || libraryId.isEmpty) return;

    List<StudentModel> students = ref.read(studentsStreamProvider).value ?? [];

    // Offline / Cold-start fallback: if stream is loading or empty, fetch from Firestore
    if (students.isEmpty) {
      try {
        final snap = await FirebaseFirestore.instance
            .collection('libraries')
            .doc(libraryId)
            .collection('students')
            .get();
        students = snap.docs
            .map((d) => StudentModel.fromJson({...d.data(), 'id': d.id}))
            .toList();
      } catch (_) {
        // Fallback silently if offline and empty
      }
    }

    if (!context.mounted) return;

    if (students.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No students registered yet. Add a student first.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => _SmartPaymentPickerContent(students: students),
    );
  }
}

class _SmartPaymentPickerContent extends StatefulWidget {
  final List<StudentModel> students;
  const _SmartPaymentPickerContent({required this.students});

  @override
  State<_SmartPaymentPickerContent> createState() => _SmartPaymentPickerContentState();
}

class _SmartPaymentPickerContentState extends State<_SmartPaymentPickerContent> {
  String _searchQuery = '';
  _PaymentPickerFilter _selectedFilter = _PaymentPickerFilter.all;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final now = DateTime.now();
    final in7Days = now.add(const Duration(days: 7));

    final defaultersCount = widget.students
        .where((s) => (s.pendingDueBalance ?? 0) > 0)
        .length;

    final expiringCount = widget.students.where((s) {
      if (s.membershipStatus == MembershipStatus.grace) return true;
      if (s.membershipStatus == MembershipStatus.active && s.planEndDate != null) {
        return !s.planEndDate!.isBefore(now) && !s.planEndDate!.isAfter(in7Days);
      }
      return false;
    }).length;

    // 1. Filter students based on active filter tab
    List<StudentModel> list = widget.students.where((s) {
      if (_selectedFilter == _PaymentPickerFilter.hasDues) {
        return (s.pendingDueBalance ?? 0) > 0;
      }
      if (_selectedFilter == _PaymentPickerFilter.expiringSoon) {
        if (s.membershipStatus == MembershipStatus.grace) return true;
        if (s.membershipStatus == MembershipStatus.active && s.planEndDate != null) {
          return !s.planEndDate!.isBefore(now) && !s.planEndDate!.isAfter(in7Days);
        }
        return false;
      }
      return true;
    }).toList();

    // 2. Search filtering (Name, Phone, Admission Number, Seat Label)
    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.trim().toLowerCase();
      list = list.where((s) {
        final name = s.name.toLowerCase();
        final phone = s.phone.toLowerCase();
        final memNo = (s.membershipNumber ?? '').toLowerCase();
        final seat = (s.seatId ?? '').toLowerCase();
        return name.contains(q) || phone.contains(q) || memNo.contains(q) || seat.contains(q);
      }).toList();
    }

    // 3. Smart Prioritization Sorting
    list.sort((a, b) {
      final aDue = a.pendingDueBalance ?? 0.0;
      final bDue = b.pendingDueBalance ?? 0.0;

      // Defaulters strictly at the top (highest dues first)
      if (aDue > 0 && bDue <= 0) return -1;
      if (bDue > 0 && aDue <= 0) return 1;
      if (aDue > 0 && bDue > 0) return bDue.compareTo(aDue);

      // Next: Grace period / Expiring students
      final aIsGrace = a.membershipStatus == MembershipStatus.grace;
      final bIsGrace = b.membershipStatus == MembershipStatus.grace;
      if (aIsGrace && !bIsGrace) return -1;
      if (bIsGrace && !aIsGrace) return 1;

      // Alphabetical secondary sort
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      builder: (ctx, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Drag Handle
              Center(
                child: Container(
                  width: 44,
                  height: 4.5,
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),

              // Sheet Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.payments_rounded, color: Color(0xFF059669), size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Select Student for Payment',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              letterSpacing: -0.2,
                            ),
                          ),
                          Text(
                            defaultersCount > 0
                                ? '$defaultersCount student${defaultersCount > 1 ? "s have" : " has"} pending dues'
                                : 'All fees settled • Record fee or deposit',
                            style: TextStyle(
                              fontSize: 12,
                              color: defaultersCount > 0
                                  ? const Color(0xFFDC2626)
                                  : theme.colorScheme.onSurfaceVariant,
                              fontWeight: defaultersCount > 0 ? FontWeight.w600 : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      tooltip: 'Close',
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),

              const Divider(height: 12),

              // Search Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: TextField(
                  autofocus: false,
                  decoration: InputDecoration(
                    hintText: 'Search by Name, Phone, #CC ID, or Desk...',
                    hintStyle: TextStyle(fontSize: 13, color: theme.colorScheme.onSurfaceVariant),
                    prefixIcon: const Icon(Icons.search, size: 20),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () => setState(() => _searchQuery = ''),
                          )
                        : null,
                    isDense: true,
                    filled: true,
                    fillColor: isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: isDark ? Colors.white12 : const Color(0xFFE2E8F0)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: isDark ? Colors.white12 : const Color(0xFFE2E8F0)),
                    ),
                  ),
                  onChanged: (val) => setState(() => _searchQuery = val),
                ),
              ),

              // Filter Chips Ribbon
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    FilterChip(
                      selected: _selectedFilter == _PaymentPickerFilter.all,
                      label: Text('All (${widget.students.length})'),
                      onSelected: (_) => setState(() => _selectedFilter = _PaymentPickerFilter.all),
                      visualDensity: VisualDensity.compact,
                    ),
                    const SizedBox(width: 8),
                    FilterChip(
                      selected: _selectedFilter == _PaymentPickerFilter.hasDues,
                      label: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.warning_amber_rounded,
                            size: 14,
                            color: _selectedFilter == _PaymentPickerFilter.hasDues
                                ? Colors.red
                                : const Color(0xFFDC2626),
                          ),
                          const SizedBox(width: 4),
                          Text('Has Dues ($defaultersCount)'),
                        ],
                      ),
                      selectedColor: Colors.red.withValues(alpha: 0.15),
                      checkmarkColor: Colors.red,
                      onSelected: (_) => setState(() => _selectedFilter = _PaymentPickerFilter.hasDues),
                      visualDensity: VisualDensity.compact,
                    ),
                    const SizedBox(width: 8),
                    FilterChip(
                      selected: _selectedFilter == _PaymentPickerFilter.expiringSoon,
                      label: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.alarm_rounded,
                            size: 14,
                            color: _selectedFilter == _PaymentPickerFilter.expiringSoon
                                ? Colors.orange
                                : const Color(0xFFD97706),
                          ),
                          const SizedBox(width: 4),
                          Text('Due Soon ($expiringCount)'),
                        ],
                      ),
                      selectedColor: Colors.orange.withValues(alpha: 0.15),
                      checkmarkColor: Colors.orange,
                      onSelected: (_) => setState(() => _selectedFilter = _PaymentPickerFilter.expiringSoon),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
              ),

              const Divider(height: 1),

              // Student List
              Expanded(
                child: list.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.person_search_rounded, size: 48, color: theme.colorScheme.outline),
                            const SizedBox(height: 8),
                            Text(
                              _searchQuery.isNotEmpty
                                  ? 'No matching students found for "$_searchQuery"'
                                  : 'No students in this category',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        controller: scrollController,
                        itemCount: list.length,
                        separatorBuilder: (_, _) => const Divider(height: 1, indent: 72),
                        itemBuilder: (context, index) {
                          final student = list[index];
                          final due = student.pendingDueBalance ?? 0.0;
                          final hasDue = due > 0;
                          final seatLabel = SeatHelper.formatSeatLabel(
                            seatId: student.seatId,
                          );

                          Color statusColor;
                          switch (student.membershipStatus) {
                            case MembershipStatus.active:
                              statusColor = const Color(0xFF10B981);
                              break;
                            case MembershipStatus.grace:
                              statusColor = const Color(0xFFF59E0B);
                              break;
                            case MembershipStatus.expired:
                              statusColor = const Color(0xFFEF4444);
                              break;
                            default:
                              statusColor = const Color(0xFF64748B);
                          }

                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                            leading: Hero(
                              tag: 'payment-picker-avatar-${student.id}',
                              child: CircleAvatar(
                                radius: 22,
                                backgroundColor: hasDue
                                    ? Colors.red.withValues(alpha: 0.12)
                                    : theme.colorScheme.primaryContainer,
                                backgroundImage: ImageService.getImageProvider(student.photoUrl),
                                child: ImageService.getImageProvider(student.photoUrl) == null
                                    ? Text(
                                        student.name.isNotEmpty ? student.name[0].toUpperCase() : '?',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: hasDue ? Colors.red : theme.colorScheme.primary,
                                        ),
                                      )
                                    : null,
                              ),
                            ),
                            title: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    student.name,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (hasDue)
                                  Container(
                                    margin: const EdgeInsets.only(left: 6),
                                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFEF4444).withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.3)),
                                    ),
                                    child: Text(
                                      '₹${due.toStringAsFixed(0)} Due',
                                      style: const TextStyle(
                                        color: Color(0xFFDC2626),
                                        fontWeight: FontWeight.w900,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            subtitle: Row(
                              children: [
                                if (student.membershipNumber != null && student.membershipNumber!.isNotEmpty)
                                  Text(
                                    '#${student.membershipNumber} • ',
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                  ),
                                Text(
                                  student.phone,
                                  style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
                                ),
                                if (seatLabel != 'No Seat' && seatLabel.isNotEmpty) ...[
                                  Text(' • ', style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: statusColor.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      seatLabel,
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.bold,
                                        color: statusColor,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            trailing: const Icon(Icons.chevron_right, size: 20, color: Colors.grey),
                            onTap: () {
                              AppHaptics.light();
                              Navigator.pop(ctx);
                              context.push('/admin/payments/record/${student.id}');
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}
