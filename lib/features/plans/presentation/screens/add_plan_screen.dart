import 'package:flutter/material.dart';
import 'package:study_library/core/utils/app_validators.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:study_library/models/plan_model.dart';
import 'package:study_library/features/plans/presentation/providers/plan_providers.dart';
import 'package:study_library/core/widgets/validated_text_field.dart';
import 'package:study_library/core/security/audit_logger.dart';
import 'package:study_library/core/providers/library_provider.dart';

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
  late TextEditingController _originalPriceController;
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
    _originalPriceController = TextEditingController(
      text: widget.plan?.originalPrice != null ? widget.plan!.originalPrice!.toStringAsFixed(0) : '',
    );
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
    _originalPriceController.dispose();
    _durationController.dispose();
    _descriptionController.dispose();
    _graceController.dispose();
    super.dispose();
  }

  void _save() async {
    if (_formKey.currentState!.validate()) {
      // L4 FIX: Validate duration and price sanity
      final dur = int.tryParse(_durationController.text.trim()) ?? 0;
      if (dur <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Plan duration must be at least 1 day/month.')),
        );
        return;
      }
      final price = double.tryParse(_priceController.text.trim()) ?? -1;
      if (price <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Plan fee must be greater than ₹0.')),
        );
        return;
      }

      String planName = _nameController.text.trim();
      if (planName.toLowerCase() == 'quaterly') {
        planName = 'Quarterly';
      }

      final plan = PlanModel(
        id: widget.plan?.id ?? '',
        libraryId: widget.plan?.libraryId ?? '',
        name: planName,
        duration: int.parse(_durationController.text),
        durationUnit: _durationUnit,
        price: double.parse(_priceController.text),
        originalPrice: double.tryParse(_originalPriceController.text.trim()),
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
        // Audit log
        final libraryId = ref.read(currentLibraryIdProvider) ?? '';
        AuditLogger().log(
          action: widget.plan == null ? AuditAction.created : AuditAction.updated,
          entityType: AuditEntity.plan,
          libraryId: libraryId,
          entityId: plan.id.isNotEmpty ? plan.id : plan.name,
          details: {'planName': plan.name, 'price': plan.price, 'duration': plan.duration},
        ).ignore();
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
                      textCapitalization: TextCapitalization.words,
                      validator: AppValidators.planName,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: ValidatedTextField(
                            label: 'Duration',
                            controller: _durationController,
                            keyboardType: TextInputType.number,
                            inputFormatters: [AppValidators.digitsOnly],
                            validator: (val) => AppValidators.duration(val, min: 1, max: 365),
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: DropdownButtonFormField<DurationUnit>(
                            initialValue: _durationUnit,
                            decoration: const InputDecoration(labelText: 'Billing Cycle Unit'),
                            items: [
                              const DropdownMenuItem(
                                value: DurationUnit.months,
                                child: Text('Calendar Month(s)'),
                              ),
                              if (_durationUnit == DurationUnit.days)
                                const DropdownMenuItem(
                                  value: DurationUnit.days,
                                  child: Text('Days (Legacy 30-Day)'),
                                ),
                              if (_durationUnit == DurationUnit.weeks)
                                const DropdownMenuItem(
                                  value: DurationUnit.weeks,
                                  child: Text('Weeks (Legacy)'),
                                ),
                            ],
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
                      inputFormatters: AppValidators.amountFormatters,
                      validator: AppValidators.price,
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 16),
                    ValidatedTextField(
                      label: 'Original Price / MRP (Optional - for cut text)',
                      controller: _originalPriceController,
                      keyboardType: TextInputType.number,
                      inputFormatters: AppValidators.amountFormatters,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return null;
                        final p = double.tryParse(v.trim());
                        if (p == null || p <= 0) return 'Enter a valid original price (> 0)';
                        return null;
                      },
                      onChanged: (_) => setState(() {}),
                    ),
                    Builder(builder: (context) {
                      final p = double.tryParse(_priceController.text) ?? 0;
                      final op = double.tryParse(_originalPriceController.text) ?? 0;
                      final dur = int.tryParse(_durationController.text) ?? 1;
                      int cycleDays = 30;
                      if (_durationUnit == DurationUnit.days) {
                        cycleDays = dur > 0 ? dur : 1;
                      } else if (_durationUnit == DurationUnit.weeks) {
                        cycleDays = dur > 0 ? dur * 7 : 7;
                      } else {
                        if (dur == 1) {
                          cycleDays = 30;
                        } else if (dur == 3) {
                          cycleDays = 90;
                        } else if (dur == 6) {
                          cycleDays = 180;
                        } else if (dur == 12) {
                          cycleDays = 365;
                        } else {
                          cycleDays = dur * 30;
                        }
                      }
                      final dailyRate = p > 0 && cycleDays > 0 ? (p / cycleDays) : 0.0;

                      if (p > 0) {
                        final hasDiscount = op > p;
                        final disc = hasDiscount ? (((op - p) / op) * 100).round() : 0;
                        final saved = hasDiscount ? (op - p) : 0.0;

                        return Container(
                          margin: const EdgeInsets.only(top: 10),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.green.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.calculate_rounded, color: Colors.green, size: 18),
                                  const SizedBox(width: 6),
                                  const Text(
                                    'Live Pricing Breakdown',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.green),
                                  ),
                                  const Spacer(),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: Colors.green.shade300, width: 0.8),
                                    ),
                                    child: Text(
                                      '⚡ ₹${dailyRate.toStringAsFixed(1)} / day',
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.green.shade900,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              if (hasDiscount) ...[
                                const SizedBox(height: 8),
                                Wrap(
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  spacing: 8,
                                  runSpacing: 4,
                                  children: [
                                    const Text(
                                      'Display Discount:',
                                      style: TextStyle(fontSize: 12, color: Colors.black87),
                                    ),
                                    Text(
                                      '₹${op.toStringAsFixed(0)}',
                                      style: const TextStyle(
                                        decoration: TextDecoration.lineThrough,
                                        color: Colors.grey,
                                        fontSize: 13,
                                      ),
                                    ),
                                    Text(
                                      '₹${p.toStringAsFixed(0)}',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.green),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.green,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        '$disc% OFF (Save ₹${saved.toStringAsFixed(0)})',
                                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        );
                      }
                      return const SizedBox.shrink();
                    },
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
