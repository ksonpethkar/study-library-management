import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:study_library/core/providers/library_provider.dart';
import 'package:study_library/features/seats/presentation/providers/seat_providers.dart';
import 'package:study_library/models/seat_model.dart';
import 'package:study_library/models/section_model.dart';
import 'package:study_library/core/utils/seat_helper.dart';
import 'package:study_library/core/constants/amenity_catalog.dart';
import 'package:study_library/core/widgets/pressable_scale.dart';
import '../providers/registration_provider.dart';
import 'package:study_library/services/form_config_service.dart';
import 'package:study_library/core/utils/error_formatter.dart';

class SeatSelectionScreen extends ConsumerStatefulWidget {
  const SeatSelectionScreen({super.key});

  @override
  ConsumerState<SeatSelectionScreen> createState() => _SeatSelectionScreenState();
}

class _SeatSelectionScreenState extends ConsumerState<SeatSelectionScreen> {
  String? _selectedSectionId;
  bool _deepLinkApplied = false;

  bool _isEligibleForGender({
    required String studentGenderStr,
    required SectionModel section,
    required SeatModel seat,
  }) {
    final gender = studentGenderStr.toLowerCase().trim();
    final sectionGender = (section.genderRestriction ?? 'any').toLowerCase().trim();
    final seatGender = seat.genderRestriction;

    if (gender == 'male' || gender == 'boy') {
      if (sectionGender == 'female' || sectionGender == 'girls') return false;
      if (seatGender == GenderRestriction.female) return false;
      return true;
    } else if (gender == 'female' || gender == 'girl') {
      if (sectionGender == 'male' || sectionGender == 'boys') return false;
      if (seatGender == GenderRestriction.male) return false;
      return true;
    }

    return true; // Other / unisex
  }

  void _showGenderRestrictionNotice({
    required BuildContext context,
    required String studentGenderStr,
    required SeatModel seat,
    required SectionModel section,
  }) {
    HapticFeedback.lightImpact();
    final isGirlOnly = seat.genderRestriction == GenderRestriction.female ||
        (section.genderRestriction ?? '').toLowerCase().contains('female') ||
        (section.genderRestriction ?? '').toLowerCase().contains('girls');
    final reservedFor = isGirlOnly ? 'Female / Girls' : 'Male / Boys';
    final accentColor = isGirlOnly ? Colors.pink.shade700 : Colors.blue.shade700;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SafeArea(
        child: Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 16,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              CircleAvatar(
                radius: 28,
                backgroundColor: accentColor.withValues(alpha: 0.12),
                child: Icon(Icons.lock_person_rounded, size: 30, color: accentColor),
              ),
              const SizedBox(height: 12),
              Text(
                'Reserved for $reservedFor',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Desk #${seat.label} in ${section.name} is reserved for $reservedFor students only.\n\n'
                'Please select an available desk designated for your group.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, height: 1.4, color: Colors.grey.shade700),
              ),
              const SizedBox(height: 20),
              FilledButton(
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  backgroundColor: accentColor,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Choose Another Desk'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _onDeskTap({
    required BuildContext context,
    required SeatModel seat,
    required SectionModel section,
    required String studentGenderStr,
    required bool isOccupied,
    required bool isReserved,
    required bool isMaintenance,
    required bool isGenderAllowed,
  }) async {
    if (isOccupied) {
      HapticFeedback.lightImpact();
      _showRestrictedDeskDialog(
        context: context,
        seat: seat,
        section: section,
        icon: Icons.lock_rounded,
        color: Colors.grey.shade700,
        title: '${SeatHelper.formatDeskLabel(rawLabel: seat.label)} Is Occupied',
        message:
            'This desk is already assigned to an enrolled student and cannot be booked or inquired about.\n\nPlease choose an available green desk or tap "Auto-Assign".',
      );
      return;
    }

    if (isReserved) {
      HapticFeedback.mediumImpact();
      final exp = seat.reservationExpiresAt;
      final remainingText = exp != null && exp.isAfter(DateTime.now())
          ? () {
              final mins = exp.difference(DateTime.now()).inMinutes;
              if (mins >= 60) return 'held for another ${(mins / 60).ceil()}h';
              return 'held for ${mins < 1 ? 1 : mins} min';
            }()
          : 'currently reserved';
      final noteLine = (seat.statusReason?.trim().isNotEmpty ?? false)
          ? '\nReason: ${seat.statusReason!.trim()}'
          : '';
      _showRestrictedDeskDialog(
        context: context,
        seat: seat,
        section: section,
        icon: Icons.timer_outlined,
        color: const Color(0xFFF59E0B),
        title: '${SeatHelper.formatDeskLabel(rawLabel: seat.label)} Is Reserved',
        message:
            'Another applicant has held this desk or management has reserved it ($remainingText).$noteLine\n\nPlease choose any other available green desk or tap "Auto-Assign".',
      );
      return;
    }

    if (isMaintenance) {
      HapticFeedback.lightImpact();
      final noteLine = (seat.statusReason?.trim().isNotEmpty ?? false)
          ? '\nReason: ${seat.statusReason!.trim()}'
          : '';
      _showRestrictedDeskDialog(
        context: context,
        seat: seat,
        section: section,
        icon: Icons.build_rounded,
        color: const Color(0xFFD97706),
        title: !section.isActive
            ? '${section.name} Under Maintenance'
            : '${SeatHelper.formatDeskLabel(rawLabel: seat.label)} Under Maintenance',
        message: !section.isActive
            ? 'This hall is temporarily closed for maintenance. No desks in ${section.name} can be selected right now.$noteLine'
            : 'This desk is temporarily out of service for maintenance and cannot be selected.$noteLine',
      );
      return;
    }

    if (!isGenderAllowed) {
      _showGenderRestrictionNotice(
        context: context,
        studentGenderStr: studentGenderStr,
        seat: seat,
        section: section,
      );
      return;
    }

    // Available & Eligible -> Acquire transactional soft-lock on sections/{secId}/seats/{seatId}
    HapticFeedback.selectionClick();
    final prevDetails = ref.read(selectedSeatDetailsProvider);
    final prevSeatId = prevDetails.seatId;
    final prevSectionId = prevDetails.sectionId;
    final libId = ref.read(currentLibraryIdProvider) ?? CurrentLibraryNotifier.defaultLibraryId;
    final curUser = FirebaseAuth.instance.currentUser;
    final applicantName = (ref.read(registrationNotifierProvider)['name']?.toString().trim().isNotEmpty == true)
        ? ref.read(registrationNotifierProvider)['name'].toString().trim()
        : (curUser?.displayName ?? 'Applicant');

    if (libId.isNotEmpty && curUser != null) {
      // Release previous hold owned by this user on the correct nested section seat doc
      if (prevSeatId != null &&
          prevSeatId.isNotEmpty &&
          prevSectionId != null &&
          prevSectionId.isNotEmpty &&
          (prevSeatId != seat.id || prevSectionId != section.id)) {
        ref.read(seatRepositoryProvider).releaseSoftLock(
          libraryId: libId,
          sectionId: prevSectionId,
          seatId: prevSeatId,
          expectedCandidateId: curUser.uid,
        ).ignore();
      }

      final configuredHoldMin = (ref.read(currentLibraryProvider).value?.seatHoldMinutes ?? 10).clamp(5, 30);
      try {
        await ref.read(seatRepositoryProvider).softLockSeat(
          libraryId: libId,
          sectionId: section.id,
          seatId: seat.id,
          candidateId: curUser.uid,
          candidateName: applicantName,
          duration: Duration(minutes: configuredHoldMin),
        );
      } catch (e) {
        if (!context.mounted) return;
        final errText = e.toString().replaceFirst('Exception: ', '');
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errText),
            backgroundColor: Colors.orange.shade800,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
    }

    if (!context.mounted) return;
    ref.read(selectedSeatDetailsProvider.notifier).selectSeat(
      seatId: seat.id,
      seatLabel: seat.label,
      sectionId: section.id,
      sectionName: section.name,
    );

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.greenAccent, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                curUser != null
                    ? 'Selected ${SeatHelper.formatDeskLabel(rawLabel: seat.label)} (Held for 10 mins)!'
                    : 'Selected ${SeatHelper.formatDeskLabel(rawLabel: seat.label)} (Will lock upon Sign-In & Submit)!',
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF1E293B),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showRestrictedDeskDialog({
    required BuildContext context,
    required SeatModel seat,
    required SectionModel section,
    required IconData icon,
    required Color color,
    required String title,
    required String message,
  }) {
    final library = ref.read(currentLibraryProvider).value;
    final amenities = AmenityCatalog.resolveEffectiveAmenities(
      library: library,
      section: section,
      seat: seat,
    );
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message, style: const TextStyle(fontSize: 13.5, height: 1.45)),
            if (amenities.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                'DESK AMENITIES',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: amenities.map((item) {
                  return Chip(
                    avatar: Icon(item.icon, size: 14),
                    label: Text(item.shortLabel, style: const TextStyle(fontSize: 11)),
                    visualDensity: VisualDensity.compact,
                  );
                }).toList(),
              ),
            ],
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Choose Another Desk'),
          ),
        ],
      ),
    );
  }

  void _onAutoAssignTap({required SectionModel section}) {
    HapticFeedback.mediumImpact();
    final prevDetails = ref.read(selectedSeatDetailsProvider);
    final prevSeatId = prevDetails.seatId;
    final prevSectionId = prevDetails.sectionId;
    final libId = ref.read(currentLibraryIdProvider) ?? CurrentLibraryNotifier.defaultLibraryId;
    final curUid = FirebaseAuth.instance.currentUser?.uid;

    // Release previously held seat on the correct nested section seat doc
    if (prevSeatId != null &&
        prevSeatId.isNotEmpty &&
        prevSectionId != null &&
        prevSectionId.isNotEmpty &&
        libId.isNotEmpty &&
        curUid != null &&
        curUid.isNotEmpty) {
      ref.read(seatRepositoryProvider).releaseSoftLock(
        libraryId: libId,
        sectionId: prevSectionId,
        seatId: prevSeatId,
        expectedCandidateId: curUid,
      ).ignore();
    }

    ref.read(selectedSeatDetailsProvider.notifier).selectAutoAssign(
      sectionId: section.id,
      sectionName: section.name,
    );

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.bolt_rounded, color: Colors.amber, size: 20),
            SizedBox(width: 8),
            Expanded(child: Text('Auto-Assign selected! Library management will assign the best desk for you.')),
          ],
        ),
        backgroundColor: const Color(0xFF1E293B),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final sectionsAsync = ref.watch(sectionsProvider);
    final regData = ref.watch(registrationNotifierProvider);
    final studentGenderStr = (regData['gender'] as String? ?? 'male').toLowerCase();
    final seatDetails = ref.watch(selectedSeatDetailsProvider);

    final formConfigAsync = ref.watch(formConfigStreamProvider);
    final isGovIdVisible = FormConfigService.isFieldVisible(formConfigAsync.value ?? [], 'govId');
    final stepTitle = isGovIdVisible ? 'Step 5 of 6: Choose Desk' : 'Step 4 of 5: Choose Desk';
    final progressValue = isGovIdVisible ? 5 / 6 : 4 / 5;

    return Scaffold(
      appBar: AppBar(
        title: Text(stepTitle),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => ref.read(registrationStepProvider.notifier).goTo(4),
        ),
      ),
      body: Column(
        children: [
          LinearProgressIndicator(value: progressValue),
          Expanded(
            child: sectionsAsync.when(
        loading: () => const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Loading live desk map...'),
            ],
          ),
        ),
        error: (err, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, color: Colors.red, size: 40),
              const SizedBox(height: 12),
              Text(
                AppErrorFormatter.toUserFriendly(err, actionContext: 'section'),
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => ref.refresh(sectionsProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (sections) {
          if (sections.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.chair_outlined, size: 48, color: Colors.grey),
                  const SizedBox(height: 12),
                  const Text('No study hall sections configured.'),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: () {
                      ref.read(selectedSeatDetailsProvider.notifier).selectAutoAssign();
                      ref.read(registrationStepProvider.notifier).goTo(6);
                    },
                    icon: const Icon(Icons.bolt_rounded),
                    label: const Text('Continue with Auto-Assign ➔'),
                  ),
                ],
              ),
            );
          }

          final deepLink = ref.watch(registrationDeepLinkProvider);
          if (_selectedSectionId == null &&
              deepLink.sectionId != null &&
              sections.any((s) => s.id == deepLink.sectionId)) {
            _selectedSectionId = deepLink.sectionId;
          }

          // Active section
          final currentSection = sections.firstWhere(
            (s) => s.id == _selectedSectionId,
            orElse: () => sections.first,
          );
          final library = ref.watch(currentLibraryProvider).value;
          final resolvedSectionAmenities = AmenityCatalog.resolveEffectiveAmenities(
            library: library,
            section: currentSection,
          );
          final currentSeats = ref.watch(seatsProvider(currentSection.id)).value ?? [];
          final hasBoySeats = currentSection.genderRestriction?.toLowerCase() == 'male' ||
              currentSeats.any((s) => s.genderRestriction == GenderRestriction.male);
          final hasGirlSeats = currentSection.genderRestriction?.toLowerCase() == 'female' ||
              currentSeats.any((s) => s.genderRestriction == GenderRestriction.female);

          final selectedSeat = currentSeats
              .where((s) => s.id == seatDetails.seatId || s.label == seatDetails.seatLabel)
              .firstOrNull;
          String deskCategoryText;
          if (selectedSeat != null) {
            if (selectedSeat.genderRestriction == GenderRestriction.female) {
              deskCategoryText = 'Girls Reserved Desk';
            } else if (selectedSeat.genderRestriction == GenderRestriction.male) {
              deskCategoryText = 'Boys Reserved Desk';
            } else {
              deskCategoryText = 'General Desk';
            }
          } else {
            deskCategoryText = 'General Desk';
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 800),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header Banner
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: isDark
                              ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
                              : [const Color(0xFFEDE9FE), const Color(0xFFDDD6FE)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark ? const Color(0xFF334155) : const Color(0xFFC4B5FD),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF334155) : Colors.white,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.event_seat_rounded,
                              color: isDark ? Colors.purple.shade200 : const Color(0xFF6D28D9),
                              size: 26,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Choose Your Study Desk',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Tap an available desk on the floor map, or choose Auto-Assign.',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Two Quick Option Cards: Map vs Auto-Assign
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () {
                              // Focus on map
                            },
                            borderRadius: BorderRadius.circular(14),
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: !seatDetails.isAutoAssign && seatDetails.hasSelection
                                    ? (isDark ? const Color(0xFF1E3A8A) : const Color(0xFFDBEAFE))
                                    : (isDark ? const Color(0xFF1E293B) : Colors.grey.shade100),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: !seatDetails.isAutoAssign && seatDetails.hasSelection
                                      ? const Color(0xFF3B82F6)
                                      : (isDark ? const Color(0xFF334155) : Colors.grey.shade300),
                                  width: !seatDetails.isAutoAssign && seatDetails.hasSelection ? 2 : 1,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.touch_app_rounded, size: 20, color: Color(0xFF2563EB)),
                                      const Spacer(),
                                      if (!seatDetails.isAutoAssign && seatDetails.hasSelection)
                                        const Icon(Icons.check_circle_rounded, size: 18, color: Color(0xFF2563EB)),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  const Text('Select on Map', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                  const SizedBox(height: 2),
                                  Text(
                                    !seatDetails.isAutoAssign && seatDetails.hasSelection
                                        ? SeatHelper.formatDeskLabel(rawLabel: seatDetails.seatLabel)
                                        : 'Tap desk in grid below',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: !seatDetails.isAutoAssign && seatDetails.hasSelection
                                          ? const Color(0xFF1D4ED8)
                                          : Colors.grey.shade600,
                                      fontWeight: !seatDetails.isAutoAssign && seatDetails.hasSelection
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: InkWell(
                            onTap: () => _onAutoAssignTap(section: currentSection),
                            borderRadius: BorderRadius.circular(14),
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: seatDetails.isAutoAssign
                                    ? (isDark ? const Color(0xFF451A03) : const Color(0xFFFEF3C7))
                                    : (isDark ? const Color(0xFF1E293B) : Colors.grey.shade100),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: seatDetails.isAutoAssign
                                      ? const Color(0xFFF59E0B)
                                      : (isDark ? const Color(0xFF334155) : Colors.grey.shade300),
                                  width: seatDetails.isAutoAssign ? 2 : 1,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.bolt_rounded, size: 20, color: Color(0xFFD97706)),
                                      const Spacer(),
                                      if (seatDetails.isAutoAssign)
                                        const Icon(Icons.check_circle_rounded, size: 18, color: Color(0xFFD97706)),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  const Text('⚡ Auto-Assign', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                  const SizedBox(height: 2),
                                  Text(
                                    seatDetails.isAutoAssign ? 'Selected (Staff assigns)' : 'Any best available desk',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: seatDetails.isAutoAssign ? const Color(0xFFB45309) : Colors.grey.shade600,
                                      fontWeight: seatDetails.isAutoAssign ? FontWeight.bold : FontWeight.normal,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Section Selector Tabs (if multiple sections exist)
                    if (sections.length > 1) ...[
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: sections.map((sec) {
                            final isSecSelected = sec.id == currentSection.id;
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ChoiceChip(
                                label: Text(sec.name),
                                selected: isSecSelected,
                                onSelected: (sel) {
                                  if (sel) setState(() => _selectedSectionId = sec.id);
                                },
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Map Card
                    Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(
                          color: isDark ? const Color(0xFF334155) : Colors.grey.shade300,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Section title & Legend
                            Row(
                              children: [
                                Icon(Icons.meeting_room_outlined, size: 20, color: theme.colorScheme.primary),
                                const SizedBox(width: 8),
                                Text(
                                  currentSection.name,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                                const Spacer(),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.green.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.circle, color: Color(0xFF10B981), size: 10),
                                      SizedBox(width: 6),
                                      Text(
                                        'LIVE MAP',
                                        style: TextStyle(
                                          color: Color(0xFF047857),
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),

                            // Compact Single-Line Horizontal Legend Strip (Saves vertical space on mobile)
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              physics: const BouncingScrollPhysics(),
                              child: Row(
                                children: [
                                  _buildLegendItem(color: const Color(0xFF10B981), label: 'Available'),
                                  const SizedBox(width: 12),
                                  _buildLegendItem(color: const Color(0xFFF59E0B), label: 'Held'),
                                  const SizedBox(width: 12),
                                  _buildLegendItem(color: const Color(0xFFEF4444), label: 'Occupied'),
                                  const SizedBox(width: 12),
                                  _buildLegendItem(color: const Color(0xFFD97706), label: 'Maint.'),
                                  const SizedBox(width: 12),
                                  _buildLegendItem(color: const Color(0xFF8B5CF6), label: 'Selected'),
                                  if (hasBoySeats) ...[
                                    const SizedBox(width: 12),
                                    _buildLegendItem(color: const Color(0xFF3B82F6), label: '♂ Boys', isIcon: true, icon: Icons.male_rounded),
                                  ],
                                  if (hasGirlSeats) ...[
                                    const SizedBox(width: 12),
                                    _buildLegendItem(color: const Color(0xFFEC4899), label: '♀ Girls', isIcon: true, icon: Icons.female_rounded),
                                  ],
                                ],
                              ),
                            ),
                            if (!currentSection.isActive) ...[
                              const SizedBox(height: 12),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.amber.shade100,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: Colors.amber.shade400),
                                ),
                                child: Text(
                                  '${currentSection.name} is currently under maintenance. Desks in this hall cannot be selected.',
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.amber.shade900),
                                ),
                              ),
                            ],
                            if (resolvedSectionAmenities.isNotEmpty) ...[
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: resolvedSectionAmenities.map((item) {
                                  return Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(item.icon, size: 12, color: theme.colorScheme.primary),
                                        const SizedBox(width: 4),
                                        Text(item.shortLabel, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ),
                            ],
                            const Divider(height: 24),

                            // Seats Grid
                            _buildSeatsGrid(
                              context: context,
                              theme: theme,
                              section: currentSection,
                              studentGenderStr: studentGenderStr,
                              seatDetails: seatDetails,
                              isDark: isDark,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Dedicated Selected Desk Confirmation Card
                    if (seatDetails.hasSelection && !seatDetails.isAutoAssign) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E1B4B) : const Color(0xFFEDE9FE),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isDark ? const Color(0xFF6D28D9) : const Color(0xFF8B5CF6),
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: const BoxDecoration(
                                color: Color(0xFF7C3AED),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.event_seat_rounded, color: Colors.white, size: 20),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Selected: ${SeatHelper.formatDeskLabel(rawLabel: seatDetails.seatLabel)}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                      color: isDark ? const Color(0xFFDDD6FE) : const Color(0xFF4C1D95),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${currentSection.name} • $deskCategoryText',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            TextButton.icon(
                              onPressed: () => _onAutoAssignTap(section: currentSection),
                              icon: const Icon(Icons.bolt_rounded, size: 16),
                              label: const Text('Auto-Assign', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                    ] else if (seatDetails.isAutoAssign) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF451A03) : const Color(0xFFFEF3C7),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: const Color(0xFFF59E0B),
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: const BoxDecoration(
                                color: Color(0xFFD97706),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.bolt_rounded, color: Colors.white, size: 20),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Auto-Assign Mode Active',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                      color: isDark ? const Color(0xFFFDE68A) : const Color(0xFF92400E),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Staff will allocate the optimal available desk upon registration review.',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isDark ? Colors.amber.shade200 : Colors.brown.shade700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                    const SizedBox(height: 8),

                    // Action Buttons (Back & Continue)
                    Row(
                      children: [
                        OutlinedButton(
                          onPressed: () => ref.read(registrationStepProvider.notifier).goTo(4),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('Back'),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: () {
                              if (!seatDetails.hasSelection) {
                                // Default to auto-assign if user clicks continue without selecting
                                _onAutoAssignTap(section: currentSection);
                              }
                              ref.read(registrationStepProvider.notifier).goTo(6);
                            },
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              backgroundColor: const Color(0xFF2563EB),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              elevation: 2,
                            ),
                            icon: const Icon(Icons.arrow_forward_rounded),
                            label: Text(
                              seatDetails.hasSelection
                                  ? 'Next: Review & Submit ➔'
                                  : 'Auto-Assign Desk & Continue ➔',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    ),
  ],
),
);
  }

  Widget _buildLegendItem({
    required Color color,
    required String label,
    bool isIcon = false,
    IconData? icon,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isIcon && icon != null)
          Icon(icon, size: 14, color: color)
        else
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.grey.shade700, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  Widget _buildSeatsGrid({
    required BuildContext context,
    required ThemeData theme,
    required SectionModel section,
    required String studentGenderStr,
    required SelectedSeatDetails seatDetails,
    required bool isDark,
  }) {
    final seatsAsync = ref.watch(seatsProvider(section.id));

    return seatsAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 30),
        child: Center(
          child: Text(
            AppErrorFormatter.toUserFriendly(e, actionContext: 'seat'),
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
        ),
      ),
      data: (seats) {
        if (seats.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 30),
            child: Center(child: Text('No desks configured in this section.')),
          );
        }

        final sortedSeats = [...seats]..sort(SeatHelper.compareSeats);
        final deepLink = ref.read(registrationDeepLinkProvider);
        if (!_deepLinkApplied &&
            deepLink.seatId != null &&
            deepLink.seatId!.isNotEmpty &&
            (deepLink.sectionId == null || deepLink.sectionId!.isEmpty || deepLink.sectionId == section.id)) {
          _deepLinkApplied = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            final targetNum = SeatHelper.formatSeatNumberOnly(rawLabel: deepLink.seatId);
            final matched = sortedSeats.where((s) {
              if (s.id == deepLink.seatId || s.label == deepLink.seatId) return true;
              final sNum = SeatHelper.formatSeatNumberOnly(seatId: s.id, rawLabel: s.label, cols: section.cols);
              return targetNum.isNotEmpty && sNum == targetNum;
            }).firstOrNull;
            if (matched == null) return;
            final curUid = FirebaseAuth.instance.currentUser?.uid;
            final isHeldByMe = curUid != null && curUid.isNotEmpty && matched.reservedCandidateId == curUid;
            final mOccupied = matched.isOccupied;
            final mReserved = matched.effectiveStatus == SeatStatus.reserved && !isHeldByMe;
            final mMaint = !section.isActive || matched.effectiveStatus == SeatStatus.maintenance;
            final mGender = _isEligibleForGender(
              studentGenderStr: studentGenderStr,
              section: section,
              seat: matched,
            );
            _onDeskTap(
              context: context,
              seat: matched,
              section: section,
              studentGenderStr: studentGenderStr,
              isOccupied: mOccupied,
              isReserved: mReserved,
              isMaintenance: mMaint,
              isGenderAllowed: mGender,
            );
          });
        }
        final screenWidth = MediaQuery.of(context).size.width;
        final crossAxisCount = section.cols > 0 ? section.cols : 10;
        // On mobile phones (< 500px), a 10-column grid requires at least 44px per desk (440px total)
        // so that desk numbers and tap targets are comfortable, readable, and meet touch-target guidelines.
        final minGridWidth = math.max(360.0, crossAxisCount * 44.0);
        final bool isSmallScreen = screenWidth < (minGridWidth + 48);

        final grid = GridView.builder(
          key: ValueKey('grid_${section.id}_${sortedSeats.length}'),
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: sortedSeats.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 1.0,
          ),
          itemBuilder: (context, index) {
            final seat = sortedSeats[index];
            final curUid = FirebaseAuth.instance.currentUser?.uid;
            final isOccupied = seat.isOccupied;
            final isHeldByMe = curUid != null &&
                curUid.isNotEmpty &&
                seat.reservedCandidateId == curUid;
            final isReserved = seat.effectiveStatus == SeatStatus.reserved && !isHeldByMe;
            final isMaintenance = !section.isActive || seat.effectiveStatus == SeatStatus.maintenance;
            final isSelected = !seatDetails.isAutoAssign &&
                (seat.id == seatDetails.seatId || seat.label == seatDetails.seatLabel);

            final isGenderAllowed = _isEligibleForGender(
              studentGenderStr: studentGenderStr,
              section: section,
              seat: seat,
            );

            final isGirlSeat = seat.genderRestriction == GenderRestriction.female ||
                (section.genderRestriction?.toLowerCase() == 'female');
            final isBoySeat = seat.genderRestriction == GenderRestriction.male ||
                (section.genderRestriction?.toLowerCase() == 'male');

            // Visual Colors
            Color bgColor;
            Color borderColor;
            Color textColor;
            double borderWidth = 1.0;
            List<BoxShadow>? shadows;

            if (isSelected) {
              bgColor = const Color(0xFF7C3AED);
              borderColor = const Color(0xFFC4B5FD);
              borderWidth = 2.0;
              textColor = Colors.white;
              shadows = [
                BoxShadow(
                  color: const Color(0xFF7C3AED).withValues(alpha: 0.45),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ];
            } else if (isOccupied) {
              bgColor = isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9);
              borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1);
              textColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
            } else if (isReserved) {
              bgColor = isDark ? const Color(0xFF451A03) : const Color(0xFFFEF3C7);
              borderColor = const Color(0xFFF59E0B);
              textColor = const Color(0xFFB45309);
              borderWidth = 1.2;
            } else if (isMaintenance) {
              bgColor = isDark ? const Color(0xFF451A03) : const Color(0xFFFEF3C7);
              borderColor = const Color(0xFFF59E0B);
              textColor = const Color(0xFFB45309);
            } else if (!isGenderAllowed) {
              bgColor = isDark ? const Color(0xFF18181B) : const Color(0xFFF8FAFC);
              borderColor = isDark ? const Color(0xFF27272A) : const Color(0xFFE2E8F0);
              textColor = isDark ? const Color(0xFF71717A) : const Color(0xFF94A3B8);
            } else if (isGirlSeat) {
              // Available & Eligible Girls Desk
              bgColor = isDark ? const Color(0xFF371B28) : const Color(0xFFFDF2F8);
              borderColor = const Color(0xFFF472B6);
              textColor = isDark ? const Color(0xFFF472B6) : const Color(0xFFBE185D);
              borderWidth = 1.4;
            } else if (isBoySeat) {
              // Available & Eligible Boys Desk
              bgColor = isDark ? const Color(0xFF1E3A8A) : const Color(0xFFEFF6FF);
              borderColor = const Color(0xFF3B82F6);
              textColor = isDark ? const Color(0xFF93C5FD) : const Color(0xFF1D4ED8);
              borderWidth = 1.4;
            } else {
              // Available & Eligible General Desk
              bgColor = isDark ? const Color(0xFF064E3B) : const Color(0xFFECFDF5);
              borderColor = const Color(0xFF10B981);
              textColor = isDark ? const Color(0xFF6EE7B7) : const Color(0xFF065F46);
              borderWidth = 1.4;
            }

            // High-legibility seat number (NO '#' prefix inside tile to maximize size and clarity)
            final seatNumber = SeatHelper.formatSeatNumberOnly(
              seatId: seat.id,
              rawLabel: seat.label,
              cols: section.cols,
            );

            return PressableScale(
              onTap: () => _onDeskTap(
                context: context,
                seat: seat,
                section: section,
                studentGenderStr: studentGenderStr,
                isOccupied: isOccupied,
                isReserved: isReserved,
                isMaintenance: isMaintenance,
                isGenderAllowed: isGenderAllowed,
              ),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: borderColor, width: borderWidth),
                  boxShadow: shadows,
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Clean, prominent seat number (FittedBox ensures it scales down if 3 digits)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2.0),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          seatNumber,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            color: textColor,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                    ),

                    // Top-right corner indicator (small, unobtrusive, does not collide with number)
                    if (isSelected)
                      Positioned(
                        top: 2,
                        right: 2,
                        child: Container(
                          padding: const EdgeInsets.all(1.5),
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.check_rounded,
                            size: 8,
                            color: Color(0xFF7C3AED),
                          ),
                        ),
                      )
                    else if (isOccupied)
                      Positioned(
                        top: 2,
                        right: 2,
                        child: Icon(Icons.lock_rounded, size: 9, color: textColor),
                      )
                    else if (isReserved)
                      Positioned(
                        top: 2,
                        right: 2,
                        child: Icon(Icons.timer_rounded, size: 9, color: textColor),
                      )
                    else if (isMaintenance)
                      Positioned(
                        top: 2,
                        right: 2,
                        child: Icon(Icons.build_rounded, size: 9, color: textColor),
                      )
                    else if (!isGenderAllowed)
                      Positioned(
                        top: 2,
                        right: 2,
                        child: Icon(
                          isGirlSeat ? Icons.female_rounded : Icons.male_rounded,
                          size: 9,
                          color: isGirlSeat ? const Color(0xFFEC4899) : const Color(0xFF3B82F6),
                        ),
                      )
                    else if (isGirlSeat)
                      Positioned(
                        top: 2,
                        right: 2,
                        child: Icon(
                          Icons.female_rounded,
                          size: 9,
                          color: const Color(0xFFEC4899).withValues(alpha: 0.8),
                        ),
                      )
                    else if (isBoySeat)
                      Positioned(
                        top: 2,
                        right: 2,
                        child: Icon(
                          Icons.male_rounded,
                          size: 9,
                          color: const Color(0xFF3B82F6).withValues(alpha: 0.8),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        );

        if (!isSmallScreen) {
          return grid;
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.pinch_rounded, size: 14, color: theme.colorScheme.primary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Pinch or swipe horizontally to inspect all ${sortedSeats.length} desks',
                      style: TextStyle(
                        fontSize: 11,
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            InteractiveViewer(
              minScale: 0.7,
              maxScale: 2.5,
              clipBehavior: Clip.none,
              boundaryMargin: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              child: SizedBox(
                width: minGridWidth,
                child: grid,
              ),
            ),
          ],
        );
      },
    );
  }
}
