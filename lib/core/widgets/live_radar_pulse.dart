import 'package:flutter/material.dart';

/// Leading-Brand Ambient Live Radar Pulse Indicator (Linear / Arc / FlightRadar).
///
/// Features a solid glowing core with an expanding, fading concentric sonar ripple.
class LiveRadarPulse extends StatefulWidget {
  final Color color;
  final double size;
  final bool isLive;

  const LiveRadarPulse({
    super.key,
    required this.color,
    this.size = 10.0,
    this.isLive = true,
  });

  @override
  State<LiveRadarPulse> createState() => _LiveRadarPulseState();
}

class _LiveRadarPulseState extends State<LiveRadarPulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    if (widget.isLive) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant LiveRadarPulse oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isLive != oldWidget.isLive) {
      if (widget.isLive) {
        if (!_controller.isAnimating) _controller.repeat();
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
    if (!widget.isLive) {
      return Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: widget.color.withValues(alpha: 0.6),
        ),
      );
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final progress = _controller.value;
        return SizedBox(
          width: widget.size * 2.2,
          height: widget.size * 2.2,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Expanding radar wave
              Container(
                width: widget.size + (widget.size * 1.2 * progress),
                height: widget.size + (widget.size * 1.2 * progress),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.color.withValues(alpha: (1.0 - progress) * 0.45),
                ),
              ),
              // Inner core glowing dot
              Container(
                width: widget.size,
                height: widget.size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.color,
                  boxShadow: [
                    BoxShadow(
                      color: widget.color.withValues(alpha: 0.65),
                      blurRadius: 5,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
