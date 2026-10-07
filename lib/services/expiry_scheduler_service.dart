import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

/// Schedules local notifications to remind students before membership expiry.
/// Works OFFLINE — does not require FCM or internet connection.
class ExpirySchedulerService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  // Notification IDs — unique per notification type
  static const int _expiryIn3DaysId = 1001;
  static const int _expiryIn1DayId = 1002;
  static const int _expiryTodayId = 1003;

  static Future<void> initialize() async {
    if (_initialized) return;
    try {
      tz.initializeTimeZones();
      // Set to India timezone
      try {
        tz.setLocalLocation(tz.getLocation('Asia/Kolkata'));
      } catch (_) {
        // fallback to UTC
      }

      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      const settings = InitializationSettings(android: androidSettings);
      await _plugin.initialize(settings: settings);
      _initialized = true;
    } catch (e) {
      debugPrint('ExpiryScheduler init failed: $e');
    }
  }

  /// Schedule expiry reminders for a student.
  /// Call this on login and when plan is renewed.
  /// [expiryDate] is the planEndDate of the student.
  /// [studentName] is used in the notification message.
  /// [libraryName] is the library name shown in notification.
  static Future<void> scheduleExpiryReminders({
    required DateTime expiryDate,
    required String studentName,
    required String libraryName,
    int reminderDays = 3,
  }) async {
    if (!_initialized) await initialize();

    // Cancel previous reminders first
    await cancelExpiryReminders();

    final now = DateTime.now();

    // Don't schedule if already expired
    if (expiryDate.isBefore(now)) return;

    const androidDetails = AndroidNotificationDetails(
      'expiry_reminders',
      'Membership Reminders',
      channelDescription: 'Reminders about your library membership expiry',
      importance: Importance.high,
      priority: Priority.high,
      enableLights: true,
      enableVibration: true,
    );
    const details = NotificationDetails(android: androidDetails);

    // 3 days before
    final threeDaysBefore = expiryDate.subtract(const Duration(days: 3));
    if (threeDaysBefore.isAfter(now)) {
      try {
        await _plugin.zonedSchedule(
          id: _expiryIn3DaysId,
          title: '⏰ Membership Expires in 3 Days',
          body: 'Your $libraryName membership expires on ${_formatDate(expiryDate)}. Renew now to keep your seat!',
          scheduledDate: tz.TZDateTime.from(threeDaysBefore, tz.local),
          notificationDetails: details,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        );
      } catch (e) {
        debugPrint('Schedule 3-day reminder failed: $e');
      }
    }

    // 1 day before
    final oneDayBefore = expiryDate.subtract(const Duration(days: 1));
    if (oneDayBefore.isAfter(now)) {
      try {
        await _plugin.zonedSchedule(
          id: _expiryIn1DayId,
          title: '🚨 Membership Expires Tomorrow!',
          body: 'Your $libraryName membership expires tomorrow. Renew today to avoid losing your seat.',
          scheduledDate: tz.TZDateTime.from(oneDayBefore, tz.local),
          notificationDetails: details,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        );
      } catch (e) {
        debugPrint('Schedule 1-day reminder failed: $e');
      }
    }

    // On expiry day at 9 AM
    final expiryDayNotif = DateTime(expiryDate.year, expiryDate.month, expiryDate.day, 9, 0);
    if (expiryDayNotif.isAfter(now)) {
      try {
        await _plugin.zonedSchedule(
          id: _expiryTodayId,
          title: '❌ Membership Expired Today',
          body: 'Your $libraryName membership has expired. Visit the library to renew and keep your seat.',
          scheduledDate: tz.TZDateTime.from(expiryDayNotif, tz.local),
          notificationDetails: details,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        );
      } catch (e) {
        debugPrint('Schedule expiry-day reminder failed: $e');
      }
    }

    debugPrint('Expiry reminders scheduled for ${_formatDate(expiryDate)}');
  }

  /// Cancel all scheduled expiry reminders (call on logout or plan change).
  static Future<void> cancelExpiryReminders() async {
    if (!_initialized) return;
    try {
      await _plugin.cancel(id: _expiryIn3DaysId);
      await _plugin.cancel(id: _expiryIn1DayId);
      await _plugin.cancel(id: _expiryTodayId);
    } catch (e) {
      debugPrint('Cancel reminders failed: $e');
    }
  }

  static String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}
