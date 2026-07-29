import { chromium } from "playwright-core";
import { PNG } from "pngjs";
import fs from "node:fs";

const url = process.env.ASHFALL_PAGES_URL;
if (!url) throw new Error("ASHFALL_PAGES_URL is required");

const browser = await chromium.launch({
  headless: true,
  executablePath: "/usr/bin/google-chrome",
  args: [
    "--enable-webgl",
    "--ignore-gpu-blocklist",
    "--use-gl=angle",
    "--use-angle=swiftshader",
  ],
});
const page = await browser.newPage({ viewport: { width: 1280, height: 720 } });
fs.mkdirSync("test-results", { recursive: true });
const browserErrors = [];
page.on("pageerror", error => browserErrors.push(`pageerror: ${error.message}`));
page.on("console", message => {
  if (message.type() === "error") browserErrors.push(`console: ${message.text()}`);
});

await page.goto(url, { waitUntil: "domcontentloaded", timeout: 60_000 });
await page.locator("canvas").waitFor({ state: "visible", timeout: 60_000 });
await page.waitForTimeout(15_000);

const menuShot = await page.screenshot();
fs.writeFileSync("test-results/menu.png", menuShot);
const menuStats = analyze(menuShot);
if (menuStats.nonDarkRatio < 0.002) {
  throw new Error(
    `The deployed canvas is visually black: ${JSON.stringify(menuStats)}`
  );
}

// Godot draws its controls inside the canvas. The play button is authored at
// x=490..790, y=430..488 in the fixed 1280x720 viewport.
await page.mouse.click(640, 459);
await page.waitForTimeout(6_000);
const worldShot = await page.screenshot();
fs.writeFileSync("test-results/world.png", worldShot);
const worldStats = analyze(worldShot);
const changedRatio = compare(menuShot, worldShot);
if (worldStats.nonDarkRatio < 0.01 || changedRatio < 0.03) {
  throw new Error(
    `The world did not become visibly rendered after Play: ` +
    `${JSON.stringify({ menuStats, worldStats, changedRatio })}`
  );
}

if (browserErrors.length) {
  throw new Error(`Browser runtime errors:\n${browserErrors.join("\n")}`);
}

console.log(JSON.stringify({ url, menuStats, worldStats, changedRatio }));
await browser.close();

function analyze(buffer) {
  const png = PNG.sync.read(buffer);
  let nonDark = 0;
  let colored = 0;
  const pixels = png.width * png.height;
  for (let i = 0; i < png.data.length; i += 4) {
    const r = png.data[i];
    const g = png.data[i + 1];
    const b = png.data[i + 2];
    if (Math.max(r, g, b) >= 32) nonDark++;
    if (Math.max(r, g, b) - Math.min(r, g, b) >= 12) colored++;
  }
  return {
    width: png.width,
    height: png.height,
    nonDarkRatio: nonDark / pixels,
    coloredRatio: colored / pixels,
  };
}

function compare(beforeBuffer, afterBuffer) {
  const before = PNG.sync.read(beforeBuffer);
  const after = PNG.sync.read(afterBuffer);
  if (before.width !== after.width || before.height !== after.height) return 1;
  let changed = 0;
  const pixels = before.width * before.height;
  for (let i = 0; i < before.data.length; i += 4) {
    const delta =
      Math.abs(before.data[i] - after.data[i]) +
      Math.abs(before.data[i + 1] - after.data[i + 1]) +
      Math.abs(before.data[i + 2] - after.data[i + 2]);
    if (delta >= 24) changed++;
  }
  return changed / pixels;
}
