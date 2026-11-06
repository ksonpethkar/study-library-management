'use strict';

/**
 * Cozy Corner Smart Study Library — Progressive Web App (PWA) Service Worker
 * Version: v1.5.50
 *
 * Implements Scenario G offline resilience:
 * - Pre-caches fonts (Google Fonts, Noto Sans, Material Icons), icons, and app manifest
 * - Cache-First for static fonts and vector assets
 * - Stale-While-Revalidate for branding logos and icons
 * - Network-First with Cache Fallback for app shell during basement reading room network dropouts
 */

const CACHE_NAME = 'cozy-corner-pwa-v1.5.50';

const PRECACHE_ASSETS = [
  './manifest.json',
  './favicon.ico',
  './favicon.png',
  './icons/Icon-192.png',
  './icons/Icon-512.png',
  'https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@400;500;600;700;800&display=swap',
  'https://fonts.googleapis.com/css2?family=Noto+Sans:wght@400;500;700&display=swap'
];

// Install: Pre-cache essential offline shell and fonts
self.addEventListener('install', (event) => {
  event.waitUntil(
    caches.open(CACHE_NAME).then((cache) => {
      // Use catch for individual assets so single failures don't block install
      return Promise.allSettled(
        PRECACHE_ASSETS.map((url) =>
          cache.add(url).catch((err) => {
            console.warn('[PWA SW] Pre-cache skip for:', url, err);
          })
        )
      );
    }).then(() => self.skipWaiting())
  );
});

// Activate: Purge stale caches and claim clients immediately
self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches.keys().then((keys) => {
      return Promise.all(
        keys.map((key) => {
          if (key !== CACHE_NAME) {
            console.log('[PWA SW] Purging old cache:', key);
            return caches.delete(key);
          }
        })
      );
    }).then(() => self.clients.claim())
  );
});

// Fetch: Smart offline routing
self.addEventListener('fetch', (event) => {
  const request = event.request;
  const url = new URL(request.url);

  // Skip non-GET requests and chrome-extension / firestore sync requests
  if (request.method !== 'GET') return;
  if (url.origin.includes('firestore.googleapis.com') ||
      url.origin.includes('firebaseio.com') ||
      url.origin.includes('identitytoolkit.googleapis.com')) {
    return;
  }

  // Strategy 1: Fonts & Icons (Cache-First for instant typography)
  if (url.origin.includes('fonts.gstatic.com') ||
      url.origin.includes('fonts.googleapis.com') ||
      url.pathname.includes('/fonts/') ||
      url.pathname.includes('/icons/')) {
    event.respondWith(
      caches.match(request).then((cached) => {
        if (cached) return cached;
        return fetch(request).then((response) => {
          if (response && response.status === 200) {
            const clone = response.clone();
            caches.open(CACHE_NAME).then((cache) => cache.put(request, clone));
          }
          return response;
        });
      })
    );
    return;
  }

  // Strategy 2: App Shell, JS & Navigation (Network-First, Cache Fallback on Network Dropout)
  event.respondWith(
    fetch(request)
      .then((networkResponse) => {
        if (networkResponse && networkResponse.status === 200) {
          const clone = networkResponse.clone();
          caches.open(CACHE_NAME).then((cache) => cache.put(request, clone));
        }
        return networkResponse;
      })
      .catch(async () => {
        const cachedResponse = await caches.match(request);
        if (cachedResponse) {
          return cachedResponse;
        }
        // If navigating and completely offline, fallback to cached index.html
        if (request.mode === 'navigate') {
          const indexCached = await caches.match('./index.html') || await caches.match('/app/');
          if (indexCached) return indexCached;
        }
        return new Response('Offline - Reading room connection dropout. Your cached student pass remains accessible.', {
          status: 503,
          statusText: 'Service Unavailable (Offline)'
        });
      })
  );
});
