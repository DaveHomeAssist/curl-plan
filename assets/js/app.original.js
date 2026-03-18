// Rollback-only monolith snapshot. Not loaded by index.html.
    const STORAGE_KEY = "curlplan-v1";
    const SCHEMA_VERSION = 3;
    const CHECKLIST_DEFAULTS_KEY = "cp_checklist_defaults";
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
    let currentView = "dashboard";
    let currentFilter = "all";
    let selectedEventId = state.events[0] ? state.events[0].id : null;
    let plannerDate = todayStr();
    let currentSpeed = 0;
    let currentSeasonRange = "season";
    let plannerChecklist = [];
    let modalState = { event: null, game: null, practice: null, ice: null, issue: null };

    const searchInput = document.getElementById("searchInput");
    const filterType = document.getElementById("filterType");
    const statusBar = document.getElementById("statusBar");
    const plannerSnapshot = document.getElementById("plannerSnapshot");
    const speedLabel = document.getElementById("speedLabel");

    function createId() {
      if (window.crypto && typeof window.crypto.randomUUID === "function") {
        return window.crypto.randomUUID();
      }
      return `cp-${Date.now()}-${Math.random().toString(16).slice(2)}`;
    }

    function clone(value) {
      if (typeof structuredClone === "function") return structuredClone(value);
      return JSON.parse(JSON.stringify(value));
    }

    function todayStr() {
      const date = new Date();
      const year = date.getFullYear();
      const month = String(date.getMonth() + 1).padStart(2, "0");
      const day = String(date.getDate()).padStart(2, "0");
      return `${year}-${month}-${day}`;
    }

    function fmtDate(dateStr, withWeekday = true) {
      if (!dateStr) return "No date";
      const date = new Date(`${dateStr}T00:00:00`);
      return date.toLocaleDateString(undefined, withWeekday
        ? { weekday: "short", month: "short", day: "numeric", year: "numeric" }
        : { month: "short", day: "numeric", year: "numeric" });
    }

    function fmtDateShort(dateStr) {
      const date = new Date(`${dateStr}T00:00:00`);
      return {
        day: date.getDate(),
        mon: date.toLocaleDateString(undefined, { month: "short" })
      };
    }

    function fmtTime(value) {
      if (!value) return "";
      const [hours, minutes] = value.split(":");
      const hourNum = Number(hours);
      const suffix = hourNum >= 12 ? "PM" : "AM";
      const displayHour = hourNum % 12 || 12;
      return `${displayHour}:${minutes} ${suffix}`;
    }

    function compareDateTime(a, b) {
      return `${a.date} ${a.time || ""}`.localeCompare(`${b.date} ${b.time || ""}`);
    }

    function escapeHtml(value) {
      return String(value ?? "")
        .replaceAll("&", "&amp;")
        .replaceAll("<", "&lt;")
        .replaceAll(">", "&gt;")
        .replaceAll('"', "&quot;")
        .replaceAll("'", "&#39;");
    }

    function asString(value) {
      return typeof value === "string" ? value.trim() : "";
    }

    function normalizeType(value) {
      const type = asString(value).toLowerCase();
      return ["league", "game", "practice", "bonspiel", "other"].includes(type) ? type : "other";
    }

    function normalizePosition(value) {
      const position = asString(value);
      return ["Lead", "Second", "Third", "Skip"].includes(position) ? position : "";
    }

    function normalizeSpeed(value) {
      if (typeof value === "number" && value >= 0 && value <= 5) return value;
      const text = asString(value).toLowerCase();
      const map = {
        "very slow": 1,
        slow: 2,
        medium: 3,
        "medium-fast": 4,
        fast: 4,
        "very fast": 5
      };
      return map[text] || 0;
    }

    function speedText(value) {
      return ["No speed selected", "Very Slow", "Slow", "Medium", "Fast", "Very Fast"][value] || "No speed selected";
    }

    function normalizeChecklistItems(items) {
      if (!Array.isArray(items)) return [];
      return items
        .map(item => {
          if (typeof item === "string") {
            const text = asString(item);
            return text ? { text, checked: false } : null;
          }
          if (!item || typeof item !== "object") return null;
          const text = asString(item.text || item.label || item.value);
          if (!text) return null;
          return { text, checked: Boolean(item.checked) };
        })
        .filter(Boolean);
    }

    function cloneChecklist(items) {
      return normalizeChecklistItems(items).map(item => ({ text: item.text, checked: item.checked }));
    }

    function stripChecklistChecks(items) {
      return normalizeChecklistItems(items).map(item => ({ text: item.text, checked: false }));
    }

    function parseLegacyResult(resultText) {
      const text = asString(resultText);
      const match = text.match(/^([WLD])\s*(\d+)\s*[-–]\s*(\d+)$/i);
      if (!match) {
        return {
          us: "",
          them: "",
          result: text.startsWith("L") ? "L" : text.startsWith("D") ? "D" : text ? "W" : ""
        };
      }
      return {
        result: match[1].toUpperCase(),
        us: Number(match[2]),
        them: Number(match[3])
      };
    }

    function computeResult(us, them, fallback = "") {
      if (us === "" || them === "") return fallback;
      if (Number(us) > Number(them)) return "W";
      if (Number(us) < Number(them)) return "L";
      return "D";
    }

    function normalizeWholeNumber(value) {
      if (value === "") return "";
      const num = Number(value);
      if (!Number.isFinite(num)) return "";
      return Math.max(0, Math.round(num));
    }

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

    function pulseElement(element, className = "tap-pop", duration = 180) {
      if (!element) return;
      element.classList.remove(className);
      void element.offsetWidth;
      element.classList.add(className);
      window.setTimeout(() => element.classList.remove(className), duration);
    }

    function markWorking(element, duration = 360) {
      if (!element || !element.classList.contains("btn")) return;
      element.classList.add("is-working");
      window.clearTimeout(element._workingTimer);
      element._workingTimer = window.setTimeout(() => {
        element.classList.remove("is-working");
      }, duration);
    }

    function animateView(name) {
      pulseElement(document.getElementById(`view-${name}`), "view-enter", 320);
    }

    function focusFirstField(modalId) {
      const overlay = document.getElementById(modalId);
      if (!overlay) return;
      window.setTimeout(() => {
        const target = overlay.querySelector("input, select, textarea");
        if (target) target.focus();
      }, 50);
    }

    let activeFocusTrap = null;

    function trapFocus(overlay) {
      releaseFocusTrap();
      const handler = (event) => {
        if (event.key !== "Tab") return;
        const focusable = overlay.querySelectorAll('button, input, select, textarea, [tabindex]:not([tabindex="-1"])');
        if (!focusable.length) return;
        const first = focusable[0];
        const last = focusable[focusable.length - 1];
        if (event.shiftKey && document.activeElement === first) {
          event.preventDefault();
          last.focus();
        } else if (!event.shiftKey && document.activeElement === last) {
          event.preventDefault();
          first.focus();
        }
      };
      overlay.addEventListener("keydown", handler);
      activeFocusTrap = { overlay, handler };
    }

    function releaseFocusTrap() {
      if (!activeFocusTrap) return;
      activeFocusTrap.overlay.removeEventListener("keydown", activeFocusTrap.handler);
      activeFocusTrap = null;
    }

    function setStatus(message = "", tone = "") {
      statusBar.textContent = message;
      statusBar.className = `status-bar${tone ? ` ${tone}` : ""}`;
      pulseElement(statusBar, "is-pulsing", 260);
    }

    function showToast(message) {
      const toast = document.createElement("div");
      toast.className = "toast";
      toast.textContent = message;
      document.body.appendChild(toast);
      window.setTimeout(() => {
        toast.classList.add("toast-out");
        toast.addEventListener("animationend", () => toast.remove(), { once: true });
      }, 1800);
    }

    function buildSparkline(values, width = 220, height = 48, className = "sparkline-line") {
      const nums = values.filter(value => Number.isFinite(Number(value))).map(Number);
      if (!nums.length) {
        return `<svg class="sparkline" viewBox="0 0 ${width} ${height}" role="img" aria-hidden="true"><line class="sparkline-track" x1="0" y1="${height - 2}" x2="${width}" y2="${height - 2}"></line></svg>`;
      }
      if (nums.length === 1) {
        const y = height / 2;
        return `<svg class="sparkline" viewBox="0 0 ${width} ${height}" role="img" aria-hidden="true"><line class="sparkline-track" x1="0" y1="${height - 2}" x2="${width}" y2="${height - 2}"></line><line class="${className}" x1="12" y1="${y}" x2="${width - 12}" y2="${y}"></line><circle class="sparkline-point" cx="${width / 2}" cy="${y}" r="3"></circle></svg>`;
      }
      const min = Math.min(...nums);
      const max = Math.max(...nums);
      const spread = max - min || 1;
      const stepX = (width - 16) / (nums.length - 1);
      const points = nums.map((value, index) => {
        const x = 8 + stepX * index;
        const y = 6 + ((max - value) / spread) * (height - 14);
        return `${x.toFixed(1)},${y.toFixed(1)}`;
      });
      const lastPoint = points[points.length - 1].split(",");
      return `
        <svg class="sparkline" viewBox="0 0 ${width} ${height}" role="img" aria-hidden="true">
          <line class="sparkline-track" x1="0" y1="${height - 2}" x2="${width}" y2="${height - 2}"></line>
          <polyline class="${className}" points="${points.join(" ")}"></polyline>
          <circle class="sparkline-point" cx="${lastPoint[0]}" cy="${lastPoint[1]}" r="3"></circle>
        </svg>
      `;
    }

    function buildTrendSVG(games, key, width = 220, height = 54) {
      const values = games
        .map(game => Number(game?.[key]))
        .filter(value => Number.isFinite(value) && value > 0);
      return buildSparkline(values, width, height, "sparkline-line");
    }

    function getGamesForRange(range) {
      const ascending = state.games.slice().sort((a, b) => a.date.localeCompare(b.date));
      if (range === "all") return ascending;
      if (range === "last10") return ascending.slice(-10);
      const seasonYear = todayStr().slice(0, 4);
      return ascending.filter(game => game.date.startsWith(seasonYear));
    }

    function getRangeLabel(range, items) {
      if (range === "all") return "All logged games";
      if (range === "last10") return `${items.length} most recent game${items.length === 1 ? "" : "s"}`;
      return `Current calendar year (${todayStr().slice(0, 4)})`;
    }

    function calculateSeasonStats(items) {
      const games = items.slice().sort((a, b) => a.date.localeCompare(b.date));
      const completed = games.filter(item => item.result);
      const wins = completed.filter(item => item.result === "W").length;
      const losses = completed.filter(item => item.result === "L").length;
      const draws = completed.filter(item => item.result === "D").length;
      const scoredGames = games.filter(item => item.us !== "" && item.them !== "");
      const diffs = scoredGames.map(item => Number(item.us) - Number(item.them));
      const avgDiff = diffs.length ? (diffs.reduce((sum, diff) => sum + diff, 0) / diffs.length) : null;
      let streak = 0;
      let longestStreak = 0;
      games.forEach(item => {
        if (item.result === "W") {
          streak += 1;
          longestStreak = Math.max(longestStreak, streak);
        } else {
          streak = 0;
        }
      });

      const byPosition = {};
      const byRink = {};
      completed.forEach(item => {
        const position = item.position || "Unknown";
        const rink = item.rink || "Unknown Rink";
        if (!byPosition[position]) byPosition[position] = { wins: 0, losses: 0, draws: 0, total: 0 };
        if (!byRink[rink]) byRink[rink] = { wins: 0, losses: 0, draws: 0, total: 0 };
        byPosition[position].total += 1;
        byRink[rink].total += 1;
        if (item.result === "W") {
          byPosition[position].wins += 1;
          byRink[rink].wins += 1;
        } else if (item.result === "L") {
          byPosition[position].losses += 1;
          byRink[rink].losses += 1;
        } else if (item.result === "D") {
          byPosition[position].draws += 1;
          byRink[rink].draws += 1;
        }
      });

      const positionSummary = Object.entries(byPosition)
        .map(([name, record]) => ({
          name,
          ...record,
          winPct: record.total ? Math.round((record.wins / record.total) * 100) : 0
        }))
        .sort((a, b) => b.winPct - a.winPct || b.total - a.total);

      const rinkSummary = Object.entries(byRink)
        .map(([name, record]) => ({
          name,
          ...record,
          winPct: record.total ? Math.round((record.wins / record.total) * 100) : 0
        }))
        .sort((a, b) => b.total - a.total || b.winPct - a.winPct);

      return {
        wins,
        losses,
        draws,
        avgDiff,
        longestStreak,
        positionSummary,
        rinkSummary,
        diffSpark: diffs,
        shotTrendGames: games.filter(item => Number(item.shotPct) > 0).slice(-10),
        gameCount: games.length
      };
    }

    function renderSeasonStats() {
      const target = document.getElementById("seasonStatsGrid");
      const games = getGamesForRange(currentSeasonRange);
      const rangeLabel = document.getElementById("seasonRangeLabel");
      document.querySelectorAll("[data-season-range]").forEach(button => {
        button.classList.toggle("active", button.dataset.seasonRange === currentSeasonRange);
      });
      if (rangeLabel) rangeLabel.textContent = getRangeLabel(currentSeasonRange, games);

      if (!games.length) {
        target.innerHTML = renderEmpty("📈", "No games in this range yet.");
        return;
      }

      const stats = calculateSeasonStats(games);
      const positionBest = stats.positionSummary[0];
      const topRink = stats.rinkSummary[0];
      const recordValues = [stats.wins, stats.losses, stats.draws];
      const positionValues = stats.positionSummary.map(item => item.winPct);
      const rinkValues = stats.rinkSummary.slice(0, 4).map(item => item.winPct);
      const streakValues = games.map(item => item.result === "W" ? 100 : item.result === "D" ? 50 : 0);
      const shotTrendMarkup = stats.shotTrendGames.length >= 2
        ? buildTrendSVG(stats.shotTrendGames, "shotPct", 220, 54)
        : '<div class="insight-meta">Log at least two shot percentages to draw the trend.</div>';

      target.innerHTML = `
        <div class="insight-card">
          <div class="insight-kicker">Record</div>
          <div class="insight-value">${stats.wins}-${stats.losses}-${stats.draws}</div>
          <div class="insight-meta">${escapeHtml(getRangeLabel(currentSeasonRange, games))}</div>
          ${buildSparkline(recordValues, 220, 44, "sparkline-soft")}
        </div>
        <div class="insight-card">
          <div class="insight-kicker">Best Position</div>
          <div class="insight-value">${escapeHtml(positionBest ? `${positionBest.winPct}%` : "—")}</div>
          <div class="insight-meta">${escapeHtml(positionBest ? `${positionBest.name} • ${positionBest.wins}-${positionBest.losses}-${positionBest.draws}` : "Not enough position data yet.")}</div>
          ${positionValues.length ? buildSparkline(positionValues, 220, 44, "sparkline-soft") : '<div class="insight-meta">No position-tagged games in this range.</div>'}
        </div>
        <div class="insight-card">
          <div class="insight-kicker">Avg Score Differential</div>
          <div class="insight-value">${stats.avgDiff === null ? "—" : `${stats.avgDiff > 0 ? "+" : ""}${stats.avgDiff.toFixed(1)}`}</div>
          <div class="insight-meta">${escapeHtml(stats.avgDiff === null ? "No scored games in this range." : "Average points above or below opponent.")}</div>
          ${stats.diffSpark.length ? buildSparkline(stats.diffSpark, 220, 44, "sparkline-soft") : '<div class="insight-meta">Score both sides to unlock this card.</div>'}
        </div>
        <div class="insight-card">
          <div class="insight-kicker">Longest Win Streak</div>
          <div class="insight-value">${escapeHtml(String(stats.longestStreak || 0))}</div>
          <div class="insight-meta">${escapeHtml(stats.longestStreak ? `Best run across ${stats.gameCount} game${stats.gameCount === 1 ? "" : "s"}.` : "No winning streak in this range yet.")}</div>
          ${buildSparkline(streakValues, 220, 44, "sparkline-soft")}
        </div>
        <div class="insight-card">
          <div class="insight-kicker">Top Rink Split</div>
          <div class="insight-value">${escapeHtml(topRink ? `${topRink.winPct}%` : "—")}</div>
          <div class="insight-meta">${escapeHtml(topRink ? `${topRink.name} • ${topRink.wins}-${topRink.losses}-${topRink.draws}` : "No rink-tagged games yet.")}</div>
          ${rinkValues.length ? buildSparkline(rinkValues, 220, 44, "sparkline-soft") : '<div class="insight-meta">Save rink names to compare performance by club.</div>'}
        </div>
        <div class="insight-card">
          <div class="insight-kicker">Shot % Trend</div>
          <div class="insight-value">${escapeHtml(stats.shotTrendGames.length ? `${Math.round(stats.shotTrendGames.reduce((sum, item) => sum + Number(item.shotPct), 0) / stats.shotTrendGames.length)}%` : "—")}</div>
          <div class="insight-meta">${escapeHtml(stats.shotTrendGames.length ? `Last ${stats.shotTrendGames.length} logged shot percentage${stats.shotTrendGames.length === 1 ? "" : "s"}.` : "Shot percentage is optional until you want trend tracking.")}</div>
          ${shotTrendMarkup}
        </div>
      `;
    }

    function renderPlannerChecklist() {
      const target = document.getElementById("plannerChecklist");
      if (!target) return;
      target.innerHTML = plannerChecklist.length
        ? plannerChecklist.map((item, index) => `
          <div class="checklist-item${item.checked ? " is-checked" : ""}">
            <input type="checkbox" ${item.checked ? "checked" : ""} data-action="planner-check-toggle" data-index="${index}" aria-label="Toggle checklist item ${escapeHtml(item.text)}" />
            <div class="checklist-copy">${escapeHtml(item.text)}</div>
            <div class="checklist-actions">
              <button type="button" class="btn btn-ghost btn-sm" data-action="planner-check-move" data-direction="-1" data-index="${index}" ${index === 0 ? "disabled" : ""}>↑</button>
              <button type="button" class="btn btn-ghost btn-sm" data-action="planner-check-move" data-direction="1" data-index="${index}" ${index === plannerChecklist.length - 1 ? "disabled" : ""}>↓</button>
              <button type="button" class="btn btn-danger btn-sm" data-action="planner-check-remove" data-index="${index}">Remove</button>
            </div>
          </div>
        `).join("")
        : '<div class="planner-checklist-empty">No checklist items yet. Add one below or reset to defaults.</div>';
    }

    function getUpcomingEvents() {
      const today = todayStr();
      return state.events.filter(item => item.date >= today).slice().sort(compareDateTime);
    }

    function getFilteredEvents() {
      const query = asString(searchInput.value).toLowerCase();
      return state.events
        .filter(item => currentFilter === "all" || item.type === currentFilter)
        .filter(item => {
          if (!query) return true;
          return [item.title, item.rink, item.team, item.opponent, item.notes, item.position, item.sheet]
            .join(" ")
            .toLowerCase()
            .includes(query);
        })
        .slice()
        .sort(compareDateTime);
    }

    function positionClass(position) {
      return position ? `position-${position.toLowerCase()}` : "";
    }

    function resultClass(result) {
      return result ? `result-${result.toLowerCase()}` : "result-d";
    }

    function renderEmpty(icon, text, cta) {
      return `<div class="empty"><div class="empty-icon">${icon}</div><div>${escapeHtml(text)}</div>${cta ? `<button type="button" class="btn btn-ghost btn-sm empty-cta" data-open-modal="${cta.modal}">+ ${escapeHtml(cta.label)}</button>` : ""}</div>`;
    }

    function renderEventCard(item, selected = false) {
      const shortDate = fmtDateShort(item.date);
      return `
        <div class="event-item${selected ? " selected" : ""}" data-event-id="${escapeHtml(item.id)}">
          <div class="event-date-block">
            <div class="event-day">${shortDate.day}</div>
            <div class="event-mon">${escapeHtml(shortDate.mon)}</div>
          </div>
          <div class="event-info">
            <div class="event-title">${escapeHtml(item.title)}</div>
            <div class="event-meta">
              <span class="type-chip type-${escapeHtml(item.type)}">${escapeHtml(item.type)}</span>
              ${item.time ? `<span>${escapeHtml(fmtTime(item.time))}</span>` : ""}
              ${item.rink ? `<span>${escapeHtml(item.rink)}</span>` : ""}
              ${item.sheet ? `<span>Sheet ${escapeHtml(item.sheet)}</span>` : ""}
              ${item.position ? `<span class="position-badge ${positionClass(item.position)}">${escapeHtml(item.position)}</span>` : ""}
            </div>
            ${item.notes ? `<div class="event-notes">${escapeHtml(item.notes)}</div>` : ""}
            <div class="event-actions">
              <button type="button" class="btn btn-ghost btn-sm" data-action="select-event" data-id="${escapeHtml(item.id)}">View</button>
              <button type="button" class="btn btn-ghost btn-sm" data-open-modal="event" data-id="${escapeHtml(item.id)}">Edit</button>
            </div>
          </div>
        </div>
      `;
    }

    function renderEventList() {
      const target = document.getElementById("event-list");
      const items = getFilteredEvents();
      if (!items.length) {
        if (selectedEventId && !state.events.find(item => item.id === selectedEventId)) selectedEventId = null;
        target.innerHTML = renderEmpty("📅", "No events match the current filter.");
        renderSelectedEvent();
        return;
      }
      if (!selectedEventId || !state.events.find(item => item.id === selectedEventId)) {
        selectedEventId = items[0].id;
      }
      target.innerHTML = items.map(item => renderEventCard(item, item.id === selectedEventId)).join("");
      renderSelectedEvent();
    }

    function renderSelectedEvent() {
      const target = document.getElementById("eventDetail");
      const item = state.events.find(entry => entry.id === selectedEventId);
      if (!item) {
        target.className = "empty";
        target.innerHTML = '<div class="empty-icon">📅</div><div>Select an event to inspect details.</div>';
        return;
      }
      target.className = "stack";
      target.innerHTML = `
        <div class="card-sm">
          <div class="card-head">
            <div>
              <div class="pill-row">
                <span class="type-chip type-${escapeHtml(item.type)}">${escapeHtml(item.type)}</span>
                ${item.position ? `<span class="position-badge ${positionClass(item.position)}">${escapeHtml(item.position)}</span>` : ""}
              </div>
              <h3 class="card-title" style="margin-top:10px;">${escapeHtml(item.title)}</h3>
            </div>
            <div class="inline-actions">
              <button type="button" class="btn btn-ghost btn-sm" data-open-modal="event" data-id="${escapeHtml(item.id)}">Edit</button>
              <button type="button" class="btn btn-danger btn-sm" data-action="delete-entry" data-type="event" data-id="${escapeHtml(item.id)}">Delete</button>
            </div>
          </div>
          <div class="stack">
            <div><strong>Date:</strong> ${escapeHtml(fmtDate(item.date))}${item.time ? ` at ${escapeHtml(fmtTime(item.time))}` : ""}</div>
            <div><strong>Rink:</strong> ${escapeHtml(item.rink || "—")}</div>
            <div><strong>Team:</strong> ${escapeHtml(item.team || "—")}</div>
            <div><strong>Opponent:</strong> ${escapeHtml(item.opponent || "—")}</div>
            <div><strong>Sheet:</strong> ${escapeHtml(item.sheet || "—")}</div>
            <div><strong>Notes:</strong> ${escapeHtml(item.notes || "—")}</div>
          </div>
        </div>
      `;
    }

    function renderDashboard() {
      const wins = state.games.filter(item => item.result === "W").length;
      const upcoming = getUpcomingEvents();
      document.getElementById("stat-games").textContent = state.games.length;
      document.getElementById("stat-wins").textContent = wins;
      document.getElementById("stat-upcoming").textContent = upcoming.length;
      renderSeasonStats();

      document.getElementById("dash-upcoming").innerHTML = upcoming.length
        ? upcoming.slice(0, 3).map(item => renderEventCard(item)).join("")
        : renderEmpty("📅", "No upcoming events.", { modal: "event", label: "Add Event" });

      const plannerKeys = Object.keys(state.plannerEntries).sort();
      const activePlannerKey = plannerKeys.find(key => key >= todayStr()) || plannerKeys[plannerKeys.length - 1];
      const plannerEntry = activePlannerKey ? state.plannerEntries[activePlannerKey] : null;
      plannerSnapshot.innerHTML = plannerEntry
        ? `
          <div class="card-sm">
            <div class="pill-row">
              <span class="badge mono">${escapeHtml(fmtDate(activePlannerKey))}</span>
              ${plannerEntry.position ? `<span class="position-badge ${positionClass(plannerEntry.position)}">${escapeHtml(plannerEntry.position)}</span>` : ""}
            </div>
            <h3 class="card-title" style="margin-top:10px;">${escapeHtml(plannerEntry.opponent || "No opponent set")}</h3>
            <div class="muted">${plannerEntry.time ? escapeHtml(fmtTime(plannerEntry.time)) : "No time set"}${plannerEntry.rink ? ` • ${escapeHtml(plannerEntry.rink)}` : ""}</div>
            <div class="event-notes" style="margin-top:10px;">${escapeHtml(plannerEntry.goals || "No goals entered yet.")}</div>
            ${plannerEntry.checklist && plannerEntry.checklist.some(item => item.checked) ? `<div class="muted" style="margin-top:8px;">Checklist complete: ${escapeHtml(String(plannerEntry.checklist.filter(item => item.checked).length))}/${escapeHtml(String(plannerEntry.checklist.length))}</div>` : ""}
          </div>
        `
        : renderEmpty("📝", "No planner entries saved yet.");

      document.getElementById("dash-games").innerHTML = state.games.length
        ? state.games.slice().sort((a, b) => b.date.localeCompare(a.date)).slice(0, 3).map(item => `
          <div class="card-sm">
            <div class="card-head">
              <div>
                <h3 class="card-title">vs ${escapeHtml(item.opponent || "Unknown Opponent")}</h3>
                <div class="muted">${escapeHtml(fmtDate(item.date))}</div>
              </div>
              <div class="pill-row">
                ${(item.us !== "" && item.them !== "") ? `<span class="score-pill">${escapeHtml(String(item.us))}-${escapeHtml(String(item.them))}</span>` : ""}
                ${item.result ? `<span class="result-badge ${resultClass(item.result)}">${escapeHtml(item.result)}</span>` : ""}
              </div>
            </div>
            <div class="event-notes">${escapeHtml(item.notes || item.keyShot || "No notes saved.")}</div>
          </div>
        `).join("")
        : renderEmpty("🥌", "No games logged yet.", { modal: "game", label: "Log Game" });

      const latestIce = state.ice.slice().sort((a, b) => b.date.localeCompare(a.date))[0];
      document.getElementById("dash-ice").innerHTML = latestIce
        ? `
          <div class="card-sm">
            <div class="card-head">
              <div>
                <h3 class="card-title">${escapeHtml(latestIce.rink || "Unknown Rink")}</h3>
                <div class="muted">${escapeHtml(fmtDate(latestIce.date))}</div>
              </div>
              <div class="pill-row">
                <span class="badge mono">${escapeHtml(speedText(latestIce.speed))}</span>
                ${latestIce.curl ? `<span class="type-chip type-other">${escapeHtml(latestIce.curl)}</span>` : ""}
              </div>
            </div>
            <div class="event-notes">${escapeHtml(latestIce.notes || "No note text saved.")}</div>
          </div>
        `
        : renderEmpty("🧊", "No ice notes saved yet.", { modal: "ice", label: "Add Ice Notes" });
    }

    function renderGames() {
      const tbody = document.getElementById("game-tbody");
      const empty = document.getElementById("games-empty");
      const items = state.games.slice().sort((a, b) => b.date.localeCompare(a.date));
      if (!items.length) {
        tbody.innerHTML = "";
        empty.classList.remove("hidden");
      } else {
        empty.classList.add("hidden");
        tbody.innerHTML = items.map(item => `
          <tr>
            <td class="mono">${escapeHtml(fmtDate(item.date))}</td>
            <td><strong>${escapeHtml(item.opponent || "Unknown Opponent")}</strong><br /><span class="muted">${escapeHtml(item.rink || "No rink saved")}</span></td>
            <td>${(item.us !== "" && item.them !== "") ? `<span class="score-pill">${escapeHtml(String(item.us))}-${escapeHtml(String(item.them))}</span>` : '<span class="muted">—</span>'}</td>
            <td>${item.shotPct !== "" ? `<span class="badge mono">${escapeHtml(String(item.shotPct))}%</span>` : '<span class="muted">—</span>'}</td>
            <td>${item.result ? `<span class="result-badge ${resultClass(item.result)}">${escapeHtml(item.result)}</span>` : '<span class="muted">—</span>'}</td>
            <td>${item.position ? `<span class="position-badge ${positionClass(item.position)}">${escapeHtml(item.position)}</span>` : '<span class="muted">—</span>'}</td>
            <td>${escapeHtml(item.notes || item.keyShot || "—")}</td>
            <td>
              <div class="table-actions report-actions">
                <button type="button" class="btn btn-ghost btn-sm" data-action="print-game-report" data-id="${escapeHtml(item.id)}">Print</button>
                <button type="button" class="btn btn-ghost btn-sm" data-open-modal="game" data-id="${escapeHtml(item.id)}">Edit</button>
                <button type="button" class="btn btn-danger btn-sm" data-action="delete-entry" data-type="game" data-id="${escapeHtml(item.id)}">Delete</button>
              </div>
            </td>
          </tr>
        `).join("");
      }

      const shotGames = items.filter(item => Number(item.shotPct) > 0).slice().sort((a, b) => a.date.localeCompare(b.date)).slice(-10);
      const avgShot = shotGames.length ? Math.round(shotGames.reduce((sum, item) => sum + Number(item.shotPct), 0) / shotGames.length) : 0;
      const wins = items.filter(item => item.result === "W").length;
      const losses = items.filter(item => item.result === "L").length;
      document.getElementById("gameStats").innerHTML = `
        <div class="summary-row"><div class="summary-name">Avg shot %</div><div class="summary-count">${avgShot || 0}%</div></div>
        <div class="summary-row"><div class="summary-name">Wins logged</div><div class="summary-count">${wins}</div></div>
        <div class="summary-row"><div class="summary-name">Losses logged</div><div class="summary-count">${losses}</div></div>
        <div class="summary-row"><div class="summary-name">Games total</div><div class="summary-count">${items.length}</div></div>
        ${shotGames.length >= 2 ? `<div class="card-sm">${buildTrendSVG(shotGames, "shotPct", 260, 56)}<div class="muted">Last ${shotGames.length} logged shot percentages.</div></div>` : ""}
      `;
    }

    function renderPractice() {
      const list = document.getElementById("practice-list");
      const empty = document.getElementById("practice-empty");
      const items = state.practice.slice().sort((a, b) => b.date.localeCompare(a.date));
      if (!items.length) {
        list.innerHTML = "";
        empty.classList.remove("hidden");
      } else {
        empty.classList.add("hidden");
        list.innerHTML = items.map(item => `
          <div class="card-sm">
            <div class="card-head">
              <div>
                <h3 class="card-title">${escapeHtml(fmtDate(item.date))}</h3>
                <div class="muted">${escapeHtml(item.duration || "Duration not set")}</div>
              </div>
              <div class="inline-actions">
                <button type="button" class="btn btn-ghost btn-sm" data-open-modal="practice" data-id="${escapeHtml(item.id)}">Edit</button>
                <button type="button" class="btn btn-danger btn-sm" data-action="delete-entry" data-type="practice" data-id="${escapeHtml(item.id)}">Delete</button>
              </div>
            </div>
            <div class="pill-row">${(item.shots || []).map(shot => `<span class="type-chip type-practice">${escapeHtml(shot)}</span>`).join("")}</div>
            ${item.focus ? `<div class="event-notes" style="margin-top:10px;">${escapeHtml(item.focus)}</div>` : ""}
            ${item.notes ? `<div class="muted" style="margin-top:8px;">${escapeHtml(item.notes)}</div>` : ""}
          </div>
        `).join("");
      }

      const counts = {};
      items.forEach(item => (item.shots || []).forEach(shot => {
        counts[shot] = (counts[shot] || 0) + 1;
      }));
      const summary = Object.entries(counts).sort((a, b) => b[1] - a[1]);
      document.getElementById("practiceSummary").innerHTML = summary.length
        ? summary.map(([name, count]) => `
          <div class="summary-row">
            <div class="summary-name">${escapeHtml(name)}</div>
            <div class="summary-count">${count} session${count === 1 ? "" : "s"}</div>
          </div>
        `).join("")
        : renderEmpty("🎯", "No drill patterns yet.");
    }

    function renderIce() {
      const list = document.getElementById("ice-list");
      const empty = document.getElementById("ice-empty");
      const items = state.ice.slice().sort((a, b) => b.date.localeCompare(a.date));
      if (!items.length) {
        list.innerHTML = "";
        empty.classList.remove("hidden");
      } else {
        empty.classList.add("hidden");
        list.innerHTML = items.map(item => `
          <div class="card-sm">
            <div class="card-head">
              <div>
                <h3 class="card-title">${escapeHtml(item.rink || "Unknown Rink")}</h3>
                <div class="muted">${escapeHtml(fmtDate(item.date))}</div>
              </div>
              <div class="inline-actions">
                <button type="button" class="btn btn-ghost btn-sm" data-open-modal="ice" data-id="${escapeHtml(item.id)}">Edit</button>
                <button type="button" class="btn btn-danger btn-sm" data-action="delete-entry" data-type="ice" data-id="${escapeHtml(item.id)}">Delete</button>
              </div>
            </div>
            <div class="pill-row">
              <span class="badge mono">${escapeHtml(speedText(item.speed))}</span>
              ${item.curl ? `<span class="type-chip type-other">${escapeHtml(item.curl)}</span>` : ""}
            </div>
            ${item.notes ? `<div class="event-notes" style="margin-top:10px;">${escapeHtml(item.notes)}</div>` : ""}
          </div>
        `).join("");
      }

      const byRink = {};
      items.forEach(item => {
        const name = item.rink || "Unknown Rink";
        byRink[name] = (byRink[name] || 0) + 1;
      });
      const summary = Object.entries(byRink).sort((a, b) => b[1] - a[1]);
      document.getElementById("rinkSummary").innerHTML = summary.length
        ? summary.map(([name, count]) => `
          <div class="summary-row">
            <div class="summary-name">${escapeHtml(name)}</div>
            <div class="summary-count">${count} note${count === 1 ? "" : "s"}</div>
          </div>
        `).join("")
        : renderEmpty("🧊", "Start logging rink behavior to build memory.");
    }

    function severityClass(severity) {
      if (severity === "P1") return "result-l";
      if (severity === "P3") return "result-w";
      return "result-d";
    }

    function statusChipClass(status) {
      if (status === "resolved") return "type-practice";
      if (status === "deferred") return "type-other";
      if (status === "in-progress") return "type-bonspiel";
      return "type-chip";
    }

    function renderIssues() {
      const tbody = document.getElementById("issues-tbody");
      const empty = document.getElementById("issues-empty");
      const severityOrder = { P1: 0, P2: 1, P3: 2 };
      const items = state.issues.slice().sort((a, b) => (severityOrder[a.severity] ?? 9) - (severityOrder[b.severity] ?? 9));
      if (!items.length) {
        tbody.innerHTML = "";
        empty.classList.remove("hidden");
      } else {
        empty.classList.add("hidden");
        tbody.innerHTML = items.map(item => `
          <tr>
            <td class="mono">${escapeHtml(item.id)}</td>
            <td class="summary-name">${escapeHtml(item.component)}</td>
            <td class="event-notes">${escapeHtml(item.description)}</td>
            <td><span class="badge ${severityClass(item.severity)}">${escapeHtml(item.severity)}</span></td>
            <td><span class="${statusChipClass(item.status)}">${escapeHtml(item.status)}</span></td>
            <td class="event-notes">${escapeHtml(item.proposedFix)}</td>
            <td>
              <div class="inline-actions">
                <button type="button" class="btn btn-ghost btn-sm" data-open-modal="issue" data-id="${escapeHtml(item.id)}">Edit</button>
                <button type="button" class="btn btn-danger btn-sm" data-action="delete-entry" data-type="issue" data-id="${escapeHtml(item.id)}">Delete</button>
              </div>
            </td>
          </tr>
        `).join("");
      }

      const total = items.length;
      const p1 = items.filter(i => i.severity === "P1").length;
      const p2 = items.filter(i => i.severity === "P2").length;
      const p3 = items.filter(i => i.severity === "P3").length;
      const open = items.filter(i => i.status === "open").length;
      const inProgress = items.filter(i => i.status === "in-progress").length;
      const resolved = items.filter(i => i.status === "resolved").length;
      const deferred = items.filter(i => i.status === "deferred").length;
      document.getElementById("issueSummary").innerHTML = total
        ? `
          <div class="summary-row"><span class="summary-name">Total Issues</span><span class="badge result-d">${total}</span></div>
          ${p1 ? `<div class="summary-row"><span class="summary-name">P1 — Blocker</span><span class="badge result-l">${p1}</span></div>` : ""}
          ${p2 ? `<div class="summary-row"><span class="summary-name">P2 — Degraded</span><span class="badge result-d">${p2}</span></div>` : ""}
          ${p3 ? `<div class="summary-row"><span class="summary-name">P3 — Polish</span><span class="badge result-w">${p3}</span></div>` : ""}
          ${open ? `<div class="summary-row"><span class="summary-name">Open</span><span class="type-chip">${open}</span></div>` : ""}
          ${inProgress ? `<div class="summary-row"><span class="summary-name">In Progress</span><span class="type-chip">${inProgress}</span></div>` : ""}
          ${deferred ? `<div class="summary-row"><span class="summary-name">Deferred</span><span class="type-chip">${deferred}</span></div>` : ""}
          ${resolved ? `<div class="summary-row"><span class="summary-name">Resolved</span><span class="type-chip">${resolved}</span></div>` : ""}
        `
        : renderEmpty("🐛", "Add your first issue to start tracking.");
    }

    function renderPlannerEntries() {
      const target = document.getElementById("planner-entries");
      const entries = Object.entries(state.plannerEntries)
        .filter(([, entry]) => entry && Object.values(entry).some(Boolean))
        .sort((a, b) => b[0].localeCompare(a[0]));
      const filtered = entries.filter(([date]) => date !== plannerDate).slice(0, 6);
      target.innerHTML = filtered.length
        ? filtered.map(([date, entry]) => `
          <div class="card-sm planner-entry-card" data-action="planner-jump" data-date="${escapeHtml(date)}">
            <div class="card-head">
              <div>
                <h3 class="card-title">${escapeHtml(fmtDate(date))}</h3>
                <div class="muted">${escapeHtml(entry.opponent || "No opponent set")}</div>
              </div>
              ${entry.position ? `<span class="position-badge ${positionClass(entry.position)}">${escapeHtml(entry.position)}</span>` : ""}
            </div>
            ${(entry.scoreUs || entry.scoreThem) ? `<div class="score-pill">${escapeHtml(entry.scoreUs || "0")}-${escapeHtml(entry.scoreThem || "0")}</div>` : ""}
            ${entry.checklist && entry.checklist.length ? `<div class="muted" style="margin-top:8px;">Checklist ${escapeHtml(String(entry.checklist.filter(item => item.checked).length))}/${escapeHtml(String(entry.checklist.length))}</div>` : ""}
            ${entry.reflection ? `<div class="event-notes" style="margin-top:10px;">${escapeHtml(entry.reflection.slice(0, 120))}${entry.reflection.length > 120 ? "…" : ""}</div>` : ""}
          </div>
        `).join("")
        : renderEmpty("📝", "No other planner entries saved yet.");
    }

    function updatePlannerLabel() {
      document.getElementById("planner-label").textContent = fmtDate(plannerDate);
    }

    function loadPlanner() {
      const entry = state.plannerEntries[plannerDate] || {};
      document.getElementById("pg-time").value = entry.time || "";
      document.getElementById("pg-rink").value = entry.rink || "";
      document.getElementById("pg-opponent").value = entry.opponent || "";
      document.getElementById("pg-position").value = entry.position || "";
      document.getElementById("pg-goals").value = entry.goals || "";
      document.getElementById("pg-score-us").value = entry.scoreUs || "";
      document.getElementById("pg-score-them").value = entry.scoreThem || "";
      document.getElementById("pg-ice").value = entry.ice || "";
      document.getElementById("pg-reflection").value = entry.reflection || "";
      document.getElementById("pg-keyshot").value = entry.keyShot || "";
      plannerChecklist = entry.checklist && entry.checklist.length ? cloneChecklist(entry.checklist) : loadChecklistDefaults();
      renderPlannerChecklist();
    }

    function savePlanner() {
      const entry = {
        time: asString(document.getElementById("pg-time").value),
        rink: asString(document.getElementById("pg-rink").value),
        opponent: asString(document.getElementById("pg-opponent").value),
        position: normalizePosition(document.getElementById("pg-position").value),
        goals: asString(document.getElementById("pg-goals").value),
        scoreUs: asString(document.getElementById("pg-score-us").value),
        scoreThem: asString(document.getElementById("pg-score-them").value),
        ice: asString(document.getElementById("pg-ice").value),
        reflection: asString(document.getElementById("pg-reflection").value),
        keyShot: asString(document.getElementById("pg-keyshot").value),
        checklist: checklistHasMeaningfulState(plannerChecklist) ? cloneChecklist(plannerChecklist) : []
      };
      if (plannerEntryHasContent(entry)) state.plannerEntries[plannerDate] = entry;
      else delete state.plannerEntries[plannerDate];
      saveState();
      renderAll();
      setStatus("Planner saved.", "success");
      showToast("Planner saved");
    }

    function printGameReport(gameId) {
      const game = state.games.find(item => item.id === gameId);
      if (!game) {
        setStatus("Could not find that game to print.", "error");
        return;
      }
      const plannerEntry = state.plannerEntries[game.date] || null;
      const iceEntries = state.ice.filter(item => item.date === game.date);
      const checklistItems = plannerEntry && plannerEntry.checklist ? plannerEntry.checklist : [];
      const checklistDone = checklistItems.filter(item => item.checked).length;
      const report = document.getElementById("printReport");
      report.innerHTML = `
        <div class="report-sheet">
          <div class="report-header">
            <div>
              <div class="brand-kicker">CurlPlan Game Report</div>
              <div class="report-title">vs ${escapeHtml(game.opponent || "Unknown Opponent")}</div>
              <div class="report-subtitle">${escapeHtml(fmtDate(game.date))}${game.rink ? ` • ${escapeHtml(game.rink)}` : ""}${game.position ? ` • ${escapeHtml(game.position)}` : ""}${checklistItems.length ? ` • Checklist ${escapeHtml(String(checklistDone))}/${escapeHtml(String(checklistItems.length))}` : ""}</div>
            </div>
            <div class="report-block">
              <h3>Result</h3>
              <div class="report-metric">${game.us !== "" && game.them !== "" ? `${escapeHtml(String(game.us))}-${escapeHtml(String(game.them))}` : "—"}</div>
              <div class="report-subtitle">${escapeHtml(game.result || "No result logged")}${game.shotPct !== "" ? ` • Shot ${escapeHtml(String(game.shotPct))}%` : ""}</div>
            </div>
          </div>
          <div class="report-grid">
            <div class="report-block">
              <h3>Game Notes</h3>
              <div class="report-lines">
                <div><strong>Key Shot:</strong> ${escapeHtml(game.keyShot || "—")}</div>
                <div><strong>Notes:</strong></div>
                <div class="report-note">${escapeHtml(game.notes || "No game notes logged.")}</div>
              </div>
            </div>
            <div class="report-block">
              <h3>Planner Entry</h3>
              ${plannerEntry ? `
                <div class="report-lines">
                  <div><strong>Goals:</strong> ${escapeHtml(plannerEntry.goals || "—")}</div>
                  <div><strong>Ice Notes:</strong> ${escapeHtml(plannerEntry.ice || "—")}</div>
                  <div><strong>Reflection:</strong></div>
                  <div class="report-note">${escapeHtml(plannerEntry.reflection || "No post-game reflection logged.")}</div>
                </div>
              ` : '<div class="report-note">No planner entry saved for this date.</div>'}
            </div>
            <div class="report-block">
              <h3>Checklist</h3>
              ${plannerEntry && plannerEntry.checklist && plannerEntry.checklist.length ? `
                <div class="report-lines">
                  ${plannerEntry.checklist.map(item => `<div>${item.checked ? "✓" : "○"} ${escapeHtml(item.text)}</div>`).join("")}
                </div>
              ` : '<div class="report-note">No checklist state saved for this date.</div>'}
            </div>
            <div class="report-block">
              <h3>Ice Read</h3>
              ${iceEntries.length ? `
                <div class="report-lines">
                  ${iceEntries.map(item => `<div><strong>${escapeHtml(item.rink || "Unknown Rink")}</strong> • ${escapeHtml(speedText(item.speed))}${item.curl ? ` • ${escapeHtml(item.curl)}` : ""}</div><div class="report-note">${escapeHtml(item.notes || "No note text saved.")}</div>`).join("")}
                </div>
              ` : '<div class="report-note">No matching ice notes for this date.</div>'}
            </div>
          </div>
        </div>
      `;
      report.setAttribute("aria-hidden", "false");
      document.body.classList.add("printing-report");
      setStatus("Preparing game report for print.", "success");
      showToast("Preparing report");
      window.setTimeout(() => window.print(), 60);
    }

    function clearPrintReport() {
      const report = document.getElementById("printReport");
      report.innerHTML = "";
      report.setAttribute("aria-hidden", "true");
      document.body.classList.remove("printing-report");
    }

    function plannerNav(dir) {
      const date = new Date(`${plannerDate}T00:00:00`);
      date.setDate(date.getDate() + Number(dir));
      plannerDate = [date.getFullYear(), String(date.getMonth() + 1).padStart(2, "0"), String(date.getDate()).padStart(2, "0")].join("-");
      updatePlannerLabel();
      loadPlanner();
      renderPlannerEntries();
    }

    function setSpeed(value) {
      currentSpeed = Number(value);
      document.querySelectorAll(".speed-dot").forEach(dot => {
        dot.classList.toggle("active", Number(dot.dataset.speed) <= currentSpeed);
      });
      speedLabel.textContent = speedText(currentSpeed);
    }

    function showView(name) {
      currentView = name;
      document.querySelectorAll(".view").forEach(view => {
        view.classList.toggle("active", view.id === `view-${name}`);
      });
      document.querySelectorAll(".nav-btn").forEach(button => {
        const isActive = button.dataset.view === name;
        button.classList.toggle("active", isActive);
        button.setAttribute("aria-selected", isActive ? "true" : "false");
      });
      if (name === "planner") {
        updatePlannerLabel();
        loadPlanner();
      }
      if (window.location.hash !== `#${name}`) {
        window.history.replaceState(null, "", `#${name}`);
      }
      animateView(name);
    }

    function resetModal(type) {
      modalState[type] = null;
      if (type === "event") {
        document.getElementById("eventModalTitle").textContent = "Add Event";
        document.getElementById("ev-name").value = "";
        document.getElementById("ev-date").value = todayStr();
        document.getElementById("ev-time").value = "";
        document.getElementById("ev-type").value = "league";
        document.getElementById("ev-position").value = "";
        document.getElementById("ev-location").value = "";
        document.getElementById("ev-sheet").value = "";
        document.getElementById("ev-notes").value = "";
        document.getElementById("eventDeleteBtn").classList.add("hidden");
      }
      if (type === "game") {
        document.getElementById("gameModalTitle").textContent = "Log Game";
        document.getElementById("gm-date").value = todayStr();
        document.getElementById("gm-opponent").value = "";
        document.getElementById("gm-us").value = "";
        document.getElementById("gm-them").value = "";
        document.getElementById("gm-shotpct").value = "";
        document.getElementById("gm-position").value = "";
        document.getElementById("gm-rink").value = "";
        document.getElementById("gm-keyshot").value = "";
        document.getElementById("gm-notes").value = "";
        document.getElementById("gameDeleteBtn").classList.add("hidden");
      }
      if (type === "practice") {
        document.getElementById("practiceModalTitle").textContent = "Log Practice";
        document.getElementById("pr-date").value = todayStr();
        document.getElementById("pr-duration").value = "60 min";
        document.querySelectorAll(".pr-shot").forEach(input => input.checked = false);
        document.getElementById("pr-focus").value = "";
        document.getElementById("pr-notes").value = "";
        document.getElementById("practiceDeleteBtn").classList.add("hidden");
      }
      if (type === "ice") {
        document.getElementById("iceModalTitle").textContent = "Add Ice Notes";
        document.getElementById("ice-date").value = todayStr();
        document.getElementById("ice-rink").value = "";
        document.getElementById("ice-curl").value = "";
        document.getElementById("ice-notes-text").value = "";
        document.getElementById("iceDeleteBtn").classList.add("hidden");
        setSpeed(0);
      }
      if (type === "issue") {
        document.getElementById("issueModalTitle").textContent = "Add Issue";
        document.getElementById("is-component").value = "";
        document.getElementById("is-severity").value = "P2";
        document.getElementById("is-description").value = "";
        document.getElementById("is-status").value = "open";
        document.getElementById("is-fix").value = "";
        document.getElementById("issueDeleteBtn").classList.add("hidden");
      }
    }

    function openModal(type, id = "") {
      resetModal(type);
      const modalId = `modal-${type}`;
      const overlay = document.getElementById(modalId);
      const collectionName = type === "issue" ? "issues" : type === "ice" ? "ice" : type === "practice" ? "practice" : type === "game" ? "games" : "events";
      const item = id ? state[collectionName].find(entry => entry.id === id) : null;
      modalState[type] = item ? item.id : null;

      if (type === "event" && item) {
        document.getElementById("eventModalTitle").textContent = "Edit Event";
        document.getElementById("ev-name").value = item.title;
        document.getElementById("ev-date").value = item.date;
        document.getElementById("ev-time").value = item.time;
        document.getElementById("ev-type").value = item.type;
        document.getElementById("ev-position").value = item.position;
        document.getElementById("ev-location").value = item.rink;
        document.getElementById("ev-sheet").value = item.sheet;
        document.getElementById("ev-notes").value = item.notes;
        document.getElementById("eventDeleteBtn").classList.remove("hidden");
      }

      if (type === "game" && item) {
        document.getElementById("gameModalTitle").textContent = "Edit Game";
        document.getElementById("gm-date").value = item.date;
        document.getElementById("gm-opponent").value = item.opponent;
        document.getElementById("gm-us").value = item.us;
        document.getElementById("gm-them").value = item.them;
        document.getElementById("gm-shotpct").value = item.shotPct;
        document.getElementById("gm-position").value = item.position;
        document.getElementById("gm-rink").value = item.rink;
        document.getElementById("gm-keyshot").value = item.keyShot;
        document.getElementById("gm-notes").value = item.notes;
        document.getElementById("gameDeleteBtn").classList.remove("hidden");
      }

      if (type === "practice" && item) {
        document.getElementById("practiceModalTitle").textContent = "Edit Practice";
        document.getElementById("pr-date").value = item.date;
        document.getElementById("pr-duration").value = item.duration || "60 min";
        document.querySelectorAll(".pr-shot").forEach(input => {
          input.checked = (item.shots || []).includes(input.value);
        });
        document.getElementById("pr-focus").value = item.focus;
        document.getElementById("pr-notes").value = item.notes;
        document.getElementById("practiceDeleteBtn").classList.remove("hidden");
      }

      if (type === "ice" && item) {
        document.getElementById("iceModalTitle").textContent = "Edit Ice Notes";
        document.getElementById("ice-date").value = item.date;
        document.getElementById("ice-rink").value = item.rink;
        document.getElementById("ice-curl").value = item.curl;
        document.getElementById("ice-notes-text").value = item.notes;
        document.getElementById("iceDeleteBtn").classList.remove("hidden");
        setSpeed(item.speed);
      }

      if (type === "issue" && item) {
        document.getElementById("issueModalTitle").textContent = "Edit Issue";
        document.getElementById("is-component").value = item.component;
        document.getElementById("is-severity").value = item.severity;
        document.getElementById("is-description").value = item.description;
        document.getElementById("is-status").value = item.status;
        document.getElementById("is-fix").value = item.proposedFix;
        document.getElementById("issueDeleteBtn").classList.remove("hidden");
      }

      clearFieldErrors(modalId);
      overlay.classList.add("open");
      trapFocus(overlay);
      focusFirstField(modalId);
    }

    function closeModal(modalId) {
      const overlay = document.getElementById(modalId);
      if (overlay) overlay.classList.remove("open");
      releaseFocusTrap();
    }

    function upsertEntry(collectionName, entry) {
      const index = state[collectionName].findIndex(item => item.id === entry.id);
      if (index >= 0) state[collectionName][index] = entry;
      else state[collectionName].push(entry);
      saveState();
      renderAll();
    }

    function markFieldError(fieldId, message) {
      const field = document.getElementById(fieldId);
      if (!field) return;
      const row = field.closest(".form-row");
      if (!row) return;
      row.classList.add("has-error");
      const existing = row.querySelector(".field-error");
      if (existing) existing.remove();
      const hint = document.createElement("div");
      hint.className = "field-error";
      hint.textContent = message;
      row.appendChild(hint);
    }

    function clearFieldErrors(modalId) {
      const overlay = document.getElementById(modalId);
      if (!overlay) return;
      overlay.querySelectorAll(".has-error").forEach(row => row.classList.remove("has-error"));
      overlay.querySelectorAll(".field-error").forEach(el => el.remove());
    }

    function saveEvent() {
      clearFieldErrors("modal-event");
      const title = asString(document.getElementById("ev-name").value);
      const date = asString(document.getElementById("ev-date").value);
      if (!title || !date) {
        if (!title) markFieldError("ev-name", "Name is required");
        if (!date) markFieldError("ev-date", "Date is required");
        setStatus("Event name and date are required.", "error");
        return;
      }
      const existing = modalState.event ? state.events.find(item => item.id === modalState.event) : null;
      const entry = {
        id: modalState.event || createId(),
        title,
        type: normalizeType(document.getElementById("ev-type").value),
        date,
        time: asString(document.getElementById("ev-time").value),
        rink: asString(document.getElementById("ev-location").value),
        team: existing ? existing.team : "",
        opponent: existing ? existing.opponent : "",
        position: normalizePosition(document.getElementById("ev-position").value),
        sheet: asString(document.getElementById("ev-sheet").value),
        notes: asString(document.getElementById("ev-notes").value)
      };
      selectedEventId = entry.id;
      upsertEntry("events", entry);
      closeModal("modal-event");
      setStatus("Event saved.", "success");
      showToast("Event saved");
    }

    function saveGame() {
      clearFieldErrors("modal-game");
      const date = asString(document.getElementById("gm-date").value);
      const opponent = asString(document.getElementById("gm-opponent").value);
      if (!date || !opponent) {
        if (!date) markFieldError("gm-date", "Date is required");
        if (!opponent) markFieldError("gm-opponent", "Opponent is required");
        setStatus("Game date and opponent are required.", "error");
        return;
      }
      const existing = modalState.game ? state.games.find(item => item.id === modalState.game) : null;
      const usRaw = asString(document.getElementById("gm-us").value);
      const themRaw = asString(document.getElementById("gm-them").value);
      const shotPctRaw = asString(document.getElementById("gm-shotpct").value);
      const us = normalizeWholeNumber(usRaw);
      const them = normalizeWholeNumber(themRaw);
      const shotPct = shotPctRaw === "" ? "" : Math.max(0, Math.min(100, Number(shotPctRaw)));
      const entry = {
        id: modalState.game || createId(),
        date,
        opponent,
        us,
        them,
        result: computeResult(us, them),
        position: normalizePosition(document.getElementById("gm-position").value),
        rink: asString(document.getElementById("gm-rink").value),
        keyShot: asString(document.getElementById("gm-keyshot").value),
        notes: asString(document.getElementById("gm-notes").value),
        shotPct: Number.isFinite(shotPct) ? shotPct : existing ? existing.shotPct : ""
      };
      upsertEntry("games", entry);
      closeModal("modal-game");
      setStatus("Game saved.", "success");
      showToast("Game saved");
    }

    function savePractice() {
      clearFieldErrors("modal-practice");
      const date = asString(document.getElementById("pr-date").value);
      if (!date) {
        markFieldError("pr-date", "Date is required");
        setStatus("Practice date is required.", "error");
        return;
      }
      const entry = {
        id: modalState.practice || createId(),
        date,
        duration: asString(document.getElementById("pr-duration").value) || "60 min",
        shots: Array.from(document.querySelectorAll(".pr-shot:checked")).map(input => input.value),
        focus: asString(document.getElementById("pr-focus").value),
        notes: asString(document.getElementById("pr-notes").value)
      };
      upsertEntry("practice", entry);
      closeModal("modal-practice");
      setStatus("Practice session saved.", "success");
      showToast("Practice saved");
    }

    function saveIce() {
      clearFieldErrors("modal-ice");
      const date = asString(document.getElementById("ice-date").value);
      if (!date) {
        markFieldError("ice-date", "Date is required");
        setStatus("Ice note date is required.", "error");
        return;
      }
      const entry = {
        id: modalState.ice || createId(),
        date,
        rink: asString(document.getElementById("ice-rink").value),
        speed: currentSpeed,
        curl: asString(document.getElementById("ice-curl").value),
        notes: asString(document.getElementById("ice-notes-text").value)
      };
      upsertEntry("ice", entry);
      closeModal("modal-ice");
      setStatus("Ice notes saved.", "success");
      showToast("Ice notes saved");
    }

    function saveIssue() {
      const component = asString(document.getElementById("is-component").value);
      const description = asString(document.getElementById("is-description").value);
      if (!component || !description) {
        setStatus("Component and description are required.", "error");
        return;
      }
      const entry = {
        id: modalState.issue || nextIssueId(),
        component,
        description,
        severity: normalizeIssueSeverity(document.getElementById("is-severity").value),
        status: normalizeIssueStatus(document.getElementById("is-status").value),
        proposedFix: asString(document.getElementById("is-fix").value)
      };
      upsertEntry("issues", entry);
      closeModal("modal-issue");
      setStatus("Issue saved.", "success");
      showToast("Issue saved");
    }

    function deleteEntry(type, id) {
      const collectionName = type === "issue" ? "issues" : type === "ice" ? "ice" : type === "practice" ? "practice" : type === "game" ? "games" : "events";
      state[collectionName] = state[collectionName].filter(item => item.id !== id);
      if (type === "event" && selectedEventId === id) {
        selectedEventId = state.events[0] ? state.events[0].id : null;
      }
      saveState();
      renderAll();
      setStatus(`${type.charAt(0).toUpperCase() + type.slice(1)} deleted.`, "success");
      showToast(`${type.charAt(0).toUpperCase() + type.slice(1)} deleted`);
    }

    function saveModal(type) {
      if (type === "event") saveEvent();
      if (type === "game") saveGame();
      if (type === "practice") savePractice();
      if (type === "ice") saveIce();
      if (type === "issue") saveIssue();
    }

    function deleteModal(type) {
      const id = modalState[type];
      if (!id) return;
      if (!window.confirm("Delete this entry?")) return;
      deleteEntry(type, id);
      closeModal(`modal-${type}`);
    }

    function exportData() {
      const blob = new Blob([JSON.stringify(state, null, 2)], { type: "application/json" });
      const url = URL.createObjectURL(blob);
      const link = document.createElement("a");
      link.href = url;
      link.download = "curlplan-data.json";
      link.click();
      URL.revokeObjectURL(url);
      setStatus("Export ready.", "success");
      showToast("Export ready");
    }

    function importData(file) {
      if (!file) return;
      const reader = new FileReader();
      reader.onload = () => {
        try {
          const parsed = JSON.parse(reader.result);
          const nextState = normalizeState(parsed, true);
          saveState(nextState);
          selectedEventId = state.events[0] ? state.events[0].id : null;
          plannerDate = todayStr();
          renderAll();
          setStatus("Import complete.", "success");
          showToast("Import complete");
        } catch (error) {
          setStatus(error instanceof Error ? error.message : "Import failed.", "error");
        }
      };
      reader.readAsText(file);
    }

    function resetDemoData() {
      if (!window.confirm("Replace current data with the demo dataset?")) return;
      localStorage.removeItem(CHECKLIST_DEFAULTS_KEY);
      saveState(clone(demoState()));
      selectedEventId = state.events[0] ? state.events[0].id : null;
      plannerDate = todayStr();
      plannerChecklist = cloneChecklist(DEFAULT_PLANNER_CHECKLIST);
      renderAll();
      setStatus("Demo data restored.", "success");
      showToast("Demo data restored");
    }

    function renderAll() {
      renderDashboard();
      renderEventList();
      renderGames();
      renderPractice();
      renderIce();
      renderIssues();
      updatePlannerLabel();
      loadPlanner();
      renderPlannerEntries();
      filterType.value = currentFilter;
      document.querySelectorAll("#filter-bar [data-filter]").forEach(button => {
        button.classList.toggle("active-filter", button.dataset.filter === currentFilter);
      });
      if (!selectedEventId && state.events[0]) {
        selectedEventId = state.events[0].id;
        renderEventList();
      }
    }

    document.addEventListener("click", event => {
      const viewButton = event.target.closest("[data-view]");
      if (viewButton) {
        pulseElement(viewButton);
        showView(viewButton.dataset.view);
        return;
      }

      const modalOpenButton = event.target.closest("[data-open-modal]");
      if (modalOpenButton) {
        pulseElement(modalOpenButton);
        openModal(modalOpenButton.dataset.openModal, modalOpenButton.dataset.id || "");
        return;
      }

      const modalCloseButton = event.target.closest("[data-close-modal]");
      if (modalCloseButton) {
        pulseElement(modalCloseButton);
        closeModal(modalCloseButton.dataset.closeModal);
        return;
      }

      if (event.target.classList.contains("overlay")) {
        event.target.classList.remove("open");
        return;
      }

      const filterButton = event.target.closest("[data-filter]");
      if (filterButton) {
        pulseElement(filterButton);
        currentFilter = filterButton.dataset.filter;
        renderEventList();
        filterType.value = currentFilter;
        document.querySelectorAll("#filter-bar [data-filter]").forEach(button => {
          button.classList.toggle("active-filter", button === filterButton);
        });
        return;
      }

      const seasonRangeButton = event.target.closest("[data-season-range]");
      if (seasonRangeButton) {
        pulseElement(seasonRangeButton);
        currentSeasonRange = seasonRangeButton.dataset.seasonRange;
        renderSeasonStats();
        return;
      }

      const plannerButton = event.target.closest("[data-planner-dir]");
      if (plannerButton) {
        pulseElement(plannerButton);
        plannerNav(plannerButton.dataset.plannerDir);
        return;
      }

      const speedButton = event.target.closest("[data-speed]");
      if (speedButton) {
        pulseElement(speedButton);
        setSpeed(speedButton.dataset.speed);
        return;
      }

      const actionButton = event.target.closest("[data-action]");
      if (actionButton) {
        pulseElement(actionButton);
        const action = actionButton.dataset.action;
        if (action === "select-event") {
          selectedEventId = actionButton.dataset.id || null;
          renderEventList();
        }
        if (action === "delete-entry") {
          const { type, id } = actionButton.dataset;
          if (type && id && window.confirm("Delete this entry?")) deleteEntry(type, id);
        }
        if (action === "planner-jump") {
          plannerDate = actionButton.dataset.date;
          updatePlannerLabel();
          loadPlanner();
          renderPlannerEntries();
          showView("planner");
        }
        if (action === "planner-check-toggle") {
          const index = Number(actionButton.dataset.index);
          if (plannerChecklist[index]) {
            plannerChecklist[index].checked = Boolean(actionButton.checked);
            renderPlannerChecklist();
          }
        }
        if (action === "planner-check-move") {
          const index = Number(actionButton.dataset.index);
          const direction = Number(actionButton.dataset.direction);
          const nextIndex = index + direction;
          if (plannerChecklist[index] && plannerChecklist[nextIndex]) {
            const nextChecklist = plannerChecklist.slice();
            [nextChecklist[index], nextChecklist[nextIndex]] = [nextChecklist[nextIndex], nextChecklist[index]];
            plannerChecklist = nextChecklist;
            saveChecklistDefaults(plannerChecklist);
            renderPlannerChecklist();
          }
        }
        if (action === "planner-check-remove") {
          const index = Number(actionButton.dataset.index);
          plannerChecklist = plannerChecklist.filter((_, itemIndex) => itemIndex !== index);
          saveChecklistDefaults(plannerChecklist);
          renderPlannerChecklist();
        }
        if (action === "planner-check-reset") {
          plannerChecklist = cloneChecklist(DEFAULT_PLANNER_CHECKLIST);
          saveChecklistDefaults(DEFAULT_PLANNER_CHECKLIST);
          renderPlannerChecklist();
          document.getElementById("plannerChecklistInput").value = "";
        }
        if (action === "planner-check-add") {
          const input = document.getElementById("plannerChecklistInput");
          const text = asString(input.value);
          if (!text) {
            setStatus("Checklist item text is required.", "error");
          } else {
            plannerChecklist = plannerChecklist.concat({ text, checked: false });
            saveChecklistDefaults(plannerChecklist);
            renderPlannerChecklist();
            input.value = "";
            input.focus();
            setStatus("Checklist item added.", "success");
          }
        }
        if (action === "print-game-report") {
          printGameReport(actionButton.dataset.id);
        }
        return;
      }

      const saveButton = event.target.closest("[data-save-modal]");
      if (saveButton) {
        markWorking(saveButton);
        saveModal(saveButton.dataset.saveModal);
        return;
      }

      const deleteButton = event.target.closest("[data-delete-modal]");
      if (deleteButton) {
        pulseElement(deleteButton);
        deleteModal(deleteButton.dataset.deleteModal);
      }
    });

    searchInput.addEventListener("input", renderEventList);

    filterType.addEventListener("change", () => {
      pulseElement(filterType, "tap-pop", 180);
      currentFilter = filterType.value;
      renderEventList();
      document.querySelectorAll("#filter-bar [data-filter]").forEach(button => {
        button.classList.toggle("active-filter", button.dataset.filter === currentFilter);
      });
    });

    document.getElementById("savePlannerBtn").addEventListener("click", event => {
      markWorking(event.currentTarget);
      savePlanner();
    });

    document.getElementById("exportBtn").addEventListener("click", event => {
      markWorking(event.currentTarget, 420);
      exportData();
    });

    document.getElementById("resetBtn").addEventListener("click", event => {
      pulseElement(event.currentTarget);
      resetDemoData();
    });

    document.getElementById("importFile").addEventListener("change", event => {
      importData(event.target.files[0]);
      event.target.value = "";
    });

    document.addEventListener("DOMContentLoaded", () => {
      document.getElementById("todayChip").textContent = new Date().toLocaleDateString(undefined, {
        weekday: "long",
        month: "long",
        day: "numeric"
      });
      if (!state.plannerEntries[plannerDate]) {
        const firstPlannerDate = Object.keys(state.plannerEntries).sort()[0];
        if (firstPlannerDate) plannerDate = firstPlannerDate;
      }
      setSpeed(0);
      renderAll();
      setStatus("Ready.");
      document.querySelectorAll(".overlay").forEach(el => el.dataset.ready = "");

      const validViews = ["dashboard", "calendar", "planner", "games", "practice", "ice", "issues"];
      const hashView = window.location.hash.slice(1);
      if (validViews.includes(hashView)) showView(hashView);
    });

    window.addEventListener("hashchange", () => {
      const validViews = ["dashboard", "calendar", "planner", "games", "practice", "ice", "issues"];
      const hashView = window.location.hash.slice(1);
      if (validViews.includes(hashView) && hashView !== currentView) showView(hashView);
    });

    document.addEventListener("keydown", (event) => {
      if (event.key !== "Escape") return;
      const openOverlay = document.querySelector(".overlay.open");
      if (openOverlay) closeModal(openOverlay.id);
    });

    document.getElementById("plannerChecklistInput").addEventListener("keydown", (event) => {
      if (event.key !== "Enter") return;
      event.preventDefault();
      document.querySelector('[data-action="planner-check-add"]').click();
    });

    window.addEventListener("afterprint", clearPrintReport);
