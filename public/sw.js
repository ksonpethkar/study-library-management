/**
 * Study Library Management System — Service Worker (PWA)
 * Instant offline caching, network-first strategy, app shell optimization
 */

const CACHE_NAME = 'studylib-pwa-v1';
const ASSETS_TO_CACHE = [
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
  '/css/index.css',
  '/css/layout.css',
  '/css/components.css',
  '/js/app.js',
  '/js/auth.js',
  '/js/ui.js',
  '/js/api.js',
  '/js/pdfGenerator.js'
];

self.addEventListener('install', (event) => {
  event.waitUntil(
    caches.open(CACHE_NAME).then((cache) => {
      return cache.addAll(ASSETS_TO_CACHE);
    }).then(() => self.skipWaiting())
  );
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches.keys().then((cacheNames) => {
      return Promise.all(
        cacheNames.map((cache) => {
          if (cache !== CACHE_NAME) {
            return caches.delete(cache);
          }
        })
      );
    }).then(() => self.clients.claim())
  );
});

self.addEventListener('fetch', (event) => {
  const req = event.request;

  // Skip non-GET requests and API calls from static caching
  if (req.method !== 'GET' || req.url.includes('/api/')) {
    return;
  }

  event.respondWith(
    fetch(req)
      .then((networkResponse) => {
        if (networkResponse && networkResponse.status === 200) {
          const responseClone = networkResponse.clone();
          caches.open(CACHE_NAME).then((cache) => {
            cache.put(req, responseClone);
          });
        }
        return networkResponse;
      })
      .catch(() => {
        return caches.match(req).then((cachedResponse) => {
          if (cachedResponse) {
            return cachedResponse;
          }
          if (req.headers.get('accept').includes('text/html')) {
            return caches.match('/index.html');
          }
        });
      })
  );
});
