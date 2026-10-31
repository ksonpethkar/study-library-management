import 'package:flutter/foundation.dart';
import 'ocr/ocr_service_io.dart' if (dart.library.html) 'ocr/ocr_service_web.dart';

class OcrService {
  /// Extract text from a local file path (Mobile / Desktop)
  Future<String> processImage(String imagePath) async {
    if (kIsWeb) {
      return '';
    }
    return PlatformOcrService.processPath(imagePath);
  }

  /// Extract text from image bytes (Universal: works on Web and Mobile)
  Future<String> processImageBytes(Uint8List bytes) async {
    return PlatformOcrService.processBytes(bytes);
  }

  /// Decode QR Code directly from image bytes (Instant & 100% accurate for Aadhaar, PAN, DL)
  Future<String?> decodeQrBytes(Uint8List bytes) async {
    return PlatformOcrService.decodeQrBytes(bytes);
  }
}
