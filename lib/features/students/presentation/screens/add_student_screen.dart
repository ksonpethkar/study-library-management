import 'dart:io';
import 'package:flutter/material.dart';
import 'package:study_library/core/router/app_router.dart';
import 'package:study_library/core/utils/app_validators.dart';
import 'package:study_library/core/validators/gov_id_validator.dart';
import 'package:study_library/core/widgets/id_card_scanner_dialog.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:study_library/core/providers/library_provider.dart';
import 'package:study_library/features/seats/presentation/providers/seat_providers.dart';
import 'package:study_library/features/students/presentation/providers/student_providers.dart';
import 'package:study_library/features/plans/presentation/providers/plan_providers.dart';
import 'package:study_library/models/student_model.dart';
import 'package:study_library/models/receipt_model.dart';
import 'package:study_library/features/receipts/data/repositories/receipt_repository.dart';
import 'package:study_library/core/utils/seat_helper.dart';
import 'package:flutter/services.dart';
import 'package:study_library/services/image_service.dart';
import 'package:study_library/services/plan_calculator_service.dart';
import 'package:study_library/services/form_config_service.dart';
import 'package:study_library/core/utils/error_formatter.dart';
import 'package:study_library/services/whatsapp_service.dart';
import 'package:study_library/models/seat_model.dart';

class AddStudentScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic>? initialData;
  const AddStudentScreen({super.key, this.initialData});

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
  final _customPlanNameController = TextEditingController(text: 'Custom Plan');
  final _customPlanFeeController = TextEditingController(text: '500');
  final _customDiscountReasonController = TextEditingController();
  final _paidAmountController = TextEditingController();
  final _securityDepositController = TextEditingController();

  // State
  Gender _gender = Gender.male;
  GovIdType _govIdType = GovIdType.aadhaar;
  DateTime? _dob;
  File? _pickedPhoto;
  String? _selectedPlanId;
  DateTime? _customPlanEndDate;
  int _customDurationDays = 0; // 0 = Till Month End, 1 = Today only, -1 = Pick date
  bool _isStickyCustomPrice = false;
  String? _selectedSectionId;
  String? _selectedSeatId;
  String? _selectedSeatLabel;
  String? _selectedSectionName;
  String _paymentMethod = 'Cash';
  bool _issueReceipt = true;
  bool _sendWhatsAppWelcome = true;
  String? _bloodGroup;
  final _rollNumberController = TextEditingController();
  final Map<String, TextEditingController> _customControllers = {};
  bool _isLoading = false;
  String _loadingMessage = 'Saving student...';

  @override
  void initState() {
    super.initState();
    if (widget.initialData != null) {
      final d = widget.initialData!;
      if (d['name'] != null) _nameController.text = d['name'].toString();
      if (d['phone'] != null) _phoneController.text = d['phone'].toString();
      if (d['seatId'] != null && d['seatId'].toString().isNotEmpty) {
        _selectedSeatId = d['seatId'].toString();
      }
      if (d['sectionId'] != null && d['sectionId'].toString().isNotEmpty) {
        _selectedSectionId = d['sectionId'].toString();
      }
      if (d['gender'] != null) {
        final g = d['gender'].toString().toLowerCase();
        if (g == 'male') _gender = Gender.male;
        if (g == 'female') _gender = Gender.female;
        if (g == 'other') _gender = Gender.other;
      }
    }
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
    _customPlanNameController.dispose();
    _customPlanFeeController.dispose();
    _customDiscountReasonController.dispose();
    _paidAmountController.dispose();
    _securityDepositController.dispose();
    _rollNumberController.dispose();
    for (final c in _customControllers.values) {
      c.dispose();
    }
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

  DateTime? _tryParseDob(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    final clean = raw.trim();
    final iso = DateTime.tryParse(clean);
    if (iso != null) return iso;
    final parts = clean.split(RegExp(r'[/.-]'));
    if (parts.length == 3) {
      final p0 = int.tryParse(parts[0]);
      final p1 = int.tryParse(parts[1]);
      final p2 = int.tryParse(parts[2]);
      if (p0 != null && p1 != null && p2 != null) {
        if (p0 > 1000 && p1 <= 12 && p2 <= 31) return DateTime(p0, p1, p2);
        if (p2 > 1000 && p1 <= 12 && p0 <= 31) return DateTime(p2, p1, p0);
      }
    }
    return null;
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
          final parsedDob = _tryParseDob(result.dob);
          if (parsedDob != null) _dob = parsedDob;
          if (result.gender != null) {
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
          if (result.phone?.isNotEmpty == true) _phoneController.text = result.phone!;
          if (result.bloodGroup?.isNotEmpty == true) _bloodGroup = result.bloodGroup;
          if (result.college?.isNotEmpty == true) _collegeController.text = result.college!;
          if (result.course?.isNotEmpty == true) _courseController.text = result.course!;
          if (result.rollNumber?.isNotEmpty == true) _rollNumberController.text = result.rollNumber!;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('ID Scanned & details auto-filled successfully!'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      },
    );
  }

  void _confirmDiscardAndExit() async {
    final hasContent = _nameController.text.isNotEmpty ||
        _phoneController.text.isNotEmpty ||
        _pickedPhoto != null;
    if (!hasContent) {
      if (context.canPop()) {
        context.pop();
      } else {
        context.go(Routes.adminStudents);
      }
      return;
    }

    final discard = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Discard Changes?'),
        content: const Text('Are you sure you want to discard this student registration? Entered details will not be saved.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Keep Editing'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );

    if (discard == true && mounted) {
      if (context.canPop()) {
        context.pop();
      } else {
        context.go(Routes.adminStudents);
      }
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
        if (_selectedPlanId == 'custom') {
          planStartDate = DateTime.now();
          final now = planStartDate;
          final nextMonthFirst = DateTime(now.year, now.month + 1, 1);
          final monthEnd = DateTime(nextMonthFirst.year, nextMonthFirst.month, 0, 23, 59, 59, 999);
          planEndDate = _customPlanEndDate ?? monthEnd;
          status = MembershipStatus.active;
        } else {
          final plansAsync = ref.read(plansStreamProvider);
          final plans = plansAsync.value ?? [];
          final plan = plans.where((p) => p.id == _selectedPlanId).firstOrNull;

          if (plan != null) {
            planStartDate = DateTime.now();
            final smartCalc = PlanCalculatorService.calculateSmartPlan(
              plan: plan,
              fromDate: planStartDate,
            );
            planEndDate = smartCalc.endDate;
            status = MembershipStatus.active;
          }
        }
      }

      final customData = <String, dynamic>{};
      for (final entry in _customControllers.entries) {
        if (entry.value.text.trim().isNotEmpty) {
          customData[entry.key] = entry.value.text.trim();
        }
      }

      final plans = ref.read(plansStreamProvider).value ?? [];
      final plan = plans.where((p) => p.id == _selectedPlanId).firstOrNull;
      final effectiveFee = _selectedPlanId == 'custom'
          ? (double.tryParse(_customPlanFeeController.text.trim()) ?? 0.0)
          : (_selectedPlanId != null ? (plan?.price ?? 0.0) : 0.0);
      final paidAmount = _selectedPlanId != null
          ? (double.tryParse(_paidAmountController.text.trim()) ?? effectiveFee)
          : 0.0;
      final remainingDue = (effectiveFee > paidAmount) ? (effectiveFee - paidAmount) : 0.0;
      final securityDeposit = double.tryParse(_securityDepositController.text.trim());
      final effectivePlanName = _selectedPlanId == 'custom'
          ? (_customPlanNameController.text.trim().isNotEmpty ? _customPlanNameController.text.trim() : 'Custom Plan')
          : (plan?.name ?? 'Standard Plan');

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
        customPlanName: _selectedPlanId == 'custom' ? _customPlanNameController.text.trim() : null,
        customPlanFee: _selectedPlanId == 'custom' ? double.tryParse(_customPlanFeeController.text.trim()) : null,
        isStickyCustomPrice: _selectedPlanId == 'custom' ? _isStickyCustomPrice : false,
        customDiscountReason: _selectedPlanId == 'custom' ? _customDiscountReasonController.text.trim() : null,
        planStartDate: planStartDate,
        planEndDate: planEndDate,
        membershipStatus: status,
        customFields: customData,
        notes: _notesController.text.trim(),
        bloodGroup: _bloodGroup,
        rollNumber: _rollNumberController.text.trim().isEmpty ? null : _rollNumberController.text.trim(),
        pendingDueBalance: remainingDue > 0 ? remainingDue : null,
        securityDepositAmount: (securityDeposit != null && securityDeposit > 0) ? securityDeposit : null,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final repo = ref.read(studentRepositoryProvider);
      final studentId = await repo.createStudent(libraryId, newStudent);

      // If a seat was assigned during student registration, mark it occupied
      if (_selectedSeatId != null &&
          _selectedSectionId != null &&
          _selectedSeatId!.isNotEmpty &&
          _selectedSectionId!.isNotEmpty) {
        await ref.read(seatRepositoryProvider).assignStudent(
              libraryId,
              _selectedSectionId!,
              _selectedSeatId!,
              studentId,
            );
      }

      // If student was created with an active plan and receipt requested, generate official initial admission receipt & payment record
      if (status == MembershipStatus.active && _selectedPlanId != null && _issueReceipt) {
        try {
          final receiptRepo = ReceiptRepository();
          final nextRecNum = await receiptRepo.getNextReceiptNumber(libraryId);
          final rec = ReceiptModel(
            id: '',
            libraryId: libraryId,
            receiptNumber: nextRecNum,
            studentId: studentId,
            studentUserId: null,
            planId: _selectedPlanId!,
            amount: paidAmount,
            totalFee: effectiveFee,
            paidAmount: paidAmount,
            remainingDue: remainingDue,
            paymentMethod: _paymentMethod,
            validFrom: planStartDate ?? DateTime.now(),
            validTo: planEndDate ?? (planStartDate ?? DateTime.now()).add(const Duration(days: 30)),
            customFields: {
              'planName': effectivePlanName,
              if (_selectedSeatId != null) 'seatLabel': _selectedSeatLabel ?? SeatHelper.formatSeatLabel(seatId: _selectedSeatId),
              if (securityDeposit != null && securityDeposit > 0) 'securityDeposit': securityDeposit,
              'admissionType': 'Walk-in Admission',
            },
            status: ReceiptStatus.active,
            createdAt: DateTime.now(),
          );
          await receiptRepo.generateReceipt(libraryId, rec, recordMatchingPayment: paidAmount > 0);
        } catch (e) {
          debugPrint('Silent initial receipt generation error: $e');
        }
      }

      // Send WhatsApp welcome if selected
      if (_sendWhatsAppWelcome && newStudent.phone.isNotEmpty) {
        try {
          final lib = ref.read(currentLibraryProvider).value;
          final libName = lib?.name.isNotEmpty == true ? lib!.name : 'The Cozy Corner';
          final deskInfo = _selectedSeatId != null
              ? 'Desk: ${_selectedSeatLabel ?? SeatHelper.formatSeatLabel(seatId: _selectedSeatId)}'
              : 'Desk: General / Shared';
          final planInfo = _selectedPlanId != null ? 'Plan: $effectivePlanName' : 'Registration Confirmed';
          final dueInfo = remainingDue > 0 ? '\nPending Due: ₹${remainingDue.toStringAsFixed(0)}' : '';
          final depositInfo = (securityDeposit != null && securityDeposit > 0) ? '\nSecurity Deposit: ₹${securityDeposit.toStringAsFixed(0)} (Refundable)' : '';

          final msg = 'Dear ${newStudent.name},\n\n'
              'Welcome to $libName! 🎉\n'
              'Your admission has been confirmed successfully.\n\n'
              '• $deskInfo\n'
              '• $planInfo\n'
              '• Amount Paid: ₹${paidAmount.toStringAsFixed(0)} ($_paymentMethod)$dueInfo$depositInfo\n\n'
              'You can log in to our study app anytime to view your digital ID card, desk status, and payment receipts.\n\n'
              'Best regards,\n'
              'Team $libName';

          if (mounted) {
            WhatsAppService().sendMessage(
              newStudent.phone,
              msg,
              recipientName: newStudent.name,
              title: 'Welcome ${newStudent.name}',
              context: context,
            ).ignore();
          }
        } catch (e) {
          debugPrint('Silent WhatsApp welcome error: $e');
        }
      }

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
        AppErrorFormatter.showErrorSnackBar(context, e, actionContext: 'student');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final plansAsync = ref.watch(plansStreamProvider);
    final formConfigAsync = ref.watch(formConfigStreamProvider);
    final formFields = formConfigAsync.value ?? [];

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back',
          onPressed: _confirmDiscardAndExit,
        ),
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
                  // Section 0: Quick OCR Scan Card
                  _buildOcrBanner(context),

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
                            radius: 44,
                            backgroundColor: theme.colorScheme.primaryContainer,
                            backgroundImage:
                                _pickedPhoto != null ? FileImage(_pickedPhoto!) : null,
                            child: _pickedPhoto == null
                                ? Icon(
                                    Icons.person_rounded,
                                    size: 44,
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
                  if (FormConfigService.isFieldVisible(formFields, 'fatherName')) ...[
                    TextFormField(
                      controller: _fatherNameController,
                      decoration: InputDecoration(
                        labelText: FormConfigService.getFieldLabel(formFields, 'fatherName', "Father's / Guardian's Name"),
                        prefixIcon: const Icon(Icons.family_restroom_rounded),
                        border: const OutlineInputBorder(),
                      ),
                      textCapitalization: TextCapitalization.words,
                    ),
                    const SizedBox(height: 12),
                  ],
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final genderField = DropdownButtonFormField<Gender>(
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
                      );

                      final dobField = InkWell(
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
                      );

                      if (constraints.maxWidth < 460) {
                        return Column(
                          children: [
                            genderField,
                            const SizedBox(height: 12),
                            dobField,
                          ],
                        );
                      }

                      return Row(
                        children: [
                          Expanded(child: genderField),
                          const SizedBox(width: 12),
                          Expanded(child: dobField),
                        ],
                      );
                    },
                  ),

                  const SizedBox(height: 24),

                  // Section 2: Contact Details
                  _buildSectionHeader(context, 'Contact Information', Icons.phone_outlined),
                  const SizedBox(height: 12),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final phoneField = TextFormField(
                        controller: _phoneController,
                        decoration: const InputDecoration(
                          labelText: 'Mobile Number *',
                          prefixIcon: Icon(Icons.phone_android_rounded),
                          border: OutlineInputBorder(),
                          hintText: '10-digit mobile number',
                        ),
                        keyboardType: TextInputType.phone,
                        validator: AppValidators.phone,
                      );

                      final emailField = TextFormField(
                        controller: _emailController,
                        decoration: const InputDecoration(
                          labelText: 'Email Address (Optional)',
                          prefixIcon: Icon(Icons.email_outlined),
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.emailAddress,
                      );

                      if (constraints.maxWidth < 460) {
                        return Column(
                          children: [
                            phoneField,
                            const SizedBox(height: 12),
                            emailField,
                          ],
                        );
                      }
                      return Row(
                        children: [
                          Expanded(child: phoneField),
                          const SizedBox(width: 12),
                          Expanded(child: emailField),
                        ],
                      );
                    },
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
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final pinField = TextFormField(
                        controller: _pincodeController,
                        decoration: const InputDecoration(
                          labelText: 'Pincode',
                          prefixIcon: Icon(Icons.pin_drop_outlined),
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                      );

                      final emergField = TextFormField(
                        controller: _emergencyController,
                        decoration: const InputDecoration(
                          labelText: 'Emergency Contact',
                          prefixIcon: Icon(Icons.contact_phone_outlined),
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.phone,
                      );

                      if (constraints.maxWidth < 460) {
                        return Column(
                          children: [
                            pinField,
                            const SizedBox(height: 12),
                            emergField,
                          ],
                        );
                      }
                      return Row(
                        children: [
                          Expanded(child: pinField),
                          const SizedBox(width: 12),
                          Expanded(child: emergField),
                        ],
                      );
                    },
                  ),

                  const SizedBox(height: 24),

                  // Section 3: Identity & Verification
                  _buildSectionHeader(context, 'Identity Verification', Icons.credit_card_rounded),
                  const SizedBox(height: 12),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final idTypeField = DropdownButtonFormField<GovIdType>(
                        isExpanded: true,
                        initialValue: _govIdType,
                        icon: const Icon(Icons.arrow_drop_down, size: 22),
                        decoration: const InputDecoration(
                          labelText: 'ID Type',
                          contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 15),
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(value: GovIdType.aadhaar, child: Text('Aadhaar Card')),
                          DropdownMenuItem(value: GovIdType.pan, child: Text('PAN Card')),
                          DropdownMenuItem(value: GovIdType.drivingLicence, child: Text('Driving Licence')),
                          DropdownMenuItem(value: GovIdType.collegeId, child: Text('College ID')),
                        ],
                        onChanged: (v) {
                          if (v != null) setState(() => _govIdType = v);
                        },
                      );

                      final idText = _govIdNumberController.text.trim();
                      final isIdValid = idText.isNotEmpty && GovIdValidator.isValid(_govIdType, idText);

                      final idNumberField = TextFormField(
                        controller: _govIdNumberController,
                        keyboardType: GovIdValidator.keyboardType(_govIdType),
                        inputFormatters: GovIdValidator.inputFormatters(_govIdType),
                        decoration: InputDecoration(
                          labelText: '${_govIdType.displayName} Number',
                          prefixIcon: const Icon(Icons.numbers_rounded),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
                          border: const OutlineInputBorder(),
                          suffixIcon: idText.isEmpty
                              ? null
                              : Tooltip(
                                  message: isIdValid
                                      ? '${_govIdType.displayName} Checksum Valid ✓'
                                      : 'Invalid format or checksum mismatch',
                                  child: Icon(
                                    isIdValid ? Icons.verified_rounded : Icons.warning_amber_rounded,
                                    color: isIdValid ? Colors.green.shade600 : Colors.amber.shade800,
                                    size: 20,
                                  ),
                                ),
                          enabledBorder: idText.isNotEmpty
                              ? OutlineInputBorder(
                                  borderSide: BorderSide(
                                    color: isIdValid ? Colors.green.shade400 : Colors.amber.shade600,
                                    width: 1.5,
                                  ),
                                )
                              : null,
                        ),
                        validator: (v) => GovIdValidator.validate(_govIdType, v, isRequired: false),
                        onChanged: (_) => setState(() {}),
                      );

                      if (constraints.maxWidth < 560) {
                        return Column(
                          children: [
                            idTypeField,
                            const SizedBox(height: 12),
                            idNumberField,
                          ],
                        );
                      }
                      return Row(
                        children: [
                          Expanded(flex: 5, child: idTypeField),
                          const SizedBox(width: 12),
                          Expanded(flex: 6, child: idNumberField),
                        ],
                      );
                    },
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
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final courseField = TextFormField(
                        controller: _courseController,
                        decoration: const InputDecoration(
                          labelText: 'Course / Degree',
                          prefixIcon: Icon(Icons.menu_book_rounded),
                          border: OutlineInputBorder(),
                        ),
                      );

                      final yearField = TextFormField(
                        controller: _yearController,
                        decoration: const InputDecoration(
                          labelText: 'Year / Sem',
                          prefixIcon: Icon(Icons.calendar_today_rounded),
                          border: OutlineInputBorder(),
                        ),
                      );

                      if (constraints.maxWidth < 460) {
                        return Column(
                          children: [
                            courseField,
                            const SizedBox(height: 12),
                            yearField,
                          ],
                        );
                      }
                      return Row(
                        children: [
                          Expanded(child: courseField),
                          const SizedBox(width: 12),
                          Expanded(child: yearField),
                        ],
                      );
                    },
                  ),

                  const SizedBox(height: 12),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final rollField = TextFormField(
                        controller: _rollNumberController,
                        decoration: const InputDecoration(
                          labelText: 'Roll / Enroll Number',
                          prefixIcon: Icon(Icons.numbers_rounded),
                          border: OutlineInputBorder(),
                        ),
                      );

                      final bloodField = DropdownButtonFormField<String>(
                        isExpanded: true,
                        initialValue: _bloodGroup,
                        icon: const Icon(Icons.arrow_drop_down, size: 22),
                        decoration: const InputDecoration(
                          labelText: 'Blood Group',
                          contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 15),
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
                      );

                      if (constraints.maxWidth < 560) {
                        return Column(
                          children: [
                            rollField,
                            const SizedBox(height: 12),
                            bloodField,
                          ],
                        );
                      }
                      return Row(
                        children: [
                          Expanded(flex: 3, child: rollField),
                          const SizedBox(width: 12),
                          Expanded(flex: 2, child: bloodField),
                        ],
                      );
                    },
                  ),

                  const SizedBox(height: 24),

                  // Section 5: Desk / Seat Allocation (Walk-in)
                  _buildSectionHeader(context, 'Desk / Seat Allocation (Optional)', Icons.event_seat_rounded),
                  const SizedBox(height: 12),
                  _buildDeskPickerCard(context),

                  const SizedBox(height: 24),

                  // Section 6: Plan Assignment (Optional)
                  _buildSectionHeader(context, 'Membership Plan (Optional)', Icons.card_membership_rounded),
                  const SizedBox(height: 12),
                  plansAsync.when(
                    data: (plans) {
                      final active = plans.where((p) => p.isActive).toList();

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Option 1: Assign Later (No Plan)
                          _buildPlanOptionCard(
                            context: context,
                            isSelected: _selectedPlanId == null,
                            title: 'Assign Later (No Plan)',
                            subtitle: 'Register student now; plan & fee can be added anytime',
                            icon: Icons.hourglass_empty_rounded,
                            priceText: 'Free now',
                            onTap: () {
                              setState(() {
                                _selectedPlanId = null;
                                _paidAmountController.clear();
                              });
                            },
                          ),
                          const SizedBox(height: 8),

                          // Option 2: Active Library Plans with exact discount and duration visuals
                          ...active.map((p) {
                            final isSelected = _selectedPlanId == p.id;
                            final disc = p.getDiscountPercent();
                            final discText = disc != null ? '$disc% OFF' : null;
                            final origPrice = p.getEffectiveOriginalPrice();
                            final origText = (origPrice != null && origPrice > p.price)
                                ? '₹${origPrice.toStringAsFixed(0)}'
                                : null;

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: _buildPlanOptionCard(
                                context: context,
                                isSelected: isSelected,
                                title: p.name,
                                subtitle: 'Duration: ${p.duration} ${p.durationUnit.name} • Full Access',
                                icon: Icons.card_membership_rounded,
                                priceText: '₹${p.price.toStringAsFixed(0)}',
                                originalPriceText: origText,
                                badge: discText ?? (p.isFeatured ? 'POPULAR' : null),
                                onTap: () {
                                  setState(() {
                                    _selectedPlanId = p.id;
                                    _paidAmountController.text = p.price.toStringAsFixed(0);
                                  });
                                },
                              ),
                            );
                          }),

                          // Option 3: Custom Plan (Ad-Hoc / Special Concession)
                          _buildPlanOptionCard(
                            context: context,
                            isSelected: _selectedPlanId == 'custom',
                            title: 'Custom Plan (Ad-Hoc / Special Concession)',
                            subtitle: 'Tailored fee, special scholarship, or sprint duration capped at month end',
                            icon: Icons.tune_rounded,
                            priceText: '₹${_customPlanFeeController.text.isNotEmpty ? _customPlanFeeController.text : "500"}',
                            badge: 'CUSTOM',
                            onTap: () {
                              setState(() {
                                _selectedPlanId = 'custom';
                                final now = DateTime.now();
                                final nextMonthFirst = DateTime(now.year, now.month + 1, 1);
                                _customPlanEndDate ??= DateTime(nextMonthFirst.year, nextMonthFirst.month, 0, 23, 59, 59, 999);
                                _paidAmountController.text = _customPlanFeeController.text.isNotEmpty ? _customPlanFeeController.text : "500";
                              });
                            },
                          ),

                          // Custom Plan Configuration Card
                          if (_selectedPlanId == 'custom') ...[
                            const SizedBox(height: 10),
                            Builder(
                              builder: (context) {
                                final theme = Theme.of(context);
                                final now = DateTime.now();
                                final nextMonthFirst = DateTime(now.year, now.month + 1, 1);
                                final monthEnd = DateTime(nextMonthFirst.year, nextMonthFirst.month, 0, 23, 59, 59, 999);
                                final remainingDaysInMonth = monthEnd.difference(now).inDays + 1;
                                final df = DateFormat('dd MMM yyyy');

                                return Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.primaryContainer.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.4)),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(Icons.tune_rounded, size: 18, color: theme.colorScheme.primary),
                                          const SizedBox(width: 8),
                                          Text(
                                            'Custom Plan Configuration',
                                            style: TextStyle(fontWeight: FontWeight.bold, color: theme.colorScheme.primary, fontSize: 14),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      TextFormField(
                                        controller: _customPlanNameController,
                                        decoration: const InputDecoration(
                                          labelText: 'Custom Plan Name *',
                                          hintText: 'e.g. 15-Day Exam Pass, Daily Trial, Scholarship',
                                          border: OutlineInputBorder(),
                                          isDense: true,
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      TextFormField(
                                        controller: _customPlanFeeController,
                                        keyboardType: TextInputType.number,
                                        decoration: const InputDecoration(
                                          labelText: 'Custom Plan Fee (₹) *',
                                          prefixText: '₹ ',
                                          border: OutlineInputBorder(),
                                          isDense: true,
                                        ),
                                        onChanged: (_) => setState(() {}),
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        'Validity & Duration (Strictly capped to current month end):',
                                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurfaceVariant),
                                      ),
                                      const SizedBox(height: 8),
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        children: [
                                          ChoiceChip(
                                            label: const Text('Today Only (1 Day)'),
                                            selected: _customDurationDays == 1,
                                            onSelected: (val) {
                                              if (val) {
                                                setState(() {
                                                  _customDurationDays = 1;
                                                  _customPlanEndDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
                                                });
                                              }
                                            },
                                          ),
                                          ChoiceChip(
                                            label: Text('Till Month End ($remainingDaysInMonth Days)'),
                                            selected: _customDurationDays == 0,
                                            onSelected: (val) {
                                              if (val) {
                                                setState(() {
                                                  _customDurationDays = 0;
                                                  _customPlanEndDate = monthEnd;
                                                });
                                              }
                                            },
                                          ),
                                          if (remainingDaysInMonth > 7)
                                            ChoiceChip(
                                              label: const Text('7 Days Sprint'),
                                              selected: _customDurationDays == 7,
                                              onSelected: (val) {
                                                if (val) {
                                                  setState(() {
                                                    _customDurationDays = 7;
                                                    _customPlanEndDate = now.add(const Duration(days: 6));
                                                  });
                                                }
                                              },
                                            ),
                                          if (remainingDaysInMonth > 15)
                                            ChoiceChip(
                                              label: const Text('15 Days Pass'),
                                              selected: _customDurationDays == 15,
                                              onSelected: (val) {
                                                if (val) {
                                                  setState(() {
                                                    _customDurationDays = 15;
                                                    _customPlanEndDate = now.add(const Duration(days: 14));
                                                  });
                                                }
                                              },
                                            ),
                                          ChoiceChip(
                                            avatar: const Icon(Icons.calendar_month_rounded, size: 16),
                                            label: Text(_customDurationDays == -1 && _customPlanEndDate != null
                                                ? 'Exp: ${df.format(_customPlanEndDate!)}'
                                                : 'Pick Specific Date...'),
                                            selected: _customDurationDays == -1,
                                            onSelected: (val) async {
                                              final picked = await showDatePicker(
                                                context: context,
                                                initialDate: _customPlanEndDate ?? now,
                                                firstDate: now,
                                                lastDate: monthEnd,
                                                helpText: 'Select Custom Expiry (Capped to Month End)',
                                              );
                                              if (picked != null) {
                                                setState(() {
                                                  _customDurationDays = -1;
                                                  _customPlanEndDate = DateTime(picked.year, picked.month, picked.day, 23, 59, 59);
                                                });
                                              }
                                            },
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                        decoration: BoxDecoration(
                                          color: theme.colorScheme.surface,
                                          borderRadius: BorderRadius.circular(10),
                                          border: Border.all(color: theme.colorScheme.outlineVariant),
                                        ),
                                        child: Column(
                                          children: [
                                            SwitchListTile(
                                              contentPadding: EdgeInsets.zero,
                                              title: const Text('Recurring Monthly Concession', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                                              subtitle: const Text('Apply this custom rate to all future renewals (Permanent)', style: TextStyle(fontSize: 11)),
                                              value: _isStickyCustomPrice,
                                              onChanged: (v) => setState(() => _isStickyCustomPrice = v),
                                            ),
                                            if (_isStickyCustomPrice) ...[
                                              const SizedBox(height: 6),
                                              TextFormField(
                                                controller: _customDiscountReasonController,
                                                decoration: const InputDecoration(
                                                  labelText: 'Concession / Approval Reason (Optional)',
                                                  hintText: 'e.g. Merit Scholarship, Staff Ward, Financial Hardship',
                                                  border: OutlineInputBorder(),
                                                  isDense: true,
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        '✓ Plan valid until ${df.format(_customPlanEndDate ?? monthEnd)}. On the 1st of next month, all standard catalog plans will be available.',
                                        style: TextStyle(fontSize: 11.5, color: theme.colorScheme.primary, fontWeight: FontWeight.w500),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ],
                        ],
                      );
                    },
                    loading: () => const LinearProgressIndicator(),
                    error: (_, _) => const SizedBox(),
                  ),

                  if (_selectedPlanId != null) ...[
                    const SizedBox(height: 24),
                    _buildSectionHeader(context, 'Initial Payment & Admission Receipt', Icons.receipt_long_rounded),
                    const SizedBox(height: 12),
                    Builder(
                      builder: (context) {
                        final plans = ref.read(plansStreamProvider).value ?? [];
                        final plan = plans.where((p) => p.id == _selectedPlanId).firstOrNull;
                        final effectiveFee = _selectedPlanId == 'custom'
                            ? (double.tryParse(_customPlanFeeController.text.trim()) ?? 0.0)
                            : (plan?.price ?? 0.0);
                        return _buildPaymentCollectionCard(context, effectiveFee);
                      },
                    ),
                  ],

                  const SizedBox(height: 24),

                  // Section 7: Additional Notes
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

                  Builder(
                    builder: (context) {
                      final customFields = formFields.where((f) {
                        final isBuiltin = f['builtin'] as bool? ?? false;
                        final isVis = f['visible'] as bool? ?? true;
                        return !isBuiltin && isVis;
                      }).toList();

                      if (customFields.isEmpty) return const SizedBox.shrink();

                      // Ensure controllers exist
                      for (final f in customFields) {
                        final fid = f['id'] as String? ?? '';
                        if (fid.isNotEmpty && !_customControllers.containsKey(fid)) {
                          _customControllers[fid] = TextEditingController();
                        }
                      }

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 24),
                          _buildSectionHeader(context, 'Additional Admission Fields', Icons.tune_rounded),
                          const SizedBox(height: 12),
                          for (final f in customFields)
                            _buildCustomFieldItem(context, f),
                        ],
                      );
                    },
                  ),

                  const SizedBox(height: 32),

                  // Dual Action Buttons: Balanced Discard & Add Student
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: OutlinedButton.icon(
                          onPressed: _isLoading ? null : _confirmDiscardAndExit,
                          icon: const Icon(Icons.close_rounded, size: 18),
                          label: const Text('Cancel'),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(52),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                            side: BorderSide(color: theme.colorScheme.outline.withValues(alpha: 0.5)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 3,
                        child: FilledButton.icon(
                          onPressed: _isLoading ? null : _saveStudent,
                          icon: _isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Icon(Icons.person_add_rounded, size: 20),
                          label: Text(_isLoading ? 'Saving...' : 'Add Student to Library'),
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(52),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }

  Widget _buildOcrBanner(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primary.withValues(alpha: isDark ? 0.2 : 0.09),
            theme.colorScheme.surfaceContainerHighest.withValues(alpha: isDark ? 0.3 : 0.45),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: theme.colorScheme.primary.withValues(alpha: 0.25),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: const Icon(Icons.document_scanner_rounded, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Scan Govt ID (OCR Auto-Fill)',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Aadhaar • PAN • DL • College ID',
                      style: TextStyle(
                        fontSize: 11,
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.withValues(alpha: 0.4)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.bolt_rounded, size: 14, color: Colors.green),
                    SizedBox(width: 2),
                    Text(
                      '1-Tap',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.green),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Scan physical ID card to auto-extract student name, DOB, ID number, and address automatically without manual typing.',
            style: TextStyle(
              fontSize: 12.5,
              height: 1.35,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: FilledButton.tonalIcon(
              onPressed: _openOcrScanner,
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.camera_alt_outlined, size: 18),
              label: const Text(
                'Scan & Auto-Fill Form',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlanOptionCard({
    required BuildContext context,
    required bool isSelected,
    required String title,
    required String subtitle,
    required IconData icon,
    required String priceText,
    String? originalPriceText,
    String? badge,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? theme.colorScheme.primary.withValues(alpha: isDark ? 0.22 : 0.08)
                : (isDark ? const Color(0xFF1E2430) : theme.cardColor),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.outlineVariant.withValues(alpha: 0.6),
              width: isSelected ? 2 : 1,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: theme.colorScheme.primary.withValues(alpha: 0.15),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              Icon(
                isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                color: isSelected ? theme.colorScheme.primary : theme.hintColor,
                size: 22,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            title,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: isSelected ? theme.colorScheme.primary : null,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (badge != null) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? theme.colorScheme.primary.withValues(alpha: 0.18)
                                  : Colors.amber.shade100,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              badge,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: isSelected ? theme.colorScheme.primary : Colors.amber.shade900,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    priceText,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurface,
                    ),
                  ),
                  if (originalPriceText != null)
                    Text(
                      originalPriceText,
                      style: TextStyle(
                        fontSize: 11,
                        color: theme.hintColor,
                        decoration: TextDecoration.lineThrough,
                      ),
                    ),
                ],
              ),
            ],
          ),
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

  Widget _buildDeskPickerCard(BuildContext context) {
    final theme = Theme.of(context);
    final isAssigned = _selectedSeatId != null && _selectedSeatId!.isNotEmpty;

    if (!isAssigned) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.colorScheme.outlineVariant),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.chair_outlined, size: 28, color: Colors.grey.shade600),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('No Desk Assigned', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 2),
                  Text(
                    'Student can be admitted without a desk or assigned anytime.',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            FilledButton.tonalIcon(
              onPressed: () => _showWalkinSeatPickerSheet(context),
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Choose Desk'),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF10B981).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.4), width: 1.5),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.chair_rounded, size: 28, color: Color(0xFF059669)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Desk ${_selectedSeatLabel ?? SeatHelper.formatSeatLabel(seatId: _selectedSeatId)}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF065F46)),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text('ALLOCATED', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  '${_selectedSectionName ?? "Main Section"} • Full Day Access',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 10),
            ),
            onPressed: () => _showWalkinSeatPickerSheet(context),
            child: const Text('Change'),
          ),
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 20, color: Colors.grey),
            tooltip: 'Remove Desk',
            onPressed: () => setState(() {
              _selectedSeatId = null;
              _selectedSeatLabel = null;
              _selectedSectionId = null;
              _selectedSectionName = null;
            }),
          ),
        ],
      ),
    );
  }

  void _showWalkinSeatPickerSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          return DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.75,
            maxChildSize: 0.95,
            minChildSize: 0.5,
            builder: (innerCtx, scrollController) {
              return Consumer(
                builder: (consumerCtx, ref, _) {
                  final sectionsAsync = ref.watch(sectionsProvider);

                  return sectionsAsync.when(
                    data: (sections) {
                      final activeSections = sections.where((s) => s.isActive).toList();
                      if (activeSections.isEmpty) {
                        return const Center(child: Padding(
                          padding: EdgeInsets.all(24.0),
                          child: Text('No active sections found. Please add a section in Seats settings.'),
                        ));
                      }

                      final curSection = activeSections.firstWhere(
                        (s) => s.id == _selectedSectionId,
                        orElse: () => activeSections.first,
                      );

                      final seatsAsync = ref.watch(seatsProvider(curSection.id));

                      return Column(
                        children: [
                          const SizedBox(height: 8),
                          Container(
                            width: 40,
                            height: 4,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade300,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: Row(
                              children: [
                                const Icon(Icons.event_seat_rounded, color: Color(0xFF059669)),
                                const SizedBox(width: 8),
                                const Expanded(
                                  child: Text(
                                    'Select Available Desk',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.close_rounded),
                                  onPressed: () => Navigator.pop(sheetCtx),
                                ),
                              ],
                            ),
                          ),
                          if (activeSections.length > 1) ...[
                            const SizedBox(height: 8),
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              child: Row(
                                children: activeSections.map((sec) {
                                  final isSecSel = sec.id == curSection.id;
                                  return Padding(
                                    padding: const EdgeInsets.only(right: 8),
                                    child: FilterChip(
                                      selected: isSecSel,
                                      label: Text(sec.name),
                                      onSelected: (_) {
                                        setSheetState(() {
                                          _selectedSectionId = sec.id;
                                          _selectedSectionName = sec.name;
                                        });
                                      },
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                          ],
                          const Divider(height: 16),
                          Expanded(
                            child: seatsAsync.when(
                              data: (seats) {
                                final available = seats.where((s) => s.status == SeatStatus.available).toList()
                                  ..sort(SeatHelper.compareSeats);
                                if (available.isEmpty) {
                                  return Center(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.event_busy_rounded, size: 48, color: Colors.grey.shade400),
                                        const SizedBox(height: 8),
                                        Text(
                                          'No available desks in ${curSection.name}',
                                          style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.w600),
                                        ),
                                      ],
                                    ),
                                  );
                                }

                                return GridView.builder(
                                  controller: scrollController,
                                  padding: const EdgeInsets.all(16),
                                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                                    maxCrossAxisExtent: 110,
                                    childAspectRatio: 1.1,
                                    crossAxisSpacing: 10,
                                    mainAxisSpacing: 10,
                                  ),
                                  itemCount: available.length,
                                  itemBuilder: (gridCtx, i) {
                                    final seat = available[i];
                                    final isChosen = _selectedSeatId == seat.id;

                                    return InkWell(
                                      borderRadius: BorderRadius.circular(12),
                                      onTap: () {
                                        setState(() {
                                          _selectedSeatId = seat.id;
                                          _selectedSectionId = curSection.id;
                                          _selectedSeatLabel = seat.label;
                                          _selectedSectionName = curSection.name;
                                        });
                                        Navigator.pop(sheetCtx);
                                      },
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: isChosen ? const Color(0xFF059669) : Colors.green.shade50,
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(
                                            color: isChosen ? const Color(0xFF059669) : Colors.green.shade200,
                                            width: 1.5,
                                          ),
                                        ),
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.chair_rounded,
                                              size: 24,
                                              color: isChosen ? Colors.white : const Color(0xFF059669),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              '#${seat.label}',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 13,
                                                color: isChosen ? Colors.white : const Color(0xFF065F46),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                );
                              },
                              loading: () => const Center(child: CircularProgressIndicator()),
                              error: (e, _) => Center(child: Text('Error: $e')),
                            ),
                          ),
                        ],
                      );
                    },
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Center(child: Text('Error: $e')),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildPaymentCollectionCard(BuildContext context, double totalFee) {
    final theme = Theme.of(context);
    final paidNow = double.tryParse(_paidAmountController.text.trim()) ?? totalFee;
    final due = totalFee > paidNow ? (totalFee - paidNow) : 0.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Total Plan Fee', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                  Text(
                    '₹${totalFee.toStringAsFixed(0)}',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              if (due > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Text(
                    'Pending Due: ₹${due.toStringAsFixed(0)}',
                    style: TextStyle(color: Colors.red.shade800, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Text(
                    'Fully Paid ✓',
                    style: TextStyle(color: Colors.green.shade800, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Payment Mode',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            children: ['Cash', 'UPI / Online', 'Bank Transfer', 'Card'].map((m) {
              final isSel = _paymentMethod == m;
              return ChoiceChip(
                label: Text(m),
                selected: isSel,
                onSelected: (val) {
                  if (val) setState(() => _paymentMethod = m);
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _paidAmountController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Amount Paid Now (₹) *',
              prefixText: '₹ ',
              border: OutlineInputBorder(),
              isDense: true,
              helperText: 'Enter full fee or advance deposit. Remainder will be recorded as pending due.',
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _securityDepositController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Refundable Security Deposit (₹) (Optional)',
              prefixText: '₹ ',
              border: OutlineInputBorder(),
              isDense: true,
              hintText: 'e.g. 500 for locker or desk keys',
              helperText: 'Tracked separately on student record; refundable upon exit',
            ),
          ),
          const SizedBox(height: 14),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: _issueReceipt,
            title: const Text('Issue Official Admission Receipt & Record Payment', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
            subtitle: const Text('Generates official serial receipt with PDF export', style: TextStyle(fontSize: 11.5)),
            onChanged: (val) => setState(() => _issueReceipt = val ?? true),
          ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: _sendWhatsAppWelcome,
            title: const Text('Send Welcome & Admission Confirmation to WhatsApp', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
            subtitle: const Text('Dispatches greeting with Desk #, Plan, and Receipt details', style: TextStyle(fontSize: 11.5)),
            onChanged: (val) => setState(() => _sendWhatsAppWelcome = val ?? true),
          ),
        ],
      ),
    );
  }
}
