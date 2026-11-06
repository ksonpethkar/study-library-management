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
import 'package:flutter/services.dart';
import 'package:study_library/core/utils/app_validators.dart';
import 'package:study_library/services/form_config_service.dart';
import 'package:study_library/core/utils/error_formatter.dart';

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

  // State
  Gender _gender = Gender.male;
  GovIdType _govIdType = GovIdType.aadhaar;
  MembershipStatus _membershipStatus = MembershipStatus.active;
  String? _bloodGroup;
  DateTime? _dob;
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
    for (final c in _customControllers.values) {
      c.dispose();
    }
    super.dispose();
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
        _gender = s.gender;
        _bloodGroup = s.bloodGroup;
        _govIdType = s.govIdType;
        _membershipStatus = s.membershipStatus;
        _dob = s.dob;
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

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/admin/students/${widget.studentId}');
              }
            },
          ),
          title: const Text('Edit Student'),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_originalStudent == null) {
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/admin/students/${widget.studentId}');
              }
            },
          ),
          title: const Text('Edit Student'),
        ),
        body: const Center(child: Text('Student profile not found')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/admin/students/${widget.studentId}');
            }
          },
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
                              child: const Icon(Icons.camera_alt_rounded, size: 18, color: Colors.white),
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
                  TextFormField(
                    controller: _fatherNameController,
                    decoration: const InputDecoration(
                      labelText: "Father's / Guardian's Name",
                      prefixIcon: Icon(Icons.family_restroom_rounded),
                      border: OutlineInputBorder(),
                    ),
                    textCapitalization: TextCapitalization.words,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<Gender>(
                                    isExpanded: true,
                                    initialValue: _gender,
                          decoration: const InputDecoration(
                            labelText: 'Gender *',
                            prefixIcon: Icon(Icons.people_outline_rounded),
                            border: OutlineInputBorder(),
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
                      const SizedBox(width: 12),
                      Expanded(
                        child: InkWell(
                          onTap: _pickDob,
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'Date of Birth',
                              prefixIcon: Icon(Icons.cake_outlined),
                              border: OutlineInputBorder(),
                            ),
                            child: Text(
                              _dob != null ? DateFormat('dd/MM/yyyy').format(_dob!) : 'DD/MM/YYYY',
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    initialValue: _bloodGroup,
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
                    onChanged: (v) => setState(() => _bloodGroup = v),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<MembershipStatus>(
                    isExpanded: true,
                    initialValue: _membershipStatus,
                    decoration: const InputDecoration(
                      labelText: 'Membership Status',
                      prefixIcon: Icon(Icons.verified_user_outlined),
                      border: OutlineInputBorder(),
                    ),
                    items: MembershipStatus.values.map((s) {
                      return DropdownMenuItem(
                        value: s,
                        child: Text(s.name.toUpperCase()),
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
                    decoration: const InputDecoration(
                      labelText: 'Mobile Number *',
                      prefixIcon: Icon(Icons.phone_android_rounded),
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.phone,
                    validator: (v) => (v == null || v.trim().length < 10) ? 'Valid phone required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _emailController,
                    decoration: const InputDecoration(
                      labelText: 'Email Address',
                      prefixIcon: Icon(Icons.email_outlined),
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _addressController,
                    decoration: const InputDecoration(
                      labelText: 'Address',
                      prefixIcon: Icon(Icons.home_outlined),
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _pincodeController,
                          decoration: const InputDecoration(
                            labelText: 'Pincode',
                            prefixIcon: Icon(Icons.pin_drop_outlined),
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _emergencyController,
                          decoration: const InputDecoration(
                            labelText: 'Emergency Contact',
                            prefixIcon: Icon(Icons.contact_phone_outlined),
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.phone,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Section 3: Identity & Education
                  _buildSectionHeader(context, 'Identity & Education', Icons.school_outlined),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: DropdownButtonFormField<GovIdType>(
                          isExpanded: true,
                          initialValue: _govIdType,
                          decoration: const InputDecoration(labelText: 'ID Type', border: OutlineInputBorder()),
                          items: GovIdType.values.map((t) => DropdownMenuItem(value: t, child: Text(t.name.toUpperCase()))).toList(),
                          onChanged: (v) {
                            if (v != null) setState(() => _govIdType = v);
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 3,
                        child: TextFormField(
                          controller: _govIdNumberController,
                          decoration: const InputDecoration(labelText: 'ID Number', border: OutlineInputBorder()),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _collegeController,
                    decoration: const InputDecoration(labelText: 'College / School', prefixIcon: Icon(Icons.school), border: OutlineInputBorder()),
                    validator: AppValidators.collegeName,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _courseController,
                          decoration: const InputDecoration(labelText: 'Course / Degree', border: OutlineInputBorder()),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _yearController,
                          decoration: const InputDecoration(labelText: 'Year / Semester', border: OutlineInputBorder()),
                          validator: AppValidators.yearOrSem,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Section 4: Remarks
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
                      final formConfigAsync = ref.watch(formConfigStreamProvider);
                      final fieldsList = formConfigAsync.value ?? [];
                      final customFields = fieldsList.where((f) {
                        final isBuiltin = f['builtin'] as bool? ?? false;
                        final isVis = f['visible'] as bool? ?? true;
                        return !isBuiltin && isVis;
                      }).toList();

                      final allKeys = {
                        ...customFields.map((f) => f['id'] as String),
                        ..._customControllers.keys,
                      }.where((k) => !_isInternalKey(k)).toList();

                      if (allKeys.isEmpty) return const SizedBox.shrink();

                      for (final fid in allKeys) {
                        if (fid.isNotEmpty && !_customControllers.containsKey(fid)) {
                          _customControllers[fid] = TextEditingController();
                        }
                      }

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 24),
                          _buildSectionHeader(context, 'Additional Information', Icons.tune_rounded),
                          const SizedBox(height: 12),
                          for (final fid in allKeys)
                            Builder(
                              builder: (ctx) {
                                final f = customFields.where((el) => el['id'] == fid).firstOrNull ?? {'id': fid, 'label': _formatFieldKey(fid), 'type': 'Text'};
                                return _buildCustomFieldItem(ctx, f);
                              },
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

  Widget _buildCustomFieldItem(BuildContext context, Map<String, dynamic> f) {
    final id = f['id'] as String? ?? '';
    final label = f['label'] as String? ?? id;
    final isRequired = f['required'] as bool? ?? false;
    final fType = f['type']?.toString() ?? 'Text';
    final customPattern = f['pattern'] as String?;
    final patternError = f['patternError'] as String?;
    final ctrl = _customControllers[id] ??= TextEditingController();
    final options = (f['options'] as List?)?.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList() ?? [];

    if (fType == 'Dropdown' && options.isNotEmpty) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12.0),
        child: DropdownButtonFormField<String>(
          initialValue: options.contains(ctrl.text.trim()) ? ctrl.text.trim() : null,
          decoration: InputDecoration(
            labelText: '$label${isRequired ? ' *' : ''}',
            prefixIcon: const Icon(Icons.arrow_drop_down_circle_outlined),
            border: const OutlineInputBorder(),
          ),
          items: options
              .map((opt) => DropdownMenuItem(value: opt, child: Text(opt)))
              .toList(),
          onChanged: (val) {
            if (val != null) {
              setState(() => ctrl.text = val);
            }
          },
          validator: isRequired
              ? (v) => (v == null || v.trim().isEmpty) ? '$label is required' : null
              : null,
        ),
      );
    }

    if (fType == 'Date') {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12.0),
        child: InkWell(
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: DateTime.now(),
              firstDate: DateTime(1920),
              lastDate: DateTime(2100),
            );
            if (picked != null) {
              final formatted = '${picked.day.toString().padLeft(2, '0')}/${picked.month.toString().padLeft(2, '0')}/${picked.year}';
              setState(() => ctrl.text = formatted);
            }
          },
          child: AbsorbPointer(
            child: TextFormField(
              controller: ctrl,
              decoration: InputDecoration(
                labelText: '$label${isRequired ? ' *' : ''}',
                hintText: 'DD/MM/YYYY',
                prefixIcon: const Icon(Icons.calendar_today_rounded),
                border: const OutlineInputBorder(),
              ),
              validator: isRequired
                  ? (val) => (val == null || val.trim().isEmpty) ? '$label is required' : null
                  : null,
            ),
          ),
        ),
      );
    }

    if (fType == 'Number') {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12.0),
        child: TextFormField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(
            labelText: '$label${isRequired ? ' *' : ''}',
            prefixIcon: const Icon(Icons.numbers_rounded),
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

    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: TextFormField(
        controller: ctrl,
        decoration: InputDecoration(
          labelText: '$label${isRequired ? ' *' : ''}',
          prefixIcon: const Icon(Icons.edit_note_rounded),
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

  static bool _isInternalKey(String key) {
    final k = key.trim().toLowerCase();
    return k.startsWith('_') ||
        const {
          'note',
          'notes',
          'originalrequestid',
          'requestid',
          'admissionrequestid',
          'shift',
          'shiftname',
          'studentuserid',
          'userid',
          'libraryid',
          'deletedat',
          'adminnotes',
          'isrefund',
          'planname',
          'planid',
          'customplanname',
          'systemaudit',
          'fcmtoken',
          'fcmtokens',
          'deviceinfo',
          'status',
          'type',
        }.contains(k);
  }

  static String _formatFieldKey(String key) {
    if (key.isEmpty) return key;
    final spaced = key
        .replaceAllMapped(RegExp(r'([a-z])([A-Z])'), (m) => '${m[1]} ${m[2]}')
        .replaceAll('_', ' ')
        .replaceAll('-', ' ')
        .trim();
    if (spaced.isEmpty) return key;
    return spaced
        .split(' ')
        .where((w) => w.isNotEmpty)
        .map((w) => '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');
  }
}
