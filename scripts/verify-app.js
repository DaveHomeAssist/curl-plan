#!/usr/bin/env node
// Verify the promoted single-file Hi-Fi app at the repo root (index.html).
// Checks: inline JS parses, all primary views + router exist, the service worker
// is registered and present, the inline favicon is set, and no dangling references
// to the archived classic/ asset paths leak into the root shell.

const fs = require("fs");
const path = require("path");

const root = path.resolve(__dirname, "..");
const indexPath = path.join(root, "index.html");
const html = fs.readFileSync(indexPath, "utf8");

function assert(condition, message) {
  if (!condition) throw new Error(message);
}

// 1. Inline scripts must parse.
const scripts = Array.from(html.matchAll(/<script>([\s\S]*?)<\/script>/g)).map(m => m[1]);
assert(scripts.length >= 1, "Expected at least one inline <script> block.");
new Function(scripts.join("\n"));

// 2. No external <script src> dependencies — the app is self-contained.
assert(!/<script\s+src=/.test(html), "Root app must not load external scripts.");

// 3. Primary views + router must be present.
const required = [
  "viewPassport", "viewLocker", "viewSpiels", "viewRoster", "viewStop", "viewCurler",
  "function render(", "function gotoTab(", "function push(", "function back(",
  "applyHash(", "applyQueryOverrides("
];
required.forEach(tok => assert(html.includes(tok), `Missing expected token: ${tok}`));

// 4. Theme tokens for both Ice and Arena must exist.
assert(/\[data-theme="arena"\]/.test(html), "Arena theme tokens missing.");

// 5. Service worker registered + file present.
assert(/serviceWorker.+register\("\.\/sw\.js"\)/s.test(html), "Service worker not registered.");
const swPath = path.join(root, "sw.js");
assert(fs.existsSync(swPath), "sw.js must exist at repo root.");
const sw = fs.readFileSync(swPath, "utf8");
new Function(sw); // parse-only smoke check (identifiers need not resolve)
assert(/CACHE_NAME\s*=\s*"curlplan-hifi-v1"/.test(sw), "sw.js CACHE_NAME must be curlplan-hifi-v1.");
assert(/caches\.keys\(\)/.test(sw) && /caches\.delete\(/.test(sw), "sw.js must purge old caches on activate.");

// 6. Inline favicon (self-contained, no file dependency).
assert(/rel="icon"[^>]*data:image\/svg\+xml/.test(html), "Inline SVG favicon missing.");

// 7. Root shell must not reference the archived classic/ asset tree.
assert(!/assets\/js\/app\//.test(html), "Root app should not reference classic split JS assets.");

console.log("verify-app: ok (root index.html + sw.js)");
