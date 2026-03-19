// Node.js headless runner for CurlPlan stress tests
// Usage: node tests/run-stress.js

const fs = require('fs');
const path = require('path');

// ── Minimal DOM stubs ──
global.document = {
  getElementById: () => ({ value: '', textContent: '', addEventListener: () => {}, classList: { add(){}, remove(){}, toggle(){}, contains(){ return false; } }, style: {}, focus(){}, blur(){} }),
  querySelector: () => null,
  querySelectorAll: () => [],
  createElement: (tag) => ({ tagName: tag, className: '', textContent: '', innerHTML: '', style: {}, appendChild(){}, addEventListener(){}, setAttribute(){}, getAttribute(){ return null; }, classList: { add(){}, remove(){}, toggle(){}, contains(){ return false; } } }),
  body: { appendChild(){}, insertAdjacentHTML(){} },
  addEventListener: () => {},
};
global.window = { addEventListener: () => {}, removeEventListener: () => {}, matchMedia: () => ({ matches: false }) };
global.localStorage = (() => {
  const store = {};
  return {
    getItem: (k) => store[k] || null,
    setItem: (k, v) => { store[k] = String(v); },
    removeItem: (k) => { delete store[k]; },
    clear: () => { Object.keys(store).forEach(k => delete store[k]); },
  };
})();
global.navigator = { clipboard: { writeText: () => Promise.resolve() } };
global.requestAnimationFrame = (fn) => setTimeout(fn, 0);
global.setTimeout = global.setTimeout;
global.clearTimeout = global.clearTimeout;

// ── Load app modules ──
const utilsCode = fs.readFileSync(path.join(__dirname, '..', 'assets', 'js', 'app', 'utils.js'), 'utf8');
const coreCode = fs.readFileSync(path.join(__dirname, '..', 'assets', 'js', 'app', 'core.js'), 'utf8');

// eval in global scope so var declarations become globals
// Wrap const/let in a way that exposes needed symbols
const wrappedUtils = utilsCode.replace(/^const /gm, 'var ').replace(/^let /gm, 'var ');
const wrappedCore = coreCode.replace(/^const /gm, 'var ').replace(/^let /gm, 'var ');
eval(wrappedUtils);
eval(wrappedCore);

// ── Test harness ──
let totalPass = 0, totalFail = 0, totalSkip = 0;
const suites = [];

function suite(name, fn) {
  const cases = [];
  const assert = (label, condition) => {
    if (condition) { cases.push({ label, ok: true }); totalPass++; }
    else { cases.push({ label, ok: false }); totalFail++; }
  };
  const skip = (label) => { cases.push({ label, ok: null }); totalSkip++; };
  try { fn(assert, skip); } catch (e) {
    cases.push({ label: `SUITE THREW: ${e.message}`, ok: false }); totalFail++;
  }
  suites.push({ name, cases });
}

const t0 = Date.now();

// ═══════════════════════════════════════════════════════════════
// 1: Event Normalization
// ═══════════════════════════════════════════════════════════════
suite('Event Normalization', (assert) => {
  const e1 = normalizeEvent({ id: 'e1', title: 'League Night', type: 'league', date: '2026-03-19' });
  assert('Valid event preserves all fields', e1.title === 'League Night' && e1.type === 'league');

  assert('Missing title defaults to "Untitled Event"', normalizeEvent({ date: '2026-01-01' }).title === 'Untitled Event');
  assert('Legacy name → title', normalizeEvent({ name: 'Old', date: '2025-01-01' }).title === 'Old');
  assert('Invalid type → "other"', normalizeEvent({ title: 'X', type: 'bogus', date: '2026-01-01' }).type === 'other');
  assert('Null input → valid event', normalizeEvent(null).title === 'Untitled Event');
  assert('String input → valid event', normalizeEvent('hello').title === 'Untitled Event');
  assert('XSS stored as raw string', normalizeEvent({ title: '<script>alert(1)</script>', date: '2026-01-01' }).title.includes('<script>'));
});

// ═══════════════════════════════════════════════════════════════
// 2: Game Normalization
// ═══════════════════════════════════════════════════════════════
suite('Game Normalization', (assert) => {
  assert('Win computed', normalizeGame({ date: '2026-03-18', opponent: 'X', us: 7, them: 3 }).result === 'W');
  assert('Loss computed', normalizeGame({ date: '2026-03-18', opponent: 'X', us: 2, them: 8 }).result === 'L');
  assert('Draw computed', normalizeGame({ date: '2026-03-18', opponent: 'X', us: 5, them: 5 }).result === 'D');
  assert('Empty scores → null', normalizeGame({ date: '2026-03-18', opponent: 'X' }).us === null);
  assert('0-0 is valid draw', (() => { const g = normalizeGame({ date: '2026-03-18', opponent: 'X', us: 0, them: 0 }); return g.us === 0 && g.them === 0 && g.result === 'D'; })());
  assert('Legacy "W 7-3" parses', (() => { const g = normalizeGame({ date: '2026-03-18', opponent: 'X', result: 'W 7-3' }); return g.us === 7 && g.them === 3 && g.result === 'W'; })());
  assert('Shot pct number preserved', normalizeGame({ date: '2026-03-18', opponent: 'X', shotPct: 85 }).shotPct === 85);
  assert('Shot pct non-numeric → null', normalizeGame({ date: '2026-03-18', opponent: 'X', shotPct: 'high' }).shotPct === null);
  assert('Negative score floors to 0', normalizeGame({ date: '2026-03-18', opponent: 'X', us: -3, them: 5 }).us === 0);
});

// ═══════════════════════════════════════════════════════════════
// 3: Practice Normalization
// ═══════════════════════════════════════════════════════════════
suite('Practice Normalization', (assert) => {
  assert('Shots array preserved', normalizePractice({ date: '2026-03-18', shots: ['Draw', 'Guard'] }).shots.length === 2);
  assert('Comma focus → shots', normalizePractice({ date: '2026-03-18', focus: 'Draw, Guard, Takeout' }).shots.length === 3);
  assert('Missing shots → empty array', normalizePractice({ date: '2026-03-18' }).shots.length === 0);
});

// ═══════════════════════════════════════════════════════════════
// 4: Ice Normalization
// ═══════════════════════════════════════════════════════════════
suite('Ice Normalization', (assert) => {
  assert('Valid ice preserves', normalizeIce({ date: '2026-03-18', speed: 3, curl: 'Moderate' }).speed === 3);
  assert('Text speed "fast" maps to 4', normalizeIce({ date: '2026-03-18', speed: 'fast' }).speed === 4);
  assert('Speed > 5 resets to 0', normalizeIce({ date: '2026-03-18', speed: 6 }).speed === 0);
  assert('Negative speed resets to 0', normalizeIce({ date: '2026-03-18', speed: -1 }).speed === 0);
});

// ═══════════════════════════════════════════════════════════════
// 5: Issue Normalization
// ═══════════════════════════════════════════════════════════════
suite('Issue Normalization', (assert) => {
  assert('P1 preserved', normalizeIssue({ component: 'X', description: 'Y', severity: 'P1' }).severity === 'P1');
  assert('High → P1', normalizeIssue({ component: 'X', description: 'Y', severity: 'High' }).severity === 'P1');
  assert('Med → P2', normalizeIssue({ component: 'X', description: 'Y', severity: 'Med' }).severity === 'P2');
  assert('Low → P3', normalizeIssue({ component: 'X', description: 'Y', severity: 'Low' }).severity === 'P3');
  assert('Unknown → P2', normalizeIssue({ component: 'X', description: 'Y', severity: 'Critical' }).severity === 'P2');
  assert('active → open', normalizeIssue({ component: 'X', description: 'Y', status: 'active' }).status === 'open');
});

// ═══════════════════════════════════════════════════════════════
// 6: Planner Entries
// ═══════════════════════════════════════════════════════════════
suite('Planner Entries', (assert) => {
  const p1 = normalizePlannerEntries({ '2026-03-18': { time: '19:00', rink: 'Main' } });
  assert('Valid date key preserved', p1['2026-03-18'] && p1['2026-03-18'].rink === 'Main');
  assert('Invalid date key rejected', !normalizePlannerEntries({ 'bad': {} })['bad']);
  assert('Null → empty', Object.keys(normalizePlannerEntries(null)).length === 0);
  assert('Array → empty', Object.keys(normalizePlannerEntries([1])).length === 0);
  assert('Legacy gameTime → time', normalizePlannerEntries({ '2026-01-01': { gameTime: '18:00' } })['2026-01-01'].time === '18:00');
  assert('Legacy iceNotes → ice', normalizePlannerEntries({ '2026-01-01': { iceNotes: 'Fast' } })['2026-01-01'].ice === 'Fast');
});

// ═══════════════════════════════════════════════════════════════
// 7: Full State Normalization
// ═══════════════════════════════════════════════════════════════
suite('Full State', (assert) => {
  assert('Empty {} → valid state', normalizeState({}).version === SCHEMA_VERSION);
  assert('Null → empty state', normalizeState(null).events.length === 0);
  assert('Array → empty state', normalizeState([1]).events.length === 0);

  const demo = demoState();
  const rt = normalizeState(JSON.parse(JSON.stringify(demo)));
  assert('Demo round-trips', rt.events.length === demo.events.length && rt.games.length === demo.games.length);

  let threw = false;
  try { normalizeState({ randomKey: true }, { strict: true }); } catch (e) { threw = true; }
  assert('Strict rejects alien JSON', threw);

  let threwValid = false;
  try { normalizeState({ version: 3, events: [] }, { strict: true }); } catch (e) { threwValid = true; }
  assert('Strict accepts valid CurlPlan', !threwValid);
});

// ═══════════════════════════════════════════════════════════════
// 8: Validation Warnings
// ═══════════════════════════════════════════════════════════════
suite('Validation Warnings', (assert) => {
  const w1 = [];
  collectEventWarnings([{ title: '', date: '' }, { title: 'OK', date: '2026-01-01' }], w1);
  assert('Missing title flagged', w1.some(w => w.includes('missing title')));
  assert('Missing date flagged', w1.some(w => w.includes('missing date')));

  const w2 = [];
  warnAboutUnknownKeys('Event', { title: 'X', bogus: 'Z' }, ['title'], w2);
  assert('Unknown key flagged', w2.some(w => w.includes('bogus')));
});

// ═══════════════════════════════════════════════════════════════
// 9: Scale Stress
// ═══════════════════════════════════════════════════════════════
suite('Scale Stress', (assert) => {
  const bigEvents = Array.from({ length: 500 }, (_, i) => ({ id: 'e' + i, title: 'Event ' + i, type: 'league', date: '2026-01-01' }));
  const t1 = Date.now();
  const s1 = normalizeState({ events: bigEvents });
  const d1 = Date.now() - t1;
  assert(`500 events in < 100ms (${d1}ms)`, d1 < 100);
  assert('500 events preserved', s1.events.length === 500);

  const bigGames = Array.from({ length: 200 }, (_, i) => ({ id: 'g' + i, date: '2026-01-01', opponent: 'T' + i, us: i % 10, them: (i + 3) % 10 }));
  const t2 = Date.now();
  const s2 = normalizeState({ games: bigGames });
  const d2 = Date.now() - t2;
  assert(`200 games in < 100ms (${d2}ms)`, d2 < 100);
  assert('200 games preserved', s2.games.length === 200);

  const bigPlanner = {};
  for (let d = 0; d < 365; d++) {
    const dt = new Date(2026, 0, 1 + d);
    bigPlanner[dt.toISOString().slice(0, 10)] = { time: '19:00', rink: 'R' + (d % 3), checklist: [{ text: 'Item', checked: d % 2 === 0 }] };
  }
  const t3 = Date.now();
  const p3 = normalizePlannerEntries(bigPlanner);
  const d3 = Date.now() - t3;
  assert(`365 planner entries in < 200ms (${d3}ms)`, d3 < 200);
  assert('365 entries preserved', Object.keys(p3).length === 365);

  const full = normalizeState({ events: bigEvents, games: bigGames, plannerEntries: bigPlanner });
  const kb = Math.round(JSON.stringify(full).length / 1024);
  assert(`Full state < 500KB (${kb}KB)`, kb < 500);
});

// ═══════════════════════════════════════════════════════════════
// 10: Persistence Round-Trip
// ═══════════════════════════════════════════════════════════════
suite('Persistence Round-Trip', (assert) => {
  const original = demoState();
  const key = 'test-' + Date.now();
  localStorage.setItem(key, JSON.stringify(original));
  const loaded = JSON.parse(localStorage.getItem(key));
  const normalized = normalizeState(loaded);
  assert('Events survive', normalized.events.length === original.events.length);
  assert('Games survive', normalized.games.length === original.games.length);
  assert('Planner survives', Object.keys(normalized.plannerEntries).length === Object.keys(original.plannerEntries).length);
  localStorage.removeItem(key);
});

// ═══════════════════════════════════════════════════════════════
// 11: Security
// ═══════════════════════════════════════════════════════════════
suite('Security', (assert) => {
  normalizeState(JSON.parse('{"__proto__": {"polluted": true}, "events": []}'));
  assert('__proto__ does not pollute', !({}).polluted);

  normalizeState(JSON.parse('{"constructor": {"prototype": {"polluted": true}}, "events": []}'));
  assert('constructor does not pollute', !({}).polluted);

  assert('10K title no crash', normalizeEvent({ title: 'A'.repeat(10000), date: '2026-01-01' }).title.length === 10000);
  assert('Unicode preserved', normalizeEvent({ title: '🥌 café 日本語', date: '2026-01-01' }).title.includes('🥌'));
  assert('Object in title → string', typeof normalizeEvent({ title: { nested: true }, date: '2026-01-01' }).title === 'string');
});

// ═══════════════════════════════════════════════════════════════
// 12: Season Stats
// ═══════════════════════════════════════════════════════════════
suite('Season Stats', (assert, skip) => {
  if (typeof calculateSeasonStats !== 'function') { skip('calculateSeasonStats not loaded'); return; }

  assert('Empty → zero record', (() => { const s = calculateSeasonStats([], 'all'); return s.wins === 0 && s.losses === 0; })());

  const wins = Array.from({ length: 10 }, (_, i) => normalizeGame({ date: '2026-03-' + String(i + 1).padStart(2, '0'), opponent: 'X', us: 7, them: 3 }));
  assert('10 wins: longestStreak = 10', calculateSeasonStats(wins, 'all').longestStreak === 10);

  const mixed = [
    normalizeGame({ date: '2026-03-01', opponent: 'A', us: 7, them: 3 }),
    normalizeGame({ date: '2026-03-02', opponent: 'B', us: 3, them: 7 }),
    normalizeGame({ date: '2026-03-03', opponent: 'C', us: 5, them: 5 }),
  ];
  const s3 = calculateSeasonStats(mixed, 'all');
  assert('1W 1L 1D', s3.wins === 1 && s3.losses === 1 && s3.draws === 1);

  assert('Unscored excluded', calculateSeasonStats([normalizeGame({ date: '2026-03-01', opponent: 'X' })], 'all').wins === 0);
});

// ═══════════════════════════════════════════════════════════════
// 13: Import Scenarios
// ═══════════════════════════════════════════════════════════════
suite('Import Scenarios', (assert) => {
  assert('Valid v3 strict', normalizeState({ version: 3, events: [{ id: 'e1', title: 'X', type: 'league', date: '2026-01-01' }], games: [], practice: [], ice: [], issues: [], plannerEntries: {} }, { strict: true }).events.length === 1);

  const legacy = { events: [{ name: 'Old', date: '2025-01-01' }], notes: [{ date: '2025-01-01', rink: 'X', speed: 3 }] };
  const s2 = normalizeState(legacy);
  assert('Legacy "notes" → "ice"', s2.ice.length === 1);
  assert('Legacy "name" → "title"', s2.events[0].title === 'Old');

  let threw = false;
  try { normalizeState({ foo: 'bar' }, { strict: true }); } catch (e) { threw = true; }
  assert('Alien JSON strict throws', threw);
  assert('Alien JSON non-strict → empty', normalizeState({ foo: 'bar' }).events.length === 0);

  let threw2 = false;
  try { normalizeState([{ title: 'X' }], { strict: true }); } catch (e) { threw2 = true; }
  assert('Array strict throws', threw2);

  const warnings = [];
  normalizeState({ events: [{ date: '' }] }, { warnings });
  assert('Warnings collected', warnings.some(w => w.includes('missing title')));
});

// ═══════════════════════════════════════════════════════════════
// RESULTS
// ═══════════════════════════════════════════════════════════════
const elapsed = Date.now() - t0;
console.log('\n═══ CurlPlan Stress Test Results ═══\n');
suites.forEach(s => {
  const passCount = s.cases.filter(c => c.ok === true).length;
  const failCount = s.cases.filter(c => c.ok === false).length;
  const mark = failCount > 0 ? '✗' : '✓';
  console.log(`${mark} ${s.name} (${passCount}/${s.cases.length})`);
  s.cases.filter(c => c.ok === false).forEach(c => console.log(`    ✗ ${c.label}`));
  s.cases.filter(c => c.ok === null).forEach(c => console.log(`    — ${c.label}`));
});
console.log(`\n${totalPass} passed · ${totalFail} failed · ${totalSkip} skipped · ${elapsed}ms\n`);
process.exit(totalFail > 0 ? 1 : 0);
