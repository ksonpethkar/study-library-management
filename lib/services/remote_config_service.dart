import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// All controllable feature flags — change from Firebase Console,
/// takes effect on next app launch (no APK update needed).
class RemoteConfigService {
  static final _rc = FirebaseRemoteConfig.instance;

  static Future<void> initialize() async {
    try {
      await _rc.setConfigSettings(RemoteConfigSettings(
        fetchTimeout: const Duration(seconds: 10),
        minimumFetchInterval: kDebugMode ? Duration.zero : const Duration(hours: 1), // in prod; 0 for debug
      ));

      // Default values — used if fetch fails or first launch
      await _rc.setDefaults({
        'grace_period_days': 7,
        'max_seats_per_section': 100,
        'renewal_reminder_days': 3,
        'enable_revenue_dashboard': true,
        'enable_bulk_import': true,
        'enable_qr_scan': true,
        'enable_waiting_list': true,
        'enable_data_export': true,
        'enable_recycle_bin': true,
        'min_plan_price': 0,
        'max_plan_duration_days': 365,
        'announcement_max_length': 500,
        'app_notice_banner': '',       // shows a yellow banner at top if non-empty
        'maintenance_mode': false,     // shows maintenance screen if true
        'force_update_version': '',    // e.g. '1.5.0' — force update if below
      });

      await _rc.fetchAndActivate();
    } catch (e) {
      debugPrint('RemoteConfig init failed: $e');
      // App works fine with defaults
    }
  }

  // ─── Getters ────────────────────────────────────────────
  static int get gracePeriodDays => _rc.getInt('grace_period_days');
  static int get maxSeatsPerSection => _rc.getInt('max_seats_per_section');
  static int get renewalReminderDays => _rc.getInt('renewal_reminder_days');
  static bool get enableRevenueDashboard => _rc.getBool('enable_revenue_dashboard');
  static bool get enableBulkImport => _rc.getBool('enable_bulk_import');
  static bool get enableQrScan => _rc.getBool('enable_qr_scan');
  static bool get enableWaitingList => _rc.getBool('enable_waiting_list');
  static bool get enableDataExport => _rc.getBool('enable_data_export');
  static bool get enableRecycleBin => _rc.getBool('enable_recycle_bin');
  static int get minPlanPrice => _rc.getInt('min_plan_price');
  static int get maxPlanDurationDays => _rc.getInt('max_plan_duration_days');
  static int get announcementMaxLength => _rc.getInt('announcement_max_length');
  static String get appNoticeBanner => _rc.getString('app_notice_banner');
  static bool get maintenanceMode => _rc.getBool('maintenance_mode');
  static String get forceUpdateVersion => _rc.getString('force_update_version');
}

final remoteConfigProvider = Provider<RemoteConfigService>((_) => RemoteConfigService());
