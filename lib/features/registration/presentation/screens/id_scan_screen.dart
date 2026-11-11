import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../providers/registration_provider.dart';
import 'package:study_library/features/registration/data/ocr_parser.dart';
import 'package:study_library/features/registration/data/document_layout_classifier.dart';
import 'package:study_library/core/validators/gov_id_validator.dart';
import 'package:study_library/services/ocr_service.dart';
import 'package:study_library/services/document_picker_service.dart';

class IdScanScreen extends ConsumerStatefulWidget {
  const IdScanScreen({super.key});

  @override
  ConsumerState<IdScanScreen> createState() => _IdScanScreenState();
}

class _IdScanScreenState extends ConsumerState<IdScanScreen> {
  GovIdType _selectedType = GovIdType.aadhaar;
  bool _isProcessing = false;
  Uint8List? _scannedBytes;
  Uint8List? _scannedBackBytes;
  String _statusMessage = 'Reading your ID document...';
  bool _frontScanned = false; // true after first (front) scan completes
  DocumentSideClassification? _detectedLayout;

  /// IDs that have meaningful back-side content worth scanning
  bool get _hasTwoSides {
    if (_selectedType == GovIdType.pan) return false;
    if (_detectedLayout == DocumentSideClassification.bothSidesCombined) return false;
    if (_detectedLayout == DocumentSideClassification.panCard) return false;
    return _selectedType == GovIdType.aadhaar ||
        _selectedType == GovIdType.drivingLicence ||
        _selectedType == GovIdType.passport ||
        _selectedType == GovIdType.voterId;
  }

  Future<void> _captureAndScan(ImageSource source, {bool isBackSide = false}) async {
    final doc = await DocumentPickerService.pickDocument(
      context: context,
      preferredSource: source,
    );
    if (doc == null || !mounted) return;

    final bytes = doc.bytes;
    final dataUrl = doc.dataUrl;

    if (doc.isPdf) {
      final updates = <String, dynamic>{
        if (isBackSide) ...{
          'govIdBackDataUrl': dataUrl,
          'govIdBackImageUrl': dataUrl,
          'govIdBackImagePath': dataUrl,
          'govIdBackFileName': doc.fileName,
        } else ...{
          'govIdType': _selectedType.name,
          'govIdDataUrl': dataUrl,
          'govIdImageUrl': dataUrl,
          'govIdImagePath': dataUrl,
          'govIdFileName': doc.fileName,
        },
      };
      ref.read(registrationNotifierProvider.notifier).updateFields(updates);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.picture_as_pdf_rounded, color: Colors.amberAccent),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('PDF Document (${doc.fileName}) attached! Review details in the form.'),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF1E293B),
            behavior: SnackBarBehavior.floating,
          ),
        );
        ref.read(registrationStepProvider.notifier).goTo(2);
      }
      return;
    }

    setState(() {
      if (isBackSide) {
        _scannedBackBytes = bytes;
      } else {
        _scannedBytes = bytes;
      }
      _isProcessing = true;
      _statusMessage = isBackSide
          ? 'Reading back side for address...'
          : 'Analyzing ID with OCR & QR...';
    });

    // ── Resilient Document Attachment ─────────────────────────────────────────
    // Always persist the attached document image immediately so the user never
    // loses their scanned file even if OCR is incomplete or unavailable.
    final baseUpdates = <String, dynamic>{
      if (isBackSide) ...{
        'govIdBackDataUrl': dataUrl,
        'govIdBackImageUrl': dataUrl,
        'govIdBackImagePath': dataUrl,
        'govIdBackFileName': doc.fileName,
      } else ...{
        'govIdType': _selectedType.name,
        'govIdDataUrl': dataUrl,
        'govIdImageUrl': dataUrl,
        'govIdImagePath': dataUrl,
        'govIdFileName': doc.fileName,
      },
    };
    ref.read(registrationNotifierProvider.notifier).updateFields(baseUpdates);

    try {
      final ocrService = OcrService();
      String? qrString;
      String rawText = '';

      try {
        qrString = await ocrService.decodeQrBytes(bytes);
      } catch (qrErr) {
        debugPrint('[IdScanScreen] QR decode non-fatal error: $qrErr');
      }

      try {
        rawText = await ocrService.processImageBytes(bytes);
      } catch (ocrErr) {
        debugPrint('[IdScanScreen] OCR text process non-fatal error: $ocrErr');
      }

      if (isBackSide) {
        // For back side: only extract address/PIN — don't overwrite name/DOB
        final backResult = OcrParser.parseUnified(
          qrString: qrString,
          rawText: rawText,
          preferredType: _selectedType,
        );

        // Update address-related fields from the back scan
        final updates = <String, dynamic>{
          'govIdBackDataUrl': dataUrl,
          'govIdBackImageUrl': dataUrl,
          'govIdBackImagePath': dataUrl,
          'govIdBackFileName': doc.fileName,
        };
        if (backResult.address != null && backResult.address!.trim().isNotEmpty) updates['address'] = backResult.address!.trim();
        if (backResult.pinCode != null && backResult.pinCode!.trim().isNotEmpty) updates['pinCode'] = backResult.pinCode!.trim();
        if (backResult.district != null && backResult.district!.trim().isNotEmpty) updates['district'] = backResult.district!.trim();
        if (backResult.state != null && backResult.state!.trim().isNotEmpty) updates['state'] = backResult.state!.trim();

        ref.read(registrationNotifierProvider.notifier).updateFields(updates);
        final existing = ref.read(ocrResultProvider);
        ref.read(ocrResultProvider.notifier).setResult({
          ...existing,
          ...updates,
        });

        if (mounted) setState(() => _isProcessing = false);
        if (mounted) _showBackScanResult(backResult);
      } else {
        // Front side: full extraction & orientation classification
        final qrParsed = QrIdParser.parseQrString(qrString);
        final detectedType = qrParsed?.type ?? OcrParser.detectGovIdType(rawText);
        final effectiveType = detectedType != GovIdType.other ? detectedType : _selectedType;
        final layout = DocumentLayoutClassifier.classify(
          rawText: rawText,
          preferredType: effectiveType,
        );

        setState(() {
          _selectedType = effectiveType;
          _detectedLayout = layout;
        });

        final result = OcrParser.parseUnified(
          qrString: qrString,
          rawText: rawText,
          preferredType: effectiveType,
        );

        final updates = <String, dynamic>{
          'govIdType': effectiveType.name,
          'govIdDataUrl': dataUrl,
          'govIdImageUrl': dataUrl,
          'govIdImagePath': dataUrl,
          'govIdFileName': doc.fileName,
          if (result.name != null && result.name!.trim().isNotEmpty) 'name': result.name!.trim(),
          if (result.fatherName != null && result.fatherName!.trim().isNotEmpty) 'fatherName': result.fatherName!.trim(),
          if (result.dob != null && result.dob!.trim().isNotEmpty) 'dob': result.dob!.trim(),
          if (result.gender != null && result.gender!.trim().isNotEmpty) 'gender': result.gender!.trim(),
          if (result.idNumber != null && result.idNumber!.trim().isNotEmpty) 'govIdNumber': result.idNumber!.trim(),
          if (result.address != null && result.address!.trim().isNotEmpty) 'address': result.address!.trim(),
          if (result.pinCode != null && result.pinCode!.trim().isNotEmpty) 'pinCode': result.pinCode!.trim(),
          if (result.phone != null && result.phone!.trim().isNotEmpty) 'phone': result.phone!.trim(),
          if (result.bloodGroup != null && result.bloodGroup!.trim().isNotEmpty) 'bloodGroup': result.bloodGroup!.trim(),
          if (result.college != null && result.college!.trim().isNotEmpty) 'college': result.college!.trim(),
          if (result.course != null && result.course!.trim().isNotEmpty) 'course': result.course!.trim(),
          if (result.rollNumber != null && result.rollNumber!.trim().isNotEmpty) 'rollNumber': result.rollNumber!.trim(),
        };

        if (layout == DocumentSideClassification.bothSidesCombined) {
          // Both sides detected on single page (A4 Xerox or e-Aadhaar)
          updates['govIdBackDataUrl'] = dataUrl;
          updates['govIdBackImageUrl'] = dataUrl;
          updates['govIdBackImagePath'] = dataUrl;
          updates['govIdBackFileName'] = doc.fileName;
          setState(() {
            _scannedBackBytes = bytes;
          });
        }

        ref.read(registrationNotifierProvider.notifier).updateFields(updates);

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
    } catch (e, st) {
      debugPrint('[IdScanScreen] Resilient fallback caught: $e\n$st');
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _frontScanned = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle_rounded, color: Colors.greenAccent),
                SizedBox(width: 8),
                Expanded(
                  child: Text('ID Photo attached! Please verify your details in the registration form.'),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF1E293B),
            behavior: SnackBarBehavior.floating,
            action: SnackBarAction(
              label: 'Proceed',
              textColor: Colors.amberAccent,
              onPressed: () => ref.read(registrationStepProvider.notifier).goTo(2),
            ),
            duration: const Duration(seconds: 4),
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

    final isIdValid = GovIdValidator.isValid(_selectedType, result.idNumber);

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

              // Header with Honest Verification Status
              Row(
                children: [
                  Icon(
                    isIdValid ? Icons.verified_rounded : Icons.info_outline_rounded,
                    color: isIdValid ? Colors.green.shade600 : theme.colorScheme.primary,
                    size: 28,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isIdValid ? 'ID Scanned & Validated ✓' : 'ID Scanned (Please Review)',
                          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          isIdValid
                              ? '${_selectedType.displayName} Checksum Verified  •  Confidence: ${result.confidence}%'
                              : '${filled.length} fields filled  •  Verify highlighted fields in step 2',
                          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
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
                      style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey.shade600),
                    ),
                  ),
                )
              else
                Expanded(
                  child: ListView(
                    controller: controller,
                    children: filled.entries.map((e) {
                      final label = labelMap[e.key] ?? e.key;
                      bool? isValid;
                      if (e.key == 'idNumber') isValid = GovIdValidator.isValid(_selectedType, e.value);
                      if (e.key == 'name') isValid = GovIdValidator.isValidName(e.value);
                      if (e.key == 'dob') isValid = GovIdValidator.isValidDob(e.value);
                      if (e.key == 'pinCode') isValid = GovIdValidator.isValidPinCode(e.value);

                      final iconData = isValid == true
                          ? Icons.verified_rounded
                          : (isValid == false ? Icons.warning_amber_rounded : Icons.check_rounded);
                      final iconColor = isValid == true
                          ? Colors.green.shade600
                          : (isValid == false ? Colors.amber.shade800 : theme.colorScheme.primary);

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 5),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(iconData, color: iconColor, size: 18),
                            const SizedBox(width: 8),
                            SizedBox(
                              width: 120,
                              child: Text(
                                '$label:',
                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                e.key == 'gender'
                                    ? (e.value.isNotEmpty ? e.value[0].toUpperCase() + e.value.substring(1) : '')
                                    : e.value,
                                style: const TextStyle(fontSize: 13),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (isValid == true) ...[
                              const SizedBox(width: 4),
                              Text('✓', style: TextStyle(color: Colors.green.shade700, fontWeight: FontWeight.bold, fontSize: 12)),
                            ] else if (isValid == false) ...[
                              const SizedBox(width: 4),
                              Text('Review', style: TextStyle(color: Colors.amber.shade900, fontSize: 11, fontWeight: FontWeight.bold)),
                            ],
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
                    _scannedBytes = null;
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
      GovIdType.voterId:
          'Front: Name, Father/Husband Name, EPIC number.\nBack: Address & district.',
      GovIdType.passport:
          'Front: Name, DOB, Passport number, Nationality.\nBack: Address & expiry.',
      GovIdType.collegeId:
          'Front: Name, Roll/Enroll No., College, Course.',
      GovIdType.other:
          'Front: Name, Photo & ID number.\nBack: Address & other details.',
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
                      items: GovIdType.values
                          .map((t) => DropdownMenuItem(
                                value: t,
                                child: Text(t.displayName),
                              ))
                          .toList(),
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

  /// Card-shaped scanning guide frame with instant cross-platform memory preview
  Widget _buildCardFrame(ThemeData theme) {
    final scannedBytes = _frontScanned ? (_scannedBackBytes ?? _scannedBytes) : _scannedBytes;
    return Center(
      child: Container(
        width: 320,
        height: 200,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: scannedBytes != null
                ? theme.colorScheme.primary
                : theme.colorScheme.outline.withValues(alpha: 0.5),
            width: scannedBytes != null ? 2.5 : 1.5,
          ),
          color: theme.colorScheme.surfaceContainerLow,
          image: scannedBytes != null
              ? DecorationImage(
                  image: MemoryImage(scannedBytes),
                  fit: BoxFit.cover,
                )
              : null,
        ),
        child: scannedBytes == null
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
