import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:study_library/core/providers/library_provider.dart';
import 'package:study_library/features/students/presentation/providers/student_providers.dart';
import 'package:study_library/features/plans/presentation/providers/plan_providers.dart';
import 'package:study_library/services/expiry_scheduler_service.dart';

class RenewPlanScreen extends ConsumerStatefulWidget {
  const RenewPlanScreen({super.key});

  @override
  ConsumerState<RenewPlanScreen> createState() => _RenewPlanScreenState();
}

class _RenewPlanScreenState extends ConsumerState<RenewPlanScreen> {
  String? _selectedPlanId;
  bool _keepSeat = true;
  final _notesController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submitRenewal(String libraryId, String studentId, String studentName, String studentPhone, String? currentSeatId) async {
    if (_selectedPlanId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a plan to renew')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final plans = ref.read(plansStreamProvider).value ?? [];
      final selectedPlan = plans.where((p) => p.id == _selectedPlanId).firstOrNull;

      await FirebaseFirestore.instance
          .collection('libraries')
          .doc(libraryId)
          .collection('requests')
          .add({
        'type': 'renewal',
        'studentId': studentId,
        'studentName': studentName,
        'studentPhone': studentPhone,
        'requestedPlanId': _selectedPlanId,
        'requestedPlanName': selectedPlan?.name ?? 'Plan',
        'amount': selectedPlan?.price ?? 0.0,
        'currentSeatId': currentSeatId,
        'keepSeat': _keepSeat,
        'notes': _notesController.text.trim(),
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });

      // The actual expiry date will be set by admin on approval.
      // Schedule a reminder check when student comes back.
      ExpirySchedulerService.cancelExpiryReminders().ignore();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Renewal request submitted! Library admin will verify and update your membership.'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to submit renewal request: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final studentAsync = ref.watch(currentStudentProvider);
    final plansAsync = ref.watch(plansStreamProvider);
    final libraryId = ref.watch(currentLibraryIdProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Renew Membership'),
        centerTitle: true,
      ),
      body: studentAsync.when(
        data: (student) {
          if (student == null || libraryId == null) {
            return const Center(child: Text('Student profile not found'));
          }

          return plansAsync.when(
            data: (plans) {
              final activePlans = plans.where((p) => p.isActive).toList();

              if (_selectedPlanId == null && activePlans.isNotEmpty) {
                // Default to current plan if active, else first plan
                final currentMatches = activePlans.any((p) => p.id == student.planId);
                _selectedPlanId = currentMatches ? student.planId : activePlans.first.id;
              }

              return RadioGroup<String?>(
                groupValue: _selectedPlanId,
                onChanged: (String? val) {
                  if (val != null) setState(() => _selectedPlanId = val);
                },
                child: ListView(
                  padding: const EdgeInsets.all(16),
                children: [
                  // Info banner
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.autorenew_rounded, color: theme.colorScheme.primary),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Select your preferred study plan. Your admin will confirm seat continuity.',
                            style: theme.textTheme.bodyMedium,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  Text('Available Plans', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),

                  if (activePlans.isEmpty)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(24.0),
                        child: Center(child: Text('No active plans currently configured by the library.')),
                      ),
                    )
                  else
                    ...activePlans.map((plan) {
                      final isSelected = _selectedPlanId == plan.id;
                      return Card(
                        elevation: isSelected ? 2 : 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: isSelected ? theme.colorScheme.primary : theme.colorScheme.outlineVariant,
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        margin: const EdgeInsets.only(bottom: 10),
                        child: RadioListTile<String>(
                          value: plan.id,
                          title: Text(plan.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text(
                            '₹${plan.price.toStringAsFixed(0)} • ${plan.duration} ${plan.durationUnit.name}${plan.description.isNotEmpty ? "\n${plan.description}" : ""}',
                          ),
                          isThreeLine: plan.description.isNotEmpty,
                        ),
                      );
                    }),
                  const SizedBox(height: 16),

                  // Seat continuity
                  if (student.seatId != null)
                    Card(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: SwitchListTile(
                        title: const Text('Keep My Current Seat', style: TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: const Text('Retain your allocated desk upon renewal approval'),
                        value: _keepSeat,
                        onChanged: (val) => setState(() => _keepSeat = val),
                      ),
                    ),
                  const SizedBox(height: 16),

                  // Notes
                  TextField(
                    controller: _notesController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Special Note / Requests (Optional)',
                      hintText: 'e.g. Prefer morning shift, payment via UPI ref #...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Submit Button
                  FilledButton.icon(
                    icon: _isSubmitting
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.send_rounded),
                    label: Text(_isSubmitting ? 'Submitting...' : 'Submit Renewal Request'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: _isSubmitting
                        ? null
                        : () => _submitRenewal(
                              libraryId,
                              student.id,
                              student.name,
                              student.phone,
                              student.seatId,
                            ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => Center(child: Text('Error loading plans: $err')),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error loading student: $err')),
      ),
    );
  }
}

