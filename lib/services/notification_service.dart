import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:study_library/core/utils/permission_utils.dart';

/// Top-level background message handler (must be top-level function)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (kDebugMode) debugPrint('FCM background message: ${message.messageId}');
}

class NotificationService {
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  // Channels
  static const String channelFeeAlerts = 'fee_alerts';
  static const String channelAnnouncements = 'announcements';
  static const String channelAttendance = 'attendance_shifts';
  static const String channelGeneral = 'study_library_channel';

  /// Call once from main.dart after Firebase.initializeApp()
  static Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    // Register background handler
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Request permission (Android 13+ and iOS)
    final messaging = FirebaseMessaging.instance;
    await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // Init local notifications with monochrome silhouette icon (Android 12+ compliant)
    const androidSettings = AndroidInitializationSettings('@drawable/ic_stat_notification');
    const iosSettings = DarwinInitializationSettings();
    const settings = InitializationSettings(android: androidSettings, iOS: iosSettings);
    await _localNotifications.initialize(settings: settings);

    // Create Notification Channels for Android 8.0+
    if (!kIsWeb && Platform.isAndroid) {
      final androidImplementation = _localNotifications.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

      if (androidImplementation != null) {
        // Channel 1: Critical Fee & Expiry Alerts
        await androidImplementation.createNotificationChannel(
          const AndroidNotificationChannel(
            channelFeeAlerts,
            'Fee Due & Expiry Alerts',
            description: 'Critical reminders for membership validity, seat expiry, and renewals',
            importance: Importance.max,
            enableVibration: true,
            playSound: true,
            showBadge: true,
          ),
        );

        // Channel 2: Announcements
        await androidImplementation.createNotificationChannel(
          const AndroidNotificationChannel(
            channelAnnouncements,
            'Library Announcements',
            description: 'Notices, holiday alerts, and library rules updates',
            importance: Importance.defaultImportance,
            enableVibration: false,
            showBadge: true,
          ),
        );

        // Channel 3: Attendance & Shifts
        await androidImplementation.createNotificationChannel(
          const AndroidNotificationChannel(
            channelAttendance,
            'Attendance & Shift Timings',
            description: 'Check-in confirmations, shift start/end reminders',
            importance: Importance.high,
            enableVibration: true,
            showBadge: true,
          ),
        );

        // Channel 4: General / Fallback
        await androidImplementation.createNotificationChannel(
          const AndroidNotificationChannel(
            channelGeneral,
            'General Notifications',
            description: 'General system and desk notices',
            importance: Importance.high,
            showBadge: true,
          ),
        );
      }
    }

    // Show notification when app is in foreground
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      final notification = message.notification;
      if (notification != null) {
        final channelId = message.data['channel_id'] ?? channelFeeAlerts;
        _showLocalNotification(
          title: notification.title ?? 'Library Notice',
          body: notification.body ?? '',
          payload: message.data.toString(),
          channelId: channelId,
        );
      }
    });
  }

  static Future<void> _showLocalNotification({
    required String title,
    required String body,
    String? payload,
    String channelId = channelFeeAlerts,
    int? badgeNumber,
  }) async {
    await showNotification(
      title: title,
      body: body,
      payload: payload,
      channelId: channelId,
      badgeNumber: badgeNumber,
    );
  }

  /// Public API to dispatch rich notifications to Android status bar with short message & app icon badge
  static Future<void> showNotification({
    required String title,
    required String body,
    String? payload,
    String channelId = channelFeeAlerts,
    int? badgeNumber,
  }) async {
    // BigTextStyleInformation ensures the short message is rendered clearly without truncation in the Android notification shade
    final bigTextStyle = BigTextStyleInformation(
      body,
      contentTitle: title,
      summaryText: 'Study Library',
    );

    final androidDetails = AndroidNotificationDetails(
      channelId,
      channelId == channelFeeAlerts
          ? 'Fee Due & Expiry Alerts'
          : (channelId == channelAnnouncements ? 'Library Announcements' : 'Library Alerts'),
      channelDescription: 'Library membership, fee receipts and seat notifications',
      importance: Importance.max,
      priority: Priority.high,
      icon: '@drawable/ic_stat_notification',
      showWhen: true,
      styleInformation: bigTextStyle,
      number: badgeNumber,
    );
    const iosDetails = DarwinNotificationDetails();
    final details = NotificationDetails(android: androidDetails, iOS: iosDetails);

    await _localNotifications.show(
      id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
      title: title,
      body: body,
      notificationDetails: details,
      payload: payload,
    );
  }

  /// Get the FCM registration token for this device.
  /// firebase_messaging v17: uses register() + onRegistered stream.
  /// Store the returned token in Firestore for targeted push notifications.
  static Future<String?> getToken() async {
    try {
      if (!kIsWeb && Platform.isIOS) {
        await FirebaseMessaging.instance.getAPNSToken();
      }
      // Register and wait for the token via the onRegistered stream
      final completer = Completer<String?>();
      final sub = FirebaseMessaging.instance.onRegistered.listen(
        (token) { if (!completer.isCompleted) completer.complete(token); },
        onError: (e) { if (!completer.isCompleted) completer.complete(null); },
      );
      await FirebaseMessaging.instance.register();
      final token = await completer.future.timeout(
        const Duration(seconds: 10),
        onTimeout: () => null,
      );
      await sub.cancel();
      return token;
    } catch (e) {
      if (kDebugMode) debugPrint('FCM token error: $e');
      return null;
    }
  }

  /// Subscribe device to a topic (e.g. library-specific alerts)
  Future<void> subscribeToTopic(String topic) async {
    if (kIsWeb || topic.isEmpty) return;
    try {
      final safeTopic = topic.replaceAll(RegExp(r'[^a-zA-Z0-9-_.~%]'), '_');
      await FirebaseMessaging.instance.subscribeToTopic(safeTopic);
    } catch (e) {
      if (kDebugMode) debugPrint('FCM subscribe error: $e');
    }
  }

  /// Unsubscribe from a topic
  Future<void> unsubscribeFromTopic(String topic) async {
    if (kIsWeb || topic.isEmpty) return;
    try {
      final safeTopic = topic.replaceAll(RegExp(r'[^a-zA-Z0-9-_.~%]'), '_');
      await FirebaseMessaging.instance.unsubscribeFromTopic(safeTopic);
    } catch (e) {
      if (kDebugMode) debugPrint('FCM unsubscribe error: $e');
    }
  }

  /// Subscribes device to library topics based on user role:
  /// - `lib-$libraryId` (all library members for announcements)
  /// - `admin-$libraryId` (staff / admin desk notices)
  /// - `student-$libraryId` (student-targeted announcements)
  static Future<void> subscribeToLibraryTopics({
    required String libraryId,
    required bool isAdmin,
  }) async {
    if (kIsWeb || libraryId.isEmpty) return;
    try {
      final safeLibId = libraryId.replaceAll(RegExp(r'[^a-zA-Z0-9-_.~%]'), '_');
      final messaging = FirebaseMessaging.instance;
      await messaging.subscribeToTopic('lib-$safeLibId');
      if (isAdmin) {
        await messaging.subscribeToTopic('admin-$safeLibId');
        await messaging.unsubscribeFromTopic('student-$safeLibId');
      } else {
        await messaging.subscribeToTopic('student-$safeLibId');
        await messaging.unsubscribeFromTopic('admin-$safeLibId');
      }
    } catch (e) {
      if (kDebugMode) debugPrint('FCM subscribeToLibraryTopics error: $e');
    }
  }

  /// Unsubscribes from all library topics on user logout
  static Future<void> unsubscribeFromLibraryTopics({
    required String libraryId,
  }) async {
    if (kIsWeb || libraryId.isEmpty) return;
    try {
      final safeLibId = libraryId.replaceAll(RegExp(r'[^a-zA-Z0-9-_.~%]'), '_');
      final messaging = FirebaseMessaging.instance;
      await messaging.unsubscribeFromTopic('lib-$safeLibId');
      await messaging.unsubscribeFromTopic('admin-$safeLibId');
      await messaging.unsubscribeFromTopic('student-$safeLibId');
    } catch (e) {
      if (kDebugMode) debugPrint('FCM unsubscribeFromLibraryTopics error: $e');
    }
  }
}

final notificationServiceProvider = Provider((ref) => NotificationService());
