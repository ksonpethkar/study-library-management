import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:csv/csv.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:study_library/core/providers/library_provider.dart';
import 'package:study_library/features/students/data/repositories/student_repository.dart';

class BulkImportScreen extends ConsumerStatefulWidget {
  const BulkImportScreen({super.key});

  @override
  ConsumerState<BulkImportScreen> createState() => _BulkImportScreenState();
}

class _BulkImportScreenState extends ConsumerState<BulkImportScreen> {
  List<Map<String, String>> _parsedStudents = [];
  bool _isImporting = false;
  int _importedCount = 0;
  int _skippedDuplicateCount = 0;
  int _errorCount = 0;
  String? _fileName;
  bool _importDone = false;

  static const _nameKeys = ['name', 'student name', 'full name', 'student'];
  static const _phoneKeys = ['phone', 'mobile', 'contact', 'phone number', 'mobile number'];
  static const _emailKeys = ['email', 'email id', 'e-mail'];
  static const _genderKeys = ['gender', 'sex'];
  static const _addressKeys = ['address', 'city'];

  Future<void> _pickFile() async {
    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
    );

    if (files.isEmpty) return;

    final file = files.first;
    _fileName = file.name;

    try {
      final bytes = await file.readAsBytes();
      final content = utf8.decode(bytes);
      final csvTable = const CsvDecoder().convert(content);

      if (csvTable.length < 2) {
        _showError('CSV must have at least a header row and one data row.');
        return;
      }

      setState(() {
        _parsedStudents = _parseStudents(csvTable);
        _importDone = false;
        _importedCount = 0;
        _skippedDuplicateCount = 0;
        _errorCount = 0;
      });
    } catch (e) {
      _showError('Failed to read CSV: $e');
    }
  }

  List<Map<String, String>> _parseStudents(List<List<dynamic>> csv) {
    final headers = csv[0].map((h) => h.toString().trim().toLowerCase()).toList();
    final students = <Map<String, String>>[];

    final nameIdx = _findColumn(headers, _nameKeys);
    final phoneIdx = _findColumn(headers, _phoneKeys);
    final emailIdx = _findColumn(headers, _emailKeys);
    final genderIdx = _findColumn(headers, _genderKeys);
    final addressIdx = _findColumn(headers, _addressKeys);

    if (nameIdx == -1) {
      _showError('CSV must have a "Name" column.');
      return [];
    }

    for (int i = 1; i < csv.length; i++) {
      final row = csv[i];
      final name = _getCell(row, nameIdx);
      if (name.isEmpty) continue;

      students.add({
        'name': name,
        'phone': _getCell(row, phoneIdx),
        'email': _getCell(row, emailIdx),
        'gender': _getCell(row, genderIdx).toLowerCase(),
        'address': _getCell(row, addressIdx),
      });
    }

    return students;
  }

  int _findColumn(List<String> headers, List<String> keys) {
    for (int i = 0; i < headers.length; i++) {
      if (keys.contains(headers[i])) return i;
    }
    return -1;
  }

  String _getCell(List<dynamic> row, int idx) {
    if (idx < 0 || idx >= row.length) return '';
    return row[idx]?.toString().trim() ?? '';
  }

  Future<void> _importStudents() async {
    final libraryId = ref.read(currentLibraryIdProvider);
    if (libraryId == null || libraryId.isEmpty) {
      _showError('Library not loaded. Please go back and try again.');
      return;
    }

    setState(() {
      _isImporting = true;
      _importedCount = 0;
      _skippedDuplicateCount = 0;
      _errorCount = 0;
    });

    try {
      // Pre-fetch all existing student phone numbers to avoid duplicate queries
      final existingDocs = await FirebaseFirestore.instance
          .collection('libraries')
          .doc(libraryId)
          .collection('students')
          .get();
      final existingPhones = existingDocs.docs
          .map((d) => (d.data()['phone'] ?? '').toString().trim())
          .where((p) => p.isNotEmpty)
          .toSet();

      final seenInFile = <String>{};
      final repo = StudentRepository();

      for (final student in _parsedStudents) {
        final phone = (student['phone'] ?? '').trim();
        // Check if duplicate within file or already registered
        if (phone.isNotEmpty && (seenInFile.contains(phone) || existingPhones.contains(phone))) {
          setState(() => _skippedDuplicateCount++);
          continue;
        }

        if (phone.isNotEmpty) {
          seenInFile.add(phone);
        }

        try {
          await repo.addStudent(
            libraryId: libraryId,
            name: student['name']!,
            phone: phone,
            email: student['email'] ?? '',
            gender: student['gender'] ?? 'male',
            address: student['address'] ?? '',
          );
          if (phone.isNotEmpty) existingPhones.add(phone);
          setState(() => _importedCount++);
        } catch (e) {
          setState(() => _errorCount++);
        }
      }
    } catch (e) {
      _showError('Failed to import: $e');
    }

    setState(() {
      _isImporting = false;
      _importDone = true;
    });
  }

  void _showError(String msg) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Bulk Import Students')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('CSV Format', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    const Text('Your CSV file should have these columns:'),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        _chip('Name *', Colors.red),
                        _chip('Phone', Colors.blue),
                        _chip('Email', Colors.green),
                        _chip('Gender', Colors.orange),
                        _chip('Address', Colors.purple),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text('* Required column', style: theme.textTheme.bodySmall?.copyWith(color: Colors.red)),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _isImporting ? null : _pickFile,
                icon: const Icon(Icons.upload_file),
                label: Text(_fileName ?? 'Select CSV File'),
              ),
            ),

            const SizedBox(height: 16),

            if (_parsedStudents.isNotEmpty) ...[
              Text(
                '${_parsedStudents.length} students found',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),

              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      headingRowColor: WidgetStateProperty.all(theme.colorScheme.surfaceContainerHighest),
                      columns: const [
                        DataColumn(label: Text('#')),
                        DataColumn(label: Text('Name')),
                        DataColumn(label: Text('Phone')),
                        DataColumn(label: Text('Email')),
                        DataColumn(label: Text('Gender')),
                      ],
                      rows: _parsedStudents.take(20).toList().asMap().entries.map((e) {
                        final i = e.key;
                        final s = e.value;
                        return DataRow(cells: [
                          DataCell(Text('${i + 1}')),
                          DataCell(Text(s['name'] ?? '')),
                          DataCell(Text(s['phone'] ?? '')),
                          DataCell(Text(s['email'] ?? '')),
                          DataCell(Text(s['gender'] ?? '')),
                        ]);
                      }).toList(),
                    ),
                  ),
                ),
              ),
              if (_parsedStudents.length > 20)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text('...and ${_parsedStudents.length - 20} more', style: theme.textTheme.bodySmall),
                ),

              const SizedBox(height: 24),

              if (!_importDone)
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _isImporting ? null : _importStudents,
                    icon: _isImporting
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.cloud_upload),
                    label: Text(_isImporting
                        ? 'Importing... $_importedCount / ${_parsedStudents.length}'
                        : 'Import ${_parsedStudents.length} Students'),
                  ),
                ),
            ],

            if (_importDone) ...[
              const SizedBox(height: 16),
              Card(
                color: Colors.green.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      const Icon(Icons.check_circle, size: 48, color: Colors.green),
                      const SizedBox(height: 8),
                      Text('Import Complete!', style: theme.textTheme.titleLarge),
                      const SizedBox(height: 8),
                      Text('✅ $_importedCount imported successfully'),
                      if (_skippedDuplicateCount > 0)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text('ℹ️ $_skippedDuplicateCount skipped (already registered or duplicate in file)',
                              style: const TextStyle(color: Colors.blueGrey)),
                        ),
                      if (_errorCount > 0)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text('❌ $_errorCount failed', style: const TextStyle(color: Colors.red)),
                        ),
                      const SizedBox(height: 16),
                      OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Done'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _chip(String label, Color color) {
    return Chip(
      label: Text(label, style: TextStyle(fontSize: 12, color: color)),
      backgroundColor: color.withValues(alpha: 0.1),
      side: BorderSide(color: color.withValues(alpha: 0.3)),
      visualDensity: VisualDensity.compact,
    );
  }
}
