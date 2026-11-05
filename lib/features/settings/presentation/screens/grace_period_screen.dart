import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:study_library/core/providers/library_provider.dart';
import 'package:study_library/features/plans/presentation/providers/plan_providers.dart';
import 'package:study_library/services/membership_automation_service.dart';
import 'package:study_library/core/utils/error_formatter.dart';

class GracePeriodScreen extends ConsumerStatefulWidget {
  const GracePeriodScreen({super.key});

  @override
  ConsumerState<GracePeriodScreen> createState() => _GracePeriodScreenState();
}

class _GracePeriodScreenState extends ConsumerState<GracePeriodScreen> {
  final _defaultController = TextEditingController(text: '3');
  final Map<String, TextEditingController> _planControllers = {};
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isRunningMaintenance = false;

  Future<void> _runMaintenanceNow() async {
    final libraryId = ref.read(currentLibraryIdProvider);
    if (libraryId == null || libraryId.isEmpty) return;

    setState(() => _isRunningMaintenance = true);
    try {
      final result = await MembershipAutomationService.runDailyMaintenance(
        libraryId,
        force: true,
      );

      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            icon: const Icon(Icons.check_circle_rounded, color: Colors.green, size: 44),
            title: const Text('Maintenance Execution Complete', style: TextStyle(fontWeight: FontWeight.bold)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Daily membership validation, grace period calculations, and seat pool deallocations have finished:',
                  style: TextStyle(fontSize: 13, color: Colors.grey),
                ),
                const SizedBox(height: 14),
                _reportRow(Icons.people_outline, 'Active/Grace Checked', '${result.checkedCount}'),
                const SizedBox(height: 8),
                _reportRow(Icons.hourglass_bottom_rounded, 'Moved to Grace', '${result.enteredGraceCount}', color: Colors.orange),
                const SizedBox(height: 8),
                _reportRow(Icons.cancel_outlined, 'Auto-Expired Past Grace', '${result.expiredCount}', color: Colors.red),
                const SizedBox(height: 8),
                _reportRow(Icons.chair_outlined, 'Seats Released to Pool', '${result.releasedSeatsCount}', color: Colors.teal),
              ],
            ),
            actions: [
              FilledButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Done'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        AppErrorFormatter.showErrorSnackBar(context, e, actionContext: 'seat');
      }
    } finally {
      if (mounted) setState(() => _isRunningMaintenance = false);
    }
  }

  Widget _reportRow(IconData icon, String label, String value, {Color? color}) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color ?? Colors.grey.shade700),
        const SizedBox(width: 8),
        Expanded(child: Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500))),
        Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }

  Widget _statBadge(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$label: ', style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w500)),
          Text(value, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _defaultController.dispose();
    for (final c in _planControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final libraryId = ref.read(currentLibraryIdProvider);
    if (libraryId == null || libraryId.isEmpty) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection('libraries')
          .doc(libraryId)
          .collection('settings')
          .doc('grace_period')
          .get();

      if (doc.exists && mounted) {
        final data = doc.data() ?? {};
        _defaultController.text = (data['defaultDays'] ?? 3).toString();
        final overrides = data['planOverrides'] as Map<String, dynamic>? ?? {};
        overrides.forEach((k, v) {
          _planControllers[k] = TextEditingController(text: v.toString());
        });
      }
    } catch (_) {
      // Use defaults if not set yet
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveSettings() async {
    final libraryId = ref.read(currentLibraryIdProvider);
    if (libraryId == null || libraryId.isEmpty) return;

    setState(() => _isSaving = true);
    try {
      final defaultDays = int.tryParse(_defaultController.text.trim()) ?? 3;
      final planOverrides = <String, int>{};
      final batch = FirebaseFirestore.instance.batch();

      for (final entry in _planControllers.entries) {
        final days = int.tryParse(entry.value.text.trim());
        if (days != null) {
          planOverrides[entry.key] = days;
          final planRef = FirebaseFirestore.instance
              .collection('libraries')
              .doc(libraryId)
              .collection('plans')
              .doc(entry.key);
          batch.update(planRef, {
            'gracePeriodDays': days,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      }

      final gracePeriodDocRef = FirebaseFirestore.instance
          .collection('libraries')
          .doc(libraryId)
          .collection('settings')
          .doc('grace_period');

      batch.set(gracePeriodDocRef, {
        'defaultDays': defaultDays,
        'planOverrides': planOverrides,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Also sync defaultGraceDays to root library document for backward compatibility
      final libRef = FirebaseFirestore.instance.collection('libraries').doc(libraryId);
      batch.update(libRef, {
        'defaultGraceDays': defaultDays,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();

      // Trigger instant automation recalculation with new settings
      MembershipAutomationService.runDailyMaintenance(libraryId, force: true).ignore();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Grace period settings saved successfully!'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        AppErrorFormatter.showErrorSnackBar(context, e, actionContext: 'seat');
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final plansAsync = ref.watch(plansStreamProvider);
    final libraryAsync = ref.watch(currentLibraryProvider);
    final library = libraryAsync.value;
    final lastRun = library?.lastAutomationRunDateTime;
    final report = library?.lastMaintenanceReport;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Grace Period Settings'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                // Autonomous Cloud Automation Status Card
                Card(
                  elevation: 0,
                  color: theme.colorScheme.primaryContainer.withValues(alpha: 0.25),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(
                      color: theme.colorScheme.primary.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.green.withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.cloud_done_rounded, color: Colors.green, size: 22),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Autonomous Midnight Engine',
                                    style: theme.textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    'Scheduled daily at 00:01 AM IST • Serverless',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.green.shade700,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.bolt_rounded, size: 14, color: Colors.white),
                                  SizedBox(width: 3),
                                  Text(
                                    'ACTIVE',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Evaluates all student plans every night, applies courtesy buffer days, and auto-releases unrenewed desks to the waiting list without requiring any admin device to be online.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            height: 1.35,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.access_time_rounded, size: 16, color: theme.colorScheme.primary),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      lastRun != null
                                          ? 'Last Run: ${DateFormat('dd MMM yyyy, hh:mm a').format(lastRun.toLocal())}'
                                          : 'Next Run: Tonight at 00:01 AM IST',
                                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                    ),
                                  ),
                                  if (report != null && report['source'] != null)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: theme.colorScheme.secondaryContainer,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        report['source'] == 'cloud_function_scheduler'
                                            ? '☁ Cloud Scheduler'
                                            : '⚡ Manual Run',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: theme.colorScheme.onSecondaryContainer,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              if (report != null) ...[
                                const SizedBox(height: 10),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 6,
                                  children: [
                                    _statBadge('Checked', '${report['totalChecked'] ?? 0}', Colors.blueGrey),
                                    _statBadge('In Grace', '${report['totalGrace'] ?? 0}', Colors.orange),
                                    _statBadge('Expired', '${report['totalExpired'] ?? 0}', Colors.red),
                                    _statBadge('Seats Freed', '${report['totalReleasedSeats'] ?? 0}', Colors.teal),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        Align(
                          alignment: Alignment.centerRight,
                          child: FilledButton.tonalIcon(
                            onPressed: _isRunningMaintenance ? null : _runMaintenanceNow,
                            icon: _isRunningMaintenance
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Icon(Icons.refresh_rounded, size: 18),
                            label: Text(_isRunningMaintenance ? 'Running Maintenance...' : 'Run Maintenance Now'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Card(
                  elevation: 0,
                  color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.hourglass_top_rounded, color: theme.colorScheme.primary),
                            const SizedBox(width: 8),
                            Text('Courtesy Seat Buffer (Grace Period)', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Courtesy days given after membership ends before the reserved desk is released for other students to book.',
                          style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            SizedBox(
                              width: 100,
                              child: TextFormField(
                                controller: _defaultController,
                                keyboardType: TextInputType.number,
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                                decoration: InputDecoration(
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Text('courtesy days after plan ends', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text('Plan-Specific Courtesy Buffers', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(
                  'Customize courtesy buffer days for specific membership tiers:',
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 12),
                plansAsync.when(
                  data: (plans) {
                    if (plans.isEmpty) {
                      return const Card(
                        child: Padding(
                          padding: EdgeInsets.all(20),
                          child: Center(child: Text('No plans created yet.')),
                        ),
                      );
                    }
                    return Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: theme.colorScheme.outlineVariant),
                      ),
                      child: ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: plans.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final plan = plans[index];
                          _planControllers.putIfAbsent(
                            plan.id,
                            () => TextEditingController(
                              text: plan.gracePeriodDays > 0
                                  ? plan.gracePeriodDays.toString()
                                  : _defaultController.text,
                            ),
                          );
                          return ListTile(
                            title: Text(plan.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text('₹${plan.price.toStringAsFixed(0)} • ${plan.duration} ${plan.durationUnit.name}'),
                            trailing: SizedBox(
                              width: 90,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Expanded(
                                    child: TextFormField(
                                      controller: _planControllers[plan.id],
                                      keyboardType: TextInputType.number,
                                      textAlign: TextAlign.center,
                                      decoration: InputDecoration(
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                        isDense: true,
                                        contentPadding: const EdgeInsets.symmetric(vertical: 8),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  const Text('d', style: TextStyle(color: Colors.grey)),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Text('Error loading plans: $e'),
                ),
                const SizedBox(height: 80),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isSaving ? null : _saveSettings,
        icon: _isSaving
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : const Icon(Icons.save_rounded),
        label: Text(_isSaving ? 'Saving...' : 'Save Settings'),
      ),
    );
  }
}
