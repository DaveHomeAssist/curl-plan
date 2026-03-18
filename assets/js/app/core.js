// CurlPlan core state, schema, storage, and normalization
const STORAGE_KEY = "curlplan-v1";
const SCHEMA_VERSION = 3;
const CHECKLIST_DEFAULTS_KEY = "cp_checklist_defaults";
const UI_PREFS_KEY = "cp_ui_prefs_v1";
const PROTOTYPE_KEYS = {
  events: "cp_events",
  games: "cp_games",
  practice: "cp_practice",
  ice: "cp_ice",
  issues: "cp_issues",
  planner: "cp_planner"
};
const DEFAULT_PLANNER_CHECKLIST = [
  { text: "Equipment check", checked: false },
  { text: "Warm-up routine", checked: false },
  { text: "Team communication reminders", checked: false }
];

const emptyState = () => ({
  version: SCHEMA_VERSION,
  events: [],
  games: [],
  practice: [],
  ice: [],
  issues: [],
  plannerEntries: {}
});

const demoState = () => ({
  version: SCHEMA_VERSION,
  events: [
    {
      id: createId(),
      title: "Team Night",
      type: "league",
      date: "2026-03-19",
      time: "19:00",
      rink: "Main Rink",
      team: "",
      opponent: "",
      position: "Third",
      sheet: "3",
      notes: "Arrive early"
    },
    {
      id: createId(),
      title: "Spring Tournament",
      type: "bonspiel",
      date: "2026-03-21",
      time: "09:00",
      rink: "City Arena",
      team: "",
      opponent: "",
      position: "Skip",
      sheet: "1",
      notes: "Round robin format"
    },
    {
      id: createId(),
      title: "Morning Session",
      type: "practice",
      date: "2026-03-22",
      time: "06:30",
      rink: "Main Rink",
      team: "",
      opponent: "",
      position: "Lead",
      sheet: "2",
      notes: "Focus on basics"
    }
  ],
  games: [
    {
      id: createId(),
      date: "2026-03-12",
      opponent: "Team A",
      us: 7,
      them: 3,
      result: "W",
      position: "Third",
      rink: "Main Rink",
      keyShot: "Draw to button",
      notes: "Strong hammer game",
      shotPct: 82
    },
    {
      id: createId(),
      date: "2026-03-05",
      opponent: "Team B",
      us: 4,
      them: 6,
      result: "L",
      position: "Lead",
      rink: "City Arena",
      keyShot: "Guard held 3 ends",
      notes: "Lost hammer in 4th",
      shotPct: 71
    },
    {
      id: createId(),
      date: "2026-02-26",
      opponent: "Team C",
      us: 5,
      them: 5,
      result: "D",
      position: "Second",
      rink: "Main Rink",
      keyShot: "Freeze on shot rock",
      notes: "Extra end, came up light",
      shotPct: 76
    }
  ],
  practice: [
    {
      id: createId(),
      date: "2026-03-15",
      duration: "60 min",
      shots: ["Draw", "Guard"],
      focus: "Release",
      notes: "Working on flat release"
    },
    {
      id: createId(),
      date: "2026-03-08",
      duration: "90 min",
      shots: ["Takeout", "Hit & Roll"],
      focus: "Weight control",
      notes: "Rolls landing off target"
    },
    {
      id: createId(),
      date: "2026-03-01",
      duration: "45 min",
      shots: ["Broom Work"],
      focus: "Communication",
      notes: "Louder verbal cues needed"
    }
  ],
  ice: [
    {
      id: createId(),
      date: "2026-03-19",
      rink: "Main Rink",
      speed: 4,
      curl: "Moderate",
      notes: "Sheet 3 curls late. Rocks 4 and 7 run light."
    },
    {
      id: createId(),
      date: "2026-03-12",
      rink: "Main Rink",
      speed: 3,
      curl: "Big Finish",
      notes: "Fresh pebble, draw weight longer than usual"
    },
    {
      id: createId(),
      date: "2026-03-05",
      rink: "City Arena",
      speed: 3,
      curl: "Straight",
      notes: "Consistent ice, nearly no curl on sheet 1"
    }
  ],
  issues: [
    { id: "001", component: "Service Worker", description: "Offline cache not updating on curlplan_v_1 edits.", severity: "P1", status: "open", proposedFix: "Version-string the cache name in sw.js." },
    { id: "002", component: "Form UI", description: "is-working button class triggers but doesn't clear.", severity: "P2", status: "deferred", proposedFix: "Add setTimeout clear to markWorking() function." },
    { id: "003", component: "Local Storage", description: "importData fails on legacy schema versions.", severity: "P1", status: "open", proposedFix: "Implement a data-migration switch-case in DataManager." }
  ],
  plannerEntries: {
    "2026-03-19": {
      time: "19:00",
      rink: "Main Rink",
      opponent: "Team B",
      position: "Third",
      goals: "Control early ends",
      scoreUs: "6",
      scoreThem: "4",
      ice: "Medium speed, slight curl left",
      reflection: "Consistent weight, adjust guard calls next game",
      keyShot: "Draw in 6th end",
      checklist: [
        { text: "Equipment check", checked: true },
        { text: "Warm-up routine", checked: true },
        { text: "Team communication reminders", checked: false }
      ]
    }
  }
});

let state = loadState();
let uiPrefs = loadUiPrefs();
let currentView = uiPrefs.lastView || "dashboard";
let currentFilter = "all";
let selectedEventId = state.events[0] ? state.events[0].id : null;
let plannerDate = uiPrefs.lastPlannerDate || todayStr();
let currentSpeed = 0;
let currentSeasonRange = "season";
let plannerChecklist = [];
let modalState = { event: null, game: null, practice: null, ice: null, issue: null };
let expandedGameId = null;
let pendingImportState = null;

const searchInput = document.getElementById("searchInput");
const filterType = document.getElementById("filterType");
const statusBar = document.getElementById("statusBar");
const plannerSnapshot = document.getElementById("plannerSnapshot");
const speedLabel = document.getElementById("speedLabel");

function normalizeEvent(item) {
  const candidate = item && typeof item === "object" ? item : {};
  return {
    id: asString(candidate.id) || createId(),
    title: asString(candidate.title || candidate.name) || "Untitled Event",
    type: normalizeType(candidate.type),
    date: asString(candidate.date) || todayStr(),
    time: asString(candidate.time),
    rink: asString(candidate.rink || candidate.location),
    team: asString(candidate.team),
    opponent: asString(candidate.opponent),
    position: normalizePosition(candidate.position),
    sheet: asString(candidate.sheet),
    notes: asString(candidate.notes)
  };
}

function normalizeGame(item) {
  const candidate = item && typeof item === "object" ? item : {};
  const parsed = parseLegacyResult(candidate.result);
  const us = candidate.us === "" ? "" : Number.isFinite(Number(candidate.us)) ? Number(candidate.us) : parsed.us;
  const them = candidate.them === "" ? "" : Number.isFinite(Number(candidate.them)) ? Number(candidate.them) : parsed.them;
  return {
    id: asString(candidate.id) || createId(),
    date: asString(candidate.date) || todayStr(),
    opponent: asString(candidate.opponent),
    us: us === "" ? "" : Number(us),
    them: them === "" ? "" : Number(them),
    result: computeResult(us, them, parsed.result || ""),
    position: normalizePosition(candidate.position),
    rink: asString(candidate.rink),
    keyShot: asString(candidate.keyShot || candidate.keyshot || candidate.keyShots),
    notes: asString(candidate.notes),
    shotPct: Number.isFinite(Number(candidate.shotPct)) ? Number(candidate.shotPct) : ""
  };
}

function normalizePractice(item) {
  const candidate = item && typeof item === "object" ? item : {};
  const shots = Array.isArray(candidate.shots)
    ? candidate.shots.map(asString).filter(Boolean)
    : asString(candidate.focus).split(",").map(part => part.trim()).filter(Boolean);
  return {
    id: asString(candidate.id) || createId(),
    date: asString(candidate.date) || todayStr(),
    duration: asString(candidate.duration) || "60 min",
    shots,
    focus: asString(candidate.focus),
    notes: asString(candidate.notes)
  };
}

function normalizeIce(item) {
  const candidate = item && typeof item === "object" ? item : {};
  return {
    id: asString(candidate.id) || createId(),
    date: asString(candidate.date) || todayStr(),
    rink: asString(candidate.rink),
    speed: normalizeSpeed(candidate.speed),
    curl: asString(candidate.curl),
    notes: asString(candidate.notes)
  };
}

function normalizeIssueSeverity(value) {
  const s = asString(value);
  if (["P1", "P2", "P3"].includes(s)) return s;
  if (s === "High") return "P1";
  if (s === "Med") return "P2";
  if (s === "Low") return "P3";
  return "P2";
}

function normalizeIssueStatus(value) {
  const s = asString(value).toLowerCase();
  if (["open", "in-progress", "resolved", "deferred"].includes(s)) return s;
  if (s === "active") return "open";
  if (s === "draft") return "deferred";
  return "open";
}

function nextIssueId() {
  const nums = state.issues.map(i => {
    const m = i.id.match(/^(\d+)$/);
    return m ? Number(m[1]) : 0;
  });
  const max = nums.length ? Math.max(...nums) : 0;
  return String(max + 1).padStart(3, "0");
}

function normalizeIssue(item) {
  const candidate = item && typeof item === "object" ? item : {};
  return {
    id: asString(candidate.id) || String(Date.now()).slice(-3),
    component: asString(candidate.component),
    description: asString(candidate.description),
    severity: normalizeIssueSeverity(candidate.severity),
    status: normalizeIssueStatus(candidate.status),
    proposedFix: asString(candidate.proposedFix)
  };
}

function normalizePlannerEntries(entries) {
  const output = {};
  if (!entries || typeof entries !== "object" || Array.isArray(entries)) return output;
  Object.entries(entries).forEach(([date, entry]) => {
    if (!/^\d{4}-\d{2}-\d{2}$/.test(date) || !entry || typeof entry !== "object") return;
    output[date] = {
      time: asString(entry.time || entry.gameTime),
      rink: asString(entry.rink),
      opponent: asString(entry.opponent),
      position: normalizePosition(entry.position),
      goals: asString(entry.goals),
      scoreUs: asString(entry.scoreUs),
      scoreThem: asString(entry.scoreThem),
      ice: asString(entry.ice || entry.iceNotes),
      reflection: asString(entry.reflection),
      keyShot: asString(entry.keyShot || entry.keyshot),
      checklist: normalizeChecklistItems(entry.checklist)
    };
  });
  return output;
}

function normalizeState(raw, strict = false) {
  const base = emptyState();
  if (!raw || typeof raw !== "object" || Array.isArray(raw)) {
    if (strict) throw new Error("Imported file is not a valid CurlPlan object.");
    return base;
  }

  const recognized = ["events", "games", "practice", "notes", "ice", "issues", "planner", "plannerEntries", "version"]
    .some(key => Object.prototype.hasOwnProperty.call(raw, key));
  if (strict && !recognized) {
    throw new Error("Imported JSON does not match a CurlPlan export.");
  }

  const events = Array.isArray(raw.events) ? raw.events.map(normalizeEvent) : [];
  const games = Array.isArray(raw.games) ? raw.games.map(normalizeGame) : [];
  const practice = Array.isArray(raw.practice) ? raw.practice.map(normalizePractice) : [];
  const iceSource = Array.isArray(raw.ice) ? raw.ice : Array.isArray(raw.notes) ? raw.notes : [];
  const ice = iceSource.map(normalizeIce);
  const issues = Array.isArray(raw.issues) ? raw.issues.map(normalizeIssue) : [];

  let plannerEntries = normalizePlannerEntries(raw.plannerEntries);
  const legacyPlanner = raw.planner;
  if (!Object.keys(plannerEntries).length && legacyPlanner && typeof legacyPlanner === "object") {
    const legacyDate = asString(legacyPlanner.date) || todayStr();
    plannerEntries = {
      [legacyDate]: {
        time: asString(legacyPlanner.time || legacyPlanner.gameTime),
        rink: asString(legacyPlanner.rink),
        opponent: asString(legacyPlanner.opponent),
        position: normalizePosition(legacyPlanner.position),
        goals: asString(legacyPlanner.goals),
        scoreUs: asString(legacyPlanner.scoreUs),
        scoreThem: asString(legacyPlanner.scoreThem),
        ice: asString(legacyPlanner.ice || legacyPlanner.iceNotes),
        reflection: asString(legacyPlanner.reflection),
        keyShot: asString(legacyPlanner.keyShot),
        checklist: []
      }
    };
  }

  return {
    version: SCHEMA_VERSION,
    events,
    games,
    practice,
    ice,
    issues,
    plannerEntries
  };
}

function safeParseStorage(key) {
  try {
    const raw = localStorage.getItem(key);
    return raw ? JSON.parse(raw) : null;
  } catch {
    return null;
  }
}

function loadChecklistDefaults() {
  const stored = safeParseStorage(CHECKLIST_DEFAULTS_KEY);
  const normalized = stripChecklistChecks(stored);
  return normalized.length ? normalized : cloneChecklist(DEFAULT_PLANNER_CHECKLIST);
}

function defaultUiPrefs() {
  return {
    lastView: "dashboard",
    lastPlannerDate: todayStr(),
    plannerTemplate: {
      rink: "",
      position: "",
      opponent: ""
    }
  };
}

function loadUiPrefs() {
  const defaults = defaultUiPrefs();
  const stored = safeParseStorage(UI_PREFS_KEY);
  if (!stored || typeof stored !== "object" || Array.isArray(stored)) return defaults;
  return {
    ...defaults,
    ...stored,
    plannerTemplate: {
      ...defaults.plannerTemplate,
      ...(stored.plannerTemplate && typeof stored.plannerTemplate === "object" ? stored.plannerTemplate : {})
    }
  };
}

function saveUiPrefs(nextPrefs = uiPrefs) {
  const defaults = defaultUiPrefs();
  uiPrefs = {
    ...defaults,
    ...nextPrefs,
    plannerTemplate: {
      ...defaults.plannerTemplate,
      ...(nextPrefs.plannerTemplate && typeof nextPrefs.plannerTemplate === "object" ? nextPrefs.plannerTemplate : {})
    }
  };
  localStorage.setItem(UI_PREFS_KEY, JSON.stringify(uiPrefs));
}

function saveChecklistDefaults(items) {
  const defaults = stripChecklistChecks(items);
  const safeDefaults = defaults.length ? defaults : cloneChecklist(DEFAULT_PLANNER_CHECKLIST);
  localStorage.setItem(CHECKLIST_DEFAULTS_KEY, JSON.stringify(safeDefaults));
}

function checklistMatchesDefaults(items) {
  const checklist = stripChecklistChecks(items);
  const defaults = loadChecklistDefaults();
  if (checklist.length !== defaults.length) return false;
  return checklist.every((item, index) => item.text === defaults[index].text);
}

function checklistHasMeaningfulState(items) {
  const checklist = normalizeChecklistItems(items);
  if (!checklist.length) return false;
  if (checklist.some(item => item.checked)) return true;
  return !checklistMatchesDefaults(checklist);
}

function plannerEntryHasContent(entry) {
  if (!entry || typeof entry !== "object") return false;
  const scalarFields = [entry.time, entry.rink, entry.opponent, entry.position, entry.goals, entry.scoreUs, entry.scoreThem, entry.ice, entry.reflection, entry.keyShot];
  return scalarFields.some(value => asString(value)) || checklistHasMeaningfulState(entry.checklist);
}

function loadPrototypeState() {
  const rawEvents = safeParseStorage(PROTOTYPE_KEYS.events);
  const rawGames = safeParseStorage(PROTOTYPE_KEYS.games);
  const rawPractice = safeParseStorage(PROTOTYPE_KEYS.practice);
  const rawIce = safeParseStorage(PROTOTYPE_KEYS.ice);
  const rawPlanner = safeParseStorage(PROTOTYPE_KEYS.planner);
  const hasAnyData = [rawEvents, rawGames, rawPractice, rawIce, rawPlanner]
    .some(value => value && (Array.isArray(value) ? value.length : Object.keys(value).length));
  if (!hasAnyData) return null;
  return normalizeState({
    events: rawEvents,
    games: rawGames,
    practice: rawPractice,
    ice: rawIce,
    plannerEntries: rawPlanner
  });
}

function loadState() {
  const raw = localStorage.getItem(STORAGE_KEY);
  if (raw) {
    try {
      return normalizeState(JSON.parse(raw));
    } catch {
      return clone(demoState());
    }
  }
  const migratedPrototype = loadPrototypeState();
  if (migratedPrototype) {
    localStorage.setItem(STORAGE_KEY, JSON.stringify(migratedPrototype));
    return migratedPrototype;
  }
  return clone(demoState());
}

function saveState(nextState = state) {
  state = normalizeState(nextState);
  localStorage.setItem(STORAGE_KEY, JSON.stringify(state));
}
