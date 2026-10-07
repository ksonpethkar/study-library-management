import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:study_library/models/plan_model.dart';
import 'package:study_library/features/plans/presentation/providers/plan_providers.dart';
import 'package:study_library/core/widgets/empty_state_widget.dart';
import 'package:study_library/core/widgets/confirmation_sheet.dart';
import 'package:study_library/features/plans/presentation/screens/add_plan_screen.dart';

class PlanListScreen extends ConsumerWidget {
  const PlanListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plansAsync = ref.watch(plansStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Subscription Plans'),
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
      body: plansAsync.when(
        data: (plans) {
          if (plans.isEmpty) {
            return EmptyStateWidget(
              icon: Icons.assignment_outlined,
              title: 'No plans yet!',
              message: 'Create your first plan so students can choose when they register.',
              actionLabel: 'Add Plan',
              onAction: () => _navigateToAddPlan(context, null),
            );
          }
          return ReorderableListView.builder(
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
              return Dismissible(
                key: ValueKey(plan.id),
                background: Container(
                  color: Theme.of(context).colorScheme.primary,
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: const Icon(Icons.edit, color: Colors.white),
                ),
                secondaryBackground: Container(
                  color: Theme.of(context).colorScheme.error,
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
                  child: ListTile(
                    onTap: () => _navigateToAddPlan(context, plan),
                    title: Row(
                      children: [
                        Expanded(
                          child: Text(
                            plan.name,
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                        ),
                        if (plan.isFeatured) ...[
                          const SizedBox(width: 8),
                          const Badge(label: Text('Featured')),
                        ]
                      ],
                    ),
                    subtitle: Text('₹${plan.price.toStringAsFixed(2)} • ${plan.duration} ${plan.durationUnit.name}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Tooltip(
                          message: plan.isActive ? 'Active (tap to disable)' : 'Inactive (tap to enable)',
                          child: Switch(
                            value: plan.isActive,
                            onChanged: (val) {
                              ref.read(planActionProvider.notifier).toggleActive(plan.id, val);
                            },
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, size: 20),
                          tooltip: 'Edit / Rename Plan',
                          onPressed: () => _navigateToAddPlan(context, plan),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
                          tooltip: 'Delete Plan',
                          onPressed: () => _confirmAndDelete(context, ref, plan),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('Error: $e')),
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
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Plan "${plan.name}" deleted successfully.')),
          );
        }
        return true;
      } catch (e) {
        if (!context.mounted) return false;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
        return false;
      }
    }
    return false;
  }
}
