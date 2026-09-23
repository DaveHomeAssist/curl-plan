// CurlPlan Service Worker (classic app, scope /classic/)
// Cache name is version-stamped so edits to assets invalidate the old cache.
// Renamed from the pre-promote "curlplan-sw-v5" so that the root Hi-Fi worker can
// purge the genuinely-stale v5 cache without touching the live classic cache.
// CacheStorage is per-origin, so prune only this worker's cache lineage.
const CACHE_NAME = "curlplan-classic-v10";
const OWN_PREFIX = "curlplan-classic-";

const PRECACHE_URLS = [
  "./",
  "./index.html",
  "./assets/css/app.css?v=20260923c",
  "./assets/css/theme.css",
  "./assets/js/app/utils.js",
  "./assets/js/app/core.js",
  "./assets/js/app/render.js",
  "./assets/js/app/actions.js?v=20260923b",
  "./assets/js/app/bootstrap.js?v=20260923b",
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
        keys
          .filter(key => key !== CACHE_NAME && key.startsWith(OWN_PREFIX))
          .map(key => caches.delete(key))
      )
    )
  );
  self.clients.claim();
});

// Refresh the shell and assets online while retaining cached offline copies.
self.addEventListener("fetch", event => {
  if (event.request.method !== "GET") return;
  if (event.request.mode === "navigate") {
    event.respondWith(
      fetch(event.request).then(response => {
        if (response.ok) {
          const clone = response.clone();
          caches.open(CACHE_NAME).then(cache => cache.put("./index.html", clone));
        }
        return response;
      }).catch(() => caches.match("./index.html"))
    );
    return;
  }
  event.respondWith(
    fetch(event.request, { cache: "reload" }).then(response => {
      if (response.ok) {
        const clone = response.clone();
        caches.open(CACHE_NAME).then(cache => cache.put(event.request, clone));
      }
      return response;
    }).catch(() => caches.match(event.request))
  );
});
