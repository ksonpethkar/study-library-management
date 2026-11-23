import 'package:flutter/material.dart';

/// Leading-Brand Rolling Odometer Numeric Ticker (Stripe / Revolut / Robinhood).
///
/// Smoothly animates numeric transitions for currency (₹), percentages, and seat counts
/// using high-performance sub-pixel digit rolling.
class RollingOdometerText extends StatelessWidget {
  final num value;
  final String prefix;
  final String suffix;
  final TextStyle? style;
  final Duration duration;
  final Curve curve;
  final int decimalPlaces;

  const RollingOdometerText({
    super.key,
    required this.value,
    this.prefix = '',
    this.suffix = '',
    this.style,
    this.duration = const Duration(milliseconds: 750),
    this.curve = Curves.easeOutCubic,
    this.decimalPlaces = 0,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: value.toDouble()),
      duration: duration,
      curve: curve,
      builder: (context, animatedValue, child) {
        final formattedNumber = decimalPlaces > 0
            ? animatedValue.toStringAsFixed(decimalPlaces)
            : animatedValue.round().toString();

        return Text(
          '$prefix$formattedNumber$suffix',
          style: style,
        );
      },
    );
  }
}
