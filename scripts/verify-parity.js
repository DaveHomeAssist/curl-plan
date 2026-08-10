#!/usr/bin/env node
/* ============================================================
 * verify-parity.js — cross-platform capability gate.
 *
 * Asserts that each parity capability is present on BOTH the web app (index.html)
 * and the iOS port (ios/CurlPlan/*.swift). A capability that exists on one platform
 * but not the other fails CI — the tripwire that stops the two apps drifting again.
 *
 * This is a lightweight token checklist, not a behavioral test. Keep it honest:
 * when you add a capability to one side, add its token here and to the other side.
 * ============================================================ */
"use strict";
const fs = require("fs");
const path = require("path");

const root = path.resolve(__dirname, "..");
const web = fs.readFileSync(path.join(root, "index.html"), "utf8");
const iosDir = path.join(root, "ios", "CurlPlan");
const ios = fs.readdirSync(iosDir)
  .filter(f => f.endsWith(".swift"))
  .map(f => fs.readFileSync(path.join(iosDir, f), "utf8"))
  .join("\n");

// Each capability: tokens that must appear in the web corpus AND the iOS corpus.
const CAPABILITIES = [
  { name: "Shared seed source of truth",     web: ["SEED:START", "CLUBS:START"],            ios: ["enum Seed", "enum Clubs"] },
  { name: "Interactive likes (persisted)",    web: ["toggleLike("],                          ios: ["func toggleLike(", "store.toggleLike("] },
  { name: "Compose note/result/review",       web: ["openCompose(", 'type === "review"'],    ios: ["ComposeSheet", "func addNote(", "func addReview(", "func addResult("] },
  { name: "Messaging threads",                web: ["openThread(", "function sendMessage("], ios: ["MessageThreadView", "func sendMessage("] },
  { name: "Stop contributions",               web: ["submitVisit", "submitIceRead", "submitReview"], ios: ["func addVisit(", "func addIceRead(", "func addStopReview("] },
  { name: "Spiel registration unified (spielId)", web: ["spielById(p.spielId)"],             ios: ["spielId", "func spielStatus("] },
  { name: "Credential-free demo gate",        web: ["Demo only.", 'data-action="auth-demo"'], ios: ["Demo only.", "func exploreDemo("] },
  { name: "Personalized Passport / derived stats", web: ["function derivedStats(", "function visitedStops("], ios: ["func derivedStats(", "func visitedStops("] },
  { name: "Functional search (Locker+Roster)", web: ["function lockerPosts(", "function rosterRows("], ios: ["func postMatches(", "SearchField"] },
  { name: "Create spiel / curler",            web: ["function submitNewSpiel(", "function submitNewCurler("], ios: ["func addSpiel(", "func addCurler(", "NewSpielSheet", "NewCurlerSheet"] },
  { name: "Following / Discover filter",       web: ["lockerTab", 'data-action="locker-tab"'], ios: ["lockerTab", "enum LockerTab"] },
  { name: "Demo state scoping",               web: ["storeKey(", "curlplan-hifi-state-v1"],  ios: ["stateKey", "cp.state.v2"] },
];

let failed = 0;
for (const cap of CAPABILITIES) {
  const missWeb = cap.web.filter(t => !web.includes(t));
  const missIos = cap.ios.filter(t => !ios.includes(t));
  if (missWeb.length || missIos.length) {
    failed++;
    console.error(`✗ ${cap.name}`);
    if (missWeb.length) console.error(`    web missing:  ${missWeb.join(", ")}`);
    if (missIos.length) console.error(`    iOS missing:  ${missIos.join(", ")}`);
  } else {
    console.log(`✓ ${cap.name}`);
  }
}

if (failed) {
  console.error(`\nverify-parity: ${failed} capability/capabilities out of parity.`);
  process.exit(1);
}
console.log(`\nverify-parity: all ${CAPABILITIES.length} capabilities present on both platforms ✓`);
