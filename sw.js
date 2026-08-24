// CurlPlan root preview service worker. Cache ownership is prefix-scoped so
// activation can never remove Classic or unrelated origin caches.
const CACHE_PREFIX = "curlplan-root-";
const CACHE_NAME = `${CACHE_PREFIX}v3`;
const PRECACHE_URLS = [
  "./", "./index.html", "./manifest.webmanifest",
  "./icons/icon.svg", "./icons/icon-192.png", "./icons/icon-512.png",
  "./icons/icon-maskable-512.png", "./icons/apple-touch-icon.png"
];

function scopePath() {
  return new URL(self.registration.scope).pathname;
}

function isRootProductUrl(url) {
  const path = url.pathname;
  const scope = scopePath();
  return url.origin === self.location.origin && path.startsWith(scope) &&
    !path.startsWith(`${scope}classic/`);
}

function isRootShellNavigation(request) {
  if (request.mode !== "navigate") return false;
  const url = new URL(request.url);
  const scope = scopePath();
  return isRootProductUrl(url) && (url.pathname === scope || url.pathname === `${scope}index.html`);
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
  if (!isRootProductUrl(url)) return;

  if (isRootShellNavigation(request)) {
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

  if (request.mode === "navigate") return;
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
