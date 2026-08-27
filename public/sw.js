/**
 * Study Library Management System — Service Worker (PWA) v4
 * Phase 4: Updated cache, offline fallback page, stale-while-revalidate
 */

const CACHE_NAME = 'studylib-pwa-v41';

// All static assets to pre-cache on install
const STATIC_ASSETS = [
  '/',
  '/index.html',
  '/offline.html',
  '/student-login',
  '/student-login.html',
  '/register',
  '/register.html',
  '/landing',
  '/landing.html',
  '/kiosk',
  '/kiosk.html',
  '/manifest.json',
  '/manifest-student.json',
  '/manifest-admin.json',
  '/css/variables.css',
  '/css/base.css',
  '/css/layout.css',
  '/css/responsive.css',
  '/css/components.css',
  '/css/print.css',
  // Core JS
  '/js/app.js',
  '/js/auth.js',
  '/js/ui.js',
  '/js/api.js',
  '/js/router.js',
  '/js/search.js',
  '/js/shortcuts.js',
  '/js/i18n.js',
  '/js/themeManager.js',
  '/js/pwaManager.js',
  '/js/dragDrop.js',
  '/js/utils/attendanceHeatmap.js',
  '/js/utils/imageCompressor.js',
  '/js/utils/audioFeedback.js',
  '/js/utils/pushNotifications.js',
  '/js/pdfGenerator.js',
  '/js/signatureStudio.js',
  '/js/mediaStudio.js'
];

// ── Install — pre-cache all static assets ─────────────────────────────────
self.addEventListener('install', (event) => {
  self.skipWaiting();
  event.waitUntil(
    caches.open(CACHE_NAME).then((cache) => {
      return Promise.allSettled(
        STATIC_ASSETS.map(url =>
          cache.add(url).catch(err => {
            console.warn(`SW: failed to cache ${url}:`, err.message);
          })
        )
      );
    })
  );
});

// ── Activate — clean up old cache versions ─────────────────────────────────
self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches.keys().then((cacheNames) =>
      Promise.all(
        cacheNames
          .filter(name => name !== CACHE_NAME)
          .map(name => caches.delete(name))
      )
    ).then(() => self.clients.claim())
  );
});

// ── Fetch — Network-First for code (JS/CSS/HTML) + Stale-While-Revalidate for images ──
self.addEventListener('fetch', (event) => {
  const req = event.request;
  const url = new URL(req.url);

  // Bypass: non-GET, API endpoints, chrome-extension, external domains
  if (
    req.method !== 'GET' ||
    url.pathname.startsWith('/api/') ||
    url.pathname.startsWith('/uploads/') ||
    !url.origin.startsWith(self.location.origin.slice(0, -1))
  ) {
    return;
  }

  // Network-First for JS, CSS, and HTML files so deployments apply instantly
  if (
    url.pathname.endsWith('.js') ||
    url.pathname.endsWith('.css') ||
    url.pathname.endsWith('.html') ||
    url.pathname === '/' ||
    url.pathname === '/register' ||
    url.pathname === '/landing' ||
    url.pathname === '/student-login' ||
    url.pathname === '/portal-login' ||
    url.pathname === '/kiosk'
  ) {
    event.respondWith(
      fetch(req)
        .then((networkResponse) => {
          if (networkResponse && networkResponse.status === 200) {
            const copy = networkResponse.clone();
            caches.open(CACHE_NAME).then((cache) => cache.put(req, copy));
          }
          return networkResponse;
        })
        .catch(async () => {
          const cached = await caches.match(req);
          if (cached) return cached;
          if (req.headers.get('accept')?.includes('text/html')) {
            return (await caches.match('/index.html')) || (await caches.match('/offline.html'));
          }
          return new Response('', { status: 503 });
        })
    );
    return;
  }

  // Stale-While-Revalidate for other static assets (icons, fonts, images)
  event.respondWith(
    caches.open(CACHE_NAME).then(async (cache) => {
      const cachedResponse = await cache.match(req);
      const fetchPromise = fetch(req)
        .then((networkResponse) => {
          if (networkResponse && networkResponse.status === 200 && networkResponse.type !== 'opaque') {
            cache.put(req, networkResponse.clone());
          }
          return networkResponse;
        })
        .catch(async () => {
          return cachedResponse || new Response('', { status: 503 });
        });

      return cachedResponse || fetchPromise;
    })
  );
});

// ── Push Notifications ────────────────────────────────────────────────────
self.addEventListener('push', (event) => {
  let data = { title: 'The Cozy Corner Centre', body: 'You have a new notification.' };
  if (event.data) {
    try { data = { ...data, ...event.data.json() }; } catch {
      data.body = event.data.text();
    }
  }

  event.waitUntil(
    self.registration.showNotification(data.title || 'The Cozy Corner Centre', {
      body: data.body || 'You have a new update.',
      icon: data.icon || '/manifest.json',
      badge: data.badge || '/manifest.json',
      data: { url: data.url || '/' },
      vibrate: [100, 50, 100],
      actions: data.actions || []
    })
  );
});

// ── Notification Click ─────────────────────────────────────────────────────
self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  const targetUrl = event.notification?.data?.url || '/';

  event.waitUntil(
    clients.matchAll({ type: 'window', includeUncontrolled: true }).then((clientList) => {
      for (const client of clientList) {
        if ((client.url.includes(targetUrl) || targetUrl === '/') && 'focus' in client) {
          return client.focus().then(() => {
            if ('navigate' in client && targetUrl !== '/') client.navigate(targetUrl);
          });
        }
      }
      if (clients.openWindow) return clients.openWindow(targetUrl);
    })
  );
});

// ── Background Sync (stub for future use) ─────────────────────────────────
self.addEventListener('sync', (event) => {
  if (event.tag === 'sl-sync-attendance') {
    event.waitUntil(
      // Future: flush queued offline attendance punches when online
      Promise.resolve()
    );
  }
});
