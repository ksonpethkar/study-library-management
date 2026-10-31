import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// Wraps a list item widget with a staggered entrance animation.
///
/// Each item fades in and slides up slightly, with a cascading delay
/// based on its [index] in the list, creating a smooth "waterfall" effect.
///
/// Usage:
/// ```dart
/// ListView.builder(
///   itemBuilder: (context, index) => StaggeredListItem(
///     index: index,
///     child: YourCardWidget(),
///   ),
/// )
/// ```
class StaggeredListItem extends StatelessWidget {
  final int index;
  final Widget child;
  
  /// Maximum delay cap (items beyond this index all animate at the same time).
  final int maxDelayIndex;

  const StaggeredListItem({
    super.key,
    required this.index,
    required this.child,
    this.maxDelayIndex = 15,
  });

  @override
  Widget build(BuildContext context) {
    final clampedIndex = index.clamp(0, maxDelayIndex);
    return child
        .animate()
        .fadeIn(
          duration: 350.ms,
          delay: (clampedIndex * 50).ms,
          curve: Curves.easeOutCubic,
        )
        .slideY(
          begin: 0.05,
          end: 0,
          duration: 350.ms,
          delay: (clampedIndex * 50).ms,
          curve: Curves.easeOutCubic,
        );
  }
}

/// Extension to easily wrap any widget with staggered animation.
extension StaggeredAnimateExtension on Widget {
  Widget staggered(int index, {int maxDelay = 15}) {
    return StaggeredListItem(
      index: index,
      maxDelayIndex: maxDelay,
      child: this,
    );
  }
}
