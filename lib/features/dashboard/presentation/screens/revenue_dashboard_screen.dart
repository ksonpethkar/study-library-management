import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:study_library/core/providers/library_provider.dart';
import 'package:study_library/models/receipt_model.dart';

class RevenueDashboardScreen extends ConsumerStatefulWidget {
  const RevenueDashboardScreen({super.key});
  @override
  ConsumerState<RevenueDashboardScreen> createState() => _RevenueDashboardScreenState();
}

class _RevenueDashboardScreenState extends ConsumerState<RevenueDashboardScreen> {
  String _range = 'month'; // week / month / year / all
  bool _isLoading = true;
  double _totalRevenue = 0;
  double _rangeRevenue = 0;
  int _activeStudents = 0;
  Map<String, double> _byPlan = {};
  Map<String, double> _byMethod = {};
  List<ReceiptModel> _recentReceipts = [];
  int _totalReceiptsCount = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final libraryId = ref.read(currentLibraryIdProvider) ?? '';
    if (libraryId.isEmpty) { setState(() => _isLoading = false); return; }
    try {
      // Determine date range filter
      final now = DateTime.now();
      DateTime? since;
      if (_range == 'week') {
        since = now.subtract(const Duration(days: 7));
      } else if (_range == 'month') {
        since = DateTime(now.year, now.month, 1);
      } else if (_range == 'year') {
        since = DateTime(now.year, 1, 1);
      }

      // Load receipts
      Query<Map<String, dynamic>> query = FirebaseFirestore.instance
          .collection('libraries').doc(libraryId)
          .collection('receipts')
          .orderBy('createdAt', descending: true);
      
      final allSnap = await query.get();
      
      double total = 0;
      double rangeTotal = 0;
      final byPlan = <String, double>{};
      final byMethod = <String, double>{};
      final receipts = <ReceiptModel>[];
      
      for (final doc in allSnap.docs) {
        final data = {...doc.data(), 'id': doc.id};
        ReceiptModel receipt;
        try { receipt = ReceiptModel.fromJson(data); } catch (_) { continue; }
        
        final amt = receipt.amount;
        total += amt;
        
        final genAt = receipt.createdAt;
        if (since == null || (genAt != null && genAt.isAfter(since))) {
          rangeTotal += amt;
          final plan = receipt.planId.isNotEmpty ? receipt.planId : 'Unknown Plan';
          byPlan[plan] = (byPlan[plan] ?? 0) + amt;
          final method = receipt.paymentMethod.isNotEmpty ? receipt.paymentMethod : 'Cash';
          byMethod[method] = (byMethod[method] ?? 0) + amt;
        }
        receipts.add(receipt);
      }
      
      // Active students count
      final stuSnap = await FirebaseFirestore.instance
          .collection('libraries').doc(libraryId)
          .collection('students')
          .where('membershipStatus', isEqualTo: 'active')
          .count()
          .get();
      
      setState(() {
        _totalRevenue = total;
        _rangeRevenue = rangeTotal;
        _activeStudents = stuSnap.count ?? 0;
        _totalReceiptsCount = allSnap.docs.length;
        _byPlan = byPlan;
        _byMethod = byMethod;
        _recentReceipts = receipts.take(10).toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fmt = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Revenue & Analytics'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Date Range Filter
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          for (final r in [('week','This Week'),('month','This Month'),('year','This Year'),('all','All Time')])
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: FilterChip(
                                label: Text(r.$2),
                                selected: _range == r.$1,
                                onSelected: (_) {
                                  setState(() => _range = r.$1);
                                  _loadData();
                                },
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Summary Cards
                    Row(
                      children: [
                        _SummaryCard(title: 'Total Revenue', value: fmt.format(_totalRevenue), icon: Icons.account_balance_wallet_rounded, color: Colors.green),
                        const SizedBox(width: 8),
                        _SummaryCard(title: _rangeLabel(), value: fmt.format(_rangeRevenue), icon: Icons.trending_up_rounded, color: Colors.blue),
                        const SizedBox(width: 8),
                        _SummaryCard(title: 'Active Students', value: '$_activeStudents', icon: Icons.people_rounded, color: Colors.orange),
                      ],
                    ),
                    if (_totalReceiptsCount >= 500) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.blue.shade200),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline, color: Colors.blue, size: 20),
                            const SizedBox(width: 8),
                            Expanded(child: Text('Showing all $_totalReceiptsCount payments. For very large datasets, use Data Export.', style: TextStyle(color: Colors.blue.shade900, fontSize: 13))),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    
                    // Revenue by Plan
                    if (_byPlan.isNotEmpty) ...[
                      Text('Revenue by Plan', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      ..._buildBarChart(_byPlan, fmt, theme),
                      const SizedBox(height: 24),
                    ],
                    
                    // Payment Methods
                    if (_byMethod.isNotEmpty) ...[
                      Text('Payment Methods', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _byMethod.entries.map((e) => Chip(
                          avatar: const Icon(Icons.payment, size: 16),
                          label: Text('${e.key}: ${fmt.format(e.value)}'),
                        )).toList(),
                      ),
                      const SizedBox(height: 24),
                    ],
                    
                    // Recent Transactions
                    Text('Recent Transactions', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    if (_recentReceipts.isEmpty)
                      const Center(child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text('No transactions yet', style: TextStyle(color: Colors.grey)),
                      ))
                    else
                      ...(_recentReceipts.map((r) => Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.green.shade50,
                            child: const Icon(Icons.receipt_rounded, color: Colors.green, size: 20),
                          ),
                          title: Text(r.studentId.isNotEmpty ? r.studentId : 'Unknown', style: const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Text('${r.planId} • ${r.paymentMethod}\n${r.createdAt != null ? DateFormat('dd MMM yyyy, hh:mm a').format(r.createdAt!) : ''}'),
                          trailing: Text(fmt.format(r.amount), style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green.shade700, fontSize: 15)),
                          isThreeLine: true,
                        ),
                      ))),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
    );
  }

  String _rangeLabel() {
    switch (_range) {
      case 'week': return 'This Week';
      case 'month': return 'This Month';
      case 'year': return 'This Year';
      default: return 'All Time';
    }
  }

  List<Widget> _buildBarChart(Map<String, double> data, NumberFormat fmt, ThemeData theme) {
    if (data.isEmpty) return [];
    final max = data.values.reduce((a, b) => a > b ? a : b);
    return data.entries.map((e) {
      final pct = max > 0 ? e.value / max : 0.0;
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(child: Text(e.key, style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis)),
                Text(fmt.format(e.value), style: TextStyle(fontWeight: FontWeight.bold, color: theme.colorScheme.primary)),
              ],
            ),
            const SizedBox(height: 4),
            LayoutBuilder(builder: (ctx, constraints) {
              return Container(
                height: 10,
                width: constraints.maxWidth,
                decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(5)),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: FractionallySizedBox(
                    widthFactor: pct,
                    child: Container(
                      decoration: BoxDecoration(color: theme.colorScheme.primary, borderRadius: BorderRadius.circular(5)),
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
      );
    }).toList();
  }
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  const _SummaryCard({required this.title, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(height: 6),
              Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: color)),
              const SizedBox(height: 2),
              Text(title, style: const TextStyle(fontSize: 11, color: Colors.grey)),
            ],
          ),
        ),
      ),
    );
  }
}
