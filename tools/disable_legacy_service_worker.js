// Tombstone for the legacy 2D PWA worker.
// Browsers fetch this URL when checking the old registration for updates.
self.addEventListener("install", event => {
	event.waitUntil(self.skipWaiting());
});

self.addEventListener("activate", event => {
	event.waitUntil((async () => {
		const keys = await caches.keys();
		await Promise.all(keys.map(key => caches.delete(key)));
		await self.clients.claim();
		const clients = await self.clients.matchAll({
			type: "window",
			includeUncontrolled: true,
		});
		await self.registration.unregister();
		for (const client of clients) {
			await client.navigate(client.url);
		}
	})());
});

self.addEventListener("fetch", event => {
	// Never answer from an old cache while this tombstone is taking control.
	event.respondWith(fetch(event.request));
});
