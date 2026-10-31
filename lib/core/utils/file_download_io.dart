import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

Future<void> downloadFilePlatform({
  required String fileName,
  required List<int> bytes,
  required String mimeType,
}) async {
  final directory = await getApplicationDocumentsDirectory();
  final file = File('${directory.path}/$fileName');
  await file.writeAsBytes(bytes);
  await SharePlus.instance.share(
    ShareParams(
      files: [XFile(file.path, name: fileName, mimeType: mimeType)],
      subject: fileName,
    ),
  );
}
