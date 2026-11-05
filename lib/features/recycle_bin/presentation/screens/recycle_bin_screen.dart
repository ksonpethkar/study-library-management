import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:study_library/core/providers/library_provider.dart';
import 'package:study_library/core/widgets/empty_state_widget.dart';
import 'package:study_library/core/error/error_handler.dart';
import 'package:go_router/go_router.dart';
import 'package:study_library/core/router/app_router.dart';
import 'package:study_library/core/utils/error_formatter.dart';

class _RecycleBinEntry {
  final String id;
  final String type;
  final Map<String, dynamic> data;

  const _RecycleBinEntry({
    required this.id,
    required this.type,
    required this.data,
  });
}

class RecycleBinScreen extends ConsumerStatefulWidget {
  const RecycleBinScreen({super.key});

  @override
  ConsumerState<RecycleBinScreen> createState() => _RecycleBinScreenState();
}

class _RecycleBinScreenState extends ConsumerState<RecycleBinScreen> {
  String _selectedTab = 'All';

  final List<String> _tabs = [
    'All',
    'Students',
    'Receipts & Payments',
    'Plans',
    'Sections',
    'Announcements',
  ];

  Future<void> _restoreItem(String docId, Map<String, dynamic> data) async {
    final libraryId = ref.read(currentLibraryIdProvider) ?? '';
    if (libraryId.isEmpty) return;

    final type = (data['type'] ?? 'student').toString().toLowerCase();
    String targetCollection;
    switch (type) {
      case 'student':
        targetCollection = 'students';
        break;
      case 'receipt':
        targetCollection = 'receipts';
        break;
      case 'payment':
        targetCollection = 'payments';
        break;
      case 'section':
        targetCollection = 'sections';
        break;
      case 'plan':
        targetCollection = 'plans';
        break;
      case 'announcement':
        targetCollection = 'announcements';
        break;
      default:
        targetCollection = 'students';
    }

    final rawData = data['originalData'] is Map
        ? Map<String, dynamic>.from(data['originalData'] as Map)
        : Map<String, dynamic>.from(data);

    final restoreData = Map<String, dynamic>.from(rawData);
    restoreData.remove('deletedAt');
    restoreData.remove('type');
    restoreData.remove('libraryId');
    restoreData.remove('displayName');
    restoreData.remove('expiresAt');
    restoreData.remove('deletedBy');
    restoreData.remove('originalData');

    if (type == 'plan') {
      restoreData['deletedAt'] = null;
    }

    // Prevent double-booking / seat collision if restoring a student
    if (type == 'student' && restoreData['seatId'] != null) {
      final seatId = restoreData['seatId'] as String;
      final occupiedCheck = await FirebaseFirestore.instance
          .collection('libraries')
          .doc(libraryId)
          .collection('students')
          .where('seatId', isEqualTo: seatId)
          .where('membershipStatus', isEqualTo: 'active')
          .get();

      if (occupiedCheck.docs.isNotEmpty) {
        final otherStudent = occupiedCheck.docs.first.data()['name'] ?? 'another student';
        if (!mounted) return;
        final proceed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Colors.orange),
                SizedBox(width: 8),
                Text('Seat Already Occupied'),
              ],
            ),
            content: Text(
              'Desk "$seatId" is currently assigned to active student "$otherStudent".\n\nTo prevent a double-booking collision, would you like to restore this student with an unassigned seat status?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Restore Without Seat'),
              ),
            ],
          ),
        );

        if (proceed != true) return;
        restoreData['seatId'] = null;
      }
    }

    try {
      final batch = FirebaseFirestore.instance.batch();
      final targetRef = FirebaseFirestore.instance
          .collection('libraries')
          .doc(libraryId)
          .collection(targetCollection)
          .doc(docId);

      final libBinRef = FirebaseFirestore.instance
          .collection('libraries')
          .doc(libraryId)
          .collection('recycle_bin')
          .doc(docId);

      batch.set(targetRef, restoreData, SetOptions(merge: true));
      batch.delete(libBinRef);

      // If restoring a receipt, restore revenue aggregate
      if (type == 'receipt') {
        final amt = (data['amount'] as num?)?.toDouble() ?? 0.0;
        if (amt > 0) {
          final revRef = FirebaseFirestore.instance
              .collection('libraries')
              .doc(libraryId)
              .collection('settings')
              .doc('revenue_aggregate');
          batch.set(revRef, {'totalRevenue': FieldValue.increment(amt)}, SetOptions(merge: true));
        }
      }

      // If restoring an active payment, reduce the student's pending dues
      if (type == 'payment') {
        final amt = (data['amount'] as num?)?.toDouble() ?? 0.0;
        final studentId = data['studentId'] as String?;
        final payStatus = (data['status'] as String? ?? '').toLowerCase();
        if (amt > 0 && studentId != null && studentId.isNotEmpty && payStatus != 'voided' && payStatus != 'refunded') {
          try {
            final sDoc = await FirebaseFirestore.instance
                .collection('libraries')
                .doc(libraryId)
                .collection('students')
                .doc(studentId)
                .get();
            if (sDoc.exists) {
              final currentDue = (sDoc.data()?['pendingDueBalance'] as num?)?.toDouble() ?? 0.0;
              final newDue = (currentDue - amt).clamp(0.0, double.infinity);
              batch.update(sDoc.reference, {
                'pendingDueBalance': newDue,
                'updatedAt': FieldValue.serverTimestamp(),
              });
            }
          } catch (_) {}
        }
      }

      await batch.commit();

      try {
        await FirebaseFirestore.instance.collection('recycle_bin').doc(docId).delete();
      } catch (_) {}

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Restored ${type.toUpperCase()} successfully! ✓'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        AppErrorFormatter.showErrorSnackBar(context, e, actionContext: 'student');
      }
    }
  }

  Future<bool?> _showTypedDeleteConfirmation({
    required BuildContext context,
    required String title,
    required String message,
    String requiredWord = 'DELETE',
  }) {
    final textController = TextEditingController();
    return showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDlgState) {
            final isMatch = textController.text.trim().toUpperCase() == requiredWord;
            return AlertDialog(
              icon: const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 36),
              title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(message),
                  const SizedBox(height: 16),
                  Text(
                    'To confirm, please type "$requiredWord" below:',
                    style: TextStyle(fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.error),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: textController,
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: requiredWord,
                      border: const OutlineInputBorder(),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    onChanged: (_) => setDlgState(() {}),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: Colors.red),
                  onPressed: isMatch ? () => Navigator.pop(ctx, true) : null,
                  child: const Text('Delete Permanently'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _deletePermanently(String docId) async {
    final libraryId = ref.read(currentLibraryIdProvider) ?? '';
    if (libraryId.isEmpty) return;

    // S8 FIX: Require explicit typed confirmation before permanent deletion
    final confirm = await _showTypedDeleteConfirmation(
      context: context,
      title: 'Delete Forever?',
      message: 'This will permanently destroy this record. This action cannot be undone.',
      requiredWord: 'DELETE',
    );

    if (confirm != true) return;

    try {
      final batch = FirebaseFirestore.instance.batch();
      batch.delete(
        FirebaseFirestore.instance
            .collection('libraries')
            .doc(libraryId)
            .collection('recycle_bin')
            .doc(docId),
      );
      // Also delete from plans if it was a soft-deleted plan
      batch.delete(
        FirebaseFirestore.instance
            .collection('libraries')
            .doc(libraryId)
            .collection('plans')
            .doc(docId),
      );
      await batch.commit();

      try {
        await FirebaseFirestore.instance.collection('recycle_bin').doc(docId).delete();
      } catch (_) {}

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Permanently deleted.')),
        );
      }
    } catch (e) {
      if (mounted) {
        AppSnackbar.showError(context, e);
      }
    }
  }

  Future<void> _emptyRecycleBin(String libraryId) async {
    // S8 FIX: Require explicit typed confirmation before emptying entire recycle bin
    final confirm = await _showTypedDeleteConfirmation(
      context: context,
      title: 'Empty Recycle Bin?',
      message: 'This will permanently destroy ALL items in the recycle bin. No data can be restored afterwards.',
      requiredWord: 'EMPTY',
    );

    if (confirm != true) return;

    try {
      final snap1 = await FirebaseFirestore.instance
          .collection('libraries')
          .doc(libraryId)
          .collection('recycle_bin')
          .get();

      final batch = FirebaseFirestore.instance.batch();
      for (final doc in snap1.docs) {
        batch.delete(doc.reference);
      }

      // Also clean up any soft-deleted plans
      final snapPlans = await FirebaseFirestore.instance
          .collection('libraries')
          .doc(libraryId)
          .collection('plans')
          .get();
      for (final doc in snapPlans.docs) {
        if (doc.data()['deletedAt'] != null) {
          batch.delete(doc.reference);
        }
      }

      await batch.commit();

      try {
        final snap2 = await FirebaseFirestore.instance
            .collection('recycle_bin')
            .where('libraryId', isEqualTo: libraryId)
            .get();
        final rootBatch = FirebaseFirestore.instance.batch();
        for (final doc in snap2.docs) {
          rootBatch.delete(doc.reference);
        }
        await rootBatch.commit();
      } catch (_) {}

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Recycle bin emptied.')),
        );
      }
    } catch (e) {
      if (mounted) {
        AppErrorFormatter.showErrorSnackBar(context, e, actionContext: 'student');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final libraryId = ref.watch(currentLibraryIdProvider) ?? '';

    if (libraryId.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            tooltip: 'Back',
            onPressed: () => context.canPop() ? context.pop() : context.go(Routes.adminHome),
          ),
          title: const Text('Recycle Bin'),
        ),
        body: const Center(child: Text('Library not loaded')),
      );
    }

    final libBinStream = FirebaseFirestore.instance
        .collection('libraries')
        .doc(libraryId)
        .collection('recycle_bin')
        .snapshots();

    final plansStream = FirebaseFirestore.instance
        .collection('libraries')
        .doc(libraryId)
        .collection('plans')
        .snapshots();

    final globalBinStream = FirebaseFirestore.instance
        .collection('recycle_bin')
        .where('libraryId', isEqualTo: libraryId)
        .snapshots()
        .handleError((e) {
      debugPrint('Global bin query note: $e');
    });

    return DefaultTabController(
      length: _tabs.length,
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            tooltip: 'Back',
            onPressed: () => context.canPop() ? context.pop() : context.go(Routes.adminHome),
          ),
          title: const Text('Recycle Bin'),
          actions: [
            TextButton.icon(
              onPressed: () => _emptyRecycleBin(libraryId),
              icon: const Icon(Icons.delete_sweep_rounded, color: Colors.red),
              label: const Text('Empty All', style: TextStyle(color: Colors.red)),
            ),
          ],
          bottom: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            onTap: (index) {
              setState(() {
                _selectedTab = _tabs[index];
              });
            },
            tabs: _tabs.map((t) => Tab(text: t)).toList(),
          ),
        ),
        body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: libBinStream,
          builder: (context, snapshot1) {
            if (snapshot1.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline_rounded, size: 48, color: Colors.red),
                      const SizedBox(height: 12),
                      Text(
                        AppErrorFormatter.toUserFriendly(snapshot1.error),
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                ),
              );
            }

            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: plansStream,
              builder: (context, snapshotPlans) {
                return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: globalBinStream,
                  builder: (context, snapshot2) {
                    if (snapshot1.connectionState == ConnectionState.waiting &&
                        !snapshot1.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    // Combine and de-duplicate by document ID
                    final itemMap = <String, _RecycleBinEntry>{};

                    if (snapshot1.hasData && snapshot1.data != null) {
                      for (final d in snapshot1.data!.docs) {
                        final raw = d.data();
                        final unwrap = (raw['originalData'] is Map)
                            ? {...(raw['originalData'] as Map).cast<String, dynamic>(), ...raw}
                            : raw;
                        final type = (unwrap['type'] ?? 'student').toString().toLowerCase();
                        itemMap[d.id] = _RecycleBinEntry(id: d.id, type: type, data: unwrap);
                      }
                    }

                    if (snapshotPlans.hasData && snapshotPlans.data != null) {
                      for (final d in snapshotPlans.data!.docs) {
                        final pData = d.data();
                        if (pData['deletedAt'] != null && !itemMap.containsKey(d.id)) {
                          final merged = {
                            ...pData,
                            'id': d.id,
                            'type': 'plan',
                            'name': pData['name'] ?? 'Plan',
                            'displayName': pData['name'] ?? 'Plan',
                          };
                          itemMap[d.id] = _RecycleBinEntry(id: d.id, type: 'plan', data: merged);
                        }
                      }
                    }

                    if (snapshot2.hasData && snapshot2.data != null) {
                      for (final d in snapshot2.data!.docs) {
                        if (!itemMap.containsKey(d.id)) {
                          final raw = d.data();
                          final unwrap = (raw['originalData'] is Map)
                              ? {...(raw['originalData'] as Map).cast<String, dynamic>(), ...raw}
                              : raw;
                          final type = (unwrap['type'] ?? 'student').toString().toLowerCase();
                          itemMap[d.id] = _RecycleBinEntry(id: d.id, type: type, data: unwrap);
                        }
                      }
                    }

                    final entries = itemMap.values.toList();
                    // Sort newest deletedAt first
                    entries.sort((a, b) {
                      final aDate = a.data['deletedAt'];
                      final bDate = b.data['deletedAt'];
                      final dtA = aDate is Timestamp ? aDate.toDate() : (aDate is String ? DateTime.tryParse(aDate) : null);
                      final dtB = bDate is Timestamp ? bDate.toDate() : (bDate is String ? DateTime.tryParse(bDate) : null);
                      if (dtA == null && dtB == null) return 0;
                      if (dtA == null) return 1;
                      if (dtB == null) return -1;
                      return dtB.compareTo(dtA);
                    });

                    List<_RecycleBinEntry> filteredDocs;

                    if (_selectedTab == 'Students') {
                      filteredDocs = entries.where((e) => e.type == 'student').toList();
                    } else if (_selectedTab == 'Receipts & Payments' || _selectedTab == 'Receipts' || _selectedTab == 'Payments') {
                      filteredDocs = entries.where((e) => e.type == 'receipt' || e.type == 'payment').toList();
                    } else if (_selectedTab == 'Plans') {
                      filteredDocs = entries.where((e) => e.type == 'plan').toList();
                    } else if (_selectedTab == 'Sections') {
                      filteredDocs = entries.where((e) => e.type == 'section').toList();
                    } else if (_selectedTab == 'Announcements') {
                      filteredDocs = entries.where((e) => e.type == 'announcement').toList();
                    } else {
                      filteredDocs = entries;
                    }

                    if (filteredDocs.isEmpty) {
                      return EmptyStateWidget(
                        icon: Icons.delete_outline_rounded,
                        title: 'No deleted ${_selectedTab == "All" ? "items" : _selectedTab.toLowerCase()} found!',
                        message: 'Deleted items appear here for 30 days and can be restored anytime.',
                      );
                    }

                    return RefreshIndicator(
                      onRefresh: () async {
                        setState(() {});
                        await Future.delayed(const Duration(milliseconds: 400));
                      },
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: filteredDocs.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final item = filteredDocs[index];
                          final data = item.data;
                          final type = item.type;

                      // Smart display name, subtitle and icon
                      String title;
                      String subtitle;
                      IconData typeIcon;
                      Color typeColor;

                      switch (type) {
                        case 'receipt':
                          title = data['displayName'] ?? 'Receipt #${data['receiptNumber'] ?? item.id}';
                          subtitle = 'Amount: ₹${(data['amount'] as num?)?.toDouble().toStringAsFixed(0) ?? 0} • Paid via: ${data['paymentMethod'] ?? 'Cash'}';
                          typeIcon = Icons.receipt_long_rounded;
                          typeColor = Colors.orange;
                          break;
                        case 'payment':
                          title = data['displayName'] ?? 'Payment: ₹${(data['amount'] as num?)?.toDouble().toStringAsFixed(0) ?? 0}';
                          subtitle = 'Method: ${data['paymentMethod'] ?? data['method'] ?? 'Cash'}';
                          typeIcon = Icons.payments_rounded;
                          typeColor = Colors.green;
                          break;
                        case 'plan':
                          title = data['name'] ?? 'Plan';
                          subtitle = 'Fee: ₹${data['price']} • ${data['duration']} ${data['durationUnit'] ?? "months"}';
                          typeIcon = Icons.card_membership_rounded;
                          typeColor = Colors.purple;
                          break;
                        case 'section':
                          title = data['name'] ?? 'Section / Hall';
                          subtitle = '${data['totalSeats'] ?? "Configured"} seats';
                          typeIcon = Icons.meeting_room_rounded;
                          typeColor = Colors.teal;
                          break;
                        case 'announcement':
                          title = data['title'] ?? 'Announcement';
                          subtitle = data['message'] ?? '';
                          typeIcon = Icons.campaign_rounded;
                          typeColor = Colors.deepOrange;
                          break;
                        case 'student':
                        default:
                          title = data['name'] ?? 'Student';
                          final phone = data['phone'] ?? '';
                          final seat = data['seatId'] ?? '';
                          subtitle = '${phone.isNotEmpty ? "Phone: $phone" : ""}${seat.isNotEmpty ? " • Seat: $seat" : ""}';
                          typeIcon = Icons.person_rounded;
                          typeColor = Colors.blue;
                          break;
                      }

                      final deletedAtRaw = data['deletedAt'];
                      String deletedDate = '';
                      int remainingDays = 30;
                      if (deletedAtRaw != null) {
                        DateTime? dt;
                        if (deletedAtRaw is Timestamp) dt = deletedAtRaw.toDate();
                        if (deletedAtRaw is String) dt = DateTime.tryParse(deletedAtRaw);
                        if (dt != null) {
                          deletedDate = DateFormat('dd MMM yyyy').format(dt);
                          final elapsed = DateTime.now().difference(dt).inDays;
                          remainingDays = (30 - elapsed).clamp(0, 30);
                        }
                      }

                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: typeColor.withValues(alpha: 0.12),
                          child: Icon(typeIcon, color: typeColor, size: 22),
                        ),
                        title: Text(
                          title,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (subtitle.isNotEmpty)
                              Text(subtitle, style: const TextStyle(fontSize: 12.5)),
                            const SizedBox(height: 3),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: typeColor.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    type.toUpperCase(),
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: typeColor,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                if (deletedDate.isNotEmpty)
                                  Text(
                                    'Deleted: $deletedDate',
                                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                                  ),
                                const Spacer(),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: remainingDays <= 5 ? Colors.red.shade100 : Colors.amber.shade100,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    '$remainingDays days left',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: remainingDays <= 5 ? Colors.red.shade900 : Colors.amber.shade900,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.restore_rounded, color: Colors.green),
                              tooltip: 'Restore $type',
                              onPressed: () => _restoreItem(item.id, data),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_forever_rounded, color: Colors.red),
                              tooltip: 'Delete Forever',
                              onPressed: () => _deletePermanently(item.id),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                );
              },
            );
          },
        );
      },
    ),
  ),
);
}
}
