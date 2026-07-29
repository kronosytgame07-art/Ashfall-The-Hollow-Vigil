import fs from "node:fs";

const target = process.argv[2];
if (!target) throw new Error("Usage: node prepare_web_export.mjs <index.html>");

let html = fs.readFileSync(target, "utf8");
const cleanup = `
		<script>
			// Supprime définitivement le cache de l'ancien prototype HTML à sprites.
			(async () => {
				const hadController = Boolean(navigator.serviceWorker && navigator.serviceWorker.controller);
				if ("serviceWorker" in navigator) {
					const registrations = await navigator.serviceWorker.getRegistrations();
					await Promise.all(registrations.map(registration => registration.unregister()));
				}
				if ("caches" in window) {
					const keys = await caches.keys();
					await Promise.all(keys.map(key => caches.delete(key)));
				}
				if (hadController && !sessionStorage.getItem("ashfall-godot-cache-reset")) {
					sessionStorage.setItem("ashfall-godot-cache-reset", "1");
					location.reload();
				}
			})();
		</script>`;

html = html.replace("<head>", `<head>${cleanup}`);
html = html.replace('<html lang="en">', '<html lang="fr">');
html = html.replace(
	"<head>",
	'<head><meta name="ashfall-build" content="godot-soulslike"><meta http-equiv="Cache-Control" content="no-cache, no-store, must-revalidate">'
);
fs.writeFileSync(target, html);
