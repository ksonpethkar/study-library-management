/// App icon badge count service.
/// flutter_app_badger was discontinued; on Android 8+ the OS manages
/// badge count automatically via the notification channel — no library needed.
/// All call sites are preserved; methods are safe no-ops.
class BadgeService {
  static Future<void> initialize() async {}

  /// No-op: Android 8+ handles badge count via notification channels natively.
  static Future<void> updateBadge(int count) async {}

  static Future<void> clearBadge() async {}
}
