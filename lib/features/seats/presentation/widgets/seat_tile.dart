import 'package:flutter/material.dart';
import 'package:study_library/core/widgets/pressable_scale.dart';
import 'package:study_library/models/seat_model.dart';

class SeatTile extends StatelessWidget {
  final SeatModel seat;
  final bool isSelected;
  final Color? sectionColor;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const SeatTile({
    super.key,
    required this.seat,
    required this.isSelected,
    this.sectionColor,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Color bgColor;
    Color borderColor;
    Color textColor;

    switch (seat.status) {
      case SeatStatus.available:
        bgColor = isDark ? const Color(0xFF1B382B) : const Color(0xFFE8F5E9);
        borderColor = sectionColor != null
            ? sectionColor!.withValues(alpha: 0.7)
            : (isDark ? const Color(0xFF2E7D32) : const Color(0xFF81C784));
        textColor = isDark ? const Color(0xFFA5D6A7) : const Color(0xFF1B5E20);
        break;
      case SeatStatus.occupied:
        bgColor = isDark ? const Color(0xFF3E1D24) : const Color(0xFFFFEBEE);
        borderColor = isDark ? const Color(0xFFC62828) : const Color(0xFFEF9A9A);
        textColor = isDark ? const Color(0xFFEF9A9A) : const Color(0xFFB71C1C);
        break;
      case SeatStatus.reserved:
        bgColor = isDark ? const Color(0xFF3E3218) : const Color(0xFFFFF8E1);
        borderColor = isDark ? const Color(0xFFF57F17) : const Color(0xFFFFD54F);
        textColor = isDark ? const Color(0xFFFFE082) : const Color(0xFFE65100);
        break;
      case SeatStatus.maintenance:
        bgColor = isDark ? const Color(0xFF2B2B2B) : const Color(0xFFEEEEEE);
        borderColor = isDark ? const Color(0xFF616161) : const Color(0xFFBDBDBD);
        textColor = isDark ? const Color(0xFF9E9E9E) : const Color(0xFF616161);
        break;
    }

    return PressableScale(
      onTap: onTap,
      onLongPress: onLongPress,
      scaleFactor: 0.94,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(8),
          border: isSelected
              ? Border.all(color: Theme.of(context).colorScheme.primary, width: 2.5)
              : Border.all(color: borderColor, width: 1.2),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Theme.of(context).colorScheme.primary
                        .withValues(alpha: 0.4),
                    blurRadius: 4,
                  ),
                ]
              : [],
        ),
        child: Stack(
          children: [
            if (isSelected)
              Positioned(
                top: 2,
                left: 2,
                child: Container(
                  padding: const EdgeInsets.all(1),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check, size: 10, color: Colors.white),
                ),
              ),
            Center(
              child: Text(
                seat.label,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: textColor,
                ),
              ),
            ),
            if (seat.genderRestriction != GenderRestriction.any)
              Positioned(
                top: 2,
                right: 2,
                child: Icon(
                  seat.genderRestriction == GenderRestriction.male
                      ? Icons.male
                      : Icons.female,
                  size: 12,
                  color: textColor.withValues(alpha: 0.8),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
