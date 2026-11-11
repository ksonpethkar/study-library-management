import 'package:flutter/material.dart';
import 'package:study_library/core/widgets/pressable_scale.dart';
import 'package:study_library/models/seat_model.dart';
import 'package:study_library/models/student_model.dart';

class SeatTile extends StatelessWidget {
  final SeatModel seat;
  final bool isSelected;
  final Color? sectionColor;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final int columns;
  final String? studentName;
  final String? shiftName;
  final StudentModel? student;
  final bool isDimmed;
  final bool showGenderBadge;

  const SeatTile({
    super.key,
    required this.seat,
    required this.isSelected,
    this.sectionColor,
    required this.onTap,
    required this.onLongPress,
    this.columns = 6,
    this.studentName,
    this.shiftName,
    this.student,
    this.isDimmed = false,
    this.showGenderBadge = true,
  });

  /// Guaranteed display label that is NEVER blank
  String get displayLabel {
    final trimmed = seat.label.trim();
    if (trimmed.isNotEmpty) return trimmed;
    final numFromId = RegExp(r'\d+').stringMatch(seat.id);
    if (numFromId != null && numFromId.isNotEmpty) return numFromId;
    return '${seat.row * 10 + seat.col + 1}';
  }

  static String _formatShortName(String? name) {
    if (name == null || name.trim().isEmpty) return '';
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length == 1) {
      final s = parts.first;
      if (s.isEmpty) return '';
      return s[0].toUpperCase() + (s.length > 1 ? s.substring(1).toLowerCase() : '');
    }
    final first = parts.first;
    final capFirst = first.isNotEmpty
        ? first[0].toUpperCase() + (first.length > 1 ? first.substring(1).toLowerCase() : '')
        : '';
    final lastInitial = parts.last.isNotEmpty ? parts.last[0].toUpperCase() : '';
    return lastInitial.isNotEmpty ? '$capFirst $lastInitial.' : capFirst;
  }

  String _buildTooltipText() {
    final buffer = StringBuffer();
    final zoneStr = seat.genderRestriction == GenderRestriction.female
        ? 'Girls Reserved'
        : seat.genderRestriction == GenderRestriction.male
            ? 'Boys Reserved'
            : 'Any / Unisex';

    buffer.writeln('Desk #$displayLabel • $zoneStr');

    final bool isOnLeave = (seat.reservationType == 'study_leave' || seat.reservationType == 'freeze') ||
        (student != null && student!.isCurrentlyFrozen);

    if (isOnLeave) {
      buffer.writeln('Status: 🟡 Temporarily On Leave (Study Vacation)');
      final name = studentName ?? student?.name;
      if (name != null && name.isNotEmpty) {
        buffer.writeln('Student: $name');
      }
      if (student?.freezeEndDate != null) {
        final resume = student!.freezeEndDate!.add(const Duration(days: 1));
        final dateStr = '${resume.day.toString().padLeft(2, '0')}/${resume.month.toString().padLeft(2, '0')}/${resume.year}';
        buffer.write('Resumes On: $dateStr');
      } else {
        buffer.write('Membership pass frozen for study leave');
      }
      return buffer.toString().trim();
    }

    switch (seat.status) {
      case SeatStatus.available:
        buffer.write('Status: 🟢 Available (Ready for assignment)');
        break;
      case SeatStatus.occupied:
        buffer.writeln('Status: 🔴 Occupied');
        final name = studentName ?? student?.name;
        if (name != null && name.isNotEmpty) {
          buffer.writeln('Student: $name');
        }
        if (student?.phone != null && student!.phone.isNotEmpty) {
          buffer.writeln('Phone: ${student!.phone}');
        }
        if (student?.customPlanName != null || shiftName != null) {
          buffer.writeln('Plan: ${student?.customPlanName ?? shiftName ?? 'Standard'}');
        }
        if (student?.planEndDate != null) {
          final now = DateTime.now();
          final daysLeft = student!.planEndDate!.difference(now).inDays;
          final dateStr = '${student!.planEndDate!.day.toString().padLeft(2, '0')}/${student!.planEndDate!.month.toString().padLeft(2, '0')}/${student!.planEndDate!.year}';
          buffer.write('Expires: $dateStr (${daysLeft >= 0 ? '$daysLeft days left' : 'Expired'})');
        }
        break;
      case SeatStatus.reserved:
        buffer.writeln('Status: 🟡 Reserved');
        if (seat.reservedCandidateName != null && seat.reservedCandidateName!.isNotEmpty) {
          buffer.writeln('Applicant: ${seat.reservedCandidateName}');
        }
        if (seat.reservationExpiresAt != null) {
          final exp = seat.reservationExpiresAt!;
          buffer.write('Hold Until: ${exp.day}/${exp.month} ${exp.hour.toString().padLeft(2, '0')}:${exp.minute.toString().padLeft(2, '0')}');
        }
        break;
      case SeatStatus.maintenance:
        buffer.write('Status: ⚪ Under Maintenance');
        break;
    }
    return buffer.toString().trim();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bool isOnLeave = (seat.reservationType == 'study_leave' || seat.reservationType == 'freeze') ||
        (student != null && student!.isCurrentlyFrozen);

    Color bgColor;
    Color borderColor;
    Color textColor;

    if (isOnLeave) {
      bgColor = isDark ? const Color(0xFF382405) : const Color(0xFFFEF3C7);
      borderColor = isDark ? const Color(0xFFB45309) : const Color(0xFFF59E0B);
      textColor = isDark ? const Color(0xFFFDE68A) : const Color(0xFF92400E);
    } else {
      switch (seat.status) {
        case SeatStatus.available:
          bgColor = isDark ? const Color(0xFF1B382B) : const Color(0xFFE8F5E9);
          borderColor = isDark ? const Color(0xFF2E7D32) : const Color(0xFF81C784);
          textColor = isDark ? const Color(0xFFA5D6A7) : const Color(0xFF1B5E20);
          break;
        case SeatStatus.occupied:
          bgColor = isDark ? const Color(0xFF45141D) : const Color(0xFFFFEBEE);
          borderColor = isDark ? const Color(0xFFE53935) : const Color(0xFFE57373);
          textColor = isDark ? const Color(0xFFFF8A80) : const Color(0xFFB71C1C);
          break;
        case SeatStatus.reserved:
          bgColor = isDark ? const Color(0xFF3E3218) : const Color(0xFFFFF8E1);
          borderColor = isDark ? const Color(0xFFF57F17) : const Color(0xFFFFD54F);
          textColor = isDark ? const Color(0xFFFFE082) : const Color(0xFFE65100);
          break;
        case SeatStatus.maintenance:
          bgColor = isDark ? const Color(0xFF2C2C2C) : const Color(0xFFEEEEEE);
          borderColor = isDark ? const Color(0xFF757575) : const Color(0xFFBDBDBD);
          textColor = isDark ? const Color(0xFFE0E0E0) : const Color(0xFF212121);
          break;
      }
    }

    final isMaleOnly = showGenderBadge && seat.genderRestriction == GenderRestriction.male;
    final isFemaleOnly = showGenderBadge && seat.genderRestriction == GenderRestriction.female;
    final genderColor = isFemaleOnly ? const Color(0xFFE91E63) : const Color(0xFF1976D2);

    final tileWidget = PressableScale(
      onTap: onTap,
      onLongPress: onLongPress,
      scaleFactor: 0.92,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: isDimmed ? 0.22 : 1.0,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(columns <= 2 ? 14 : (columns <= 4 ? 10 : (columns >= 10 ? 6 : 8))),
            border: isSelected
                ? Border.all(color: Theme.of(context).colorScheme.primary, width: 2.5)
                : Border.all(
                    color: (isFemaleOnly || isMaleOnly)
                        ? genderColor.withValues(alpha: columns >= 10 ? 0.9 : 0.65)
                        : borderColor,
                    width: (isFemaleOnly || isMaleOnly) ? 1.5 : 1.2,
                  ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.45),
                      blurRadius: 8,
                      spreadRadius: 1.5,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : (seat.status == SeatStatus.available)
                    ? [
                        BoxShadow(
                          color: const Color(0xFF10B981).withValues(alpha: isDark ? 0.25 : 0.16),
                          blurRadius: 6,
                          offset: const Offset(0, 1.5),
                        ),
                      ]
                    : (seat.status == SeatStatus.reserved)
                        ? [
                            BoxShadow(
                              color: const Color(0xFFF59E0B).withValues(alpha: isDark ? 0.25 : 0.16),
                              blurRadius: 5,
                              offset: const Offset(0, 1.5),
                            ),
                          ]
                        : [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.03),
                              blurRadius: 2,
                              offset: const Offset(0, 1),
                            ),
                          ],
          ),
          child: _buildTileContent(context, isDark, textColor, genderColor, isMaleOnly, isFemaleOnly, isOnLeave: isOnLeave),
        ),
      ),
    );

    return Tooltip(
      waitDuration: const Duration(milliseconds: 250),
      showDuration: const Duration(seconds: 4),
      message: _buildTooltipText(),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white24, width: 0.8),
        boxShadow: const [
          BoxShadow(
            color: Colors.black54,
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      textStyle: const TextStyle(
        color: Colors.white,
        fontSize: 12,
        fontWeight: FontWeight.w600,
        height: 1.35,
      ),
      child: tileWidget,
    );
  }

  Widget _buildTileContent(
    BuildContext context,
    bool isDark,
    Color textColor,
    Color genderColor,
    bool isMaleOnly,
    bool isFemaleOnly, {
    bool isOnLeave = false,
  }) {
    // -------------------------------------------------------------
    // LEVEL 3: 2 COLUMNS (LARGE DETAILED STUDENT FOCUS CARD)
    // -------------------------------------------------------------
    if (columns <= 2) {
      return Padding(
        padding: const EdgeInsets.all(10.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Top Bar
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Seat $displayLabel',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.primary,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
                const Spacer(),
                if (isMaleOnly || isFemaleOnly)
                  Container(
                    margin: const EdgeInsets.only(right: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: genderColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isFemaleOnly ? Icons.female_rounded : Icons.male_rounded,
                          size: 12,
                          color: genderColor,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          isFemaleOnly ? 'Girls' : 'Boys',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: genderColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: textColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    isOnLeave ? 'ON LEAVE' : seat.status.name.toUpperCase(),
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      color: textColor,
                    ),
                  ),
                ),
              ],
            ),

            // Middle: Student info / Occupancy
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    studentName != null && studentName!.isNotEmpty
                        ? studentName!
                        : (seat.status == SeatStatus.occupied
                            ? 'Occupied'
                            : (seat.status == SeatStatus.reserved
                                ? 'Reserved'
                                : (seat.status == SeatStatus.maintenance ? 'Under Maintenance' : 'Vacant Seat'))),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    shiftName ?? (seat.status == SeatStatus.available ? 'Ready for assignment' : 'Active shift'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white60 : Colors.black54,
                    ),
                  ),
                ],
              ),
            ),

            // Bottom row: Selection checkmark or tap hint
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (isSelected)
                  Row(
                    children: [
                      Icon(Icons.check_circle_rounded, size: 14, color: Theme.of(context).colorScheme.primary),
                      const SizedBox(width: 4),
                      Text(
                        'Selected',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ],
                  )
                else
                  Text(
                    'Tap to view',
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white38 : Colors.black38,
                    ),
                  ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 10,
                  color: isDark ? Colors.white38 : Colors.black38,
                ),
              ],
            ),
          ],
        ),
      );
    }

    // -------------------------------------------------------------
    // LEVEL 2: 4 COLUMNS (COMFORTABLE SPACIOUS CARDS)
    // -------------------------------------------------------------
    if (columns <= 4) {
      return Padding(
        padding: const EdgeInsets.all(6.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  displayLabel,
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                    color: textColor,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                if (isMaleOnly || isFemaleOnly)
                  Icon(
                    isFemaleOnly ? Icons.female_rounded : Icons.male_rounded,
                    size: 13,
                    color: genderColor,
                  ),
              ],
            ),
            Text(
              studentName != null && studentName!.isNotEmpty
                  ? (isOnLeave ? '${_formatShortName(studentName)} (Leave)' : _formatShortName(studentName))
                  : (isOnLeave
                      ? 'On Leave'
                      : (seat.status == SeatStatus.occupied
                          ? 'Occupied'
                          : (seat.status == SeatStatus.reserved
                              ? 'Reserved'
                              : (seat.status == SeatStatus.maintenance ? 'Service' : 'Vacant')))),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 10,
                color: textColor,
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: textColor,
                    shape: BoxShape.circle,
                  ),
                ),
                if (isSelected)
                  Icon(Icons.check, size: 12, color: Theme.of(context).colorScheme.primary),
              ],
            ),
          ],
        ),
      );
    }

    // -------------------------------------------------------------
    // LEVEL 1: 6-8 COLUMNS (STANDARD MOBILE & LAPTOP COMFORT VIEW)
    // -------------------------------------------------------------
    if (columns < 10) {
      final isOccupied = seat.status == SeatStatus.occupied;
      final isReserved = seat.status == SeatStatus.reserved;
      final displayName = _formatShortName(studentName ?? student?.name);

      return Stack(
        children: [
          // Selection Checkmark
          if (isSelected)
            Positioned(
              top: 3,
              left: 3,
              child: Container(
                padding: const EdgeInsets.all(1.5),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check, size: 9, color: Colors.white),
              ),
            ),

          // High-Visibility Gender Badge
          if (isMaleOnly || isFemaleOnly)
            Positioned(
              top: 3,
              right: 3,
              child: Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: genderColor,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 2,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Center(
                  child: Icon(
                    isFemaleOnly ? Icons.female_rounded : Icons.male_rounded,
                    size: 10,
                    color: Colors.white,
                  ),
                ),
              ),
            ),

          // Center Prominent Seat Number and Student Name
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      displayLabel,
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: displayLabel.length > 3 ? 12 : (displayLabel.length > 2 ? 14 : 17),
                        color: textColor,
                        letterSpacing: -0.2,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                  if (isOnLeave) ...[
                    const SizedBox(height: 1.5),
                    Text(
                      displayName.isNotEmpty ? '$displayName (Leave)' : 'On Leave',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 9.0,
                        fontWeight: FontWeight.w800,
                        color: textColor,
                      ),
                    ),
                  ] else if (isOccupied && displayName.isNotEmpty) ...[
                    const SizedBox(height: 1.5),
                    Text(
                      displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        color: textColor,
                      ),
                    ),
                  ] else if (isReserved) ...[
                    const SizedBox(height: 1.5),
                    Text(
                      'Reserved',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: textColor,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      );
    }

    // -------------------------------------------------------------
    // LEVEL 0: 10 COLUMNS (PHYSICAL ROOM OVERVIEW - EXACT 10 COLUMNS)
    // -------------------------------------------------------------
    final isOccupied = seat.status == SeatStatus.occupied;
    final isReserved = seat.status == SeatStatus.reserved;
    final displayName = _formatShortName(studentName ?? student?.name);

    return Stack(
      children: [
        // Selection Checkmark
        if (isSelected)
          Positioned(
            top: 1,
            left: 1,
            child: Container(
              padding: const EdgeInsets.all(1),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check, size: 6, color: Colors.white),
            ),
          ),

        // Micro Gender Indicator Dot (Top-Right)
        if (isMaleOnly || isFemaleOnly)
          Positioned(
            top: 2,
            right: 2,
            child: Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: genderColor,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: genderColor.withValues(alpha: 0.5),
                    blurRadius: 1.5,
                  ),
                ],
              ),
            ),
          ),

        // Prominent Seat Number & Student Name/Label
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    displayLabel,
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: displayLabel.length > 3 ? 10 : (displayLabel.length > 2 ? 11.5 : 13.5),
                      color: textColor,
                      letterSpacing: -0.3,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
                if (isOnLeave) ...[
                  const SizedBox(height: 1),
                  Text(
                    'Leave',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.w800,
                      color: textColor,
                    ),
                  ),
                ] else if (isOccupied && displayName.isNotEmpty) ...[
                  const SizedBox(height: 1),
                  Text(
                    displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 8.5,
                      fontWeight: FontWeight.w800,
                      color: textColor,
                    ),
                  ),
                ] else if (isReserved) ...[
                  const SizedBox(height: 1),
                  Text(
                    'Res.',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.w700,
                      color: textColor,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}
