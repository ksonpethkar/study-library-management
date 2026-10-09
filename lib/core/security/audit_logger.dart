import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../constants/firestore_paths.dart';

enum AuditAction {
  created,
  updated,
  deleted,
  restored,
  login,
  logout,
  exported,
  imported,
  approved,
  rejected,
  voided,
  generated,
}

enum AuditEntity {
  student,
  seat,
  section,
  plan,
  payment,
  receipt,
  request,
  announcement,
  holiday,
  settings,
  library,
}

class AuditLogger {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Returns the correct scoped audit log collection reference for a library.
  /// Always writes to libraries/{libraryId}/audit_log so the AuditLogScreen
  /// can read from the correct path.
  CollectionReference<Map<String, dynamic>> _auditCollection(String? libraryId) {
    if (libraryId != null && libraryId.isNotEmpty) {
      return _firestore
          .collection(FirestorePaths.libraries)
          .doc(libraryId)
          .collection(FirestorePaths.auditLog);
    }
    // Fallback to top-level (should not normally happen)
    return _firestore.collection(FirestorePaths.auditLog);
  }

  /// Logs an audit event to the library-scoped Firestore audit log.
  /// [libraryId] must be provided so logs are scoped correctly per library.
  Future<void> log({
    required AuditAction action,
    required AuditEntity entityType,
    String? libraryId,
    String? entityId,
    String? entityName,
    Map<String, dynamic>? details,
    Map<String, dynamic>? previousData,
  }) async {
    try {
      final user = _auth.currentUser;
      final userId = user?.uid ?? 'system';
      final userEmail = user?.email ?? '';

      await _auditCollection(libraryId).add({
        'action': action.name,
        'entityType': entityType.name,
        'entityId': entityId,
        'entityName': entityName,
        'userId': userId,
        'userEmail': userEmail,
        'timestamp': FieldValue.serverTimestamp(),
        'details': details,
        'previousData': previousData,
      });
    } catch (e) {
      debugPrint('Audit log failed: $e');
    }
  }

  /// Retrieves audit logs for a specific library with optional filtering.
  Future<List<Map<String, dynamic>>> getAuditLogs({
    required String libraryId,
    AuditEntity? entityType,
    DateTime? startDate,
    DateTime? endDate,
    int limit = 50,
    DocumentSnapshot? startAfter,
  }) async {
    try {
      Query query = _auditCollection(libraryId)
          .orderBy('timestamp', descending: true)
          .limit(limit);

      if (entityType != null) {
        query = query.where('entityType', isEqualTo: entityType.name);
      }

      if (startDate != null) {
        query = query.where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate));
      }

      if (endDate != null) {
        query = query.where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(endDate));
      }

      if (startAfter != null) {
        query = query.startAfterDocument(startAfter);
      }

      final snapshot = await query.get();
      return snapshot.docs.map((doc) => {
        'id': doc.id,
        ...doc.data() as Map<String, dynamic>
      }).toList();
    } catch (e) {
      throw Exception('Failed to fetch audit logs. Please check your connection and try again.');
    }
  }
}
