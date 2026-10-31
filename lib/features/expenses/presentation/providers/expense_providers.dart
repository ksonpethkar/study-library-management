import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:study_library/core/providers/library_provider.dart';
import 'package:study_library/features/expenses/data/repositories/expense_repository.dart';
import 'package:study_library/models/expense_model.dart';

final expenseRepositoryProvider = Provider<ExpenseRepository>((ref) {
  return ExpenseRepository();
});

final expensesStreamProvider = StreamProvider<List<ExpenseModel>>((ref) {
  final libraryId = ref.watch(currentLibraryIdProvider);
  if (libraryId == null || libraryId.isEmpty) return Stream.value([]);
  return ref.watch(expenseRepositoryProvider).streamExpenses(libraryId);
});

class NetProfitSummary {
  final double grossRevenue;
  final double totalExpenses;
  final double netProfit;
  final double profitMargin;
  final Map<ExpenseCategory, double> expensesByCategory;
  final int expenseCount;

  const NetProfitSummary({
    required this.grossRevenue,
    required this.totalExpenses,
    required this.netProfit,
    required this.profitMargin,
    required this.expensesByCategory,
    required this.expenseCount,
  });

  bool get isProfitable => netProfit >= 0;
}

final netProfitProvider = FutureProvider<NetProfitSummary>((ref) async {
  final libraryId = ref.watch(currentLibraryIdProvider);
  if (libraryId == null || libraryId.isEmpty) {
    return const NetProfitSummary(
      grossRevenue: 0.0,
      totalExpenses: 0.0,
      netProfit: 0.0,
      profitMargin: 0.0,
      expensesByCategory: {},
      expenseCount: 0,
    );
  }

  // 1. Fetch Gross Revenue from payments (or fallback to receipts)
  double grossRevenue = 0.0;
  try {
    final paymentsSnap = await FirebaseFirestore.instance
        .collection('libraries')
        .doc(libraryId)
        .collection('payments')
        .get();

    for (final doc in paymentsSnap.docs) {
      final d = doc.data();
      final status = (d['status'] ?? '').toString().toLowerCase();
      if (status == 'voided' || status == 'cancelled' || status == 'refunded' || d['isDeleted'] == true) {
        continue;
      }
      final amount = (d['amount'] as num?)?.toDouble() ?? 0.0;
      grossRevenue += amount;
    }
  } catch (_) {}

  // Fallback to receipts if payments collection has no gross revenue
  if (grossRevenue == 0.0) {
    try {
      final receiptsSnap = await FirebaseFirestore.instance
          .collection('libraries')
          .doc(libraryId)
          .collection('receipts')
          .get();

      for (final doc in receiptsSnap.docs) {
        final d = doc.data();
        final status = (d['status'] ?? '').toString().toLowerCase();
        if (status == 'voided' || d['deletedAt'] != null || d['isDeleted'] == true) {
          continue;
        }
        final amount = (d['amount'] as num?)?.toDouble() ?? 0.0;
        grossRevenue += amount;
      }
    } catch (_) {}
  }

  // 2. Fetch all expenses
  double totalExpenses = 0.0;
  final byCategory = <ExpenseCategory, double>{};
  int expenseCount = 0;

  try {
    final expenses = await ref.watch(expenseRepositoryProvider).getExpenses(libraryId);
    expenseCount = expenses.length;
    for (final e in expenses) {
      if (e.isDeleted) continue;
      totalExpenses += e.amount;
      byCategory[e.category] = (byCategory[e.category] ?? 0.0) + e.amount;
    }
  } catch (_) {}

  final netProfit = grossRevenue - totalExpenses;
  final profitMargin = grossRevenue > 0 ? (netProfit / grossRevenue) * 100 : 0.0;

  return NetProfitSummary(
    grossRevenue: grossRevenue,
    totalExpenses: totalExpenses,
    netProfit: netProfit,
    profitMargin: profitMargin,
    expensesByCategory: byCategory,
    expenseCount: expenseCount,
  );
});
