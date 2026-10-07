import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:study_library/core/providers/library_provider.dart';
import 'package:study_library/models/receipt_model.dart';
import 'package:study_library/features/receipts/data/repositories/receipt_repository.dart';
import 'package:study_library/core/widgets/empty_state_widget.dart';
import 'package:study_library/core/widgets/confirmation_sheet.dart';
import 'receipt_preview_screen.dart';

final receiptListProvider = StreamProvider<List<ReceiptModel>>((ref) {
  final libraryId = ref.watch(currentLibraryIdProvider) ?? '';
  if (libraryId.isEmpty) return const Stream.empty();
  final repo = ReceiptRepository();
  return repo.getReceipts(libraryId);
});

class ReceiptListScreen extends ConsumerWidget {
  const ReceiptListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final libraryId = ref.watch(currentLibraryIdProvider) ?? '';
    final receiptsAsync = ref.watch(receiptListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Receipts'),
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
            itemCount: receipts.length,
            itemBuilder: (context, index) {
              final receipt = receipts[index];
              return Dismissible(
                key: ValueKey(receipt.id),
                background: Container(
                  color: Colors.orange,
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: const Icon(Icons.cancel, color: Colors.white),
                ),
                secondaryBackground: Container(
                  color: Colors.red,
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: const Icon(Icons.delete, color: Colors.white),
                ),
                confirmDismiss: (direction) async {
                  if (direction == DismissDirection.endToStart) {
                    bool confirm = false;
                    await ConfirmationSheet.show(
                      context,
                      title: 'Delete Receipt',
                      message: 'Are you sure you want to permanently delete this receipt?',
                      confirmLabel: 'Delete',
                      isDestructive: true,
                      onConfirm: () => confirm = true,
                    );
                    if (confirm && libraryId.isNotEmpty) {
                      await ReceiptRepository().deleteReceipt(libraryId, receipt.id);
                      return true;
                    }
                    return false;
                  } else {
                    bool confirm = false;
                    await ConfirmationSheet.show(
                      context,
                      title: 'Void Receipt',
                      message: 'Marking a receipt as void means it is no longer valid.',
                      confirmLabel: 'Void',
                      onConfirm: () => confirm = true,
                    );
                    if (confirm && libraryId.isNotEmpty) {
                      await ReceiptRepository().voidReceipt(libraryId, receipt.id);
                    }
                    return false;
                  }
                },
                child: Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: ListTile(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ReceiptPreviewScreen(receiptId: receipt.id),
                        ),
                      );
                    },
                    leading: CircleAvatar(
                      backgroundColor: receipt.status == ReceiptStatus.active 
                          ? Colors.green.withValues(alpha: 0.1) 
                          : Colors.grey.withValues(alpha: 0.1),
                      child: Icon(Icons.receipt, 
                        color: receipt.status == ReceiptStatus.active ? Colors.green : Colors.grey,
                      ),
                    ),
                    title: Text('${receipt.receiptNumber} - ₹${receipt.amount.toStringAsFixed(0)}'),
                    subtitle: Text('Valid till: ${receipt.validTo.toLocal().toString().split(' ')[0]}'),
                    trailing: receipt.status == ReceiptStatus.voided 
                        ? const Badge(label: Text('VOID'), backgroundColor: Colors.grey)
                        : IconButton(
                            icon: const Icon(Icons.picture_as_pdf),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ReceiptPreviewScreen(receiptId: receipt.id),
                                ),
                              );
                            },
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
    );
  }
}
