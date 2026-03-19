// CurlPlan shared utilities and UI helpers
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

const LINEUP_PRIMARY_SLOTS = [
  { key: "lead", label: "Lead" },
  { key: "second", label: "Second" },
  { key: "vice", label: "Vice" },
  { key: "skip", label: "Skip" }
];

const LINEUP_SUPPORT_SLOTS = [
  { key: "alternate", label: "Alternate" },
  { key: "spare", label: "Spare" }
];

const LINEUP_ALL_SLOTS = LINEUP_PRIMARY_SLOTS.concat(LINEUP_SUPPORT_SLOTS);

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
      us: null,
      them: null,
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
  if (us === null || us === "" || them === null || them === "") return fallback;
  if (Number(us) > Number(them)) return "W";
  if (Number(us) < Number(them)) return "L";
  return "D";
}

function normalizeWholeNumber(value) {
  if (value === "" || value === null || value === undefined) return null;
  const num = Number(value);
  if (!Number.isFinite(num)) return null;
  return Math.max(0, Math.round(num));
}

function relativeTimeFromIso(value) {
  if (!value) return "never";
  const parsed = new Date(value);
  if (Number.isNaN(parsed.getTime())) return "unknown";
  const diffMs = Date.now() - parsed.getTime();
  if (diffMs < 60 * 1000) return "just now";
  const minutes = Math.floor(diffMs / (60 * 1000));
  if (minutes < 60) return `${minutes}m ago`;
  const hours = Math.floor(minutes / 60);
  if (hours < 24) return `${hours}h ago`;
  const days = Math.floor(hours / 24);
  if (days < 7) return `${days}d ago`;
  const weeks = Math.floor(days / 7);
  if (weeks < 5) return `${weeks}w ago`;
  return fmtDate(parsed.toISOString().slice(0, 10), false);
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

function debounce(fn, wait = 250) {
  let timer = null;
  return (...args) => {
    window.clearTimeout(timer);
    timer = window.setTimeout(() => fn(...args), wait);
  };
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

let activeToast = null;

function clearToast() {
  if (!activeToast) return;
  const toast = activeToast;
  toast.classList.add("toast-out");
  toast.addEventListener("animationend", () => toast.remove(), { once: true });
  activeToast = null;
}

function showToast(message, options = {}) {
  clearToast();
  const toast = document.createElement("div");
  toast.className = "toast";
  toast.innerHTML = `
    <span class="toast-copy">${escapeHtml(message)}</span>
    ${options.actionLabel ? `<button type="button" class="toast-action">${escapeHtml(options.actionLabel)}</button>` : ""}
  `;
  document.body.appendChild(toast);
  activeToast = toast;
  if (options.actionLabel && typeof options.onAction === "function") {
    toast.querySelector(".toast-action")?.addEventListener("click", () => {
      options.onAction();
      clearToast();
    });
  }
  if (!options.persist) {
    window.setTimeout(() => {
      if (toast === activeToast) clearToast();
    }, options.duration || 2600);
  }
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
  const scoredGames = games.filter(item => item.us !== null && item.us !== "" && item.them !== null && item.them !== "");
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

function getEventById(eventId) {
  return state.events.find((item) => item.id === eventId) || null;
}

function getRinkById(rinkId) {
  return state.rinks.find((item) => item.id === rinkId) || null;
}

function getSheetById(sheetId) {
  return state.sheets.find((item) => item.id === sheetId) || null;
}

function getPlannerEntriesList() {
  return Array.isArray(state.plannerEntries) ? state.plannerEntries : [];
}

function getPlannerEntryByEventId(eventId) {
  if (!eventId) return null;
  return getPlannerEntriesList().find((item) => item.eventId === eventId) || null;
}

function getPlannerEntryForDate(date) {
  if (!date) return null;
  const exactDate = getPlannerEntriesList()
    .filter((item) => item.date === date)
    .slice()
    .sort((a, b) => (b.eventId ? 1 : 0) - (a.eventId ? 1 : 0));
  return exactDate[0] || null;
}

function getPlannerLinkedEvent(date, plannerEntry) {
  const linkedById = plannerEntry?.eventId ? getEventById(plannerEntry.eventId) : null;
  if (linkedById) return linkedById;
  const sameDate = state.events.filter((item) => item.date === date).slice().sort(compareDateTime);
  if (!sameDate.length) return null;
  const plannerOpponent = asString(plannerEntry?.opponent).toLowerCase();
  const plannerRink = asString(plannerEntry?.rink).toLowerCase();
  const plannerSheet = asString(plannerEntry?.sheet).toLowerCase();
  const exact = sameDate.find((item) => {
    const oppMatch = plannerOpponent && [item.opponent, item.title].map((value) => asString(value).toLowerCase()).includes(plannerOpponent);
    const rinkMatch = plannerRink && asString(item.rink).toLowerCase() === plannerRink;
    const sheetMatch = plannerSheet && asString(item.sheet).toLowerCase() === plannerSheet;
    return (oppMatch && rinkMatch) || (oppMatch && sheetMatch) || oppMatch || rinkMatch;
  });
  return exact || sameDate[0];
}

function getPlannerGoals(entry) {
  if (!entry || typeof entry !== "object") return [];
  const structuredGoals = [entry.goalOne, entry.goalTwo, entry.goalThree].map((item) => asString(item)).filter(Boolean);
  if (structuredGoals.length) return structuredGoals;
  return asString(entry.goals)
    .split(/\r?\n|•|;/)
    .map((item) => item.replace(/^[\s\u2022*-]+/, "").trim())
    .filter(Boolean)
    .slice(0, 3);
}

function hasPlannerReviewContent(entry) {
  if (!entry || typeof entry !== "object") return false;
  const reviewFields = [
    entry.drawRating,
    entry.takeoutRating,
    entry.communicationRating,
    entry.sweepingRating,
    entry.mentalRating,
    entry.keyTakeaways,
    entry.nextFocus,
    entry.reflection,
    entry.keyShot,
    entry.scoreUs,
    entry.scoreThem
  ];
  return reviewFields.some((value) => asString(value));
}

function getPlannerReviewStatus(entry) {
  if (!entry || typeof entry !== "object" || !hasPlannerReviewContent(entry)) return "none";
  const ratingCount = [
    entry.drawRating,
    entry.takeoutRating,
    entry.communicationRating,
    entry.sweepingRating,
    entry.mentalRating
  ].filter((value) => Number.isFinite(Number(value))).length;
  const textCount = [entry.keyTakeaways || entry.reflection, entry.nextFocus, entry.keyShot].filter((value) => asString(value)).length;
  if (entry.reviewCompletedAt || (ratingCount >= 3 && textCount >= 1)) return "complete";
  return "partial";
}

function upsertPlannerEntryForDate(date, entry) {
  const existing = getPlannerEntryForDate(date);
  const mergedEntry = {
    ...(existing || {}),
    ...entry,
    id: existing?.id || entry.id || createId(),
    date
  };
  const nextEntry = normalizePlannerRecord(mergedEntry, date);
  if (existing) {
    state.plannerEntries = getPlannerEntriesList().map((item) => item.id === existing.id ? nextEntry : item);
  } else {
    state.plannerEntries = getPlannerEntriesList().concat(nextEntry);
  }
  return nextEntry;
}

function removePlannerEntryForDate(date) {
  const existing = getPlannerEntryForDate(date);
  if (!existing) return;
  state.plannerEntries = getPlannerEntriesList().filter((item) => item.id !== existing.id);
}

function getGamesByEventId(eventId) {
  if (!eventId) return [];
  return state.games.filter((item) => item.eventId === eventId);
}

function getPracticeByEventId(eventId) {
  if (!eventId) return [];
  return state.practice.filter((item) => item.eventId === eventId);
}

function getRinkConditionHistory(rinkId, sheetId = "") {
  return (state.rinkConditionEntries || [])
    .filter((item) => item.rinkId === rinkId && (!sheetId || item.sheetId === sheetId))
    .slice()
    .sort((a, b) => `${b.recordedAt}`.localeCompare(`${a.recordedAt}`));
}

function getAverageCurlLast3(rinkId, sheetId = "") {
  const values = getRinkConditionHistory(rinkId, sheetId)
    .slice(0, 3)
    .map((item) => Number(item.curlOutTurns ?? item.curlInTurns))
    .filter((value) => Number.isFinite(value) && value > 0);
  if (!values.length) return null;
  return Math.round((values.reduce((sum, value) => sum + value, 0) / values.length) * 10) / 10;
}

function getMostCommonIceNote(rinkId, sheetId = "") {
  const counts = {};
  getRinkConditionHistory(rinkId, sheetId).forEach((item) => {
    const note = asString(item.notes);
    if (!note) return;
    counts[note] = (counts[note] || 0) + 1;
  });
  const top = Object.entries(counts).sort((a, b) => b[1] - a[1])[0];
  return top ? top[0] : "";
}

function getLatestRinkProfile(rinkId, sheetId = "") {
  if (!rinkId) return null;
  const history = getRinkConditionHistory(rinkId, sheetId);
  const latest = history[0];
  if (!latest) return null;
  return {
    latest,
    history,
    averageCurlLast3: getAverageCurlLast3(rinkId, sheetId),
    mostCommonIceNote: getMostCommonIceNote(rinkId, sheetId)
  };
}

function getLineupByEventId(eventId) {
  if (!eventId) return null;
  return (state.lineups || []).find((item) => item.eventId === eventId) || null;
}

function getLineupPresetsList() {
  return Array.isArray(state.lineupPresets) ? state.lineupPresets : [];
}

function getLineupPresetById(presetId) {
  if (!presetId) return null;
  return getLineupPresetsList().find((item) => item.id === presetId) || null;
}

function getLineupFilledSlots(lineup) {
  if (!lineup || typeof lineup !== "object") return 0;
  return LINEUP_ALL_SLOTS.filter(({ key }) => asString(lineup.assignments?.[key])).length;
}

function getLineupSummary(lineup) {
  if (!lineup || typeof lineup !== "object") return "No lineup saved";
  const primaryFilled = LINEUP_PRIMARY_SLOTS.filter(({ key }) => asString(lineup.assignments?.[key])).length;
  const supportFilled = LINEUP_SUPPORT_SLOTS.filter(({ key }) => asString(lineup.assignments?.[key])).length;
  if (!primaryFilled && !supportFilled) return "No lineup saved";
  return `${primaryFilled}/4 positions set${supportFilled ? ` • ${supportFilled} support` : ""}`;
}

function getBonspielById(bonspielId) {
  if (!bonspielId) return null;
  return (state.bonspiels || []).find((item) => item.id === bonspielId) || null;
}

function getBonspielDraws(bonspielId) {
  if (!bonspielId) return [];
  return state.events.filter((item) => item.bonspielId === bonspielId).slice().sort(compareDateTime);
}

function getSeasonDashboardStats() {
  const games = getGamesForRange(currentSeasonRange);
  const eventsThisMonth = state.events.filter((item) => item.date.slice(0, 7) === todayStr().slice(0, 7)).length;
  const mostPlayedRink = calculateSeasonStats(games).rinkSummary[0] || null;
  const reviewComplete = getPlannerEntriesList().filter((item) => getPlannerReviewStatus(item) === "complete").length;
  const reviewPartial = getPlannerEntriesList().filter((item) => getPlannerReviewStatus(item) === "partial").length;
  return {
    eventsThisMonth,
    gamesCount: games.length,
    practiceCount: state.practice.length,
    mostPlayedRink,
    reviewComplete,
    reviewPartial
  };
}
