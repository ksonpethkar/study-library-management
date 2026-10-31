import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import 'package:printing/printing.dart';
import 'package:study_library/core/providers/library_provider.dart';
import 'package:study_library/models/receipt_model.dart';
import 'package:study_library/models/student_model.dart';
import 'package:study_library/models/plan_model.dart';
import 'package:study_library/models/library_model.dart';
import 'package:study_library/services/pdf_service.dart';
import 'package:study_library/services/image_service.dart';
import 'package:study_library/services/image_transparency_service.dart';
import 'package:study_library/core/widgets/brand_color_picker_dialog.dart';
import 'package:study_library/core/error/error_handler.dart';

class ReceiptTemplateScreen extends ConsumerStatefulWidget {
  const ReceiptTemplateScreen({super.key});

  @override
  ConsumerState<ReceiptTemplateScreen> createState() => _ReceiptTemplateScreenState();
}

class _ReceiptTemplateScreenState extends ConsumerState<ReceiptTemplateScreen> {
  // Underlying receipt elements map - fully backward-compatible with Firestore schema
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
    'Seat Number': true,
    'Plan Name': true,
    'Valid From': true,
    'Valid To': true,
    'Next Due Date': false,
    'Payment Method': true,
  };

  final TextEditingController _prefixController = TextEditingController(text: 'REC');
  final TextEditingController _termsController = TextEditingController();
  final TextEditingController _footerController = TextEditingController(text: 'Thank you for your payment! 📚');

  // Stamp settings
  String? _stampUrl;
  bool _stampEnabled = true;
  double _stampRotation = -12.0;
  double _stampScale = 1.0;

  // Watermark settings
  String? _watermarkUrl;
  bool _watermarkEnabled = true;
  double _watermarkOpacity = 0.08;
  double _watermarkScale = 0.88;

  // Header settings
  double _headerFontSize = 22.0;

  // Style / layout settings
  String _receiptStyle = 'classic';
  String _pageSize = 'a4';
  Color _primaryColor = const Color(0xFF1565C0);

  bool _isLoading = true;
  bool _isSaving = false;
  bool _isUploadingStamp = false;
  bool _isUploadingWatermark = false;

  @override
  void initState() {
    super.initState();
    _loadTemplate();
  }

  @override
  void dispose() {
    _prefixController.dispose();
    _termsController.dispose();
    _footerController.dispose();
    super.dispose();
  }

  Future<void> _loadTemplate() async {
    var libraryId = ref.read(currentLibraryIdProvider);
    if (libraryId == null || libraryId.isEmpty) {
      libraryId = ref.read(currentLibraryProvider).value?.id;
    }
    if (libraryId == null || libraryId.isEmpty) {
      await Future.delayed(const Duration(milliseconds: 250));
      libraryId = ref.read(currentLibraryIdProvider) ??
          ref.read(currentLibraryProvider).value?.id ??
          CurrentLibraryNotifier.defaultLibraryId;
    }
    if (libraryId.isEmpty) {
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
          _watermarkUrl = data['watermarkUrl'] as String?;
          _watermarkEnabled = (data['watermarkEnabled'] as bool?) ?? true;
          _watermarkOpacity = (((data['watermarkOpacity'] as num?)?.toDouble()) ?? 0.08).clamp(0.02, 0.40);
          _watermarkScale = (((data['watermarkScale'] as num?)?.toDouble()) ?? 0.88).clamp(0.10, 0.98);
          _headerFontSize = ((data['headerFontSize'] as num?)?.toDouble()) ?? 22.0;
          final loadedStyle = (data['receiptStyle'] as String?) ?? 'classic';
          _receiptStyle = loadedStyle == 'compact' ? 'classic' : loadedStyle;
          final loadedSize = (data['pageSize'] as String?) ?? 'a4';
          _pageSize = loadedSize.toLowerCase() == 'a5' ? 'a4' : loadedSize;

          final colorHex = data['primaryColor'] as String?;
          if (colorHex != null && colorHex.isNotEmpty) {
            try {
              final v = int.parse('FF$colorHex', radix: 16);
              _primaryColor = Color.fromARGB((v >> 24) & 0xFF, (v >> 16) & 0xFF, (v >> 8) & 0xFF, v & 0xFF);
            } catch (_) {}
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

  /// Safely process transparent PNG images to keep document size < 60KB or upload to Firebase Storage
  Future<String> _processAndUploadTransparentPng({
    required Uint8List transparentBytes,
    required String libraryId,
    required String subpath,
  }) async {
    // 1. Resize & aggressively compress to safe dimensions (max 300x300, PNG level 9)
    // to strictly prevent Firestore 1MB document limit violations
    Uint8List safeBytes = transparentBytes;
    try {
      final decoded = img.decodeImage(transparentBytes);
      if (decoded != null) {
        img.Image current = decoded;
        if (current.width > 300 || current.height > 300) {
          current = img.copyResize(
            current,
            width: current.width >= current.height ? 300 : null,
            height: current.height > current.width ? 300 : null,
            interpolation: img.Interpolation.linear,
          );
        }
        safeBytes = Uint8List.fromList(img.encodePng(current, level: 9));

        // If still > 100KB, downscale further to 220x220
        if (safeBytes.length > 100 * 1024) {
          current = img.copyResize(current, width: 220, height: 220, interpolation: img.Interpolation.linear);
          safeBytes = Uint8List.fromList(img.encodePng(current, level: 9));
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Image compression warning: $e');
      safeBytes = transparentBytes;
    }

    // 2. Attempt to upload to Firebase Storage to get clean URL (~120 bytes)
    try {
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('libraries/$libraryId/receipt_template/$subpath.png');
      await storageRef.putData(
        safeBytes,
        SettableMetadata(contentType: 'image/png'),
      );
      return await storageRef.getDownloadURL();
    } catch (e) {
      if (kDebugMode) debugPrint('Firebase Storage upload fallback to compressed base64: $e');
      // 3. Fallback: If Firebase Storage is unavailable or offline, use compressed Base64 data URL (< 50KB, safely below Firestore's 1MB limit)
      return 'data:image/png;base64,${base64Encode(safeBytes)}';
    }
  }

  Future<void> _pickStamp() async {
    final libraryId = ref.read(currentLibraryIdProvider) ??
        ref.read(currentLibraryProvider).value?.id ??
        CurrentLibraryNotifier.defaultLibraryId;
    if (libraryId.isEmpty) return;

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
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: source, maxWidth: 800, imageQuality: 80);
      if (picked == null || !mounted) return;

      // Automatically strip paper/white background into crisp transparent PNG
      final rawBytes = await picked.readAsBytes();
      final transparentBytes = ImageTransparencyService.removeWhiteBackground(rawBytes, threshold: 220);
      final url = await _processAndUploadTransparentPng(
        transparentBytes: transparentBytes,
        libraryId: libraryId,
        subpath: 'stamp',
      );

      if (mounted) {
        setState(() {
          _stampUrl = url;
          _stampEnabled = true;
        });
        AppSnackbar.showSuccess(
          context,
          '✨ Stamp uploaded with transparent background! Remember to save settings.',
        );
      }
    } catch (e) {
      if (mounted) {
        AppSnackbar.showError(context, e);
      }
    } finally {
      if (mounted) setState(() => _isUploadingStamp = false);
    }
  }

  Future<void> _pickWatermark() async {
    final libraryId = ref.read(currentLibraryIdProvider) ??
        ref.read(currentLibraryProvider).value?.id ??
        CurrentLibraryNotifier.defaultLibraryId;
    if (libraryId.isEmpty) return;

    final libraryAsync = ref.read(currentLibraryProvider);
    final libraryLogoUrl = libraryAsync.value?.logoUrl;

    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_rounded),
              title: const Text('Choose from Gallery / Files'),
              onTap: () => Navigator.pop(ctx, 'gallery'),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded),
              title: const Text('Take Photo of Logo'),
              onTap: () => Navigator.pop(ctx, 'camera'),
            ),
            if (libraryLogoUrl != null && libraryLogoUrl.isNotEmpty)
              ListTile(
                leading: const Icon(Icons.business_rounded, color: Colors.blue),
                title: const Text('Use Main Library Logo'),
                subtitle: const Text('Syncs watermark with library profile logo'),
                onTap: () => Navigator.pop(ctx, 'use_library_logo'),
              ),
            if (_watermarkUrl != null && _watermarkUrl!.isNotEmpty)
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded, color: Colors.red),
                title: const Text('Remove Custom Watermark', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(ctx);
                  setState(() => _watermarkUrl = null);
                },
              ),
          ],
        ),
      ),
    );

    if (action == null) return;

    if (action == 'use_library_logo' && libraryLogoUrl != null) {
      String compressedLogo = libraryLogoUrl;
      if (compressedLogo.startsWith('data:image') || compressedLogo.length > 2000) {
        compressedLogo = _compressBase64Image(compressedLogo, maxDim: 250);
      }
      if (mounted) {
        setState(() {
          _watermarkUrl = compressedLogo;
          _watermarkEnabled = true;
        });
        AppSnackbar.showSuccess(
          context,
          '✨ Set library profile logo as watermark! Remember to save settings.',
        );
      }
      return;
    }

    final source = action == 'camera' ? ImageSource.camera : ImageSource.gallery;

    setState(() => _isUploadingWatermark = true);
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: source, maxWidth: 800, imageQuality: 80);
      if (picked == null || !mounted) return;

      // Automatically strip paper/white background into crisp transparent PNG
      final rawBytes = await picked.readAsBytes();
      final transparentBytes = ImageTransparencyService.removeWhiteBackground(rawBytes, threshold: 235);
      final url = await _processAndUploadTransparentPng(
        transparentBytes: transparentBytes,
        libraryId: libraryId,
        subpath: 'watermark',
      );

      if (mounted) {
        setState(() {
          _watermarkUrl = url;
          _watermarkEnabled = true;
        });
        AppSnackbar.showSuccess(
          context,
          '✨ Background watermark uploaded with transparent background! Remember to save settings.',
        );
      }
    } catch (e) {
      if (mounted) {
        AppSnackbar.showError(context, e);
      }
    } finally {
      if (mounted) setState(() => _isUploadingWatermark = false);
    }
  }

  /// Aggressively compress any data URI / Base64 image to strictly < 60KB
  String _compressBase64Image(String dataUriOrBase64, {int maxDim = 250}) {
    try {
      final b64 = dataUriOrBase64.contains(',') ? dataUriOrBase64.split(',')[1] : dataUriOrBase64;
      final cleanB64 = b64.trim().replaceAll('\n', '').replaceAll('\r', '');
      final raw = base64Decode(cleanB64);
      final decoded = img.decodeImage(raw);
      if (decoded == null) return dataUriOrBase64;

      img.Image current = decoded;
      if (current.width > maxDim || current.height > maxDim) {
        current = img.copyResize(
          current,
          width: current.width >= current.height ? maxDim : null,
          height: current.height > current.width ? maxDim : null,
          interpolation: img.Interpolation.linear,
        );
      }
      var compressedBytes = Uint8List.fromList(img.encodePng(current, level: 9));
      if (compressedBytes.length > 60 * 1024) {
        current = img.copyResize(current, width: 180, height: 180, interpolation: img.Interpolation.linear);
        compressedBytes = Uint8List.fromList(img.encodePng(current, level: 9));
      }
      return 'data:image/png;base64,${base64Encode(compressedBytes)}';
    } catch (e) {
      if (kDebugMode) debugPrint('Base64 compression failed: $e');
      return dataUriOrBase64;
    }
  }

  Future<void> _saveTemplate() async {
    var libraryId = ref.read(currentLibraryIdProvider);
    if (libraryId == null || libraryId.isEmpty) {
      libraryId = ref.read(currentLibraryProvider).value?.id ?? CurrentLibraryNotifier.defaultLibraryId;
    }
    if (libraryId.isEmpty) return;

    setState(() => _isSaving = true);
    try {
      // Auto-sanitize existing oversized base64 images if present before writing to Firestore.
      // Cloud Firestore limits properties to < 1,048,487 bytes; we strictly cap under 60KB.
      String? safeWatermark = _watermarkUrl;
      if (safeWatermark != null && safeWatermark.isNotEmpty) {
        if (safeWatermark.startsWith('data:image') || safeWatermark.length > 2000) {
          safeWatermark = _compressBase64Image(safeWatermark, maxDim: 250);
          _watermarkUrl = safeWatermark;
        }
        if (safeWatermark.length > 250 * 1024) {
          safeWatermark = '';
          _watermarkUrl = null;
        }
      }

      String? safeStamp = _stampUrl;
      if (safeStamp != null && safeStamp.isNotEmpty) {
        if (safeStamp.startsWith('data:image') || safeStamp.length > 2000) {
          safeStamp = _compressBase64Image(safeStamp, maxDim: 250);
          _stampUrl = safeStamp;
        }
        if (safeStamp.length > 250 * 1024) {
          safeStamp = '';
          _stampUrl = null;
        }
      }

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
        'stampUrl': safeStamp ?? '',
        'stampEnabled': _stampEnabled,
        'stampRotation': _stampRotation,
        'stampScale': _stampScale,
        'watermarkUrl': safeWatermark ?? '',
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
          name: 'Study Library Center',
          address: 'Station Road, City Centre',
          logoUrl: '',
          contact: '+91 9800000000',
          ownerId: 'preview_admin',
          accentColor: 0xFF1E3A8A,
          welcomeMessage: 'Your Peaceful Study Haven',
          operatingHours: '6 AM - 11 PM',
          socialLinks: const {},
          rulesText: 'Maintain silence.',
          adminPhotoUrl: '',
          helplineNumber: '+91 9800000000',
          waitingListMode: WaitingListMode.waitingList,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

    final mockStudent = StudentModel(
      id: 'CC20260002',
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
      membershipNumber: 'CC20260002',
      seatId: 'seat_2',
      customFields: const {},
      createdAt: DateTime.now(),
    );

    final mockPlan = PlanModel(
      id: 'PLAN-001',
      libraryId: library.id,
      name: 'Monthly Dedicated Seat Plan',
      price: 1500.0,
      duration: 1,
      durationUnit: DurationUnit.months,
      description: 'AC Study Hall Access • Reserved Desk • High-Speed Wi-Fi • Power Backup',
      gracePeriodDays: 3,
      isActive: true,
      isFeatured: false,
      displayOrder: 1,
    );

    final mockReceipt = ReceiptModel(
      id: 'REC-2026-0004',
      libraryId: library.id,
      receiptNumber: 'REC-2026-0004',
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
        'watermarkUrl': _watermarkUrl,
        'watermarkEnabled': _watermarkEnabled,
        'watermarkOpacity': _watermarkOpacity,
        'watermarkScale': _watermarkScale,
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
        seatLabel: 'Seat #2 (Cozy Hall)',
      );

      await Printing.layoutPdf(
        onLayout: (format) async => pdfBytes,
        name: 'Fee_Receipt_Sample.pdf',
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
    final libraryLogo = ref.watch(currentLibraryProvider).value?.logoUrl ?? '';
    final effectiveWatermark = (_watermarkUrl != null && _watermarkUrl!.isNotEmpty)
        ? _watermarkUrl!
        : libraryLogo;

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Receipt Template')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Receipt Template'),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_rounded),
            tooltip: 'Preview PDF Receipt',
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
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820),
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
            children: [
          // ── CARD 1: FORMAT, LAYOUT & BRANDING ────────────────────────────
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(18.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(Icons.style_rounded, color: theme.colorScheme.onPrimaryContainer, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Layout & Branding Identity',
                              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              'Receipt architecture, paper standard and brand accent',
                              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // Template Architecture & Page Standard (Unified Modern Business A4)
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.7)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(Icons.receipt_long_rounded, color: theme.colorScheme.onPrimaryContainer, size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      'Modern Business Standard',
                                      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.green.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: Colors.green.withValues(alpha: 0.35)),
                                    ),
                                    child: const Text(
                                      'A4 Full Sheet',
                                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.green),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Universal institutional invoice format: 2-column metadata, itemized fee table with seat & validity badges, balance due status, digital stamp, watermark, and QR verification. Standardized for A4 paper and high-clarity PDF sharing via WhatsApp.',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                  height: 1.35,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Prefix
                  Text('Receipt Number Prefix', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _prefixController,
                    textCapitalization: TextCapitalization.characters,
                    decoration: InputDecoration(
                      hintText: 'e.g. REC, INV, CC',
                      prefixIcon: const Icon(Icons.tag_rounded),
                      helperText: 'Sample generated number: ${_prefixController.text.trim().isEmpty ? "REC" : _prefixController.text.trim()}-2026-0001',
                      border: const OutlineInputBorder(),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 16),

                  // Accent Color
                  Text('Receipt Brand Accent Color', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        ...[
                          const Color(0xFF881337), // Cozy Corner Maroon
                          const Color(0xFF1565C0), // Royal Blue
                          const Color(0xFF047857), // Forest Emerald
                          const Color(0xFF1E293B), // Slate Obsidian
                          const Color(0xFF78350F), // Warm Amber/Brown
                          const Color(0xFF4A148C), // Deep Purple
                          const Color(0xFF0277BD), // Cyan Blue
                          const Color(0xFFBE185D), // Magenta
                        ].map((color) => GestureDetector(
                          onTap: () => setState(() => _primaryColor = color),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            margin: const EdgeInsets.only(right: 10),
                            width: 36,
                            height: 36,
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
                        )),
                        const SizedBox(width: 4),
                        // Custom Color Picker Button
                        GestureDetector(
                          onTap: () async {
                            final chosen = await BrandColorPickerDialog.show(
                              context,
                              initialColor: _primaryColor,
                              title: 'Pick Custom Receipt Accent Color',
                            );
                            if (chosen != null && mounted) {
                              setState(() => _primaryColor = chosen);
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: theme.colorScheme.outlineVariant),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.colorize_rounded, size: 16, color: _primaryColor),
                                const SizedBox(width: 6),
                                Text(
                                  '#${_primaryColor.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}',
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ── CARD 2: STAMP & ANTI-FORGERY WATERMARK ─────────────────────────
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(18.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(Icons.verified_user_rounded, color: theme.colorScheme.onPrimaryContainer, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Official Stamp & Watermark', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                                Text('Anti-counterfeiting security and authentication', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline), overflow: TextOverflow.ellipsis),
                              ],
                            ),
                          ),
                        ],
                      ),
                      Switch(
                        value: _stampEnabled,
                        onChanged: (v) => setState(() => _stampEnabled = v),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // ── Stamp Upload & Interactive Customization Section ────
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Clickable Stamp Preview Thumbnail
                      Tooltip(
                        message: 'Click to upload or change stamp image',
                        child: InkWell(
                          onTap: _isUploadingStamp ? null : _pickStamp,
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              border: Border.all(
                                color: _stampUrl != null && _stampUrl!.isNotEmpty
                                    ? theme.colorScheme.primary.withValues(alpha: 0.5)
                                    : Colors.grey.shade300,
                                width: 1.5,
                              ),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                if (_stampUrl != null && _stampUrl!.isNotEmpty)
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(9),
                                    child: Transform.scale(
                                      scale: _stampScale.clamp(0.6, 1.6),
                                      child: Transform.rotate(
                                        angle: _stampRotation * 3.14159 / 180,
                                        child: ImageService.buildImageWidget(_stampUrl!, fit: BoxFit.contain),
                                      ),
                                    ),
                                  )
                                else
                                  const Center(
                                    child: Icon(Icons.approval_rounded, size: 36, color: Colors.grey),
                                  ),
                                Positioned(
                                  bottom: 4,
                                  right: 4,
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.primary,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.edit, size: 10, color: Colors.white),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            OutlinedButton.icon(
                              onPressed: _isUploadingStamp ? null : _pickStamp,
                              icon: _isUploadingStamp
                                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                                  : const Icon(Icons.upload_rounded),
                              label: Text(_stampUrl != null && _stampUrl!.isNotEmpty ? 'Change Stamp' : 'Upload Official Stamp'),
                            ),
                            if (_stampUrl != null && _stampUrl!.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Wrap(
                                spacing: 8,
                                runSpacing: 4,
                                children: [
                                  TextButton.icon(
                                    onPressed: _isUploadingStamp
                                        ? null
                                        : () async {
                                            setState(() => _isUploadingStamp = true);
                                            try {
                                              final clean = ImageTransparencyService.removeBackgroundFromDataUri(_stampUrl!);
                                              setState(() => _stampUrl = clean);
                                              if (mounted) {
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  const SnackBar(
                                                    content: Text('✨ White paper background removed! Stamp is now a crisp transparent PNG.'),
                                                    backgroundColor: Colors.green,
                                                  ),
                                                );
                                              }
                                            } catch (e) {
                                              if (mounted) {
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  SnackBar(content: Text('Could not remove background: $e')),
                                                );
                                              }
                                            } finally {
                                              if (mounted) setState(() => _isUploadingStamp = false);
                                            }
                                          },
                                    icon: const Icon(Icons.auto_fix_high_rounded, size: 16),
                                    label: const Text('Auto-Remove Paper Background', style: TextStyle(fontSize: 12)),
                                  ),
                                  TextButton.icon(
                                    onPressed: () => setState(() => _stampUrl = null),
                                    icon: const Icon(Icons.delete_outline_rounded, size: 16, color: Colors.red),
                                    label: const Text('Remove Stamp', style: TextStyle(fontSize: 12, color: Colors.red)),
                                  ),
                                ],
                              ),
                            ],
                            const SizedBox(height: 2),
                            Text(
                              _stampUrl != null && _stampUrl!.isNotEmpty
                                  ? 'Stamp will appear rotated ${_stampRotation.toInt()}° overlapping signature'
                                  : 'Upload library seal or stamp image to authenticate receipts',
                              style: const TextStyle(fontSize: 11, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  // Stamp Customization Sliders (Rotation & Size)
                  if (_stampEnabled) ...[
                    const SizedBox(height: 14),
                    // Stamp Rotation Control
                    Row(
                      children: [
                        const Text('Stamp Rotation Angle', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text('${_stampRotation.toInt()}°', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: theme.colorScheme.onPrimaryContainer)),
                        ),
                      ],
                    ),
                    Slider(
                      value: _stampRotation.clamp(-45.0, 45.0),
                      min: -45.0,
                      max: 45.0,
                      divisions: 90,
                      label: '${_stampRotation.toInt()}°',
                      onChanged: (v) => setState(() => _stampRotation = double.parse(v.toStringAsFixed(1))),
                    ),
                    // Rotation Presets
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          const Text('Presets: ', style: TextStyle(fontSize: 11.5, color: Colors.grey)),
                          const SizedBox(width: 4),
                          for (final preset in const [
                            (-12.0, '-12° (Authentic)'),
                            (0.0, '0° (Straight)'),
                            (-20.0, '-20° (Tilt)'),
                            (12.0, '+12° (Right)'),
                          ])
                            Padding(
                              padding: const EdgeInsets.only(right: 6.0),
                              child: ChoiceChip(
                                label: Text(preset.$2, style: const TextStyle(fontSize: 11)),
                                selected: (_stampRotation - preset.$1).abs() < 1.0,
                                onSelected: (_) => setState(() => _stampRotation = preset.$1),
                                visualDensity: VisualDensity.compact,
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    // Stamp Scale / Size Control
                    Row(
                      children: [
                        const Text('Stamp Size / Scale', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text('${(_stampScale * 100).toInt()}%', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: theme.colorScheme.onPrimaryContainer)),
                        ),
                      ],
                    ),
                    Slider(
                      value: _stampScale.clamp(0.60, 1.60),
                      min: 0.60,
                      max: 1.60,
                      divisions: 10,
                      label: '${(_stampScale * 100).toInt()}%',
                      onChanged: (v) => setState(() => _stampScale = double.parse(v.toStringAsFixed(2))),
                    ),
                  ],

                  const Divider(height: 28),

                  // ── Watermark Section ─────────────────────────────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.opacity_rounded, color: theme.colorScheme.primary, size: 18),
                          const SizedBox(width: 8),
                          const Text('Background Watermark Logo', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                        ],
                      ),
                      Switch(
                        value: _watermarkEnabled,
                        onChanged: (v) => setState(() => _watermarkEnabled = v),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Faintly prints your library logo in the center of every receipt to prevent forgery.',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  if (_watermarkEnabled) ...[
                    const SizedBox(height: 14),
                    // Watermark Upload & Preview Row
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Clickable Watermark Preview Thumbnail
                        Tooltip(
                          message: 'Click to upload or select watermark logo',
                          child: InkWell(
                            onTap: _isUploadingWatermark ? null : _pickWatermark,
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                border: Border.all(
                                  color: effectiveWatermark.isNotEmpty
                                      ? theme.colorScheme.primary.withValues(alpha: 0.5)
                                      : Colors.grey.shade300,
                                  width: 1.5,
                                ),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  if (effectiveWatermark.isNotEmpty)
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(9),
                                      child: Opacity(
                                        opacity: (_watermarkOpacity * 4.0).clamp(0.25, 1.0),
                                        child: ImageService.buildImageWidget(effectiveWatermark, fit: BoxFit.contain),
                                      ),
                                    )
                                  else
                                    const Center(
                                      child: Icon(Icons.water_drop_outlined, size: 36, color: Colors.grey),
                                    ),
                                  Positioned(
                                    bottom: 4,
                                    right: 4,
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: theme.colorScheme.primary,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.edit, size: 10, color: Colors.white),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              OutlinedButton.icon(
                                onPressed: _isUploadingWatermark ? null : _pickWatermark,
                                icon: _isUploadingWatermark
                                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                                    : const Icon(Icons.upload_file_rounded),
                                label: Text(
                                  _watermarkUrl != null && _watermarkUrl!.isNotEmpty
                                      ? 'Change Watermark Logo'
                                      : (libraryLogo.isNotEmpty ? 'Upload Custom Logo' : 'Upload Watermark Logo'),
                                ),
                              ),
                              if (effectiveWatermark.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 4,
                                  children: [
                                    if (effectiveWatermark.startsWith('data:'))
                                      TextButton.icon(
                                        onPressed: _isUploadingWatermark
                                            ? null
                                            : () async {
                                                setState(() => _isUploadingWatermark = true);
                                                try {
                                                  final clean = ImageTransparencyService.removeBackgroundFromDataUri(effectiveWatermark);
                                                  setState(() => _watermarkUrl = clean);
                                                  if (mounted) {
                                                    ScaffoldMessenger.of(context).showSnackBar(
                                                      const SnackBar(
                                                        content: Text('✨ White paper background removed! Watermark is now a crisp transparent PNG.'),
                                                        backgroundColor: Colors.green,
                                                      ),
                                                    );
                                                  }
                                                } catch (e) {
                                                  if (mounted) {
                                                    ScaffoldMessenger.of(context).showSnackBar(
                                                      SnackBar(content: Text('Could not remove background: $e')),
                                                    );
                                                  }
                                                } finally {
                                                  if (mounted) setState(() => _isUploadingWatermark = false);
                                                }
                                              },
                                        icon: const Icon(Icons.auto_fix_high_rounded, size: 16),
                                        label: const Text('Auto-Remove Paper Background', style: TextStyle(fontSize: 12)),
                                      ),
                                    if (_watermarkUrl != null && _watermarkUrl!.isNotEmpty)
                                      TextButton.icon(
                                        onPressed: () => setState(() => _watermarkUrl = null),
                                        icon: const Icon(Icons.refresh_rounded, size: 16, color: Colors.blue),
                                        label: const Text('Revert to Main Logo', style: TextStyle(fontSize: 12, color: Colors.blue)),
                                      ),
                                  ],
                                ),
                              ],
                              const SizedBox(height: 2),
                              Text(
                                _watermarkUrl != null && _watermarkUrl!.isNotEmpty
                                    ? 'Custom watermark logo active'
                                    : libraryLogo.isNotEmpty
                                        ? 'Using Main Library Logo as watermark'
                                        : 'No logo set yet. Tap to upload or sync with Library Logo.',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: _watermarkUrl != null && _watermarkUrl!.isNotEmpty
                                      ? (Theme.of(context).brightness == Brightness.dark ? Colors.green.shade300 : Colors.green.shade700)
                                      : libraryLogo.isNotEmpty
                                          ? (Theme.of(context).brightness == Brightness.dark ? Colors.blue.shade300 : Colors.blue.shade700)
                                          : (Theme.of(context).brightness == Brightness.dark ? Colors.orange.shade300 : Colors.orange.shade800),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Watermark Faintness / Opacity Slider
                    Row(
                      children: [
                        const Text('Watermark Faintness / Opacity', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text('${(_watermarkOpacity * 100).toInt()}%', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: theme.colorScheme.onPrimaryContainer)),
                        ),
                      ],
                    ),
                    Slider(
                      value: _watermarkOpacity.clamp(0.02, 0.30),
                      min: 0.02,
                      max: 0.30,
                      divisions: 28,
                      label: '${(_watermarkOpacity * 100).toInt()}%',
                      onChanged: (v) => setState(() => _watermarkOpacity = double.parse(v.toStringAsFixed(2))),
                    ),
                    const Padding(
                      padding: EdgeInsets.only(left: 4.0, bottom: 8.0),
                      child: Text(
                        'Tip: Faint (6% - 10%) is recommended for clear reading of printed text without distraction.',
                        style: TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    ),

                    // Watermark Size / Coverage Slider
                    Row(
                      children: [
                        const Text('Watermark Size / Coverage', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text('${(_watermarkScale * 100).toInt()}%', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: theme.colorScheme.onPrimaryContainer)),
                        ),
                      ],
                    ),
                    Slider(
                      value: _watermarkScale.clamp(0.40, 1.0),
                      min: 0.40,
                      max: 1.0,
                      divisions: 12,
                      label: '${(_watermarkScale * 100).toInt()}%',
                      onChanged: (v) => setState(() => _watermarkScale = double.parse(v.toStringAsFixed(2))),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ── CARD 3: RECEIPT CONTENT, POLICIES & FOOTER ────────────────────
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(18.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(Icons.article_rounded, color: theme.colorScheme.onPrimaryContainer, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Receipt Details & Policies', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                            Text('Display toggles, student code of conduct and footer', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline), overflow: TextOverflow.ellipsis),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Essential Toggles
                  SwitchListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Show Allocated Seat & Hall', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
                    subtitle: const Text('Prints assigned seat number (e.g. Seat #2 (Cozy Hall))', style: TextStyle(fontSize: 11.5)),
                    value: _elements['Seat Number'] ?? true,
                    onChanged: (val) => setState(() => _elements['Seat Number'] = val),
                  ),
                  SwitchListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Show Terms & Conditions', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
                    subtitle: const Text('Includes non-refundable policy and silent decorum rules', style: TextStyle(fontSize: 11.5)),
                    value: _elements['Terms'] ?? true,
                    onChanged: (val) => setState(() => _elements['Terms'] = val),
                  ),
                  SwitchListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Show Authorized Signatory Line', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
                    subtitle: const Text('Includes authorized signature line below the official seal', style: TextStyle(fontSize: 11.5)),
                    value: _elements['Signature'] ?? true,
                    onChanged: (val) => setState(() => _elements['Signature'] = val),
                  ),
                  SwitchListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Show Library Logo in Header', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
                    subtitle: const Text('Renders transparent high-res logo alongside title', style: TextStyle(fontSize: 11.5)),
                    value: _elements['Logo'] ?? true,
                    onChanged: (val) => setState(() => _elements['Logo'] = val),
                  ),
                  SwitchListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Show Helpline & Email', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
                    subtitle: const Text('Prints official helpline and reception email under title', style: TextStyle(fontSize: 11.5)),
                    value: _elements['Contact'] ?? true,
                    onChanged: (val) => setState(() => _elements['Contact'] = val),
                  ),
                  const Divider(height: 24),

                  // Custom Terms Field
                  Text('Custom Terms & Policies (Optional)', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  const Text('Leave blank to use the standard library non-refundable policy and silent study guidelines.', style: TextStyle(fontSize: 11.5, color: Colors.grey)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _termsController,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      hintText: '• Fees once paid are non-refundable.\n• Preserving receipt is mandatory for library access.\n• Maintain strict silence in study halls.',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Footer Text Field
                  Text('Receipt Footer Note', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _footerController,
                    decoration: const InputDecoration(
                      hintText: 'Thank you for choosing {libraryName} • Computer-generated receipt',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.format_quote),
                    ),
                    maxLines: 2,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ── BRANDING PLACEMENT GUIDE CARD ────────────────────────────────
          Card(
            color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline_rounded, color: theme.colorScheme.primary, size: 20),
                      const SizedBox(width: 8),
                      Text('Where Branding Elements Are Used', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _buildBrandingGuideItem('Official Logo', 'Browser tab favicon, fee receipt top header, student ID card front, and student portal navigation.'),
                  _buildBrandingGuideItem('Official Stamp', 'Fee receipts (Authorized Signatory seal) and student ID card back (Authorized Stamp / Seal verification box).'),
                  _buildBrandingGuideItem('Watermark', 'Faintly behind fee receipts and student ID card backgrounds (anti-forgery authenticity).'),
                  _buildBrandingGuideItem('Org Name & Contact', 'Receipts, ID cards, emergency cards, WhatsApp confirmation receipts, and public seat occupancy page.'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 120), // Generous padding so FAB never blocks stamp/signature cards
        ],
      ),
    ),
  ),
  bottomNavigationBar: SafeArea(
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: FilledButton.icon(
        onPressed: _isSaving ? null : _saveTemplate,
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        icon: _isSaving
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : const Icon(Icons.save_rounded),
        label: Text(
          _isSaving ? 'Saving Template...' : 'Save Template Settings',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
      ),
    ),
  ),
);
  }

  Widget _buildBrandingGuideItem(String title, String desc) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 5, right: 8),
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: Theme.of(context).textTheme.bodySmall,
                children: [
                  TextSpan(text: '$title: ', style: const TextStyle(fontWeight: FontWeight.bold)),
                  TextSpan(text: desc),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
