import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:study_library/core/router/app_router.dart';

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
      await _plugin.initialize(
        settings: settings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          final payload = response.payload;
          if (payload != null && payload.isNotEmpty) {
            navigateViaRoot(payload);
          }
        },
      );
      _initialized = true;
    } catch (e) {
      if (kDebugMode) debugPrint('ExpiryScheduler init failed: $e');
    }
  }

  /// Schedule expiry reminders for a student.
  /// Call this on login and when plan is renewed.
  /// [expiryDate] is the planEndDate of the student.
  /// [studentName] is used in the notification message.
  /// [libraryName] is the library name shown in notification.
  /// Schedule expiry reminders for a student using configurable [reminderOffsets] (in days).
  static Future<void> scheduleExpiryReminders({
    required DateTime expiryDate,
    required String studentName,
    required String libraryName,
    int reminderDays = 3,
    List<int> reminderOffsets = const [3, 1, 0],
    int preferredHour = 9,
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

    final offsets = (reminderOffsets.isNotEmpty ? reminderOffsets : [reminderDays, 1, 0])
        .where((d) => d >= 0)
        .toSet()
        .toList();

    for (final offset in offsets) {
      final targetDate = offset == 0
          ? DateTime(expiryDate.year, expiryDate.month, expiryDate.day, preferredHour, 0)
          : expiryDate.subtract(Duration(days: offset));
      if (!targetDate.isAfter(now)) continue;

      final notifId = offset == 3
          ? _expiryIn3DaysId
          : offset == 1
              ? _expiryIn1DayId
              : offset == 0
                  ? _expiryTodayId
                  : 1000 + offset;

      final title = offset == 0
          ? '❌ Membership Expired Today'
          : offset == 1
              ? '🚨 Membership Expires Tomorrow!'
              : '⏰ Membership Expires in $offset Days';

      final body = offset == 0
          ? 'Your $libraryName membership has expired. Visit the library to renew and keep your seat.'
          : offset == 1
              ? 'Your $libraryName membership expires tomorrow. Renew today to avoid losing your seat.'
              : 'Your $libraryName membership expires on ${_formatDate(expiryDate)}. Renew now to keep your seat!';

      try {
        await _plugin.zonedSchedule(
          id: notifId,
          title: title,
          body: body,
          scheduledDate: tz.TZDateTime.from(targetDate, tz.local),
          notificationDetails: details,
          payload: Routes.studentRenew,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        );
      } catch (e) {
        if (kDebugMode) debugPrint('Schedule $offset-day reminder failed: $e');
      }
    }

    if (kDebugMode) debugPrint('Expiry reminders scheduled for ${_formatDate(expiryDate)} ($offsets)');
  }

  /// Cancel all scheduled expiry reminders (call on logout or plan change).
  static Future<void> cancelExpiryReminders() async {
    if (!_initialized) return;
    try {
      await _plugin.cancel(id: _expiryIn3DaysId);
      await _plugin.cancel(id: _expiryIn1DayId);
      await _plugin.cancel(id: _expiryTodayId);
      for (final d in const [5, 7, 10, 14, 30]) {
        await _plugin.cancel(id: 1000 + d);
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Cancel reminders failed: $e');
    }
  }

  static String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}
