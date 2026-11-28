import 'dart:typed_data';
import 'pdf_helper_stub.dart' show PdfRasterResult;
import 'pdf_helper_stub.dart' if (dart.library.js_interop) 'pdf_helper_web.dart';
export 'pdf_helper_stub.dart' show PdfRasterResult;

/// Cross-platform PDF unlocker, text extractor, and page-to-JPEG rasterizer.
class PdfHelper {
  PdfHelper._();

  static Future<PdfRasterResult> renderFirstPageAsJpeg(
    Uint8List pdfBytes, {
    String? password,
    double dpi = 150,
  }) {
    return renderPdfFirstPageAsJpegPlatform(
      pdfBytes,
      password: password,
      dpi: dpi,
    );
  }

  static Future<String> extractText(Uint8List pdfBytes, {String? password}) {
    return extractPdfTextPlatform(pdfBytes, password: password);
  }
}
