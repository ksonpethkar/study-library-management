import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:intl/intl.dart';
import 'package:study_library/models/student_model.dart';

enum _DocFilter { original, autoClarity, bwScan }

enum _EditorTool { none, crop, redact }

/// Pre-upload interactive ID document editor allowing users/staff to:
/// - Rotate 90°
/// - Crop (with optional 1.58:1 ID card aspect preset)
/// - Enhance clarity (Auto Clarity / B&W Scan)
/// - Permanently redact/mask sensitive areas (e.g. first 8 Aadhaar digits)
/// - Burn in a KYC purpose watermark ("FOR STUDY CENTRE KYC ONLY • DD MMM YYYY")
/// - Inspect automatic resolution & lighting quality warnings
class IdDocumentEditorDialog extends StatefulWidget {
  final Uint8List imageBytes;
  final GovIdType? govIdType;
  final String title;

  const IdDocumentEditorDialog({
    super.key,
    required this.imageBytes,
    this.govIdType,
    this.title = 'Review & Edit ID Document',
  });

  /// Opens the modal editor and returns processed JPEG bytes, or `null` if cancelled.
  static Future<Uint8List?> show(
    BuildContext context, {
    required Uint8List imageBytes,
    GovIdType? govIdType,
    String title = 'Review & Edit ID Document',
  }) {
    return showDialog<Uint8List>(
      context: context,
      barrierDismissible: false,
      builder: (_) => IdDocumentEditorDialog(
        imageBytes: imageBytes,
        govIdType: govIdType,
        title: title,
      ),
    );
  }

  @override
  State<IdDocumentEditorDialog> createState() => _IdDocumentEditorDialogState();
}

class _IdDocumentEditorDialogState extends State<IdDocumentEditorDialog> {
  img.Image? _workingImage;
  Uint8List? _previewBytes;
  _DocFilter _filter = _DocFilter.original;
  _EditorTool _activeTool = _EditorTool.none;
  bool _applyWatermark = false;
  bool _processing = true;
  String? _qualityWarning;

  // Normalized (0.0..1.0) crop rectangle when _activeTool == _EditorTool.crop
  Rect _cropRect = const Rect.fromLTWH(0.05, 0.08, 0.90, 0.84);

  // Normalized (0.0..1.0) redaction boxes burned into the image
  final List<Rect> _redactionBoxes = [];
  Offset? _dragStart;
  Rect? _activeDragRect;

  @override
  void initState() {
    super.initState();
    _initImage();
  }

  Future<void> _initImage() async {
    await Future<void>.delayed(Duration.zero);
    final decoded = img.decodeImage(widget.imageBytes);
    if (decoded == null) {
      if (!mounted) return;
      setState(() {
        _previewBytes = widget.imageBytes;
        _processing = false;
        _qualityWarning = 'Could not decode image for editing. You can still attach it as-is.';
      });
      return;
    }

    // Resize oversized camera images down to max 1600px on longest side for snappy editing
    final base = (decoded.width > 1600 || decoded.height > 1600)
        ? img.copyResize(
            decoded,
            width: decoded.width >= decoded.height ? 1600 : null,
            height: decoded.height > decoded.width ? 1600 : null,
          )
        : decoded;

    _workingImage = base;
    _rebuildPreview();
  }

  String? _analyzeQuality(img.Image image) {
    if (image.width < 300 || image.height < 200) {
      return 'Low resolution (${image.width}×${image.height}). Text may appear blurry.';
    }
    double lumSum = 0;
    int count = 0;
    final stepX = math.max(1, image.width ~/ 40);
    final stepY = math.max(1, image.height ~/ 40);
    for (int y = 0; y < image.height; y += stepY) {
      for (int x = 0; x < image.width; x += stepX) {
        final p = image.getPixel(x, y);
        final luma = 0.299 * p.r + 0.587 * p.g + 0.114 * p.b;
        lumSum += luma;
        count++;
      }
    }
    if (count > 0) {
      final avg = lumSum / count;
      if (avg < 45) {
        return 'Image looks too dark. Try "Auto Clarity" or retake in brighter light.';
      }
      if (avg > 235) {
        return 'Image looks overexposed / washed out. Text may be hard to read.';
      }
    }
    return null;
  }

  img.Image _renderProcessedImage() {
    final base = _workingImage!;
    img.Image out = img.Image.from(base);

    // 1. Filter
    switch (_filter) {
      case _DocFilter.original:
        break;
      case _DocFilter.autoClarity:
        out = img.adjustColor(out, contrast: 1.28, brightness: 1.04, saturation: 1.06);
        break;
      case _DocFilter.bwScan:
        out = img.grayscale(out);
        out = img.adjustColor(out, contrast: 1.45, brightness: 1.05);
        break;
    }

    // 2. Permanent Privacy Redaction Boxes
    for (final r in _redactionBoxes) {
      final x1 = (r.left.clamp(0.0, 1.0) * out.width).round();
      final y1 = (r.top.clamp(0.0, 1.0) * out.height).round();
      final x2 = (r.right.clamp(0.0, 1.0) * out.width).round();
      final y2 = (r.bottom.clamp(0.0, 1.0) * out.height).round();
      if (x2 > x1 && y2 > y1) {
        img.fillRect(
          out,
          x1: x1,
          y1: y1,
          x2: x2,
          y2: y2,
          color: img.ColorRgb8(15, 23, 42),
        );
      }
    }

    // 3. Optional KYC Purpose Watermark
    if (_applyWatermark) {
      final dateStr = DateFormat('dd MMM yyyy').format(DateTime.now()).toUpperCase();
      final label = 'FOR STUDY CENTRE KYC ONLY - $dateStr';
      final barHeight = math.max(28, (out.height * 0.065).round());
      final yTop = math.max(0, out.height - barHeight);
      img.fillRect(
        out,
        x1: 0,
        y1: yTop,
        x2: out.width,
        y2: out.height,
        color: img.ColorRgba8(15, 23, 42, 185),
      );
      img.drawString(
        out,
        label,
        font: img.arial14,
        x: 12,
        y: yTop + math.max(4, (barHeight - 14) ~/ 2),
        color: img.ColorRgb8(248, 250, 252),
      );
    }

    return out;
  }

  void _rebuildPreview() {
    if (_workingImage == null) return;
    setState(() => _processing = true);
    final processed = _renderProcessedImage();
    final jpg = Uint8List.fromList(img.encodeJpg(processed, quality: 84));
    final warning = _analyzeQuality(_workingImage!);
    if (!mounted) return;
    setState(() {
      _previewBytes = jpg;
      _qualityWarning = warning;
      _processing = false;
    });
  }

  void _rotate90() {
    if (_workingImage == null) return;
    _workingImage = img.copyRotate(_workingImage!, angle: 90);
    _redactionBoxes.clear();
    _rebuildPreview();
  }

  void _applyCrop() {
    if (_workingImage == null) return;
    final w = _workingImage!.width;
    final h = _workingImage!.height;
    final x = (_cropRect.left.clamp(0.0, 0.95) * w).round();
    final y = (_cropRect.top.clamp(0.0, 0.95) * h).round();
    final cw = math.max(50, (_cropRect.width * w).round().clamp(1, w - x));
    final ch = math.max(50, (_cropRect.height * h).round().clamp(1, h - y));
    _workingImage = img.copyCrop(_workingImage!, x: x, y: y, width: cw, height: ch);
    _redactionBoxes.clear();
    _activeTool = _EditorTool.none;
    _cropRect = const Rect.fromLTWH(0.05, 0.08, 0.90, 0.84);
    _rebuildPreview();
  }

  void _setIdCardAspectPreset() {
    if (_workingImage == null) return;
    // Standard ISO/IEC 7810 ID-1 ratio ~1.586:1
    const targetRatio = 1.586;
    final imgRatio = _workingImage!.width / _workingImage!.height;
    double rw = 0.90;
    double rh = (rw * imgRatio) / targetRatio;
    if (rh > 0.90) {
      rh = 0.90;
      rw = (rh * targetRatio) / imgRatio;
    }
    setState(() {
      _cropRect = Rect.fromCenter(
        center: const Offset(0.5, 0.5),
        width: rw.clamp(0.2, 0.96),
        height: rh.clamp(0.2, 0.96),
      );
    });
  }

  void _addAadhaarMaskPreset() {
    setState(() {
      // Typical location of Aadhaar 12-digit number (masks left 65% = first 8 digits)
      _redactionBoxes.add(const Rect.fromLTWH(0.22, 0.68, 0.36, 0.11));
    });
    _rebuildPreview();
  }

  Future<void> _saveAndFinish() async {
    if (_workingImage == null) {
      Navigator.of(context).pop(_previewBytes ?? widget.imageBytes);
      return;
    }
    var processed = _renderProcessedImage();
    var bytes = Uint8List.fromList(img.encodeJpg(processed, quality: 82));
    // Keep under 450 KB for fast Firestore/Storage persistence
    if (bytes.lengthInBytes > 450 * 1024) {
      processed = img.copyResize(processed, width: math.min(1100, processed.width));
      bytes = Uint8List.fromList(img.encodeJpg(processed, quality: 75));
    }
    if (!mounted) return;
    Navigator.of(context).pop(bytes);
  }

  @override
  Widget build(BuildContext context) {
    final isAadhaar = widget.govIdType == GovIdType.aadhaar;

    return Dialog(
      backgroundColor: const Color(0xFF0F172A),
      insetPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680, maxHeight: 780),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 10, 10),
              child: Row(
                children: [
                  const Icon(Icons.tune_rounded, color: Colors.cyanAccent, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(null),
                    child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
                  ),
                ],
              ),
            ),
            if (_qualityWarning != null)
              Container(
                margin: const EdgeInsets.fromLTRB(14, 0, 14, 8),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.amber.withValues(alpha: 0.5)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _qualityWarning!,
                        style: const TextStyle(color: Colors.amber, fontSize: 11.5),
                      ),
                    ),
                  ],
                ),
              ),
            // Image Canvas
            Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white12),
                ),
                child: _processing && _previewBytes == null
                    ? const Center(child: CircularProgressIndicator())
                    : LayoutBuilder(
                        builder: (context, constraints) {
                          return GestureDetector(
                            onPanStart: _activeTool == _EditorTool.none
                                ? null
                                : (details) {
                                    final w = constraints.maxWidth;
                                    final h = constraints.maxHeight;
                                    if (w <= 0 || h <= 0) return;
                                    final norm = Offset(
                                      (details.localPosition.dx / w).clamp(0.0, 1.0),
                                      (details.localPosition.dy / h).clamp(0.0, 1.0),
                                    );
                                    setState(() {
                                      _dragStart = norm;
                                      _activeDragRect = Rect.fromPoints(norm, norm);
                                    });
                                  },
                            onPanUpdate: _activeTool == _EditorTool.none
                                ? null
                                : (details) {
                                    if (_dragStart == null) return;
                                    final w = constraints.maxWidth;
                                    final h = constraints.maxHeight;
                                    if (w <= 0 || h <= 0) return;
                                    final norm = Offset(
                                      (details.localPosition.dx / w).clamp(0.0, 1.0),
                                      (details.localPosition.dy / h).clamp(0.0, 1.0),
                                    );
                                    setState(() {
                                      _activeDragRect = Rect.fromPoints(_dragStart!, norm);
                                      if (_activeTool == _EditorTool.crop) {
                                        _cropRect = _activeDragRect!;
                                      }
                                    });
                                  },
                            onPanEnd: _activeTool == _EditorTool.none
                                ? null
                                : (_) {
                                    if (_activeTool == _EditorTool.redact &&
                                        _activeDragRect != null &&
                                        _activeDragRect!.width > 0.02 &&
                                        _activeDragRect!.height > 0.02) {
                                      _redactionBoxes.add(_activeDragRect!);
                                      _activeDragRect = null;
                                      _dragStart = null;
                                      _rebuildPreview();
                                    } else {
                                      setState(() {
                                        _activeDragRect = null;
                                        _dragStart = null;
                                      });
                                    }
                                  },
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                if (_previewBytes != null)
                                  Image.memory(_previewBytes!, fit: BoxFit.contain),
                                if (_activeTool == _EditorTool.crop)
                                  CustomPaint(
                                    painter: _OverlayBoxPainter(
                                      rect: _cropRect,
                                      color: Colors.cyanAccent,
                                      label: 'Drag to set crop area',
                                    ),
                                  ),
                                if (_activeTool == _EditorTool.redact && _activeDragRect != null)
                                  CustomPaint(
                                    painter: _OverlayBoxPainter(
                                      rect: _activeDragRect!,
                                      color: Colors.redAccent,
                                      label: 'Masking...',
                                    ),
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ),
            // Hint bar for active tool
            if (_activeTool != _EditorTool.none)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  alignment: WrapAlignment.center,
                  children: [
                    if (_activeTool == _EditorTool.crop) ...[
                      OutlinedButton.icon(
                        onPressed: _setIdCardAspectPreset,
                        icon: const Icon(Icons.crop_16_9_rounded, size: 16),
                        label: const Text('ID Card 1.58:1', style: TextStyle(fontSize: 12)),
                      ),
                      FilledButton.icon(
                        onPressed: _applyCrop,
                        icon: const Icon(Icons.check_rounded, size: 16),
                        label: const Text('Apply Crop', style: TextStyle(fontSize: 12)),
                      ),
                    ],
                    if (_activeTool == _EditorTool.redact) ...[
                      const Text(
                        'Drag over text to permanently black-out',
                        style: TextStyle(color: Colors.white70, fontSize: 11.5),
                      ),
                      if (isAadhaar)
                        OutlinedButton(
                          onPressed: _addAadhaarMaskPreset,
                          child: const Text('Mask Aadhaar Digits',
                              style: TextStyle(fontSize: 11.5)),
                        ),
                      if (_redactionBoxes.isNotEmpty)
                        TextButton(
                          onPressed: () {
                            _redactionBoxes.removeLast();
                            _rebuildPreview();
                          },
                          child: const Text('Undo Mask', style: TextStyle(fontSize: 11.5)),
                        ),
                    ],
                  ],
                ),
              ),
            // Tool Strip
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _ToolChip(
                      icon: Icons.rotate_right_rounded,
                      label: 'Rotate 90°',
                      selected: false,
                      onTap: _rotate90,
                    ),
                    const SizedBox(width: 8),
                    _ToolChip(
                      icon: Icons.crop_rounded,
                      label: 'Crop',
                      selected: _activeTool == _EditorTool.crop,
                      onTap: () => setState(() {
                        _activeTool = _activeTool == _EditorTool.crop
                            ? _EditorTool.none
                            : _EditorTool.crop;
                      }),
                    ),
                    const SizedBox(width: 8),
                    _ToolChip(
                      icon: Icons.auto_fix_high_rounded,
                      label: 'Auto Clarity',
                      selected: _filter == _DocFilter.autoClarity,
                      onTap: () {
                        _filter = _filter == _DocFilter.autoClarity
                            ? _DocFilter.original
                            : _DocFilter.autoClarity;
                        _rebuildPreview();
                      },
                    ),
                    const SizedBox(width: 8),
                    _ToolChip(
                      icon: Icons.contrast_rounded,
                      label: 'B&W Scan',
                      selected: _filter == _DocFilter.bwScan,
                      onTap: () {
                        _filter = _filter == _DocFilter.bwScan
                            ? _DocFilter.original
                            : _DocFilter.bwScan;
                        _rebuildPreview();
                      },
                    ),
                    const SizedBox(width: 8),
                    _ToolChip(
                      icon: Icons.privacy_tip_outlined,
                      label: 'Mask / Redact',
                      selected: _activeTool == _EditorTool.redact,
                      onTap: () => setState(() {
                        _activeTool = _activeTool == _EditorTool.redact
                            ? _EditorTool.none
                            : _EditorTool.redact;
                      }),
                    ),
                    const SizedBox(width: 8),
                    _ToolChip(
                      icon: Icons.verified_user_outlined,
                      label: 'KYC Watermark',
                      selected: _applyWatermark,
                      onTap: () {
                        _applyWatermark = !_applyWatermark;
                        _rebuildPreview();
                      },
                    ),
                  ],
                ),
              ),
            ),
            // Footer
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 6, 14, 14),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _previewBytes != null
                          ? 'Size: ${(_previewBytes!.lengthInBytes / 1024).round()} KB'
                          : '',
                      style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: _processing ? null : _saveAndFinish,
                    icon: const Icon(Icons.check_circle_outline_rounded, size: 18),
                    label: const Text('Save & Use Document'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ToolChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ToolChip({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? Colors.cyanAccent.withValues(alpha: 0.18) : const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? Colors.cyanAccent : Colors.white12,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: selected ? Colors.cyanAccent : Colors.white70),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.cyanAccent : Colors.white,
                fontSize: 12,
                fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OverlayBoxPainter extends CustomPainter {
  final Rect rect;
  final Color color;
  final String label;

  _OverlayBoxPainter({
    required this.rect,
    required this.color,
    required this.label,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final pixelRect = Rect.fromLTRB(
      rect.left * size.width,
      rect.top * size.height,
      rect.right * size.width,
      rect.bottom * size.height,
    );
    final fill = Paint()..color = color.withValues(alpha: 0.14);
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawRect(pixelRect, fill);
    canvas.drawRect(pixelRect, stroke);
  }

  @override
  bool shouldRepaint(covariant _OverlayBoxPainter oldDelegate) {
    return oldDelegate.rect != rect || oldDelegate.color != color;
  }
}
