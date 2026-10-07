import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:study_library/core/providers/library_provider.dart';
import 'package:study_library/features/students/presentation/providers/student_providers.dart';
import 'package:study_library/features/plans/presentation/providers/plan_providers.dart';
import 'package:study_library/models/student_model.dart';
import 'package:study_library/models/plan_model.dart';
import 'package:study_library/services/image_service.dart';

class AddStudentScreen extends ConsumerStatefulWidget {
  const AddStudentScreen({super.key});

  @override
  ConsumerState<AddStudentScreen> createState() => _AddStudentScreenState();
}

class _AddStudentScreenState extends ConsumerState<AddStudentScreen> {
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
  DateTime? _dob;
  File? _pickedPhoto;
  String? _selectedPlanId;
  String? _selectedSectionId;
  String? _selectedSeatId;
  String? _bloodGroup;
  final _rollNumberController = TextEditingController();
  bool _isLoading = false;
  String _loadingMessage = 'Saving student...';

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
    _rollNumberController.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final source = await ImageService.showSourcePicker(
      context,
      canRemove: _pickedPhoto != null,
    );
    if (!mounted) return;

    if (source == null) {
      // User tapped remove or cancelled
      setState(() => _pickedPhoto = null);
      return;
    }

    final compressed = await ImageService.pickAndCompressImage(source: source);
    if (compressed != null && mounted) {
      setState(() => _pickedPhoto = compressed);
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
    if (!_formKey.currentState!.validate()) return;

    final libraryId = ref.read(currentLibraryIdProvider) ?? '';
    if (libraryId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No active library found. Please sign in again.')),
      );
      return;
    }

    final cleanedPhone = _phoneController.text.trim();
    // Check for duplicate phone
    final existingSnap = await FirebaseFirestore.instance
      .collection('libraries').doc(libraryId)
      .collection('students')
      .where('phone', isEqualTo: cleanedPhone)
      .limit(1)
      .get();

    if (existingSnap.docs.isNotEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('A student with this phone number already exists.'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return; // abort save
    }

    setState(() {
      _isLoading = true;
      _loadingMessage = _pickedPhoto != null ? 'Uploading photo...' : 'Saving student...';
    });

    try {
      String photoUrl = '';
      if (_pickedPhoto != null) {
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final storagePath = 'libraries/$libraryId/students/photo_$timestamp.jpg';
        try {
          photoUrl = await ImageService.uploadToStorage(
            file: _pickedPhoto!,
            path: storagePath,
          );
        } catch (e) {
          debugPrint('Photo upload failed: $e, continuing without remote photo');
        }
      }

      setState(() => _loadingMessage = 'Creating student profile in database...');

      // Calculate plan dates if plan is selected
      DateTime? planStartDate;
      DateTime? planEndDate;
      MembershipStatus status = MembershipStatus.pending;

      if (_selectedPlanId != null && _selectedPlanId!.isNotEmpty) {
        final plansAsync = ref.read(plansStreamProvider);
        final plans = plansAsync.value ?? [];
        final plan = plans.where((p) => p.id == _selectedPlanId).firstOrNull;

        if (plan != null) {
          planStartDate = DateTime.now();
          if (plan.durationUnit == DurationUnit.months) {
            planEndDate = DateTime(
              planStartDate.year,
              planStartDate.month + plan.duration,
              planStartDate.day,
            );
          } else {
            planEndDate = planStartDate.add(Duration(days: plan.duration));
          }
          status = MembershipStatus.active;
        }
      }

      final newStudent = StudentModel(
        id: '',
        name: _nameController.text.trim(),
        fatherName: _fatherNameController.text.trim(),
        phone: _phoneController.text.trim(),
        email: _emailController.text.trim(),
        dob: _dob,
        gender: _gender,
        address: _addressController.text.trim(),
        pincode: _pincodeController.text.trim(),
        govIdType: _govIdType,
        govIdNumber: _govIdNumberController.text.trim(),
        govIdImageUrl: '',
        photoUrl: photoUrl,
        college: _collegeController.text.trim(),
        course: _courseController.text.trim(),
        year: _yearController.text.trim(),
        emergencyContact: _emergencyController.text.trim(),
        seatId: _selectedSeatId,
        sectionId: _selectedSectionId,
        planId: _selectedPlanId,
        planStartDate: planStartDate,
        planEndDate: planEndDate,
        membershipStatus: status,
        customFields: {},
        notes: _notesController.text.trim(),
        bloodGroup: _bloodGroup,
        rollNumber: _rollNumberController.text.trim().isEmpty ? null : _rollNumberController.text.trim(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final repo = ref.read(studentRepositoryProvider);
      final studentId = await repo.createStudent(libraryId, newStudent);

      // Invalidate stream so UI refreshes immediately
      ref.invalidate(studentsStreamProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Student profile created successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        // Navigate directly to the newly created student profile
        context.go('/admin/students/$studentId');
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
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final plansAsync = ref.watch(plansStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Student'),
        actions: [
          TextButton.icon(
            onPressed: _isLoading ? null : _saveStudent,
            icon: const Icon(Icons.check_rounded),
            label: const Text('Save', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(_loadingMessage, style: theme.textTheme.bodyMedium),
                ],
              ),
            )
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Photo Avatar Section
                  Center(
                    child: Stack(
                      children: [
                        GestureDetector(
                          onTap: () {
                            if (_pickedPhoto != null) {
                              ImageService.showImageViewer(
                                context,
                                imageFile: _pickedPhoto,
                                title: _nameController.text.isNotEmpty
                                    ? _nameController.text
                                    : 'Profile Photo',
                              );
                            } else {
                              _pickPhoto();
                            }
                          },
                          child: CircleAvatar(
                            radius: 54,
                            backgroundColor: theme.colorScheme.primaryContainer,
                            backgroundImage:
                                _pickedPhoto != null ? FileImage(_pickedPhoto!) : null,
                            child: _pickedPhoto == null
                                ? Icon(
                                    Icons.person_rounded,
                                    size: 54,
                                    color: theme.colorScheme.onPrimaryContainer,
                                  )
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
                              child: const Icon(
                                Icons.camera_alt_rounded,
                                size: 18,
                                color: Colors.white,
                              ),
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
                        _pickedPhoto == null ? 'Upload Profile Photo' : 'Change Photo',
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
                    validator: (v) => (v == null || v.trim().length < 2)
                        ? 'Name must be at least 2 characters'
                        : null,
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
                              style: TextStyle(
                                color: _dob != null
                                    ? theme.textTheme.bodyMedium?.color
                                    : theme.hintColor,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
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
                      hintText: '10-digit mobile number',
                    ),
                    keyboardType: TextInputType.phone,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Phone number is required';
                      final cleaned = v.trim().replaceAll(RegExp(r'\D'), '');
                      if (cleaned.length != 10) return 'Enter a valid 10-digit mobile number';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _emailController,
                    decoration: const InputDecoration(
                      labelText: 'Email Address (Optional)',
                      prefixIcon: Icon(Icons.email_outlined),
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _addressController,
                    decoration: const InputDecoration(
                      labelText: 'Residential Address',
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

                  // Section 3: Identity & Verification
                  _buildSectionHeader(context, 'Identity Verification', Icons.credit_card_rounded),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: DropdownButtonFormField<GovIdType>(
                          initialValue: _govIdType,
                          decoration: const InputDecoration(
                            labelText: 'ID Type',
                            border: OutlineInputBorder(),
                          ),
                          items: const [
                            DropdownMenuItem(value: GovIdType.aadhaar, child: Text('Aadhaar')),
                            DropdownMenuItem(value: GovIdType.pan, child: Text('PAN Card')),
                            DropdownMenuItem(value: GovIdType.drivingLicence, child: Text('Driving Lic.')),
                            DropdownMenuItem(value: GovIdType.collegeId, child: Text('College ID')),
                          ],
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
                          decoration: InputDecoration(
                            labelText: '${_govIdType.name.toUpperCase()} Number',
                            border: const OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Section 4: Academics
                  _buildSectionHeader(context, 'Education / College', Icons.school_outlined),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _collegeController,
                    decoration: const InputDecoration(
                      labelText: 'College / Institute Name',
                      prefixIcon: Icon(Icons.school_rounded),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _courseController,
                          decoration: const InputDecoration(
                            labelText: 'Course / Degree',
                            prefixIcon: Icon(Icons.menu_book_rounded),
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _yearController,
                          decoration: const InputDecoration(
                            labelText: 'Year / Sem',
                            prefixIcon: Icon(Icons.calendar_today_rounded),
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: TextFormField(
                          controller: _rollNumberController,
                          decoration: const InputDecoration(
                            labelText: 'Roll / Enroll Number',
                            prefixIcon: Icon(Icons.numbers_rounded),
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: DropdownButtonFormField<String>(
                          initialValue: _bloodGroup,
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
                          onChanged: (v) => setState(() => _bloodGroup = v),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Section 5: Plan Assignment (Optional)
                  _buildSectionHeader(context, 'Membership Plan (Optional)', Icons.card_membership_rounded),
                  const SizedBox(height: 12),
                  plansAsync.when(
                    data: (plans) {
                      final active = plans.where((p) => p.isActive).toList();
                      return DropdownButtonFormField<String?>(
                        initialValue: _selectedPlanId,
                        decoration: const InputDecoration(
                          labelText: 'Assign Membership Plan',
                          prefixIcon: Icon(Icons.loyalty_rounded),
                          border: OutlineInputBorder(),
                          helperText: 'You can also assign or change plan later',
                        ),
                        items: [
                          const DropdownMenuItem(value: null, child: Text('Assign Later (No Plan)')),
                          ...active.map((p) => DropdownMenuItem(
                                value: p.id,
                                child: Text('${p.name} — ₹${p.price} (${p.duration} ${p.durationUnit.name})'),
                              )),
                        ],
                        onChanged: (v) => setState(() => _selectedPlanId = v),
                      );
                    },
                    loading: () => const LinearProgressIndicator(),
                    error: (_, _) => const SizedBox(),
                  ),

                  const SizedBox(height: 24),

                  // Section 6: Additional Notes
                  _buildSectionHeader(context, 'Remarks & Notes', Icons.notes_rounded),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _notesController,
                    decoration: const InputDecoration(
                      labelText: 'Notes (Optional)',
                      hintText: 'Any special seat preference, shift, or notes...',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 2,
                  ),

                  const SizedBox(height: 32),

                  // Submit Button
                  FilledButton.icon(
                    onPressed: _saveStudent,
                    icon: const Icon(Icons.person_add_rounded),
                    label: const Text('Add Student to Library'),
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
