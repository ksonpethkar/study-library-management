import 'dart:io';
import 'dart:typed_data';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image/image.dart' as img;
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:path_provider/path_provider.dart';

class PlatformOcrService {
  /// Preprocesses an image before ML Kit text recognition:
  /// - Converts to grayscale to remove colored security printing & gradient interference on PVC/laminated cards
  /// - Enhances contrast (1.3x) and normalizes brightness to clarify etched/faint letters
  /// - Resizes oversized images (> 1600px) to prevent OOM on budget mobile devices
  static Uint8List preprocessImage(Uint8List bytes) {
    try {
      final decoded = img.decodeImage(bytes);
      if (decoded == null) return bytes;

      img.Image processed = decoded;
      if (processed.width > 1600 || processed.height > 1600) {
        final isLandscape = processed.width > processed.height;
        processed = img.copyResize(
          processed,
          width: isLandscape ? 1600 : null,
          height: !isLandscape ? 1600 : null,
        );
      }

      processed = img.grayscale(processed);
      processed = img.adjustColor(processed, contrast: 1.3, brightness: 1.05);

      return Uint8List.fromList(img.encodeJpg(processed, quality: 90));
    } catch (_) {
      return bytes;
    }
  }

  static Future<String> processPath(String imagePath) async {
    final inputImage = InputImage.fromFilePath(imagePath);
    final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final RecognizedText recognizedText = await textRecognizer.processImage(inputImage);
      return recognizedText.text;
    } finally {
      textRecognizer.close();
    }
  }

  static Future<String> processBytes(Uint8List bytes) async {
    final preprocessedBytes = preprocessImage(bytes);
    final tempDir = await getTemporaryDirectory();
    final tempFile = File('${tempDir.path}/ocr_${DateTime.now().millisecondsSinceEpoch}.jpg');
    await tempFile.writeAsBytes(preprocessedBytes);
    try {
      final text = await processPath(tempFile.path);
      if (text.trim().length >= 10) {
        return text;
      }
      // Fallback: try raw bytes if preprocessing yielded almost nothing
      await tempFile.writeAsBytes(bytes);
      return await processPath(tempFile.path);
    } finally {
      if (await tempFile.exists()) {
        try {
          await tempFile.delete();
        } catch (_) { /* intentionally silent */ }
      }
    }
  }

  static Future<String> extractPdfText(Uint8List bytes) async {
    return '';
  }

  static Future<String?> decodeQrBytes(Uint8List bytes) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/qr_${DateTime.now().millisecondsSinceEpoch}.jpg');
      await tempFile.writeAsBytes(bytes);
      try {
        final controller = MobileScannerController();
        try {
          final capture = await controller.analyzeImage(tempFile.path);
          if (capture != null && capture.barcodes.isNotEmpty) {
            final raw = capture.barcodes.first.rawValue;
            if (raw != null && raw.isNotEmpty) return raw;
          }
        } finally {
          // Always dispose to prevent camera pipeline leak even if analyzeImage() throws
          await controller.dispose();
        }
      } finally {
        if (await tempFile.exists()) {
          try {
            await tempFile.delete();
          } catch (_) { /* intentionally silent */ }
        }
      }
    } catch (_) { /* intentionally silent */ }
    return null;
  }
}
