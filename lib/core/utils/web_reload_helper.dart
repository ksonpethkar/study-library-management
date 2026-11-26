import 'package:flutter/foundation.dart';
import 'web_reload_stub.dart' if (dart.library.js_interop) 'web_reload_web.dart';

void reloadAppWeb() {
  if (kIsWeb) {
    reloadWebPage();
  }
}
