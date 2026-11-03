import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/registration_provider.dart';
import 'package:study_library/features/plans/presentation/providers/plan_providers.dart';
import 'package:study_library/services/plan_calculator_service.dart';
import 'package:study_library/core/error/error_handler.dart';

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

                final baseMonthly = PlanCalculatorService.getBaseMonthlyPrice(activePlans);

                return RadioGroup<String>(
                  groupValue: selectedPlanId ?? '',
                  onChanged: (String? val) {
                    if (val != null && val.isNotEmpty) {
                      ref.read(selectedPlanProvider.notifier).select(val);
                    }
                  },
                  child: ListView(
                    padding: const EdgeInsets.all(16.0),
                    children: [
                      Text(
                        'Choose Your Plan',
                        style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Select the study pass duration that fits your schedule. Multi-month plans include exclusive savings.',
                        style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey.shade600),
                      ),
                      const SizedBox(height: 18),
                      ...activePlans.map((plan) {
                        final isSelected = selectedPlanId == plan.id;
                        final origPrice = plan.getEffectiveOriginalPrice(baseMonthlyPrice: baseMonthly);
                        final discPercent = plan.getDiscountPercent(baseMonthlyPrice: baseMonthly);
                        final saved = plan.getSavingsAmount(baseMonthlyPrice: baseMonthly);
                        final hasDiscount = origPrice != null && origPrice > plan.price;
                        final dailyRate = PlanCalculatorService.getDailyRate(plan);
                        final smartCalc = PlanCalculatorService.calculateSmartPlan(plan: plan);

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12.0),
                          child: InkWell(
                            onTap: () {
                              ref.read(selectedPlanProvider.notifier).select(plan.id);
                            },
                            borderRadius: BorderRadius.circular(16),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? theme.colorScheme.primaryContainer.withValues(alpha: 0.35)
                                    : theme.cardColor,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isSelected
                                      ? theme.colorScheme.primary
                                      : theme.colorScheme.outlineVariant.withValues(alpha: 0.7),
                                  width: isSelected ? 2 : 1,
                                ),
                                boxShadow: isSelected
                                    ? [
                                        BoxShadow(
                                          color: theme.colorScheme.primary.withValues(alpha: 0.15),
                                          blurRadius: 10,
                                          offset: const Offset(0, 3),
                                        ),
                                      ]
                                    : [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.02),
                                          blurRadius: 4,
                                          offset: const Offset(0, 1),
                                        ),
                                      ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Row 1: Radio + Title + Duration + Popular Badge
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    children: [
                                      Radio<String>(
                                        value: plan.id,
                                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                        visualDensity: VisualDensity.compact,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Wrap(
                                          crossAxisAlignment: WrapCrossAlignment.center,
                                          spacing: 8,
                                          runSpacing: 4,
                                          children: [
                                            Text(
                                              plan.displayName,
                                              style: TextStyle(
                                                fontSize: 16.5,
                                                fontWeight: FontWeight.bold,
                                                color: isSelected ? theme.colorScheme.primary : null,
                                              ),
                                            ),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                                              decoration: BoxDecoration(
                                                color: theme.colorScheme.primaryContainer.withValues(alpha: 0.6),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                '${plan.duration} ${plan.durationUnit.name}',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w700,
                                                  color: theme.colorScheme.primary,
                                                ),
                                              ),
                                            ),
                                            if (plan.isFeatured)
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                                                decoration: BoxDecoration(
                                                  gradient: const LinearGradient(
                                                    colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
                                                  ),
                                                  borderRadius: BorderRadius.circular(6),
                                                  boxShadow: [
                                                    BoxShadow(
                                                      color: Colors.amber.withValues(alpha: 0.25),
                                                      blurRadius: 4,
                                                      offset: const Offset(0, 1),
                                                    ),
                                                  ],
                                                ),
                                                child: const Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Icon(Icons.star_rounded, size: 12, color: Colors.white),
                                                    SizedBox(width: 3),
                                                    Text(
                                                      'POPULAR',
                                                      style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),

                                  // Row 2: Description (if present)
                                  if (plan.description.trim().isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    Container(
                                      width: double.infinity,
                                      margin: const EdgeInsets.only(left: 36),
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Padding(
                                            padding: const EdgeInsets.only(top: 2),
                                            child: Icon(Icons.check_circle_outline_rounded, size: 13, color: theme.colorScheme.primary),
                                          ),
                                          const SizedBox(width: 6),
                                          Expanded(
                                            child: Text(
                                              plan.description.trim(),
                                              style: TextStyle(
                                                fontSize: 12,
                                                height: 1.35,
                                                color: theme.colorScheme.onSurfaceVariant,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],

                                  const SizedBox(height: 12),
                                  const Divider(height: 1, thickness: 0.8),
                                  const SizedBox(height: 10),

                                  // Row 3: Pricing Hero Section
                                  Padding(
                                    padding: const EdgeInsets.only(left: 36),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.center,
                                      children: [
                                        // Left: Pricing Details & Daily Rate
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Wrap(
                                                crossAxisAlignment: WrapCrossAlignment.center,
                                                spacing: 8,
                                                runSpacing: 4,
                                                children: [
                                                  if (hasDiscount) ...[
                                                    Text(
                                                      '₹${origPrice.toStringAsFixed(0)}',
                                                      style: TextStyle(
                                                        decoration: TextDecoration.lineThrough,
                                                        decorationColor: Colors.grey.shade500,
                                                        color: Colors.grey.shade500,
                                                        fontSize: 13,
                                                        fontWeight: FontWeight.w500,
                                                        fontFeatures: const [FontFeature.tabularFigures()],
                                                      ),
                                                    ),
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                                                      decoration: BoxDecoration(
                                                        color: Colors.green.shade50,
                                                        borderRadius: BorderRadius.circular(6),
                                                        border: Border.all(color: Colors.green.shade300, width: 0.8),
                                                      ),
                                                      child: Text(
                                                        '${discPercent ?? 0}% OFF • Save ₹${saved?.toStringAsFixed(0) ?? '0'}',
                                                        style: TextStyle(
                                                          color: Colors.green.shade800,
                                                          fontSize: 11,
                                                          fontWeight: FontWeight.w800,
                                                          fontFeatures: const [FontFeature.tabularFigures()],
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ],
                                              ),
                                              const SizedBox(height: 4),
                                              Wrap(
                                                crossAxisAlignment: WrapCrossAlignment.center,
                                                spacing: 8,
                                                runSpacing: 4,
                                                children: [
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: Colors.grey.shade100,
                                                      borderRadius: BorderRadius.circular(6),
                                                      border: Border.all(color: Colors.grey.shade300, width: 0.8),
                                                    ),
                                                    child: Text(
                                                      '₹${dailyRate.toStringAsFixed(1)} / day',
                                                      style: TextStyle(
                                                        fontSize: 11,
                                                        fontWeight: FontWeight.w600,
                                                        color: Colors.grey.shade800,
                                                        fontFeatures: const [FontFeature.tabularFigures()],
                                                      ),
                                                    ),
                                                  ),
                                                  if (plan.gracePeriodDays > 0)
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                      decoration: BoxDecoration(
                                                        color: Colors.blue.shade50,
                                                        borderRadius: BorderRadius.circular(6),
                                                        border: Border.all(color: Colors.blue.shade200, width: 0.8),
                                                      ),
                                                      child: Text(
                                                        '+${plan.gracePeriodDays}d Grace',
                                                        style: TextStyle(
                                                          fontSize: 10.5,
                                                          fontWeight: FontWeight.bold,
                                                          color: Colors.blue.shade900,
                                                        ),
                                                      ),
                                                    ),
                                                ],
                                              ),
                                              if (smartCalc.isProrated) ...[
                                                const SizedBox(height: 5),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                                                  decoration: BoxDecoration(
                                                    color: Colors.amber.shade50,
                                                    borderRadius: BorderRadius.circular(6),
                                                    border: Border.all(color: Colors.amber.shade400, width: 0.8),
                                                  ),
                                                  child: Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      Icon(Icons.calendar_month_rounded, size: 12, color: Colors.amber.shade900),
                                                      const SizedBox(width: 4),
                                                      Text(
                                                        smartCalc.hasBridgeOption
                                                            ? 'Pro-rata ₹${smartCalc.formattedProratedPrice} (${smartCalc.daysRemaining}d) • Bridge Pass Option'
                                                            : 'Pro-rata: ₹${smartCalc.formattedProratedPrice} (${smartCalc.daysRemaining}d to month-end)',
                                                        style: TextStyle(
                                                          fontSize: 10.5,
                                                          fontWeight: FontWeight.bold,
                                                          color: Colors.amber.shade900,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),

                                        // Right: Final Bold Price
                                        Text(
                                          '₹${plan.price.toStringAsFixed(0)}',
                                          style: TextStyle(
                                            fontSize: 22,
                                            fontWeight: FontWeight.w900,
                                            color: hasDiscount ? Colors.green.shade800 : theme.colorScheme.primary,
                                            fontFeatures: const [FontFeature.tabularFigures()],
                                          ),
                                        ),
                                      ],
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
                            child: const Text('Next: Choose Desk ➔'),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    ErrorHandler.handleError(err),
                    textAlign: TextAlign.center,
                    style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 13),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
