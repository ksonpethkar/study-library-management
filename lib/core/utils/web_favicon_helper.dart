import 'package:flutter/foundation.dart';
import 'web_favicon_stub.dart'
    if (dart.library.html) 'web_favicon_web.dart';

void setWebTabBranding({String? logoUrl, String? title}) {
  if (!kIsWeb) return;
  WebFaviconPlatform.updateBranding(logoUrl: logoUrl, title: title);
}
