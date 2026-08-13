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

// 2. Dependencies are allowed: external <script src>, bundlers, and a backend are
//    all permitted. The app is no longer required to be self-contained.

// 3. Primary views + router must be present.
const required = [
  "viewAuth", "viewPassport", "viewLocker", "viewSpiels", "viewRoster", "viewStop", "viewCurler",
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
assert(/CACHE_NAME\s*=\s*"curlplan-hifi-v2"/.test(sw), "sw.js CACHE_NAME must be curlplan-hifi-v2.");
assert(/caches\.keys\(\)/.test(sw) && /caches\.delete\(/.test(sw), "sw.js must purge old caches on activate.");

// 6. Public preview must not collect credentials until real backend auth is live.
assert(!/type="password"/.test(html), "Public preview must not render a password field.");
assert(!/data-action="submit-sign(?:in|up)"/.test(html), "Public preview must not expose local sign-in/sign-up actions.");
assert(/Demo only\./.test(html) && /No credentials are collected or transmitted\./.test(html), "Demo-only disclosure missing.");

// 7. Inline favicon present.
assert(/rel="icon"[^>]*data:image\/svg\+xml/.test(html), "Inline SVG favicon missing.");

// 8. Root shell must not reference the archived classic/ asset tree.
assert(!/assets\/js\/app\//.test(html), "Root app should not reference classic split JS assets.");

// 9. The static preview still needs browser-enforced boundaries around its
// inline shell and explicitly approved font hosts.
assert(/Content-Security-Policy/.test(html), "Content Security Policy missing.");
assert(/object-src 'none'/.test(html) && /base-uri 'self'/.test(html), "CSP object/base restrictions missing.");
assert(/name="referrer" content="strict-origin-when-cross-origin"/.test(html), "Referrer policy missing.");
assert(/<main class="phone">/.test(html) && /<\/main>/.test(html), "Main landmark missing.");

// 10. Closed dialogs must not leak controls into the initial keyboard order,
// and the shared lifecycle must provide the expected keyboard behavior.
["sheet", "sheet2"].forEach(id => {
  const dialog = html.match(new RegExp(`<div class="sheet" id="${id}"[^>]*>`));
  assert(dialog, `Dialog ${id} missing.`);
  assert(/aria-modal="true"/.test(dialog[0]), `Dialog ${id} must be modal.`);
  assert(/aria-hidden="true"/.test(dialog[0]) && /\bhidden\b/.test(dialog[0]) && /\binert\b/.test(dialog[0]),
    `Dialog ${id} must start hidden and inert.`);
});
assert(/function openManagedSheet\(/.test(html) && /function closeManagedSheet\(/.test(html),
  "Managed sheet lifecycle missing.");
assert(/e\.key === "Escape"/.test(html), "Escape must close the active sheet.");
assert(/closing\.trigger\.focus\(\)/.test(html), "Closing a sheet must restore invoking-control focus.");
assert(/activeSheet\.sheet\.focus\(\)/.test(html) && /e\.key !== "Tab"/.test(html),
  "Modal Tab containment missing.");

console.log("verify-app: ok (root index.html + sw.js)");
