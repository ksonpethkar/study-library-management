import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:study_library/core/providers/library_provider.dart';
import 'package:study_library/models/receipt_model.dart';
import 'package:study_library/features/receipts/data/repositories/receipt_repository.dart';
import 'package:study_library/core/widgets/empty_state_widget.dart';
import 'receipt_preview_screen.dart';

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
  // Cache student names: studentId → name
  final Map<String, String> _studentNames = {};

  Future<String> _fetchStudentName(String libraryId, String studentId) async {
    if (_studentNames.containsKey(studentId)) return _studentNames[studentId]!;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('libraries')
          .doc(libraryId)
          .collection('students')
          .doc(studentId)
          .get();
      final name = doc.data()?['name'] as String? ?? 'Student';
      _studentNames[studentId] = name;
      return name;
    } catch (_) {
      return 'Student';
    }
  }

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
                Navigator.push(context, MaterialPageRoute(
                  builder: (_) => ReceiptPreviewScreen(receiptId: receipt.id),
                ));
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
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Receipt restored to active')),
                    );
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
      body: receiptsAsync.when(
        data: (receipts) {
          if (receipts.isEmpty) {
            return const EmptyStateWidget(
              icon: Icons.receipt_long,
              title: 'No receipts yet',
              message: 'When payments are recorded, generated receipts will appear here.',
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: receipts.length,
            itemBuilder: (context, index) {
              final receipt = receipts[index];
              final isVoided = receipt.status == ReceiptStatus.voided;
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
                child: FutureBuilder<String>(
                  future: libraryId.isNotEmpty
                      ? _fetchStudentName(libraryId, receipt.studentId)
                      : Future.value('Student'),
                  builder: (ctx, snap) {
                    final studentName = snap.data ?? '…';
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 6),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              ReceiptPreviewScreen(receiptId: receipt.id),
                        ),
                      ),
                      leading: CircleAvatar(
                        backgroundColor: isVoided
                            ? Colors.grey.withValues(alpha: 0.12)
                            : Colors.green.withValues(alpha: 0.12),
                        child: Icon(
                          isVoided
                              ? Icons.cancel_outlined
                              : Icons.receipt_rounded,
                          color: isVoided ? Colors.grey : Colors.green,
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
                              color: isVoided
                                  ? Colors.grey
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
                          if (isVoided)
                            Container(
                              margin: const EdgeInsets.only(top: 3),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade200,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'VOIDED',
                                style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey),
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
                    );
                  },
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('Error: $e')),
      ),
    );
  }
}
