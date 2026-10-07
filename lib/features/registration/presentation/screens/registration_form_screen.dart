import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:study_library/core/providers/library_provider.dart';
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

  String _gender = 'male';
  String _selectedGovIdType = 'aadhaar';

  // Tracks which fields were auto-filled from OCR
  final Set<String> _autoFilledKeys = {};

  List<Map<String, dynamic>> _customFieldsConfig = [];
  final Map<String, TextEditingController> _customControllers = {};

  @override
  void initState() {
    super.initState();
    final reg = ref.read(registrationNotifierProvider);
    final ocr = ref.read(ocrResultProvider);

    String pick(String key) => reg[key]?.toString() ?? ocr[key]?.toString() ?? '';
    bool isFromOcr(String key) =>
        reg[key] == null && ocr[key] != null && ocr[key]!.isNotEmpty;
    bool isFromReg(String key) => reg[key] != null && reg[key].toString().isNotEmpty;

    void trackIfFilled(String key, String value) {
      if (value.isNotEmpty && (isFromOcr(key) || isFromReg(key))) {
        _autoFilledKeys.add(key);
      }
    }

    final nameVal = pick('name');
    _nameController = TextEditingController(text: nameVal);
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

    _emailController = TextEditingController(text: pick('email'));

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
    if (['pan', 'drivinglicence', 'collegeid'].contains(rawGovIdType)) {
      _selectedGovIdType = rawGovIdType == 'drivinglicence' ? 'drivingLicence' : rawGovIdType == 'collegeid' ? 'collegeId' : rawGovIdType;
    } else {
      _selectedGovIdType = 'aadhaar';
    }

    final emergencyVal = pick('emergencyContact');
    _emergencyContactController = TextEditingController(text: emergencyVal);
    trackIfFilled('emergencyContact', emergencyVal);

    final yearVal = pick('year');
    _yearController = TextEditingController(text: yearVal);
    trackIfFilled('year', yearVal);

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
    } catch (_) {}
  }

  bool _isFieldVisible(String fieldId) {
    if (_customFieldsConfig.isEmpty) return true;
    final match = _customFieldsConfig.where((f) => f['id'] == fieldId).firstOrNull;
    if (match != null) {
      return match['visible'] as bool? ?? true;
    }
    return true;
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
    for (final c in _customControllers.values) {
      c.dispose();
    }
    super.dispose();
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
      'govIdType': _selectedGovIdType,           // fixed: was missing
      'govIdNumber': _idNumberController.text.trim(),
      'address': _addressController.text.trim(),
      'pincode': _pinCodeController.text.trim(),
      'college': _collegeController.text.trim(),
      'course': _courseController.text.trim(),
      'bloodGroup': _bloodGroupController.text.trim(),
      'rollNumber': _rollNumberController.text.trim(),
      'emergencyContact': _emergencyContactController.text.trim(),
      'year': _yearController.text.trim(),
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
  }) {
    final isAutoFilled = _autoFilledKeys.contains(trackKey);
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      textCapitalization: capitalization,
      decoration: InputDecoration(
        labelText: label,
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
                    BorderSide(color: Colors.green.shade300, width: 1.5),
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
              padding: const EdgeInsets.all(24.0),
              child: Form(
                key: _formKey,
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
                      trackKey: 'name',
                      icon: Icons.person_rounded,
                      capitalization: TextCapitalization.words,
                      validator: (v) =>
                          (v == null || v.trim().length < 2) ? 'Name is required' : null,
                    ),
                    const SizedBox(height: 14),

                    if (_isFieldVisible('fatherName')) ...[
                      _field(
                        controller: _fatherNameController,
                        label: "Father's / Guardian's Name",
                        trackKey: 'fatherName',
                        icon: Icons.family_restroom_rounded,
                        capitalization: TextCapitalization.words,
                      ),
                      const SizedBox(height: 14),
                    ],

                    // DOB + Gender in a row
                    if (_isFieldVisible('dob') || _isFieldVisible('gender')) ...[
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

                    // Blood Group + Roll Number in a row
                    if (_isFieldVisible('bloodGroup') || _isFieldVisible('rollNumber')) ...[
                      Row(
                        children: [
                          if (_isFieldVisible('bloodGroup'))
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                initialValue: _bloodGroupController.text.isNotEmpty ? _bloodGroupController.text : null,
                                decoration: const InputDecoration(
                                  labelText: 'Blood Group',
                                  prefixIcon: Icon(Icons.bloodtype_rounded),
                                  border: OutlineInputBorder(),
                                ),
                                hint: const Text('Select'),
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
                            ),
                          if (_isFieldVisible('bloodGroup') && _isFieldVisible('rollNumber'))
                            const SizedBox(width: 12),
                          if (_isFieldVisible('rollNumber'))
                            Expanded(
                              child: _field(
                                controller: _rollNumberController,
                                label: 'Roll / Enroll No.',
                                trackKey: 'rollNumber',
                                icon: Icons.badge_outlined,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 24),
                    ],

                    // ── Contact ────────────────────────────────────────────
                    _sectionHeader(theme, 'Contact'),
                    const SizedBox(height: 12),

                    _field(
                      controller: _phoneController,
                      label: 'Mobile Phone *',
                      trackKey: 'phone',
                      icon: Icons.phone_android_rounded,
                      keyboardType: TextInputType.phone,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Phone number is required';
                        final digits = v.trim().replaceAll(RegExp(r'[^0-9]'), '');
                        if (digits.length != 10) return 'Must be exactly 10 digits';
                        if (!RegExp(r'^[6-9]').hasMatch(digits)) return 'Must start with 6, 7, 8, or 9';
                        return null;
                      },
                    ),
                    if (_isFieldVisible('email')) ...[
                      const SizedBox(height: 14),
                      _field(
                        controller: _emailController,
                        label: 'Email Address',
                        trackKey: 'email',
                        icon: Icons.email_outlined,
                        keyboardType: TextInputType.emailAddress,
                      ),
                    ],
                    if (_isFieldVisible('emergencyContact')) ...[
                      const SizedBox(height: 14),
                      _field(
                        controller: _emergencyContactController,
                        label: 'Emergency Contact Number',
                        trackKey: 'emergencyContact',
                        icon: Icons.emergency_rounded,
                        keyboardType: TextInputType.phone,
                      ),
                    ],
                    const SizedBox(height: 24),

                    // ── ID Details ─────────────────────────────────────────
                    if (_isFieldVisible('govId')) ...[
                      _sectionHeader(theme, 'ID Details'),
                      const SizedBox(height: 12),

                      _field(
                        controller: _idNumberController,
                        label: 'Government ID Number',
                        trackKey: 'govIdNumber',
                        icon: Icons.credit_card_rounded,
                        capitalization: (_selectedGovIdType == 'aadhaar')
                            ? TextCapitalization.none
                            : TextCapitalization.characters,
                        keyboardType: (_selectedGovIdType == 'aadhaar')
                            ? TextInputType.number
                            : TextInputType.text,
                      ),
                      const SizedBox(height: 24),
                    ],

                    // ── Address ────────────────────────────────────────────
                    if (_isFieldVisible('address')) ...[
                      _sectionHeader(theme, 'Address'),
                      const SizedBox(height: 12),

                      _field(
                        controller: _addressController,
                        label: 'Address',
                        trackKey: 'address',
                        icon: Icons.home_outlined,
                        maxLines: 2,
                      ),
                      const SizedBox(height: 14),

                      _field(
                        controller: _pinCodeController,
                        label: 'PIN Code',
                        trackKey: 'pinCode',
                        icon: Icons.pin_drop_outlined,
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 24),
                    ],

                    // ── Academic Info ──────────────────────────────────────
                    _sectionHeader(theme, 'Academic Information'),
                    const SizedBox(height: 12),

                    if (_isFieldVisible('college') || _isFieldVisible('course')) ...[
                      Row(
                        children: [
                          if (_isFieldVisible('college'))
                            Expanded(
                              child: _field(
                                controller: _collegeController,
                                label: 'College / Institute',
                                trackKey: 'college',
                                icon: Icons.school_outlined,
                              ),
                            ),
                          if (_isFieldVisible('college') && _isFieldVisible('course'))
                            const SizedBox(width: 12),
                          if (_isFieldVisible('course'))
                            Expanded(
                              child: _field(
                                controller: _courseController,
                                label: 'Course / Degree',
                                trackKey: 'course',
                                icon: Icons.menu_book_outlined,
                              ),
                            ),
                        ],
                      ),
                    ],
                    if (_isFieldVisible('year')) ...[
                      const SizedBox(height: 14),
                      _field(
                        controller: _yearController,
                        label: 'Study Year / Semester',
                        trackKey: 'year',
                        icon: Icons.school_outlined,
                      ),
                    ],

                    if (_customControllers.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _sectionHeader(theme, 'Additional Information'),
                      const SizedBox(height: 12),
                      ..._customFieldsConfig
                          .where((f) =>
                              (f['builtin'] as bool? ?? false) == false &&
                              (f['visible'] as bool? ?? true))
                          .map((f) {
                        final id = f['id'] as String? ?? '';
                        final label = f['label'] as String? ?? id;
                        final isRequired = f['required'] as bool? ?? false;
                        final ctrl = _customControllers[id];
                        if (ctrl == null) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 14.0),
                          child: TextFormField(
                            controller: ctrl,
                            decoration: InputDecoration(
                              labelText: '$label${isRequired ? ' *' : ''}',
                              border: const OutlineInputBorder(),
                            ),
                            validator: isRequired
                                ? (val) => (val == null || val.trim().isEmpty)
                                    ? '$label is required'
                                    : null
                                : null,
                          ),
                        );
                      }),
                    ],

                    const SizedBox(height: 32),

                    // Navigation buttons
                    Row(
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
                        FilledButton(
                          onPressed: _onNext,
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 32, vertical: 14),
                          ),
                          child: const Text('Next: Profile Photo ➔'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
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
        Expanded(
          child: Divider(color: theme.colorScheme.outlineVariant, height: 1),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            title,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ),
        Expanded(
          child: Divider(color: theme.colorScheme.outlineVariant, height: 1),
        ),
      ],
    );
  }
}
