// CurlPlan Classic service worker. Cache ownership and fetch handling stay
// inside the Classic product boundary even though CacheStorage is origin-wide.
const CACHE_PREFIX = "curlplan-classic-";
const CACHE_NAME = `${CACHE_PREFIX}v7`;
const PRECACHE_URLS = [
  "./", "./index.html", "./manifest.webmanifest",
  "../icons/icon-192.png", "../icons/icon-512.png", "../icons/icon-maskable-512.png",
  "./assets/css/app.css", "./assets/css/theme.css",
  "./assets/js/app/utils.js", "./assets/js/app/core.js",
  "./assets/js/app/render.js", "./assets/js/app/actions.js",
  "./assets/js/app/bootstrap.js", "./assets/icons/favicon/favicon.svg"
];

function isClassicUrl(url) {
  return url.origin === self.location.origin &&
    url.pathname.startsWith(new URL(self.registration.scope).pathname);
}

self.addEventListener("install", event => {
  event.waitUntil(caches.open(CACHE_NAME).then(cache => cache.addAll(PRECACHE_URLS)));
  self.skipWaiting();
});

self.addEventListener("activate", event => {
  event.waitUntil(
    caches.keys()
      .then(keys => Promise.all(keys
        .filter(key => key.startsWith(CACHE_PREFIX) && key !== CACHE_NAME)
        .map(key => caches.delete(key))))
      .then(() => self.clients.claim())
  );
});

self.addEventListener("fetch", event => {
  const request = event.request;
  if (request.method !== "GET") return;
  const url = new URL(request.url);
  if (!isClassicUrl(url)) return;

  if (request.mode === "navigate") {
    event.respondWith(
      fetch(request)
        .then(response => {
          if (response.ok) {
            const copy = response.clone();
            event.waitUntil(caches.open(CACHE_NAME).then(cache => cache.put("./index.html", copy)));
          }
          return response;
        })
        .catch(() => caches.match("./index.html"))
    );
    return;
  }

  event.respondWith(
    caches.match(request, { cacheName: CACHE_NAME }).then(cached => cached ||
      fetch(request).then(response => {
        if (response.ok) {
          const copy = response.clone();
          event.waitUntil(caches.open(CACHE_NAME).then(cache => cache.put(request, copy)));
        }
        return response;
      })
    )
  );
});
