import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';

@JS('recognizeOcrText')
external JSPromise<JSString>? _recognizeOcrText(JSString base64Image);

@JS('decodeQrCodeFromImage')
external JSPromise<JSString?>? _decodeQrCodeFromImage(JSString base64Image);

class PlatformOcrService {
  static Future<String> processPath(String imagePath) async {
    return '';
  }

  static Future<String> processBytes(Uint8List bytes) async {
    try {
      final base64Str = 'data:image/jpeg;base64,${base64Encode(bytes)}';
      final promise = _recognizeOcrText(base64Str.toJS);
      if (promise == null) return '';
      final jsResult = await promise.toDart;
      return jsResult.toDart;
    } catch (_) {
      return '';
    }
  }

  static Future<String?> decodeQrBytes(Uint8List bytes) async {
    try {
      final base64Str = 'data:image/jpeg;base64,${base64Encode(bytes)}';
      final promise = _decodeQrCodeFromImage(base64Str.toJS);
      if (promise == null) return null;
      final jsResult = await promise.toDart;
      return jsResult?.toDart;
    } catch (_) {
      return null;
    }
  }
}
