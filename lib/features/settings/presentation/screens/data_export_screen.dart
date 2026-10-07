import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:typed_data';
import 'package:study_library/core/providers/library_provider.dart';

class DataExportScreen extends ConsumerStatefulWidget {
  const DataExportScreen({super.key});

  @override
  ConsumerState<DataExportScreen> createState() => _DataExportScreenState();
}

class _DataExportScreenState extends ConsumerState<DataExportScreen> {
  bool _isExporting = false;
  String _status = '';

  Future<void> _exportStudents() async {
    final libraryId = ref.read(currentLibraryIdProvider);
    if (libraryId == null || libraryId.isEmpty) return;

    setState(() {
      _isExporting = true;
      _status = 'Fetching students...';
    });

    try {
      final snap = await FirebaseFirestore.instance
          .collection('libraries')
          .doc(libraryId)
          .collection('students')
          .get();

      final csv = StringBuffer();
      csv.writeln('Name,Phone,Email,Gender,Address,College,Course,Status,Joined');

      for (final doc in snap.docs) {
        final d = doc.data();
        final name = _escape(d['name'] ?? '');
        final phone = _escape(d['phone'] ?? '');
        final email = _escape(d['email'] ?? '');
        final gender = d['gender'] ?? '';
        final address = _escape(d['address'] ?? '');
        final college = _escape(d['college'] ?? '');
        final course = _escape(d['course'] ?? '');
        final status = d['membershipStatus'] ?? '';
        final created = d['createdAt'] ?? '';
        csv.writeln('$name,$phone,$email,$gender,$address,$college,$course,$status,$created');
      }

      setState(() => _status = 'Sharing ${snap.docs.length} students...');

      final bytes = Uint8List.fromList(utf8.encode(csv.toString()));
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile.fromData(bytes, name: 'students_export.csv', mimeType: 'text/csv')],
          subject: 'Students Export',
        ),
      );

      setState(() => _status = '✅ Exported ${snap.docs.length} students');
    } catch (e) {
      setState(() => _status = '❌ Error: $e');
    }

    setState(() => _isExporting = false);
  }

  Future<void> _exportPayments() async {
    final libraryId = ref.read(currentLibraryIdProvider);
    if (libraryId == null || libraryId.isEmpty) return;

    setState(() {
      _isExporting = true;
      _status = 'Fetching payments...';
    });

    try {
      final snap = await FirebaseFirestore.instance
          .collection('libraries')
          .doc(libraryId)
          .collection('payments')
          .get();

      final csv = StringBuffer();
      csv.writeln('Student ID,Amount,Method,Status,Date,Reference,Notes');

      for (final doc in snap.docs) {
        final d = doc.data();
        final studentId = d['studentId'] ?? '';
        final amount = d['amount'] ?? 0;
        final method = d['method'] ?? '';
        final status = d['status'] ?? '';
        final date = d['date'] ?? '';
        final ref = _escape(d['referenceNumber'] ?? '');
        final notes = _escape(d['notes'] ?? '');
        csv.writeln('$studentId,$amount,$method,$status,$date,$ref,$notes');
      }

      setState(() => _status = 'Sharing ${snap.docs.length} payments...');

      final bytes = Uint8List.fromList(utf8.encode(csv.toString()));
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile.fromData(bytes, name: 'payments_export.csv', mimeType: 'text/csv')],
          subject: 'Payments Export',
        ),
      );

      setState(() => _status = '✅ Exported ${snap.docs.length} payments');
    } catch (e) {
      setState(() => _status = '❌ Error: $e');
    }

    setState(() => _isExporting = false);
  }

  String _escape(String value) {
    if (value.contains(',') || value.contains('"') || value.contains('\n')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Export Data')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Export your data as CSV files', style: theme.textTheme.bodyLarge),
            const SizedBox(height: 24),

            Card(
              child: ListTile(
                leading: const Icon(Icons.people, color: Colors.blue),
                title: const Text('Export Students'),
                subtitle: const Text('Name, phone, email, status, etc.'),
                trailing: _isExporting ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.download),
                onTap: _isExporting ? null : _exportStudents,
              ),
            ),
            const SizedBox(height: 8),
            Card(
              child: ListTile(
                leading: const Icon(Icons.payment, color: Colors.green),
                title: const Text('Export Payments'),
                subtitle: const Text('Amount, method, date, status'),
                trailing: _isExporting ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.download),
                onTap: _isExporting ? null : _exportPayments,
              ),
            ),

            if (_status.isNotEmpty) ...[
              const SizedBox(height: 24),
              Card(
                color: _status.startsWith('✅') ? Colors.green.shade50 : _status.startsWith('❌') ? Colors.red.shade50 : null,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      if (!_status.startsWith('✅') && !_status.startsWith('❌'))
                        const Padding(
                          padding: EdgeInsets.only(right: 12),
                          child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                        ),
                      Expanded(child: Text(_status)),
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
}
