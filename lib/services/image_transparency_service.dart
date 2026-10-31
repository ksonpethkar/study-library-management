import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

class ImageTransparencyService {
  /// Converts any image (JPEG/PNG/etc) with a white or light-paper background
  /// into a pure transparent PNG where only the stamp/signature/logo ink remains.
  ///
  /// [threshold]: Pixels with R, G, B >= threshold are turned 100% transparent (alpha = 0).
  /// [softEdgeRange]: Pixels in [threshold - softEdgeRange, threshold] receive soft alpha
  /// for smooth, anti-aliased edges without white fringes.
  static Uint8List removeWhiteBackground(
    Uint8List inputBytes, {
    int threshold = 225,
    int softEdgeRange = 30,
  }) {
    try {
      final decoded = img.decodeImage(inputBytes);
      if (decoded == null) return inputBytes;

      // Ensure 4 channels (RGBA)
      final rgbaImage = decoded.convert(numChannels: 4);
      final minThreshold = threshold - softEdgeRange;

      for (int y = 0; y < rgbaImage.height; y++) {
        for (int x = 0; x < rgbaImage.width; x++) {
          final pixel = rgbaImage.getPixel(x, y);
          final r = pixel.r.toInt();
          final g = pixel.g.toInt();
          final b = pixel.b.toInt();

          // Check if pixel is white / light paper
          if (r >= threshold && g >= threshold && b >= threshold) {
            pixel.a = 0; // Pure transparent
          } else if (r >= minThreshold && g >= minThreshold && b >= minThreshold) {
            // Anti-aliased transition for smooth ink strokes
            final brightness = (r + g + b) / 3.0;
            final factor = (threshold - brightness) / softEdgeRange.toDouble();
            final newAlpha = (factor.clamp(0.0, 1.0) * 255).round();
            if (newAlpha < pixel.a.toInt()) {
              pixel.a = newAlpha;
            }
          }
        }
      }

      return Uint8List.fromList(img.encodePng(rgbaImage));
    } catch (e) {
      if (kDebugMode) debugPrint('removeWhiteBackground error: $e');
      return inputBytes;
    }
  }

  /// Converts a data URI or Base64 string to a transparent PNG data URI
  static String removeBackgroundFromDataUri(String dataUriOrBase64, {int threshold = 225}) {
    try {
      final b64 = dataUriOrBase64.contains(',') ? dataUriOrBase64.split(',')[1] : dataUriOrBase64;
      final bytes = base64Decode(b64);
      final transparentBytes = removeWhiteBackground(bytes, threshold: threshold);
      return 'data:image/png;base64,${base64Encode(transparentBytes)}';
    } catch (e) {
      if (kDebugMode) debugPrint('removeBackgroundFromDataUri error: $e');
      return dataUriOrBase64;
    }
  }
}
