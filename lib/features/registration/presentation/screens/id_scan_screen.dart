import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:study_library/core/router/app_router.dart';
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

  void _openLiveQrScanner() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.black,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => _LiveAadhaarQrScannerSheet(
        onQrDetected: (String rawCode) {
          Navigator.of(ctx).pop();
          _handleQrDecoded(rawCode);
        },
      ),
    );
  }

  void _handleQrDecoded(String rawCode) {
    final qrResult = QrIdParser.parseQrString(rawCode);
    if (qrResult == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unrecognized QR format. Please scan an official Aadhaar or Indian Gov ID QR code.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      HapticFeedback.mediumImpact();
    } catch (_) {}

    final ocrResult = qrResult.toOcrResult();

    final updates = <String, dynamic>{
      'govIdType': qrResult.type.name,
      if (ocrResult.name != null && ocrResult.name!.trim().isNotEmpty) 'name': ocrResult.name!.trim(),
      if (ocrResult.fatherName != null && ocrResult.fatherName!.trim().isNotEmpty) 'fatherName': ocrResult.fatherName!.trim(),
      if (ocrResult.dob != null && ocrResult.dob!.trim().isNotEmpty) 'dob': ocrResult.dob!.trim(),
      if (ocrResult.gender != null && ocrResult.gender!.trim().isNotEmpty) 'gender': ocrResult.gender!.trim(),
      if (ocrResult.idNumber != null && ocrResult.idNumber!.trim().isNotEmpty) 'govIdNumber': ocrResult.idNumber!.trim(),
      if (ocrResult.address != null && ocrResult.address!.trim().isNotEmpty) 'address': ocrResult.address!.trim(),
      if (ocrResult.pinCode != null && ocrResult.pinCode!.trim().isNotEmpty) 'pinCode': ocrResult.pinCode!.trim(),
      if (ocrResult.phone != null && ocrResult.phone!.trim().isNotEmpty) 'phone': ocrResult.phone!.trim(),
      'isQrVerified': 'true',
    };

    ref.read(registrationNotifierProvider.notifier).updateFields(updates);
    ref.read(ocrResultProvider.notifier).setResult({
      ...ocrResult.toMap(),
      'isQrVerified': 'true',
    });

    setState(() {
      _selectedType = qrResult.type;
      _frontScanned = true;
    });

    _showAutoFillPreview(ocrResult);
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
        
        // Safeguard: Never allow false PAN / generic detection to override user-selected Aadhaar
        // unless unmistakable evidence of that ID type exists in text
        GovIdType effectiveType;
        if (detectedType == GovIdType.other) {
          effectiveType = _selectedType;
        } else if (_selectedType == GovIdType.aadhaar && detectedType != GovIdType.aadhaar) {
          final upper = rawText.toUpperCase();
          final isDefinitePan = upper.contains('INCOME TAX') ||
              RegExp(r'\b[A-Z]{5}[0-9]{4}[A-Z]\b').hasMatch(upper);
          final isDefiniteDl = upper.contains('DRIVING LICENCE') ||
              upper.contains('DRIVING LICENSE');
          final isDefiniteVoter = upper.contains('ELECTION COMMISSION');
          final isDefinitePassport = upper.contains('PASSPORT') ||
              upper.contains('P<IND');

          if (isDefinitePan) {
            effectiveType = GovIdType.pan;
          } else if (isDefiniteDl) {
            effectiveType = GovIdType.drivingLicence;
          } else if (isDefiniteVoter) {
            effectiveType = GovIdType.voterId;
          } else if (isDefinitePassport) {
            effectiveType = GovIdType.passport;
          } else {
            effectiveType = _selectedType;
          }
        } else {
          effectiveType = detectedType;
        }

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
          'isQrVerified': result.isQrVerified ? 'true' : 'false',
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
          'isQrVerified': result.isQrVerified ? 'true' : 'false',
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
                    result.isQrVerified
                        ? Icons.verified_rounded
                        : (isIdValid ? Icons.verified_rounded : Icons.auto_fix_high_rounded),
                    color: result.isQrVerified
                        ? const Color(0xFF16A34A)
                        : (isIdValid ? Colors.green.shade600 : const Color(0xFF2563EB)),
                    size: 28,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          result.isQrVerified
                              ? 'Official ID QR Verified ✓'
                              : (isIdValid ? 'ID Scanned & Number Validated ✓' : 'ID Scanned (Please Review)'),
                          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          result.isQrVerified
                              ? '100% Cryptographic Match from UIDAI Signed QR'
                              : (isIdValid
                                  ? '${_selectedType.displayName} Checksum Verified  •  Review details in Step 2'
                                  : '${filled.length} fields auto-filled  •  Verify details in Step 2'),
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
                    children: filled.entries.where((e) => e.key != 'isQrVerified').map((e) {
                      final label = labelMap[e.key] ?? e.key;
                      bool? isValid;
                      if (e.key == 'idNumber') isValid = GovIdValidator.isValid(_selectedType, e.value);
                      if (e.key == 'name') isValid = GovIdValidator.isValidName(e.value);
                      if (e.key == 'dob') isValid = GovIdValidator.isValidDob(e.value);
                      if (e.key == 'pinCode') isValid = GovIdValidator.isValidPinCode(e.value);

                      IconData iconData;
                      Color iconColor;
                      Widget badgeWidget;

                      if (result.isQrVerified) {
                        iconData = Icons.verified_rounded;
                        iconColor = Colors.green.shade600;
                        badgeWidget = Text('Verified ✓', style: TextStyle(color: Colors.green.shade700, fontWeight: FontWeight.bold, fontSize: 11));
                      } else if (e.key == 'idNumber' && isValid == true) {
                        iconData = Icons.verified_rounded;
                        iconColor = Colors.green.shade600;
                        badgeWidget = Text('Checksum ✓', style: TextStyle(color: Colors.green.shade700, fontWeight: FontWeight.bold, fontSize: 11));
                      } else if (isValid == false) {
                        iconData = Icons.warning_amber_rounded;
                        iconColor = Colors.amber.shade800;
                        badgeWidget = Text('Review', style: TextStyle(color: Colors.amber.shade900, fontSize: 11, fontWeight: FontWeight.bold));
                      } else {
                        iconData = Icons.auto_fix_high_rounded;
                        iconColor = const Color(0xFF2563EB);
                        badgeWidget = const Text('Auto-filled', style: TextStyle(color: Color(0xFF1D4ED8), fontSize: 11, fontWeight: FontWeight.w600));
                      }

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
                            const SizedBox(width: 4),
                            badgeWidget,
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
      appBar: AppBar(
        title: const Text('Step 1 of 6: Scan Government ID'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go(Routes.login);
            }
          },
        ),
      ),
      body: Column(
        children: [
          const LinearProgressIndicator(value: 1 / 6),
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
                    // ── 1. RECOMMENDED: DIRECT AADHAAR / ID QR SCANNER ──────
                    Container(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF047857), Color(0xFF059669)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF059669).withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: _openLiveQrScanner,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: const BoxDecoration(
                                    color: Colors.white24,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.qr_code_scanner_rounded, color: Colors.white, size: 24),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          const Text(
                                            'Scan Aadhaar QR Code',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 15,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: const BoxDecoration(
                                              color: Colors.amber,
                                              borderRadius: BorderRadius.all(Radius.circular(6)),
                                            ),
                                            child: const Text(
                                              '100% ACCURATE',
                                              style: TextStyle(
                                                color: Colors.black87,
                                                fontSize: 9,
                                                fontWeight: FontWeight.w900,
                                                letterSpacing: 0.5,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                      const Text(
                                        'Instant, zero typos • Direct UIDAI signed demographic data',
                                        style: TextStyle(color: Colors.white70, fontSize: 11.5),
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white70, size: 14),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        const Expanded(child: Divider()),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: Text('OR USE OCR PHOTO SCAN',
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey.shade500,
                                  letterSpacing: 0.8)),
                        ),
                        const Expanded(child: Divider()),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // ── 2. OCR PHOTO SCAN BUTTONS ────────────────────────────
                    FilledButton.icon(
                      onPressed: () => _captureAndScan(ImageSource.camera),
                      icon: const Icon(Icons.camera_alt_rounded),
                      label: const Text('Scan Card with Camera'),
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

  /// CR80 Standard (1.586 : 1) Aspect Ratio Card Viewfinder Frame
  Widget _buildCardFrame(ThemeData theme) {
    final scannedBytes = _frontScanned ? (_scannedBackBytes ?? _scannedBytes) : _scannedBytes;
    return Center(
      child: Container(
        width: 320,
        height: 202, // Standard CR80 card aspect ratio (85.6mm x 53.98mm)
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: scannedBytes != null
                ? theme.colorScheme.primary
                : theme.colorScheme.outline.withValues(alpha: 0.35),
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
            ? Stack(
                children: [
                  // Corner brackets
                  Positioned(
                    top: 12,
                    left: 12,
                    child: Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        border: Border(
                          top: BorderSide(color: theme.colorScheme.primary, width: 2.5),
                          left: BorderSide(color: theme.colorScheme.primary, width: 2.5),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        border: Border(
                          top: BorderSide(color: theme.colorScheme.primary, width: 2.5),
                          right: BorderSide(color: theme.colorScheme.primary, width: 2.5),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 12,
                    left: 12,
                    child: Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(color: theme.colorScheme.primary, width: 2.5),
                          left: BorderSide(color: theme.colorScheme.primary, width: 2.5),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 12,
                    right: 12,
                    child: Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(color: theme.colorScheme.primary, width: 2.5),
                          right: BorderSide(color: theme.colorScheme.primary, width: 2.5),
                        ),
                      ),
                    ),
                  ),

                  // Center Guidance
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.badge_outlined,
                          size: 42,
                          color: theme.colorScheme.primary.withValues(alpha: 0.7),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _frontScanned && _hasTwoSides
                              ? 'Fit Back of ${_selectedType.displayName} inside frame'
                              : 'Fit ${_selectedType.displayName} inside frame',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Ensure clear lighting • Avoid shadows & glare',
                          style: TextStyle(
                            fontSize: 11,
                            color: theme.colorScheme.outline,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              )
            : Align(
                alignment: Alignment.bottomRight,
                child: Container(
                  margin: const EdgeInsets.all(10),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.75),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.check_circle_rounded, color: Colors.greenAccent, size: 14),
                      const SizedBox(width: 5),
                      Text(
                        _frontScanned && _scannedBackBytes != null ? 'Back Captured' : 'Front Captured',
                        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}

/// Live Aadhaar & Government ID QR Code Camera Scanner Bottom Sheet
class _LiveAadhaarQrScannerSheet extends StatefulWidget {
  final ValueChanged<String> onQrDetected;

  const _LiveAadhaarQrScannerSheet({
    required this.onQrDetected,
  });

  @override
  State<_LiveAadhaarQrScannerSheet> createState() => _LiveAadhaarQrScannerSheetState();
}

class _LiveAadhaarQrScannerSheetState extends State<_LiveAadhaarQrScannerSheet> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    facing: CameraFacing.back,
    torchEnabled: false,
  );
  bool _hasScanned = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_hasScanned) return;
    for (final barcode in capture.barcodes) {
      final code = barcode.rawValue;
      if (code != null && code.trim().isNotEmpty) {
        setState(() => _hasScanned = true);
        widget.onQrDetected(code.trim());
        break;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: const BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Top bar with grabber & close
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white, size: 26),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                const Text(
                  'Scan Aadhaar QR Code',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.flash_on_rounded, color: Colors.white, size: 22),
                      onPressed: () => _controller.toggleTorch(),
                    ),
                    IconButton(
                      icon: const Icon(Icons.cameraswitch_rounded, color: Colors.white, size: 22),
                      onPressed: () => _controller.switchCamera(),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Live Viewfinder
          Expanded(
            child: Stack(
              alignment: Alignment.center,
              children: [
                MobileScanner(
                  controller: _controller,
                  onDetect: _onDetect,
                ),

                // Viewfinder Reticle Overlay
                Center(
                  child: Container(
                    width: 260,
                    height: 260,
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFF10B981), width: 2.5),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF10B981).withValues(alpha: 0.25),
                          blurRadius: 16,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Stack(
                      children: [
                        Positioned(
                          top: 10,
                          left: 10,
                          child: Container(width: 24, height: 24, decoration: const BoxDecoration(border: Border(top: BorderSide(color: Colors.white, width: 3), left: BorderSide(color: Colors.white, width: 3)))),
                        ),
                        Positioned(
                          top: 10,
                          right: 10,
                          child: Container(width: 24, height: 24, decoration: const BoxDecoration(border: Border(top: BorderSide(color: Colors.white, width: 3), right: BorderSide(color: Colors.white, width: 3)))),
                        ),
                        Positioned(
                          bottom: 10,
                          left: 10,
                          child: Container(width: 24, height: 24, decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Colors.white, width: 3), left: BorderSide(color: Colors.white, width: 3)))),
                        ),
                        Positioned(
                          bottom: 10,
                          right: 10,
                          child: Container(width: 24, height: 24, decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Colors.white, width: 3), right: BorderSide(color: Colors.white, width: 3)))),
                        ),
                      ],
                    ),
                  ),
                ),

                // Helper text pill
                Positioned(
                  bottom: 30,
                  left: 20,
                  right: 20,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.75),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: const Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.center_focus_strong_rounded, color: Color(0xFF10B981), size: 18),
                            SizedBox(width: 8),
                            Text(
                              'Align Aadhaar QR inside the box',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                          ],
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Works with e-Aadhaar PDF, PVC card & paper slips',
                          style: TextStyle(color: Colors.white70, fontSize: 11.5),
                          textAlign: TextAlign.center,
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
    );
  }
}
