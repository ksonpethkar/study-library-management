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
  final _searchController = TextEditingController();

  String _searchQuery = '';
  String _selectedMethodFilter = 'All'; // 'All', 'Cash', 'UPI', 'Card', 'Bank'
  String _selectedStatusFilter = 'All'; // 'All', 'Active', 'Voided'
  bool _isSearchOpen = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _handleBack(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/admin/dashboard');
    }
  }

  String _capitalize(String name) {
    if (name.trim().isEmpty) return 'Student';
    return name.trim().split(RegExp(r'\s+')).map((part) {
      if (part.isEmpty) return part;
      return '${part[0].toUpperCase()}${part.substring(1).toLowerCase()}';
    }).join(' ');
  }

  String _getReceiptNumber(ReceiptModel receipt) {
    final raw = receipt.receiptNumber.trim();
    if (raw.isNotEmpty) {
      if (raw.startsWith('REC') && !raw.contains('-') && raw.length >= 7) {
        return 'REC-${raw.substring(3, 7)}-${raw.substring(7)}';
      }
      return raw;
    }
    final fallbackId = receipt.id.length >= 6 ? receipt.id.substring(0, 6).toUpperCase() : 'RC2026';
    return 'REC-$fallbackId';
  }

  String _formatPaymentMethod(String method) {
    final m = method.toLowerCase();
    if (m.contains('cash')) return 'Cash';
    if (m.contains('upi')) return 'UPI';
    if (m.contains('card')) return 'Card';
    if (m.contains('bank') || m.contains('netbanking')) return 'Bank Transfer';
    if (m.contains('cheque')) return 'Cheque';
    if (m.contains('plan assigned')) return 'Plan Assigned';
    return method.isNotEmpty ? method : 'Payment';
  }

  Color _getMethodColor(String method, bool isVoided) {
    if (isVoided) return Colors.red.shade700;
    final m = method.toLowerCase();
    if (m.contains('upi')) return const Color(0xFF7C3AED); // Modern violet
    if (m.contains('cash')) return const Color(0xFF059669); // Emerald
    if (m.contains('card')) return const Color(0xFF2563EB); // Royal Blue
    if (m.contains('bank') || m.contains('netbanking')) return const Color(0xFF0891B2); // Cyan
    return const Color(0xFF4B5563);
  }

  IconData _getMethodIcon(String method, bool isVoided) {
    if (isVoided) return Icons.block_rounded;
    final m = method.toLowerCase();
    if (m.contains('upi')) return Icons.qr_code_2_rounded;
    if (m.contains('cash')) return Icons.payments_rounded;
    if (m.contains('card')) return Icons.credit_card_rounded;
    if (m.contains('bank') || m.contains('netbanking')) return Icons.account_balance_rounded;
    return Icons.receipt_long_rounded;
  }

  String _formatValidity(DateTime from, DateTime to) {
    final fromStr = _dateFormat.format(from);
    final toStr = _dateFormat.format(to);
    if (fromStr == toStr) {
      return 'Date: $fromStr (Single Day / Admission)';
    }
    return 'Valid: $fromStr – $toStr';
  }

  void _showFilterSheet(BuildContext context) {
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Icon(Icons.filter_list_rounded, size: 22),
                    const SizedBox(width: 8),
                    Text(
                      'Filter Receipts',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const Spacer(),
                    if (_selectedMethodFilter != 'All' || _selectedStatusFilter != 'All')
                      TextButton(
                        onPressed: () {
                          setSheetState(() {
                            _selectedMethodFilter = 'All';
                            _selectedStatusFilter = 'All';
                          });
                          setState(() {});
                        },
                        child: const Text('Reset All'),
                      ),
                  ],
                ),
                const Divider(height: 20),
                Text('Payment Mode', style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: ['All', 'Cash', 'UPI', 'Card', 'Bank'].map((method) {
                    final isSelected = _selectedMethodFilter == method;
                    return ChoiceChip(
                      label: Text(method),
                      selected: isSelected,
                      onSelected: (selected) {
                        setSheetState(() => _selectedMethodFilter = selected ? method : 'All');
                        setState(() {});
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 18),
                Text('Receipt Status', style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: ['All', 'Active', 'Voided'].map((status) {
                    final isSelected = _selectedStatusFilter == status;
                    return ChoiceChip(
                      label: Text(status),
                      selected: isSelected,
                      onSelected: (selected) {
                        setSheetState(() => _selectedStatusFilter = selected ? status : 'All');
                        setState(() {});
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Apply Filters'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showAdminActions(BuildContext context, ReceiptModel receipt, String libraryId) {
    final theme = Theme.of(context);
    final receiptNum = _getReceiptNumber(receipt);
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
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
                  Text(receiptNum,
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                  const Spacer(),
                  Text('₹${receipt.amount.toStringAsFixed(0)}',
                      style: theme.textTheme.titleMedium
                          ?.copyWith(color: theme.colorScheme.primary, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf_rounded),
              title: const Text('View / Share PDF'),
              onTap: () {
                Navigator.pop(ctx);
                context.push('/admin/receipts/${receipt.id}');
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit_note_rounded),
              title: const Text('Edit Admin Notes'),
              onTap: () {
                Navigator.pop(ctx);
                _showEditNotesDialog(context, receipt, libraryId);
              },
            ),
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
    final receiptNum = _getReceiptNumber(receipt);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Receipt'),
        content: Text(
          'Delete $receiptNum? This moves it to the recycle bin.',
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
    final studentNameMap = {
      for (final s in ref.watch(studentsStreamProvider).value ?? []) s.id: s.name,
    };

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _handleBack(context);
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            tooltip: 'Back',
            onPressed: () => _handleBack(context),
          ),
          title: _isSearchOpen
              ? TextField(
                  controller: _searchController,
                  autofocus: true,
                  decoration: const InputDecoration(
                    hintText: 'Search student, receipt #...',
                    border: InputBorder.none,
                    hintStyle: TextStyle(fontSize: 14),
                  ),
                  style: const TextStyle(fontSize: 14),
                  onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
                )
              : const Text('Receipts'),
          actions: [
            IconButton(
              icon: Icon(_isSearchOpen ? Icons.close_rounded : Icons.search_rounded),
              tooltip: _isSearchOpen ? 'Close search' : 'Search receipts',
              onPressed: () {
                setState(() {
                  if (_isSearchOpen) {
                    _isSearchOpen = false;
                    _searchQuery = '';
                    _searchController.clear();
                  } else {
                    _isSearchOpen = true;
                  }
                });
              },
            ),
            IconButton(
              icon: Stack(
                clipBehavior: Clip.none,
                children: [
                  const Icon(Icons.filter_list_rounded),
                  if (_selectedMethodFilter != 'All' || _selectedStatusFilter != 'All')
                    Positioned(
                      right: -2,
                      top: -2,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              ),
              tooltip: 'Filter receipts',
              onPressed: () => _showFilterSheet(context),
            ),
          ],
        ),
        body: RefreshIndicator(
          onRefresh: () async => ref.invalidate(receiptListProvider),
          child: receiptsAsync.when(
            data: (receipts) {
              // Apply search and filter
              final filtered = receipts.where((receipt) {
                final studentName = studentNameMap[receipt.studentId] ?? '';
                final receiptNum = _getReceiptNumber(receipt);
                final method = _formatPaymentMethod(receipt.paymentMethod);

                // Search query match
                if (_searchQuery.isNotEmpty) {
                  final matchName = studentName.toLowerCase().contains(_searchQuery);
                  final matchNum = receiptNum.toLowerCase().contains(_searchQuery);
                  final matchMethod = method.toLowerCase().contains(_searchQuery);
                  if (!matchName && !matchNum && !matchMethod) return false;
                }

                // Method filter match
                if (_selectedMethodFilter != 'All') {
                  final filterLower = _selectedMethodFilter.toLowerCase();
                  if (!receipt.paymentMethod.toLowerCase().contains(filterLower)) {
                    return false;
                  }
                }

                // Status filter match
                if (_selectedStatusFilter == 'Active' && receipt.status != ReceiptStatus.active) {
                  return false;
                }
                if (_selectedStatusFilter == 'Voided' && receipt.status != ReceiptStatus.voided) {
                  return false;
                }

                return true;
              }).toList();

              if (filtered.isEmpty) {
                return SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: SizedBox(
                    height: 450,
                    child: EmptyStateWidget(
                      icon: Icons.receipt_long,
                      title: receipts.isEmpty ? 'No receipts yet' : 'No matching receipts',
                      message: receipts.isEmpty
                          ? 'When payments are recorded, generated receipts will appear here.'
                          : 'Try adjusting your search query or filter criteria.',
                      actionLabel: (_selectedMethodFilter != 'All' || _selectedStatusFilter != 'All' || _searchQuery.isNotEmpty)
                          ? 'Reset Filters'
                          : null,
                      onAction: () {
                        setState(() {
                          _searchQuery = '';
                          _searchController.clear();
                          _selectedMethodFilter = 'All';
                          _selectedStatusFilter = 'All';
                          _isSearchOpen = false;
                        });
                      },
                    ),
                  ),
                );
              }

              // Compute aggregate stats for filtered set
              final totalAmount = filtered
                  .where((r) => r.status == ReceiptStatus.active)
                  .fold<double>(0.0, (sum, r) => sum + r.amount);

              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
                itemCount: filtered.length + 1, // +1 for the aggregate header chip bar
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8, top: 4),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.35),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.receipt_rounded, size: 14, color: Theme.of(context).colorScheme.primary),
                                const SizedBox(width: 5),
                                Text(
                                  '${filtered.length} ${filtered.length == 1 ? 'Receipt' : 'Receipts'}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(context).colorScheme.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: const Color(0xFF059669).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.currency_rupee_rounded, size: 14, color: Color(0xFF059669)),
                                const SizedBox(width: 2),
                                Text(
                                  '${totalAmount.toStringAsFixed(0)} Total Collected',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF059669),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Spacer(),
                          if (_selectedMethodFilter != 'All' || _selectedStatusFilter != 'All' || _searchQuery.isNotEmpty)
                            InkWell(
                              onTap: () {
                                setState(() {
                                  _searchQuery = '';
                                  _searchController.clear();
                                  _selectedMethodFilter = 'All';
                                  _selectedStatusFilter = 'All';
                                  _isSearchOpen = false;
                                });
                              },
                              borderRadius: BorderRadius.circular(8),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                child: Text(
                                  'Clear Filters',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Theme.of(context).colorScheme.error,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    );
                  }

                  final receipt = filtered[index - 1];
                  final isVoided = receipt.status == ReceiptStatus.voided;
                  final rawStudentName = studentNameMap[receipt.studentId] ?? 'Student';
                  final studentName = _capitalize(rawStudentName);
                  final receiptNum = _getReceiptNumber(receipt);
                  final cleanMethod = _formatPaymentMethod(receipt.paymentMethod);
                  final methodColor = _getMethodColor(receipt.paymentMethod, isVoided);
                  final methodIcon = _getMethodIcon(receipt.paymentMethod, isVoided);

                  return StaggeredListItem(
                    index: index - 1,
                    child: Opacity(
                      opacity: isVoided ? 0.72 : 1.0,
                      child: Card(
                        margin: const EdgeInsets.symmetric(vertical: 5),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          onTap: () => context.push('/admin/receipts/${receipt.id}'),
                          leading: CircleAvatar(
                            backgroundColor: isVoided
                                ? Colors.red.shade50
                                : methodColor.withValues(alpha: 0.12),
                            child: Icon(
                              methodIcon,
                              color: isVoided ? Colors.red.shade700 : methodColor,
                              size: 22,
                            ),
                          ),
                          title: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  studentName,
                                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '₹${receipt.amount.toStringAsFixed(0)}',
                                style: TextStyle(
                                  fontSize: 16,
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
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Text(
                                    receiptNum,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey.shade700,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                    decoration: BoxDecoration(
                                      color: methodColor.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(color: methodColor.withValues(alpha: 0.35)),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(methodIcon, size: 10, color: methodColor),
                                        const SizedBox(width: 3),
                                        Text(
                                          cleanMethod,
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: methodColor,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 3),
                              Text(
                                _formatValidity(receipt.validFrom, receipt.validTo),
                                style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600),
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
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
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
                            onPressed: () => _showAdminActions(context, receipt, libraryId),
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
      ),
    );
  }
}
