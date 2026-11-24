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
    // Clean string normalization: remove punctuation and emojis so minor variations match
    final cleanTitle = n.title.replaceAll(RegExp(r'[^\w\s]'), '').trim().toLowerCase();
    final cleanBody = n.body.replaceAll(RegExp(r'[^\w\s]'), '').trim().toLowerCase();
    final target = (n.targetUserId ?? '').trim().toLowerCase();
    final key = '${cleanTitle}_${cleanBody}_$target';

    if (!uniqueMap.containsKey(key)) {
      uniqueMap[key] = n;
    } else {
      final existing = uniqueMap[key]!;
      // Keep newer notification timestamp
      final keepNewer = n.createdAt.isAfter(existing.createdAt);
      // If either notification was marked read, honor read status
      final isRead = existing.read || n.read;

      final winner = keepNewer ? n : existing;
      final loser = keepNewer ? existing : n;

      uniqueMap[key] = winner.copyWith(read: isRead);
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

  AppNotificationService._ensureLocalPrefsLoaded(libraryId, 'admin');

  return FirebaseFirestore.instance
      .collection('libraries')
      .doc(libraryId)
      .collection('notifications')
      .orderBy('createdAt', descending: true)
      .limit(50)
      .snapshots()
      .map((snap) {
        final all = snap.docs.map((doc) => AppNotificationModel.fromFirestore(doc)).toList();
        final filtered = all.where((n) {
          if (AppNotificationService.isLocallyDismissed(n.id)) return false;
          return n.targetRole == 'admin' || n.targetRole == 'all';
        }).map((n) {
          if (AppNotificationService.isLocallyRead(n.id)) {
            return n.copyWith(read: true);
          }
          return n;
        }).toList();
        return _deduplicateNotifications(filtered, libraryId);
      });
});

/// Unread admin notifications count for badges
final unreadAdminNotificationsCountProvider = Provider<int>((ref) {
  final notifsAsync = ref.watch(adminNotificationsStreamProvider);
  final notifs = notifsAsync.value ?? [];
  return notifs.where((n) => !n.isRead).length;
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

  // Pre-load local prefs
  AppNotificationService._ensureLocalPrefsLoaded(libraryId, effectiveId);

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
          return all.where((n) {
            if (n.targetRole == 'admin') return false; // STRICT ROLE FENCE
            if (AppNotificationService.isLocallyDismissed(n.id)) return false;
            return n.targetRole == 'all' && (n.targetUserId == null || n.targetUserId!.isEmpty);
          }).map((n) {
            if (AppNotificationService.isLocallyRead(n.id)) {
              return n.copyWith(read: true);
            }
            return n;
          }).toList();
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
        // 1. Notifications explicitly addressed to THIS specific student (targetUserId, metadata.studentId, or metadata.studentUserId/userId)
        // 2. General public broadcasts intended for ALL users (type == 'announcement' with NO student-specific data)
        final filtered = all.where((n) {
          // 1. Strict Target Role Fence: A student MUST NEVER see notifications intended for admins!
          if (n.targetRole == 'admin') return false;

          // 2. Strict Local Dismissal Fence: If dismissed locally by this student, hide it!
          if (AppNotificationService.isLocallyDismissed(n.id)) return false;

          final metaStudentId = n.metadata['studentId']?.toString().trim();
          final metaUserId = (n.metadata['studentUserId'] ?? n.metadata['userId'])?.toString().trim();

          if (n.targetUserId != null && n.targetUserId!.trim().isNotEmpty) {
            final t = n.targetUserId!.trim();
            final matchesDirect = t == effectiveId ||
                (authUid != null && t == authUid) ||
                (studentId != null && t == studentId);
            if (matchesDirect) return true;

            // Cross-ID resolution: Notification was addressed by studentId or authUid
            if (studentId != null && metaStudentId != null && metaStudentId == studentId) return true;
            if (metaStudentId != null && metaStudentId == effectiveId) return true;
            if (authUid != null && metaUserId != null && metaUserId == authUid) return true;
            if (metaUserId != null && metaUserId == effectiveId) return true;

            return false;
          }

          // Check if metadata matches this student even if targetUserId was omitted
          if ((studentId != null && metaStudentId != null && metaStudentId == studentId) ||
              (authUid != null && metaUserId != null && metaUserId == authUid) ||
              ((metaStudentId != null && metaStudentId == effectiveId) ||
                  (metaUserId != null && metaUserId == effectiveId))) {
            return true;
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
            'due',
            'renewal',
            'profile_update_request',
          };
          if (personalTypes.contains(n.type.toLowerCase())) {
            return false; // Hard reject untargeted sensitive notifications
          }
          return n.targetRole == 'all' || n.targetRole == 'student' || n.type == 'announcement';
        }).map((n) {
          if (AppNotificationService.isLocallyRead(n.id)) {
            return n.copyWith(read: true);
          }
          return n;
        }).toList();
        return _deduplicateNotifications(filtered, libraryId);
      });
});

class AppNotificationService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static final Set<String> _locallyReadIds = {};
  static final Set<String> _locallyDismissedIds = {};
  static bool _localPrefsLoaded = false;

  static String _readKey(String libraryId, String? userId) =>
      'locally_read_notifs_${libraryId}_${userId ?? "all"}';
  static String _dismissKey(String libraryId, String? userId) =>
      'locally_dismissed_notifs_${libraryId}_${userId ?? "all"}';

  static Future<void> _ensureLocalPrefsLoaded(String libraryId, String? userId) async {
    if (_localPrefsLoaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final readList = prefs.getStringList(_readKey(libraryId, userId)) ?? [];
      final dismissedList = prefs.getStringList(_dismissKey(libraryId, userId)) ?? [];
      _locallyReadIds.addAll(readList);
      _locallyDismissedIds.addAll(dismissedList);
      _localPrefsLoaded = true;
    } catch (_) {}
  }

  static void _recordLocallyRead(String libraryId, String? userId, String id) {
    _locallyReadIds.add(id);
    SharedPreferences.getInstance().then((prefs) {
      final key = _readKey(libraryId, userId);
      final current = prefs.getStringList(key) ?? [];
      if (!current.contains(id)) {
        current.add(id);
        prefs.setStringList(key, current);
      }
    }).catchError((_) {});
  }

  static void _recordLocallyDismissed(String libraryId, String? userId, String id) {
    _locallyDismissedIds.add(id);
    _locallyReadIds.add(id); // Dismissed items are implicitly read
    SharedPreferences.getInstance().then((prefs) {
      final key = _dismissKey(libraryId, userId);
      final current = prefs.getStringList(key) ?? [];
      if (!current.contains(id)) {
        current.add(id);
        prefs.setStringList(key, current);
      }
    }).catchError((_) {});
  }

  @visibleForTesting
  static void recordLocallyRead(String libraryId, String? userId, String id) =>
      _recordLocallyRead(libraryId, userId, id);

  @visibleForTesting
  static void recordLocallyDismissed(String libraryId, String? userId, String id) =>
      _recordLocallyDismissed(libraryId, userId, id);

  @visibleForTesting
  static void clearLocalCachesForTest() {
    _locallyReadIds.clear();
    _locallyDismissedIds.clear();
    _localPrefsLoaded = false;
  }

  static bool isLocallyDismissed(String id) => _locallyDismissedIds.contains(id);
  static bool isLocallyRead(String id) => _locallyReadIds.contains(id);

  /// Exposes deduplication logic to UI and stream consumers
  static List<AppNotificationModel> deduplicate(List<AppNotificationModel> list, [String? libraryId]) =>
      _deduplicateNotifications(list, libraryId);

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
    String? notificationId,
  }) async {
    try {
      final cleanTitle = title.replaceAll(RegExp(r'[^\w\s]'), '').trim().toLowerCase();
      final cleanBody = body.replaceAll(RegExp(r'[^\w\s]'), '').trim().toLowerCase();

      // Deduplicate recent identical dispatches within 60 minutes to prevent double-writes
      if (libraryId.isNotEmpty && type != 'general') {
        try {
          final recentSnap = await _firestore
              .collection('libraries')
              .doc(libraryId)
              .collection('notifications')
              .orderBy('createdAt', descending: true)
              .limit(25)
              .get();

          final isDuplicate = recentSnap.docs.any((d) {
            final dData = d.data();
            final dTitle = (dData['title'] ?? '').toString().replaceAll(RegExp(r'[^\w\s]'), '').trim().toLowerCase();
            final dBody = (dData['body'] ?? '').toString().replaceAll(RegExp(r'[^\w\s]'), '').trim().toLowerCase();
            final dTarget = (dData['targetUserId'] ?? '').toString().trim();
            final dCreated = (dData['createdAt'] as Timestamp?)?.toDate();

            if (dTitle == cleanTitle && dBody == cleanBody) {
              if (targetUserId == null || targetUserId.isEmpty || dTarget == targetUserId || dTarget.isEmpty) {
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

      final docRef = (notificationId != null && notificationId.isNotEmpty)
          ? _firestore.collection('libraries').doc(libraryId).collection('notifications').doc(notificationId)
          : _firestore.collection('libraries').doc(libraryId).collection('notifications').doc();

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

      await docRef.set(model.toFirestore(), SetOptions(merge: true));

      // Trigger Android system notification with short message snippet
      final channelId = switch (type) {
        'payment' || 'expiry' => NotificationService.channelFeeAlerts,
        'announcement' => NotificationService.channelAnnouncements,
        'seat' => NotificationService.channelDeskAlerts,
        _ => NotificationService.channelGeneral,
      };

      // Strict Device-Role Fencing:
      // Only show local Android status-bar notification on this device if the notification
      // is actually intended for this device's current user/role.
      // E.g., when a student submits an admission request, the admin-targeted alert
      // ('targetRole == admin') must NEVER buzz or show on the student's phone!
      bool shouldShowLocally = true;
      try {
        final prefs = await SharedPreferences.getInstance();
        final currentRole = prefs.getString('cached_current_user_role') ??
            prefs.getString('persisted_role') ??
            'student';
        final currentUid = FirebaseAuth.instance.currentUser?.uid;

        if (targetRole == 'admin') {
          // If current device is NOT logged in as admin, NEVER show admin alert locally!
          if (currentRole != 'admin') {
            shouldShowLocally = false;
          }
        } else if (targetRole == 'student') {
          if (currentRole == 'admin') {
            // Admins don't need personal student alerts popping up
            shouldShowLocally = false;
          } else if (targetUserId != null && targetUserId.isNotEmpty && currentUid != null) {
            final cachedStudentId = prefs.getString('cached_student_id');
            if (targetUserId != currentUid && targetUserId != cachedStudentId) {
              shouldShowLocally = false;
            }
          }
        }
      } catch (_) {
        if (targetRole == 'admin') shouldShowLocally = false;
      }

      if (shouldShowLocally) {
        await NotificationService.showNotification(
          title: title,
          body: body,
          channelId: channelId,
          payload: actionRoute,
        );
      }

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
    String? targetUserId,
  }) async {
    _recordLocallyRead(libraryId, targetUserId, notificationId);
    try {
      await _firestore
          .collection('libraries')
          .doc(libraryId)
          .collection('notifications')
          .doc(notificationId)
          .update({'read': true, 'readAt': FieldValue.serverTimestamp()});
    } catch (e) {
      if (kDebugMode) debugPrint('Error marking notification as read: $e');
    }
  }

  /// Mark all notifications as read for current viewer
  static Future<void> markAllAsRead({
    required String libraryId,
    required String targetRole,
    String? targetUserId,
    List<String>? notificationIds,
  }) async {
    // 1. Immediately mark provided notification IDs as read locally
    if (notificationIds != null && notificationIds.isNotEmpty) {
      for (final id in notificationIds) {
        _recordLocallyRead(libraryId, targetUserId, id);
      }
    }

    // 2. Resilient Firestore update per document (avoids batch abort on permission checks)
    try {
      final snap = await _firestore
          .collection('libraries')
          .doc(libraryId)
          .collection('notifications')
          .where('read', isEqualTo: false)
          .get();

      final currentAuthUid = FirebaseAuth.instance.currentUser?.uid;

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

        _recordLocallyRead(libraryId, targetUserId, doc.id);
        doc.reference.update({'read': true, 'readAt': FieldValue.serverTimestamp()}).catchError((_) {});
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Error marking all notifications as read: $e');
    }
  }

  /// Delete notification or dismiss it permanently
  static Future<void> deleteNotification({
    required String libraryId,
    required String notificationId,
    String? targetUserId,
  }) async {
    _recordLocallyDismissed(libraryId, targetUserId, notificationId);
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
    List<String>? readNotificationIds,
  }) async {
    // 1. Immediately record read notification IDs as dismissed locally
    if (readNotificationIds != null && readNotificationIds.isNotEmpty) {
      for (final id in readNotificationIds) {
        _recordLocallyDismissed(libraryId, targetUserId, id);
      }
    }

    // 2. Resilient Firestore delete per document (avoids batch abort on permission checks)
    try {
      final snap = await _firestore
          .collection('libraries')
          .doc(libraryId)
          .collection('notifications')
          .where('read', isEqualTo: true)
          .get();

      final currentAuthUid = FirebaseAuth.instance.currentUser?.uid;

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

        _recordLocallyDismissed(libraryId, targetUserId, doc.id);
        doc.reference.delete().catchError((_) {});
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

