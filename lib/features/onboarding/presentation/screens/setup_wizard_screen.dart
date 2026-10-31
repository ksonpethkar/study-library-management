import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:study_library/core/providers/library_provider.dart';
import 'package:study_library/core/router/app_router.dart';
import 'package:study_library/core/utils/app_validators.dart';
import 'package:study_library/core/error/error_handler.dart';


class SetupWizardScreen extends ConsumerStatefulWidget {
  const SetupWizardScreen({super.key});

  @override
  ConsumerState<SetupWizardScreen> createState() => _SetupWizardScreenState();
}

class _SetupWizardScreenState extends ConsumerState<SetupWizardScreen> {
  int _currentStep = 0;
  bool _isLoading = false;

  // Step 1: Library Info
  final _formKey1 = GlobalKey<FormState>();
  String _libraryName = '';
  String _libraryAddress = '';
  String _libraryPhone = '';
  String _libraryEmail = '';

  // Step 2: Branding (skipped mostly)

  // Step 3: First Section
  final _formKey3 = GlobalKey<FormState>();
  String _sectionName = '';
  int _rows = 0;
  int _cols = 0;
  int _sectionColor = 0xFF3498DB;

  final List<int> _colorOptions = [
    0xFF3498DB, // Blue
    0xFFE74C3C, // Red
    0xFF2ECC71, // Green
    0xFFF1C40F, // Yellow
    0xFF9B59B6, // Purple
    0xFFE67E22, // Orange
    0xFF1ABC9C, // Teal
    0xFF34495E, // Navy
  ];

  // Step 4: First Plan
  final _formKey4 = GlobalKey<FormState>();
  String _planName = '';
  double _price = 0.0;
  int _durationMonths = 1;

  Future<void> _saveSetupData() async {
    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('No authenticated user found.');

      final db = FirebaseFirestore.instance;
      final batch = db.batch();

      // 1. Library Document
      final libraryRef = db.collection('libraries').doc();
      final libraryId = libraryRef.id;

      batch.set(libraryRef, {
        'id': libraryId,
        'name': _libraryName,
        'address': _libraryAddress,
        'phone': _libraryPhone,
        'email': _libraryEmail,
        'ownerId': user.uid,
        'createdAt': FieldValue.serverTimestamp(),
        'seatNumberingFormat': 'numeric',
      });

      // 2. Section Document
      final sectionRef = libraryRef.collection('sections').doc();
      final sectionId = sectionRef.id;

      batch.set(sectionRef, {
        'id': sectionId,
        'libraryId': libraryId,
        'name': _sectionName,
        'rows': _rows,
        'cols': _cols,
        'color': _sectionColor,
        'capacity': _rows * _cols,
        'genderRestriction': 'any',
        'namingStyle': 'numeric',
        'createdAt': FieldValue.serverTimestamp(),
      });

      // 3. Seats (Batch write)
      for (int r = 1; r <= _rows; r++) {
        for (int c = 1; c <= _cols; c++) {
          final seatRef = sectionRef.collection('seats').doc();
          batch.set(seatRef, {
            'id': seatRef.id,
            'sectionId': sectionId,
            'label': '$r$c',
            'row': r,
            'col': c,
            'status': 'available',
            'studentId': null,
            'genderRestriction': 'any',
          });
        }
      }

      // 4. Plan Document
      final planRef = libraryRef.collection('plans').doc();
      batch.set(planRef, {
        'id': planRef.id,
        'libraryId': libraryId,
        'name': _planName,
        'price': _price,
        'duration': _durationMonths,
        'durationUnit': 'months',
        'description': '',
        'isActive': true,
        'isFeatured': false,
        'displayOrder': 0,
        'gracePeriodDays': 3,
        'createdAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();

      // Update provider
      ref.read(currentLibraryIdProvider.notifier).set(libraryId);

      if (!mounted) return;
      context.go(Routes.adminHome);

    } catch (e) {
      if (!mounted) return;
      AppSnackbar.showError(context, e);
      setState(() => _isLoading = false);
    }
  }

  void _onStepContinue() {
    if (_currentStep == 0) {
      if (_formKey1.currentState!.validate()) {
        _formKey1.currentState!.save();
        setState(() => _currentStep += 1);
      }
    } else if (_currentStep == 1) {
      setState(() => _currentStep += 1);
    } else if (_currentStep == 2) {
      if (_formKey3.currentState!.validate()) {
        _formKey3.currentState!.save();
        setState(() => _currentStep += 1);
      }
    } else if (_currentStep == 3) {
      if (_formKey4.currentState!.validate()) {
        _formKey4.currentState!.save();
        _saveSetupData();
      }
    }
  }

  void _onStepCancel() {
    if (_currentStep > 0) {
      setState(() => _currentStep -= 1);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Library Setup Wizard'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Stepper(
              currentStep: _currentStep,
              onStepContinue: _onStepContinue,
              onStepCancel: _onStepCancel,
              steps: [
                Step(
                  title: const Text('Basic Info'),
                  content: Form(
                    key: _formKey1,
                    child: Column(
                      children: [
                        TextFormField(
                          decoration: const InputDecoration(
                            labelText: 'Library Name',
                            hintText: 'e.g. Apex Study Lounge',
                          ),
                          validator: (v) => AppValidators.name(v, required: true, label: 'Library Name', min: 3),
                          onSaved: (v) => _libraryName = v!.trim(),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          decoration: const InputDecoration(
                            labelText: 'Address',
                            hintText: 'e.g. Station Road, City',
                          ),
                          validator: (v) => AppValidators.address(v, required: true, label: 'Address', min: 5),
                          onSaved: (v) => _libraryAddress = v!.trim(),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          decoration: const InputDecoration(
                            labelText: 'Phone',
                            hintText: '10-digit mobile number',
                            prefixText: '+91 ',
                          ),
                          inputFormatters: AppValidators.phoneFormatters,
                          keyboardType: TextInputType.phone,
                          validator: (v) => AppValidators.phone(v, label: 'Phone number'),
                          onSaved: (v) => _libraryPhone = v!.trim(),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          decoration: const InputDecoration(
                            labelText: 'Email',
                            hintText: 'e.g. contact@library.com',
                          ),
                          keyboardType: TextInputType.emailAddress,
                          validator: (v) => AppValidators.email(v, required: true),
                          onSaved: (v) => _libraryEmail = v!.trim(),
                        ),
                      ],
                    ),
                  ),
                  isActive: _currentStep >= 0,
                ),
                Step(
                  title: const Text('Branding'),
                  content: Column(
                    children: [
                      const Text('Upload your library logo (Optional)'),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _onStepContinue,
                        icon: const Icon(Icons.skip_next),
                        label: const Text('Skip for now'),
                      ),
                    ],
                  ),
                  isActive: _currentStep >= 1,
                ),
                Step(
                  title: const Text('First Section'),
                  content: Form(
                    key: _formKey3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextFormField(
                          decoration: const InputDecoration(
                            labelText: 'Section Name',
                            hintText: 'e.g. Main Hall, Silent Zone',
                          ),
                          validator: (v) => AppValidators.name(v, required: true, label: 'Section Name', min: 2),
                          onSaved: (v) => _sectionName = v!.trim(),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          decoration: const InputDecoration(labelText: 'Rows (1–50)'),
                          keyboardType: TextInputType.number,
                          inputFormatters: [AppValidators.digitsOnly],
                          validator: (v) {
                            final n = int.tryParse(v ?? '');
                            if (n == null || n < 1 || n > 50) return 'Rows must be between 1 and 50';
                            return null;
                          },
                          onSaved: (v) => _rows = int.parse(v!.trim()),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          decoration: const InputDecoration(labelText: 'Columns (1–50)'),
                          keyboardType: TextInputType.number,
                          inputFormatters: [AppValidators.digitsOnly],
                          validator: (v) {
                            final n = int.tryParse(v ?? '');
                            if (n == null || n < 1 || n > 50) return 'Columns must be between 1 and 50';
                            return null;
                          },
                          onSaved: (v) => _cols = int.parse(v!.trim()),
                        ),
                        const SizedBox(height: 16),
                        const Text('Section Color'),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          children: _colorOptions.map((color) {
                            final isSelected = _sectionColor == color;
                            return GestureDetector(
                              onTap: () {
                                setState(() {
                                  _sectionColor = color;
                                });
                              },
                              child: Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: Color(color),
                                  shape: BoxShape.circle,
                                  border: isSelected
                                      ? Border.all(color: Colors.black, width: 3)
                                      : null,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                  isActive: _currentStep >= 2,
                ),
                Step(
                  title: const Text('First Plan'),
                  content: Form(
                    key: _formKey4,
                    child: Column(
                      children: [
                        TextFormField(
                          decoration: const InputDecoration(
                            labelText: 'Plan Name',
                            hintText: 'e.g. Full Day Monthly',
                          ),
                          validator: (v) => AppValidators.planName(v, required: true),
                          onSaved: (v) => _planName = v!.trim(),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          decoration: const InputDecoration(
                            labelText: 'Price (₹)',
                            prefixText: '₹ ',
                          ),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          inputFormatters: AppValidators.amountFormatters,
                          validator: (v) => AppValidators.amount(v, required: true, min: 1, max: 99999, label: 'Price'),
                          onSaved: (v) => _price = double.parse(v!.trim()),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          initialValue: '1',
                          decoration: const InputDecoration(
                            labelText: 'Duration (Months)',
                            hintText: 'e.g. 1 (Calendar Month)',
                          ),
                          keyboardType: TextInputType.number,
                          inputFormatters: [AppValidators.digitsOnly],
                          validator: (v) => AppValidators.duration(v, min: 1, max: 24, label: 'Duration (Months)'),
                          onSaved: (v) => _durationMonths = int.parse(v!.trim()),
                        ),
                      ],
                    ),
                  ),
                  isActive: _currentStep >= 3,
                ),
              ],
            ),
    );
  }
}
