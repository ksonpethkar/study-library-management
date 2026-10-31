import 'dart:io';
import 'dart:typed_data';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:path_provider/path_provider.dart';

class PlatformOcrService {
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
    final tempDir = await getTemporaryDirectory();
    final tempFile = File('${tempDir.path}/ocr_${DateTime.now().millisecondsSinceEpoch}.jpg');
    await tempFile.writeAsBytes(bytes);
    try {
      return await processPath(tempFile.path);
    } finally {
      if (await tempFile.exists()) {
        try {
          await tempFile.delete();
        } catch (_) { /* intentionally silent */ }
      }
    }
  }

  static Future<String?> decodeQrBytes(Uint8List bytes) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/qr_${DateTime.now().millisecondsSinceEpoch}.jpg');
      await tempFile.writeAsBytes(bytes);
      try {
        final controller = MobileScannerController();
        final capture = await controller.analyzeImage(tempFile.path);
        await controller.dispose();
        if (capture != null && capture.barcodes.isNotEmpty) {
          final raw = capture.barcodes.first.rawValue;
          if (raw != null && raw.isNotEmpty) return raw;
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
