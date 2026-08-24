#!/usr/bin/env node

const fs = require("fs");
const path = require("path");

// The original multi-file app now lives under classic/ (the root index.html is the
// promoted single-file Hi-Fi app, checked by verify-app.js instead).
const root = path.resolve(__dirname, "..");
const base = path.join(root, "classic");
const indexPath = path.join(base, "index.html");
const html = fs.readFileSync(indexPath, "utf8");

const expectedScripts = [
  "assets/js/app/utils.js",
  "assets/js/app/core.js",
  "assets/js/app/render.js",
  "assets/js/app/actions.js",
  "assets/js/app/bootstrap.js"
];

const requiredIds = [
  "todayChip",
  "stat-games",
  "stat-wins",
  "stat-upcoming",
  "seasonStatsGrid",
  "seasonRangeLabel",
  "dash-upcoming",
  "dash-games",
  "dash-ice",
  "planner-label",
  "plannerChecklist",
  "plannerChecklistInput",
  "planner-entries",
  "game-table",
  "game-tbody",
  "games-empty",
  "gm-shotpct",
  "practice-list",
  "practice-empty",
  "ice-list",
  "ice-empty",
  "printReport",
  "modal-event",
  "modal-game",
  "modal-practice",
  "modal-ice",
  "modal-issue"
];

function assert(condition, message) {
  if (!condition) {
    throw new Error(message);
  }
}

function countMatches(source, pattern) {
  return (source.match(pattern) || []).length;
}

assert(html.includes('href="assets/css/app.css"'), "Missing app.css stylesheet include.");
assert(html.includes('href="assets/icons/favicon/favicon.svg"'), "Missing favicon asset include.");

const scriptMatches = Array.from(html.matchAll(/<script src="([^"]+)"><\/script>/g)).map(match => match[1]);
assert(
  JSON.stringify(scriptMatches) === JSON.stringify(expectedScripts),
  `Unexpected script load order: ${scriptMatches.join(", ")}`
);

requiredIds.forEach((id) => {
  const count = countMatches(html, new RegExp(`id="${id}"`, "g"));
  assert(count === 1, `Expected id="${id}" exactly once, found ${count}.`);
});

const stateSource = fs.readFileSync(path.join(base, "assets/js/app/core.js"), "utf8");
assert(/const SCHEMA_VERSION = 4;/.test(stateSource), "SCHEMA_VERSION must remain 4 in core.js.");
assert(fs.existsSync(path.join(base, "assets/icons/favicon/favicon.svg")), "favicon.svg must exist.");

const manifestPath = path.join(base, "manifest.webmanifest");
assert(fs.existsSync(manifestPath), "Classic manifest must exist.");
const manifest = JSON.parse(fs.readFileSync(manifestPath, "utf8"));
assert(manifest.name === "CurlPlan Classic" && manifest.start_url === "./" && manifest.scope === "./",
  "Classic manifest must retain its product identity and scope.");
assert(html.includes('href="manifest.webmanifest"'), "Classic manifest link missing.");
assert(/Content-Security-Policy/.test(html) && /frame-src 'none'/.test(html), "Classic CSP boundary missing.");

const combined = expectedScripts
  .map((file) => fs.readFileSync(path.join(base, file), "utf8"))
  .join("\n");
new Function(combined);
assert(/IMPORT_LIMITS/.test(combined) && /validateImportText/.test(combined) && /validateImportRecords/.test(combined),
  "Classic import byte/depth/key/record limits missing.");

const sw = fs.readFileSync(path.join(base, "sw.js"), "utf8");
new Function(sw);
assert(/CACHE_PREFIX\s*=\s*"curlplan-classic-"/.test(sw), "Classic cache prefix missing.");
assert(/key\.startsWith\(CACHE_PREFIX\)\s*&&\s*key\s*!==\s*CACHE_NAME/.test(sw),
  "Classic worker must delete only obsolete Classic caches.");

console.log("verify-split: ok (classic/)");
