// ignore: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;

void reloadWebPage() {
  // 1. Unregister all service workers so stale WASM/JS cache is evicted
  try {
    if (html.window.navigator.serviceWorker != null) {
      html.window.navigator.serviceWorker!.getRegistrations().then((registrations) {
        for (final reg in registrations) {
          reg.unregister();
        }
      }).catchError((_) {});
    }
  } catch (_) {}

  // 2. Clear browser CacheStorage if accessible
  try {
    if (html.window.caches != null) {
      html.window.caches!.keys().then((keys) {
        for (final key in keys) {
          html.window.caches!.delete(key);
        }
      }).catchError((_) {});
    }
  } catch (_) {}

  // 3. Force hard reload with cache-busting timestamp
  try {
    final currentUri = Uri.parse(html.window.location.href);
    final queryParams = Map<String, String>.from(currentUri.queryParameters);
    queryParams['reload_ts'] = DateTime.now().millisecondsSinceEpoch.toString();
    final bustedUrl = currentUri.replace(queryParameters: queryParams).toString();
    html.window.location.replace(bustedUrl);
  } catch (_) {
    html.window.location.reload();
  }
}

