import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:study_library/core/security/audit_logger.dart';
import 'package:study_library/features/auth/presentation/providers/auth_provider.dart';

final auditLoggerProvider = Provider<AuditLogger>((ref) {
  return AuditLogger();
});

/// Streams all audit log records for the active library, sorted by timestamp descending.
final auditLogStreamProvider = StreamProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  final libraryId = ref.watch(currentLibraryIdProvider);
  if (libraryId == null || libraryId.isEmpty) {
    return Stream.value([]);
  }

  return FirebaseFirestore.instance
      .collection('libraries')
      .doc(libraryId)
      .collection('audit_log')
      .snapshots()
      .map((snapshot) {
    final logs = snapshot.docs.map((doc) => {...doc.data(), 'id': doc.id}).toList();
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
    return logs;
  });
});
