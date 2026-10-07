import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class ExpiryNotificationService {
  static final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  static Future<void> initialize() async {
    if (_initialized) return;

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _plugin.initialize(
      settings: const InitializationSettings(android: androidSettings),
    );
    _initialized = true;
  }

  /// Check for plans expiring within the next 3 days and show notifications
  static Future<void> checkExpiringPlans(String libraryId) async {
    await initialize();

    final now = DateTime.now();
    final threeDaysLater = now.add(const Duration(days: 3));

    try {
      final snap = await FirebaseFirestore.instance
          .collection('libraries')
          .doc(libraryId)
          .collection('students')
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
        if (endDateRaw != null && endDateRaw.runtimeType.toString() == 'Timestamp') {
          try { endDate = endDateRaw.toDate(); } catch (_) {}
        }

        if (endDate == null) continue;

        if (endDate.isAfter(now.subtract(const Duration(days: 1))) && endDate.isBefore(threeDaysLater)) {
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
    } catch (_) {}
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
      title: 'Cozy Corner',
      body: 'Notifications are working!',
    );
  }
}
