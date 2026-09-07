/**
 * Study Library Management System — Service Worker (PWA) v4
 * Phase 4: Updated cache, offline fallback page, stale-while-revalidate
 */
const CACHE_NAME = 'studylib-pwa-v65';

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
  '/css/mobile-nav.css',
  '/css/mobile-cards.css',
  '/css/mobile-settings.css',
  '/css/mobile-overrides.css',
  '/css/mobile-portal.css',
  '/css/mobile-delight.css',
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
  '/js/sidebarCustomizer.js',
  '/js/charts.js',
  '/js/tableBuilder.js',
  '/js/commandPalette.js',
  '/js/formBuilder.js',
  '/js/utils/mobileGestures.js',
  '/js/utils/attendanceHeatmap.js',
  '/js/utils/imageCompressor.js',
  '/js/utils/audioFeedback.js',
  '/js/utils/pushNotifications.js',
  '/js/utils/smartIntelligence.js',
  '/js/utils/smartFormatters.js',
  '/js/utils/idbStorage.js',
  '/js/pdfGenerator.js',
  '/js/signatureStudio.js',
  '/js/mediaStudio.js',
  '/js/paymentStudio.js',
  '/js/errorBoundary.js',
  '/js/smartLoading.js',
  '/js/performanceMonitor.js',
  // Dynamic Route Pages (pre-cache for instant offline & zero-lag tab transitions)
  '/js/pages/dashboard.js',
  '/js/pages/students.js',
  '/js/pages/seats.js',
  '/js/pages/plans.js',
  '/js/pages/lockers.js',
  '/js/pages/payments.js',
  '/js/pages/attendance.js',
  '/js/pages/shifts.js',
  '/js/pages/branches.js',
  '/js/pages/reports.js',
  '/js/pages/expenses.js',
  '/js/pages/operations.js',
  '/js/pages/trash.js',
  '/js/pages/settings.js',
  '/js/pages/profile.js',
  '/js/pages/portal.js'
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

// ── Fetch — Stale-While-Revalidate for JS/CSS & Media, Network-First for HTML ──
self.addEventListener('fetch', (event) => {
  const req = event.request;
  const url = new URL(req.url);

  // Bypass: non-GET, API endpoints, uploaded files, external domains
  if (
    req.method !== 'GET' ||
    url.pathname.startsWith('/api/') ||
    url.pathname.startsWith('/uploads/') ||
    !url.origin.startsWith(self.location.origin.slice(0, -1))
  ) {
    return;
  }

  // 1. Network-First ONLY for HTML documents so new server releases/auth checks apply immediately
  const isHtmlDoc = req.headers.get('accept')?.includes('text/html') ||
    url.pathname === '/' ||
    url.pathname.endsWith('.html') ||
    url.pathname === '/register' ||
    url.pathname === '/landing' ||
    url.pathname === '/student-login' ||
    url.pathname === '/portal-login' ||
    url.pathname === '/kiosk';

  if (isHtmlDoc) {
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
          return (await caches.match('/index.html')) || (await caches.match('/offline.html')) || new Response('', { status: 503 });
        })
    );
    return;
  }

  // 2. Ultra-Fast Stale-While-Revalidate for JS, CSS, fonts, icons, images
  // Serves instantaneous sub-10ms response from cache, while silently updating cache in the background
  event.respondWith(
    caches.open(CACHE_NAME).then(async (cache) => {
      const cachedResponse = await cache.match(req);
      const networkFetch = fetch(req)
        .then((networkResponse) => {
          if (networkResponse && networkResponse.status === 200 && networkResponse.type !== 'opaque') {
            cache.put(req, networkResponse.clone());
          }
          return networkResponse;
        })
        .catch(() => cachedResponse);

      return cachedResponse || networkFetch;
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
