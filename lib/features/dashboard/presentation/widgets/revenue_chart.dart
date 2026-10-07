import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:study_library/core/providers/library_provider.dart';

final revenueDataProvider = FutureProvider<List<_MonthlyRevenue>>((ref) async {
  final libraryId = ref.watch(currentLibraryIdProvider);
  if (libraryId == null || libraryId.isEmpty) return [];

  final snap = await FirebaseFirestore.instance
      .collection('libraries')
      .doc(libraryId)
      .collection('payments')
      .get();

  final now = DateTime.now();
  final monthData = <int, double>{};

  // Last 6 months
  for (int i = 5; i >= 0; i--) {
    final month = DateTime(now.year, now.month - i, 1);
    final key = month.year * 100 + month.month;
    monthData[key] = 0;
  }

  for (final doc in snap.docs) {
    final data = doc.data();
    final amount = (data['amount'] as num?)?.toDouble() ?? 0;
    final dateRaw = data['date'] ?? data['createdAt'];
    DateTime? date;
    if (dateRaw is String) date = DateTime.tryParse(dateRaw);
    if (dateRaw is int) date = DateTime.fromMillisecondsSinceEpoch(dateRaw);
    if (dateRaw != null && dateRaw.runtimeType.toString() == 'Timestamp') {
      try {
        date = dateRaw.toDate();
      } catch (_) {
        date = DateTime.now(); // fallback to today if timestamp is malformed
      }
    }
    if (date == null) continue;

    final key = date.year * 100 + date.month;
    if (monthData.containsKey(key)) {
      monthData[key] = monthData[key]! + amount;
    }
  }

  final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return monthData.entries.map((e) {
    final month = e.key % 100;
    return _MonthlyRevenue(
      label: months[month - 1],
      amount: e.value,
    );
  }).toList();
});

class _MonthlyRevenue {
  final String label;
  final double amount;
  _MonthlyRevenue({required this.label, required this.amount});
}

class RevenueChart extends ConsumerWidget {
  const RevenueChart({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final revenueAsync = ref.watch(revenueDataProvider);
    final theme = Theme.of(context);

    return revenueAsync.when(
      loading: () => const SizedBox(height: 200, child: Center(child: CircularProgressIndicator())),
      error: (_, _) => const SizedBox.shrink(),
      data: (data) {
        if (data.isEmpty) return const SizedBox.shrink();

        final maxY = data.map((e) => e.amount).fold<double>(0, (a, b) => a > b ? a : b);
        final total = data.map((e) => e.amount).fold<double>(0, (a, b) => a + b);

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Revenue', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                    Text('₹${_formatAmount(total)}', style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    )),
                  ],
                ),
                Text('Last 6 months', style: theme.textTheme.bodySmall),
                const SizedBox(height: 16),
                SizedBox(
                  height: 160,
                  child: BarChart(
                    BarChartData(
                      alignment: BarChartAlignment.spaceAround,
                      maxY: maxY * 1.2,
                      barTouchData: BarTouchData(
                        touchTooltipData: BarTouchTooltipData(
                          getTooltipItem: (group, groupIndex, rod, rodIndex) {
                            return BarTooltipItem(
                              '₹${_formatAmount(rod.toY)}',
                              TextStyle(color: theme.colorScheme.onPrimary, fontWeight: FontWeight.bold),
                            );
                          },
                        ),
                      ),
                      titlesData: FlTitlesData(
                        show: true,
                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (value, meta) {
                              final idx = value.toInt();
                              if (idx >= 0 && idx < data.length) {
                                return Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Text(data[idx].label, style: const TextStyle(fontSize: 11)),
                                );
                              }
                              return const Text('');
                            },
                          ),
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      gridData: const FlGridData(show: false),
                      barGroups: data.asMap().entries.map((e) {
                        return BarChartGroupData(
                          x: e.key,
                          barRods: [
                            BarChartRodData(
                              toY: e.value.amount,
                              color: theme.colorScheme.primary,
                              width: 20,
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  static String _formatAmount(double amount) {
    if (amount >= 100000) return '${(amount / 100000).toStringAsFixed(1)}L';
    if (amount >= 1000) return '${(amount / 1000).toStringAsFixed(1)}K';
    return amount.toStringAsFixed(0);
  }
}
