import 'package:flutter/material.dart';

/// Reusable mobile-first zoomable and pannable viewport with:
/// - 2-finger pinch & mouse/trackpad scroll-to-zoom (`trackpadScrollCausesScale: true`)
/// - Double-tap to toggle 1.0x <-> 2.5x zoom at tap position
/// - Floating `[ - ]  100%  [ + ]  [ Reset ]` pill for 1-handed mobile & desktop control
class ZoomableDocumentViewport extends StatefulWidget {
  final Widget child;
  final double minScale;
  final double maxScale;
  final EdgeInsets boundaryMargin;
  final EdgeInsets controlsPadding;

  const ZoomableDocumentViewport({
    super.key,
    required this.child,
    this.minScale = 0.5,
    this.maxScale = 5.0,
    this.boundaryMargin = const EdgeInsets.all(100),
    this.controlsPadding = const EdgeInsets.only(bottom: 12, right: 12),
  });

  @override
  State<ZoomableDocumentViewport> createState() => _ZoomableDocumentViewportState();
}

class _ZoomableDocumentViewportState extends State<ZoomableDocumentViewport> {
  final TransformationController _controller = TransformationController();
  TapDownDetails? _doubleTapDetails;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double get _currentScale => _controller.value.getMaxScaleOnAxis();

  void _resetZoom() {
    _controller.value = Matrix4.identity();
  }

  void _zoomTo(double targetScale, Offset focalPoint) {
    final clamped = targetScale.clamp(widget.minScale, widget.maxScale);
    if ((clamped - 1.0).abs() < 0.02) {
      _resetZoom();
      return;
    }

    final current = _currentScale;
    final currentTranslation = _controller.value.getTranslation();
    // Convert viewport focal point into scene coordinates before applying new scale
    final sceneX = (focalPoint.dx - currentTranslation.x) / current;
    final sceneY = (focalPoint.dy - currentTranslation.y) / current;
    final tx = focalPoint.dx - (sceneX * clamped);
    final ty = focalPoint.dy - (sceneY * clamped);

    _controller.value = Matrix4.diagonal3Values(clamped, clamped, 1.0)
      ..setTranslationRaw(tx, ty, 0.0);
  }

  void _handleDoubleTap(Size viewportSize) {
    if (_currentScale > 1.15) {
      _resetZoom();
    } else {
      final focal = _doubleTapDetails?.localPosition ??
          Offset(viewportSize.width / 2, viewportSize.height / 2);
      _zoomTo(2.5, focal);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final viewportSize = Size(
          constraints.maxWidth.isFinite ? constraints.maxWidth : 360,
          constraints.maxHeight.isFinite ? constraints.maxHeight : 480,
        );
        final center = Offset(viewportSize.width / 2, viewportSize.height / 2);

        return ClipRect(
          child: Stack(
            fit: StackFit.expand,
            children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onDoubleTapDown: (details) => _doubleTapDetails = details,
                onDoubleTap: () => _handleDoubleTap(viewportSize),
                child: InteractiveViewer(
                  transformationController: _controller,
                  panEnabled: true,
                  scaleEnabled: true,
                  trackpadScrollCausesScale: true,
                  minScale: widget.minScale,
                  maxScale: widget.maxScale,
                  boundaryMargin: widget.boundaryMargin,
                  clipBehavior: Clip.none,
                  child: Center(child: widget.child),
                ),
              ),
              Positioned(
                bottom: widget.controlsPadding.bottom,
                right: widget.controlsPadding.right,
                child: ListenableBuilder(
                  listenable: _controller,
                  builder: (context, _) {
                    final scale = _currentScale;
                    final pct = (scale * 100).round();
                    final isDefault = (scale - 1.0).abs() < 0.05;

                    return Material(
                      color: Colors.black.withValues(alpha: 0.72),
                      borderRadius: BorderRadius.circular(24),
                      elevation: 2,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _ZoomPillButton(
                              icon: Icons.remove_rounded,
                              tooltip: 'Zoom Out',
                              onTap: scale <= widget.minScale + 0.02
                                  ? null
                                  : () => _zoomTo(scale - 0.35, center),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 6),
                              child: Text(
                                '$pct%',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            _ZoomPillButton(
                              icon: Icons.add_rounded,
                              tooltip: 'Zoom In',
                              onTap: scale >= widget.maxScale - 0.02
                                  ? null
                                  : () => _zoomTo(scale + 0.35, center),
                            ),
                            if (!isDefault) ...[
                              Container(
                                width: 1,
                                height: 16,
                                margin: const EdgeInsets.symmetric(horizontal: 4),
                                color: Colors.white24,
                              ),
                              InkWell(
                                onTap: _resetZoom,
                                borderRadius: BorderRadius.circular(14),
                                child: const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                                  child: Text(
                                    'Reset',
                                    style: TextStyle(
                                      color: Color(0xFF93C5FD),
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ZoomPillButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;

  const _ZoomPillButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(5),
          child: Icon(
            icon,
            size: 16,
            color: onTap == null ? Colors.white30 : Colors.white,
          ),
        ),
      ),
    );
  }
}
