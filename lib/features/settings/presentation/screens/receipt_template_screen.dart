import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:printing/printing.dart';
import 'package:study_library/core/providers/library_provider.dart';
import 'package:study_library/models/receipt_model.dart';
import 'package:study_library/models/student_model.dart';
import 'package:study_library/models/plan_model.dart';
import 'package:study_library/models/library_model.dart';
import 'package:study_library/services/pdf_service.dart';
import 'package:study_library/services/image_service.dart';

class ReceiptTemplateScreen extends ConsumerStatefulWidget {
  const ReceiptTemplateScreen({super.key});

  @override
  ConsumerState<ReceiptTemplateScreen> createState() => _ReceiptTemplateScreenState();
}

class _ReceiptTemplateScreenState extends ConsumerState<ReceiptTemplateScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final Map<String, bool> _elements = {
    'Logo': true,
    'Org Name': true,
    'Address': true,
    'Contact': true,
    'Tagline': false,
    'Receipt #': true,
    'Date': true,
    'Student Name': true,
    'Terms': true,
    'Signature': true,
    'Seat Number': false,
    'Plan Name': true,
    'Valid From': true,
    'Valid To': true,
    'Next Due Date': false,
    'Payment Method': true,
  };

  final TextEditingController _prefixController = TextEditingController(text: 'REC');
  final TextEditingController _termsController = TextEditingController();

  // Stamp settings
  String? _stampUrl;
  bool _stampEnabled = true;
  double _stampRotation = -12.0;
  double _stampScale = 1.0;

  // Watermark settings
  bool _watermarkEnabled = false;
  double _watermarkOpacity = 0.12;
  double _watermarkScale = 0.4;

  // Header settings
  double _headerFontSize = 22.0;

  // Style / layout settings
  String _receiptStyle = 'classic';
  String _pageSize = 'a4';
  Color _primaryColor = const Color(0xFF1565C0);

  // Footer
  final TextEditingController _footerController = TextEditingController(text: 'Thank you for your payment! 📚');

  bool _isLoading = true;
  bool _isSaving = false;
  bool _isUploadingStamp = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadTemplate();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _prefixController.dispose();
    _termsController.dispose();
    _footerController.dispose();
    super.dispose();
  }

  Future<void> _loadTemplate() async {
    final libraryId = ref.read(currentLibraryIdProvider);
    if (libraryId == null || libraryId.isEmpty) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection('libraries')
          .doc(libraryId)
          .collection('settings')
          .doc('receipt_template')
          .get();

      if (doc.exists && mounted) {
        final data = doc.data() ?? {};
        setState(() {
          _prefixController.text = (data['prefix'] as String?) ?? 'REC';
          _termsController.text = (data['customTerms'] as String?) ?? '';
          _footerController.text = (data['footerText'] as String?) ?? 'Thank you for your payment! 📚';
          _stampUrl = data['stampUrl'] as String?;
          _stampEnabled = (data['stampEnabled'] as bool?) ?? (_stampUrl != null && _stampUrl!.isNotEmpty);
          _stampRotation = ((data['stampRotation'] as num?)?.toDouble()) ?? -12.0;
          _stampScale = ((data['stampScale'] as num?)?.toDouble()) ?? 1.0;
          _watermarkEnabled = (data['watermarkEnabled'] as bool?) ?? false;
          _watermarkOpacity = ((data['watermarkOpacity'] as num?)?.toDouble()) ?? 0.12;
          _watermarkScale = ((data['watermarkScale'] as num?)?.toDouble()) ?? 0.4;
          _headerFontSize = ((data['headerFontSize'] as num?)?.toDouble()) ?? 22.0;
          _receiptStyle = (data['receiptStyle'] as String?) ?? 'classic';
          _pageSize = (data['pageSize'] as String?) ?? 'a4';

          final colorHex = data['primaryColor'] as String?;
          if (colorHex != null && colorHex.isNotEmpty) {
            try { final v = int.parse('FF$colorHex', radix: 16); _primaryColor = Color.fromARGB((v >> 24) & 0xFF, (v >> 16) & 0xFF, (v >> 8) & 0xFF, v & 0xFF); } catch (_) {}
          }

          for (final key in _elements.keys) {
            if (data.containsKey(key)) {
              _elements[key] = data[key] as bool;
            }
          }
        });
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickStamp() async {
    final libraryId = ref.read(currentLibraryIdProvider);
    if (libraryId == null || libraryId.isEmpty) return;

    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Take Photo of Stamp'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choose from Gallery'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            if (_stampUrl != null && _stampUrl!.isNotEmpty)
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('Remove Stamp', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(ctx);
                  setState(() => _stampUrl = null);
                },
              ),
          ],
        ),
      ),
    );

    if (source == null) return;

    setState(() => _isUploadingStamp = true);
    try {
      final file = await ImageService.pickAndCompressImage(source: source);
      if (file == null) return;

      String url;
      try {
        final path = 'libraries/$libraryId/stamp/stamp_${DateTime.now().millisecondsSinceEpoch}.jpg';
        url = await ImageService.uploadToStorage(file: file, path: path);
      } catch (_) {
        final bytes = await file.readAsBytes();
        url = 'data:image/jpeg;base64,${base64Encode(bytes)}';
      }

      if (mounted) {
        setState(() {
          _stampUrl = url;
          _stampEnabled = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Official stamp uploaded! Remember to save settings.'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Stamp upload error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploadingStamp = false);
    }
  }

  Future<void> _saveTemplate() async {
    final libraryId = ref.read(currentLibraryIdProvider);
    if (libraryId == null || libraryId.isEmpty) return;

    setState(() => _isSaving = true);
    try {
      final prefixText = _prefixController.text.trim().isEmpty ? 'REC' : _prefixController.text.trim();
      await FirebaseFirestore.instance
          .collection('libraries')
          .doc(libraryId)
          .collection('settings')
          .doc('receipt_template')
          .set({
        ..._elements,
        'prefix': prefixText,
        'customTerms': _termsController.text.trim(),
        'footerText': _footerController.text.trim(),
        'stampUrl': _stampUrl ?? '',
        'stampEnabled': _stampEnabled,
        'stampRotation': _stampRotation,
        'stampScale': _stampScale,
        'watermarkEnabled': _watermarkEnabled,
        'watermarkOpacity': _watermarkOpacity,
        'watermarkScale': _watermarkScale,
        'headerFontSize': _headerFontSize,
        'receiptStyle': _receiptStyle,
        'pageSize': _pageSize,
        'primaryColor': _primaryColor.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Receipt template settings saved!'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving template: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _previewPdf() async {
    final libraryAsync = ref.read(currentLibraryProvider);
    final library = libraryAsync.value ??
        LibraryModel(
          id: 'preview_lib',
          name: 'Cozy Corner Study Hub',
          address: '42 Knowledge Park, Metro City',
          logoUrl: '',
          contact: '+91 98765 43210',
          ownerId: 'preview_admin',
          accentColor: 0xFF4F46E5,
          welcomeMessage: 'Your Peaceful Study Haven',
          operatingHours: '6 AM - 11 PM',
          socialLinks: const {},
          rulesText: 'Maintain silence.',
          adminPhotoUrl: '',
          helplineNumber: '+91 98765 43210',
          waitingListMode: WaitingListMode.waitingList,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

    final mockStudent = StudentModel(
      id: 'STU-001',
      name: 'Ashish Wagesh Choudhari',
      fatherName: 'Wagesh Choudhari',
      phone: '+91 73858 17571',
      email: 'ashish@example.com',
      gender: Gender.male,
      address: 'Main Street, Parli',
      pincode: '431515',
      govIdType: GovIdType.aadhaar,
      govIdNumber: 'XXXX-XXXX-1234',
      govIdImageUrl: '',
      photoUrl: '',
      college: 'City College',
      course: 'Pharmacy',
      year: 'Completed',
      emergencyContact: '+91 73858 17571',
      membershipStatus: MembershipStatus.active,
      customFields: const {},
      createdAt: DateTime.now(),
    );

    final mockPlan = PlanModel(
      id: 'PLAN-001',
      libraryId: library.id,
      name: 'Monthly Dedicated Seat Plan',
      price: 1500.0,
      duration: 30,
      durationUnit: DurationUnit.days,
      description: 'Monthly unlimited access',
      gracePeriodDays: 3,
      isActive: true,
      isFeatured: false,
      displayOrder: 1,
    );

    final mockReceipt = ReceiptModel(
      id: 'REC-2026-0001',
      libraryId: library.id,
      receiptNumber: 'REC-001',
      studentId: mockStudent.id,
      planId: mockPlan.id,
      amount: 1500.0,
      paymentMethod: 'UPI',
      validFrom: DateTime.now(),
      validTo: DateTime.now().add(const Duration(days: 30)),
      customFields: const {},
      status: ReceiptStatus.active,
      createdAt: DateTime.now(),
    );

    try {
      final templateMap = {
        ..._elements,
        'customTerms': _termsController.text.trim(),
        'stampUrl': _stampUrl,
        'stampEnabled': _stampEnabled,
        'stampRotation': _stampRotation,
        'stampScale': _stampScale,
        'watermarkEnabled': _watermarkEnabled,
        'watermarkOpacity': _watermarkOpacity,
        'headerFontSize': _headerFontSize,
        'receiptStyle': _receiptStyle,
        'pageSize': _pageSize,
        'primaryColor': _primaryColor.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase(),
        'footerText': _footerController.text.trim(),
      };

      final pdfBytes = await PdfService().generateReceiptPdf(
        mockReceipt,
        mockStudent,
        mockPlan,
        library,
        templateMap,
      );

      await Printing.layoutPdf(
        onLayout: (format) async => pdfBytes,
        name: 'Receipt_Template_Sample.pdf',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not generate preview: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Receipt Template Customizer')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Receipt Customizer'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.tune_rounded), text: 'Elements & Branding'),
            Tab(icon: Icon(Icons.verified_rounded), text: 'Stamp & Watermark'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_rounded),
            tooltip: 'Preview PDF',
            onPressed: _previewPdf,
          ),
          IconButton(
            icon: _isSaving
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.check_rounded),
            tooltip: 'Save Settings',
            onPressed: _isSaving ? null : _saveTemplate,
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // ── TAB 1: ELEMENTS & BRANDING ────────────────────────────────────
          ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              // Receipt Style Selector
              Card(
                elevation: 0,
                margin: const EdgeInsets.only(bottom: 16),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Receipt Template Style', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      Row(children: [
                        Expanded(child: _styleCard('classic', 'Classic', 'Traditional layout: header, details table, stamped amount box', Icons.receipt_long_rounded)),
                        const SizedBox(width: 12),
                        Expanded(child: _styleCard('compact', 'Modern Compact', 'Colored header band, clean A5-friendly minimal layout', Icons.receipt_rounded)),
                      ]),
                      const SizedBox(height: 4),
                      Text('Page Size', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(value: 'a4', label: Text('A4 (210×297mm)'), icon: Icon(Icons.article_outlined)),
                          ButtonSegment(value: 'a5', label: Text('A5 (148×210mm)'), icon: Icon(Icons.description_outlined)),
                        ],
                        selected: {_pageSize},
                        onSelectionChanged: (s) => setState(() => _pageSize = s.first),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Receipt Prefix', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _prefixController,
                        textCapitalization: TextCapitalization.characters,
                        decoration: const InputDecoration(
                          labelText: 'Invoice / Receipt Prefix',
                          hintText: 'e.g. REC, INV, CC',
                          helperText: 'Prefix format: PREFIX-YYYY-XXXX (e.g. REC-2026-0001)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text('Header Title Size: ${_headerFontSize.toInt()} pt', style: const TextStyle(fontWeight: FontWeight.w600)),
                      Slider(
                        value: _headerFontSize,
                        min: 16,
                        max: 30,
                        divisions: 14,
                        label: '${_headerFontSize.toInt()} pt',
                        onChanged: (v) => setState(() => _headerFontSize = v),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Display Elements', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      ..._elements.keys.map((key) {
                        return SwitchListTile(
                          dense: true,
                          title: Text(key),
                          value: _elements[key]!,
                          onChanged: (val) => setState(() => _elements[key] = val),
                        );
                      }),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Custom Terms & Policies', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _termsController,
                        maxLines: 4,
                        decoration: const InputDecoration(
                          hintText: '• Fee once paid is non-refundable.\n• Membership is non-transferable.',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _footerController,
                        decoration: const InputDecoration(
                          labelText: 'Receipt Footer Text',
                          hintText: 'Thank you for choosing {libraryName}.',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.format_quote),
                        ),
                        maxLines: 2,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // ── TAB 2: STAMP & WATERMARK ──────────────────────────────────────
          ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              // Official Stamp Card
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.verified_rounded, color: theme.colorScheme.primary),
                              const SizedBox(width: 8),
                              Text('Official Organization Stamp', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                            ],
                          ),
                          Switch(
                            value: _stampEnabled,
                            onChanged: (v) => setState(() => _stampEnabled = v),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              border: Border.all(color: Colors.grey.shade300),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: _stampUrl != null && _stampUrl!.isNotEmpty
                                ? Transform.rotate(
                                    angle: _stampRotation * 3.14159 / 180,
                                    child: ImageService.buildImageWidget(_stampUrl!, fit: BoxFit.contain),
                                  )
                                : const Center(child: Icon(Icons.approval_rounded, size: 36, color: Colors.grey)),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                OutlinedButton.icon(
                                  onPressed: _isUploadingStamp ? null : _pickStamp,
                                  icon: _isUploadingStamp
                                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                                      : const Icon(Icons.upload_rounded),
                                  label: Text(_stampUrl != null ? 'Change Stamp' : 'Upload Stamp'),
                                ),
                                const SizedBox(height: 4),
                                const Text('Square transparent PNG / JPG recommended', style: TextStyle(fontSize: 11, color: Colors.grey)),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (_stampEnabled && _stampUrl != null && _stampUrl!.isNotEmpty) ...[
                        const Divider(height: 24),
                        Text('Stamp Angle / Rotation: ${_stampRotation.toInt()}°', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                        Slider(
                          value: _stampRotation,
                          min: -45,
                          max: 45,
                          divisions: 90,
                          label: '${_stampRotation.toInt()}°',
                          onChanged: (v) => setState(() => _stampRotation = v),
                        ),
                        Text('Stamp Size: ${(_stampScale * 100).toInt()}%', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                        Slider(
                          value: _stampScale,
                          min: 0.6,
                          max: 1.6,
                          divisions: 10,
                          label: '${(_stampScale * 100).toInt()}%',
                          onChanged: (v) => setState(() => _stampScale = v),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Watermark Card
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.opacity_rounded, color: theme.colorScheme.primary),
                              const SizedBox(width: 8),
                              Text('Background Watermark Logo', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                            ],
                          ),
                          Switch(
                            value: _watermarkEnabled,
                            onChanged: (v) => setState(() => _watermarkEnabled = v),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Displays your library logo faintly across the background of every receipt to prevent forgery and unauthorized duplication.',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      if (_watermarkEnabled) ...[
                        const SizedBox(height: 16),
                        Text('Watermark Opacity: ${(_watermarkOpacity * 100).toInt()}%', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                        Slider(
                          value: _watermarkOpacity,
                          min: 0.05,
                          max: 0.40,
                          divisions: 35,
                          label: '${(_watermarkOpacity * 100).toInt()}%',
                          onChanged: (v) => setState(() => _watermarkOpacity = v),
                        ),
                        const SizedBox(height: 8),
                        Row(children: [
                          const Text('Watermark Logo Size', style: TextStyle(fontWeight: FontWeight.w500)),
                          const Spacer(),
                          Text('${(_watermarkScale * 100).round()}%', style: const TextStyle(fontWeight: FontWeight.bold)),
                        ]),
                        Slider(
                          value: _watermarkScale, min: 0.1, max: 0.9, divisions: 16,
                          label: '${(_watermarkScale * 100).round()}%',
                          onChanged: (v) => setState(() => _watermarkScale = v),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Accent Color Card
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Receipt Accent Color', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            const Color(0xFF1565C0), const Color(0xFF2E7D32), const Color(0xFFC62828),
                            const Color(0xFF4A148C), const Color(0xFF212121), const Color(0xFFE65100),
                            const Color(0xFF00695C), const Color(0xFF0277BD),
                          ].map((color) => GestureDetector(
                            onTap: () => setState(() => _primaryColor = color),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              margin: const EdgeInsets.only(right: 10),
                              width: 38, height: 38,
                              decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: _primaryColor == color ? Colors.white : Colors.transparent,
                                  width: 3,
                                ),
                                boxShadow: _primaryColor == color
                                    ? [BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 8, spreadRadius: 1)]
                                    : null,
                              ),
                              child: _primaryColor == color ? const Icon(Icons.check, color: Colors.white, size: 18) : null,
                            ),
                          )).toList(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isSaving ? null : _saveTemplate,
        icon: _isSaving
            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : const Icon(Icons.save_rounded),
        label: Text(_isSaving ? 'Saving...' : 'Save Settings'),
      ),
    );
  }

  Widget _styleCard(String value, String label, String desc, IconData icon) {
    final theme = Theme.of(context);
    final selected = _receiptStyle == value;
    return GestureDetector(
      onTap: () => setState(() => _receiptStyle = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected ? theme.colorScheme.primaryContainer : theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? theme.colorScheme.primary : theme.colorScheme.outline.withValues(alpha: 0.4),
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(children: [
          Icon(icon, size: 28, color: selected ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant),
          const SizedBox(height: 6),
          Text(label, style: TextStyle(fontWeight: FontWeight.bold, color: selected ? theme.colorScheme.primary : null), textAlign: TextAlign.center),
          const SizedBox(height: 4),
          Text(desc, style: theme.textTheme.bodySmall, textAlign: TextAlign.center),
          if (selected) ...[
            const SizedBox(height: 4),
            Icon(Icons.check_circle_rounded, color: theme.colorScheme.primary, size: 16),
          ],
        ]),
      ),
    );
  }
}
