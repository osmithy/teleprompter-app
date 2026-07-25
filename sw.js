// Network-first service worker.
// Always try the latest version from the network when online, and fall back to the
// last cached copy only when offline. This keeps the home-screen (standalone) app
// up to date instead of getting stuck on an old cached page.
const CACHE = 'teleprompter-v1';

self.addEventListener('install', () => self.skipWaiting());
self.addEventListener('activate', (e) => e.waitUntil(self.clients.claim()));

self.addEventListener('fetch', (e) => {
  const req = e.request;
  if (req.method !== 'GET') return;
  e.respondWith(
    fetch(req)
      .then((res) => {
        // stash a fresh same-origin copy for offline use
        if (res && res.status === 200 && res.type === 'basic') {
          const copy = res.clone();
          caches.open(CACHE).then((c) => c.put(req, copy));
        }
        return res;
      })
      .catch(() => caches.match(req).then((r) => r || caches.match('./')))
  );
});
