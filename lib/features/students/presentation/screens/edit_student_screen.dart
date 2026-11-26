import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:study_library/core/providers/library_provider.dart';
import 'package:study_library/features/students/presentation/providers/student_providers.dart';
import 'package:study_library/models/student_model.dart';
import 'package:study_library/services/image_service.dart';
import 'package:study_library/core/security/encryption_service.dart';
import 'package:study_library/core/security/audit_logger.dart';
import 'package:study_library/core/utils/app_validators.dart';
import 'package:study_library/services/form_config_service.dart';
import 'package:study_library/core/utils/error_formatter.dart';
import 'package:study_library/core/validators/gov_id_validator.dart';
import 'package:study_library/core/widgets/dynamic_form_field_renderer.dart';
import 'package:study_library/core/widgets/id_card_scanner_dialog.dart';

class EditStudentScreen extends ConsumerStatefulWidget {
  final String studentId;
  const EditStudentScreen({super.key, required this.studentId});

  @override
  ConsumerState<EditStudentScreen> createState() => _EditStudentScreenState();
}

class _EditStudentScreenState extends ConsumerState<EditStudentScreen> {
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final _nameController = TextEditingController();
  final _fatherNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _addressController = TextEditingController();
  final _pincodeController = TextEditingController();
  final _collegeController = TextEditingController();
  final _courseController = TextEditingController();
  final _yearController = TextEditingController();
  final _emergencyController = TextEditingController();
  final _govIdNumberController = TextEditingController();
  final _notesController = TextEditingController();
  final _targetExamController = TextEditingController();
  final _rollNumberController = TextEditingController();

  // State
  Gender _gender = Gender.male;
  GovIdType _govIdType = GovIdType.aadhaar;
  MembershipStatus _membershipStatus = MembershipStatus.active;
  String? _bloodGroup;
  DateTime? _dob;
  DateTime? _admissionDate;
  File? _newPhoto;
  String _currentPhotoUrl = '';
  final Map<String, TextEditingController> _customControllers = {};
  bool _isLoading = true;
  bool _isSaving = false;
  String _savingMessage = 'Saving changes...';
  StudentModel? _originalStudent;

  @override
  void initState() {
    super.initState();
    final initialLibId = ref.read(currentLibraryIdProvider) ?? CurrentLibraryNotifier.defaultLibraryId;
    _loadStudent(overrideLibId: initialLibId);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _fatherNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _pincodeController.dispose();
    _collegeController.dispose();
    _courseController.dispose();
    _yearController.dispose();
    _emergencyController.dispose();
    _govIdNumberController.dispose();
    _notesController.dispose();
    _targetExamController.dispose();
    _rollNumberController.dispose();
    for (final c in _customControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _openOcrScanner() {
    IdCardScannerDialog.show(
      context,
      initialType: _govIdType,
      onScanned: (result) {
        setState(() {
          _govIdType = result.detectedType;
          if (result.name?.isNotEmpty == true) _nameController.text = result.name!;
          if (result.fatherName?.isNotEmpty == true) _fatherNameController.text = result.fatherName!;
          if (result.idNumber?.isNotEmpty == true) {
            _govIdNumberController.text = GovIdValidator.format(result.detectedType, result.idNumber!);
          }
          if (result.dob?.isNotEmpty == true) {
            try {
              final parts = result.dob!.split('/');
              if (parts.length == 3) {
                _dob = DateTime(int.parse(parts[2]), int.parse(parts[1]), int.parse(parts[0]));
              }
            } catch (_) {}
          }
          if (result.gender?.isNotEmpty == true) {
            final g = result.gender!.toLowerCase();
            if (g.contains('female')) {
              _gender = Gender.female;
            } else if (g.contains('male')) {
              _gender = Gender.male;
            } else {
              _gender = Gender.other;
            }
          }
          if (result.address?.isNotEmpty == true) _addressController.text = result.address!;
          if (result.pinCode?.isNotEmpty == true) _pincodeController.text = result.pinCode!;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result.isChecksumValid
                  ? 'ID Scanned & Verified (${result.detectedType.name.toUpperCase()})'
                  : 'ID Scanned with potential checksum discrepancy - please review',
            ),
            backgroundColor: result.isChecksumValid ? const Color(0xFF059669) : const Color(0xFFD97706),
          ),
        );
      },
    );
  }

  Future<void> _loadStudent({String? overrideLibId}) async {
    final libraryId = overrideLibId ?? ref.read(currentLibraryIdProvider) ?? CurrentLibraryNotifier.defaultLibraryId;
    if (libraryId.isEmpty || widget.studentId.isEmpty) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection('libraries')
          .doc(libraryId)
          .collection('students')
          .doc(widget.studentId)
          .get()
          .timeout(const Duration(seconds: 8));

      if (doc.exists && mounted) {
        final data = doc.data()!;
        final rawGovId = data['govIdNumber']?.toString() ?? '';
        final decryptedGovId = EncryptionService.safeDecryptGovId(rawGovId, libraryId);
        final s = StudentModel.fromJson({
          ...data,
          'id': doc.id,
          'govIdNumber': decryptedGovId,
        });
        _originalStudent = s;
        _nameController.text = s.name;
        _fatherNameController.text = s.fatherName;
        _phoneController.text = s.phone;
        _emailController.text = s.email;
        _addressController.text = s.address;
        _pincodeController.text = s.pincode;
        _collegeController.text = s.college;
        _courseController.text = s.course;
        _yearController.text = s.year;
        _emergencyController.text = s.emergencyContact;
        _govIdNumberController.text = s.govIdNumber;
        _notesController.text = s.notes ?? '';
        _targetExamController.text = s.targetExamName?.isNotEmpty == true
            ? s.targetExamName!
            : (s.customFields['prep']?.toString() ?? '');
        _rollNumberController.text = s.rollNumber?.isNotEmpty == true
            ? s.rollNumber!
            : (s.customFields['rollNumber']?.toString() ?? '');
        _gender = s.gender;
        _bloodGroup = s.bloodGroup;
        _govIdType = s.govIdType;
        _membershipStatus = s.membershipStatus;
        _dob = s.dob;
        _admissionDate = s.admissionDate ?? s.planStartDate ?? s.createdAt;
        _currentPhotoUrl = s.photoUrl;

        _customControllers.clear();
        for (final entry in s.customFields.entries) {
          if (!_isInternalKey(entry.key)) {
            _customControllers[entry.key] = TextEditingController(text: entry.value?.toString() ?? '');
          }
        }

        setState(() => _isLoading = false);
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickPhoto() async {
    final source = await ImageService.showSourcePicker(
      context,
      canRemove: _newPhoto != null || _currentPhotoUrl.isNotEmpty,
    );
    if (!mounted) return;

    if (source == null) {
      // Remove photo
      setState(() {
        _newPhoto = null;
        _currentPhotoUrl = '';
      });
      return;
    }

    final compressed = await ImageService.pickAndCompressImage(source: source);
    if (compressed != null && mounted) {
      setState(() => _newPhoto = compressed);
    }
  }

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dob ?? DateTime(now.year - 20, now.month, now.day),
      firstDate: DateTime(1950),
      lastDate: now,
      helpText: 'Select Date of Birth',
    );
    if (picked != null && mounted) {
      setState(() => _dob = picked);
    }
  }

  Future<void> _saveStudent() async {
    if (!_formKey.currentState!.validate() || _originalStudent == null) return;

    final libraryId = ref.read(currentLibraryIdProvider) ?? '';
    if (libraryId.isEmpty) return;

    final cleanedPhone = _phoneController.text.trim();
    final existingSnap = await FirebaseFirestore.instance
      .collection('libraries').doc(libraryId)
      .collection('students')
      .where('phone', isEqualTo: cleanedPhone)
      .limit(1)
      .get();

    if (existingSnap.docs.isNotEmpty && existingSnap.docs.first.id != widget.studentId) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('A student with this phone number already exists.'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    setState(() {
      _isSaving = true;
      _savingMessage = _newPhoto != null ? 'Uploading updated photo...' : 'Updating profile...';
    });

    try {
      String finalPhotoUrl = _currentPhotoUrl;
      if (_newPhoto != null) {
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final storagePath = 'libraries/$libraryId/students/photo_${widget.studentId}_$timestamp.jpg';
        try {
          finalPhotoUrl = await ImageService.uploadToStorage(
            file: _newPhoto!,
            path: storagePath,
          );
        } catch (e) {
          debugPrint('Photo upload error: $e');
        }
      }

      final updatedCustom = Map<String, dynamic>.from(_originalStudent!.customFields);
      for (final entry in _customControllers.entries) {
        updatedCustom[entry.key] = entry.value.text.trim();
      }

      final prepVal = _targetExamController.text.trim();
      final rollVal = _rollNumberController.text.trim();
      if (prepVal.isNotEmpty) {
        updatedCustom['prep'] = prepVal;
      } else {
        updatedCustom.remove('prep');
      }
      if (rollVal.isNotEmpty) {
        updatedCustom['rollNumber'] = rollVal;
      } else {
        updatedCustom.remove('rollNumber');
      }

      final updated = _originalStudent!.copyWith(
        name: _nameController.text.trim(),
        fatherName: _fatherNameController.text.trim(),
        phone: _phoneController.text.trim(),
        email: _emailController.text.trim(),
        address: _addressController.text.trim(),
        pincode: _pincodeController.text.trim(),
        college: _collegeController.text.trim(),
        course: _courseController.text.trim(),
        year: _yearController.text.trim(),
        emergencyContact: _emergencyController.text.trim(),
        govIdType: _govIdType,
        govIdNumber: _govIdNumberController.text.trim(),
        notes: _notesController.text.trim(),
        gender: _gender,
        dob: _dob,
        photoUrl: finalPhotoUrl,
        membershipStatus: _membershipStatus,
        bloodGroup: _bloodGroup,
        admissionDate: _admissionDate,
        targetExamName: prepVal.isNotEmpty ? prepVal : null,
        rollNumber: rollVal.isNotEmpty ? rollVal : null,
        customFields: updatedCustom,
        updatedAt: DateTime.now(),
      );

      final repo = ref.read(studentRepositoryProvider);
      await repo.updateStudent(libraryId, updated);

      AuditLogger().log(
        action: AuditAction.updated,
        entityType: AuditEntity.student,
        libraryId: libraryId,
        entityId: widget.studentId,
        details: {'name': _nameController.text.trim(), 'libraryId': libraryId},
      ).ignore();

      ref.invalidate(studentsStreamProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Student profile updated!'), backgroundColor: Colors.green),
        );
        if (context.canPop()) {
          context.pop();
        } else {
          context.go('/admin/students/${widget.studentId}');
        }
      }
    } catch (e) {
      if (mounted) {
        AppErrorFormatter.showErrorSnackBar(context, e, actionContext: 'student');
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<String?>(currentLibraryIdProvider, (previous, next) {
      if (next != null && next.isNotEmpty && (_originalStudent == null || next != previous)) {
        _loadStudent(overrideLibId: next);
      }
    });

    final theme = Theme.of(context);
    final formConfigAsync = ref.watch(formConfigStreamProvider);
    final fieldsList = formConfigAsync.value ?? FormConfigService.defaultBuiltinFields;
    syncCustomFieldControllers(fieldsList, _customControllers);

    bool isReq(String id) => FormConfigService.isFieldRequired(fieldsList, id);
    String fieldLabel(String id, String fallback) {
      final lbl = FormConfigService.getFieldLabel(fieldsList, id, fallback);
      return isReq(id) ? '$lbl *' : lbl;
    }

    void handleBack() {
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/admin/students/${widget.studentId}');
      }
    }

    Widget content;
    if (_isLoading) {
      content = Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: handleBack,
          ),
          title: const Text('Edit Student'),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    } else if (_originalStudent == null) {
      content = Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: handleBack,
          ),
          title: const Text('Edit Student'),
        ),
        body: const Center(child: Text('Student profile not found')),
      );
    } else {
      content = Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: handleBack,
          ),
          title: const Text('Edit Student'),
        actions: [
          TextButton.icon(
            onPressed: _isSaving ? null : _saveStudent,
            icon: const Icon(Icons.check_rounded),
            label: const Text('Save', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: _isSaving
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(_savingMessage),
                ],
              ),
            )
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Photo Avatar with Preview
                  Center(
                    child: Stack(
                      children: [
                        GestureDetector(
                          onTap: () {
                            if (_newPhoto != null) {
                              ImageService.showImageViewer(
                                context,
                                imageFile: _newPhoto,
                                title: _nameController.text,
                              );
                            } else if (_currentPhotoUrl.isNotEmpty) {
                              ImageService.showImageViewer(
                                context,
                                imageUrl: _currentPhotoUrl,
                                title: _nameController.text,
                              );
                            } else {
                              _pickPhoto();
                            }
                          },
                          child: CircleAvatar(
                            radius: 54,
                            backgroundColor: theme.colorScheme.primaryContainer,
                            backgroundImage: _newPhoto != null
                                ? FileImage(_newPhoto!)
                                : ImageService.getImageProvider(_currentPhotoUrl),
                            child: (_newPhoto == null && ImageService.getImageProvider(_currentPhotoUrl) == null)
                                ? Icon(Icons.person_rounded, size: 54, color: theme.colorScheme.onPrimaryContainer)
                                : null,
                          ),
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: InkWell(
                            onTap: _pickPhoto,
                            borderRadius: BorderRadius.circular(20),
                            child: CircleAvatar(
                              radius: 18,
                              backgroundColor: theme.colorScheme.primary,
                              child: Icon(Icons.camera_alt_rounded, size: 18, color: theme.colorScheme.onPrimary),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: TextButton(
                      onPressed: _pickPhoto,
                      child: Text(
                        (_newPhoto != null || _currentPhotoUrl.isNotEmpty)
                            ? 'Change Profile Photo'
                            : 'Upload Profile Photo',
                        style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Section 1: Personal Details
                  _buildSectionHeader(context, 'Personal Information', Icons.person_outline_rounded),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Full Name *',
                      prefixIcon: Icon(Icons.badge_outlined),
                      border: OutlineInputBorder(),
                    ),
                    textCapitalization: TextCapitalization.words,
                    validator: (v) => (v == null || v.trim().length < 2) ? 'Name is required' : null,
                  ),
                  const SizedBox(height: 12),
                  // Admission Date Picker
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _admissionDate ?? DateTime.now(),
                        firstDate: DateTime(2015),
                        lastDate: DateTime(2035),
                        helpText: 'SELECT ADMISSION / ENROLLMENT DATE',
                      );
                      if (picked != null) {
                        setState(() => _admissionDate = picked);
                      }
                    },
                    borderRadius: BorderRadius.circular(4),
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: 'Admission Date (Member Since)',
                        prefixIcon: const Icon(Icons.history_edu_rounded),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.calendar_month_rounded),
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: _admissionDate ?? DateTime.now(),
                              firstDate: DateTime(2015),
                              lastDate: DateTime(2035),
                              helpText: 'SELECT ADMISSION / ENROLLMENT DATE',
                            );
                            if (picked != null) {
                              setState(() => _admissionDate = picked);
                            }
                          },
                        ),
                        border: const OutlineInputBorder(),
                      ),
                      child: Text(
                        _admissionDate != null
                            ? DateFormat('dd MMMM yyyy').format(_admissionDate!)
                            : 'Not set (Defaults to enrollment date)',
                        style: TextStyle(
                          fontSize: 14,
                          color: _admissionDate != null
                              ? theme.colorScheme.onSurface
                              : theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (FormConfigService.isFieldVisible(fieldsList, 'fatherName')) ...[
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _fatherNameController,
                      decoration: InputDecoration(
                        labelText: fieldLabel('fatherName', "Father's / Guardian's Name"),
                        prefixIcon: const Icon(Icons.family_restroom_rounded),
                        border: const OutlineInputBorder(),
                      ),
                      textCapitalization: TextCapitalization.words,
                      validator: (v) => AppValidators.name(
                        v,
                        required: isReq('fatherName'),
                        label: FormConfigService.getFieldLabel(fieldsList, 'fatherName', "Father's / Guardian's Name"),
                      ),
                    ),
                  ],
                  if (FormConfigService.isFieldVisible(fieldsList, 'gender') ||
                      FormConfigService.isFieldVisible(fieldsList, 'dob')) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        if (FormConfigService.isFieldVisible(fieldsList, 'gender'))
                          Expanded(
                            child: DropdownButtonFormField<Gender>(
                              isExpanded: true,
                              initialValue: _gender,
                              decoration: InputDecoration(
                                labelText: fieldLabel('gender', 'Gender'),
                                prefixIcon: const Icon(Icons.people_outline_rounded),
                                border: const OutlineInputBorder(),
                              ),
                              items: const [
                                DropdownMenuItem(value: Gender.male, child: Text('Male')),
                                DropdownMenuItem(value: Gender.female, child: Text('Female')),
                                DropdownMenuItem(value: Gender.other, child: Text('Other')),
                              ],
                              onChanged: (v) {
                                if (v != null) setState(() => _gender = v);
                              },
                            ),
                          ),
                        if (FormConfigService.isFieldVisible(fieldsList, 'gender') &&
                            FormConfigService.isFieldVisible(fieldsList, 'dob'))
                          const SizedBox(width: 12),
                        if (FormConfigService.isFieldVisible(fieldsList, 'dob'))
                          Expanded(
                            child: FormField<DateTime>(
                              initialValue: _dob,
                              validator: (_) => isReq('dob') && _dob == null
                                  ? '${FormConfigService.getFieldLabel(fieldsList, 'dob', 'Date of Birth')} is required'
                                  : null,
                              builder: (state) => InkWell(
                                onTap: () async {
                                  await _pickDob();
                                  state.didChange(_dob);
                                },
                                child: InputDecorator(
                                  decoration: InputDecoration(
                                    labelText: fieldLabel('dob', 'Date of Birth'),
                                    prefixIcon: const Icon(Icons.cake_outlined),
                                    border: const OutlineInputBorder(),
                                    errorText: state.errorText,
                                  ),
                                  child: Text(
                                    _dob != null ? DateFormat('dd/MM/yyyy').format(_dob!) : 'DD/MM/YYYY',
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],

                  if (FormConfigService.isFieldVisible(fieldsList, 'bloodGroup')) ...[
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      initialValue: _bloodGroup,
                      decoration: InputDecoration(
                        labelText: fieldLabel('bloodGroup', 'Blood Group'),
                        prefixIcon: const Icon(Icons.bloodtype_rounded),
                        border: const OutlineInputBorder(),
                      ),
                      hint: const Text('Select Blood Group'),
                      validator: isReq('bloodGroup')
                          ? (v) => AppValidators.bloodGroup(v, required: true)
                          : null,
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
                      onChanged: (v) => setState(() => _bloodGroup = v),
                    ),
                  ],
                  const SizedBox(height: 12),
                  DynamicCategoryCustomFieldsSection(
                    fields: fieldsList,
                    category: FormFieldCategory.personal,
                    controllers: _customControllers,
                    onChanged: () => setState(() {}),
                  ),
                  DropdownButtonFormField<MembershipStatus>(
                    isExpanded: true,
                    initialValue: _membershipStatus,
                    itemHeight: 54.0,
                    decoration: const InputDecoration(
                      labelText: 'Membership Status',
                      prefixIcon: Icon(Icons.verified_user_outlined),
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    selectedItemBuilder: (context) {
                      return MembershipStatus.values.map((s) {
                        return _buildMembershipStatusBadge(s, isSelectedView: true);
                      }).toList();
                    },
                    items: MembershipStatus.values.map((s) {
                      return DropdownMenuItem(
                        value: s,
                        child: _buildMembershipStatusBadge(s, isSelectedView: false),
                      );
                    }).toList(),
                    onChanged: (v) {
                      if (v != null) setState(() => _membershipStatus = v);
                    },
                  ),

                  const SizedBox(height: 24),

                  // Section 2: Contact Details
                  _buildSectionHeader(context, 'Contact Information', Icons.phone_outlined),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _phoneController,
                    decoration: InputDecoration(
                      labelText: fieldLabel('phone', 'Mobile Number'),
                      prefixIcon: const Icon(Icons.phone_android_rounded),
                      border: const OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.phone,
                    validator: (v) => AppValidators.phone(
                      v,
                      label: FormConfigService.getFieldLabel(fieldsList, 'phone', 'Mobile Number'),
                    ),
                  ),
                  if (FormConfigService.isFieldVisible(fieldsList, 'email')) ...[
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _emailController,
                      decoration: InputDecoration(
                        labelText: fieldLabel('email', 'Email Address'),
                        prefixIcon: const Icon(Icons.email_outlined),
                        border: const OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.emailAddress,
                      validator: (v) => AppValidators.email(
                        v,
                        required: isReq('email'),
                        label: FormConfigService.getFieldLabel(fieldsList, 'email', 'Email Address'),
                      ),
                    ),
                  ],
                  if (FormConfigService.isFieldVisible(fieldsList, 'address')) ...[
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _addressController,
                      decoration: InputDecoration(
                        labelText: fieldLabel('address', 'Address'),
                        prefixIcon: const Icon(Icons.home_outlined),
                        border: const OutlineInputBorder(),
                      ),
                      maxLines: 2,
                      validator: (v) => AppValidators.address(
                        v,
                        required: isReq('address'),
                        label: FormConfigService.getFieldLabel(fieldsList, 'address', 'Address'),
                      ),
                    ),
                  ],
                  if (FormConfigService.isFieldVisible(fieldsList, 'pincode') ||
                      FormConfigService.isFieldVisible(fieldsList, 'emergencyContact')) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        if (FormConfigService.isFieldVisible(fieldsList, 'pincode'))
                          Expanded(
                            child: TextFormField(
                              controller: _pincodeController,
                              decoration: InputDecoration(
                                labelText: fieldLabel('pincode', 'Pincode'),
                                prefixIcon: const Icon(Icons.pin_drop_outlined),
                                border: const OutlineInputBorder(),
                              ),
                              keyboardType: TextInputType.number,
                              inputFormatters: AppValidators.pincodeFormatters,
                              validator: (v) => AppValidators.pinCode(
                                v,
                                required: isReq('pincode'),
                                label: FormConfigService.getFieldLabel(fieldsList, 'pincode', 'Pincode'),
                              ),
                            ),
                          ),
                        if (FormConfigService.isFieldVisible(fieldsList, 'pincode') &&
                            FormConfigService.isFieldVisible(fieldsList, 'emergencyContact'))
                          const SizedBox(width: 12),
                        if (FormConfigService.isFieldVisible(fieldsList, 'emergencyContact'))
                          Expanded(
                            child: TextFormField(
                              controller: _emergencyController,
                              decoration: InputDecoration(
                                labelText: fieldLabel('emergencyContact', 'Emergency Contact'),
                                prefixIcon: const Icon(Icons.contact_phone_outlined),
                                border: const OutlineInputBorder(),
                              ),
                              keyboardType: TextInputType.phone,
                              inputFormatters: AppValidators.phoneFormatters,
                              validator: (v) => AppValidators.emergencyPhone(
                                v,
                                primaryPhone: _phoneController.text,
                                required: isReq('emergencyContact'),
                                label: FormConfigService.getFieldLabel(fieldsList, 'emergencyContact', 'Emergency Contact'),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 12),
                  DynamicCategoryCustomFieldsSection(
                    fields: fieldsList,
                    category: FormFieldCategory.contact,
                    controllers: _customControllers,
                    onChanged: () => setState(() {}),
                  ),

                  if (FormConfigService.isFieldVisible(fieldsList, 'govId') ||
                      FormConfigService.getCustomFieldsForCategory(fieldsList, FormFieldCategory.govId).isNotEmpty) ...[
                    const SizedBox(height: 24),

                    // Section 3: Identity & Verification
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildSectionHeader(context, 'Identity Verification', Icons.school_outlined),
                        if (FormConfigService.isFieldVisible(fieldsList, 'govId'))
                          TextButton.icon(
                            onPressed: _openOcrScanner,
                            icon: const Icon(Icons.document_scanner_outlined, size: 18),
                            label: const Text('Scan ID Card'),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (FormConfigService.isFieldVisible(fieldsList, 'govId'))
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 2,
                            child: DropdownButtonFormField<GovIdType>(
                              isExpanded: true,
                              initialValue: _govIdType,
                              decoration: InputDecoration(
                                labelText: FormConfigService.getFieldLabel(fieldsList, 'govIdType', 'ID Type'),
                                border: const OutlineInputBorder(),
                              ),
                              items: GovIdType.values.map((t) => DropdownMenuItem(value: t, child: Text(t.displayName))).toList(),
                              onChanged: (v) {
                                if (v != null) {
                                  setState(() {
                                    _govIdType = v;
                                    _govIdNumberController.text = GovIdValidator.format(v, _govIdNumberController.text);
                                  });
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 3,
                            child: ValueListenableBuilder<TextEditingValue>(
                              valueListenable: _govIdNumberController,
                              builder: (context, val, child) {
                                final rawText = val.text.trim();
                                final isValid = rawText.isNotEmpty &&
                                    GovIdValidator.isValid(_govIdType, rawText);
                                final showWarning = rawText.isNotEmpty && !isValid;

                                return TextFormField(
                                  controller: _govIdNumberController,
                                  keyboardType: GovIdValidator.keyboardType(_govIdType),
                                  inputFormatters: GovIdValidator.inputFormatters(_govIdType),
                                  validator: (v) => GovIdValidator.validate(_govIdType, v, isRequired: isReq('govId')),
                                  decoration: InputDecoration(
                                    labelText: fieldLabel('govId', 'ID Number'),
                                    hintText: _govIdType.placeholder,
                                    border: const OutlineInputBorder(),
                                    suffixIcon: rawText.isEmpty
                                        ? null
                                        : isValid
                                            ? const Tooltip(
                                                message: 'Valid Checksum / Format Verified',
                                                child: Icon(Icons.verified_rounded, color: Color(0xFF059669), size: 20),
                                              )
                                            : showWarning
                                                ? const Tooltip(
                                                    message: 'Invalid format or checksum mismatch',
                                                    child: Icon(Icons.warning_amber_rounded, color: Color(0xFFD97706), size: 20),
                                                  )
                                                : null,
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    const SizedBox(height: 12),
                    DynamicCategoryCustomFieldsSection(
                      fields: fieldsList,
                      category: FormFieldCategory.govId,
                      controllers: _customControllers,
                      onChanged: () => setState(() {}),
                    ),
                  ],
                  if (FormConfigService.isFieldVisible(fieldsList, 'college')) ...[
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _collegeController,
                      decoration: InputDecoration(
                        labelText: fieldLabel('college', 'College / School'),
                        prefixIcon: const Icon(Icons.school),
                        border: const OutlineInputBorder(),
                      ),
                      validator: (v) => AppValidators.collegeName(v, required: isReq('college')),
                    ),
                  ],
                  if (FormConfigService.isFieldVisible(fieldsList, 'course') ||
                      FormConfigService.isFieldVisible(fieldsList, 'year')) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        if (FormConfigService.isFieldVisible(fieldsList, 'course'))
                          Expanded(
                            child: TextFormField(
                              controller: _courseController,
                              decoration: InputDecoration(
                                labelText: fieldLabel('course', 'Course / Degree'),
                                border: const OutlineInputBorder(),
                              ),
                              validator: isReq('course')
                                  ? (v) => AppValidators.required(
                                        v,
                                        label: FormConfigService.getFieldLabel(fieldsList, 'course', 'Course / Degree'),
                                      )
                                  : null,
                            ),
                          ),
                        if (FormConfigService.isFieldVisible(fieldsList, 'course') &&
                            FormConfigService.isFieldVisible(fieldsList, 'year'))
                          const SizedBox(width: 12),
                        if (FormConfigService.isFieldVisible(fieldsList, 'year'))
                          Expanded(
                            child: TextFormField(
                              controller: _yearController,
                              decoration: InputDecoration(
                                labelText: fieldLabel('year', 'Year / Semester'),
                                border: const OutlineInputBorder(),
                              ),
                              validator: (v) => AppValidators.yearOrSem(v, required: isReq('year')),
                            ),
                          ),
                      ],
                    ),
                  ],

                  if (FormConfigService.isFieldVisible(fieldsList, 'prep') ||
                      FormConfigService.isFieldVisible(fieldsList, 'rollNumber')) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        if (FormConfigService.isFieldVisible(fieldsList, 'prep'))
                          Expanded(
                            child: TextFormField(
                              controller: _targetExamController,
                              decoration: InputDecoration(
                                labelText: fieldLabel('prep', 'Target Exam / Competitive Goal'),
                                prefixIcon: const Icon(Icons.track_changes_rounded),
                                border: const OutlineInputBorder(),
                                hintText: 'e.g. RTO Exam, MPSC, UPSC, NEET',
                              ),
                              textCapitalization: TextCapitalization.words,
                              validator: isReq('prep')
                                  ? (v) => AppValidators.required(
                                        v,
                                        label: FormConfigService.getFieldLabel(fieldsList, 'prep', 'Target Exam'),
                                      )
                                  : null,
                            ),
                          ),
                        if (FormConfigService.isFieldVisible(fieldsList, 'prep') &&
                            FormConfigService.isFieldVisible(fieldsList, 'rollNumber'))
                          const SizedBox(width: 12),
                        if (FormConfigService.isFieldVisible(fieldsList, 'rollNumber'))
                          Expanded(
                            child: TextFormField(
                              controller: _rollNumberController,
                              decoration: InputDecoration(
                                labelText: fieldLabel('rollNumber', 'Roll / Enroll Number'),
                                prefixIcon: const Icon(Icons.badge_outlined),
                                border: const OutlineInputBorder(),
                              ),
                              validator: isReq('rollNumber')
                                  ? (v) => AppValidators.required(
                                        v,
                                        label: FormConfigService.getFieldLabel(fieldsList, 'rollNumber', 'Roll / Enroll Number'),
                                      )
                                  : null,
                            ),
                          ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 12),
                  DynamicCategoryCustomFieldsSection(
                    fields: fieldsList,
                    category: FormFieldCategory.academics,
                    controllers: _customControllers,
                    onChanged: () => setState(() {}),
                  ),

                  // Section 4: Admin Remarks & Notes (Always accessible for counter staff)
                  const SizedBox(height: 24),
                  _buildSectionHeader(context, 'Remarks & Notes', Icons.notes_rounded),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _notesController,
                    decoration: const InputDecoration(
                      labelText: 'Notes & Remarks',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 2,
                  ),

                  Builder(
                    builder: (context) {
                      final configuredCustom = FormConfigService.getCustomFieldsForCategory(
                        fieldsList,
                        FormFieldCategory.custom,
                      );
                      final configuredIds = fieldsList.map((f) => (f['id'] ?? '').toString()).toSet();
                      const builtinIds = {
                        'name', 'fatherName', 'gender', 'dob', 'bloodGroup',
                        'phone', 'email', 'emergencyContact', 'address', 'pincode', 'pinCode',
                        'govId', 'govIdType', 'govIdNumber',
                        'college', 'course', 'year', 'prep', 'rollNumber', 'notes'
                      };
                      final legacyOrphanKeys = _customControllers.keys.where((k) =>
                          !_isInternalKey(k) &&
                          !builtinIds.contains(k) &&
                          !configuredIds.contains(k)).toList();

                      if (configuredCustom.isEmpty && legacyOrphanKeys.isEmpty) {
                        return const SizedBox.shrink();
                      }

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 24),
                          _buildSectionHeader(context, 'Additional Information / Custom Fields', Icons.tune_rounded),
                          const SizedBox(height: 12),
                          DynamicCategoryCustomFieldsSection(
                            fields: fieldsList,
                            category: FormFieldCategory.custom,
                            controllers: _customControllers,
                            onChanged: () => setState(() {}),
                          ),
                          for (final fid in legacyOrphanKeys)
                            DynamicFormFieldRenderer(
                              field: {'id': fid, 'label': _formatFieldKey(fid), 'type': 'Text'},
                              controller: _customControllers[fid]!,
                              onChanged: () => setState(() {}),
                            ),
                        ],
                      );
                    },
                  ),

                  const SizedBox(height: 32),
                  FilledButton.icon(
                    onPressed: _saveStudent,
                    icon: const Icon(Icons.save_rounded),
                    label: const Text('Save Changes'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
      );
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        handleBack();
      },
      child: content,
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title, IconData icon) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 20, color: theme.colorScheme.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.primary,
          ),
        ),
      ],
    );
  }

  static bool _isInternalKey(String key) => FormConfigService.isInternalKey(key);

  static String _formatFieldKey(String key) => FormConfigService.formatFieldKey(key);

  Widget _buildMembershipStatusBadge(MembershipStatus status, {bool isSelectedView = false}) {
    final (Color color, IconData icon, String desc) = switch (status) {
      MembershipStatus.active => (
        const Color(0xFF10B981),
        Icons.check_circle_rounded,
        'Pass Active • Seat Locked • Entry Allowed'
      ),
      MembershipStatus.grace => (
        const Color(0xFFF59E0B),
        Icons.hourglass_top_rounded,
        'Within Grace Buffer • Seat Protected'
      ),
      MembershipStatus.expired => (
        const Color(0xFFEF4444),
        Icons.timer_off_rounded,
        'Pass Expired • Seat Released to Pool'
      ),
      MembershipStatus.pending => (
        const Color(0xFF6366F1),
        Icons.pending_actions_rounded,
        'New Applicant • Awaiting Fee / Seat'
      ),
      MembershipStatus.inactive => (
        const Color(0xFF6B7280),
        Icons.pause_circle_outline_rounded,
        'Past Member • Ready for Renewal'
      ),
      MembershipStatus.archived => (
        const Color(0xFF94A3B8),
        Icons.inventory_2_outlined,
        'Historical Record • Inactive History'
      ),
      MembershipStatus.blocked => (
        const Color(0xFFDC2626),
        Icons.block_rounded,
        'Access Denied • Turnstile Blocked'
      ),
    };

    if (isSelectedView) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: color.withValues(alpha: 0.4)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 14, color: color),
                const SizedBox(width: 5),
                Text(
                  status.name.toUpperCase(),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              desc,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  status.name.toUpperCase(),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: color,
                  ),
                ),
                Text(
                  desc,
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
