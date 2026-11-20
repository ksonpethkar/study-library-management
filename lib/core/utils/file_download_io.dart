import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

Future<void> downloadFilePlatform({
  required String fileName,
  required List<int> bytes,
  required String mimeType,
}) async {
  File? targetFile;

  // On Android, attempt writing directly to the public Download directory
  if (Platform.isAndroid) {
    try {
      final publicDownloads = Directory('/storage/emulated/0/Download');
      if (await publicDownloads.exists()) {
        final f = File('${publicDownloads.path}/$fileName');
        await f.writeAsBytes(bytes, flush: true);
        targetFile = f;
      }
    } catch (e) {
      debugPrint('[FileDownload] Public Download folder write error: $e');
    }

    if (targetFile == null) {
      try {
        final d = await getDownloadsDirectory();
        if (d != null) {
          final f = File('${d.path}/$fileName');
          await f.writeAsBytes(bytes, flush: true);
          targetFile = f;
        }
      } catch (e) {
        debugPrint('[FileDownload] getDownloadsDirectory write error: $e');
      }
    }
  }

  // Fallback to application documents directory (works reliably on iOS/Android/Desktop)
  if (targetFile == null) {
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/$fileName');
    await file.writeAsBytes(bytes, flush: true);
    targetFile = file;
  }

  // Always share or notify share sheet so user can open/save immediately
  try {
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(targetFile.path, name: fileName, mimeType: mimeType)],
        subject: fileName,
      ),
    );
  } catch (e) {
    debugPrint('[FileDownload] SharePlus error: $e');
  }
}
