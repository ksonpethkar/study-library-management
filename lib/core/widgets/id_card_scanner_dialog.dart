import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:study_library/features/registration/data/ocr_parser.dart';
import 'package:study_library/features/registration/data/document_layout_classifier.dart';
import 'package:study_library/core/validators/gov_id_validator.dart';
import 'package:study_library/services/ocr_service.dart';
import 'package:study_library/services/document_picker_service.dart';
import 'package:study_library/core/utils/error_formatter.dart';

/// Data returned when the user completes an ID scan
class IdScanResult {
  final GovIdType detectedType;
  final OcrResult frontResult;
  final OcrResult? backResult;
  final Uint8List? frontImageBytes;
  final Uint8List? backImageBytes;

  const IdScanResult({
    required this.detectedType,
    required this.frontResult,
    this.backResult,
    this.frontImageBytes,
    this.backImageBytes,
  });

  /// Unified name
  String? get name => frontResult.name;
  String? get fatherName => frontResult.fatherName;
  String? get dob => frontResult.dob;
  String? get gender => frontResult.gender;
  String? get idNumber => frontResult.idNumber;
  String? get college => frontResult.college;
  String? get course => frontResult.course;
  String? get rollNumber => frontResult.rollNumber;
  String? get bloodGroup => frontResult.bloodGroup ?? backResult?.bloodGroup;

  /// Address & PIN from back side if available, else front side
  String? get address => backResult?.address ?? frontResult.address;
  String? get pinCode => backResult?.pinCode ?? frontResult.pinCode;
  String? get phone => frontResult.phone ?? backResult?.phone;

  /// Validates format and mathematical checksum (e.g. Verhoeff for Aadhaar)
  bool get isChecksumValid {
    final num = idNumber;
    if (num == null || num.trim().isEmpty) return false;
    return GovIdValidator.isValid(detectedType, num);
  }
}

class IdCardScannerDialog extends StatefulWidget {
  final GovIdType? initialType;
  final Function(IdScanResult result) onScanned;

  const IdCardScannerDialog({
    super.key,
    this.initialType,
    required this.onScanned,
  });

  static Future<void> show(
    BuildContext context, {
    GovIdType? initialType,
    required Function(IdScanResult result) onScanned,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => IdCardScannerDialog(
        initialType: initialType,
        onScanned: onScanned,
      ),
    );
  }

  @override
  State<IdCardScannerDialog> createState() => _IdCardScannerDialogState();
}

class _IdCardScannerDialogState extends State<IdCardScannerDialog> {
  final OcrService _ocrService = OcrService();

  GovIdType? _selectedType; // null = Auto-Detect
  bool _isAutoDetect = true;

  Uint8List? _frontBytes;
  Uint8List? _backBytes;

  OcrResult? _frontResult;
  OcrResult? _backResult;
  GovIdType _detectedType = GovIdType.aadhaar;

  bool _isScanning = false;
  String _scanStatus = '';
  bool _showBackScanStep = false;
  String? _layoutGuidance;

  @override
  void initState() {
    super.initState();
    if (widget.initialType != null) {
      _selectedType = widget.initialType;
      _isAutoDetect = false;
    }
  }

  bool _requiresTwoSides(GovIdType type) {
    return type == GovIdType.aadhaar ||
        type == GovIdType.drivingLicence ||
        type == GovIdType.passport ||
        type == GovIdType.voterId;
  }

  Future<void> _captureImage(ImageSource source, {bool isBack = false}) async {
    try {
      final doc = await DocumentPickerService.pickDocument(
        context: context,
        preferredSource: source,
      );
      if (doc == null || !mounted) return;

      final bytes = doc.bytes;

      setState(() {
        _isScanning = true;
        _scanStatus = isBack
            ? '⚡ Decoding Back Side (QR Code & Address/PIN)...'
            : '⚡ Decoding ID Card (Instant QR & Structured OCR)...';
        if (isBack) {
          _backBytes = bytes;
        } else {
          _frontBytes = bytes;
        }
      });

      // 1. Instant client-side QR Code decoding
      final qrString = await _ocrService.decodeQrBytes(bytes);

      // 2. High-accuracy OCR
      final rawText = await _ocrService.processImageBytes(bytes);

      if (!mounted) return;

      if (isBack) {
        // Back side parsing
        final typeToUse = _selectedType ?? _detectedType;
        final parsed = OcrParser.parseUnified(
          qrString: qrString,
          rawText: rawText,
          preferredType: typeToUse,
        );
        final layout = DocumentLayoutClassifier.classify(
          rawText: rawText,
          preferredType: typeToUse,
        );
        setState(() {
          _backResult = parsed;
          _isScanning = false;
          _showBackScanStep = false;
          _layoutGuidance = DocumentLayoutClassifier.getGuidanceMessage(
            type: typeToUse,
            classification: layout,
            isSecondUpload: true,
            hasAddress: (parsed.address != null && parsed.address!.isNotEmpty),
          );
        });
      } else {
        // Front side parsing & intelligent orientation classification
        final qrParsed = QrIdParser.parseQrString(qrString);
        final autoDetected = qrParsed?.type ?? OcrParser.detectGovIdType(rawText);
        final effectiveType = _isAutoDetect ? autoDetected : (_selectedType ?? autoDetected);
        final parsed = OcrParser.parseUnified(
          qrString: qrString,
          rawText: rawText,
          preferredType: effectiveType,
        );

        final layout = DocumentLayoutClassifier.classify(
          rawText: rawText,
          preferredType: effectiveType,
        );

        setState(() {
          _detectedType = effectiveType;
          _isScanning = false;

          final hasAddress = (parsed.address != null && parsed.address!.trim().isNotEmpty);

          if (layout == DocumentSideClassification.bothSidesCombined) {
            // Full Single-Page Xerox or e-Aadhaar PDF: both sides already present!
            _frontResult = parsed;
            _backResult = parsed;
            _backBytes = bytes;
            _showBackScanStep = false;
            _layoutGuidance = DocumentLayoutClassifier.getGuidanceMessage(
              type: effectiveType,
              classification: layout,
              isSecondUpload: false,
              hasAddress: true,
            );
          } else if (layout == DocumentSideClassification.panCard || effectiveType == GovIdType.pan) {
            // PAN card - single sided, never ask for back side
            _frontResult = parsed;
            _showBackScanStep = false;
            _layoutGuidance = DocumentLayoutClassifier.getGuidanceMessage(
              type: effectiveType,
              classification: DocumentSideClassification.panCard,
              isSecondUpload: false,
            );
          } else if (layout == DocumentSideClassification.backOnly) {
            // User uploaded back side first!
            _backResult = parsed;
            _backBytes = bytes;
            _frontResult = null;
            _frontBytes = null;
            _showBackScanStep = false;
            _layoutGuidance = DocumentLayoutClassifier.getGuidanceMessage(
              type: effectiveType,
              classification: layout,
              isSecondUpload: false,
            );
          } else {
            // Normal front side
            _frontResult = parsed;
            _showBackScanStep = DocumentLayoutClassifier.isBackSideRequired(
              type: effectiveType,
              classification: layout,
              hasAddressAlready: hasAddress,
            );
            _layoutGuidance = DocumentLayoutClassifier.getGuidanceMessage(
              type: effectiveType,
              classification: layout,
              isSecondUpload: false,
              hasAddress: hasAddress,
            );
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isScanning = false;
        });
        AppErrorFormatter.showErrorSnackBar(context, e, actionContext: 'gov_id');
      }
    }
  }

  void _applyResult() {
    if (_frontResult == null && _backResult == null) return;
    final finalResult = IdScanResult(
      detectedType: _detectedType,
      frontResult: _frontResult ?? _backResult!,
      backResult: _backResult,
      frontImageBytes: _frontBytes,
      backImageBytes: _backBytes,
    );
    widget.onScanned(finalResult);
    Navigator.of(context).pop();
  }

  void _skipBackSide() {
    setState(() {
      _showBackScanStep = false;
    });
  }

  void _resetFront() {
    setState(() {
      _frontBytes = null;
      _backBytes = null;
      _frontResult = null;
      _backResult = null;
      _showBackScanStep = false;
      _layoutGuidance = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      backgroundColor: theme.colorScheme.surface,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 720),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.badge_rounded,
                        color: theme.colorScheme.primary,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Scan Government ID',
                            style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            'Auto-detects Aadhaar, PAN, DL & auto-fills form',
                            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // ID Type Dropdown
                if (_frontBytes == null) ...[
                  Row(
                    children: [
                      const Icon(Icons.credit_card_rounded, size: 20),
                      const SizedBox(width: 8),
                      Text('Card Type: ', style: theme.textTheme.labelLarge),
                      const SizedBox(width: 8),
                      Expanded(
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<GovIdType?>(
                            value: _isAutoDetect ? null : _selectedType,
                            isExpanded: true,
                            hint: const Text('Auto-Detect ID (Recommended)'),
                            items: const [
                              DropdownMenuItem<GovIdType?>(
                                value: null,
                                child: Text('🔍 Auto-Detect ID (Recommended)'),
                              ),
                              DropdownMenuItem(
                                value: GovIdType.aadhaar,
                                child: Text('🪪 Aadhaar Card (Front + Back)'),
                              ),
                              DropdownMenuItem(
                                value: GovIdType.pan,
                                child: Text('💳 PAN Card'),
                              ),
                              DropdownMenuItem(
                                value: GovIdType.drivingLicence,
                                child: Text('🚗 Driving Licence'),
                              ),
                              DropdownMenuItem(
                                value: GovIdType.voterId,
                                child: Text('🗳️ Voter ID (EPIC)'),
                              ),
                              DropdownMenuItem(
                                value: GovIdType.passport,
                                child: Text('🛂 Passport'),
                              ),
                              DropdownMenuItem(
                                value: GovIdType.collegeId,
                                child: Text('🎓 College / Student ID'),
                              ),
                              DropdownMenuItem(
                                value: GovIdType.other,
                                child: Text('📄 Other Govt. Photo ID'),
                              ),
                            ],
                            onChanged: (val) {
                              setState(() {
                                if (val == null) {
                                  _isAutoDetect = true;
                                  _selectedType = null;
                                } else {
                                  _isAutoDetect = false;
                                  _selectedType = val;
                                }
                              });
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 20),
                ],

                // Card Frame Outbox (Viewfinder)
                _buildCardOutbox(theme, isDark),

                const SizedBox(height: 16),

                // Scanning Progress Indicator
                if (_isScanning) ...[
                  LinearProgressIndicator(color: theme.colorScheme.primary),
                  const SizedBox(height: 8),
                  Center(
                    child: Text(
                      _scanStatus,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Action Area: Front Scan, Back Scan, or Summary Apply
                if (!_isScanning) _buildActionControls(theme),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// The Outbox Viewfinder (Card-shaped container with corner brackets)
  Widget _buildCardOutbox(ThemeData theme, bool isDark) {
    final activeBytes = _showBackScanStep ? _backBytes : _frontBytes;
    final isFront = !_showBackScanStep;

    return Center(
      child: Container(
        width: 340,
        height: 215,
        decoration: BoxDecoration(
          color: activeBytes != null
              ? Colors.black87
              : (isDark ? Colors.grey.shade900 : Colors.grey.shade100),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: activeBytes != null
                ? theme.colorScheme.primary
                : theme.colorScheme.outline.withValues(alpha: 0.6),
            width: activeBytes != null ? 2.5 : 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Display image if captured
              if (activeBytes != null)
                Image.memory(
                  activeBytes,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                )
              else
                // Empty state card guide
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      isFront ? Icons.credit_card_rounded : Icons.flip_camera_android_rounded,
                      size: 44,
                      color: theme.colorScheme.primary.withValues(alpha: 0.6),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      isFront
                          ? 'Step 1: Align Front of ID Card'
                          : 'Step 2: Align Back of ID Card',
                      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isFront
                          ? 'Keep photo, name & ID number clear'
                          : 'Keep address & PIN code clear',
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.wb_sunny_outlined, size: 12, color: Colors.amber.shade700),
                        const SizedBox(width: 4),
                        Text(
                          'Avoid camera flash glare on plastic cards',
                          style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ],
                ),

              // Corner brackets
              Positioned(
                top: 10,
                left: 10,
                child: Text('┌', style: TextStyle(color: theme.colorScheme.primary, fontSize: 28, fontWeight: FontWeight.bold)),
              ),
              Positioned(
                top: 10,
                right: 10,
                child: Text('┐', style: TextStyle(color: theme.colorScheme.primary, fontSize: 28, fontWeight: FontWeight.bold)),
              ),
              Positioned(
                bottom: 10,
                left: 10,
                child: Text('└', style: TextStyle(color: theme.colorScheme.primary, fontSize: 28, fontWeight: FontWeight.bold)),
              ),
              Positioned(
                bottom: 10,
                right: 10,
                child: Text('┘', style: TextStyle(color: theme.colorScheme.primary, fontSize: 28, fontWeight: FontWeight.bold)),
              ),

              // Side Indicator Tag
              if (activeBytes != null)
                Positioned(
                  top: 12,
                  left: 24,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.75),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      isFront ? '✓ Front Side Captured' : '✓ Back Side Captured',
                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Builds the 2 primary actions: Camera & Gallery, or Back-side prompts, or Auto-fill review
  Widget _buildActionControls(ThemeData theme) {
    // 1. Initial State: No front image captured yet
    if (_frontBytes == null) {
      return Column(
        children: [
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => _captureImage(ImageSource.camera),
                  icon: const Icon(Icons.camera_alt_rounded),
                  label: const Text('Camera'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _captureImage(ImageSource.gallery),
                  icon: const Icon(Icons.upload_file_rounded),
                  label: const Text('Upload File'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ],
          ),
        ],
      );
    }

    // 2. Step 2: Prompt for Back Side (Aadhaar or DL)
    if (_showBackScanStep) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: theme.colorScheme.primaryContainer.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.4)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.check_circle_rounded, color: Colors.green.shade600, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Front Side Scanned (${_detectedType.name.toUpperCase()})',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'Now scan the BACK side to auto-extract full Residential Address & PIN code.',
              style: TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => _captureImage(ImageSource.camera, isBack: true),
                    icon: const Icon(Icons.camera_alt_rounded),
                    label: const Text('Back Camera'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _captureImage(ImageSource.gallery, isBack: true),
                    icon: const Icon(Icons.upload_file_rounded),
                    label: const Text('Back Upload'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _skipBackSide,
              child: const Text('Skip Back Side (Use Front Only)'),
            ),
          ],
        ),
      );
    }

    // 3. Completed: Show Extracted Details Summary & Auto-Fill CTA
    final f = _frontResult ?? _backResult;
    final b = _backResult;
    final hasAddress = (b?.address != null && b!.address!.isNotEmpty) ||
        (f?.address != null && f!.address!.isNotEmpty);
    final hasExtractedData = (f?.idNumber != null && f!.idNumber!.trim().isNotEmpty) ||
        (f?.name != null && f!.name!.trim().isNotEmpty) ||
        (f != null && f.confidence > 25);

    final isIdValid = GovIdValidator.isValid(_detectedType, f?.idNumber);
    final isNameValid = GovIdValidator.isValidName(f?.name);
    final isDobValid = GovIdValidator.isValidDob(f?.dob);
    final isPinValid = GovIdValidator.isValidPinCode(b?.pinCode ?? f?.pinCode);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Smart Guidance Banner based on Layout Detection
        if (_layoutGuidance != null) ...[
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isIdValid
                  ? Colors.green.withValues(alpha: 0.1)
                  : theme.colorScheme.primaryContainer.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isIdValid
                    ? Colors.green.withValues(alpha: 0.4)
                    : theme.colorScheme.primary.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  isIdValid ? Icons.verified_rounded : Icons.info_outline_rounded,
                  size: 20,
                  color: isIdValid ? Colors.green.shade700 : theme.colorScheme.primary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _layoutGuidance!,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: isIdValid ? Colors.green.shade900 : theme.colorScheme.primary,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],

        if (hasExtractedData) ...[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isIdValid
                  ? Colors.green.withValues(alpha: 0.08)
                  : Colors.amber.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isIdValid
                    ? Colors.green.withValues(alpha: 0.35)
                    : Colors.amber.withValues(alpha: 0.4),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      isIdValid ? Icons.verified_rounded : Icons.warning_amber_rounded,
                      color: isIdValid ? Colors.green : Colors.amber.shade800,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        isIdValid
                            ? 'ID Detected: ${_detectedType.name.toUpperCase()} (VALIDATED ✓)'
                            : 'ID Detected: ${_detectedType.name.toUpperCase()} (REVIEW REQUIRED)',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13.5,
                          color: isIdValid ? Colors.green.shade800 : Colors.amber.shade900,
                        ),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _resetFront,
                      icon: const Icon(Icons.refresh_rounded, size: 16),
                      label: const Text('Retake', style: TextStyle(fontSize: 12)),
                    ),
                  ],
                ),
                const Divider(height: 12),
                _buildExtractedRow(
                  'ID Number',
                  f.idNumber,
                  isValid: isIdValid,
                  badgeText: isIdValid ? 'Checksum OK' : 'Check Digits',
                ),
                _buildExtractedRow(
                  'Full Name',
                  f.name,
                  isValid: isNameValid,
                  badgeText: isNameValid ? null : 'Review Name',
                ),
                _buildExtractedRow("Father's Name", f.fatherName),
                _buildExtractedRow(
                  'Date of Birth',
                  f.dob,
                  isValid: isDobValid,
                  badgeText: isDobValid ? null : 'Review Date',
                ),
                _buildExtractedRow('Gender', f.gender),
                _buildExtractedRow('Blood Group', f.bloodGroup ?? b?.bloodGroup),
                _buildExtractedRow('Phone / Contact', f.phone ?? b?.phone),
                _buildExtractedRow('Vehicle Class', f.vehicleClass ?? b?.vehicleClass),
                if (hasAddress) ...[
                  _buildExtractedRow('Address', b?.address ?? f.address),
                  _buildExtractedRow(
                    'PIN Code',
                    b?.pinCode ?? f.pinCode,
                    isValid: isPinValid,
                    badgeText: isPinValid ? null : 'Check PIN',
                  ),
                ],
                if (f.college != null) _buildExtractedRow('College', f.college),
                if (f.course != null) _buildExtractedRow('Course', f.course),
              ],
            ),
          ),
        ] else ...[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.amber.shade400),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.info_outline_rounded, color: Colors.amber.shade900, size: 22),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Document Scanned: ${_detectedType.name.toUpperCase()}',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.amber.shade900),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _resetFront,
                      icon: const Icon(Icons.refresh_rounded, size: 16),
                      label: const Text('Retake', style: TextStyle(fontSize: 12)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Could not clearly extract text details automatically from this image.\n'
                  'Your photo has been captured and will be saved securely as ID proof — please enter your ID details manually.',
                  style: TextStyle(fontSize: 12, height: 1.4, color: Colors.grey.shade900),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 12),
        if (_backBytes == null && _requiresTwoSides(_detectedType)) ...[
          OutlinedButton.icon(
            onPressed: () => setState(() => _showBackScanStep = true),
            icon: const Icon(Icons.flip_camera_android_rounded, size: 18),
            label: const Text('Scan Back Side (Optional)'),
          ),
          const SizedBox(height: 8),
        ],
        FilledButton.icon(
          onPressed: _applyResult,
          icon: const Icon(Icons.check_circle_rounded),
          label: Text(
            hasExtractedData ? 'Auto-Fill Form Now' : 'Save Document & Enter Details Manually',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
            backgroundColor: hasExtractedData ? Colors.green.shade700 : const Color(0xFF5D4037),
          ),
        ),
      ],
    );
  }

  Widget _buildExtractedRow(String label, String? value, {bool? isValid, String? badgeText}) {
    if (value == null || value.trim().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black54),
            ),
          ),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    value,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (isValid != null) ...[
                  const SizedBox(width: 6),
                  Icon(
                    isValid ? Icons.verified_rounded : Icons.warning_amber_rounded,
                    size: 16,
                    color: isValid ? Colors.green.shade600 : Colors.amber.shade800,
                  ),
                  if (badgeText != null) ...[
                    const SizedBox(width: 4),
                    Text(
                      badgeText,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: isValid ? Colors.green.shade700 : Colors.amber.shade900,
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
