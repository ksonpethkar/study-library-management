/**
 * Study Library Management System — Service Worker (PWA)
 * Stale-While-Revalidate caching strategy, offline support, instant app shell
 */

const CACHE_NAME = 'studylib-pwa-v2';
const STATIC_ASSETS = [
  '/',
  '/index.html',
  '/student-login',
  '/student-login.html',
  '/register',
  '/register.html',
  '/landing',
  '/landing.html',
  '/kiosk',
  '/kiosk.html',
  '/manifest.json',
  '/css/variables.css',
  '/css/base.css',
  '/css/layout.css',
  '/css/components.css',
  '/css/print.css',
  '/js/themeManager.js',
  '/js/app.js',
  '/js/auth.js',
  '/js/ui.js',
  '/js/api.js',
  '/js/router.js',
  '/js/pdfGenerator.js',
  '/js/signatureStudio.js',
  '/js/mediaStudio.js'
];

self.addEventListener('install', (event) => {
  self.skipWaiting();
  event.waitUntil(
    caches.open(CACHE_NAME).then((cache) => {
      return cache.addAll(STATIC_ASSETS).catch((err) => {
        console.warn('SW: pre-caching partial failure', err);
      });
    })
  );
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches.keys().then((cacheNames) => {
      return Promise.all(
        cacheNames.map((name) => {
          if (name !== CACHE_NAME) {
            return caches.delete(name);
          }
        })
      );
    }).then(() => self.clients.claim())
  );
});

self.addEventListener('fetch', (event) => {
  const req = event.request;
  const url = new URL(req.url);

  // Bypass non-GET requests and all API endpoints
  if (req.method !== 'GET' || url.pathname.startsWith('/api/')) {
    return;
  }

  // Stale-While-Revalidate Strategy for all static assets, scripts, styles, images & fonts
  event.respondWith(
    caches.open(CACHE_NAME).then(async (cache) => {
      const cachedResponse = await cache.match(req);

      const fetchPromise = fetch(req)
        .then((networkResponse) => {
          if (networkResponse && networkResponse.status === 200) {
            cache.put(req, networkResponse.clone());
          }
          return networkResponse;
        })
        .catch((err) => {
          // If offline and requesting an HTML page, fallback to cached index.html
          if (req.headers.get('accept')?.includes('text/html')) {
            return cache.match('/index.html') || cachedResponse;
          }
          return cachedResponse;
        });

      // Return cached response immediately if available, while fetching update in background
      return cachedResponse || fetchPromise;
    })
  );
});
