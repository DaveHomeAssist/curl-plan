// CurlPlan render layer and printable report composition
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

function renderStateStrip(kind, title, copy, primary) {
  return `
    <div class="state-strip state-${escapeHtml(kind)}">
      <div class="state-copy-block">
        <div class="state-kicker">${escapeHtml(kind)}</div>
        <strong>${escapeHtml(title)}</strong>
        <span>${escapeHtml(copy)}</span>
      </div>
      ${primary ? `<button type="button" class="btn btn-primary btn-sm" ${primary.attr}>${escapeHtml(primary.label)}</button>` : ""}
    </div>
  `;
}

function getPlannerDefaults(date) {
  const linkedEvent = state.events
    .filter(item => item.date === date)
    .slice()
    .sort(compareDateTime)[0];
  return {
    time: linkedEvent?.time || "",
    rink: linkedEvent?.rink || uiPrefs.plannerTemplate.rink || "",
    opponent: linkedEvent?.opponent || linkedEvent?.title || uiPrefs.plannerTemplate.opponent || "",
    position: linkedEvent?.position || uiPrefs.plannerTemplate.position || "",
    goals: "",
    scoreUs: "",
    scoreThem: "",
    ice: "",
    reflection: "",
    keyShot: "",
    checklist: loadChecklistDefaults()
  };
}

function renderSuggestedNext() {
  const target = document.getElementById("suggestedNextStrip");
  if (!target) return;
  const today = todayStr();
  const upcoming = getUpcomingEvents()[0];
  const todayPlanner = state.plannerEntries[today];
  if (currentView === "planner") {
    const hasEntry = plannerEntryHasContent(state.plannerEntries[plannerDate]);
    target.innerHTML = renderStateStrip(
      hasEntry ? "active" : "empty",
      hasEntry ? "Planner in progress" : "Planner ready",
      hasEntry ? "Keep writing. CurlPlan will save planner work in the background." : "Start with tonight's matchup, ice notes, or checklist.",
      { label: hasEntry ? "Open Calendar" : "Add Event", attr: hasEntry ? 'data-view="calendar"' : 'data-open-modal="event"' }
    );
    return;
  }
  if (upcoming) {
    target.innerHTML = renderStateStrip(
      "active",
      `Next up: ${upcoming.title}`,
      `${fmtDate(upcoming.date, false)}${upcoming.time ? ` at ${fmtTime(upcoming.time)}` : ""}${upcoming.rink ? ` • ${upcoming.rink}` : ""}`,
      { label: "Open Planner", attr: `data-view="planner"` }
    );
    return;
  }
  target.innerHTML = renderStateStrip(
    state.events.length || state.games.length || state.practice.length || state.ice.length ? "completed" : "empty",
    state.events.length || state.games.length || state.practice.length || state.ice.length ? "Logs are up to date" : "Start your season log",
    state.events.length || state.games.length || state.practice.length || state.ice.length ? "Add a fresh event or result to keep the timeline moving." : "Create an event, game, practice session, or ice note to seed the workspace.",
    { label: "Quick Add Event", attr: 'data-open-modal="event"' }
  );
}

function renderEventCard(item, selected = false) {
  const shortDate = fmtDateShort(item.date);
  return `
    <div class="event-item${selected ? " selected" : ""}" data-event-id="${escapeHtml(item.id)}" data-action="select-event" data-id="${escapeHtml(item.id)}" tabindex="0" role="button" aria-pressed="${selected ? "true" : "false"}">
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
    target.innerHTML = '<div class="empty-icon">📅</div><div>Select an event to inspect details.</div><button type="button" class="btn btn-ghost btn-sm empty-cta" data-open-modal="event">+ Add Event</button>';
    return;
  }
  const linkedPlanner = state.plannerEntries[item.date];
  const linkedGames = state.games.filter(entry => entry.date === item.date);
  const linkedIce = state.ice.filter(entry => entry.date === item.date);
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
      <div class="linked-actions">
        <button type="button" class="btn btn-ghost btn-sm" data-view="planner">Open Planner</button>
        ${linkedGames.length ? `<button type="button" class="btn btn-ghost btn-sm" data-view="games">View ${linkedGames.length} game log ${linkedGames.length === 1 ? "entry" : "entries"}</button>` : ""}
        ${linkedIce.length ? `<button type="button" class="btn btn-ghost btn-sm" data-view="ice">View ice notes</button>` : ""}
      </div>
      <div class="summary-list">
        <div class="summary-row">
          <span class="summary-name">Planner</span>
          <span class="summary-count">${linkedPlanner ? "Entry ready" : "Not started"}</span>
        </div>
        <div class="summary-row">
          <span class="summary-name">Game log</span>
          <span class="summary-count">${linkedGames.length}</span>
        </div>
        <div class="summary-row">
          <span class="summary-name">Ice notes</span>
          <span class="summary-count">${linkedIce.length}</span>
        </div>
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
  const gameQuery = (document.getElementById("gameSearchInput")?.value || "").trim().toLowerCase();
  const gameSort = document.getElementById("gameSortSelect")?.value || "newest";
  const items = state.games.slice()
    .filter(item => {
      if (!gameQuery) return true;
      return [
        item.opponent,
        item.rink,
        item.notes,
        item.keyShot,
        item.position,
        item.result,
        item.date,
        item.us !== "" ? String(item.us) : "",
        item.them !== "" ? String(item.them) : "",
        item.shotPct !== "" ? String(item.shotPct) : ""
      ].join(" ").toLowerCase().includes(gameQuery);
    })
    .sort((a, b) => gameSort === "oldest" ? a.date.localeCompare(b.date) : b.date.localeCompare(a.date));
  if (!items.length) {
    tbody.innerHTML = "";
    empty.classList.remove("hidden");
  } else {
    empty.classList.add("hidden");
    tbody.innerHTML = items.map(item => `
      <tr class="log-row${expandedGameId === item.id ? " is-expanded" : ""}" tabindex="0" role="button" data-action="toggle-game-expand" data-id="${escapeHtml(item.id)}" aria-expanded="${expandedGameId === item.id ? "true" : "false"}">
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
      ${expandedGameId === item.id ? `
        <tr class="log-detail-row">
          <td colspan="8">
            <div class="log-detail-card">
              <div class="summary-row">
                <span class="summary-name">Key shot</span>
                <span class="summary-count">${escapeHtml(item.keyShot || "Not logged")}</span>
              </div>
              <div class="summary-row">
                <span class="summary-name">Notes</span>
                <span class="summary-count">${escapeHtml(item.notes || "No notes saved")}</span>
              </div>
              <div class="inline-actions">
                <button type="button" class="btn btn-primary btn-sm" data-open-modal="game" data-id="${escapeHtml(item.id)}">Quick Edit</button>
                <button type="button" class="btn btn-ghost btn-sm" data-action="print-game-report" data-id="${escapeHtml(item.id)}">Print Report</button>
              </div>
            </div>
          </td>
        </tr>
      ` : ""}
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
  const practiceQuery = (document.getElementById("practiceSearchInput")?.value || "").trim().toLowerCase();
  const practiceSort = document.getElementById("practiceSortSelect")?.value || "newest";
  const items = state.practice.slice()
    .filter(item => {
      if (!practiceQuery) return true;
      return [item.date, item.duration, item.focus, item.notes, (item.shots || []).join(" ")].join(" ").toLowerCase().includes(practiceQuery);
    })
    .sort((a, b) => practiceSort === "oldest" ? a.date.localeCompare(b.date) : b.date.localeCompare(a.date));
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
  const iceQuery = (document.getElementById("iceSearchInput")?.value || "").trim().toLowerCase();
  const iceSort = document.getElementById("iceSortSelect")?.value || "newest";
  const items = state.ice.slice()
    .filter(item => {
      if (!iceQuery) return true;
      return [item.date, item.rink, item.notes, item.curl, speedText(item.speed)].join(" ").toLowerCase().includes(iceQuery);
    })
    .sort((a, b) => iceSort === "oldest" ? a.date.localeCompare(b.date) : b.date.localeCompare(a.date));
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
  const savedEntry = state.plannerEntries[plannerDate];
  const entry = savedEntry || getPlannerDefaults(plannerDate);
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
  renderPlannerStateStrip(Boolean(savedEntry));
  renderGameDayBanner();
}

function renderPlannerStateStrip(hasSavedEntry) {
  const target = document.getElementById("plannerStateStrip");
  if (!target) return;
  target.innerHTML = hasSavedEntry
    ? renderStateStrip("active", "Planner entry in progress", "Changes save in the background while you edit this date.", { label: "Save Snapshot", attr: 'id="plannerStateSaveCopy" data-save-planner-inline="true"' })
    : renderStateStrip("empty", "Start this planner entry", "Defaults pulled from matching event timing and your recent rink memory.", { label: "Use Today", attr: 'data-action="planner-jump" data-date="' + escapeHtml(todayStr()) + '"' });
}

function renderGameDayBanner() {
  const target = document.getElementById("gameDayBanner");
  if (!target) return;
  const linkedEvent = state.events
    .filter(item => item.date === plannerDate)
    .slice()
    .sort(compareDateTime)[0];
  if (!linkedEvent) {
    target.innerHTML = "";
    return;
  }
  target.innerHTML = renderStateStrip("completed", `Game day focus for ${linkedEvent.title}`, `${fmtDate(plannerDate, false)}${linkedEvent.time ? ` at ${fmtTime(linkedEvent.time)}` : ""}${linkedEvent.rink ? ` • ${linkedEvent.rink}` : ""}`, { label: "Open Event", attr: `data-open-modal="event" data-id="${escapeHtml(linkedEvent.id)}"` });
}

function savePlanner(options = {}) {
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
  saveUiPrefs({
    ...uiPrefs,
    lastPlannerDate: plannerDate,
    plannerTemplate: {
      rink: entry.rink,
      position: entry.position,
      opponent: entry.opponent
    }
  });
  saveState();
  renderAll();
  if (!options.silent) {
    setStatus("Planner saved.", "success");
    showToast("Planner saved");
  } else {
    setStatus("Planner autosaved.", "success");
  }
  return entry;
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
