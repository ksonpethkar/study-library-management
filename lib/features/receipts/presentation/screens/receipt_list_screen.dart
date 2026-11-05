import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:study_library/core/providers/library_provider.dart';
import 'package:study_library/models/receipt_model.dart';
import 'package:study_library/features/receipts/data/repositories/receipt_repository.dart';
import 'package:study_library/features/students/presentation/providers/student_providers.dart';
import 'package:study_library/core/widgets/empty_state_widget.dart';
import 'package:study_library/core/widgets/loading_skeleton.dart';
import 'package:study_library/core/widgets/staggered_list_item.dart';
import 'package:study_library/core/error/error_handler.dart';

final receiptListProvider = StreamProvider<List<ReceiptModel>>((ref) {
  final libraryId = ref.watch(currentLibraryIdProvider) ?? '';
  if (libraryId.isEmpty) return const Stream.empty();
  return ReceiptRepository().getReceipts(libraryId);
});

class ReceiptListScreen extends ConsumerStatefulWidget {
  const ReceiptListScreen({super.key});

  @override
  ConsumerState<ReceiptListScreen> createState() => _ReceiptListScreenState();
}

class _ReceiptListScreenState extends ConsumerState<ReceiptListScreen> {
  final _dateFormat = DateFormat('dd MMM yyyy');

  void _showAdminActions(BuildContext context, ReceiptModel receipt, String libraryId) {
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Center(
              child: Container(
                width: 40, height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: Row(
                children: [
                  Text(receipt.receiptNumber,
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  const Spacer(),
                  Text('₹${receipt.amount.toStringAsFixed(0)}',
                      style: theme.textTheme.titleMedium
                          ?.copyWith(color: theme.colorScheme.primary, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            const Divider(height: 1),

            // View PDF
            ListTile(
              leading: const Icon(Icons.picture_as_pdf_rounded),
              title: const Text('View / Share PDF'),
              onTap: () {
                Navigator.pop(ctx);
                context.push('/admin/receipts/${receipt.id}');
              },
            ),

            // Edit Notes
            ListTile(
              leading: const Icon(Icons.edit_note_rounded),
              title: const Text('Edit Admin Notes'),
              onTap: () {
                Navigator.pop(ctx);
                _showEditNotesDialog(context, receipt, libraryId);
              },
            ),

            // Void / Unvoid
            if (receipt.status == ReceiptStatus.active)
              ListTile(
                leading: const Icon(Icons.cancel_outlined, color: Colors.orange),
                title: const Text('Void Receipt'),
                subtitle: const Text('Mark as invalid with a reason'),
                textColor: Colors.orange.shade800,
                onTap: () {
                  Navigator.pop(ctx);
                  _showVoidDialog(context, receipt, libraryId);
                },
              )
            else
              ListTile(
                leading: const Icon(Icons.restore_rounded, color: Colors.green),
                title: const Text('Unvoid Receipt'),
                subtitle: const Text('Restore to active status'),
                textColor: Colors.green.shade800,
                onTap: () async {
                  Navigator.pop(ctx);
                  await ReceiptRepository().unvoidReceipt(libraryId, receipt.id);
                  if (context.mounted) {
                    AppSnackbar.showSuccess(context, 'Receipt restored to active');
                  }
                },
              ),

            // Delete
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded, color: Colors.red),
              title: const Text('Delete Receipt'),
              subtitle: const Text('Move to recycle bin'),
              textColor: Colors.red,
              onTap: () {
                Navigator.pop(ctx);
                _confirmDelete(context, receipt, libraryId);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showEditNotesDialog(BuildContext context, ReceiptModel receipt, String libraryId) {
    final ctrl = TextEditingController(
      text: receipt.customFields['adminNotes']?.toString() ?? '',
    );
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Admin Notes'),
        content: TextField(
          controller: ctrl,
          maxLines: 4,
          decoration: const InputDecoration(
            hintText: 'Internal notes (not shown on receipt)',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              await ReceiptRepository().updateReceiptNotes(libraryId, receipt.id, ctrl.text.trim());
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showVoidDialog(BuildContext context, ReceiptModel receipt, String libraryId) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Void Receipt'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(
            labelText: 'Reason for voiding',
            hintText: 'e.g. Duplicate receipt, payment reversed',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.orange),
            onPressed: () async {
              await ReceiptRepository().voidReceipt(
                libraryId, receipt.id, reason: ctrl.text.trim(),
              );
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Void'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, ReceiptModel receipt, String libraryId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Receipt'),
        content: Text(
          'Delete ${receipt.receiptNumber}? This moves it to the recycle bin.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              await ReceiptRepository().deleteReceipt(libraryId, receipt.id);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final libraryId = ref.watch(currentLibraryIdProvider) ?? '';
    final receiptsAsync = ref.watch(receiptListProvider);
    // Build a synchronous studentId→name lookup from the already-watched students stream.
    // This eliminates the per-row FutureBuilder that caused scroll flicker (P6 fix).
    final studentNameMap = {
      for (final s in ref.watch(studentsStreamProvider).value ?? []) s.id: s.name,
    };

    return Scaffold(
      appBar: AppBar(
        title: const Text('Receipts'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list_rounded),
            tooltip: 'Filter',
            onPressed: () {}, // placeholder for future filter
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(receiptListProvider),
        child: receiptsAsync.when(
          data: (receipts) {
            if (receipts.isEmpty) {
              return SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: const SizedBox(
                  height: 400,
                  child: EmptyStateWidget(
                    icon: Icons.receipt_long,
                    title: 'No receipts yet',
                    message: 'When payments are recorded, generated receipts will appear here.',
                  ),
                ),
              );
            }
            return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: receipts.length,
            itemBuilder: (context, index) {
              final receipt = receipts[index];
              final isVoided = receipt.status == ReceiptStatus.voided;
              // Synchronous name lookup — no per-row async, no scroll flicker (P6 fix)
              final studentName = studentNameMap[receipt.studentId] ?? 'Student';
              return StaggeredListItem(
                index: index,
                child: Opacity(
                  opacity: isVoided ? 0.72 : 1.0,
                  child: Card(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 6),
                      onTap: () => context.push('/admin/receipts/${receipt.id}'),
                      leading: CircleAvatar(
                        backgroundColor: isVoided
                            ? Colors.red.shade50
                            : Colors.green.withValues(alpha: 0.12),
                        child: Icon(
                          isVoided
                              ? Icons.block_rounded
                              : Icons.receipt_rounded,
                          color: isVoided ? Colors.red.shade700 : Colors.green,
                        ),
                      ),
                      title: Row(
                        children: [
                          Expanded(
                            child: Text(
                              studentName,
                              style: const TextStyle(fontWeight: FontWeight.w600),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            '₹${receipt.amount.toStringAsFixed(0)}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              decoration: isVoided ? TextDecoration.lineThrough : null,
                              decorationColor: isVoided ? Colors.red.shade700 : null,
                              decorationThickness: 2,
                              color: isVoided
                                  ? Colors.grey.shade600
                                  : Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${receipt.receiptNumber} · ${receipt.paymentMethod}',
                            style: const TextStyle(fontSize: 12),
                          ),
                          Text(
                            'Valid: ${_dateFormat.format(receipt.validFrom)} – ${_dateFormat.format(receipt.validTo)}',
                            style: const TextStyle(fontSize: 11),
                          ),
                          if (receipt.securityDeposit != null && receipt.securityDeposit! > 0)
                            Padding(
                              padding: const EdgeInsets.only(top: 3),
                              child: Row(
                                children: [
                                  Icon(Icons.shield_outlined, size: 12, color: Colors.amber.shade800),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Incl. ₹${receipt.securityDeposit!.toStringAsFixed(0)} Deposit (Refundable)',
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.amber.shade900,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          if (isVoided)
                            Container(
                              margin: const EdgeInsets.only(top: 4),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.red.shade50,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: Colors.red.shade200),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.block_rounded, size: 10, color: Colors.red.shade800),
                                  const SizedBox(width: 4),
                                  Text(
                                    'VOIDED',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.red.shade800,
                                      letterSpacing: 0.4,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                      isThreeLine: true,
                      trailing: IconButton(
                        icon: const Icon(Icons.more_vert_rounded),
                        tooltip: 'Actions',
                        onPressed: () =>
                            _showAdminActions(context, receipt, libraryId),
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
  );
  }
}
