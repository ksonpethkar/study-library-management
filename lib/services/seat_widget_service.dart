import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service to keep the Android Home Screen AppWidget in sync with live seat occupancy
class SeatWidgetService {
  static const _channel = MethodChannel('study_library/app_widget');

  /// Updates the Android Home Screen AppWidget with current seat counts
  static Future<void> updateSeatCounts({
    required int occupied,
    required int total,
    String libraryName = 'Study Library',
  }) async {
    try {
      // 1. Save to SharedPreferences so widget can read upon system reboot or periodic alarm
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('widget_occupied_seats', occupied);
      await prefs.setInt('widget_total_seats', total);
      await prefs.setString('widget_library_name', libraryName);

      // 2. If running on native Android, trigger instant RemoteViews refresh
      if (!kIsWeb && Platform.isAndroid) {
        await _channel.invokeMethod('updateSeatWidget', {
          'occupied': occupied,
          'total': total,
          'libraryName': libraryName,
        });
      }
    } catch (e) {
      if (kDebugMode) debugPrint('SeatWidget update error: $e');
    }
  }
}
