import 'dart:js_interop';
import 'package:web/web.dart' as web;

void reloadWebPage() {
  // 1. Unregister all service workers so stale WASM/JS cache is evicted
  try {
    web.window.navigator.serviceWorker.getRegistrations().toDart.then((registrations) {
      for (final reg in registrations.toDart) {
        reg.unregister();
      }
    }).catchError((_) {});
  } catch (_) {}

  // 2. Clear browser CacheStorage if accessible
  try {
    web.window.caches.keys().toDart.then((keys) {
      for (final key in keys.toDart) {
        web.window.caches.delete(key.toDart);
      }
    }).catchError((_) {});
  } catch (_) {}

  // 3. Force hard reload with cache-busting timestamp
  try {
    final currentUri = Uri.parse(web.window.location.href);
    final queryParams = Map<String, String>.from(currentUri.queryParameters);
    queryParams['reload_ts'] = DateTime.now().millisecondsSinceEpoch.toString();
    final bustedUrl = currentUri.replace(queryParameters: queryParams).toString();
    web.window.location.replace(bustedUrl);
  } catch (_) {
    web.window.location.reload();
  }
}

