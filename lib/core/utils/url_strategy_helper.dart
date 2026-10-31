import 'package:flutter/foundation.dart';
import 'url_strategy_stub.dart'
    if (dart.library.js_interop) 'url_strategy_web.dart'
    if (dart.library.html) 'url_strategy_web.dart';

/// Configures clean, modern URLs across web and mobile without breaking mobile compilation.
void configureAppUrlStrategy() {
  if (kIsWeb) {
    setPathUrlStrategy();
  }
}
