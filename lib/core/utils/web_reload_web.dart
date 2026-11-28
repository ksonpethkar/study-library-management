import 'dart:async';
import 'dart:js_interop';
import 'package:web/web.dart' as web;

Future<void> reloadWebPage() async {
  // 1 & 2. Await service worker unregistration and CacheStorage eviction BEFORE navigating
  // so the old Service Worker cannot intercept the reload and serve a stale JS bundle.
  try {
    await Future.wait([
      () async {
        try {
          final registrations = await web.window.navigator.serviceWorker.getRegistrations().toDart;
          await Future.wait(registrations.toDart.map((reg) => reg.unregister().toDart));
        } catch (_) {}
      }(),
      () async {
        try {
          final keys = await web.window.caches.keys().toDart;
          await Future.wait(keys.toDart.map((key) => web.window.caches.delete(key.toDart).toDart));
        } catch (_) {}
      }(),
    ]).timeout(const Duration(seconds: 2));
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

