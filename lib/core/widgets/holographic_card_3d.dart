import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Leading-Brand 3D Holographic Perspective Tilt Card (Apple / Revolut Ultra).
///
/// Provides gyroscopic / touch-drag and mouse-hover 3D perspective tilt with
/// an opalescent rainbow specular sheen that reacts to tilt angles.
class HolographicCard3D extends StatefulWidget {
  final Widget front;
  final Widget? back;
  final bool isFlipped;
  final VoidCallback? onFlipTap;
  final double maxTiltAngle;
  final BorderRadius? borderRadius;

  const HolographicCard3D({
    super.key,
    required this.front,
    this.back,
    this.isFlipped = false,
    this.onFlipTap,
    this.maxTiltAngle = 0.20, // ~11 degrees max tilt
    this.borderRadius,
  });

  @override
  State<HolographicCard3D> createState() => _HolographicCard3DState();
}

class _HolographicCard3DState extends State<HolographicCard3D>
    with SingleTickerProviderStateMixin {
  double _tiltX = 0.0;
  double _tiltY = 0.0;
  late final AnimationController _flipController;
  late final Animation<double> _flipAnimation;

  @override
  void initState() {
    super.initState();
    _flipController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 550),
    );
    _flipAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _flipController, curve: Curves.easeInOutCubic),
    );

    if (widget.isFlipped) {
      _flipController.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(covariant HolographicCard3D oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isFlipped != oldWidget.isFlipped) {
      if (widget.isFlipped) {
        _flipController.forward();
      } else {
        _flipController.reverse();
      }
    }
  }

  @override
  void dispose() {
    _flipController.dispose();
    super.dispose();
  }

  void _onHover(PointerHoverEvent event, Size size) {
    if (size.width == 0 || size.height == 0) return;
    // Map hover position from -1.0 to 1.0
    final dx = (event.localPosition.dx / size.width) * 2 - 1.0;
    final dy = (event.localPosition.dy / size.height) * 2 - 1.0;

    setState(() {
      _tiltY = (dx * widget.maxTiltAngle).clamp(-widget.maxTiltAngle, widget.maxTiltAngle);
      _tiltX = (-dy * widget.maxTiltAngle).clamp(-widget.maxTiltAngle, widget.maxTiltAngle);
    });
  }

  void _onHoverExit(PointerExitEvent _) {
    setState(() {
      _tiltX = 0.0;
      _tiltY = 0.0;
    });
  }

  void _onPanUpdate(DragUpdateDetails details) {
    setState(() {
      _tiltY = (_tiltY + details.delta.dx * 0.003).clamp(-widget.maxTiltAngle, widget.maxTiltAngle);
      _tiltX = (_tiltX - details.delta.dy * 0.003).clamp(-widget.maxTiltAngle, widget.maxTiltAngle);
    });
  }

  void _onPanEnd(DragEndDetails _) {
    setState(() {
      _tiltX = 0.0;
      _tiltY = 0.0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final radius = widget.borderRadius ?? BorderRadius.circular(20);

    return LayoutBuilder(
      builder: (context, constraints) {
        final cardSize = Size(constraints.maxWidth, constraints.maxHeight);

        return MouseRegion(
          onHover: (e) => _onHover(e, cardSize),
          onExit: _onHoverExit,
          child: GestureDetector(
            onPanUpdate: _onPanUpdate,
            onPanEnd: _onPanEnd,
            onTap: widget.onFlipTap,
            behavior: HitTestBehavior.opaque,
            child: AnimatedBuilder(
              animation: _flipAnimation,
              builder: (context, _) {
                final flipProgress = _flipAnimation.value;
                final isBackVisible = flipProgress >= 0.5;
                final flipAngle = flipProgress * math.pi;

                // Base 3D Perspective Matrix
                final transform = Matrix4.identity()
                  ..setEntry(3, 2, 0.0012) // Optical camera perspective
                  ..rotateX(_tiltX)
                  ..rotateY(_tiltY + flipAngle);

                // Intensity of specular reflection based on tilt displacement
                final tiltIntensity = (_tiltX.abs() + _tiltY.abs()) / (widget.maxTiltAngle * 2);

                return Transform(
                  transform: transform,
                  alignment: Alignment.center,
                  child: Stack(
                    children: [
                      // Render front or back based on flip angle
                      if (!isBackVisible)
                        widget.front
                      else if (widget.back != null)
                        Transform(
                          transform: Matrix4.identity()..rotateY(math.pi),
                          alignment: Alignment.center,
                          child: widget.back!,
                        )
                      else
                        widget.front,

                      // Holographic Specular Lighting Overlap
                      Positioned.fill(
                        child: IgnorePointer(
                          child: ClipRRect(
                            borderRadius: radius,
                            child: AnimatedOpacity(
                              duration: const Duration(milliseconds: 180),
                              opacity: (tiltIntensity * 0.40).clamp(0.0, 0.40),
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment(
                                      -1.2 + (_tiltY * 5),
                                      -1.2 + (_tiltX * 5),
                                    ),
                                    end: Alignment(
                                      1.2 + (_tiltY * 5),
                                      1.2 + (_tiltX * 5),
                                    ),
                                    colors: [
                                      Colors.transparent,
                                      Colors.white.withValues(alpha: 0.35),
                                      Colors.cyanAccent.withValues(alpha: 0.25),
                                      Colors.purpleAccent.withValues(alpha: 0.20),
                                      Colors.amberAccent.withValues(alpha: 0.25),
                                      Colors.transparent,
                                    ],
                                    stops: const [0.0, 0.30, 0.48, 0.65, 0.82, 1.0],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
}
