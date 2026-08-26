// CurlPlan Service Worker (Hi-Fi app)
// Network-first for navigations so the HTML is always fresh; cache-first for
// other same-origin GETs. On activate we delete only caches this worker owns:
// its own "curlplan-hifi-*" lineage plus the legacy "curlplan-sw-v5" cache
// (the pre-promote root app). NOTE: CacheStorage is per-origin, not
// per-SW-scope, so the classic worker (scope /classic/) shares this keyspace;
// each worker prunes only its own cache family and leaves the rest alone.
const CACHE_NAME = "curlplan-hifi-v1";
const OWN_PREFIX = "curlplan-hifi-";
const LEGACY_CACHES = ["curlplan-sw-v5"];

const PRECACHE_URLS = ["./", "./index.html"];

self.addEventListener("install", event => {
  event.waitUntil(caches.open(CACHE_NAME).then(cache => cache.addAll(PRECACHE_URLS)));
  self.skipWaiting();
});

self.addEventListener("activate", event => {
  event.waitUntil(
    caches.keys()
      .then(keys => Promise.all(
        keys
          .filter(key => key !== CACHE_NAME && (key.startsWith(OWN_PREFIX) || LEGACY_CACHES.includes(key)))
          .map(key => caches.delete(key))
      ))
      .then(() => self.clients.claim())
  );
});

self.addEventListener("fetch", event => {
  const req = event.request;
  if (req.method !== "GET") return;

  // Navigations (the app shell): network-first, fall back to cache when offline.
  if (req.mode === "navigate") {
    const shellPath = new URL("./", self.location).pathname;
    const reqPath = new URL(req.url).pathname;
    // Only the root shell itself may refresh the canonical "./index.html"
    // entry — other navigations (classic, docs, error pages) must not
    // replace the offline shell.
    const isShell = reqPath === shellPath || reqPath === `${shellPath}index.html`;
    event.respondWith(
      fetch(req)
        .then(res => {
          // Normalize to one canonical shell entry so query-stringed deep links
          // (?theme=…&accent=…) don't accumulate per-URL copies. The runtime reads
          // theme/accent from location.search, so the shell HTML is query-agnostic.
          if (isShell && res.ok) {
            const clone = res.clone();
            caches.open(CACHE_NAME).then(cache => cache.put("./index.html", clone));
          }
          return res;
        })
        .catch(() => (isShell
          ? caches.match("./index.html")
          : caches.match(req).then(m => m || caches.match("./index.html"))))
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
