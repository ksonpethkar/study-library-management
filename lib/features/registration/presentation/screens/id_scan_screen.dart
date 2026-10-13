import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../providers/registration_provider.dart';
import '../../data/ocr_parser.dart';
import 'package:study_library/services/ocr_service.dart';
import 'package:study_library/services/image_service.dart';
import 'package:study_library/core/widgets/watermarked_kyc_widget.dart';

class IdScanScreen extends ConsumerStatefulWidget {
  const IdScanScreen({super.key});

  @override
  ConsumerState<IdScanScreen> createState() => _IdScanScreenState();
}

class _IdScanScreenState extends ConsumerState<IdScanScreen> {
  GovIdType _selectedType = GovIdType.aadhaar;
  bool _isProcessing = false;
  File? _scannedImage;
  File? _scannedBackImage;
  String _statusMessage = 'Reading your ID document...';
  bool _frontScanned = false; // true after first (front) scan completes

  /// IDs that have meaningful back-side content worth scanning
  bool get _hasTwoSides =>
      _selectedType == GovIdType.aadhaar ||
      _selectedType == GovIdType.drivingLicence ||
      _selectedType == GovIdType.passport;

  Future<void> _captureAndScan(ImageSource source, {bool isBackSide = false}) async {
    final image =
        await ImageService.pickAndCompressImage(source: source, maxWidth: 1600, quality: 85);
    if (image == null || !mounted) return;

    setState(() {
      if (isBackSide) {
        _scannedBackImage = image;
      } else {
        _scannedImage = image;
      }
      _isProcessing = true;
      _statusMessage = isBackSide
          ? 'Reading back side for address...'
          : 'Analyzing ID with Google ML Kit...';
    });

    try {
      final ocrService = OcrService();
      final rawText = await ocrService.processImage(image.path);

      if (isBackSide) {
        // For back side: only extract address/PIN — don't overwrite name/DOB
        final backResult = OcrParser.parseByType(_selectedType, rawText);

        // Watermark the back side image
        await WatermarkHelper.burnWatermark(
          sourceFile: image,
          targetPath: image.path.replaceAll(RegExp(r'\.[a-zA-Z0-9]+$'), '_kyc_back_verified.png'),
        );

        // Only update address-related fields from the back scan
        final updates = <String, dynamic>{};
        if (backResult.address != null) updates['address'] = backResult.address;
        if (backResult.pinCode != null) updates['pinCode'] = backResult.pinCode;
        if (backResult.district != null) updates['district'] = backResult.district;
        if (backResult.state != null) updates['state'] = backResult.state;

        if (updates.isNotEmpty) {
          ref.read(registrationNotifierProvider.notifier).updateFields(updates);
          // Also update OCR result provider
          final existing = ref.read(ocrResultProvider);
          ref.read(ocrResultProvider.notifier).setResult({
            ...existing,
            ...updates,
          });
        }

        if (mounted) setState(() => _isProcessing = false);
        if (mounted) _showBackScanResult(backResult);
      } else {
        // Front side: full extraction
        final detectedType = OcrParser.detectGovIdType(rawText);
        setState(() => _selectedType = detectedType);

        final result = OcrParser.parseByType(detectedType, rawText);

        // Auto-watermark KYC document
        final watermarked = await WatermarkHelper.burnWatermark(
          sourceFile: image,
          targetPath: image.path.replaceAll(RegExp(r'\.[a-zA-Z0-9]+$'), '_kyc_verified.png'),
        );

        ref.read(registrationNotifierProvider.notifier).updateFields({
          'govIdType': detectedType.name,
          'govIdImagePath': watermarked.path,
          if (result.name != null) 'name': result.name,
          if (result.fatherName != null) 'fatherName': result.fatherName,
          if (result.dob != null) 'dob': result.dob,
          if (result.gender != null) 'gender': result.gender,
          if (result.idNumber != null) 'govIdNumber': result.idNumber,
          if (result.address != null) 'address': result.address,
          if (result.pinCode != null) 'pinCode': result.pinCode,
          if (result.phone != null) 'phone': result.phone,
          if (result.bloodGroup != null) 'bloodGroup': result.bloodGroup,
          if (result.college != null) 'college': result.college,
          if (result.course != null) 'course': result.course,
          if (result.rollNumber != null) 'rollNumber': result.rollNumber,
        });

        ref.read(ocrResultProvider.notifier).setResult({
          'name': result.name,
          'fatherName': result.fatherName,
          'idNumber': result.idNumber,
          'dob': result.dob,
          'gender': result.gender,
          'address': result.address,
          'pinCode': result.pinCode,
          'phone': result.phone,
          'bloodGroup': result.bloodGroup,
          'college': result.college,
          'course': result.course,
          'rollNumber': result.rollNumber,
          'confidence': result.confidence.toString(),
        });

        if (mounted) setState(() { _isProcessing = false; _frontScanned = true; });
        if (mounted) _showAutoFillPreview(result);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            action: SnackBarAction(
              label: 'Enter Manually',
              textColor: Colors.amber,
              onPressed: () => ref.read(registrationStepProvider.notifier).goTo(2),
            ),
          ),
        );
      }
    }
  }

  /// Shows result of back-side scan
  void _showBackScanResult(OcrResult result) {
    final hasAddress = result.address != null || result.pinCode != null;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: hasAddress ? Colors.green.shade700 : Colors.orange.shade700,
        content: Text(
          hasAddress
              ? '✓ Address extracted from back side'
              : 'Could not read address — please fill manually',
        ),
        action: SnackBarAction(
          label: 'Continue',
          textColor: Colors.white,
          onPressed: () => ref.read(registrationStepProvider.notifier).goTo(2),
        ),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  /// Shows a bottom sheet summarising what was extracted, then advances to step 2.
  void _showAutoFillPreview(OcrResult result) {
    final filled = result.filledFields();
    final theme = Theme.of(context);
    final labelMap = {
      'name': 'Full Name',
      'fatherName': "Father's Name",
      'dob': 'Date of Birth',
      'gender': 'Gender',
      'idNumber': 'ID Number',
      'address': 'Address',
      'pinCode': 'PIN Code',
      'phone': 'Phone',
      'bloodGroup': 'Blood Group',
      'college': 'College',
      'course': 'Course',
      'rollNumber': 'Roll / Enroll No.',
    };

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.55,
        minChildSize: 0.35,
        maxChildSize: 0.85,
        expand: false,
        builder: (_, controller) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Header
              Row(
                children: [
                  Icon(Icons.check_circle_rounded,
                      color: theme.colorScheme.primary, size: 28),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('ID Scanned Successfully!',
                            style: theme.textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold)),
                        Text(
                          '${filled.length} field${filled.length == 1 ? '' : 's'} auto-filled  •  Confidence: ${result.confidence}%',
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: theme.colorScheme.outline),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 4),

              // Filled fields list
              if (filled.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Center(
                    child: Text(
                      'No fields could be extracted automatically.\nPlease fill in the form manually.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: Colors.grey.shade600),
                    ),
                  ),
                )
              else
                Expanded(
                  child: ListView(
                    controller: controller,
                    children: filled.entries.map((e) {
                      final label = labelMap[e.key] ?? e.key;
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 5),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.check_rounded,
                                color: theme.colorScheme.primary, size: 18),
                            const SizedBox(width: 8),
                            SizedBox(
                              width: 120,
                              child: Text(
                                '$label:',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600, fontSize: 13),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                e.key == 'gender'
                                    ? e.value.substring(0, 1).toUpperCase() +
                                        e.value.substring(1)
                                    : e.value,
                                style: const TextStyle(fontSize: 13),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),

              const SizedBox(height: 12),

              // CTA buttons
              FilledButton.icon(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  ref.read(registrationStepProvider.notifier).goTo(2);
                },
                icon: const Icon(Icons.edit_rounded),
                label: const Text('Review & Complete Registration ➔'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  setState(() {
                    _scannedImage = null;
                  });
                },
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Scan Again'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Info text per ID type
    const idInfo = {
      GovIdType.aadhaar:
          'Front: Name, DOB, Gender, Aadhaar number.\nBack: Full address & PIN code.',
      GovIdType.pan:
          'Front only: Name, Father\'s Name, DOB & PAN number.',
      GovIdType.drivingLicence:
          'Front: Name, DOB, DL number, Blood Group.\nBack: Address & PIN code.',
      GovIdType.passport:
          'Front: Name, DOB, Passport number, Nationality.\nBack: Address & expiry.',
      GovIdType.collegeId:
          'Front: Name, Roll/Enroll No., College, Course.',
    };

    return Scaffold(
      appBar: AppBar(title: const Text('Scan Government ID')),
      body: Column(
        children: [
          const LinearProgressIndicator(value: 1 / 5),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    _frontScanned
                        ? (_hasTwoSides ? 'Step 2: Scan Back Side' : 'ID Scanned ✓')
                        : 'Quick Auto-Fill with ID Scan',
                    style: theme.textTheme.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _frontScanned && _hasTwoSides
                        ? 'Flip your ID and scan the back to extract address & PIN code.'
                        : 'Choose your ID type and scan it. We will auto-fill all available details.',
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 24),

                  // ID Type dropdown (only show before front scan)
                  if (!_frontScanned) ...[
                    DropdownButtonFormField<GovIdType>(
                      initialValue: _selectedType,
                      decoration: const InputDecoration(
                        labelText: 'Select ID Type',
                        prefixIcon: Icon(Icons.credit_card_rounded),
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: GovIdType.aadhaar,
                          child: Text('Aadhaar Card'),
                        ),
                        DropdownMenuItem(
                          value: GovIdType.pan,
                          child: Text('PAN Card'),
                        ),
                        DropdownMenuItem(
                          value: GovIdType.drivingLicence,
                          child: Text('Driving Licence'),
                        ),
                        DropdownMenuItem(
                          value: GovIdType.passport,
                          child: Text('Passport'),
                        ),
                        DropdownMenuItem(
                          value: GovIdType.collegeId,
                          child: Text('College / Student ID'),
                        ),
                      ],
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedType = val);
                      },
                    ),
                    const SizedBox(height: 8),

                    // Info chip about what this ID type extracts
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.info_outline_rounded,
                              size: 16, color: theme.colorScheme.primary),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              idInfo[_selectedType] ?? '',
                              style: TextStyle(
                                fontSize: 12,
                                color: theme.colorScheme.onPrimaryContainer,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 32),

                  // Card frame overlay (scanning guide)
                  _buildCardFrame(theme),

                  const SizedBox(height: 24),

                  if (_isProcessing)
                    Column(
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: 16),
                        Text(_statusMessage,
                            style: const TextStyle(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 8),
                        Text(
                          'Please keep the ID still and well-lit.',
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey.shade500),
                        ),
                      ],
                    )
                  else if (_frontScanned && _hasTwoSides) ...[
                    // ── BACK SIDE SCAN BUTTONS ──────────────────────────────
                    FilledButton.icon(
                      onPressed: () => _captureAndScan(ImageSource.camera, isBackSide: true),
                      icon: const Icon(Icons.flip_camera_android_rounded),
                      label: const Text('Scan Back Side (Address & PIN)'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        textStyle: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () => _captureAndScan(ImageSource.gallery, isBackSide: true),
                      icon: const Icon(Icons.photo_library_rounded),
                      label: const Text('Upload Back Side from Gallery'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        foregroundColor: theme.colorScheme.primary,
                        side: BorderSide(color: theme.colorScheme.primary, width: 1.5),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextButton.icon(
                      onPressed: () => ref.read(registrationStepProvider.notifier).goTo(2),
                      icon: const Icon(Icons.skip_next_rounded, size: 18),
                      label: const Text('Skip Back Side — Continue to Form'),
                    ),
                  ] else ...[
                    // ── FRONT SIDE SCAN BUTTONS ──────────────────────────────
                    FilledButton.icon(
                      onPressed: () => _captureAndScan(ImageSource.camera),
                      icon: const Icon(Icons.camera_alt_rounded),
                      label: const Text('Scan with Camera'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        textStyle: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () => _captureAndScan(ImageSource.gallery),
                      icon: const Icon(Icons.photo_library_rounded),
                      label: const Text('Upload Photo from Gallery'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        foregroundColor: theme.colorScheme.primary,
                        side: BorderSide(color: theme.colorScheme.primary, width: 1.5),
                      ),
                    ),
                    const SizedBox(height: 24),
                    TextButton(
                      onPressed: () =>
                          ref.read(registrationStepProvider.notifier).goTo(2),
                      child: const Text('Skip & Enter Details Manually ?'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Card-shaped scanning guide frame
  Widget _buildCardFrame(ThemeData theme) {
    final scanned = _frontScanned ? _scannedBackImage ?? _scannedImage : _scannedImage;
    return Center(
      child: Container(
        width: 300,
        height: 190,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: scanned != null
                ? theme.colorScheme.primary
                : theme.colorScheme.outline.withValues(alpha: 0.5),
            width: scanned != null ? 2.5 : 1.5,
          ),
          color: theme.colorScheme.surfaceContainerLow,
          image: scanned != null
              ? DecorationImage(
                  image: FileImage(scanned),
                  fit: BoxFit.cover,
                )
              : null,
        ),
        child: scanned == null
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.credit_card_rounded,
                    size: 48,
                    color: theme.colorScheme.outline.withValues(alpha: 0.4),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _frontScanned && _hasTwoSides
                        ? 'Back of ${_selectedType.name.toUpperCase()} Card'
                        : 'Place ID card here',
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.outline,
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Corner guides
                  Text(
                    '┌─────────┐',
                    style: TextStyle(
                      fontSize: 10,
                      color: theme.colorScheme.outline.withValues(alpha: 0.3),
                      letterSpacing: 2,
                    ),
                  ),
                ],
              )
            : null,
      ),
    );
  }
}