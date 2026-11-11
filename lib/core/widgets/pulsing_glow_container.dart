import 'dart:ui';
import 'package:flutter/material.dart';

/// A high-performance, battery-friendly container with an ambient breathing
/// glow effect inspired by leading productivity dashboards (Linear, Stripe, Airbnb).
///
/// Automatically pauses animation when [isPulsing] is false.
class PulsingGlowContainer extends StatefulWidget {
  final Widget child;
  final bool isPulsing;
  final Color glowColor;
  final Color? backgroundColor;
  final BorderRadius? borderRadius;
  final EdgeInsetsGeometry? padding;
  final Duration duration;
  final double minBlur;
  final double maxBlur;
  final double minSpread;
  final double maxSpread;
  final double borderWidth;
  final VoidCallback? onTap;

  const PulsingGlowContainer({
    super.key,
    required this.child,
    this.isPulsing = true,
    this.glowColor = const Color(0xFFF59E0B),
    this.backgroundColor,
    this.borderRadius,
    this.padding,
    this.duration = const Duration(milliseconds: 1700),
    this.minBlur = 4.0,
    this.maxBlur = 16.0,
    this.minSpread = 0.5,
    this.maxSpread = 2.0,
    this.borderWidth = 1.3,
    this.onTap,
  });

  @override
  State<PulsingGlowContainer> createState() => _PulsingGlowContainerState();
}

class _PulsingGlowContainerState extends State<PulsingGlowContainer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);

    if (widget.isPulsing) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant PulsingGlowContainer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPulsing != oldWidget.isPulsing) {
      if (widget.isPulsing) {
        if (!_controller.isAnimating) _controller.repeat(reverse: true);
      } else {
        _controller.stop();
        _controller.reset();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final radius = widget.borderRadius ?? BorderRadius.circular(12);

    Widget content = Container(
      padding: widget.padding,
      child: widget.child,
    );

    if (widget.onTap != null) {
      content = InkWell(
        onTap: widget.onTap,
        borderRadius: radius,
        child: content,
      );
    }

    if (!widget.isPulsing) {
      return Container(
        decoration: BoxDecoration(
          color: widget.backgroundColor,
          borderRadius: radius,
          border: Border.all(
            color: widget.glowColor.withValues(alpha: 0.25),
            width: widget.borderWidth,
          ),
        ),
        child: content,
      );
    }

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        final progress = _animation.value;
        final blur = lerpDouble(widget.minBlur, widget.maxBlur, progress)!;
        final spread = lerpDouble(widget.minSpread, widget.maxSpread, progress)!;
        final glowAlpha = lerpDouble(0.12, 0.40, progress)!;
        final borderAlpha = lerpDouble(0.35, 0.90, progress)!;

        return Container(
          decoration: BoxDecoration(
            color: widget.backgroundColor,
            borderRadius: radius,
            border: Border.all(
              color: widget.glowColor.withValues(alpha: borderAlpha),
              width: widget.borderWidth,
            ),
            boxShadow: [
              BoxShadow(
                color: widget.glowColor.withValues(alpha: glowAlpha),
                blurRadius: blur,
                spreadRadius: spread,
              ),
            ],
          ),
          child: child,
        );
      },
      child: content,
    );
  }
}

/// A live radar beacon dot with an animated expanding circular ripple wave.
///
/// Used by leading live operations dashboards (Linear, Swiggy, Uber) to
/// communicate real-time waiting activity without taking up large screen space.
class LiveRadarDot extends StatefulWidget {
  final Color color;
  final double size;
  final Duration duration;

  const LiveRadarDot({
    super.key,
    this.color = const Color(0xFFF59E0B),
    this.size = 8.0,
    this.duration = const Duration(milliseconds: 1500),
  });

  @override
  State<LiveRadarDot> createState() => _LiveRadarDotState();
}

class _LiveRadarDotState extends State<LiveRadarDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);

    _scaleAnimation = Tween<double>(begin: 1.0, end: 2.3).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    _fadeAnimation = Tween<double>(begin: 0.85, end: 0.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    _controller.repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size * 2.3,
      height: widget.size * 2.3,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Expanding ripple wave
          AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              return Transform.scale(
                scale: _scaleAnimation.value,
                child: Container(
                  width: widget.size,
                  height: widget.size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: widget.color.withValues(alpha: _fadeAnimation.value),
                  ),
                ),
              );
            },
          ),
          // Core solid center dot
          Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: widget.color,
              boxShadow: [
                BoxShadow(
                  color: widget.color.withValues(alpha: 0.6),
                  blurRadius: 3,
                  spreadRadius: 0.5,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A compact live badge combining [LiveRadarDot] with an uppercase label pill.
class LiveRadarBadge extends StatelessWidget {
  final String label;
  final Color color;
  final Color? textColor;

  const LiveRadarBadge({
    super.key,
    required this.label,
    this.color = const Color(0xFFF59E0B),
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 1.0),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          LiveRadarDot(color: color, size: 6.5),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.4,
              color: textColor ?? color,
            ),
          ),
        ],
      ),
    );
  }
}
