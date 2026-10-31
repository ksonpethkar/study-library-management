import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:csv/csv.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';

import 'package:study_library/core/providers/library_provider.dart';
import 'package:study_library/core/utils/app_validators.dart';
import 'package:study_library/core/utils/file_download_helper.dart';
import 'package:study_library/core/utils/sequence_counter.dart';
import 'package:study_library/core/security/audit_logger.dart';
import 'package:study_library/models/student_model.dart';

enum ImportRowStatus {
  valid,
  duplicateInDb,
  duplicateInFile,
  error,
}

class ParsedImportRow {
  final int rowIndex;
  final String name;
  final String phone;
  final String email;
  final String gender;
  final String college;
  final String course;
  final String year;
  final String emergencyContact;
  final String address;
  final String bloodGroup;
  ImportRowStatus status;
  String? errorReason;

  ParsedImportRow({
    required this.rowIndex,
    required this.name,
    required this.phone,
    required this.email,
    required this.gender,
    required this.college,
    required this.course,
    required this.year,
    required this.emergencyContact,
    required this.address,
    required this.bloodGroup,
    this.status = ImportRowStatus.valid,
    this.errorReason,
  });

  bool get isValid => status == ImportRowStatus.valid;
}

class BulkImportScreen extends ConsumerStatefulWidget {
  const BulkImportScreen({super.key});

  @override
  ConsumerState<BulkImportScreen> createState() => _BulkImportScreenState();
}

class _BulkImportScreenState extends ConsumerState<BulkImportScreen>
    with SingleTickerProviderStateMixin {
  List<ParsedImportRow> _parsedRows = [];
  bool _isAnalyzing = false;
  bool _isImporting = false;
  double _importProgress = 0.0;
  String _importStatusMessage = '';
  String? _fileName;
  int _fileSizeBytes = 0;
  bool _importDone = false;
  bool _skipInvalid = true;

  int _importedSuccessCount = 0;
  int _skippedDuplicateCount = 0;
  int _skippedErrorCount = 0;

  late TabController _tabController;

  static const String _sampleCsvContent =
      'Name,Mobile,Email,Gender,College,Course,Year,EmergencyContact,Address,BloodGroup\r\n'
      'Aarav Sharma,9876543210,aarav@example.com,male,Delhi University,B.Sc,2nd Year,9876500000,Connaught Place,B+\r\n'
      'Priya Patel,9812345678,priya@example.com,female,IIT Bombay,B.Tech,Final Year,9812300000,Powai,O+\r\n'
      'Rohan Gupta,9823456789,,male,Government College,B.Com,1st Year,,Civil Lines,A+';

  // Flexible column name aliases for CSV mapping
  static const _nameKeys = ['name', 'student name', 'full name', 'student', 'candidate name', 'applicant'];
  static const _phoneKeys = ['phone', 'mobile', 'contact', 'phone number', 'mobile number', 'contact number', 'mobile no', 'cell'];
  static const _emailKeys = ['email', 'email id', 'e-mail', 'mail', 'email address'];
  static const _genderKeys = ['gender', 'sex'];
  static const _collegeKeys = ['college', 'institute', 'institution', 'university', 'college name', 'school'];
  static const _courseKeys = ['course', 'degree', 'stream', 'program', 'branch'];
  static const _yearKeys = ['year', 'year of study', 'semester', 'sem', 'current year'];
  static const _emergencyKeys = ['emergency', 'emergency contact', 'parent mobile', 'guardian phone', 'guardian contact', 'father mobile'];
  static const _addressKeys = ['address', 'city', 'location', 'residence'];
  static const _bloodGroupKeys = ['blood group', 'blood', 'bloodgroup', 'bg'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _downloadSampleCsv() async {
    try {
      final bytes = utf8.encode(_sampleCsvContent);
      await FileDownloadHelper.downloadFile(
        fileName: 'sample_students_import.csv',
        bytes: bytes,
        mimeType: 'text/csv',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sample CSV template downloaded successfully!'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not download sample CSV: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _copySampleHeader() {
    Clipboard.setData(const ClipboardData(
      text: 'Name,Mobile,Email,Gender,College,Course,Year,EmergencyContact,Address,BloodGroup',
    ));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('CSV Header columns copied to clipboard!'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _pickAndAnalyzeFile() async {
    try {
      final pickedFiles = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
      );

      if (pickedFiles.isEmpty) return;

      final file = pickedFiles.first;
      _fileName = file.name;

      setState(() {
        _isAnalyzing = true;
        _importDone = false;
        _parsedRows = [];
      });

      final bytes = await file.readAsBytes();
      _fileSizeBytes = bytes.length;

      if (bytes.isEmpty) {
        _showError('Selected file is empty or could not be read.');
        setState(() => _isAnalyzing = false);
        return;
      }

      final content = utf8.decode(bytes, allowMalformed: true);
      final csvTable = const CsvDecoder().convert(content);

      if (csvTable.length < 2) {
        _showError('CSV must have a header row and at least one data row.');
        setState(() => _isAnalyzing = false);
        return;
      }

      await _processAndValidateCsv(csvTable);
    } catch (e) {
      _showError('Failed to parse CSV file: $e');
    } finally {
      if (mounted) {
        setState(() => _isAnalyzing = false);
      }
    }
  }

  int _findColumnIndex(List<String> headers, List<String> aliases) {
    for (int i = 0; i < headers.length; i++) {
      if (aliases.contains(headers[i])) return i;
    }
    return -1;
  }

  String _getCell(List<dynamic> row, int idx) {
    if (idx < 0 || idx >= row.length) return '';
    return row[idx]?.toString().trim() ?? '';
  }

  Future<void> _processAndValidateCsv(List<List<dynamic>> csv) async {
    final libraryId = ref.read(currentLibraryIdProvider);
    if (libraryId == null || libraryId.isEmpty) {
      _showError('No active library selected.');
      return;
    }

    // 1. Map columns from header row
    final headers = csv[0].map((h) => h.toString().trim().toLowerCase()).toList();

    final nameIdx = _findColumnIndex(headers, _nameKeys);
    final phoneIdx = _findColumnIndex(headers, _phoneKeys);
    final emailIdx = _findColumnIndex(headers, _emailKeys);
    final genderIdx = _findColumnIndex(headers, _genderKeys);
    final collegeIdx = _findColumnIndex(headers, _collegeKeys);
    final courseIdx = _findColumnIndex(headers, _courseKeys);
    final yearIdx = _findColumnIndex(headers, _yearKeys);
    final emergencyIdx = _findColumnIndex(headers, _emergencyKeys);
    final addressIdx = _findColumnIndex(headers, _addressKeys);
    final bloodGroupIdx = _findColumnIndex(headers, _bloodGroupKeys);

    if (nameIdx == -1) {
      _showError('CSV is missing a required "Name" column.');
      return;
    }
    if (phoneIdx == -1) {
      _showError('CSV is missing a required "Mobile / Phone" column.');
      return;
    }

    // 2. Fetch existing student phones from Firestore in one go
    final existingSnap = await FirebaseFirestore.instance
        .collection('libraries')
        .doc(libraryId)
        .collection('students')
        .get();

    final existingPhones = existingSnap.docs
        .map((d) => (d.data()['phone'] ?? '').toString().replaceAll(RegExp(r'\D'), ''))
        .where((p) => p.isNotEmpty)
        .toSet();

    final seenPhonesInFile = <String>{};
    final rows = <ParsedImportRow>[];

    for (int i = 1; i < csv.length; i++) {
      final row = csv[i];
      if (row.isEmpty || row.every((c) => c == null || c.toString().trim().isEmpty)) {
        continue;
      }

      final rawName = _getCell(row, nameIdx);
      final rawPhone = _getCell(row, phoneIdx);
      final rawEmail = _getCell(row, emailIdx);
      final rawGender = _getCell(row, genderIdx).toLowerCase();
      final rawCollege = _getCell(row, collegeIdx);
      final rawCourse = _getCell(row, courseIdx);
      final rawYear = _getCell(row, yearIdx);
      final rawEmergency = _getCell(row, emergencyIdx);
      final rawAddress = _getCell(row, addressIdx);
      final rawBloodGroup = _getCell(row, bloodGroupIdx).toUpperCase();

      final parsedRow = ParsedImportRow(
        rowIndex: i,
        name: rawName,
        phone: rawPhone,
        email: rawEmail,
        gender: (rawGender == 'f' || rawGender == 'female') ? 'female' : 'male',
        college: rawCollege,
        course: rawCourse,
        year: rawYear,
        emergencyContact: rawEmergency,
        address: rawAddress,
        bloodGroup: rawBloodGroup,
      );

      // Validation Step 1: Name
      final nameErr = AppValidators.name(rawName, required: true);
      if (nameErr != null) {
        parsedRow.status = ImportRowStatus.error;
        parsedRow.errorReason = nameErr;
        rows.add(parsedRow);
        continue;
      }

      // Validation Step 2: Phone format
      final phoneErr = AppValidators.phone(rawPhone, required: true);
      if (phoneErr != null) {
        parsedRow.status = ImportRowStatus.error;
        parsedRow.errorReason = phoneErr;
        rows.add(parsedRow);
        continue;
      }

      final cleanDigits = rawPhone.replaceAll(RegExp(r'\D'), '');

      // Validation Step 3: Duplicate in File
      if (seenPhonesInFile.contains(cleanDigits)) {
        parsedRow.status = ImportRowStatus.duplicateInFile;
        parsedRow.errorReason = 'Duplicate phone number inside this file';
        rows.add(parsedRow);
        continue;
      }
      seenPhonesInFile.add(cleanDigits);

      // Validation Step 4: Duplicate in Database
      if (existingPhones.contains(cleanDigits)) {
        parsedRow.status = ImportRowStatus.duplicateInDb;
        parsedRow.errorReason = 'Already registered in this library';
        rows.add(parsedRow);
        continue;
      }

      // Validation Step 5: Optional Email
      if (rawEmail.isNotEmpty) {
        final emailErr = AppValidators.email(rawEmail);
        if (emailErr != null) {
          parsedRow.status = ImportRowStatus.error;
          parsedRow.errorReason = emailErr;
          rows.add(parsedRow);
          continue;
        }
      }

      // Validation Step 6: Optional College
      if (rawCollege.isNotEmpty) {
        final collegeErr = AppValidators.collegeName(rawCollege);
        if (collegeErr != null) {
          parsedRow.status = ImportRowStatus.error;
          parsedRow.errorReason = collegeErr;
          rows.add(parsedRow);
          continue;
        }
      }

      // Validation Step 7: Optional Year
      if (rawYear.isNotEmpty) {
        final yearErr = AppValidators.yearOrSem(rawYear);
        if (yearErr != null) {
          parsedRow.status = ImportRowStatus.error;
          parsedRow.errorReason = yearErr;
          rows.add(parsedRow);
          continue;
        }
      }

      // Validation Step 8: Optional Blood Group
      if (rawBloodGroup.isNotEmpty) {
        final bgErr = AppValidators.bloodGroup(rawBloodGroup);
        if (bgErr != null) {
          parsedRow.status = ImportRowStatus.error;
          parsedRow.errorReason = bgErr;
          rows.add(parsedRow);
          continue;
        }
      }

      rows.add(parsedRow);
    }

    setState(() {
      _parsedRows = rows;
    });
  }

  Future<void> _executeImport() async {
    final libraryId = ref.read(currentLibraryIdProvider);
    final library = ref.read(currentLibraryProvider).value;
    if (libraryId == null || libraryId.isEmpty) {
      _showError('Library not found.');
      return;
    }

    final toImport = _skipInvalid
        ? _parsedRows.where((r) => r.isValid).toList()
        : _parsedRows;

    if (toImport.isEmpty) {
      _showError('No valid student rows to import.');
      return;
    }

    setState(() {
      _isImporting = true;
      _importProgress = 0.0;
      _importStatusMessage = 'Reserving admission IDs...';
      _importedSuccessCount = 0;
      _skippedDuplicateCount = _parsedRows
          .where((r) =>
              r.status == ImportRowStatus.duplicateInDb ||
              r.status == ImportRowStatus.duplicateInFile)
          .length;
      _skippedErrorCount =
          _parsedRows.where((r) => r.status == ImportRowStatus.error).length;
    });

    final prefix = library?.membershipPrefix.isNotEmpty == true
        ? library!.membershipPrefix
        : 'CC';

    try {
      // 1. Reserve admission numbers in a single atomic transaction
      final admissionIds = await SequenceCounter.nextMembershipNumberBatch(
        libraryId,
        count: toImport.length,
        prefix: prefix,
      );

      final firestore = FirebaseFirestore.instance;
      final studentsColl = firestore
          .collection('libraries')
          .doc(libraryId)
          .collection('students');

      // 2. Write in chunks of 200 (well within Firestore's 500 operation limit per batch)
      const chunkSize = 200;
      int processed = 0;

      for (int i = 0; i < toImport.length; i += chunkSize) {
        final end = (i + chunkSize < toImport.length) ? i + chunkSize : toImport.length;
        final chunk = toImport.sublist(i, end);

        final batch = firestore.batch();

        for (int c = 0; c < chunk.length; c++) {
          final row = chunk[c];
          final admissionId = admissionIds[i + c];
          final docRef = studentsColl.doc();

          final student = StudentModel(
            id: docRef.id,
            name: row.name,
            fatherName: '',
            phone: row.phone.replaceAll(RegExp(r'\D'), ''),
            email: row.email,
            gender: row.gender == 'female' ? Gender.female : Gender.male,
            address: row.address,
            pincode: '',
            govIdType: GovIdType.aadhaar,
            govIdNumber: '',
            govIdImageUrl: '',
            photoUrl: '',
            college: row.college,
            course: row.course,
            year: row.year,
            emergencyContact: row.emergencyContact,
            membershipStatus: MembershipStatus.pending,
            customFields: {},
            membershipNumber: admissionId,
            bloodGroup: row.bloodGroup.isNotEmpty ? row.bloodGroup : null,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );

          batch.set(docRef, student.toJson());
        }

        await batch.commit();
        processed += chunk.length;

        setState(() {
          _importedSuccessCount = processed;
          _importProgress = processed / toImport.length;
          _importStatusMessage =
              'Imported $processed of ${toImport.length} students...';
        });
      }

      // 3. Record Audit Log
      AuditLogger().log(
        action: AuditAction.imported,
        entityType: AuditEntity.student,
        libraryId: libraryId,
        details: {
          'action': 'bulk_import_csv',
          'totalImported': _importedSuccessCount,
          'fileName': _fileName ?? '',
        },
      ).ignore();

      setState(() {
        _importDone = true;
      });
    } catch (e) {
      _showError('Batch import encountered an error: $e');
    } finally {
      if (mounted) {
        setState(() => _isImporting = false);
      }
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final validCount = _parsedRows.where((r) => r.isValid).length;
    final dupCount = _parsedRows
        .where((r) =>
            r.status == ImportRowStatus.duplicateInDb ||
            r.status == ImportRowStatus.duplicateInFile)
        .length;
    final errCount =
        _parsedRows.where((r) => r.status == ImportRowStatus.error).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bulk Student Import'),
        actions: [
          IconButton(
            icon: const Icon(Icons.download_rounded),
            tooltip: 'Download Sample CSV',
            onPressed: _downloadSampleCsv,
          ),
          IconButton(
            icon: const Icon(Icons.copy_rounded),
            tooltip: 'Copy Header Columns',
            onPressed: _copySampleHeader,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Instructions Card
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: theme.colorScheme.outlineVariant),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(Icons.table_chart_rounded,
                              color: theme.colorScheme.onPrimaryContainer,
                              size: 20),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'CSV Format Specifications',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Prepare your student admissions spreadsheet with these column names:',
                      style: TextStyle(fontSize: 13),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        _chip('Name *', Colors.red),
                        _chip('Mobile *', Colors.blue),
                        _chip('Email', Colors.green),
                        _chip('Gender', Colors.orange),
                        _chip('College', Colors.indigo),
                        _chip('Course', Colors.teal),
                        _chip('Year', Colors.deepPurple),
                        _chip('EmergencyContact', Colors.brown),
                        _chip('Address', Colors.cyan),
                        _chip('BloodGroup', Colors.pink),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                          ),
                          icon: const Icon(Icons.file_download_outlined, size: 16),
                          label: const Text('Download Sample CSV'),
                          onPressed: _downloadSampleCsv,
                        ),
                        const SizedBox(width: 8),
                        TextButton.icon(
                          style: TextButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                          ),
                          icon: const Icon(Icons.copy_rounded, size: 16),
                          label: const Text('Copy Columns'),
                          onPressed: _copySampleHeader,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Pick File Area
            InkWell(
              onTap: _isAnalyzing || _isImporting ? null : _pickAndAnalyzeFile,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                decoration: BoxDecoration(
                  color: isDark
                      ? theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3)
                      : theme.colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _fileName != null
                        ? theme.colorScheme.primary
                        : theme.colorScheme.outlineVariant,
                    width: _fileName != null ? 1.8 : 1.0,
                  ),
                ),
                child: Column(
                  children: [
                    Icon(
                      _fileName != null
                          ? Icons.description_rounded
                          : Icons.cloud_upload_outlined,
                      size: 36,
                      color: _fileName != null
                          ? theme.colorScheme.primary
                          : Colors.grey.shade600,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _fileName ?? 'Tap to Select Student CSV File',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: _fileName != null
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _fileName != null
                          ? '${(_fileSizeBytes / 1024).toStringAsFixed(1)} KB · Tap to change file'
                          : 'Supports .csv exported from Excel, Google Sheets, or any CRM',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            if (_isAnalyzing) ...[
              const SizedBox(height: 24),
              const Center(
                child: Column(
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 10),
                    Text('Analyzing and validating student records...'),
                  ],
                ),
              ),
            ],

            // Analysis Metrics Dashboard
            if (_parsedRows.isNotEmpty && !_isAnalyzing) ...[
              const SizedBox(height: 20),
              Row(
                children: [
                  _statCard('Total Records', _parsedRows.length, Colors.blue),
                  const SizedBox(width: 8),
                  _statCard('Ready to Import', validCount, Colors.green),
                  const SizedBox(width: 8),
                  _statCard('Duplicates', dupCount, Colors.orange),
                  const SizedBox(width: 8),
                  _statCard('Errors', errCount, Colors.red),
                ],
              ),

              const SizedBox(height: 16),

              // Filter Tabs
              TabBar(
                controller: _tabController,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                labelColor: theme.colorScheme.primary,
                unselectedLabelColor: Colors.grey,
                indicatorColor: theme.colorScheme.primary,
                tabs: [
                  Tab(text: 'All (${_parsedRows.length})'),
                  Tab(text: 'Ready ($validCount)'),
                  Tab(text: 'Duplicates ($dupCount)'),
                  Tab(text: 'Errors ($errCount)'),
                ],
              ),

              const SizedBox(height: 12),

              // Rows Preview
              SizedBox(
                height: 280,
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildRowList(_parsedRows),
                    _buildRowList(_parsedRows.where((r) => r.isValid).toList()),
                    _buildRowList(_parsedRows
                        .where((r) =>
                            r.status == ImportRowStatus.duplicateInDb ||
                            r.status == ImportRowStatus.duplicateInFile)
                        .toList()),
                    _buildRowList(_parsedRows
                        .where((r) => r.status == ImportRowStatus.error)
                        .toList()),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Skip invalid toggle
              CheckboxListTile(
                value: _skipInvalid,
                onChanged: (val) => setState(() => _skipInvalid = val ?? true),
                title: const Text(
                  'Skip invalid rows and duplicates automatically',
                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
                ),
                subtitle: const Text(
                  'Only records with valid name, mobile, and no duplicates will be imported.',
                  style: TextStyle(fontSize: 12),
                ),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
              ),

              const SizedBox(height: 12),

              // Action / Progress Area
              if (_isImporting) ...[
                LinearProgressIndicator(value: _importProgress),
                const SizedBox(height: 8),
                Text(
                  _importStatusMessage,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
              ] else if (!_importDone) ...[
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF059669),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.cloud_upload_rounded),
                  label: Text(
                    'Import $validCount Students Now',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  onPressed: validCount > 0 ? _executeImport : null,
                ),
              ],
            ],

            // Done Card
            if (_importDone) ...[
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.check_circle_rounded,
                        size: 48, color: Colors.green),
                    const SizedBox(height: 10),
                    Text(
                      'Import Complete!',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Successfully imported $_importedSuccessCount students into your library directory.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 13.5),
                    ),
                    if (_skippedDuplicateCount > 0) ...[
                      const SizedBox(height: 4),
                      Text(
                        'ℹ️ $_skippedDuplicateCount duplicates were safely skipped.',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                      ),
                    ],
                    if (_skippedErrorCount > 0) ...[
                      const SizedBox(height: 4),
                      Text(
                        '⚠️ $_skippedErrorCount invalid rows were bypassed.',
                        style: TextStyle(fontSize: 12, color: Colors.orange.shade800),
                      ),
                    ],
                    const SizedBox(height: 18),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () {
                        context.go('/admin/students');
                      },
                      child: const Text('View Student Directory'),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _statCard(String label, int count, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Column(
          children: [
            Text(
              '$count',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRowList(List<ParsedImportRow> rows) {
    if (rows.isEmpty) {
      return Center(
        child: Text(
          'No records in this category',
          style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
        ),
      );
    }

    return ListView.separated(
      itemCount: rows.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (ctx, idx) {
        final r = rows[idx];
        return ListTile(
          dense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 10),
          leading: CircleAvatar(
            radius: 14,
            backgroundColor: r.isValid
                ? Colors.green.withValues(alpha: 0.15)
                : (r.status == ImportRowStatus.error
                    ? Colors.red.withValues(alpha: 0.15)
                    : Colors.orange.withValues(alpha: 0.15)),
            child: Icon(
              r.isValid
                  ? Icons.check_rounded
                  : (r.status == ImportRowStatus.error
                      ? Icons.close_rounded
                      : Icons.warning_amber_rounded),
              size: 16,
              color: r.isValid
                  ? Colors.green
                  : (r.status == ImportRowStatus.error ? Colors.red : Colors.orange),
            ),
          ),
          title: Text(
            '#${r.rowIndex} · ${r.name}',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
          subtitle: Text(
            r.isValid
                ? '${r.phone} · ${r.gender}${r.college.isNotEmpty ? " · ${r.college}" : ""}'
                : '${r.phone} — ${r.errorReason ?? ""}',
            style: TextStyle(
              fontSize: 11.5,
              color: r.isValid ? Colors.grey.shade600 : Colors.red.shade700,
            ),
          ),
          trailing: _statusBadge(r),
        );
      },
    );
  }

  Widget _statusBadge(ParsedImportRow r) {
    Color bg;
    Color fg;
    String text;

    switch (r.status) {
      case ImportRowStatus.valid:
        bg = Colors.green.withValues(alpha: 0.12);
        fg = Colors.green.shade800;
        text = 'Ready';
        break;
      case ImportRowStatus.duplicateInDb:
        bg = Colors.orange.withValues(alpha: 0.12);
        fg = Colors.orange.shade900;
        text = 'In Library';
        break;
      case ImportRowStatus.duplicateInFile:
        bg = Colors.orange.withValues(alpha: 0.12);
        fg = Colors.orange.shade900;
        text = 'Duplicate';
        break;
      case ImportRowStatus.error:
        bg = Colors.red.withValues(alpha: 0.12);
        fg = Colors.red.shade800;
        text = 'Invalid';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: fg),
      ),
    );
  }

  Widget _chip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }
}
