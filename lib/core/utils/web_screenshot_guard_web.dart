import 'dart:js_interop';

@JS('setWebScreenshotProtection')
external void _setWebScreenshotProtection(JSBoolean enabled);

class WebScreenshotGuardPlatform {
  static void setEnabled(bool enabled) {
    try {
      _setWebScreenshotProtection(enabled.toJS);
    } catch (_) { /* intentionally silent */ }
  }
}
