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
