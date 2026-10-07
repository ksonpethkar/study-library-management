import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

class ExportUtils {
  /// Exports a list of maps to a CSV file.
  static Future<File> exportToCsv(List<Map<String, dynamic>> data, String filename) async {
    try {
      if (data.isEmpty) {
        throw Exception('There is no data to export.');
      }

      final headers = data.first.keys.toList();
      final buffer = StringBuffer();

      // Write headers
      buffer.writeln(headers.map((h) => _escapeCsv(h)).join(','));

      // Write rows
      for (final item in data) {
        final row = headers.map((header) => _escapeCsv(item[header]?.toString() ?? '')).join(',');
        buffer.writeln(row);
      }

      final dir = await getApplicationDocumentsDirectory();
      final targetPath = path.join(dir.path, '$filename.csv');
      final file = File(targetPath);

      await file.writeAsString(buffer.toString());
      return file;
    } catch (e) {
      throw Exception('We couldn\'t export the data. Please try again.');
    }
  }

  /// Exports a map to a JSON file.
  static Future<File> exportToJson(Map<String, dynamic> data, String filename) async {
    try {
      final jsonData = const JsonEncoder.withIndent('  ').convert(data);

      final dir = await getApplicationDocumentsDirectory();
      final targetPath = path.join(dir.path, '$filename.json');
      final file = File(targetPath);

      await file.writeAsString(jsonData);
      return file;
    } catch (e) {
      throw Exception('We couldn\'t export the data. Please try again.');
    }
  }

  /// Escapes a CSV field value properly.
  static String _escapeCsv(String value) {
    if (value.contains(',') || value.contains('"') || value.contains('\n')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }
}
