#!/usr/bin/env node
"use strict";
// Exercise the actual inline app functions with storage and form elements only.
// This verifies record transactions, not browser layout or device interaction.
const fs = require("node:fs");
const vm = require("node:vm");
const assert = require("node:assert/strict");
const path = require("node:path");
const { mergeState } = require("../src/merge.js");
const html = fs.readFileSync(path.join(__dirname, "../index.html"), "utf8");
const source = [...html.matchAll(/<script>([\s\S]*?)<\/script>/g)].map(m => m[1]).join("\n");
const functions = source.slice(0, source.indexOf("/* ============================================================\n   Event delegation"));
assert(functions.length > 0);
const disk = new Map();
let full = false, confirmed = false;
function launch() {
  const nodes = new Map();
  const sheet = {};
  Object.defineProperty(sheet, "innerHTML", { set(markup) {
    nodes.clear();
    for (const m of markup.matchAll(/\bid="(f-[^"]+)"/g)) nodes.set(m[1], { value:"", children:[] });
  }});
  const c = vm.createContext({
    console, setTimeout, clearTimeout,
    localStorage: { getItem:k => disk.get(k) || null, setItem:(k,v) => { if(full) throw Error("QuotaExceededError"); disk.set(k,v); } },
    document: { getElementById:id => id === "sheet-body" ? sheet : nodes.get(id) || null },
    window: { confirm:() => confirmed },
  });
  vm.runInContext(functions, c);
  c.toast = message => { c.message = message; };
  c.render = () => {};
  c.gotoTab = () => {};
  c.openManagedSheet = () => {};
  c.auth.session = "demo";
  c.refreshStore();
  c.field = (id, value) => { const node = nodes.get("f-" + id); assert(node, `Missing field ${id}`); node.value = value; };
  c.value = id => nodes.get("f-" + id)?.value;
  return c;
}
let app = launch();
function assertPassportGames(count) {
  assert.match(app.viewPassport(), new RegExp('class="num">' + count + '</div><div class="lab">GAMES'));
}
assertPassportGames(0);
const seed = JSON.parse(fs.readFileSync(path.join(__dirname, "../data/season-seed.json"), "utf8"));
for (const stop of seed.stops.filter(s => s.games.length)) {
  const record = stop.games.filter(g => g.res === "W").length + "–" + stop.games.filter(g => g.res === "L").length;
  assert.equal(stop.record, record, stop.id);
  assert.equal(stop.ice.rec, record, stop.id);
}
app.openCompose(); app.field("body", "original");
assert.equal(app.persistEditorDraft(), true);
assert.equal(app.closeSheet(), true);
app = launch(); app.openCompose(); assert.equal(app.value("body"), "original");
assert.equal(app.submitCompose("note"), true);
let post = app.store.posts[0]; const id = post.id;
app.store.likes[id] = {v:true, at:1}; app.saveStore();
app.openCompose(null, id); app.field("body", "corrected"); app.persistEditorDraft();
assert.equal(app.store.posts[0].body, "original");
app = launch(); app.openCompose(null, id); assert.equal(app.value("body"), "corrected");
assert.equal(app.submitCompose("note"), true);
assert.equal(app.store.posts[0].id, id); assert.equal(app.store.posts.length, 1);
assert.equal(app.store.likes[id].v, true);
app.ui.lockerQ = "corrected"; assert.match(app.lockerCards(), /corrected/);
app.ui.lockerQ = "original"; assert(!app.lockerCards().includes("corrected"));
app.ui.lockerQ = "";
const stale = JSON.parse(JSON.stringify(app.store));
confirmed = false; assert.equal(app.deleteOwnedRecord("post", id), false);
confirmed = true; assert.equal(app.deleteOwnedRecord("post", id), true);
assert.equal(mergeState(stale, app.store).posts.length, 0);
app = launch(); assert.equal(app.store.posts.length, 0);
app.openCompose(); app.field("body", "keep me"); app.persistEditorDraft();
full = true; assert.equal(app.submitCompose("note"), false);
assert.equal(app.store.posts.length, 0); assert.equal(app.value("body"), "keep me");
assert.equal(app.closeSheet(), false); assert.match(app.message, /Could not save/);
full = false; confirmed = false; app.discardEditorDraft(); assert(app.activeEditor);
confirmed = true; app.discardEditorDraft(); assert.equal(app.activeEditor, null);
app = launch(); app.openCompose(); assert.equal(app.value("body"), "");
app.openCompose("result"); app.field("for", "4.5"); app.field("ag", "2");
assert.equal(app.submitCompose("result"), false);
app.field("for", "-1"); assert.equal(app.submitCompose("result"), false);
app.field("for", "8"); assert.equal(app.submitCompose("result"), true);
assertPassportGames(1);
assert.equal(app.derivedStats().win, 100);
post = app.store.posts[0]; app.openCompose(null, post.id); app.field("for", "1");
assert.equal(app.submitCompose("result"), true); assert.equal(app.store.posts[0].score.res, "LOSS");
assert.equal(app.derivedStats().win, 0);
assertPassportGames(1);
const resultID = post.id;
assert.equal(app.deleteOwnedRecord("post", resultID), true);
app = launch(); assertPassportGames(0);
app.openCompose("result"); app.field("for", "8"); app.field("ag", "2");
assert.equal(app.submitCompose("result"), true);
post = app.store.posts[0];
app.openCompose(null, post.id); app.store.posts = [];
assert.equal(app.submitCompose("result"), false); app.activeEditor = null;
assert.equal(app.ownedPost(app.feed[0].id), null);
app.openReview("kelowna"); app.field("note", "first review"); app.setStars(5);
assert.equal(app.submitReview("kelowna"), true);
const reviewId = app.store.reviews.kelowna[0].id;
app.openReview("kelowna", reviewId); app.field("note", "revised"); app.setStars(2); app.persistEditorDraft();
app = launch(); app.openReview("kelowna", reviewId);
assert.equal(app.value("note"), "revised"); assert.equal(app.formStars, 2);
assert.equal(app.store.reviews.kelowna[0].note, "first review");
assert.equal(app.submitReview("kelowna"), true); assert.equal(app.store.reviews.kelowna[0].stars, 2);
const staleReviews = JSON.parse(JSON.stringify(app.store));
assert.equal(app.deleteOwnedRecord("review", reviewId, "kelowna"), true);
assert.equal(mergeState(staleReviews, app.store).reviews.kelowna.length, 0);
app = launch(); assert.equal(app.store.reviews.kelowna.length, 0);
disk.set(app.storeKey(), JSON.stringify({reviews:{kelowna:[{stars:4,note:"legacy review",at:1}]}}));
app = launch(); const legacyId = app.store.reviews.kelowna[0].id;
app = launch(); assert.equal(app.store.reviews.kelowna[0].id, legacyId);
app.openReview("kelowna", legacyId); app.field("note", "legacy corrected");
assert.equal(app.submitReview("kelowna"), true);
app = launch(); assert.equal(app.store.reviews.kelowna.length, 1);
assert.equal(app.store.reviews.kelowna[0].note, "legacy corrected");
app.openCompose(); app.field("body", "private draft"); app.persistEditorDraft();
app.auth.session = null; app.refreshStore(); assert.equal(Object.keys(app.store.drafts).length, 0);
assert.equal(app.persistEditorDraft(), false);
console.log("verify-record-recovery: draft reload, correction, rating, ownership, safe deletion, merge, validation, storage failure and account isolation passed");
