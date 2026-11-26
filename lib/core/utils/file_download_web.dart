import 'dart:js_interop';
import 'dart:typed_data';
import 'package:web/web.dart' as web;

Future<void> downloadFilePlatform({
  required String fileName,
  required List<int> bytes,
  required String mimeType,
}) async {
  final uint8 = bytes is Uint8List ? bytes : Uint8List.fromList(bytes);
  final blob = web.Blob(
    <web.BlobPart>[uint8.toJS].toJS,
    web.BlobPropertyBag(type: mimeType),
  );
  final url = web.URL.createObjectURL(blob);
  final anchor = (web.document.createElement('a') as web.HTMLAnchorElement)
    ..href = url
    ..setAttribute('download', fileName)
    ..style.display = 'none';
  web.document.body?.appendChild(anchor);
  anchor.click();
  anchor.remove();
  // Delay revoking the Object URL so the browser can finish initiating the download stream
  Future.delayed(const Duration(seconds: 5), () {
    web.URL.revokeObjectURL(url);
  });
}
