import 'package:flutter/foundation.dart';
import 'web_screenshot_guard_stub.dart'
    if (dart.library.js_interop) 'web_screenshot_guard_web.dart';

void setWebScreenshotProtection(bool enabled) {
  if (!kIsWeb) return;
  WebScreenshotGuardPlatform.setEnabled(enabled);
}
