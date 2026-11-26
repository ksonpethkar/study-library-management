import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ExpiryNotificationService {
  static final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  static Future<void> initialize() async {
    if (kIsWeb || _initialized) return;

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _plugin.initialize(
      settings: const InitializationSettings(android: androidSettings),
    );
    _initialized = true;
  }

  /// Check for plans expiring within the configured reminder window and show notifications (Admin only, throttled to once per 12h)
  static Future<void> checkExpiringPlans(String libraryId, {int? customReminderDays}) async {
    if (kIsWeb || libraryId.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final role = prefs.getString('cached_current_user_role') ?? prefs.getString('persisted_role');
      if (role != 'admin') return; // Never blast admin bulk expiry alerts on student devices

      final throttleKey = 'last_admin_expiry_notif_check_$libraryId';
      final lastCheckMs = prefs.getInt(throttleKey) ?? 0;
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      if (nowMs - lastCheckMs < const Duration(hours: 12).inMilliseconds) return;
      await prefs.setInt(throttleKey, nowMs);
    } catch (_) {
      return;
    }

    await initialize();

    final now = DateTime.now();
    int reminderDays = customReminderDays ?? 3;

    try {
      final libRef = FirebaseFirestore.instance.collection('libraries').doc(libraryId);
      final commDoc = await libRef.collection('settings').doc('communications').get();
      if (commDoc.exists && commDoc.data() != null) {
        final d = commDoc.data()!;
        if (d['reminderDays'] is num) {
          reminderDays = (d['reminderDays'] as num).toInt();
        }
      } else {
        final graceDoc = await libRef.collection('settings').doc('grace_period').get();
        if (graceDoc.exists && graceDoc.data() != null) {
          final d = graceDoc.data()!;
          if (d['defaultDays'] is num) {
            reminderDays = (d['defaultDays'] as num).toInt();
          }
        }
      }
    } catch (_) {
      // Fallback safely to reminderDays default
    }

    if (reminderDays < 1) reminderDays = 1;
    final windowLimit = now.add(Duration(days: reminderDays));

    try {
      final snap = await FirebaseFirestore.instance
          .collection('libraries')
          .doc(libraryId)
          .collection('students')
          .where('membershipStatus', isEqualTo: 'active')
          .get();

      int notifId = 100;

      for (final doc in snap.docs) {
        final data = doc.data();
        final name = data['name'] ?? 'Student';
        final endDateRaw = data['planEndDate'];
        final status = data['membershipStatus'] ?? '';

        if (status != 'active') continue;

        DateTime? endDate;
        if (endDateRaw is String) endDate = DateTime.tryParse(endDateRaw);
        if (endDateRaw is int) endDate = DateTime.fromMillisecondsSinceEpoch(endDateRaw);
        if (endDateRaw is Timestamp) {
          endDate = endDateRaw.toDate();
        } else if (endDateRaw != null) {
          try { endDate = (endDateRaw as dynamic).toDate(); } catch (_) { /* intentionally silent */ }
        }

        if (endDate == null) continue;

        if (endDate.isAfter(now.subtract(const Duration(days: 1))) && endDate.isBefore(windowLimit)) {
          final daysLeft = endDate.difference(now).inDays;
          String message;

          if (daysLeft <= 0) {
            message = '$name\'s plan expires today!';
          } else if (daysLeft == 1) {
            message = '$name\'s plan expires tomorrow';
          } else {
            message = '$name\'s plan expires in $daysLeft days';
          }

          await _showNotification(
            id: notifId++,
            title: 'Plan Expiring',
            body: message,
          );
        }
      }
    } catch (_) { /* intentionally silent */ }
  }

  /// Single student self-check that evaluates plan validity and notifies student directly
  /// without requiring an admin to open the dashboard (Student device only, throttled once per day).
  static Future<void> checkStudentSelfExpiry({
    required String studentName,
    required DateTime? planEndDate,
    required String seatLabel,
    int reminderDays = 3,
  }) async {
    if (kIsWeb || planEndDate == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final role = prefs.getString('cached_current_user_role') ?? prefs.getString('persisted_role');
      if (role == 'admin') return; // Never trigger student self-expiry alerts on an admin device
      final now = DateTime.now();
      final dayKey = '${now.year}-${now.month}-${now.day}';
      if (prefs.getString('last_student_self_expiry_notif_day') == dayKey) return;
      await prefs.setString('last_student_self_expiry_notif_day', dayKey);
    } catch (_) {
      return;
    }
    await initialize();

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final end = DateTime(planEndDate.year, planEndDate.month, planEndDate.day);
    final daysLeft = end.difference(today).inDays;

    final seatText = seatLabel.isNotEmpty ? 'desk ($seatLabel)' : 'desk pass';

    if (daysLeft < 0) {
      await _showNotification(
        id: 99,
        title: '⚠️ Study Pass Expired',
        body: 'Your $seatText has expired. Tap to renew now.',
      );
    } else if (daysLeft == 0) {
      await _showNotification(
        id: 99,
        title: '⚠️ Membership Expires Today',
        body: 'Today is your last day for $seatText. Renew today to retain your seat!',
      );
    } else if (daysLeft <= reminderDays) {
      await _showNotification(
        id: 99,
        title: '📅 Renewal Reminder',
        body: 'Your study pass for $seatText expires in $daysLeft ${daysLeft == 1 ? 'day' : 'days'}.',
      );
    }
  }

  static Future<void> _showNotification({
    required int id,
    required String title,
    required String body,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'plan_expiry',
      'Plan Expiry Alerts',
      channelDescription: 'Notifications for expiring student plans',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    const details = NotificationDetails(android: androidDetails);
    await _plugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: details,
    );
  }

  static Future<void> showTestNotification() async {
    await initialize();
    await _showNotification(
      id: 0,
      title: 'Library Alert',
      body: 'Notifications are working!',
    );
  }
}
