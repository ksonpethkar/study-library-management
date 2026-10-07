import 'package:flutter/material.dart';
import 'package:study_library/core/widgets/pressable_scale.dart';
import 'package:study_library/models/seat_model.dart';

class SeatTile extends StatelessWidget {
  final SeatModel seat;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const SeatTile({
    super.key,
    required this.seat,
    required this.isSelected,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    Color bgColor;
    switch (seat.status) {
      case SeatStatus.available:
        bgColor = Colors.green.shade200;
        break;
      case SeatStatus.occupied:
        bgColor = Colors.red.shade200;
        break;
      case SeatStatus.reserved:
        bgColor = Colors.amber.shade200;
        break;
      case SeatStatus.maintenance:
        bgColor = Colors.grey.shade400;
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
              ? Border.all(color: Theme.of(context).primaryColor, width: 3)
              : Border.all(color: Colors.black12),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Theme.of(context).primaryColor
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
                    color: Theme.of(context).primaryColor,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check, size: 10, color: Colors.white),
                ),
              ),
            Center(
              child: Text(
                seat.label,
                style: const TextStyle(fontWeight: FontWeight.bold),
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
                  color: Colors.black54,
                ),
              ),
            if (seat.status == SeatStatus.occupied && seat.studentId != null)
              const Positioned(
                bottom: 2,
                left: 0,
                right: 0,
                child: Center(
                  child: Text(
                    'Occ',
                    style: TextStyle(fontSize: 10, color: Colors.black54),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
