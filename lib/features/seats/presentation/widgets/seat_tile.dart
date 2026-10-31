import 'package:flutter/material.dart';
import 'package:study_library/core/widgets/pressable_scale.dart';
import 'package:study_library/models/seat_model.dart';

class SeatTile extends StatelessWidget {
  final SeatModel seat;
  final bool isSelected;
  final Color? sectionColor;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final int columns;
  final String? studentName;
  final String? shiftName;

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
  });

  /// Guaranteed display label that is NEVER blank
  String get displayLabel {
    final trimmed = seat.label.trim();
    if (trimmed.isNotEmpty) return trimmed;
    final numFromId = RegExp(r'\d+').stringMatch(seat.id);
    if (numFromId != null && numFromId.isNotEmpty) return numFromId;
    return '${seat.row * 10 + seat.col + 1}';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Color bgColor;
    Color borderColor;
    Color textColor;

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

    final isMaleOnly = seat.genderRestriction == GenderRestriction.male;
    final isFemaleOnly = seat.genderRestriction == GenderRestriction.female;
    final genderColor = isFemaleOnly ? const Color(0xFFE91E63) : const Color(0xFF1976D2);

    return PressableScale(
      onTap: onTap,
      onLongPress: onLongPress,
      scaleFactor: 0.92,
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
        child: _buildTileContent(context, isDark, textColor, genderColor, isMaleOnly, isFemaleOnly),
      ),
    );
  }

  Widget _buildTileContent(
    BuildContext context,
    bool isDark,
    Color textColor,
    Color genderColor,
    bool isMaleOnly,
    bool isFemaleOnly,
  ) {
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
                    seat.status.name.toUpperCase(),
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
                  ? studentName!.split(' ').first
                  : (seat.status == SeatStatus.occupied
                      ? 'Occupied'
                      : (seat.status == SeatStatus.reserved
                          ? 'Reserved'
                          : (seat.status == SeatStatus.maintenance ? 'Service' : 'Vacant'))),
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
    // LEVEL 1: 6 COLUMNS (STANDARD MOBILE COMFORT VIEW)
    // -------------------------------------------------------------
    if (columns < 10) {
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

          // Center Prominent Seat Number (High Visibility & Never overflows)
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              child: FittedBox(
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
            ),
          ),

          // High-Visibility Gender Badge (Zero collision with center number!)
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

          // Status dot indicator at bottom
          if (seat.status == SeatStatus.occupied || seat.status == SeatStatus.reserved)
            Positioned(
              bottom: 3,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  width: 4,
                  height: 4,
                  decoration: BoxDecoration(
                    color: textColor,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
        ],
      );
    }

    // -------------------------------------------------------------
    // LEVEL 0: 10 COLUMNS (MICRO OVERVIEW - ALL 60 SEATS IN 1 SCREEN)
    // -------------------------------------------------------------
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

        // Prominent Center Seat Number (Clean, sharp, completely visible!)
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2.0),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                displayLabel,
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: displayLabel.length > 3 ? 10.5 : (displayLabel.length > 2 ? 12 : 14),
                  color: textColor,
                  letterSpacing: -0.3,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ),
        ),

        // Status indicator dot at bottom for 10-column view
        if (seat.status == SeatStatus.occupied || seat.status == SeatStatus.reserved)
          Positioned(
            bottom: 2,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                width: 3.5,
                height: 3.5,
                decoration: BoxDecoration(
                  color: textColor,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),

        // Micro Gender Indicator Dot (Top-Right, NEVER collides with number!)
        if (isMaleOnly || isFemaleOnly)
          Positioned(
            top: 2,
            right: 2,
            child: Container(
              width: 5,
              height: 5,
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
      ],
    );
  }
}
