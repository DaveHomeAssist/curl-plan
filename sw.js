// CurlPlan Service Worker
// Cache name is version-stamped so edits to assets invalidate the old cache.
const CACHE_NAME = "curlplan-sw-v4";

const PRECACHE_URLS = [
  "./",
  "./index.html",
  "./assets/css/app.css",
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
        keys.filter(key => key !== CACHE_NAME).map(key => caches.delete(key))
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
