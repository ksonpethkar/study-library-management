import 'dart:js_interop';

@JS('updateWebBranding')
external void _updateWebBranding(JSString url, JSString title);

@JS('updateWebFavicon')
external void _updateWebFavicon(JSString url);

class WebFaviconPlatform {
  static void updateBranding({String? logoUrl, String? title}) {
    try {
      _updateWebBranding((logoUrl ?? '').toJS, (title ?? '').toJS);
    } catch (_) {
      if (logoUrl != null && logoUrl.trim().isNotEmpty) {
        try {
          _updateWebFavicon(logoUrl.toJS);
        } catch (_) { /* intentionally silent */ }
      }
    }
  }
}
