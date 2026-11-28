import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Item descriptor for [CozySegmentedTabs].
class CozySegmentItem<T> {
  final T value;
  final String label;
  final IconData? icon;

  const CozySegmentItem({
    required this.value,
    required this.label,
    this.icon,
  });
}

/// Animated sliding-pill segmented tab bar (CRED / Linear / iOS style).
/// Respects [MediaQuery.disableAnimationsOf] for reduced-motion accessibility.
class CozySegmentedTabs<T> extends StatelessWidget {
  final List<CozySegmentItem<T>> items;
  final T selectedValue;
  final ValueChanged<T> onChanged;

  const CozySegmentedTabs({
    super.key,
    required this.items,
    required this.selectedValue,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final disableAnim = MediaQuery.disableAnimationsOf(context);
    final duration = disableAnim ? Duration.zero : const Duration(milliseconds: 220);

    final selectedIndex = items.indexWhere((e) => e.value == selectedValue);
    final safeIndex = selectedIndex < 0 ? 0 : selectedIndex;
    final count = items.length;
    final alignX = count <= 1 ? 0.0 : -1.0 + (2.0 * safeIndex / (count - 1));

    return Container(
      height: 42,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.45)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final pillWidth = constraints.maxWidth / count;
          return Stack(
            children: [
              AnimatedAlign(
                duration: duration,
                curve: Curves.easeOutCubic,
                alignment: Alignment(alignX, 0),
                child: Container(
                  width: pillWidth,
                  height: double.infinity,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(9),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.07),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              ),
              Row(
                children: items.map((item) {
                  final isSelected = item.value == selectedValue;
                  return Expanded(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(9),
                      onTap: () {
                        if (!isSelected) {
                          HapticFeedback.selectionClick();
                          onChanged(item.value);
                        }
                      },
                      child: Center(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (item.icon != null) ...[
                                  Icon(
                                    item.icon,
                                    size: 14,
                                    color: isSelected
                                        ? theme.colorScheme.primary
                                        : theme.colorScheme.onSurfaceVariant,
                                  ),
                                  const SizedBox(width: 4),
                                ],
                                AnimatedDefaultTextStyle(
                                  duration: duration,
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                    color: isSelected
                                        ? theme.colorScheme.primary
                                        : theme.colorScheme.onSurfaceVariant,
                                  ),
                                  child: Text(item.label, maxLines: 1),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          );
        },
      ),
    );
  }
}
