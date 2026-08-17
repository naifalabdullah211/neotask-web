/* NEOTASK_SERVICE_WORKER_PURGE_20260817_1 */
const RELEASE = '20260817-1';

self.addEventListener('install', (event) => {
  event.waitUntil(self.skipWaiting());
});

self.addEventListener('activate', (event) => {
  event.waitUntil((async () => {
    const keys = await caches.keys();
    await Promise.all(keys.map((key) => caches.delete(key)));
    await self.clients.claim();

    const windows = await self.clients.matchAll({
      type: 'window',
      includeUncontrolled: true,
    });
    await Promise.all(windows.map(async (client) => {
      try {
        const url = new URL(client.url);
        if (
          url.origin === self.location.origin &&
          url.searchParams.get('neotaskSwPurge') !== RELEASE
        ) {
          url.searchParams.set('neotaskSwPurge', RELEASE);
          await client.navigate(url.href);
        }
      } catch (_) {}
    }));

    await self.registration.unregister().catch(() => false);
  })());
});
