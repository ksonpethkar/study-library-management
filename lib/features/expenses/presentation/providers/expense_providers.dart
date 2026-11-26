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

class UnifiedFinancialLedger {
  final double grossRevenue;
  final double totalExpenses;
  final double netProfit;
  final double profitMargin;
  final Map<ExpenseCategory, double> expensesByCategory;
  final int expenseCount;
  final Map<int, double> monthlyRevenueByYearMonth;

  const UnifiedFinancialLedger({
    this.grossRevenue = 0.0,
    this.totalExpenses = 0.0,
    this.netProfit = 0.0,
    this.profitMargin = 0.0,
    this.expensesByCategory = const {},
    this.expenseCount = 0,
    this.monthlyRevenueByYearMonth = const {},
  });

  NetProfitSummary toNetProfitSummary() => NetProfitSummary(
        grossRevenue: grossRevenue,
        totalExpenses: totalExpenses,
        netProfit: netProfit,
        profitMargin: profitMargin,
        expensesByCategory: expensesByCategory,
        expenseCount: expenseCount,
      );
}

DateTime? _parseFinancialDate(dynamic dateRaw) {
  if (dateRaw is String) return DateTime.tryParse(dateRaw);
  if (dateRaw is int) return DateTime.fromMillisecondsSinceEpoch(dateRaw);
  if (dateRaw is Timestamp) return dateRaw.toDate();
  if (dateRaw != null && dateRaw.runtimeType.toString() == 'Timestamp') {
    try {
      return (dateRaw as dynamic).toDate() as DateTime?;
    } catch (_) {}
  }
  return null;
}

/// Fetches `payments`, `receipts`, and `expenses` ONCE in parallel and
/// reconciles both Net Profit and 6-month Revenue buckets in a single pass.
final unifiedFinancialLedgerProvider = FutureProvider<UnifiedFinancialLedger>((ref) async {
  final libraryId = ref.watch(currentLibraryIdProvider);
  if (libraryId == null || libraryId.isEmpty) {
    return const UnifiedFinancialLedger();
  }

  final now = DateTime.now();
  final monthData = <int, double>{};
  for (int i = 5; i >= 0; i--) {
    final month = DateTime(now.year, now.month - i, 1);
    monthData[month.year * 100 + month.month] = 0.0;
  }

  final db = FirebaseFirestore.instance;
  final libDoc = db.collection('libraries').doc(libraryId);
  final expenseRepo = ref.watch(expenseRepositoryProvider);

  final results = await Future.wait<dynamic>([
    libDoc.collection('payments').get().then<QuerySnapshot<Map<String, dynamic>>?>((s) => s).catchError((_) => null),
    libDoc.collection('receipts').get().then<QuerySnapshot<Map<String, dynamic>>?>((s) => s).catchError((_) => null),
    expenseRepo.getExpenses(libraryId).catchError((_) => <ExpenseModel>[]),
  ]);

  final paymentsSnap = results[0] as QuerySnapshot<Map<String, dynamic>>?;
  final receiptsSnap = results[1] as QuerySnapshot<Map<String, dynamic>>?;
  final expenses = results[2] as List<ExpenseModel>;

  double grossRevenue = 0.0;
  final seenReceiptIds = <String>{};
  final seenReceiptNumbers = <String>{};

  // 1. Reconcile Payments once for both lifetime revenue and 6-month trend
  if (paymentsSnap != null) {
    for (final doc in paymentsSnap.docs) {
      final d = doc.data();
      final status = (d['status'] ?? '').toString().toLowerCase();
      if (status == 'voided' || status == 'cancelled' || status == 'refunded' || d['isDeleted'] == true) {
        continue;
      }
      final amount = (d['amount'] as num?)?.toDouble() ?? 0.0;
      grossRevenue += amount;

      final rId = d['receiptId'] as String?;
      if (rId != null && rId.isNotEmpty) seenReceiptIds.add(rId);
      final rNum = d['receiptNumber'] as String?;
      if (rNum != null && rNum.isNotEmpty) seenReceiptNumbers.add(rNum);

      final date = _parseFinancialDate(d['date'] ?? d['createdAt']);
      if (date != null) {
        final key = date.year * 100 + date.month;
        if (monthData.containsKey(key)) {
          monthData[key] = monthData[key]! + amount;
        }
      }
    }
  }

  // 2. Include any orphan/legacy Receipts not already linked to a Payment
  if (receiptsSnap != null) {
    for (final doc in receiptsSnap.docs) {
      final d = doc.data();
      final status = (d['status'] ?? '').toString().toLowerCase();
      if (status == 'voided' || d['deletedAt'] != null || d['isDeleted'] == true) {
        continue;
      }
      final rNum = d['receiptNumber'] as String?;
      if (seenReceiptIds.contains(doc.id) || (rNum != null && seenReceiptNumbers.contains(rNum))) {
        continue;
      }

      final amount = (d['amount'] as num?)?.toDouble() ?? 0.0;
      grossRevenue += amount;

      final date = _parseFinancialDate(d['createdAt'] ?? d['date']);
      if (date != null) {
        final key = date.year * 100 + date.month;
        if (monthData.containsKey(key)) {
          monthData[key] = monthData[key]! + amount;
        }
      }
    }
  }

  // 3. Tally Expenses
  double totalExpenses = 0.0;
  final byCategory = <ExpenseCategory, double>{};
  int expenseCount = 0;

  for (final e in expenses) {
    if (e.isDeleted) continue;
    expenseCount++;
    totalExpenses += e.amount;
    byCategory[e.category] = (byCategory[e.category] ?? 0.0) + e.amount;
  }

  final netProfit = grossRevenue - totalExpenses;
  final profitMargin = grossRevenue > 0 ? (netProfit / grossRevenue) * 100 : 0.0;

  return UnifiedFinancialLedger(
    grossRevenue: grossRevenue,
    totalExpenses: totalExpenses,
    netProfit: netProfit,
    profitMargin: profitMargin,
    expensesByCategory: byCategory,
    expenseCount: expenseCount,
    monthlyRevenueByYearMonth: monthData,
  );
});

final netProfitProvider = FutureProvider<NetProfitSummary>((ref) async {
  final ledger = await ref.watch(unifiedFinancialLedgerProvider.future);
  return ledger.toNetProfitSummary();
});
