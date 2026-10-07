import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Renders a KYC document with a diagonal regulatory compliance watermark:
/// "VERIFIED FOR COZY CORNER USE ONLY — [DATE]"
class WatermarkedKycWidget extends StatelessWidget {
  final Widget child;
  final String? customText;
  final String? libraryName;
  final DateTime? verificationDate;

  const WatermarkedKycWidget({
    super.key,
    required this.child,
    this.customText,
    this.libraryName,
    this.verificationDate,
  });

  @override
  Widget build(BuildContext context) {
    final date = DateFormat('dd MMM yyyy').format(verificationDate ?? DateTime.now());
    final lib = libraryName ?? 'Cozy Corner Library';
    final watermarkText = customText ?? 'VERIFIED FOR $lib USE ONLY • $date • CONFIDENTIAL KYC';

    return Stack(
      children: [
        child,
        Positioned.fill(
          child: IgnorePointer(
            child: ClipRect(
              child: CustomPaint(
                painter: _DiagonalWatermarkPainter(watermarkText),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _DiagonalWatermarkPainter extends CustomPainter {
  final String text;

  _DiagonalWatermarkPainter(this.text);

  @override
  void paint(Canvas canvas, Size size) {
    final textStyle = TextStyle(
      color: Colors.red.withValues(alpha: 0.22),
      fontSize: 13,
      fontWeight: FontWeight.w700,
      letterSpacing: 1.2,
    );

    final textSpan = TextSpan(text: text, style: textStyle);
    final textPainter = TextPainter(
      text: textSpan,
      textDirection: ui.TextDirection.ltr,
    );
    textPainter.layout();

    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.rotate(-0.45); // ~ -26 degrees

    // Draw multiple diagonal stripes
    final stepY = textPainter.height + 40;
    for (double y = -size.height * 1.5; y < size.height * 1.5; y += stepY) {
      final offsetX = -textPainter.width / 2;
      textPainter.paint(canvas, Offset(offsetX, y));
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _DiagonalWatermarkPainter oldDelegate) {
    return oldDelegate.text != text;
  }
}

/// Helper to burn the watermark directly into a File before uploading to storage/database.
class WatermarkHelper {
  WatermarkHelper._();

  static Future<File> burnWatermark({
    required File sourceFile,
    required String targetPath,
    String? libraryName,
  }) async {
    try {
      final bytes = await sourceFile.readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final image = frame.image;

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()));

      // 1. Draw source image
      canvas.drawImage(image, Offset.zero, Paint());

      // 2. Draw diagonal watermark
      final date = DateFormat('dd-MM-yyyy').format(DateTime.now());
      final lib = (libraryName ?? 'COZY CORNER').toUpperCase();
      final text = 'VERIFIED FOR $lib USE ONLY • $date • CONFIDENTIAL KYC';

      final fontSize = (image.width / 32).clamp(18.0, 48.0);
      final textStyle = ui.TextStyle(
        color: const Color(0x38E11D48), // ~22% red
        fontSize: fontSize,
        fontWeight: ui.FontWeight.bold,
      );

      final paragraphStyle = ui.ParagraphStyle(textAlign: TextAlign.center);
      final builder = ui.ParagraphBuilder(paragraphStyle)
        ..pushStyle(textStyle)
        ..addText(text);
      final paragraph = builder.build()..layout(ui.ParagraphConstraints(width: image.width * 1.8));

      canvas.save();
      canvas.translate(image.width / 2, image.height / 2);
      canvas.rotate(-0.48);

      final stepY = fontSize * 3.5;
      for (double y = -image.height.toDouble(); y < image.height.toDouble(); y += stepY) {
        canvas.drawParagraph(paragraph, Offset(-paragraph.width / 2, y));
      }

      canvas.restore();

      final picture = recorder.endRecording();
      final watermarkedImage = await picture.toImage(image.width, image.height);
      final byteData = await watermarkedImage.toByteData(format: ui.ImageByteFormat.png);

      if (byteData == null) return sourceFile;

      final outFile = File(targetPath);
      await outFile.writeAsBytes(byteData.buffer.asUint8List());
      return outFile;
    } catch (_) {
      return sourceFile;
    }
  }
}
