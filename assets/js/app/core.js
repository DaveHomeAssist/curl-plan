// CurlPlan core state, schema, storage, and normalization
const STORAGE_KEY = "curlplan-v1";
const SCHEMA_VERSION = 4;
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
  rinks: [],
  sheets: [],
  lineups: [],
  lineupPresets: [],
  bonspiels: [],
  rinkConditionEntries: [],
  issues: [],
  plannerEntries: []
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
    { id: "001", component: "Service Worker", description: "[Sample] Offline cache versioning lags after release edits.", severity: "P1", status: "open", proposedFix: "Version-string the cache name in sw.js." },
    { id: "002", component: "Form UI", description: "[Sample] is-working button class triggers but does not clear.", severity: "P2", status: "deferred", proposedFix: "Add setTimeout clear to markWorking() function." },
    { id: "003", component: "Local Storage", description: "[Sample] Legacy schema import needs a migration switch-case.", severity: "P1", status: "open", proposedFix: "Implement a data-migration switch-case in DataManager." }
  ],
  plannerEntries: [
    {
      id: createId(),
      eventId: "",
      date: "2026-03-19",
      time: "19:00",
      rink: "Main Rink",
      rinkId: "",
      sheet: "3",
      sheetId: "",
      opponent: "Team B",
      position: "Third",
      goalOne: "Control early ends",
      goalTwo: "Sweep earlier on draw calls",
      goalThree: "Stay clear on vice communication",
      goals: "Control early ends",
      scoreUs: "6",
      scoreThem: "4",
      ice: "Medium speed, slight curl left",
      drawRating: 4,
      takeoutRating: 3,
      communicationRating: 4,
      sweepingRating: 4,
      mentalRating: 3,
      keyTakeaways: "Consistent weight. Guard calls still need cleaner timing.",
      nextFocus: "Get broom and release cues aligned before the first end.",
      reflection: "Consistent weight, adjust guard calls next game",
      keyShot: "Draw in 6th end",
      prepCompletedAt: "2026-03-19T17:45:00.000Z",
      reviewCompletedAt: "2026-03-19T22:05:00.000Z",
      checklist: [
        { text: "Equipment check", checked: true },
        { text: "Warm-up routine", checked: true },
        { text: "Team communication reminders", checked: false }
      ]
    }
  ]
});

let state = loadState();
let uiPrefs = loadUiPrefs();
let currentView = uiPrefs.lastView || "dashboard";
let currentFilter = uiPrefs.calendarFilter || "all";
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
    status: normalizeEventStatus(candidate.status),
    date: asString(candidate.date) || todayStr(),
    time: asString(candidate.time),
    rinkId: asString(candidate.rinkId),
    rink: asString(candidate.rink || candidate.location),
    sheetId: asString(candidate.sheetId),
    team: asString(candidate.team),
    opponent: asString(candidate.opponent),
    position: normalizePosition(candidate.position),
    sheet: asString(candidate.sheet),
    bonspielId: asString(candidate.bonspielId),
    lineupId: asString(candidate.lineupId),
    notes: asString(candidate.notes)
  };
}

function normalizeGame(item) {
  const candidate = item && typeof item === "object" ? item : {};
  const parsed = parseLegacyResult(candidate.result);
  const us = normalizeWholeNumber(candidate.us);
  const them = normalizeWholeNumber(candidate.them);
  const normalizedUs = us === null ? parsed.us : us;
  const normalizedThem = them === null ? parsed.them : them;
  return {
    id: asString(candidate.id) || createId(),
    eventId: asString(candidate.eventId),
    date: asString(candidate.date) || todayStr(),
    opponent: asString(candidate.opponent),
    us: normalizedUs === null ? null : Number(normalizedUs),
    them: normalizedThem === null ? null : Number(normalizedThem),
    result: computeResult(normalizedUs, normalizedThem, parsed.result || ""),
    position: normalizePosition(candidate.position),
    positionPlayed: normalizePosition(candidate.positionPlayed || candidate.position),
    rinkId: asString(candidate.rinkId),
    rink: asString(candidate.rink),
    lineupId: asString(candidate.lineupId),
    keyShot: asString(candidate.keyShot || candidate.keyshot || candidate.keyShots),
    notes: asString(candidate.notes),
    shotPct: Number.isFinite(Number(candidate.shotPct)) ? Number(candidate.shotPct) : null
  };
}

function normalizePractice(item) {
  const candidate = item && typeof item === "object" ? item : {};
  const shots = Array.isArray(candidate.shots)
    ? candidate.shots.map(asString).filter(Boolean)
    : asString(candidate.focus).split(",").map(part => part.trim()).filter(Boolean);
  return {
    id: asString(candidate.id) || createId(),
    eventId: asString(candidate.eventId),
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
    eventId: asString(candidate.eventId),
    date: asString(candidate.date) || todayStr(),
    rinkId: asString(candidate.rinkId),
    rink: asString(candidate.rink),
    sheetId: asString(candidate.sheetId),
    sheet: asString(candidate.sheet),
    speed: normalizeSpeed(candidate.speed),
    curl: asString(candidate.curl),
    frostLevel: asString(candidate.frostLevel),
    pebbleFeel: asString(candidate.pebbleFeel),
    hackCondition: asString(candidate.hackCondition),
    confidence: normalizeConfidence(candidate.confidence),
    notes: asString(candidate.notes)
  };
}

function normalizeEventStatus(value) {
  const status = asString(value).toLowerCase();
  if (["scheduled", "completed", "canceled", "skipped"].includes(status)) return status;
  return "scheduled";
}

function normalizeConfidence(value) {
  const num = Number.parseInt(value, 10);
  if (!Number.isFinite(num)) return null;
  return Math.max(1, Math.min(5, num));
}

function normalizeRink(item) {
  const candidate = item && typeof item === "object" ? item : {};
  return {
    id: asString(candidate.id) || createId(),
    name: asString(candidate.name || candidate.rink || candidate.location),
    city: asString(candidate.city),
    notes: asString(candidate.notes),
    defaultSheetCount: normalizeWholeNumber(candidate.defaultSheetCount)
  };
}

function normalizeSheet(item) {
  const candidate = item && typeof item === "object" ? item : {};
  return {
    id: asString(candidate.id) || createId(),
    rinkId: asString(candidate.rinkId),
    label: asString(candidate.label || candidate.sheet),
    notes: asString(candidate.notes)
  };
}

function normalizeLineup(item) {
  const candidate = item && typeof item === "object" ? item : {};
  return {
    id: asString(candidate.id) || createId(),
    eventId: asString(candidate.eventId),
    presetId: asString(candidate.presetId),
    assignments: normalizeLineupAssignments(candidate.assignments),
    opponents: asString(candidate.opponents),
    notes: asString(candidate.notes)
  };
}

function normalizeLineupPreset(item) {
  const candidate = item && typeof item === "object" ? item : {};
  return {
    id: asString(candidate.id) || createId(),
    name: asString(candidate.name) || "Untitled Lineup",
    assignments: normalizeLineupAssignments(candidate.assignments),
    notes: asString(candidate.notes)
  };
}

function normalizeLineupAssignments(assignments) {
  const source = assignments && typeof assignments === "object" && !Array.isArray(assignments) ? assignments : {};
  return LINEUP_ALL_SLOTS.reduce((acc, { key }) => {
    const slot = key;
    acc[slot] = asString(source[slot]);
    return acc;
  }, {});
}

function normalizeBonspiel(item) {
  const candidate = item && typeof item === "object" ? item : {};
  return {
    id: asString(candidate.id) || createId(),
    title: asString(candidate.title || candidate.name) || "Untitled Bonspiel",
    startDate: asString(candidate.startDate || candidate.date) || todayStr(),
    endDate: asString(candidate.endDate || candidate.startDate || candidate.date) || asString(candidate.startDate || candidate.date) || todayStr(),
    rinkId: asString(candidate.rinkId),
    venue: asString(candidate.venue),
    hotel: asString(candidate.hotel),
    travel: asString(candidate.travel),
    packing: asString(candidate.packing),
    budget: asString(candidate.budget),
    teammates: asString(candidate.teammates),
    bracketStage: asString(candidate.bracketStage),
    notes: asString(candidate.notes)
  };
}

function normalizePlannerRecord(item, fallbackDate = "") {
  const candidate = item && typeof item === "object" ? item : {};
  const normalizedGoals = normalizePlannerGoals(candidate);
  const keyTakeaways = asString(candidate.keyTakeaways || candidate.reflection);
  return {
    id: asString(candidate.id) || createId(),
    eventId: asString(candidate.eventId),
    date: asString(candidate.date) || fallbackDate || todayStr(),
    time: asString(candidate.time || candidate.gameTime),
    rink: asString(candidate.rink),
    rinkId: asString(candidate.rinkId),
    sheet: asString(candidate.sheet),
    sheetId: asString(candidate.sheetId),
    opponent: asString(candidate.opponent),
    position: normalizePosition(candidate.position),
    goalOne: normalizedGoals[0] || "",
    goalTwo: normalizedGoals[1] || "",
    goalThree: normalizedGoals[2] || "",
    goals: asString(candidate.goals) || normalizedGoals.filter(Boolean).join(" • "),
    scoreUs: asString(candidate.scoreUs),
    scoreThem: asString(candidate.scoreThem),
    ice: asString(candidate.ice || candidate.iceNotes),
    drawRating: normalizePlannerRating(candidate.drawRating),
    takeoutRating: normalizePlannerRating(candidate.takeoutRating),
    communicationRating: normalizePlannerRating(candidate.communicationRating),
    sweepingRating: normalizePlannerRating(candidate.sweepingRating),
    mentalRating: normalizePlannerRating(candidate.mentalRating),
    keyTakeaways,
    nextFocus: asString(candidate.nextFocus),
    reflection: asString(candidate.reflection) || keyTakeaways,
    keyShot: asString(candidate.keyShot || candidate.keyshot),
    prepCompletedAt: asString(candidate.prepCompletedAt),
    reviewCompletedAt: asString(candidate.reviewCompletedAt),
    checklist: normalizeChecklistItems(candidate.checklist)
  };
}

function normalizePlannerGoals(candidate) {
  const explicitGoals = [
    asString(candidate.goalOne),
    asString(candidate.goalTwo),
    asString(candidate.goalThree)
  ].filter(Boolean);
  if (explicitGoals.length) return explicitGoals.slice(0, 3);
  const legacyGoals = asString(candidate.goals)
    .split(/\r?\n|•|;/)
    .map((item) => item.replace(/^[\s\u2022*-]+/, "").trim())
    .filter(Boolean);
  return legacyGoals.slice(0, 3);
}

function normalizePlannerRating(value) {
  if (value === "" || value === null || value === undefined) return null;
  const num = Number(value);
  if (!Number.isFinite(num)) return null;
  const rounded = Math.round(num);
  return rounded >= 1 && rounded <= 5 ? rounded : null;
}

function normalizeRinkConditionEntry(item) {
  const candidate = item && typeof item === "object" ? item : {};
  return {
    id: asString(candidate.id) || createId(),
    sourceIceId: asString(candidate.sourceIceId),
    rinkId: asString(candidate.rinkId),
    sheetId: asString(candidate.sheetId),
    eventId: asString(candidate.eventId),
    recordedAt: asString(candidate.recordedAt || candidate.date) || todayStr(),
    speedEstimate: normalizeSpeed(candidate.speedEstimate ?? candidate.speed),
    curlInTurns: normalizeDecimal(candidate.curlInTurns),
    curlOutTurns: normalizeDecimal(candidate.curlOutTurns ?? deriveCurlTurnsFromLabel(candidate.curl)),
    curlLabel: asString(candidate.curlLabel || candidate.curl),
    frostLevel: asString(candidate.frostLevel),
    pebbleFeel: asString(candidate.pebbleFeel),
    hackCondition: asString(candidate.hackCondition),
    confidence: normalizeConfidence(candidate.confidence) ?? 3,
    notes: asString(candidate.notes)
  };
}

function normalizeDecimal(value) {
  const num = Number(value);
  return Number.isFinite(num) ? num : null;
}

function deriveCurlTurnsFromLabel(value) {
  const label = asString(value);
  if (!label) return null;
  const map = {
    "Very Straight": 1,
    "Straight": 2,
    "Moderate": 3,
    "Big Finish": 4
  };
  return map[label] ?? null;
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
  if (Array.isArray(entries)) {
    return entries.map((entry) => normalizePlannerRecord(entry)).filter((entry) => entry.date);
  }
  const output = [];
  if (!entries || typeof entries !== "object") return output;
  Object.entries(entries).forEach(([date, entry]) => {
    if (!/^\d{4}-\d{2}-\d{2}$/.test(date) || !entry || typeof entry !== "object") return;
    output.push(normalizePlannerRecord(entry, date));
  });
  return output;
}

function appendValidationWarning(warnings, message) {
  if (!Array.isArray(warnings) || !message || warnings.includes(message)) return;
  warnings.push(message);
}

function warnAboutUnknownKeys(label, candidate, allowedKeys, warnings) {
  if (!candidate || typeof candidate !== "object" || Array.isArray(candidate)) return;
  const extras = Object.keys(candidate).filter(key => !allowedKeys.includes(key));
  if (extras.length) {
    appendValidationWarning(warnings, `${label}: unrecognized key${extras.length === 1 ? "" : "s"} ${extras.join(", ")}`);
  }
}

function collectMissingFieldWarnings(label, items, requiredFields, warnings) {
  if (!Array.isArray(items) || !requiredFields.length) return;
  requiredFields.forEach((field) => {
    const count = items.filter((item) => !item || typeof item !== "object" || !asString(item[field])).length;
    if (count) appendValidationWarning(warnings, `${count} ${label}${count === 1 ? "" : "s"} missing ${field}`);
  });
}

function collectEventWarnings(items, warnings) {
  if (!Array.isArray(items)) return;
  const missingTitle = items.filter((item) => !item || typeof item !== "object" || !(asString(item.title) || asString(item.name))).length;
  const missingDate = items.filter((item) => !item || typeof item !== "object" || !asString(item.date)).length;
  if (missingTitle) appendValidationWarning(warnings, `${missingTitle} event${missingTitle === 1 ? "" : "s"} missing title`);
  if (missingDate) appendValidationWarning(warnings, `${missingDate} event${missingDate === 1 ? "" : "s"} missing date`);
}

// Explicit per-version migration so importData handles any legacy schema cleanly.
function migrateRaw(raw) {
  if (!raw || typeof raw !== "object" || Array.isArray(raw)) return raw;
  const v = Number.isFinite(Number(raw.version)) ? Number(raw.version) : 0;
  switch (true) {
    case v < 2:
      // v1: ice notes were stored under "notes"
      if (!raw.ice && raw.notes) raw = { ...raw, ice: raw.notes };
      // fallthrough
    case v < 3:
      // v2: no rinks or sheets
      raw = { ...raw, rinks: raw.rinks || [], sheets: raw.sheets || [] };
      // fallthrough
    case v < 4:
      // v3: no bonspiels, issues, or plannerEntries; planner was a single object
      raw = {
        ...raw,
        bonspiels: raw.bonspiels || [],
        issues: raw.issues || [],
        plannerEntries: raw.plannerEntries || (raw.planner ? [raw.planner] : []),
      };
      break;
    default:
      break;
  }
  return raw;
}

function normalizeState(raw, options = false) {
  const strict = typeof options === "object" ? Boolean(options.strict) : Boolean(options);
  const warnings = typeof options === "object" ? options.warnings : null;
  const base = emptyState();
  if (!raw || typeof raw !== "object" || Array.isArray(raw)) {
    if (strict) throw new Error("Imported file is not a valid CurlPlan object.");
    return base;
  }

  const recognized = ["events", "games", "practice", "notes", "ice", "issues", "planner", "plannerEntries", "rinks", "sheets", "lineups", "lineupPresets", "bonspiels", "rinkConditionEntries", "version"]
    .some(key => Object.prototype.hasOwnProperty.call(raw, key));
  if (strict && !recognized) {
    throw new Error("Imported JSON does not match a CurlPlan export.");
  }
  if (Array.isArray(warnings)) {
    const topLevelAllowed = ["events", "games", "practice", "notes", "ice", "issues", "planner", "plannerEntries", "rinks", "sheets", "lineups", "lineupPresets", "bonspiels", "rinkConditionEntries", "version"];
    const topLevelExtras = Object.keys(raw).filter(key => !topLevelAllowed.includes(key));
    if (topLevelExtras.length) {
      appendValidationWarning(warnings, `Top-level unrecognized key${topLevelExtras.length === 1 ? "" : "s"}: ${topLevelExtras.join(", ")}`);
    }
    if (Number.isFinite(Number(raw.version)) && Number(raw.version) < SCHEMA_VERSION) {
      appendValidationWarning(warnings, `Legacy schema v${raw.version} detected. CurlPlan will normalize it to v${SCHEMA_VERSION}.`);
    }
    if (raw.planner && !raw.plannerEntries) {
      appendValidationWarning(warnings, "Legacy planner format detected. It will be converted to planner entries.");
    }
    collectEventWarnings(raw.events, warnings);
    collectMissingFieldWarnings("game", raw.games, ["date", "opponent"], warnings);
    collectMissingFieldWarnings("practice session", raw.practice, ["date"], warnings);
    collectMissingFieldWarnings("ice note", Array.isArray(raw.ice) ? raw.ice : raw.notes, ["date"], warnings);
    collectMissingFieldWarnings("issue", raw.issues, ["component", "description"], warnings);
    (Array.isArray(raw.events) ? raw.events : []).forEach((item, index) => warnAboutUnknownKeys(`Event ${index + 1}`, item, ["id", "title", "name", "type", "status", "date", "time", "rinkId", "rink", "location", "team", "opponent", "position", "sheetId", "sheet", "bonspielId", "lineupId", "notes"], warnings));
    (Array.isArray(raw.games) ? raw.games : []).forEach((item, index) => warnAboutUnknownKeys(`Game ${index + 1}`, item, ["id", "eventId", "date", "opponent", "us", "them", "result", "position", "positionPlayed", "rinkId", "rink", "lineupId", "keyShot", "keyshot", "keyShots", "notes", "shotPct"], warnings));
    (Array.isArray(raw.practice) ? raw.practice : []).forEach((item, index) => warnAboutUnknownKeys(`Practice ${index + 1}`, item, ["id", "eventId", "date", "duration", "shots", "focus", "notes"], warnings));
    (Array.isArray(raw.ice) ? raw.ice : Array.isArray(raw.notes) ? raw.notes : []).forEach((item, index) => warnAboutUnknownKeys(`Ice note ${index + 1}`, item, ["id", "eventId", "date", "rinkId", "rink", "sheetId", "sheet", "speed", "curl", "frostLevel", "pebbleFeel", "hackCondition", "confidence", "notes"], warnings));
    (Array.isArray(raw.lineups) ? raw.lineups : []).forEach((item, index) => warnAboutUnknownKeys(`Lineup ${index + 1}`, item, ["id", "eventId", "presetId", "assignments", "opponents", "notes"], warnings));
    (Array.isArray(raw.lineupPresets) ? raw.lineupPresets : []).forEach((item, index) => warnAboutUnknownKeys(`Lineup preset ${index + 1}`, item, ["id", "name", "assignments", "notes"], warnings));
    (Array.isArray(raw.bonspiels) ? raw.bonspiels : []).forEach((item, index) => warnAboutUnknownKeys(`Bonspiel ${index + 1}`, item, ["id", "title", "name", "startDate", "endDate", "date", "rinkId", "venue", "hotel", "travel", "packing", "budget", "teammates", "bracketStage", "notes"], warnings));
    (Array.isArray(raw.issues) ? raw.issues : []).forEach((item, index) => warnAboutUnknownKeys(`Issue ${index + 1}`, item, ["id", "component", "description", "severity", "status", "proposedFix"], warnings));
  }

  const events = Array.isArray(raw.events) ? raw.events.map(normalizeEvent) : [];
  const games = Array.isArray(raw.games) ? raw.games.map(normalizeGame) : [];
  const practice = Array.isArray(raw.practice) ? raw.practice.map(normalizePractice) : [];
  const iceSource = Array.isArray(raw.ice) ? raw.ice : Array.isArray(raw.notes) ? raw.notes : [];
  const ice = iceSource.map(normalizeIce);
  const rinks = Array.isArray(raw.rinks) ? raw.rinks.map(normalizeRink) : [];
  const sheets = Array.isArray(raw.sheets) ? raw.sheets.map(normalizeSheet) : [];
  const lineups = Array.isArray(raw.lineups) ? raw.lineups.map(normalizeLineup) : [];
  const lineupPresets = Array.isArray(raw.lineupPresets) ? raw.lineupPresets.map(normalizeLineupPreset) : [];
  const bonspiels = Array.isArray(raw.bonspiels) ? raw.bonspiels.map(normalizeBonspiel) : [];
  const rinkConditionEntries = Array.isArray(raw.rinkConditionEntries) ? raw.rinkConditionEntries.map(normalizeRinkConditionEntry) : [];
  const issues = Array.isArray(raw.issues) ? raw.issues.map(normalizeIssue) : [];

  let plannerEntries = normalizePlannerEntries(raw.plannerEntries);
  const legacyPlanner = raw.planner;
  if (!plannerEntries.length && legacyPlanner && typeof legacyPlanner === "object") {
    const legacyDate = asString(legacyPlanner.date) || todayStr();
    plannerEntries = [normalizePlannerRecord(legacyPlanner, legacyDate)];
  }

  hydrateRinksAndSheets(events, games, ice, plannerEntries, rinks, sheets);
  backfillLinkedRecords(events, games, practice, ice, plannerEntries);
  hydrateRinkConditionEntries(ice, rinkConditionEntries);

  if (Array.isArray(warnings)) {
    const eventIds = new Set(events.map((item) => item.id));
    const rinkIds = new Set(rinks.map((item) => item.id));
    const bonspielIds = new Set(bonspiels.map((item) => item.id));
    const orphanGameLinks = games.filter((item) => item.eventId && !eventIds.has(item.eventId)).length;
    const orphanPracticeLinks = practice.filter((item) => item.eventId && !eventIds.has(item.eventId)).length;
    const orphanIceLinks = ice.filter((item) => item.eventId && !eventIds.has(item.eventId)).length;
    const orphanPlannerLinks = plannerEntries.filter((item) => item.eventId && !eventIds.has(item.eventId)).length;
    const orphanLineupLinks = lineups.filter((item) => item.eventId && !eventIds.has(item.eventId)).length;
    const orphanBonspielLinks = events.filter((item) => item.bonspielId && !bonspielIds.has(item.bonspielId) && !eventIds.has(item.bonspielId)).length;
    const orphanRinkLinks = events.filter((item) => item.rinkId && !rinkIds.has(item.rinkId)).length
      + ice.filter((item) => item.rinkId && !rinkIds.has(item.rinkId)).length
      + plannerEntries.filter((item) => item.rinkId && !rinkIds.has(item.rinkId)).length;
    if (orphanGameLinks) appendValidationWarning(warnings, `${orphanGameLinks} game link${orphanGameLinks === 1 ? "" : "s"} could not resolve to an event`);
    if (orphanPracticeLinks) appendValidationWarning(warnings, `${orphanPracticeLinks} practice link${orphanPracticeLinks === 1 ? "" : "s"} could not resolve to an event`);
    if (orphanIceLinks) appendValidationWarning(warnings, `${orphanIceLinks} ice link${orphanIceLinks === 1 ? "" : "s"} could not resolve to an event`);
    if (orphanPlannerLinks) appendValidationWarning(warnings, `${orphanPlannerLinks} planner link${orphanPlannerLinks === 1 ? "" : "s"} could not resolve to an event`);
    if (orphanLineupLinks) appendValidationWarning(warnings, `${orphanLineupLinks} lineup link${orphanLineupLinks === 1 ? "" : "s"} could not resolve to an event`);
    if (orphanBonspielLinks) appendValidationWarning(warnings, `${orphanBonspielLinks} bonspiel link${orphanBonspielLinks === 1 ? "" : "s"} could not resolve to a parent`);
    if (orphanRinkLinks) appendValidationWarning(warnings, `${orphanRinkLinks} rink link${orphanRinkLinks === 1 ? "" : "s"} could not resolve to a rink`);
  }

  return {
    version: SCHEMA_VERSION,
    events,
    games,
    practice,
    ice,
    rinks,
    sheets,
    lineups,
    lineupPresets,
    bonspiels,
    rinkConditionEntries,
    issues,
    plannerEntries
  };
}

function hydrateRinksAndSheets(events, games, ice, plannerEntries, rinks, sheets) {
  const rinkKeyToId = new Map();
  rinks.forEach((rink) => {
    if (!rink.name) return;
    rinkKeyToId.set(rink.name.toLowerCase(), rink.id);
  });
  const ensureRink = (name) => {
    const safeName = asString(name);
    if (!safeName) return "";
    const key = safeName.toLowerCase();
    if (rinkKeyToId.has(key)) return rinkKeyToId.get(key);
    const rink = normalizeRink({ name: safeName });
    rinks.push(rink);
    rinkKeyToId.set(key, rink.id);
    return rink.id;
  };
  const sheetKeyToId = new Map();
  sheets.forEach((sheet) => {
    if (!sheet.rinkId || !sheet.label) return;
    sheetKeyToId.set(`${sheet.rinkId}::${sheet.label.toLowerCase()}`, sheet.id);
  });
  const ensureSheet = (rinkId, label) => {
    const safeLabel = asString(label);
    if (!rinkId || !safeLabel) return "";
    const key = `${rinkId}::${safeLabel.toLowerCase()}`;
    if (sheetKeyToId.has(key)) return sheetKeyToId.get(key);
    const sheet = normalizeSheet({ rinkId, label: safeLabel });
    sheets.push(sheet);
    sheetKeyToId.set(key, sheet.id);
    return sheet.id;
  };
  events.forEach((item) => {
    if (!item.rinkId && item.rink) item.rinkId = ensureRink(item.rink);
    if (!item.sheetId && item.sheet && item.rinkId) item.sheetId = ensureSheet(item.rinkId, item.sheet);
  });
  games.forEach((item) => {
    if (!item.rinkId && item.rink) item.rinkId = ensureRink(item.rink);
  });
  ice.forEach((item) => {
    if (!item.rinkId && item.rink) item.rinkId = ensureRink(item.rink);
    if (!item.sheetId && item.sheet && item.rinkId) item.sheetId = ensureSheet(item.rinkId, item.sheet);
  });
  plannerEntries.forEach((item) => {
    if (!item.rinkId && item.rink) item.rinkId = ensureRink(item.rink);
    if (!item.sheetId && item.sheet && item.rinkId) item.sheetId = ensureSheet(item.rinkId, item.sheet);
  });
}

function backfillLinkedRecords(events, games, practice, ice, plannerEntries) {
  const byDate = new Map();
  events.forEach((event) => {
    const list = byDate.get(event.date) || [];
    list.push(event);
    byDate.set(event.date, list);
  });
  const findEventMatch = (candidate) => {
    const matches = (byDate.get(candidate.date) || []).slice().sort(compareDateTime);
    if (!matches.length) return null;
    const rink = asString(candidate.rink).toLowerCase();
    const opponent = asString(candidate.opponent).toLowerCase();
    const sheet = asString(candidate.sheet).toLowerCase();
    const exact = matches.find((event) => {
      const rinkMatch = rink && asString(event.rink).toLowerCase() === rink;
      const oppMatch = opponent && [event.opponent, event.title].map((value) => asString(value).toLowerCase()).includes(opponent);
      const sheetMatch = sheet && asString(event.sheet).toLowerCase() === sheet;
      return (rinkMatch && oppMatch) || (rinkMatch && sheetMatch) || oppMatch;
    });
    return exact || matches[0];
  };
  games.forEach((game) => {
    if (!game.eventId) game.eventId = findEventMatch(game)?.id || "";
  });
  practice.forEach((entry) => {
    if (!entry.eventId) entry.eventId = findEventMatch(entry)?.id || "";
  });
  ice.forEach((entry) => {
    if (!entry.eventId) entry.eventId = findEventMatch(entry)?.id || "";
  });
  plannerEntries.forEach((entry) => {
    const linked = entry.eventId ? events.find((event) => event.id === entry.eventId) : findEventMatch(entry);
    if (linked) {
      entry.eventId = linked.id;
      if (!entry.rinkId) entry.rinkId = linked.rinkId;
      if (!entry.rink) entry.rink = linked.rink;
      if (!entry.sheetId) entry.sheetId = linked.sheetId;
      if (!entry.sheet) entry.sheet = linked.sheet;
      if (!entry.opponent) entry.opponent = linked.opponent || linked.title;
      if (!entry.position) entry.position = linked.position;
      if (!entry.time) entry.time = linked.time;
    }
  });
}

function hydrateRinkConditionEntries(ice, rinkConditionEntries) {
  if (rinkConditionEntries.length) return;
  ice.forEach((entry) => {
    if (!entry.rinkId && !entry.rink) return;
    rinkConditionEntries.push(normalizeRinkConditionEntry({
      sourceIceId: entry.id,
      eventId: entry.eventId,
      rinkId: entry.rinkId,
      sheetId: entry.sheetId,
      date: entry.date,
      speed: entry.speed,
      curl: entry.curl,
      frostLevel: entry.frostLevel,
      pebbleFeel: entry.pebbleFeel,
      hackCondition: entry.hackCondition,
      confidence: entry.confidence,
      notes: entry.notes
    }));
  });
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
    calendarFilter: "all",
    gameSort: "newest",
    practiceSort: "newest",
    iceSort: "newest",
    lastExportAt: "",
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
  const scalarFields = [
    entry.time,
    entry.rink,
    entry.opponent,
    entry.position,
    entry.goalOne,
    entry.goalTwo,
    entry.goalThree,
    entry.goals,
    entry.scoreUs,
    entry.scoreThem,
    entry.ice,
    entry.drawRating,
    entry.takeoutRating,
    entry.communicationRating,
    entry.sweepingRating,
    entry.mentalRating,
    entry.keyTakeaways,
    entry.nextFocus,
    entry.reflection,
    entry.keyShot
  ];
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
