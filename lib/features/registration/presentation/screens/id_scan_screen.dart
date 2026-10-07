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
  String _statusMessage = 'Reading your ID document...';

  Future<void> _captureAndScan(ImageSource source) async {
    final image =
        await ImageService.pickAndCompressImage(source: source, maxWidth: 1600, quality: 85);
    if (image == null || !mounted) return;

    setState(() {
      _scannedImage = image;
      _isProcessing = true;
      _statusMessage = 'Analyzing ID with Google ML Kit...';
    });

    try {
      final ocrService = OcrService();
      final rawText = await ocrService.processImage(image.path);

      // Auto-detect ID document type (PAN, DL, College ID, Aadhaar)
      final detectedType = OcrParser.detectGovIdType(rawText);
      final effectiveType = detectedType;
      setState(() => _selectedType = effectiveType);

      final result = OcrParser.parseByType(effectiveType, rawText);

      // Auto-watermark KYC document with diagonal compliance mark
      final watermarked = await WatermarkHelper.burnWatermark(
        sourceFile: image,
        targetPath: image.path.replaceAll(RegExp(r'\.[a-zA-Z0-9]+$'), '_kyc_verified.png'),
      );

      // ── Push ALL extracted fields into the registration provider ──────────
      ref.read(registrationNotifierProvider.notifier).updateFields({
        'govIdType': effectiveType.name,
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

      // ── Also push to the dedicated OCR result provider ────────────────
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

      if (mounted) setState(() => _isProcessing = false);

      // Show preview of what was auto-filled before advancing
      if (mounted) _showAutoFillPreview(result);
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
          'Scan front + back for Name, Father\'s Name, DOB, Gender, Address & PIN.',
      GovIdType.pan:
          'Scan front for Name, Father\'s Name, DOB & PAN number.',
      GovIdType.drivingLicence:
          'Scan front for Name, DOB, DL Number, Address & Blood Group.',
      GovIdType.collegeId:
          'Scan for Name, Roll/Enroll No., College, Course & more.',
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
                    'Quick Auto-Fill with ID Scan',
                    style: theme.textTheme.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Choose your ID type and scan it. We will auto-fill all available details.',
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 24),

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

                  const SizedBox(height: 32),

                  // Scanned image preview
                  if (_scannedImage != null && _isProcessing) ...[
                    WatermarkedKycWidget(
                      child: Container(
                        height: 180,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                              color: theme.colorScheme.primary, width: 2),
                          image: DecorationImage(
                            image: FileImage(_scannedImage!),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  if (_isProcessing)
                    Column(
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: 16),
                        Text(_statusMessage,
                            style:
                                const TextStyle(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 8),
                        Text(
                          'Please keep the ID still and well-lit.',
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey.shade500),
                        ),
                      ],
                    )
                  else ...[
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
                    const SizedBox(height: 12),

                    // Aadhaar tip: scan both sides
                    if (_selectedType == GovIdType.aadhaar)
                      Card(
                        elevation: 0,
                        color: theme.brightness == Brightness.dark
                            ? Colors.amber.shade900.withValues(alpha: 0.25)
                            : Colors.amber.shade50,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: BorderSide(
                            color: theme.brightness == Brightness.dark
                                ? Colors.amber.shade700.withValues(alpha: 0.5)
                                : Colors.amber.shade200,
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              Icon(Icons.lightbulb_outline_rounded,
                                  color: theme.brightness == Brightness.dark
                                      ? Colors.amber.shade300
                                      : Colors.amber.shade800),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Tip: Scan the BACK of the Aadhaar card to also extract your full address.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: theme.brightness == Brightness.dark
                                        ? Colors.amber.shade100
                                        : Colors.brown.shade900,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                    const SizedBox(height: 24),
                    TextButton(
                      onPressed: () =>
                          ref.read(registrationStepProvider.notifier).goTo(2),
                      child: const Text('Skip & Enter Details Manually ➔'),
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
}
