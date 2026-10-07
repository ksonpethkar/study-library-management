import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:study_library/core/providers/library_provider.dart';
import 'package:study_library/core/widgets/empty_state_widget.dart';

class RecycleBinScreen extends ConsumerStatefulWidget {
  const RecycleBinScreen({super.key});

  @override
  ConsumerState<RecycleBinScreen> createState() => _RecycleBinScreenState();
}

class _RecycleBinScreenState extends ConsumerState<RecycleBinScreen> {
  String _selectedTab = 'All';

  Future<void> _restoreItem(String docId, Map<String, dynamic> data) async {
    final libraryId = ref.read(currentLibraryIdProvider) ?? '';
    if (libraryId.isEmpty) return;

    final type = data['type']?.toString().toLowerCase() ?? 'student';
    final targetCollection = type == 'section' ? 'sections' : type == 'plan' ? 'plans' : 'students';

    final restoreData = Map<String, dynamic>.from(data);
    restoreData.remove('deletedAt');
    restoreData.remove('type');
    restoreData.remove('libraryId');

    try {
      final batch = FirebaseFirestore.instance.batch();
      final targetRef = FirebaseFirestore.instance
          .collection('libraries')
          .doc(libraryId)
          .collection(targetCollection)
          .doc(docId);
      final binRef = FirebaseFirestore.instance
          .collection('libraries')
          .doc(libraryId)
          .collection('recycle_bin')
          .doc(docId);

      batch.set(targetRef, restoreData);
      batch.delete(binRef);

      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Restored successfully! ✓')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to restore: $e')),
        );
      }
    }
  }

  Future<void> _deletePermanently(String docId) async {
    final libraryId = ref.read(currentLibraryIdProvider) ?? '';
    if (libraryId.isEmpty) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Forever'),
        content: const Text('This will permanently delete this item. This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete Forever'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await FirebaseFirestore.instance
          .collection('libraries')
          .doc(libraryId)
          .collection('recycle_bin')
          .doc(docId)
          .delete();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Permanently deleted.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _emptyRecycleBin(String libraryId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Empty Recycle Bin?'),
        content: const Text(
          'This will permanently delete all items in the recycle bin. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Empty Bin'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final snap = await FirebaseFirestore.instance
          .collection('libraries')
          .doc(libraryId)
          .collection('recycle_bin')
          .get();

      final batch = FirebaseFirestore.instance.batch();
      for (final doc in snap.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Recycle bin emptied.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to empty recycle bin: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final libraryId = ref.watch(currentLibraryIdProvider) ?? '';

    if (libraryId.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Recycle Bin')),
        body: const Center(child: Text('Library not loaded')),
      );
    }

    final stream = FirebaseFirestore.instance
        .collection('libraries')
        .doc(libraryId)
        .collection('recycle_bin')
        .snapshots();

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Recycle Bin'),
          actions: [
            TextButton.icon(
              onPressed: () => _emptyRecycleBin(libraryId),
              icon: const Icon(Icons.delete_sweep_rounded, color: Colors.red),
              label:
                  const Text('Empty All', style: TextStyle(color: Colors.red)),
            ),
          ],
          bottom: TabBar(
            onTap: (index) {
              setState(() {
                _selectedTab = ['All', 'Students', 'Sections', 'Plans'][index];
              });
            },
            tabs: const [
              Tab(text: 'All'),
              Tab(text: 'Students'),
              Tab(text: 'Sections'),
              Tab(text: 'Plans'),
            ],
          ),
        ),
        body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: stream,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final docs = snapshot.data?.docs ?? [];
            var filteredDocs = docs;

            if (_selectedTab == 'Students') {
              filteredDocs = docs.where((d) => (d.data()['type'] ?? 'student') == 'student').toList();
            } else if (_selectedTab == 'Sections') {
              filteredDocs = docs.where((d) => (d.data()['type'] ?? '') == 'section').toList();
            } else if (_selectedTab == 'Plans') {
              filteredDocs = docs.where((d) => (d.data()['type'] ?? '') == 'plan').toList();
            }

            if (filteredDocs.isEmpty) {
              return const EmptyStateWidget(
                icon: Icons.delete_outline_rounded,
                title: 'Recycle bin is empty!',
                message: 'Deleted items will appear here for 30 days and can be restored anytime.',
              );
            }

            return RefreshIndicator(
              onRefresh: () async {
                setState(() {});
                await Future.delayed(const Duration(milliseconds: 500));
              },
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: filteredDocs.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) {
                final doc = filteredDocs[index];
                final data = doc.data();
                final name = data['name'] ?? 'Item';
                final type = data['type'] ?? 'student';
                final deletedAtRaw = data['deletedAt'];

                String deletedDate = '';
                int remainingDays = 30;
                if (deletedAtRaw != null) {
                  DateTime? dt;
                  if (deletedAtRaw is Timestamp) dt = deletedAtRaw.toDate();
                  if (deletedAtRaw is String) {
                    dt = DateTime.tryParse(deletedAtRaw);
                  }
                  if (dt != null) {
                    deletedDate = DateFormat('dd MMM yyyy').format(dt);
                    final elapsed = DateTime.now().difference(dt).inDays;
                    remainingDays = (30 - elapsed).clamp(0, 30);
                  }
                }

                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.red.withValues(alpha: 0.1),
                    child: const Icon(Icons.delete_outline, color: Colors.red),
                  ),
                  title: Text(name.toString()),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Type: ${type.toString().toUpperCase()}${deletedDate.isNotEmpty ? ' • Deleted: $deletedDate' : ''}',
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: remainingDays <= 5
                              ? Colors.red.shade100
                              : Colors.amber.shade100,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '$remainingDays days left',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: remainingDays <= 5
                                ? Colors.red.shade900
                                : Colors.amber.shade900,
                          ),
                        ),
                      ),
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.restore, color: Colors.green),
                        tooltip: 'Restore',
                        onPressed: () => _restoreItem(doc.id, data),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_forever, color: Colors.red),
                        tooltip: 'Delete Forever',
                        onPressed: () => _deletePermanently(doc.id),
                      ),
                    ],
                  ),
                );
              },
            ),
          );
        },
      ),
      ),
    );
  }
}
