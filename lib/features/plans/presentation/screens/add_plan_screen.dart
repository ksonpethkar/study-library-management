import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:study_library/models/plan_model.dart';
import 'package:study_library/features/plans/presentation/providers/plan_providers.dart';
import 'package:study_library/core/widgets/validated_text_field.dart';

class AddPlanScreen extends ConsumerStatefulWidget {
  final PlanModel? plan;
  const AddPlanScreen({super.key, this.plan});

  @override
  ConsumerState<AddPlanScreen> createState() => _AddPlanScreenState();
}

class _AddPlanScreenState extends ConsumerState<AddPlanScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _priceController;
  late TextEditingController _durationController;
  late TextEditingController _descriptionController;
  late TextEditingController _graceController;
  
  DurationUnit _durationUnit = DurationUnit.months;
  bool _isActive = true;
  bool _isFeatured = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.plan?.name);
    _priceController = TextEditingController(text: widget.plan?.price.toString());
    _durationController = TextEditingController(text: widget.plan?.duration.toString());
    _descriptionController = TextEditingController(text: widget.plan?.description);
    _graceController = TextEditingController(text: widget.plan?.gracePeriodDays.toString());
    if (widget.plan != null) {
      _durationUnit = widget.plan!.durationUnit;
      _isActive = widget.plan!.isActive;
      _isFeatured = widget.plan!.isFeatured;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _durationController.dispose();
    _descriptionController.dispose();
    _graceController.dispose();
    super.dispose();
  }

  void _save() async {
    if (_formKey.currentState!.validate()) {
      final plan = PlanModel(
        id: widget.plan?.id ?? '',
        libraryId: widget.plan?.libraryId ?? '',
        name: _nameController.text.trim(),
        duration: int.parse(_durationController.text),
        durationUnit: _durationUnit,
        price: double.parse(_priceController.text),
        description: _descriptionController.text.trim(),
        gracePeriodDays: int.tryParse(_graceController.text) ?? 0,
        isActive: _isActive,
        isFeatured: _isFeatured,
        displayOrder: widget.plan?.displayOrder ?? 0,
      );

      final notifier = ref.read(planActionProvider.notifier);
      if (widget.plan == null) {
        await notifier.createPlan(plan);
      } else {
        await notifier.updatePlan(plan);
      }
      
      final state = ref.read(planActionProvider);
      if (!mounted) return;
      if (state.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(state.error!)));
      } else {
        Navigator.of(context).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(planActionProvider);
    
    return Scaffold(
      appBar: AppBar(title: Text(widget.plan == null ? 'Add Plan' : 'Edit Plan')),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    ValidatedTextField(
                      label: 'Plan Name',
                      controller: _nameController,
                      validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: ValidatedTextField(
                            label: 'Duration',
                            controller: _durationController,
                            keyboardType: TextInputType.number,
                            validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: DropdownButtonFormField<DurationUnit>(
                            initialValue: _durationUnit,
                            decoration: const InputDecoration(labelText: 'Unit'),
                            items: DurationUnit.values.map((u) {
                              return DropdownMenuItem(value: u, child: Text(u.name));
                            }).toList(),
                            onChanged: (val) => setState(() => _durationUnit = val!),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    ValidatedTextField(
                      label: 'Price (₹)',
                      controller: _priceController,
                      keyboardType: TextInputType.number,
                      validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),
                    ValidatedTextField(
                      label: 'Grace Period (Days)',
                      controller: _graceController,
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 16),
                    ValidatedTextField(
                      label: 'Description',
                      controller: _descriptionController,
                      maxLines: 3,
                    ),
                    const SizedBox(height: 16),
                    SwitchListTile(
                      title: const Text('Active'),
                      value: _isActive,
                      onChanged: (val) => setState(() => _isActive = val),
                    ),
                    SwitchListTile(
                      title: const Text('Featured'),
                      value: _isFeatured,
                      onChanged: (val) => setState(() => _isFeatured = val),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _save,
                        child: const Text('Save Plan'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
