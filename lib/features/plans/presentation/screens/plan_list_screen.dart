import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:study_library/models/plan_model.dart';
import 'package:study_library/features/plans/presentation/providers/plan_providers.dart';
import 'package:study_library/core/widgets/empty_state_widget.dart';
import 'package:study_library/core/widgets/loading_skeleton.dart';
import 'package:study_library/core/widgets/confirmation_sheet.dart';
import 'package:study_library/features/plans/presentation/screens/add_plan_screen.dart';
import 'package:study_library/services/plan_calculator_service.dart';
import 'package:study_library/core/error/error_handler.dart';

class PlanListScreen extends ConsumerWidget {
  const PlanListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plansAsync = ref.watch(plansStreamProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Membership Plans'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              context.go('/admin/home');
            }
          },
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(plansStreamProvider),
        child: plansAsync.when(
          data: (plans) {
            if (plans.isEmpty) {
              return SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: SizedBox(
                  height: 400,
                  child: EmptyStateWidget(
                    icon: Icons.assignment_outlined,
                    title: 'No plans yet!',
                    message: 'Create your first plan so students can choose when they register.',
                    actionLabel: 'Add Plan',
                    onAction: () => _navigateToAddPlan(context, null),
                  ),
                ),
              );
            }

            final baseMonthly = PlanCalculatorService.getBaseMonthlyPrice(plans);

            return ReorderableListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 12),
              itemCount: plans.length,
              onReorderItem: (oldIndex, newIndex) {
                if (newIndex > oldIndex) newIndex -= 1;
                final list = List<PlanModel>.from(plans);
                final item = list.removeAt(oldIndex);
                list.insert(newIndex, item);
                ref.read(planActionProvider.notifier).reorder(list.map((e) => e.id).toList());
              },
              itemBuilder: (context, index) {
                final plan = plans[index];
                final origPrice = plan.getEffectiveOriginalPrice(baseMonthlyPrice: baseMonthly);
                final discPercent = plan.getDiscountPercent(baseMonthlyPrice: baseMonthly);
                final saved = plan.getSavingsAmount(baseMonthlyPrice: baseMonthly);
                final hasDiscount = origPrice != null && origPrice > plan.price;
                final dailyRate = PlanCalculatorService.getDailyRate(plan);

                return Dismissible(
                  key: ValueKey(plan.id),
                  background: Container(
                    color: theme.colorScheme.primary,
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: const Icon(Icons.edit, color: Colors.white),
                  ),
                  secondaryBackground: Container(
                    color: theme.colorScheme.error,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  confirmDismiss: (direction) async {
                    if (direction == DismissDirection.endToStart) {
                      return await _confirmAndDelete(context, ref, plan);
                    } else {
                      _navigateToAddPlan(context, plan);
                      return false;
                    }
                  },
                  child: Card(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(
                        color: plan.isActive
                            ? theme.colorScheme.outlineVariant.withValues(alpha: 0.7)
                            : theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
                        width: plan.isActive ? 1.2 : 1,
                      ),
                    ),
                    child: InkWell(
                      onTap: () => _navigateToAddPlan(context, plan),
                      borderRadius: BorderRadius.circular(16),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // ── 1. Header: Plan Name, Badges & Status Switch ──
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Expanded(
                                  child: Wrap(
                                    crossAxisAlignment: WrapCrossAlignment.center,
                                    spacing: 8,
                                    runSpacing: 4,
                                    children: [
                                      Text(
                                        plan.displayName,
                                        style: theme.textTheme.titleMedium?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 17,
                                          color: plan.isActive ? null : theme.colorScheme.outline,
                                        ),
                                      ),
                                      // Duration Badge
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                                        decoration: BoxDecoration(
                                          color: theme.colorScheme.primaryContainer.withValues(alpha: 0.5),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          '${plan.duration} ${plan.durationUnit.name}',
                                          style: TextStyle(
                                            fontSize: 11.5,
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

                                // Status Indicator & Switch
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: plan.isActive
                                            ? Colors.green.withValues(alpha: 0.12)
                                            : Colors.grey.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Container(
                                            width: 7,
                                            height: 7,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: plan.isActive ? Colors.green.shade700 : Colors.grey,
                                            ),
                                          ),
                                          const SizedBox(width: 5),
                                          Text(
                                            plan.isActive ? 'Active' : 'Hidden',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: plan.isActive ? Colors.green.shade800 : Colors.grey.shade600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 2),
                                    Transform.scale(
                                      scale: 0.82,
                                      child: Switch(
                                        value: plan.isActive,
                                        onChanged: (val) {
                                          ref.read(planActionProvider.notifier).toggleActive(plan.id, val);
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),

                            // ── 2. Description Block (if present) ──
                            if (plan.description.trim().isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Container(
                                width: double.infinity,
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
                                      child: Icon(Icons.check_circle_outline_rounded, size: 14, color: theme.colorScheme.primary),
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        plan.description.trim(),
                                        style: theme.textTheme.bodySmall?.copyWith(
                                          color: theme.colorScheme.onSurfaceVariant,
                                          fontSize: 12,
                                          height: 1.35,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],

                            const SizedBox(height: 12),
                            Divider(height: 1, color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4)),
                            const SizedBox(height: 12),

                            // ── 3. Pricing Hero Block: Final Price, Cut Mark, Discount & Daily Rate ──
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Expanded(
                                  child: Wrap(
                                    crossAxisAlignment: WrapCrossAlignment.center,
                                    spacing: 8,
                                    runSpacing: 4,
                                    children: [
                                      // Discounted / Current Price
                                      Text(
                                        '₹${plan.price.toStringAsFixed(0)}',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w900,
                                          fontSize: 22,
                                          color: hasDiscount ? Colors.green.shade700 : theme.colorScheme.primary,
                                          fontFeatures: const [FontFeature.tabularFigures()],
                                        ),
                                      ),

                                      // Cut Price / Original MRP Strikethrough
                                      if (hasDiscount)
                                        Text(
                                          '₹${origPrice.toStringAsFixed(0)}',
                                          style: TextStyle(
                                            decoration: TextDecoration.lineThrough,
                                            decorationColor: Colors.grey.shade500,
                                            decorationThickness: 1.8,
                                            color: Colors.grey.shade500,
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500,
                                            fontFeatures: const [FontFeature.tabularFigures()],
                                          ),
                                        ),

                                      // Discount Pill (% OFF & Amount Saved)
                                      if (hasDiscount && discPercent != null)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: Colors.green.shade50,
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(color: Colors.green.shade400, width: 0.9),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.local_offer_outlined, size: 11, color: Colors.green.shade800),
                                              const SizedBox(width: 4),
                                              Text(
                                                '$discPercent% OFF • Save ₹${saved?.toStringAsFixed(0)}',
                                                style: TextStyle(
                                                  color: Colors.green.shade900,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 10.5,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                    ],
                                  ),
                                ),

                                // Daily Rate Benchmark Chip
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        '₹${dailyRate.toStringAsFixed(1)}',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                          color: theme.colorScheme.onSurface,
                                          fontFeatures: const [FontFeature.tabularFigures()],
                                        ),
                                      ),
                                      Text(
                                        '/ day',
                                        style: TextStyle(fontSize: 10, color: theme.colorScheme.outline),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 10),

                            // ── 4. Footer Row: Grace period + Action Buttons (Edit & Delete) ──
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                if (plan.gracePeriodDays > 0)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.shade50,
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: Colors.blue.shade200, width: 0.8),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.hourglass_bottom_rounded, size: 11, color: Colors.blue.shade800),
                                        const SizedBox(width: 4),
                                        Text(
                                          '+${plan.gracePeriodDays}d Grace',
                                          style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Colors.blue.shade900),
                                        ),
                                      ],
                                    ),
                                  )
                                else
                                  const SizedBox.shrink(),

                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    OutlinedButton.icon(
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                        visualDensity: VisualDensity.compact,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                      ),
                                      icon: const Icon(Icons.edit_outlined, size: 14),
                                      label: const Text('Edit', style: TextStyle(fontSize: 12)),
                                      onPressed: () => _navigateToAddPlan(context, plan),
                                    ),
                                    const SizedBox(width: 6),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline_rounded, size: 19, color: Colors.red),
                                      tooltip: 'Delete Plan',
                                      visualDensity: VisualDensity.compact,
                                      onPressed: () => _confirmAndDelete(context, ref, plan),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            );
          },
          loading: () => const CardListSkeleton(),
          error: (e, st) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                ErrorHandler.handleError(e),
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
              ),
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _navigateToAddPlan(context, null),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _navigateToAddPlan(BuildContext context, PlanModel? plan) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => AddPlanScreen(plan: plan),
    ));
  }

  Future<bool> _confirmAndDelete(BuildContext context, WidgetRef ref, PlanModel plan) async {
    bool confirm = false;
    await ConfirmationSheet.show(
      context,
      title: 'Delete Plan',
      message: 'Are you sure you want to delete "${plan.name}"? Active students will not be affected, but no new registrations can use this.',
      confirmLabel: 'Delete',
      isDestructive: true,
      onConfirm: () {
        confirm = true;
      },
    );
    if (confirm) {
      try {
        await ref.read(planActionProvider.notifier).deletePlan(plan.id);
        if (context.mounted) {
          AppSnackbar.showSuccess(context, 'Plan "${plan.name}" deleted successfully.');
        }
        return true;
      } catch (e) {
        if (!context.mounted) return false;
        AppSnackbar.showError(context, e);
        return false;
      }
    }
    return false;
  }
}
