import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:study_library/core/providers/library_provider.dart';
import 'package:study_library/features/expenses/presentation/providers/expense_providers.dart';
import 'package:study_library/features/expenses/presentation/screens/add_expense_dialog.dart';
import 'package:study_library/models/expense_model.dart';

class ExpenseListScreen extends ConsumerStatefulWidget {
  const ExpenseListScreen({super.key});

  @override
  ConsumerState<ExpenseListScreen> createState() => _ExpenseListScreenState();
}

class _ExpenseListScreenState extends ConsumerState<ExpenseListScreen> {
  String _searchQuery = '';
  ExpenseCategory? _selectedCategory;
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _confirmDelete(ExpenseModel expense) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Expense?'),
        content: Text('Are you sure you want to delete "${expense.title}" for ₹${expense.amount.toStringAsFixed(0)}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final libraryId = ref.read(currentLibraryIdProvider);
      if (libraryId != null && libraryId.isNotEmpty) {
        HapticFeedback.mediumImpact();
        await ref.read(expenseRepositoryProvider).deleteExpense(libraryId, expense.id);
        ref.invalidate(expensesStreamProvider);
        ref.invalidate(netProfitProvider);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Expense deleted')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final expensesAsync = ref.watch(expensesStreamProvider);
    final netProfitAsync = ref.watch(netProfitProvider);
    final dateFormat = DateFormat('dd MMM yyyy');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Operating Expenses & Net Profit'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: () {
              ref.invalidate(expensesStreamProvider);
              ref.invalidate(netProfitProvider);
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // ── 1. Net Profit Engine Summary Banner ────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: netProfitAsync.when(
              data: (summary) {
                final isProfit = summary.isProfitable;
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isProfit
                          ? (isDark
                              ? [const Color(0xFF064E3B), const Color(0xFF022C22)]
                              : [const Color(0xFFECFDF5), const Color(0xFFD1FAE5)])
                          : (isDark
                              ? [const Color(0xFF7F1D1D), const Color(0xFF450A0A)]
                              : [const Color(0xFFFEF2F2), const Color(0xFFFEE2E2)]),
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: isProfit
                          ? (isDark ? const Color(0xFF059669) : const Color(0xFF10B981))
                          : (isDark ? const Color(0xFFDC2626) : const Color(0xFFEF4444)),
                      width: 1.5,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(
                                isProfit ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                                color: isProfit ? const Color(0xFF059669) : const Color(0xFFDC2626),
                                size: 22,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'NET PROFIT ENGINE',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.2,
                                  color: isProfit
                                      ? (isDark ? const Color(0xFFA7F3D0) : const Color(0xFF065F46))
                                      : (isDark ? const Color(0xFFFECACA) : const Color(0xFF991B1B)),
                                ),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: isProfit
                                  ? (isDark ? const Color(0xFF065F46) : const Color(0xFFA7F3D0))
                                  : (isDark ? const Color(0xFF991B1B) : const Color(0xFFFECACA)),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '${summary.profitMargin.toStringAsFixed(1)}% Margin',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: isProfit
                                    ? (isDark ? Colors.white : const Color(0xFF064E3B))
                                    : (isDark ? Colors.white : const Color(0xFF7F1D1D)),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        '₹${summary.netProfit.toStringAsFixed(0)}',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          color: isProfit
                              ? (isDark ? const Color(0xFF6EE7B7) : const Color(0xFF047857))
                              : (isDark ? const Color(0xFFFCA5A5) : const Color(0xFFB91C1C)),
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Divider(height: 1),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Gross Revenue', style: theme.textTheme.labelSmall),
                                Text(
                                  '₹${summary.grossRevenue.toStringAsFixed(0)}',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.green),
                                ),
                              ],
                            ),
                          ),
                          Container(width: 1, height: 28, color: theme.colorScheme.outlineVariant),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(left: 12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Total Expenses', style: theme.textTheme.labelSmall),
                                  Text(
                                    '₹${summary.totalExpenses.toStringAsFixed(0)}',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.red),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Container(width: 1, height: 28, color: theme.colorScheme.outlineVariant),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(left: 12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Entries', style: theme.textTheme.labelSmall),
                                  Text(
                                    '${summary.expenseCount}',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
              loading: () => const SizedBox(
                height: 120,
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (err, _) => Text('Error loading Net Profit: $err'),
            ),
          ),

          // ── 2. Search & Category Filter Chips ──────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search expenses by title or vendor...',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              onChanged: (v) => setState(() => _searchQuery = v.trim().toLowerCase()),
            ),
          ),

          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                ChoiceChip(
                  label: const Text('All'),
                  selected: _selectedCategory == null,
                  onSelected: (_) => setState(() => _selectedCategory = null),
                ),
                ...ExpenseCategory.values.map((cat) {
                  final isSelected = _selectedCategory == cat;
                  return Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: ChoiceChip(
                      avatar: Text(cat.iconEmoji),
                      label: Text(cat.displayName),
                      selected: isSelected,
                      onSelected: (_) => setState(() => _selectedCategory = isSelected ? null : cat),
                    ),
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: 4),

          // ── 3. Expense List ────────────────────────────────────────────────
          Expanded(
            child: expensesAsync.when(
              data: (expenses) {
                var filtered = expenses;
                if (_selectedCategory != null) {
                  filtered = filtered.where((e) => e.category == _selectedCategory).toList();
                }
                if (_searchQuery.isNotEmpty) {
                  filtered = filtered.where((e) {
                    return e.title.toLowerCase().contains(_searchQuery) ||
                        e.paidTo.toLowerCase().contains(_searchQuery) ||
                        (e.notes?.toLowerCase().contains(_searchQuery) ?? false);
                  }).toList();
                }

                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.receipt_long_outlined, size: 64, color: theme.colorScheme.outline),
                        const SizedBox(height: 12),
                        Text(
                          expenses.isEmpty ? 'No expenses recorded yet' : 'No matching expenses',
                          style: theme.textTheme.titleMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          expenses.isEmpty
                              ? 'Tap "+ Add Expense" below to start tracking your operational overheads'
                              : 'Try resetting your search query or category filters',
                          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final item = filtered[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.red.withValues(alpha: 0.1),
                          child: Text(item.category.iconEmoji, style: const TextStyle(fontSize: 18)),
                        ),
                        title: Row(
                          children: [
                            Expanded(
                              child: Text(
                                item.title,
                                style: const TextStyle(fontWeight: FontWeight.bold),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              '-₹${item.amount.toStringAsFixed(0)}',
                              style: const TextStyle(
                                color: Colors.red,
                                fontWeight: FontWeight.w900,
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 2),
                            Text(
                              [
                                item.category.displayName,
                                if (item.paidTo.isNotEmpty) 'Paid to: ${item.paidTo}',
                                item.paymentMethod,
                              ].join(' • '),
                              style: theme.textTheme.bodySmall,
                            ),
                            const SizedBox(height: 1),
                            Text(
                              dateFormat.format(item.date),
                              style: TextStyle(fontSize: 11, color: theme.colorScheme.outline),
                            ),
                          ],
                        ),
                        trailing: PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert_rounded),
                          onSelected: (val) {
                            if (val == 'edit') {
                              AddExpenseDialog.show(context, expense: item);
                            } else if (val == 'delete') {
                              _confirmDelete(item);
                            }
                          },
                          itemBuilder: (_) => [
                            const PopupMenuItem(
                              value: 'edit',
                              child: Row(
                                children: [
                                  Icon(Icons.edit_outlined, size: 18),
                                  SizedBox(width: 8),
                                  Text('Edit'),
                                ],
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'delete',
                              child: Row(
                                children: [
                                  Icon(Icons.delete_outline, size: 18, color: Colors.red),
                                  SizedBox(width: 8),
                                  Text('Delete', style: TextStyle(color: Colors.red)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(child: Text('Error: $err')),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.red.shade700,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Record Expense'),
        onPressed: () => AddExpenseDialog.show(context),
      ),
    );
  }
}
