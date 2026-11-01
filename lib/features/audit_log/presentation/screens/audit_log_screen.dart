import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:study_library/core/providers/library_provider.dart';
import 'package:study_library/core/widgets/empty_state_widget.dart';
import 'package:go_router/go_router.dart';
import 'package:study_library/core/router/app_router.dart';

class AuditLogScreen extends ConsumerStatefulWidget {
  const AuditLogScreen({super.key});

  @override
  ConsumerState<AuditLogScreen> createState() => _AuditLogScreenState();
}

class _AuditLogScreenState extends ConsumerState<AuditLogScreen> {
  String _selectedCategory = 'all';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _getActionBadgeText(String action) {
    action = action.toLowerCase();
    if (action == 'created' || action == 'add') return 'CREATED';
    if (action == 'deleted' || action == 'remove') return 'DELETED';
    if (action == 'updated' || action == 'edit') return 'UPDATED';
    if (action == 'restored') return 'RESTORED';
    if (action == 'login') return 'LOGIN';
    if (action == 'approved') return 'APPROVED';
    if (action == 'rejected') return 'REJECTED';
    if (action == 'voided') return 'VOIDED';
    if (action == 'exported') return 'BACKUP';
    if (action == 'imported') return 'RESTORE';
    return action.toUpperCase();
  }

  Color _getActionColor(String action, bool isDark) {
    action = action.toLowerCase();
    if (action == 'created' || action == 'add' || action == 'approved') {
      return isDark ? const Color(0xFF81C784) : const Color(0xFF2E7D32);
    }
    if (action == 'deleted' || action == 'remove' || action == 'rejected' || action == 'voided') {
      return isDark ? const Color(0xFFE57373) : const Color(0xFFC62828);
    }
    if (action == 'updated' || action == 'edit') {
      return isDark ? const Color(0xFFFFB74D) : const Color(0xFFEF6C00);
    }
    if (action == 'restored') {
      return isDark ? const Color(0xFF4DB6AC) : const Color(0xFF00897B);
    }
    if (action == 'login') {
      return isDark ? const Color(0xFF64B5F6) : const Color(0xFF1565C0);
    }
    if (action == 'exported' || action == 'imported') {
      return isDark ? const Color(0xFFBA68C8) : const Color(0xFF6A1B9A);
    }
    return isDark ? Colors.grey.shade400 : Colors.blueGrey;
  }

  Color _getActionBgColor(String action, bool isDark) {
    final base = _getActionColor(action, isDark);
    return base.withValues(alpha: isDark ? 0.2 : 0.12);
  }

  String _formatHeadline(Map<String, dynamic> log) {
    final action = (log['action'] ?? '').toString().toLowerCase();
    final entityType = (log['entityType'] ?? '').toString().toLowerCase();
    final entityName = log['entityName']?.toString();
    final details = log['details'] is Map<String, dynamic>
        ? log['details'] as Map<String, dynamic>
        : <String, dynamic>{};

    if (entityType == 'receipt') {
      final recNum = details['receiptNumber'] ?? entityName ?? '';
      final amt = details['amount'] != null ? '₹${details['amount']}' : '';
      if (action == 'deleted') {
        return 'Deleted Fee Receipt #${recNum.isNotEmpty ? recNum : ""} ${amt.isNotEmpty ? "($amt)" : ""}'.trim();
      }
      if (action == 'created') {
        return 'Generated Fee Receipt #${recNum.isNotEmpty ? recNum : ""} ${amt.isNotEmpty ? "($amt)" : ""}'.trim();
      }
      return 'Receipt #${recNum.isNotEmpty ? recNum : ""} ($action)'.trim();
    }

    if (entityType == 'payment') {
      final amt = details['amount'] ?? details['deletedAmount'] ?? '';
      final amtStr = amt.toString().isNotEmpty ? '₹$amt' : '';
      final event = details['event']?.toString() ?? action;
      if (event == 'payment_voided') return 'Voided Payment $amtStr'.trim();
      if (action == 'deleted') return 'Deleted Payment Record $amtStr'.trim();
      if (action == 'created') return 'Recorded Payment $amtStr'.trim();
      return 'Payment Updated $amtStr'.trim();
    }

    if (entityType == 'student') {
      final name = entityName ?? details['name'] ?? details['studentName'] ?? 'Student';
      if (action == 'created') return 'Enrolled Student: $name';
      if (action == 'deleted') return 'Moved Student to Recycle Bin: $name';
      if (action == 'restored') return 'Restored Student from Bin: $name';
      if (details['seatAssigned'] == true) return 'Assigned Seat to $name';
      return 'Updated Student: $name';
    }

    if (entityType == 'seat' || entityType == 'section') {
      final sLabel = entityName ?? details['seatId'] ?? details['sectionName'] ?? '';
      if (action == 'updated') return 'Updated Seat / Layout ${sLabel.isNotEmpty ? "#$sLabel" : ""}';
      if (action == 'created') return 'Created Seat / Section ${sLabel.isNotEmpty ? sLabel : ""}';
      return '$action Seat $sLabel'.trim();
    }

    if (action == 'login') {
      final email = details['email'] ?? log['userEmail'] ?? 'Admin';
      return 'Admin Login: $email';
    }

    if (entityType == 'request') {
      final sName = entityName ?? details['studentName'] ?? 'Student';
      if (action == 'approved') return 'Approved Admission for $sName';
      if (action == 'rejected') return 'Rejected Admission for $sName';
      return 'Admission Request: $sName ($action)';
    }

    if (action == 'exported') return 'Created Full System Backup';
    if (action == 'imported') return 'Restored Data from Backup File';

    // General fallback
    final message = log['message']?.toString();
    if (message != null && message.isNotEmpty) return message;

    final capAction = action.isNotEmpty ? action[0].toUpperCase() + action.substring(1) : 'Action';
    final capEntity = entityType.isNotEmpty ? entityType[0].toUpperCase() + entityType.substring(1) : '';
    return '$capAction $capEntity ${entityName ?? ""}'.trim();
  }

  void _showLogDetailsSheet(BuildContext context, Map<String, dynamic> log) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final action = (log['action'] ?? '').toString();
    final badgeColor = _getActionColor(action, isDark);
    final badgeBg = _getActionBgColor(action, isDark);
    final headline = _formatHeadline(log);

    final rawTime = log['timestamp'];
    String formattedTime = 'Unknown date';
    if (rawTime is Timestamp) {
      formattedTime = DateFormat('dd MMMM yyyy, hh:mm:ss a').format(rawTime.toDate());
    } else if (rawTime is String) {
      final dt = DateTime.tryParse(rawTime);
      if (dt != null) formattedTime = DateFormat('dd MMMM yyyy, hh:mm:ss a').format(dt);
    }

    final user = (log['userEmail'] ?? log['userName'] ?? 'Admin').toString();
    final entityType = (log['entityType'] ?? '').toString();
    final entityId = (log['entityId'] ?? '').toString();
    final details = log['details'] is Map<String, dynamic> ? log['details'] as Map<String, dynamic> : null;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (_, scrollCtrl) => ListView(
          controller: scrollCtrl,
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade400,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: badgeBg,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: badgeColor, width: 1.2),
                  ),
                  child: Text(
                    _getActionBadgeText(action),
                    style: TextStyle(
                      color: badgeColor,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    formattedTime,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              headline,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            _buildDetailRow('Actor / Performed By', user, icon: Icons.person_outline),
            if (entityType.isNotEmpty)
              _buildDetailRow('Entity Category', entityType.toUpperCase(), icon: Icons.category_outlined),
            if (entityId.isNotEmpty)
              _buildDetailRow('Entity Record ID', entityId, icon: Icons.tag_rounded),
            if (details != null && details.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text(
                'Operation Parameters & Details',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF282828) : const Color(0xFFF5F5F5),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: isDark ? Colors.white12 : Colors.grey.shade300),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: details.entries.map((e) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 120,
                            child: Text(
                              e.key,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              '${e.value}',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
            const SizedBox(height: 20),
            FilledButton.tonalIcon(
              icon: const Icon(Icons.check, size: 18),
              label: const Text('Close'),
              onPressed: () => Navigator.pop(ctx),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {IconData? icon}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: Colors.grey.shade600),
            const SizedBox(width: 8),
          ],
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final libraryId = ref.watch(currentLibraryIdProvider) ?? '';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (libraryId.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            tooltip: 'Back',
            onPressed: () => context.canPop() ? context.pop() : context.go(Routes.adminHome),
          ),
          title: const Text('Audit Log'),
        ),
        body: const Center(child: Text('Library not loaded')),
      );
    }

    final stream = FirebaseFirestore.instance
        .collection('libraries')
        .doc(libraryId)
        .collection('audit_log')
        .snapshots();

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back',
          onPressed: () => context.canPop() ? context.pop() : context.go(Routes.adminHome),
        ),
        title: const Text('Audit Trail & Activity Log'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by student, receipt, action, or admin...',
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          setState(() {
                            _searchQuery = '';
                            _searchController.clear();
                          });
                        },
                      )
                    : null,
                isDense: true,
                filled: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              ),
              onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          // Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                _buildFilterChip('All Events', 'all'),
                const SizedBox(width: 8),
                _buildFilterChip('Students', 'student'),
                const SizedBox(width: 8),
                _buildFilterChip('Receipts & Fees', 'receipt'),
                const SizedBox(width: 8),
                _buildFilterChip('Seats & Layout', 'seat'),
                const SizedBox(width: 8),
                _buildFilterChip('Security & Logins', 'login'),
                const SizedBox(width: 8),
                _buildFilterChip('System & Backup', 'system'),
              ],
            ),
          ),
          const Divider(height: 1),
          // Stream List
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: stream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snapshot.data?.docs ?? [];
                if (docs.isEmpty) {
                  return const EmptyStateWidget(
                    icon: Icons.fact_check_outlined,
                    title: 'No audit records found',
                    message: 'All your administrative actions, payments, and seat updates will appear here in real-time.',
                  );
                }

                // In-memory sort by timestamp descending (zero composite index required)
                final logs = docs.map((d) => d.data()).toList();
                logs.sort((a, b) {
                  final aTime = a['timestamp'];
                  final bTime = b['timestamp'];
                  DateTime dtA = DateTime(1970);
                  DateTime dtB = DateTime(1970);
                  if (aTime is Timestamp) dtA = aTime.toDate();
                  if (bTime is Timestamp) dtB = bTime.toDate();
                  if (aTime is String) dtA = DateTime.tryParse(aTime) ?? dtA;
                  if (bTime is String) dtB = DateTime.tryParse(bTime) ?? dtB;
                  return dtB.compareTo(dtA);
                });

                // Apply category & search filtering
                final filtered = logs.where((log) {
                  final action = (log['action'] ?? '').toString().toLowerCase();
                  final entityType = (log['entityType'] ?? '').toString().toLowerCase();
                  final headline = _formatHeadline(log).toLowerCase();
                  final user = (log['userEmail'] ?? log['userName'] ?? '').toString().toLowerCase();

                  // Category filter
                  if (_selectedCategory == 'student' && entityType != 'student' && !action.contains('student')) {
                    return false;
                  }
                  if (_selectedCategory == 'receipt' && entityType != 'receipt' && entityType != 'payment' && !action.contains('receipt')) {
                    return false;
                  }
                  if (_selectedCategory == 'seat' && entityType != 'seat' && entityType != 'section' && !action.contains('seat') && log['details']?['seatId'] == null && log['details']?['sectionId'] == null) {
                    return false;
                  }
                  if (_selectedCategory == 'login' && action != 'login' && !action.contains('auth')) {
                    return false;
                  }
                  if (_selectedCategory == 'system' && action != 'exported' && action != 'imported' && entityType != 'settings') {
                    return false;
                  }

                  // Search query filter
                  if (_searchQuery.isNotEmpty) {
                    final match = headline.contains(_searchQuery) ||
                        user.contains(_searchQuery) ||
                        action.contains(_searchQuery) ||
                        entityType.contains(_searchQuery);
                    if (!match) return false;
                  }

                  return true;
                }).toList();

                if (filtered.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32.0),
                      child: Text('No matching audit records for this filter.', style: TextStyle(color: Colors.grey)),
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: filtered.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final log = filtered[index];
                    final action = (log['action'] ?? '').toString();
                    final headline = _formatHeadline(log);
                    final user = (log['userEmail'] ?? log['userName'] ?? 'Admin').toString();
                    final timestampRaw = log['timestamp'];

                    String formattedDate = '';
                    if (timestampRaw != null) {
                      DateTime? dt;
                      if (timestampRaw is Timestamp) dt = timestampRaw.toDate();
                      if (timestampRaw is String) dt = DateTime.tryParse(timestampRaw);
                      if (dt != null) {
                        formattedDate = DateFormat('dd MMM yyyy, hh:mm a').format(dt);
                      }
                    }

                    final badgeColor = _getActionColor(action, isDark);
                    final badgeBg = _getActionBgColor(action, isDark);

                    return InkWell(
                      onTap: () => _showLogDetailsSheet(context, log),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Action Badge
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: badgeBg,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: badgeColor, width: 1.2),
                              ),
                              child: Text(
                                _getActionBadgeText(action),
                                style: TextStyle(
                                  color: badgeColor,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.6,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            // Details
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    headline,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Icon(Icons.person_outline, size: 13, color: Colors.grey.shade600),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          user,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600),
                                        ),
                                      ),
                                      if (formattedDate.isNotEmpty) ...[
                                        const SizedBox(width: 8),
                                        Text(
                                          formattedDate,
                                          style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Icon(Icons.chevron_right, size: 18, color: Colors.grey),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _selectedCategory == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => setState(() => _selectedCategory = value),
      visualDensity: VisualDensity.compact,
    );
  }
}
