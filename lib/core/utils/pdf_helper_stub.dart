import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'package:printing/printing.dart';

/// Result of attempting to unlock/rasterize a PDF page into a compressed JPEG.
class PdfRasterResult {
  final Uint8List? jpegBytes;
  final bool passwordRequired;
  final bool incorrectPassword;
  final String? errorMessage;

  const PdfRasterResult({
    this.jpegBytes,
    this.passwordRequired = false,
    this.incorrectPassword = false,
    this.errorMessage,
  });
}

Future<PdfRasterResult> renderPdfFirstPageAsJpegPlatform(
  Uint8List pdfBytes, {
  String? password,
  double dpi = 150,
}) async {
  try {
    await for (final page in Printing.raster(pdfBytes, pages: const [0], dpi: dpi)) {
      final pngBytes = await page.toPng();
      final decoded = img.decodeImage(pngBytes);
      if (decoded == null) {
        return const PdfRasterResult(errorMessage: 'Could not decode PDF page image.');
      }
      final resized = (decoded.width > 1200 || decoded.height > 1200)
          ? img.copyResize(
              decoded,
              width: decoded.width >= decoded.height ? 1200 : null,
              height: decoded.height > decoded.width ? 1200 : null,
            )
          : decoded;
      final jpg = Uint8List.fromList(img.encodeJpg(resized, quality: 78));
      return PdfRasterResult(jpegBytes: jpg);
    }
    return const PdfRasterResult(errorMessage: 'PDF contains no renderable pages.');
  } catch (e) {
    final msg = e.toString().toLowerCase();
    if (msg.contains('password') || msg.contains('encrypted') || msg.contains('security')) {
      return PdfRasterResult(
        passwordRequired: true,
        incorrectPassword: password != null && password.isNotEmpty,
        errorMessage: 'This PDF is password-protected.',
      );
    }
    return PdfRasterResult(errorMessage: 'Failed to render PDF: $e');
  }
}

Future<String> extractPdfTextPlatform(Uint8List pdfBytes, {String? password}) async {
  return '';
}
