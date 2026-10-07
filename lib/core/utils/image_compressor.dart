import 'dart:io';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

class ImageCompressor {
  /// Compresses an image with given quality and max width
  static Future<File> compressImage(File file, {int quality = 80, int maxWidth = 1024}) async {
    try {
      final dir = await getTemporaryDirectory();
      final targetPath = path.join(
        dir.path, 
        'compressed_${DateTime.now().millisecondsSinceEpoch}.jpg'
      );

      final result = await FlutterImageCompress.compressAndGetFile(
        file.absolute.path,
        targetPath,
        quality: quality,
        minWidth: maxWidth,
      );

      if (result == null) {
        throw Exception('We could not compress this image. Please try another one.');
      }

      return File(result.path);
    } catch (e) {
      throw Exception('Failed to compress image. Please try a different photo.');
    }
  }

  /// Compress specifically for thumbnail size (200px)
  static Future<File> compressForThumbnail(File file) async {
    return compressImage(file, quality: 70, maxWidth: 200);
  }

  /// Get image file size in bytes
  static Future<int> getImageSize(File file) async {
    if (await file.exists()) {
      return await file.length();
    }
    return 0;
  }

  /// Check if image exceeds maximum allowed MB
  static bool isImageTooLarge(File file, int maxMB) {
    if (!file.existsSync()) return false;
    final bytes = file.lengthSync();
    final maxBytes = maxMB * 1024 * 1024;
    return bytes > maxBytes;
  }
}
