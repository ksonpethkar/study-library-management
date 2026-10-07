import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:study_library/core/providers/library_provider.dart';

class StudentHistoryScreen extends ConsumerWidget {
  final String studentId;
  
  const StudentHistoryScreen({super.key, required this.studentId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final libraryId = ref.watch(currentLibraryIdProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('History')),
      body: libraryId == null || libraryId.isEmpty
          ? const Center(child: Text('No library selected'))
          : StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('libraries')
                  .doc(libraryId)
                  .collection('audit_log')
                  .where('studentId', isEqualTo: studentId)
                  .orderBy('timestamp', descending: true)
                  .limit(50)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snapshot.data?.docs ?? [];
                
                if (docs.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(48),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.history_rounded, size: 64, color: Colors.grey),
                          SizedBox(height: 16),
                          Text('No history yet', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          SizedBox(height: 8),
                          Text('Activity will appear here as changes are made.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;
                    final title = data['action'] ?? data['type'] ?? 'Unknown Action';
                    final subtitle = data['description'] ?? data['details']?.toString() ?? 'No description';
                    final timestamp = data['timestamp'] ?? data['createdAt'];
                    String dateStr = '';
                    if (timestamp is Timestamp) {
                      dateStr = DateFormat('dd MMM yyyy, hh:mm a').format(timestamp.toDate());
                    } else if (timestamp != null) {
                      dateStr = timestamp.toString();
                    }

                    return ListTile(
                      leading: const Icon(Icons.history),
                      title: Text(title.toString().toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(subtitle),
                      trailing: Text(dateStr, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    );
                  },
                );
              },
            ),
    );
  }
}
