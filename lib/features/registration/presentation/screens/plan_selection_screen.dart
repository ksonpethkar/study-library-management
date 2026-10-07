import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/registration_provider.dart';
import 'package:study_library/features/plans/presentation/providers/plan_providers.dart';

class PlanSelectionScreen extends ConsumerWidget {
  const PlanSelectionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedPlanId = ref.watch(selectedPlanProvider);
    final plansAsync = ref.watch(plansStreamProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Select Membership Plan')),
      body: Column(
        children: [
          const LinearProgressIndicator(value: 4 / 5),
          Expanded(
            child: plansAsync.when(
              data: (plans) {
                final activePlans = plans.where((p) => p.isActive).toList();

                if (activePlans.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey.shade400),
                          const SizedBox(height: 16),
                          const Text(
                            'No plans currently available',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          const Text('You can continue and the admin will assign a plan later.'),
                          const SizedBox(height: 24),
                          FilledButton(
                            onPressed: () => ref.read(registrationStepProvider.notifier).goTo(5),
                            child: const Text('Continue without Plan'),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return RadioGroup<String>(
                  groupValue: selectedPlanId ?? '',
                  onChanged: (String? val) {
                    if (val != null && val.isNotEmpty) {
                      ref.read(selectedPlanProvider.notifier).select(val);
                    }
                  },
                  child: ListView(
                    padding: const EdgeInsets.all(20.0),
                    children: [
                      Text(
                        'Choose Your Plan',
                        style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Select the membership duration that fits your study schedule.',
                        style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey.shade600),
                      ),
                      const SizedBox(height: 20),
                      ...activePlans.map((plan) {
                        final isSelected = selectedPlanId == plan.id;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 14.0),
                          child: InkWell(
                            onTap: () {
                              ref.read(selectedPlanProvider.notifier).select(plan.id);
                            },
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              padding: const EdgeInsets.all(18),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? theme.colorScheme.primaryContainer.withValues(alpha: 0.35)
                                    : theme.cardColor,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isSelected
                                      ? theme.colorScheme.primary
                                      : theme.dividerColor,
                                  width: isSelected ? 2 : 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Radio<String>(
                                    value: plan.id,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Text(
                                              plan.name,
                                              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                                            ),
                                            if (plan.isFeatured) ...[
                                              const SizedBox(width: 8),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: Colors.amber.shade100,
                                                  borderRadius: BorderRadius.circular(8),
                                                ),
                                                child: Text(
                                                  'POPULAR',
                                                  style: TextStyle(
                                                    color: Colors.amber.shade900,
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Duration: ${plan.duration} ${plan.durationUnit.name}',
                                          style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                                        ),
                                        if (plan.description.isNotEmpty) ...[
                                          const SizedBox(height: 4),
                                          Text(
                                            plan.description,
                                            style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  Text(
                                    '₹${plan.price.toStringAsFixed(0)}',
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w800,
                                      color: theme.colorScheme.primary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        OutlinedButton(
                          onPressed: () => ref.read(registrationStepProvider.notifier).goTo(3),
                          style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14)),
                          child: const Text('Back'),
                        ),
                        FilledButton(
                          onPressed: () => ref.read(registrationStepProvider.notifier).goTo(5),
                          style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14)),
                          child: const Text('Next: Review & Submit ➔'),
                        ),
                      ],
                    ),
                  ],
                ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(child: Text('Error loading plans: $err')),
            ),
          ),
        ],
      ),
    );
  }
}
