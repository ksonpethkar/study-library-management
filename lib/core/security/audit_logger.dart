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

  /// Logs an audit event to Firestore.
  Future<void> log({
    required AuditAction action,
    required AuditEntity entityType,
    String? entityId,
    Map<String, dynamic>? details,
    Map<String, dynamic>? previousData,
  }) async {
    try {
      final user = _auth.currentUser;
      final userId = user?.uid ?? 'system';

      await _firestore.collection(FirestorePaths.auditLog).add({
        'action': action.name,
        'entityType': entityType.name,
        'entityId': entityId,
        'userId': userId,
        'timestamp': FieldValue.serverTimestamp(),
        'details': details,
        'previousData': previousData,
      });
    } catch (e) {
      // Print to debug console; in production, consider Crashlytics
      debugPrint('Audit log failed: $e');
    }
  }

  /// Retrieves audit logs with optional pagination and filtering.
  Future<List<Map<String, dynamic>>> getAuditLogs({
    AuditEntity? entityType,
    DateTime? startDate,
    DateTime? endDate,
    int limit = 50,
    DocumentSnapshot? startAfter,
  }) async {
    try {
      Query query = _firestore.collection(FirestorePaths.auditLog)
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
