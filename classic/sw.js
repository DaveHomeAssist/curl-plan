// CurlPlan Service Worker (classic app, scope /classic/)
// Cache name is version-stamped so edits to assets invalidate the old cache.
// Renamed from the pre-promote "curlplan-sw-v5" so that the root Hi-Fi worker can
// purge the genuinely-stale v5 cache without touching the live classic cache.
// CacheStorage is per-origin, so KEEP also preserves the root app's cache.
const CACHE_NAME = "curlplan-classic-v6";
const KEEP = [CACHE_NAME, "curlplan-hifi-v1"];

const PRECACHE_URLS = [
  "./",
  "./index.html",
  "./assets/css/app.css",
  "./assets/css/theme.css",
  "./assets/js/app/utils.js",
  "./assets/js/app/core.js",
  "./assets/js/app/render.js",
  "./assets/js/app/actions.js",
  "./assets/js/app/bootstrap.js",
  "./assets/icons/favicon/favicon.svg",
];

self.addEventListener("install", event => {
  event.waitUntil(
    caches.open(CACHE_NAME).then(cache => cache.addAll(PRECACHE_URLS))
  );
  self.skipWaiting();
});

self.addEventListener("activate", event => {
  event.waitUntil(
    caches.keys().then(keys =>
      Promise.all(
        keys.filter(key => !KEEP.includes(key)).map(key => caches.delete(key))
      )
    )
  );
  self.clients.claim();
});

// Cache-first for precached assets, network-first for everything else.
self.addEventListener("fetch", event => {
  if (event.request.method !== "GET") return;
  event.respondWith(
    caches.match(event.request).then(cached => {
      if (cached) return cached;
      return fetch(event.request).then(response => {
        if (response.ok) {
          const clone = response.clone();
          caches.open(CACHE_NAME).then(cache => cache.put(event.request, clone));
        }
        return response;
      });
    })
  );
});
