import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:study_library/core/providers/library_provider.dart';
import 'package:study_library/core/widgets/empty_state_widget.dart';

class AuditLogScreen extends ConsumerWidget {
  const AuditLogScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final libraryId = ref.watch(currentLibraryIdProvider) ?? '';

    if (libraryId.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Audit Log')),
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
        title: const Text('Audit Log'),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: stream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            return const EmptyStateWidget(
              icon: Icons.fact_check_outlined,
              title: 'No activity recorded yet',
              message: 'All your actions and library activities will be tracked here.',
            );
          }

          // Sort in Dart by timestamp descending to avoid composite index requirement
          final logs = docs.map((d) => d.data()).toList();
          logs.sort((a, b) {
            final aTime = a['timestamp']?.toString() ?? '';
            final bTime = b['timestamp']?.toString() ?? '';
            return bTime.compareTo(aTime);
          });

          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: logs.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final log = logs[index];
              final action = log['action'] ?? log['message'] ?? 'Action performed';
              final user = log['userName'] ?? log['userEmail'] ?? 'Admin';
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

              IconData icon = Icons.info_outline;
              Color color = Colors.blue;
              final actionLower = action.toString().toLowerCase();
              if (actionLower.contains('create') || actionLower.contains('add')) {
                icon = Icons.add_circle_outline;
                color = Colors.green;
              } else if (actionLower.contains('delete') || actionLower.contains('remove')) {
                icon = Icons.delete_outline;
                color = Colors.red;
              } else if (actionLower.contains('update') || actionLower.contains('edit')) {
                icon = Icons.edit_outlined;
                color = Colors.orange;
              }

              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: color.withValues(alpha: 0.1),
                  child: Icon(icon, color: color, size: 20),
                ),
                title: Text(action.toString(), style: const TextStyle(fontWeight: FontWeight.w500)),
                subtitle: Text('By $user${formattedDate.isNotEmpty ? ' • $formattedDate' : ''}'),
              );
            },
          );
        },
      ),
    );
  }
}
