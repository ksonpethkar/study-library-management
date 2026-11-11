import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:study_library/core/providers/library_provider.dart';
import 'package:study_library/services/image_service.dart';
import 'package:study_library/services/ocr_service.dart';
import 'package:study_library/services/document_picker_service.dart';
import '../../data/ocr_parser.dart';
import 'package:study_library/core/validators/gov_id_validator.dart';
import 'package:study_library/core/utils/app_validators.dart';
import 'package:study_library/services/form_config_service.dart';
import 'package:intl/intl.dart';
import '../providers/registration_provider.dart';

class RegistrationFormScreen extends ConsumerStatefulWidget {
  const RegistrationFormScreen({super.key});

  @override
  ConsumerState<RegistrationFormScreen> createState() =>
      _RegistrationFormScreenState();
}

class _RegistrationFormScreenState
    extends ConsumerState<RegistrationFormScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _fatherNameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _emailController;
  late final TextEditingController _idNumberController;
  late final TextEditingController _addressController;
  late final TextEditingController _pinCodeController;
  late final TextEditingController _collegeController;
  late final TextEditingController _courseController;
  late final TextEditingController _dobController;
  late final TextEditingController _bloodGroupController;
  late final TextEditingController _rollNumberController;
  late final TextEditingController _emergencyContactController;
  late final TextEditingController _yearController;
  late final TextEditingController _prepController;

  String _gender = 'male';
  GovIdType _selectedGovIdType = GovIdType.aadhaar;
  bool _isScanningId = false;
  String _scanStatusMessage = '';

  // Tracks which fields were auto-filled from OCR
  final Set<String> _autoFilledKeys = {};

  List<Map<String, dynamic>> _customFieldsConfig = [];
  final Map<String, TextEditingController> _customControllers = {};

  @override
  void initState() {
    super.initState();
    final reg = ref.read(registrationNotifierProvider);
    final ocr = ref.read(ocrResultProvider);
    final currentUser = FirebaseAuth.instance.currentUser;
    final hasGenuineOcr = ocr.isNotEmpty &&
        ocr.entries.any((e) => e.key != 'confidence' && e.value != null && e.value!.trim().isNotEmpty);

    String pick(String key) => reg[key]?.toString() ?? ocr[key]?.toString() ?? '';

    // Only mark auto-filled if it genuinely was extracted by OCR
    bool isFromOcr(String key) =>
        hasGenuineOcr && (ocr[key]?.trim().isNotEmpty == true || (key == 'govIdNumber' && ocr['idNumber']?.trim().isNotEmpty == true));

    void trackIfFilled(String key, String value) {
      if (value.isNotEmpty && isFromOcr(key)) {
        _autoFilledKeys.add(key);
      }
    }

    final nameVal = pick('name');
    final finalName = nameVal.isNotEmpty
        ? nameVal
        : (currentUser?.displayName ?? '');
    _nameController = TextEditingController(text: finalName);
    trackIfFilled('name', nameVal);

    final fatherVal = pick('fatherName');
    _fatherNameController = TextEditingController(text: fatherVal);
    trackIfFilled('fatherName', fatherVal);

    final dobVal = pick('dob');
    _dobController = TextEditingController(text: dobVal);
    trackIfFilled('dob', dobVal);

    final phoneVal = pick('phone');
    _phoneController = TextEditingController(text: phoneVal);
    trackIfFilled('phone', phoneVal);

    final initialEmail = pick('email');
    final emailVal = initialEmail.isNotEmpty
        ? initialEmail
        : (currentUser?.email ?? '');
    _emailController = TextEditingController(text: emailVal);

    final idVal = pick('govIdNumber');
    _idNumberController = TextEditingController(text: idVal);
    trackIfFilled('govIdNumber', idVal);

    final addrVal = pick('address');
    _addressController = TextEditingController(text: addrVal);
    trackIfFilled('address', addrVal);

    final pinVal = pick('pinCode');
    _pinCodeController = TextEditingController(text: pinVal);
    trackIfFilled('pinCode', pinVal);

    final collegeVal = pick('college');
    _collegeController = TextEditingController(text: collegeVal);
    trackIfFilled('college', collegeVal);

    final courseVal = pick('course');
    _courseController = TextEditingController(text: courseVal);
    trackIfFilled('course', courseVal);

    final bloodVal = pick('bloodGroup');
    _bloodGroupController = TextEditingController(text: bloodVal);
    trackIfFilled('bloodGroup', bloodVal);

    final rollVal = pick('rollNumber');
    _rollNumberController = TextEditingController(text: rollVal);
    trackIfFilled('rollNumber', rollVal);

    final rawGender = pick('gender').toLowerCase();
    if (rawGender.contains('female')) {
      _gender = 'female';
    } else if (rawGender.contains('other')) {
      _gender = 'other';
    } else {
      _gender = 'male';
    }

    final rawGovIdType = pick('govIdType').toLowerCase();
    _selectedGovIdType = GovIdType.values.firstWhere(
      (t) => t.name.toLowerCase() == rawGovIdType ||
             (rawGovIdType.contains('dl') && t == GovIdType.drivingLicence) ||
             (rawGovIdType.contains('voter') && t == GovIdType.voterId) ||
             (rawGovIdType.contains('pass') && t == GovIdType.passport),
      orElse: () => GovIdType.aadhaar,
    );

    final emergencyVal = pick('emergencyContact');
    _emergencyContactController = TextEditingController(text: emergencyVal);
    trackIfFilled('emergencyContact', emergencyVal);

    final yearVal = pick('year');
    _yearController = TextEditingController(text: yearVal);
    trackIfFilled('year', yearVal);

    final prepVal = pick('prep');
    _prepController = TextEditingController(text: prepVal);
    trackIfFilled('prep', prepVal);

    _loadCustomFields();
  }

  Future<void> _loadCustomFields() async {
    final reg = ref.read(registrationNotifierProvider);
    final libId = reg['libraryId'] as String? ?? ref.read(currentLibraryIdProvider);
    if (libId == null || libId.isEmpty) return;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('libraries')
          .doc(libId)
          .collection('settings')
          .doc('form_config')
          .get();

      if (doc.exists && mounted) {
        final data = doc.data();
        if (data != null && data['fields'] is List) {
          final fields = (data['fields'] as List)
              .map((f) => Map<String, dynamic>.from(f as Map))
              .toList();

          setState(() {
            _customFieldsConfig = fields;
            for (final f in fields) {
              final id = f['id'] as String? ?? '';
              final isBuiltin = f['builtin'] as bool? ?? false;
              if (!isBuiltin && id.isNotEmpty && !_customControllers.containsKey(id)) {
                final existingVal = (reg['customFields'] as Map?)?[id]?.toString() ?? '';
                _customControllers[id] = TextEditingController(text: existingVal);
              }
            }
          });
        }
      }
    } catch (_) { /* intentionally silent */ }
  }

  bool _isFieldVisible(String fieldId) {
    if (_customFieldsConfig.isNotEmpty) {
      final match = _customFieldsConfig.where((f) => f['id'] == fieldId).firstOrNull;
      if (match != null) {
        return match['visible'] == true;
      }
      return false;
    }
    return const ['name', 'phone', 'email', 'govId', 'gender', 'address', 'prep'].contains(fieldId);
  }

  /// Returns whether a built-in field is required per admin form_config.
  /// Falls back to the hardcoded defaults (name & phone = required) if config not loaded.
  bool _isFieldRequired(String fieldId) {
    if (_customFieldsConfig.isEmpty) {
      // Hardcoded defaults before config loads
      return fieldId == 'name' || fieldId == 'phone';
    }
    final match = _customFieldsConfig.where((f) => f['id'] == fieldId).firstOrNull;
    if (match != null) {
      return match['required'] as bool? ?? false;
    }
    return false;
  }

  /// Builds a validator that respects the admin `required` flag for a field.
  String? Function(String?)? _requiredValidator(String fieldId, {String? customMessage}) {
    if (!_isFieldRequired(fieldId)) return null; // not required → no validator
    return (v) {
      if (v == null || v.trim().isEmpty) {
        return customMessage ?? 'This field is required';
      }
      return null;
    };
  }

  /// Returns the configured custom label or fallback with required asterisk if mandated
  String _label(String id, String defaultLabel) {
    final l = FormConfigService.getFieldLabel(_customFieldsConfig, id, defaultLabel);
    return _isFieldRequired(id) ? '$l *' : l;
  }

  Widget _buildCustomFieldInput(Map<String, dynamic> f) {
    final id = f['id'] as String? ?? '';
    final label = f['label'] as String? ?? id;
    final isRequired = f['required'] as bool? ?? false;
    final type = f['type'] as String? ?? 'Text';
    final customPattern = f['pattern'] as String?;
    final patternError = f['patternError'] as String?;
    final ctrl = _customControllers[id];
    if (ctrl == null) return const SizedBox.shrink();

    if (type == 'Date') {
      return Padding(
        padding: const EdgeInsets.only(bottom: 14.0),
        child: InkWell(
          onTap: () async {
            DateTime? initialDate;
            try {
              if (ctrl.text.isNotEmpty) {
                initialDate = DateFormat('dd/MM/yyyy').parse(ctrl.text);
              }
            } catch (_) {}
            final picked = await showDatePicker(
              context: context,
              initialDate: initialDate ?? DateTime.now(),
              firstDate: DateTime(1950),
              lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
            );
            if (picked != null) {
              setState(() {
                ctrl.text = DateFormat('dd/MM/yyyy').format(picked);
              });
            }
          },
          child: IgnorePointer(
            child: TextFormField(
              controller: ctrl,
              decoration: InputDecoration(
                labelText: '$label${isRequired ? ' *' : ''}',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.calendar_today_rounded, size: 20),
                suffixIcon: const Icon(Icons.arrow_drop_down),
              ),
              validator: isRequired
                  ? (val) => (val == null || val.trim().isEmpty) ? '$label is required' : null
                  : null,
            ),
          ),
        ),
      );
    }

    if (type == 'Number') {
      return Padding(
        padding: const EdgeInsets.only(bottom: 14.0),
        child: TextFormField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(
            labelText: '$label${isRequired ? ' *' : ''}',
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.numbers_rounded, size: 20),
          ),
          validator: (val) {
            if (isRequired && (val == null || val.trim().isEmpty)) {
              return '$label is required';
            }
            if (customPattern != null && customPattern.isNotEmpty) {
              return AppValidators.validatePattern(
                val,
                customPattern,
                errorMessage: patternError,
                required: isRequired,
                label: label,
              );
            }
            return null;
          },
        ),
      );
    }

    if (type == 'Dropdown') {
      final rawOptions = f['options'];
      final List<String> options = (rawOptions is List)
          ? rawOptions.map((e) => e?.toString().trim() ?? '').where((e) => e.isNotEmpty).toList()
          : [];

      return Padding(
        padding: const EdgeInsets.only(bottom: 14.0),
        child: DropdownButtonFormField<String>(
          initialValue: options.contains(ctrl.text) ? ctrl.text : null,
          items: options
              .map((opt) => DropdownMenuItem(value: opt, child: Text(opt)))
              .toList(),
          onChanged: (val) {
            setState(() {
              ctrl.text = val ?? '';
            });
          },
          decoration: InputDecoration(
            labelText: '$label${isRequired ? ' *' : ''}',
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.arrow_drop_down_circle_outlined, size: 20),
          ),
          validator: isRequired
              ? (val) => (val == null || val.trim().isEmpty) ? '$label is required' : null
              : null,
        ),
      );
    }

    // Default: Plain Text
    return Padding(
      padding: const EdgeInsets.only(bottom: 14.0),
      child: TextFormField(
        controller: ctrl,
        decoration: InputDecoration(
          labelText: '$label${isRequired ? ' *' : ''}',
          border: const OutlineInputBorder(),
        ),
        validator: (val) {
          if (isRequired && (val == null || val.trim().isEmpty)) {
            return '$label is required';
          }
          if (customPattern != null && customPattern.isNotEmpty) {
            return AppValidators.validatePattern(
              val,
              customPattern,
              errorMessage: patternError,
              required: isRequired,
              label: label,
            );
          }
          return null;
        },
      ),
    );
  }

  Widget _buildCategoryCustomFields(String category, {bool showSectionHeader = false, ThemeData? theme}) {
    final customFields = _customFieldsConfig.where((f) {
      final isBuiltin = f['builtin'] as bool? ?? false;
      final cat = f['category']?.toString() ?? FormFieldCategory.custom;
      final visible = f['visible'] as bool? ?? true;
      return !isBuiltin && visible && cat == category;
    }).toList();

    if (customFields.isEmpty) return const SizedBox.shrink();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showSectionHeader && theme != null) ...[
          const SizedBox(height: 16),
          _sectionHeader(theme, 'Additional Information'),
          const SizedBox(height: 12),
        ],
        ...customFields.map(_buildCustomFieldInput),
      ],
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _fatherNameController.dispose();
    _dobController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _idNumberController.dispose();
    _addressController.dispose();
    _pinCodeController.dispose();
    _collegeController.dispose();
    _courseController.dispose();
    _bloodGroupController.dispose();
    _rollNumberController.dispose();
    _emergencyContactController.dispose();
    _yearController.dispose();
    _prepController.dispose();
    for (final c in _customControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickSourceAndScan({bool isBack = false}) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade400,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Text(
                isBack
                    ? 'Attach Back Side of ID (Address)'
                    : 'Attach ${_selectedGovIdType.displayName}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFE0E7FF),
                  child: Icon(Icons.camera_alt_rounded, color: Color(0xFF4338CA)),
                ),
                title: const Text('Take Photo with Camera'),
                subtitle: const Text('Ensure bright lighting and readable text'),
                onTap: () => Navigator.pop(ctx, ImageSource.camera),
              ),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFECFDF5),
                  child: Icon(Icons.photo_library_rounded, color: Color(0xFF059669)),
                ),
                title: const Text('Choose from Gallery / Files'),
                subtitle: const Text('Upload clear existing photo or document'),
                onTap: () => Navigator.pop(ctx, ImageSource.gallery),
              ),
            ],
          ),
        ),
      ),
    );

    if (source != null) {
      await _scanOrAttachGovId(source, isBackSide: isBack);
    }
  }

  Future<void> _scanOrAttachGovId(ImageSource source, {bool isBackSide = false}) async {
    final doc = await DocumentPickerService.pickDocument(
      context: context,
      preferredSource: source,
    );
    if (doc == null || !mounted) return;

    final dataUrl = doc.dataUrl;

    setState(() {
      _isScanningId = true;
      _scanStatusMessage = isBackSide
          ? 'Reading address from document...'
          : 'Processing ${_selectedGovIdType.displayName}...';
    });

    try {
      if (doc.isPdf) {
        // PDF Document directly attached
        final updates = <String, dynamic>{
          if (isBackSide) ...{
            'govIdBackDataUrl': dataUrl,
            'govIdBackImageUrl': dataUrl,
            'govIdBackImagePath': dataUrl,
            'govIdBackFileName': doc.fileName,
          } else ...{
            'govIdType': _selectedGovIdType.name,
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
                    child: Text('PDF Document (${doc.fileName}) attached as ID proof!'),
                  ),
                ],
              ),
              backgroundColor: const Color(0xFF1E293B),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }

      // Image: attempt instant QR decode + OCR
      final ocrService = OcrService();
      final qrString = await ocrService.decodeQrBytes(doc.bytes);
      final rawText = await ocrService.processImageBytes(doc.bytes);

      if (isBackSide) {
        final backResult = OcrParser.parseByType(_selectedGovIdType, rawText);
        final updates = <String, dynamic>{
          'govIdBackDataUrl': dataUrl,
          'govIdBackImageUrl': dataUrl,
          'govIdBackImagePath': dataUrl,
          'govIdBackFileName': doc.fileName,
        };
        if (backResult.address != null && backResult.address!.trim().isNotEmpty) {
          updates['address'] = backResult.address!.trim();
          _addressController.text = backResult.address!.trim();
          _autoFilledKeys.add('address');
        }
        if (backResult.pinCode != null && backResult.pinCode!.trim().isNotEmpty) {
          updates['pinCode'] = backResult.pinCode!.trim();
          _pinCodeController.text = backResult.pinCode!.trim();
          _autoFilledKeys.add('pinCode');
        }
        ref.read(registrationNotifierProvider.notifier).updateFields(updates);
      } else {
        final qrParsed = QrIdParser.parseQrString(qrString);
        final detectedType = qrParsed?.type ?? OcrParser.detectGovIdType(rawText);
        final finalType = detectedType != GovIdType.other ? detectedType : _selectedGovIdType;
        final result = OcrParser.parseUnified(
          qrString: qrString,
          rawText: rawText,
          preferredType: finalType,
        );

        final updates = <String, dynamic>{
          'govIdType': finalType.name,
          'govIdDataUrl': dataUrl,
          'govIdImageUrl': dataUrl,
          'govIdImagePath': dataUrl,
          'govIdFileName': doc.fileName,
        };

        setState(() {
          _selectedGovIdType = finalType;
          if (result.idNumber != null && result.idNumber!.trim().isNotEmpty) {
            final formatted = GovIdValidator.format(finalType, result.idNumber!.trim());
            _idNumberController.text = formatted;
            _autoFilledKeys.add('govIdNumber');
            updates['govIdNumber'] = formatted;
          }
          if (result.name != null && result.name!.trim().isNotEmpty) {
            _nameController.text = result.name!.trim();
            _autoFilledKeys.add('name');
            updates['name'] = result.name!.trim();
          }
          if (result.fatherName != null && result.fatherName!.trim().isNotEmpty) {
            _fatherNameController.text = result.fatherName!.trim();
            _autoFilledKeys.add('fatherName');
            updates['fatherName'] = result.fatherName!.trim();
          }
          if (result.dob != null && result.dob!.trim().isNotEmpty) {
            _dobController.text = result.dob!.trim();
            _autoFilledKeys.add('dob');
            updates['dob'] = result.dob!.trim();
          }
          if (result.gender != null && result.gender!.trim().isNotEmpty) {
            final g = result.gender!.toLowerCase();
            if (g.contains('female')) {
              _gender = 'female';
            } else if (g.contains('male')) {
              _gender = 'male';
            }
            updates['gender'] = _gender;
          }
        });

        ref.read(registrationNotifierProvider.notifier).updateFields(updates);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.greenAccent),
                const SizedBox(width: 8),
                Text(isBackSide
                    ? 'Address captured and pre-filled!'
                    : 'ID details scanned and filled successfully!'),
              ],
            ),
            backgroundColor: const Color(0xFF1E293B),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (_) {
      // Even if OCR failed to read, the document is STILL validly attached!
      final fallbackUpdates = <String, dynamic>{
        if (isBackSide) ...{
          'govIdBackDataUrl': dataUrl,
          'govIdBackImageUrl': dataUrl,
          'govIdBackImagePath': dataUrl,
        } else ...{
          'govIdType': _selectedGovIdType.name,
          'govIdDataUrl': dataUrl,
          'govIdImageUrl': dataUrl,
          'govIdImagePath': dataUrl,
        },
      };
      ref.read(registrationNotifierProvider.notifier).updateFields(fallbackUpdates);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('ID document attached! Please confirm or enter your ID number below.'),
            backgroundColor: Color(0xFF1E293B),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isScanningId = false);
      }
    }
  }

  void _onNext() {
    if (!_formKey.currentState!.validate()) return;

    final customData = <String, String>{};
    for (final entry in _customControllers.entries) {
      customData[entry.key] = entry.value.text.trim();
    }

    ref.read(registrationNotifierProvider.notifier).updateFields({
      'name': _nameController.text.trim(),
      'fatherName': _fatherNameController.text.trim(),
      'dob': _dobController.text.trim(),
      'phone': _phoneController.text.trim(),
      'email': _emailController.text.trim(),
      'govIdType': _selectedGovIdType.name,           // fixed: was missing
      'govIdNumber': _idNumberController.text.trim(),
      'address': _addressController.text.trim(),
      'pincode': _pinCodeController.text.trim(),
      'college': _collegeController.text.trim(),
      'course': _courseController.text.trim(),
      'bloodGroup': _bloodGroupController.text.trim(),
      'rollNumber': _rollNumberController.text.trim(),
      'emergencyContact': _emergencyContactController.text.trim(),
      'year': _yearController.text.trim(),
      'prep': _prepController.text.trim(),
      'gender': _gender,
      'customFields': customData,
    });

    ref.read(registrationStepProvider.notifier).goTo(3);
  }

  // Builds a field with a green ✓ badge if it was auto-filled
  Widget _field({
    required TextEditingController controller,
    required String label,
    required String trackKey,
    IconData? icon,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
    int maxLines = 1,
    TextCapitalization capitalization = TextCapitalization.none,
    List<TextInputFormatter>? inputFormatters,
    String? helperText,
    String? hintText,
  }) {
    final isAutoFilled = _autoFilledKeys.contains(trackKey);
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      textCapitalization: capitalization,
      inputFormatters: inputFormatters,
      decoration: InputDecoration(
        labelText: label,
        helperText: helperText,
        hintText: hintText,
        prefixIcon: icon != null ? Icon(icon) : null,
        border: const OutlineInputBorder(),
        suffixIcon: isAutoFilled
            ? Tooltip(
                message: 'Auto-filled from ID scan',
                child: Icon(Icons.verified_rounded,
                    color: Colors.green.shade600, size: 20),
              )
            : null,
        enabledBorder: isAutoFilled
            ? OutlineInputBorder(
                borderSide:
                    BorderSide(color: Colors.green.shade400, width: 1.5),
              )
            : null,
      ),
      validator: validator,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final autoCount = _autoFilledKeys.length;
    final hasOcr = autoCount > 0;

    return Scaffold(
      appBar: AppBar(title: const Text('Review Registration Details')),
      body: Column(
        children: [
          const LinearProgressIndicator(value: 2 / 5),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: MediaQuery.of(context).size.width < 380 ? 16.0 : 24.0,
                vertical: 20.0,
              ),
              child: Form(
                key: _formKey,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Auto-fill banner
                    if (hasOcr) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 20),
                        decoration: BoxDecoration(
                          color: const Color(0xFFECFDF5),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFF10B981)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle_rounded,
                                color: Color(0xFF10B981)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '$autoCount field${autoCount == 1 ? '' : 's'} auto-filled from your ID scan (shown with ✓). '
                                'Please verify and fill any missing fields below.',
                                style: const TextStyle(
                                    color: Color(0xFF065F46),
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    // ── Personal Info ──────────────────────────────────────
                    _sectionHeader(theme, 'Personal Information'),
                    const SizedBox(height: 12),

                    _field(
                      controller: _nameController,
                      label: 'Full Name *',
                      hintText: 'e.g. Rahul Sharma',
                      helperText: 'Full legal name as shown on Government ID',
                      trackKey: 'name',
                      icon: Icons.person_rounded,
                      capitalization: TextCapitalization.words,
                      validator: (v) => AppValidators.name(v, label: 'Full Name'),
                    ),
                    if (FirebaseAuth.instance.currentUser?.displayName != null &&
                        _nameController.text.trim().isNotEmpty &&
                        _nameController.text.trim().toLowerCase() !=
                            FirebaseAuth.instance.currentUser!.displayName!.trim().toLowerCase() &&
                        _autoFilledKeys.contains('name')) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFBFDBFE)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline_rounded, size: 16, color: Color(0xFF1D4ED8)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Using legal name from ID for official library pass (Google: ${FirebaseAuth.instance.currentUser!.displayName})',
                                style: const TextStyle(fontSize: 11.5, color: Color(0xFF1E40AF), fontWeight: FontWeight.w500),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),

                    if (_isFieldVisible('fatherName')) ...[
                      _field(
                        controller: _fatherNameController,
                        label: _label('fatherName', "Father's / Guardian's Name"),
                        hintText: "e.g. Suresh Sharma",
                        helperText: "Father or legal guardian's name",
                        trackKey: 'fatherName',
                        icon: Icons.family_restroom_rounded,
                        capitalization: TextCapitalization.words,
                        validator: (v) => AppValidators.name(
                          v,
                          required: _isFieldRequired('fatherName'),
                          label: "Father's / Guardian's Name",
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],

                    // DOB + Gender (stacked on phone, row on desktop)
                    if (_isFieldVisible('dob') || _isFieldVisible('gender')) ...[
                      if (MediaQuery.of(context).size.width < 600) ...[
                        if (_isFieldVisible('dob')) ...[
                          GestureDetector(
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: DateTime(2000, 1, 1),
                                firstDate: DateTime(1940),
                                lastDate: DateTime.now().subtract(const Duration(days: 365 * 4)),
                              );
                              if (picked != null && mounted) {
                                setState(() {
                                  _dobController.text = '${picked.day.toString().padLeft(2,'0')}/${picked.month.toString().padLeft(2,'0')}/${picked.year}';
                                  _autoFilledKeys.remove('dob');
                                });
                              }
                            },
                            child: AbsorbPointer(
                              child: TextFormField(
                                controller: _dobController,
                                decoration: InputDecoration(
                                  labelText: 'Date of Birth',
                                  prefixIcon: const Icon(Icons.cake_rounded),
                                  border: const OutlineInputBorder(),
                                  suffixIcon: _autoFilledKeys.contains('dob')
                                      ? Icon(Icons.verified_rounded, color: Colors.green.shade600, size: 20)
                                      : const Icon(Icons.calendar_today_outlined, size: 18),
                                  enabledBorder: _autoFilledKeys.contains('dob')
                                      ? OutlineInputBorder(borderSide: BorderSide(color: Colors.green.shade300, width: 1.5))
                                      : null,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                        ],
                        if (_isFieldVisible('gender')) ...[
                          DropdownButtonFormField<String>(
                            initialValue: _gender,
                            decoration: const InputDecoration(
                              labelText: 'Gender *',
                              prefixIcon: Icon(Icons.people_outline_rounded),
                              border: OutlineInputBorder(),
                            ),
                            items: const [
                              DropdownMenuItem(value: 'male', child: Text('Male')),
                              DropdownMenuItem(value: 'female', child: Text('Female')),
                              DropdownMenuItem(value: 'other', child: Text('Other')),
                            ],
                            onChanged: (v) {
                              if (v != null) setState(() => _gender = v);
                            },
                          ),
                          const SizedBox(height: 14),
                        ],
                      ] else ...[
                        Row(
                          children: [
                            if (_isFieldVisible('dob'))
                              Expanded(
                                child: GestureDetector(
                                  onTap: () async {
                                    final picked = await showDatePicker(
                                      context: context,
                                      initialDate: DateTime(2000, 1, 1),
                                      firstDate: DateTime(1940),
                                      lastDate: DateTime.now().subtract(const Duration(days: 365 * 4)),
                                    );
                                    if (picked != null && mounted) {
                                      setState(() {
                                        _dobController.text = '${picked.day.toString().padLeft(2,'0')}/${picked.month.toString().padLeft(2,'0')}/${picked.year}';
                                        _autoFilledKeys.remove('dob');
                                      });
                                    }
                                  },
                                  child: AbsorbPointer(
                                    child: TextFormField(
                                      controller: _dobController,
                                      decoration: InputDecoration(
                                        labelText: 'Date of Birth',
                                        prefixIcon: const Icon(Icons.cake_rounded),
                                        border: const OutlineInputBorder(),
                                        suffixIcon: _autoFilledKeys.contains('dob')
                                            ? Icon(Icons.verified_rounded, color: Colors.green.shade600, size: 20)
                                            : const Icon(Icons.calendar_today_outlined, size: 18),
                                        enabledBorder: _autoFilledKeys.contains('dob')
                                            ? OutlineInputBorder(borderSide: BorderSide(color: Colors.green.shade300, width: 1.5))
                                            : null,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            if (_isFieldVisible('dob') && _isFieldVisible('gender'))
                              const SizedBox(width: 12),
                            if (_isFieldVisible('gender'))
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  initialValue: _gender,
                                  decoration: const InputDecoration(
                                    labelText: 'Gender *',
                                    prefixIcon: Icon(Icons.people_outline_rounded),
                                    border: OutlineInputBorder(),
                                  ),
                                  items: const [
                                    DropdownMenuItem(
                                        value: 'male', child: Text('Male')),
                                    DropdownMenuItem(
                                        value: 'female', child: Text('Female')),
                                    DropdownMenuItem(
                                        value: 'other', child: Text('Other')),
                                  ],
                                  onChanged: (v) {
                                    if (v != null) setState(() => _gender = v);
                                  },
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 14),
                      ],
                    ],
                    if (_isFieldVisible('gender')) ...[
                      Container(
                        margin: const EdgeInsets.only(bottom: 14),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                        decoration: BoxDecoration(
                          color: (_gender == 'male' ? const Color(0xFFEFF6FF) : const Color(0xFFFDF2F8)),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: (_gender == 'male' ? const Color(0xFFBFDBFE) : const Color(0xFFFBCFE8)),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _gender == 'male' ? Icons.male_rounded : Icons.female_rounded,
                              size: 16,
                              color: _gender == 'male' ? const Color(0xFF2563EB) : const Color(0xFFDB2777),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _gender == 'male'
                                    ? 'Desk Allocation Info: Desks 1 to 50 are assigned for Boys. Desks 51 to 60 are reserved for Girls.'
                                    : 'Desk Allocation Info: Desks 51 to 60 are dedicated quiet desks for Girls (near road-facing windows).',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: _gender == 'male' ? const Color(0xFF1E40AF) : const Color(0xFF9D174D),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    // Blood Group
                    if (_isFieldVisible('bloodGroup')) ...[
                      DropdownButtonFormField<String>(
                        initialValue: _bloodGroupController.text.isNotEmpty ? _bloodGroupController.text : null,
                        decoration: const InputDecoration(
                          labelText: 'Blood Group',
                          prefixIcon: Icon(Icons.bloodtype_rounded),
                          border: OutlineInputBorder(),
                        ),
                        hint: const Text('Select Blood Group'),
                        items: const [
                          DropdownMenuItem(value: 'A+', child: Text('A+')),
                          DropdownMenuItem(value: 'A-', child: Text('A-')),
                          DropdownMenuItem(value: 'B+', child: Text('B+')),
                          DropdownMenuItem(value: 'B-', child: Text('B-')),
                          DropdownMenuItem(value: 'AB+', child: Text('AB+')),
                          DropdownMenuItem(value: 'AB-', child: Text('AB-')),
                          DropdownMenuItem(value: 'O+', child: Text('O+')),
                          DropdownMenuItem(value: 'O-', child: Text('O-')),
                        ],
                        onChanged: (v) {
                          if (v != null) setState(() => _bloodGroupController.text = v);
                        },
                      ),
                      const SizedBox(height: 14),
                    ],

                    // Category-aware custom fields for Personal Details
                    _buildCategoryCustomFields(FormFieldCategory.personal),

                    // ── Contact ────────────────────────────────────────────
                    _sectionHeader(theme, 'Contact'),
                    const SizedBox(height: 12),

                    _field(
                      controller: _phoneController,
                      label: 'Mobile Phone *',
                      hintText: 'e.g. 9823456789',
                      helperText: '10-digit number for WhatsApp updates & admission alerts',
                      trackKey: 'phone',
                      icon: Icons.phone_android_rounded,
                      keyboardType: TextInputType.phone,
                      inputFormatters: AppValidators.phoneFormatters,
                      validator: (v) => AppValidators.phone(v, label: 'Phone number'),
                    ),
                    if (_isFieldVisible('email')) ...[
                      const SizedBox(height: 14),
                      _field(
                        controller: _emailController,
                        label: _isFieldRequired('email') ? 'Email Address *' : 'Email Address',
                        hintText: 'e.g. student@gmail.com',
                        helperText: 'For digital receipts, renewal reminders & approval updates',
                        trackKey: 'email',
                        icon: Icons.email_outlined,
                        keyboardType: TextInputType.emailAddress,
                        validator: (v) => AppValidators.email(
                          v,
                          required: _isFieldRequired('email'),
                        ),
                      ),
                    ],
                    if (_isFieldVisible('emergencyContact')) ...[
                      const SizedBox(height: 14),
                      _field(
                        controller: _emergencyContactController,
                        label: _label('emergencyContact', 'Emergency Contact Number'),
                        hintText: 'e.g. 9876543210',
                        helperText: 'Parents or family emergency contact number',
                        trackKey: 'emergencyContact',
                        icon: Icons.emergency_rounded,
                        keyboardType: TextInputType.phone,
                        inputFormatters: AppValidators.phoneFormatters,
                        validator: (v) => AppValidators.emergencyPhone(
                          v,
                          primaryPhone: _phoneController.text,
                          required: _isFieldRequired('emergencyContact'),
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),

                    // ── ID Details ─────────────────────────────────────────
                    if (_isFieldVisible('govId')) ...[
                      _sectionHeader(theme, 'Government ID Verification'),
                      const SizedBox(height: 12),

                      DropdownButtonFormField<GovIdType>(
                        initialValue: _selectedGovIdType,
                        decoration: const InputDecoration(
                          labelText: 'Government ID Type *',
                          prefixIcon: Icon(Icons.badge_rounded),
                          border: OutlineInputBorder(),
                        ),
                        items: GovIdType.values.map((t) => DropdownMenuItem(
                          value: t,
                          child: Text(t.displayName),
                        )).toList(),
                        onChanged: (v) {
                          if (v != null) {
                            setState(() {
                              _selectedGovIdType = v;
                              _idNumberController.text = GovIdValidator.format(v, _idNumberController.text);
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 14),

                      _field(
                        controller: _idNumberController,
                        label: _isFieldRequired('govId')
                            ? '${_selectedGovIdType.displayName} Number *'
                            : '${_selectedGovIdType.displayName} Number',
                        trackKey: 'govIdNumber',
                        hintText: _selectedGovIdType.placeholder,
                        helperText: _selectedGovIdType.helperText,
                        icon: Icons.credit_card_rounded,
                        capitalization: GovIdValidator.textCapitalization(_selectedGovIdType),
                        keyboardType: GovIdValidator.keyboardType(_selectedGovIdType),
                        inputFormatters: GovIdValidator.inputFormatters(_selectedGovIdType),
                        validator: (v) => GovIdValidator.validate(
                          _selectedGovIdType,
                          v,
                          isRequired: _isFieldRequired('govId'),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Single-Upload Document Attachment Section
                      Builder(
                        builder: (context) {
                          final regData = ref.watch(registrationNotifierProvider);
                          final frontUrl = (regData['govIdImageUrl'] ?? regData['govIdDataUrl'] ?? '').toString();
                          final backUrl = (regData['govIdBackImageUrl'] ?? regData['govIdBackDataUrl'] ?? '').toString();
                          final hasFront = frontUrl.isNotEmpty;
                          final hasBack = backUrl.isNotEmpty;
                          final hasTwoSides = _selectedGovIdType == GovIdType.aadhaar ||
                              _selectedGovIdType == GovIdType.drivingLicence ||
                              _selectedGovIdType == GovIdType.voterId ||
                              _selectedGovIdType == GovIdType.passport;

                          if (_isScanningId) {
                            return Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primaryContainer.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.3)),
                              ),
                              child: Row(
                                children: [
                                  const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(strokeWidth: 2.5),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Text(
                                      _scanStatusMessage.isNotEmpty
                                          ? _scanStatusMessage
                                          : 'Analyzing document...',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: theme.colorScheme.primary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }

                          if (hasFront) {
                            return Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: const Color(0xFFECFDF5),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: const Color(0xFFA7F3D0), width: 1.5),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.verified_rounded, color: Color(0xFF059669), size: 20),
                                      const SizedBox(width: 8),
                                      const Expanded(
                                        child: Text(
                                          'ID Document Attached (Single-Upload Verified)',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13.5,
                                            color: Color(0xFF065F46),
                                          ),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFD1FAE5),
                                          borderRadius: BorderRadius.circular(9999),
                                        ),
                                        child: Text(
                                          _selectedGovIdType.displayName,
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF047857),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  const Text(
                                    'Securely encrypted and stored. You do not need to re-upload your ID in any subsequent step.',
                                    style: TextStyle(fontSize: 12, color: Color(0xFF047857), height: 1.3),
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      // Front thumbnail
                                      GestureDetector(
                                        onTap: () => ImageService.showImageViewer(context, imageUrl: frontUrl, title: 'Front ID Preview'),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(10),
                                          child: Stack(
                                            children: [
                                              DocumentPickerService.isPdf(frontUrl)
                                                   ? Container(
                                                       width: 84,
                                                       height: 56,
                                                       decoration: BoxDecoration(
                                                         color: const Color(0xFFFEF2F2),
                                                         borderRadius: BorderRadius.circular(10),
                                                         border: Border.all(color: const Color(0xFFFECACA)),
                                                       ),
                                                       child: const Center(
                                                         child: Column(
                                                           mainAxisSize: MainAxisSize.min,
                                                           children: [
                                                             Icon(Icons.picture_as_pdf_rounded, color: Colors.red, size: 22),
                                                             Text('PDF', style: TextStyle(color: Colors.red, fontSize: 9, fontWeight: FontWeight.bold)),
                                                           ],
                                                         ),
                                                       ),
                                                     )
                                                   : ImageService.buildImageWidget(frontUrl, width: 84, height: 56),
                                              Positioned(
                                                bottom: 2,
                                                left: 2,
                                                child: Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                                  decoration: BoxDecoration(
                                                    color: Colors.black.withValues(alpha: 0.65),
                                                    borderRadius: BorderRadius.circular(4),
                                                  ),
                                                  child: const Text(
                                                    'FRONT',
                                                    style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      if (hasBack) ...[
                                        const SizedBox(width: 10),
                                        GestureDetector(
                                          onTap: () => ImageService.showImageViewer(context, imageUrl: backUrl, title: 'Back ID Preview'),
                                          child: ClipRRect(
                                            borderRadius: BorderRadius.circular(10),
                                            child: Stack(
                                              children: [
                                                DocumentPickerService.isPdf(backUrl)
                                                   ? Container(
                                                       width: 84,
                                                       height: 56,
                                                       decoration: BoxDecoration(
                                                         color: const Color(0xFFFEF2F2),
                                                         borderRadius: BorderRadius.circular(10),
                                                         border: Border.all(color: const Color(0xFFFECACA)),
                                                       ),
                                                       child: const Center(
                                                         child: Column(
                                                           mainAxisSize: MainAxisSize.min,
                                                           children: [
                                                             Icon(Icons.picture_as_pdf_rounded, color: Colors.red, size: 22),
                                                             Text('PDF', style: TextStyle(color: Colors.red, fontSize: 9, fontWeight: FontWeight.bold)),
                                                           ],
                                                         ),
                                                       ),
                                                     )
                                                   : ImageService.buildImageWidget(backUrl, width: 84, height: 56),
                                                Positioned(
                                                  bottom: 2,
                                                  left: 2,
                                                  child: Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                                    decoration: BoxDecoration(
                                                      color: Colors.black.withValues(alpha: 0.65),
                                                      borderRadius: BorderRadius.circular(4),
                                                    ),
                                                    child: const Text(
                                                      'BACK',
                                                      style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                      const Spacer(),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          OutlinedButton.icon(
                                            style: OutlinedButton.styleFrom(
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                              visualDensity: VisualDensity.compact,
                                              foregroundColor: const Color(0xFF047857),
                                              side: const BorderSide(color: Color(0xFF059669)),
                                            ),
                                            onPressed: () => _pickSourceAndScan(isBack: false),
                                            icon: const Icon(Icons.refresh_rounded, size: 16),
                                            label: const Text('Replace ID', style: TextStyle(fontSize: 12)),
                                          ),
                                          if (hasTwoSides && !hasBack) ...[
                                            const SizedBox(height: 6),
                                            TextButton.icon(
                                              style: TextButton.styleFrom(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                visualDensity: VisualDensity.compact,
                                                foregroundColor: const Color(0xFF047857),
                                              ),
                                              onPressed: () => _pickSourceAndScan(isBack: true),
                                              icon: const Icon(Icons.add_photo_alternate_outlined, size: 15),
                                              label: const Text('+ Add Back Side', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          }

                          // Unattached: Show intuitive Scan/Attach box
                          return Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: theme.dividerColor.withValues(alpha: 0.35),
                                width: 1.2,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 18,
                                      backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.12),
                                      child: Icon(Icons.document_scanner_rounded, size: 20, color: theme.colorScheme.primary),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Builder(
                                            builder: (_) {
                                              final typeName = _selectedGovIdType.displayName;
                                              final cleanLabel = typeName.toLowerCase().contains('card') || typeName.toLowerCase().contains('id')
                                                  ? 'Attach $typeName'
                                                  : 'Attach $typeName Card';
                                              return Text(
                                                cleanLabel,
                                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                                              );
                                            },
                                          ),
                                          Text(
                                            'Single upload: Auto-fills details & attaches proof',
                                            style: TextStyle(fontSize: 11.5, color: theme.colorScheme.onSurfaceVariant),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        style: OutlinedButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(vertical: 10),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                        ),
                                        onPressed: () => _scanOrAttachGovId(ImageSource.camera),
                                        icon: const Icon(Icons.camera_alt_rounded, size: 18),
                                        label: const Text('Take Photo', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        style: OutlinedButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(vertical: 10),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                        ),
                                        onPressed: () => _scanOrAttachGovId(ImageSource.gallery),
                                        icon: const Icon(Icons.upload_file_rounded, size: 18),
                                        label: const Text('Upload File', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 14),
                      // Category-aware custom fields for Government ID & KYC
                      _buildCategoryCustomFields(FormFieldCategory.govId),
                      const SizedBox(height: 10),
                    ],

                    // ── Address ────────────────────────────────────────────
                    if (_isFieldVisible('address')) ...[
                      _sectionHeader(theme, 'Address Details'),
                      const SizedBox(height: 12),

                      _field(
                        controller: _addressController,
                        label: _isFieldRequired('address') ? 'Address *' : 'Address',
                        hintText: 'e.g. Near Bus Stand, Station Road, Parli',
                        helperText: 'Permanent or current hostel/PG residential address',
                        trackKey: 'address',
                        icon: Icons.home_outlined,
                        maxLines: 2,
                        validator: (v) => AppValidators.address(
                          v,
                          required: _isFieldRequired('address'),
                        ),
                      ),
                      if (_isFieldVisible('pincode') || _isFieldVisible('pinCode')) ...[
                        const SizedBox(height: 14),
                        _field(
                          controller: _pinCodeController,
                          label: (_isFieldRequired('pincode') || _isFieldRequired('pinCode')) ? 'PIN Code *' : 'PIN Code',
                          hintText: 'e.g. 431515',
                          helperText: '6-digit area postal PIN code',
                          trackKey: 'pinCode',
                          icon: Icons.pin_drop_outlined,
                          keyboardType: TextInputType.number,
                          inputFormatters: AppValidators.pincodeFormatters,
                          validator: (v) => AppValidators.pinCode(
                            v,
                            required: _isFieldRequired('pincode') || _isFieldRequired('pinCode'),
                          ),
                        ),
                      ],
                      const SizedBox(height: 14),
                      // Category-aware custom fields for Contact & Residence
                      _buildCategoryCustomFields(FormFieldCategory.contact),
                      const SizedBox(height: 10),
                    ],

                    // ── Academic & Competitive Goals ─────────────────────────
                    if (_isFieldVisible('prep') || _isFieldVisible('college') || _isFieldVisible('course') || _isFieldVisible('year') || _isFieldVisible('rollNumber')) ...[
                      _sectionHeader(theme, 'Academic & Competitive Goals'),
                      const SizedBox(height: 12),

                      if (_isFieldVisible('prep')) ...[
                        _field(
                          controller: _prepController,
                          label: _label('prep', 'Exam / Target Course'),
                          hintText: 'e.g. MPSC, UPSC, NEET, JEE, Banking, RTO, CA',
                          helperText: 'Competitive exam or study target',
                          trackKey: 'prep',
                          icon: Icons.military_tech_rounded,
                          validator: _requiredValidator('prep'),
                        ),
                        const SizedBox(height: 14),
                      ],

                      if (_isFieldVisible('college') || _isFieldVisible('course')) ...[
                        if (MediaQuery.of(context).size.width < 600) ...[
                          if (_isFieldVisible('college')) ...[
                            _field(
                              controller: _collegeController,
                              label: _label('college', 'College / Institute'),
                              hintText: 'e.g. Govt Degree College',
                              helperText: 'Current College or University',
                              trackKey: 'college',
                              icon: Icons.school_outlined,
                              validator: _requiredValidator('college'),
                            ),
                            const SizedBox(height: 14),
                          ],
                          if (_isFieldVisible('course')) ...[
                            _field(
                              controller: _courseController,
                              label: _label('course', 'Course / Degree'),
                              hintText: 'e.g. B.Sc, B.Tech, MBA',
                              helperText: 'Current Degree or Branch',
                              trackKey: 'course',
                              icon: Icons.menu_book_outlined,
                              validator: _requiredValidator('course'),
                            ),
                            const SizedBox(height: 14),
                          ],
                        ] else ...[
                          Row(
                            children: [
                              if (_isFieldVisible('college'))
                                Expanded(
                                  child: _field(
                                    controller: _collegeController,
                                    label: _label('college', 'College / Institute'),
                                    hintText: 'e.g. Govt Degree College',
                                    helperText: 'Current College or University',
                                    trackKey: 'college',
                                    icon: Icons.school_outlined,
                                    validator: _requiredValidator('college'),
                                  ),
                                ),
                              if (_isFieldVisible('college') && _isFieldVisible('course'))
                                const SizedBox(width: 12),
                              if (_isFieldVisible('course'))
                                Expanded(
                                  child: _field(
                                    controller: _courseController,
                                    label: _label('course', 'Course / Degree'),
                                    hintText: 'e.g. B.Sc, B.Tech, MBA',
                                    helperText: 'Current Degree or Branch',
                                    trackKey: 'course',
                                    icon: Icons.menu_book_outlined,
                                    validator: _requiredValidator('course'),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 14),
                        ],
                      ],

                      if (_isFieldVisible('year') || _isFieldVisible('rollNumber')) ...[
                        if (MediaQuery.of(context).size.width < 600) ...[
                          if (_isFieldVisible('year')) ...[
                            _field(
                              controller: _yearController,
                              label: _label('year', 'Study Year / Semester'),
                              hintText: 'e.g. 2nd Year / 4th Sem',
                              helperText: 'Academic year of study',
                              trackKey: 'year',
                              icon: Icons.calendar_today_outlined,
                              validator: _requiredValidator('year'),
                            ),
                            const SizedBox(height: 14),
                          ],
                          if (_isFieldVisible('rollNumber')) ...[
                            _field(
                              controller: _rollNumberController,
                              label: _label('rollNumber', 'Roll / Enroll No.'),
                              hintText: 'e.g. 2024-ME-042',
                              helperText: 'College roll / ID',
                              trackKey: 'rollNumber',
                              icon: Icons.badge_outlined,
                              validator: _requiredValidator('rollNumber'),
                            ),
                            const SizedBox(height: 14),
                          ],
                        ] else ...[
                          Row(
                            children: [
                              if (_isFieldVisible('year'))
                                Expanded(
                                  child: _field(
                                    controller: _yearController,
                                    label: _label('year', 'Study Year / Semester'),
                                    hintText: 'e.g. 2nd Year / 4th Sem',
                                    helperText: 'Academic year of study',
                                    trackKey: 'year',
                                    icon: Icons.calendar_today_outlined,
                                    validator: _requiredValidator('year'),
                                  ),
                                ),
                              if (_isFieldVisible('year') && _isFieldVisible('rollNumber'))
                                const SizedBox(width: 12),
                              if (_isFieldVisible('rollNumber'))
                                Expanded(
                                  child: _field(
                                    controller: _rollNumberController,
                                    label: _label('rollNumber', 'Roll / Enroll No.'),
                                    hintText: 'e.g. 2024-ME-042',
                                    helperText: 'College roll / ID',
                                    trackKey: 'rollNumber',
                                    icon: Icons.badge_outlined,
                                    validator: _requiredValidator('rollNumber'),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 14),
                        ],
                      ],
                      const SizedBox(height: 14),
                      // Category-aware custom fields for Academic & Competitive Goals
                      _buildCategoryCustomFields(FormFieldCategory.academics),
                      const SizedBox(height: 10),
                    ],

                    // Custom & Additional Fields (Category: custom)
                    _buildCategoryCustomFields(FormFieldCategory.custom, showSectionHeader: true, theme: theme),

                    const SizedBox(height: 32),

                    // Navigation buttons (Responsive layout)
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final screenWidth = MediaQuery.of(context).size.width;
                        final isSmallPhone = constraints.maxWidth < 360 || screenWidth < 380;
                        if (isSmallPhone) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              FilledButton(
                                onPressed: _onNext,
                                style: FilledButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                ),
                                child: const Text('Next: Profile Photo ➔'),
                              ),
                              const SizedBox(height: 10),
                              OutlinedButton(
                                onPressed: () =>
                                    ref.read(registrationStepProvider.notifier).goTo(1),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                ),
                                child: const Text('Back'),
                              ),
                            ],
                          );
                        }
                        return Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            OutlinedButton(
                              onPressed: () =>
                                  ref.read(registrationStepProvider.notifier).goTo(1),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 24, vertical: 14),
                              ),
                              child: const Text('Back'),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: FilledButton(
                                onPressed: _onNext,
                                style: FilledButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 20, vertical: 14),
                                ),
                                child: const Text(
                                  'Next: Profile Photo ➔',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(ThemeData theme, String title) {
    return Row(
      children: [
        Container(
          width: 14,
          height: 1,
          color: theme.colorScheme.outlineVariant,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Text(
            title,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Expanded(
          child: Divider(color: theme.colorScheme.outlineVariant, height: 1),
        ),
      ],
    );
  }
}
