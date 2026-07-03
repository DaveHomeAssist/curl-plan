// CurlPlan Service Worker (Hi-Fi app)
// Network-first for navigations so the HTML is always fresh; cache-first for
// other same-origin GETs. On activate we delete every
// origin cache except those in KEEP — this purges the legacy "curlplan-sw-v5" cache
// (the pre-promote root app) while preserving the archived classic app's own cache.
// NOTE: CacheStorage is per-origin, not per-SW-scope, so the classic worker
// (scope /classic/) shares this keyspace; KEEP must list its cache too, and the
// classic worker reciprocally keeps "curlplan-hifi-v1".
const CACHE_NAME = "curlplan-hifi-v1";
const KEEP = [CACHE_NAME, "curlplan-classic-v6"];

const PRECACHE_URLS = ["./", "./index.html"];

self.addEventListener("install", event => {
  event.waitUntil(caches.open(CACHE_NAME).then(cache => cache.addAll(PRECACHE_URLS)));
  self.skipWaiting();
});

self.addEventListener("activate", event => {
  event.waitUntil(
    caches.keys()
      .then(keys => Promise.all(keys.filter(key => !KEEP.includes(key)).map(key => caches.delete(key))))
      .then(() => self.clients.claim())
  );
});

self.addEventListener("fetch", event => {
  const req = event.request;
  if (req.method !== "GET") return;

  // Navigations (the app shell): network-first, fall back to cache when offline.
  if (req.mode === "navigate") {
    event.respondWith(
      fetch(req)
        .then(res => {
          // Normalize to one canonical shell entry so query-stringed deep links
          // (?theme=…&accent=…) don't accumulate per-URL copies. The runtime reads
          // theme/accent from location.search, so the shell HTML is query-agnostic.
          const clone = res.clone();
          caches.open(CACHE_NAME).then(cache => cache.put("./index.html", clone));
          return res;
        })
        .catch(() => caches.match("./index.html").then(m => m || caches.match(req)))
    );
    return;
  }

  // Everything else (same-origin static): cache-first, then network.
  event.respondWith(
    caches.match(req).then(cached => {
      if (cached) return cached;
      return fetch(req).then(res => {
        if (res.ok && new URL(req.url).origin === self.location.origin) {
          const clone = res.clone();
          caches.open(CACHE_NAME).then(cache => cache.put(req, clone));
        }
        return res;
      });
    })
  );
});
