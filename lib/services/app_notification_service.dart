import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:study_library/core/providers/library_provider.dart';
import 'package:study_library/models/app_notification_model.dart';
import 'package:study_library/services/notification_service.dart';

/// Stream of all notifications for the given library
final libraryNotificationsStreamProvider =
    StreamProvider.family<List<AppNotificationModel>, String>((ref, libraryId) {
  if (libraryId.isEmpty) return Stream.value([]);

  return FirebaseFirestore.instance
      .collection('libraries')
      .doc(libraryId)
      .collection('notifications')
      .orderBy('createdAt', descending: true)
      .limit(50)
      .snapshots()
      .map((snap) => snap.docs.map((doc) => AppNotificationModel.fromFirestore(doc)).toList());
});

/// Helper to deduplicate notifications that share the same title and body.
/// Collapses duplicates, preserves unread status if any duplicate is unread,
/// and schedules background cleanup of orphan duplicate documents in Firestore.
List<AppNotificationModel> _deduplicateNotifications(List<AppNotificationModel> list, [String? libraryId]) {
  final Map<String, AppNotificationModel> uniqueMap = {};
  final List<String> orphanDocIds = [];

  for (final n in list) {
    final normTitle = n.title.trim().toLowerCase();
    final normBody = n.body.trim().toLowerCase();
    final key = '${n.type.toLowerCase()}_${normTitle}_$normBody';

    if (!uniqueMap.containsKey(key)) {
      uniqueMap[key] = n;
    } else {
      final existing = uniqueMap[key]!;
      // Keep newer notification timestamp
      final keepNewer = n.createdAt.isAfter(existing.createdAt);
      final isUnread = (!existing.read) || (!n.read);

      final winner = keepNewer ? n : existing;
      final loser = keepNewer ? existing : n;

      uniqueMap[key] = winner.copyWith(read: !isUnread);
      orphanDocIds.add(loser.id);
    }
  }

  // Background self-healing: purge orphan duplicate documents from Firestore
  if (libraryId != null && libraryId.isNotEmpty && orphanDocIds.isNotEmpty) {
    Future.microtask(() async {
      try {
        final batch = FirebaseFirestore.instance.batch();
        for (final orphanId in orphanDocIds) {
          final ref = FirebaseFirestore.instance
              .collection('libraries')
              .doc(libraryId)
              .collection('notifications')
              .doc(orphanId);
          batch.delete(ref);
        }
        await batch.commit();
      } catch (_) {}
    });
  }

  return uniqueMap.values.toList();
}

/// Stream of admin-targeted notifications
final adminNotificationsStreamProvider = StreamProvider<List<AppNotificationModel>>((ref) {
  final libraryId = ref.watch(currentLibraryIdProvider);
  if (libraryId == null || libraryId.isEmpty) return Stream.value([]);

  return FirebaseFirestore.instance
      .collection('libraries')
      .doc(libraryId)
      .collection('notifications')
      .orderBy('createdAt', descending: true)
      .limit(50)
      .snapshots()
      .map((snap) {
        final all = snap.docs.map((doc) => AppNotificationModel.fromFirestore(doc)).toList();
        final filtered = all.where((n) => n.targetRole == 'admin' || n.targetRole == 'all').toList();
        return _deduplicateNotifications(filtered, libraryId);
      });
});

/// Stream of student-targeted notifications for the current student
final studentNotificationsStreamProvider =
    StreamProvider.family<List<AppNotificationModel>, String?>((ref, studentId) {
  final libraryId = ref.watch(currentLibraryIdProvider);
  if (libraryId == null || libraryId.isEmpty) return Stream.value([]);

  final authUid = FirebaseAuth.instance.currentUser?.uid;
  final effectiveId = (studentId != null && studentId.trim().isNotEmpty)
      ? studentId.trim()
      : authUid;

  // STRICT PRIVACY PROTECTION:
  // If effectiveId is null or empty, this user is not authenticated.
  // They MUST NOT receive any personal student alerts (receipts, admissions, feedback, seat changes).
  if (effectiveId == null || effectiveId.isEmpty) {
    return FirebaseFirestore.instance
        .collection('libraries')
        .doc(libraryId)
        .collection('notifications')
        .orderBy('createdAt', descending: true)
        .limit(20)
        .snapshots()
        .map((snap) {
          final all = snap.docs.map((doc) => AppNotificationModel.fromFirestore(doc)).toList();
          return all.where((n) => n.targetRole == 'all' && (n.targetUserId == null || n.targetUserId!.isEmpty)).toList();
        });
  }

  return FirebaseFirestore.instance
      .collection('libraries')
      .doc(libraryId)
      .collection('notifications')
      .orderBy('createdAt', descending: true)
      .limit(50)
      .snapshots()
      .map((snap) {
        final all = snap.docs.map((doc) => AppNotificationModel.fromFirestore(doc)).toList();
        // Strict privacy filter:
        // A student ONLY sees:
        // 1. Notifications explicitly addressed to THIS specific student (targetUserId == effectiveId or targetUserId == authUid)
        // 2. General public broadcasts intended for ALL users (type == 'announcement' with NO student-specific data)
        final filtered = all.where((n) {
          if (n.targetUserId != null && n.targetUserId!.trim().isNotEmpty) {
            return n.targetUserId == effectiveId ||
                (authUid != null && n.targetUserId == authUid) ||
                (studentId != null && n.targetUserId == studentId);
          }
          final personalTypes = {
            'payment',
            'receipt',
            'admission',
            'seat',
            'seat_change',
            'feedback',
            'feedback_reply',
            'expiry',
            'due'
          };
          if (personalTypes.contains(n.type.toLowerCase())) {
            return false; // Hard reject untargeted sensitive notifications
          }
          return n.targetRole == 'all' || n.targetRole == 'student' || n.type == 'announcement';
        }).toList();
        return _deduplicateNotifications(filtered, libraryId);
      });
});

class AppNotificationService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Dispatches a notification across the system:
  /// 1. Persists to Firestore `/libraries/{libId}/notifications`
  /// 2. Fires Android status bar notification with BigTextStyle short message
  static Future<String> sendNotification({
    required String libraryId,
    required String title,
    required String body,
    required String type, // 'payment', 'admission', 'seat', 'expiry', 'announcement', 'general'
    String targetRole = 'all', // 'admin', 'student', 'all'
    String? targetUserId,
    String? actionRoute,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      // Deduplicate recent identical dispatches within 30 minutes to prevent double-writes
      if (libraryId.isNotEmpty && type != 'general') {
        try {
          final recentSnap = await _firestore
              .collection('libraries')
              .doc(libraryId)
              .collection('notifications')
              .where('type', isEqualTo: type)
              .limit(10)
              .get();

          final isDuplicate = recentSnap.docs.any((d) {
            final dData = d.data();
            final dTitle = (dData['title'] ?? '').toString().trim().toLowerCase();
            final dBody = (dData['body'] ?? '').toString().trim().toLowerCase();
            final dTarget = (dData['targetUserId'] ?? '').toString().trim();
            final dCreated = (dData['createdAt'] as Timestamp?)?.toDate();

            if (dTitle == title.trim().toLowerCase() && dBody == body.trim().toLowerCase()) {
              if (targetUserId == null || targetUserId.isEmpty || dTarget == targetUserId) {
                if (dCreated != null && DateTime.now().difference(dCreated).inMinutes < 60) {
                  return true;
                }
              }
            }
            return false;
          });

          if (isDuplicate) {
            if (kDebugMode) debugPrint('[NotificationService] Suppressed duplicate notification write: $title');
            return '';
          }
        } catch (_) {}
      }

      // Check automation rules configured in Communications Hub
      if (libraryId.isNotEmpty) {
        try {
          final commDoc = await _firestore
              .collection('libraries')
              .doc(libraryId)
              .collection('settings')
              .doc('communications')
              .get();
          final rules = commDoc.data()?['rules'] as Map<String, dynamic>?;
          if (rules != null) {
            final allEnabled = rules['allNotifications'] as bool? ?? true;
            if (!allEnabled) return '';

            final isAllowed = switch (type) {
              'admission' => rules['newStudentRequest'] as bool? ?? true,
              'expiry' => rules['planExpiring'] as bool? ?? true,
              'announcement' => rules['announcementPush'] as bool? ?? true,
              'payment' => rules['paymentReceipts'] as bool? ?? true,
              _ => true,
            };
            if (!isAllowed) return '';
          }
        } catch (_) {}
      }

      final docRef = _firestore
          .collection('libraries')
          .doc(libraryId)
          .collection('notifications')
          .doc();

      final model = AppNotificationModel(
        id: docRef.id,
        title: title,
        body: body,
        type: type,
        read: false,
        createdAt: DateTime.now(),
        targetRole: targetRole,
        targetUserId: targetUserId,
        actionRoute: actionRoute,
        metadata: metadata ?? {},
      );

      await docRef.set(model.toFirestore());

      // Trigger Android system notification with short message snippet
      final channelId = switch (type) {
        'payment' || 'expiry' => NotificationService.channelFeeAlerts,
        'announcement' => NotificationService.channelAnnouncements,
        'seat' => NotificationService.channelAttendance,
        _ => NotificationService.channelGeneral,
      };

      await NotificationService.showNotification(
        title: title,
        body: body,
        channelId: channelId,
        payload: actionRoute,
      );

      return docRef.id;
    } catch (e) {
      if (kDebugMode) debugPrint('Error sending notification: $e');
      return '';
    }
  }

  /// Mark single notification as read (removes individual unread dot)
  static Future<void> markAsRead({
    required String libraryId,
    required String notificationId,
  }) async {
    try {
      await _firestore
          .collection('libraries')
          .doc(libraryId)
          .collection('notifications')
          .doc(notificationId)
          .update({'read': true});
    } catch (e) {
      if (kDebugMode) debugPrint('Error marking notification as read: $e');
    }
  }

  /// Mark all notifications as read for current viewer
  static Future<void> markAllAsRead({
    required String libraryId,
    required String targetRole,
    String? targetUserId,
  }) async {
    try {
      final snap = await _firestore
          .collection('libraries')
          .doc(libraryId)
          .collection('notifications')
          .where('read', isEqualTo: false)
          .get();

      final currentAuthUid = FirebaseAuth.instance.currentUser?.uid;
      final batch = _firestore.batch();
      int updateCount = 0;

      for (final doc in snap.docs) {
        final data = doc.data();
        final role = data['targetRole'] as String? ?? 'all';
        if (role != targetRole && role != 'all') {
          continue;
        }

        if (targetUserId != null && targetUserId.isNotEmpty) {
          final dTarget = data['targetUserId'] as String?;
          final metaStudentId = (data['metadata'] as Map?)?['studentId'] as String?;
          final metaUserId = (data['metadata'] as Map?)?['studentUserId'] as String?;

          final matches = dTarget == null ||
              dTarget.isEmpty ||
              dTarget == targetUserId ||
              (currentAuthUid != null && dTarget == currentAuthUid) ||
              (metaStudentId != null && (metaStudentId == targetUserId || metaStudentId == currentAuthUid)) ||
              (metaUserId != null && (metaUserId == targetUserId || metaUserId == currentAuthUid));

          if (!matches) continue;
        }

        batch.update(doc.reference, {'read': true});
        updateCount++;
      }
      if (updateCount > 0) {
        await batch.commit();
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Error marking all notifications as read: $e');
    }
  }

  /// Delete notification
  static Future<void> deleteNotification({
    required String libraryId,
    required String notificationId,
  }) async {
    try {
      await _firestore
          .collection('libraries')
          .doc(libraryId)
          .collection('notifications')
          .doc(notificationId)
          .delete();
    } catch (e) {
      if (kDebugMode) debugPrint('Error deleting notification: $e');
    }
  }

  /// Permanently removes all read notifications for this user/role
  static Future<void> clearAllRead({
    required String libraryId,
    required String targetRole,
    String? targetUserId,
  }) async {
    try {
      final snap = await _firestore
          .collection('libraries')
          .doc(libraryId)
          .collection('notifications')
          .where('read', isEqualTo: true)
          .get();

      final currentAuthUid = FirebaseAuth.instance.currentUser?.uid;
      final batch = _firestore.batch();
      int deleteCount = 0;

      for (final doc in snap.docs) {
        final data = doc.data();
        final role = data['targetRole'] as String? ?? 'all';
        if (role != targetRole && role != 'all') {
          continue;
        }

        if (targetUserId != null && targetUserId.isNotEmpty) {
          final dTarget = data['targetUserId'] as String?;
          final metaStudentId = (data['metadata'] as Map?)?['studentId'] as String?;
          final metaUserId = (data['metadata'] as Map?)?['studentUserId'] as String?;

          final matches = dTarget == null ||
              dTarget.isEmpty ||
              dTarget == targetUserId ||
              (currentAuthUid != null && dTarget == currentAuthUid) ||
              (metaStudentId != null && (metaStudentId == targetUserId || metaStudentId == currentAuthUid)) ||
              (metaUserId != null && (metaUserId == targetUserId || metaUserId == currentAuthUid));

          if (!matches) continue;
        }

        batch.delete(doc.reference);
        deleteCount++;
      }
      if (deleteCount > 0) {
        await batch.commit();
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Error clearing read notifications: $e');
    }
  }
}

/// Acknowledged state of dynamic administrative system alerts (Pending applications, Expiring plans)
class SystemAlertsState {
  final int acknowledgedPendingCount;
  final int acknowledgedRenewalsCount;

  const SystemAlertsState({
    this.acknowledgedPendingCount = 0,
    this.acknowledgedRenewalsCount = 0,
  });

  SystemAlertsState copyWith({
    int? acknowledgedPendingCount,
    int? acknowledgedRenewalsCount,
  }) {
    return SystemAlertsState(
      acknowledgedPendingCount: acknowledgedPendingCount ?? this.acknowledgedPendingCount,
      acknowledgedRenewalsCount: acknowledgedRenewalsCount ?? this.acknowledgedRenewalsCount,
    );
  }
}

/// Notifier to track and persist acknowledged system alert counts across app sessions
class SystemAlertsNotifier extends StateNotifier<SystemAlertsState> {
  final String libraryId;
  static final Map<String, SystemAlertsState> _cache = {};

  SystemAlertsNotifier(this.libraryId)
      : super(_cache[libraryId] ?? const SystemAlertsState()) {
    _loadFromPrefs();
  }

  Future<void> _loadFromPrefs() async {
    if (libraryId.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final ackPending = prefs.getInt('ack_pending_$libraryId') ?? 0;
      final ackRenewals = prefs.getInt('ack_renewals_$libraryId') ?? 0;
      final loaded = SystemAlertsState(
        acknowledgedPendingCount: ackPending,
        acknowledgedRenewalsCount: ackRenewals,
      );
      _cache[libraryId] = loaded;
      state = loaded;
    } catch (e) {
      if (kDebugMode) debugPrint('Error loading system alerts state: $e');
    }
  }

  Future<void> acknowledgePending(int count) async {
    state = state.copyWith(acknowledgedPendingCount: count);
    if (libraryId.isEmpty) return;
    _cache[libraryId] = state;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('ack_pending_$libraryId', count);
    } catch (_) {}
  }

  Future<void> acknowledgeRenewals(int count) async {
    state = state.copyWith(acknowledgedRenewalsCount: count);
    if (libraryId.isEmpty) return;
    _cache[libraryId] = state;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('ack_renewals_$libraryId', count);
    } catch (_) {}
  }

  Future<void> acknowledgeAll({required int pendingCount, required int renewalsCount}) async {
    state = SystemAlertsState(
      acknowledgedPendingCount: pendingCount,
      acknowledgedRenewalsCount: renewalsCount,
    );
    if (libraryId.isEmpty) return;
    _cache[libraryId] = state;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('ack_pending_$libraryId', pendingCount);
      await prefs.setInt('ack_renewals_$libraryId', renewalsCount);
    } catch (_) {}
  }

  /// Sync downward if actual counts reduced below acknowledged counts
  void syncCounts({required int currentPending, required int currentRenewals}) {
    var updated = false;
    var newPending = state.acknowledgedPendingCount;
    var newRenewals = state.acknowledgedRenewalsCount;

    if (currentPending < newPending) {
      newPending = currentPending;
      updated = true;
    }
    if (currentRenewals < newRenewals) {
      newRenewals = currentRenewals;
      updated = true;
    }

    if (updated) {
      state = SystemAlertsState(
        acknowledgedPendingCount: newPending,
        acknowledgedRenewalsCount: newRenewals,
      );
      _cache[libraryId] = state;
      if (libraryId.isNotEmpty) {
        SharedPreferences.getInstance().then((prefs) {
          prefs.setInt('ack_pending_$libraryId', newPending);
          prefs.setInt('ack_renewals_$libraryId', newRenewals);
        }).catchError((_) {});
      }
    }
  }
}

final systemAlertsProvider =
    StateNotifierProvider.family<SystemAlertsNotifier, SystemAlertsState, String>(
  (ref, libraryId) => SystemAlertsNotifier(libraryId),
);

