import 'file_download_stub.dart'
    if (dart.library.html) 'file_download_web.dart'
    if (dart.library.io) 'file_download_io.dart';

class FileDownloadHelper {
  FileDownloadHelper._();

  static Future<void> downloadFile({
    required String fileName,
    required List<int> bytes,
    required String mimeType,
  }) async {
    return downloadFilePlatform(
      fileName: fileName,
      bytes: bytes,
      mimeType: mimeType,
    );
  }
}
