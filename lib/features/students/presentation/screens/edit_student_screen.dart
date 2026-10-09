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
  DateTime? _dob;
  File? _newPhoto;
  String _currentPhotoUrl = '';
  bool _isLoading = true;
  bool _isSaving = false;
  String _savingMessage = 'Saving changes...';
  StudentModel? _originalStudent;

  @override
  void initState() {
    super.initState();
    _loadStudent();
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
    super.dispose();
  }

  Future<void> _loadStudent() async {
    final libraryId = ref.read(currentLibraryIdProvider);
    if (libraryId == null || libraryId.isEmpty) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection('libraries')
          .doc(libraryId)
          .collection('students')
          .doc(widget.studentId)
          .get();

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
        _govIdType = s.govIdType;
        _membershipStatus = s.membershipStatus;
        _dob = s.dob;
        _currentPhotoUrl = s.photoUrl;

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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString().replaceAll("Exception: ", "")}'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
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
                  DropdownButtonFormField<MembershipStatus>(
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
}
