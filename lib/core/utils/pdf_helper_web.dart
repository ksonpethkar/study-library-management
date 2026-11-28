import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';
import 'package:study_library/core/utils/pdf_helper_stub.dart' show PdfRasterResult;

@JS('renderPdfPageAsJpeg')
external JSPromise<JSString?>? _renderPdfPageAsJpeg(JSString base64Pdf, JSString? password);

@JS('extractPdfText')
external JSPromise<JSString?>? _extractPdfTextWithPassword(JSString base64Pdf, JSString? password);

Future<PdfRasterResult> renderPdfFirstPageAsJpegPlatform(
  Uint8List pdfBytes, {
  String? password,
  double dpi = 150,
}) async {
  try {
    final base64Str = 'data:application/pdf;base64,${base64Encode(pdfBytes)}';
    final promise = _renderPdfPageAsJpeg(
      base64Str.toJS,
      (password != null && password.isNotEmpty) ? password.toJS : null,
    );
    if (promise == null) {
      return const PdfRasterResult(errorMessage: 'Web PDF renderer is not available.');
    }
    final jsResult = await promise.toDart;
    final res = jsResult?.toDart ?? '';
    if (res == '__PDF_PASSWORD_REQUIRED__') {
      return PdfRasterResult(
        passwordRequired: true,
        incorrectPassword: password != null && password.isNotEmpty,
        errorMessage: 'This PDF is password-protected.',
      );
    }
    if (res.startsWith('data:image/')) {
      final commaIdx = res.indexOf(',');
      if (commaIdx != -1) {
        final rawB64 = res.substring(commaIdx + 1);
        return PdfRasterResult(jpegBytes: base64Decode(rawB64));
      }
    }
    return const PdfRasterResult(errorMessage: 'Could not render PDF page.');
  } catch (e) {
    return PdfRasterResult(errorMessage: 'PDF render failed: $e');
  }
}

Future<String> extractPdfTextPlatform(Uint8List pdfBytes, {String? password}) async {
  try {
    final base64Str = 'data:application/pdf;base64,${base64Encode(pdfBytes)}';
    final promise = _extractPdfTextWithPassword(
      base64Str.toJS,
      (password != null && password.isNotEmpty) ? password.toJS : null,
    );
    if (promise == null) return '';
    final jsResult = await promise.toDart;
    return jsResult?.toDart ?? '';
  } catch (_) {
    return '';
  }
}
