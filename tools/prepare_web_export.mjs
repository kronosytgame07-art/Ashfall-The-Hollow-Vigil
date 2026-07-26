import fs from "node:fs";

const target = process.argv[2];
if (!target) throw new Error("Usage: node prepare_web_export.mjs <index.html>");

let html = fs.readFileSync(target, "utf8");
const cleanup = `
		<script>
			// Supprime définitivement le cache de l'ancien prototype HTML à sprites.
			if ("serviceWorker" in navigator) {
				navigator.serviceWorker.getRegistrations().then(registrations => {
					for (const registration of registrations) registration.unregister();
				});
			}
			if ("caches" in window) {
				caches.keys().then(keys => Promise.all(keys.map(key => caches.delete(key))));
			}
		</script>`;

html = html.replace("<head>", `<head>${cleanup}`);
html = html.replace('<html lang="en">', '<html lang="fr">');
fs.writeFileSync(target, html);
