// CurlPlan render layer and printable report composition
let printedGameId = null;

function renderSeasonStats() {
  const target = document.getElementById("seasonStatsGrid");
  const games = getGamesForRange(currentSeasonRange);
  const rangeLabel = document.getElementById("seasonRangeLabel");
  document.querySelectorAll("[data-season-range]").forEach(button => {
    button.classList.toggle("is-active", button.dataset.seasonRange === currentSeasonRange);
  });
  if (rangeLabel) rangeLabel.textContent = getRangeLabel(currentSeasonRange, games);

  if (!games.length) {
    target.innerHTML = renderEmpty("chart", "Log your first game to unlock season insights.", null, "Season insights are waiting");
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

  const cards = [];

  cards.push(`
    <div class="insight-card">
      <div class="insight-kicker">Record</div>
      <div class="insight-value">${stats.wins}-${stats.losses}-${stats.draws}</div>
      <div class="insight-meta">${escapeHtml(getRangeLabel(currentSeasonRange, games))}</div>
      ${buildSparkline(recordValues, 220, 44, "sparkline-soft")}
    </div>
  `);

  if (positionBest) {
    cards.push(`
    <div class="insight-card">
      <div class="insight-kicker">Best Position</div>
      <div class="insight-value">${escapeHtml(`${positionBest.winPct}%`)}</div>
      <div class="insight-meta">${escapeHtml(`${positionBest.name} • ${positionBest.wins}-${positionBest.losses}-${positionBest.draws}`)}</div>
      ${buildSparkline(positionValues, 220, 44, "sparkline-soft")}
    </div>
    `);
  }

  if (stats.avgDiff !== null) {
    cards.push(`
    <div class="insight-card">
      <div class="insight-kicker">Avg Score Differential</div>
      <div class="insight-value">${stats.avgDiff > 0 ? "+" : ""}${stats.avgDiff.toFixed(1)}</div>
      <div class="insight-meta">Average points above or below opponent.</div>
      ${buildSparkline(stats.diffSpark, 220, 44, "sparkline-soft")}
    </div>
    `);
  }

  cards.push(`
    <div class="insight-card">
      <div class="insight-kicker">Longest Win Streak</div>
      <div class="insight-value">${escapeHtml(String(stats.longestStreak || 0))}</div>
      <div class="insight-meta">${escapeHtml(stats.longestStreak ? `Best run across ${stats.gameCount} game${stats.gameCount === 1 ? "" : "s"}.` : "No winning streak in this range yet.")}</div>
      ${buildSparkline(streakValues, 220, 44, "sparkline-soft")}
    </div>
  `);

  if (topRink) {
    cards.push(`
    <div class="insight-card">
      <div class="insight-kicker">Top Rink Split</div>
      <div class="insight-value">${escapeHtml(`${topRink.winPct}%`)}</div>
      <div class="insight-meta">${escapeHtml(`${topRink.name} • ${topRink.wins}-${topRink.losses}-${topRink.draws}`)}</div>
      ${buildSparkline(rinkValues, 220, 44, "sparkline-soft")}
    </div>
    `);
  }

  if (stats.shotTrendGames.length) {
    cards.push(`
    <div class="insight-card">
      <div class="insight-kicker">Shot % Trend</div>
      <div class="insight-value">${escapeHtml(`${Math.round(stats.shotTrendGames.reduce((sum, item) => sum + Number(item.shotPct), 0) / stats.shotTrendGames.length)}%`)}</div>
      <div class="insight-meta">${escapeHtml(`Last ${stats.shotTrendGames.length} logged shot percentage${stats.shotTrendGames.length === 1 ? "" : "s"}.`)}</div>
      ${shotTrendMarkup}
    </div>
    `);
  }

  target.innerHTML = cards.join("");
}

function renderPlannerChecklist() {
  const target = document.getElementById("plannerChecklist");
  if (!target) return;
  if (!plannerChecklist.length) {
    target.innerHTML = '<div class="planner-checklist-empty">No checklist items yet. Add one below or reset to defaults.</div>';
    return;
  }
  const checked = plannerChecklist.filter((item) => item.checked).length;
  const total = plannerChecklist.length;
  const pct = total ? Math.round((checked / total) * 100) : 0;
  target.innerHTML = `
    <div class="checklist-progress" aria-hidden="true"><div class="checklist-progress-fill" style="width:${pct}%"></div></div>
    <div class="checklist-progress-label">${checked} / ${total} ready</div>
    ${plannerChecklist.map((item, index) => `
      <div class="checklist-item${item.checked ? " is-checked" : ""}">
        <input type="checkbox" ${item.checked ? "checked" : ""} data-action="planner-check-toggle" data-index="${index}" aria-label="Toggle checklist item ${escapeHtml(item.text)}" />
        <div class="checklist-copy">${escapeHtml(item.text)}</div>
        <div class="checklist-actions">
          <button type="button" class="btn btn-ghost btn-sm" data-action="planner-check-move" data-direction="-1" data-index="${index}" ${index === 0 ? "disabled" : ""}>↑</button>
          <button type="button" class="btn btn-ghost btn-sm" data-action="planner-check-move" data-direction="1" data-index="${index}" ${index === plannerChecklist.length - 1 ? "disabled" : ""}>↓</button>
          <button type="button" class="btn btn-danger btn-sm" data-action="planner-check-remove" data-index="${index}">Remove</button>
        </div>
      </div>
    `).join("")}
  `;
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

function renderIcon(name, label = "") {
  const iconName = escapeHtml(name);
  const attrs = label ? `role="img" aria-label="${escapeHtml(label)}"` : 'aria-hidden="true"';
  return `<svg viewBox="0 0 24 24" ${attrs}><use href="#icon-${iconName}"></use></svg>`;
}

function renderEmpty(icon, text, cta, title) {
  const heading = title || text;
  return `
    <div class="empty">
      <div class="empty-icon">${renderIcon(icon)}</div>
      <div class="empty-copy">
        <strong>${escapeHtml(heading)}</strong>
        <span>${escapeHtml(text)}</span>
      </div>
      ${cta ? `<div class="empty-actions"><button type="button" class="btn btn-ghost btn-sm empty-cta" data-open-modal="${cta.modal}">+ ${escapeHtml(cta.label)}</button></div>` : ""}
    </div>
  `;
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

function renderRinkProfileCard(profile, rinkName, sheetLabel = "", emptyLabel = "No rink memory yet") {
  if (!profile) {
    return `
      <div class="card-sm rink-profile-card">
        <div class="summary-row">
          <span class="summary-name">Rink profile</span>
          <span class="summary-count">${escapeHtml(emptyLabel)}</span>
        </div>
      </div>
    `;
  }
  const latest = profile.latest;
  const avgCurl = profile.averageCurlLast3;
  const commonNote = profile.mostCommonIceNote;
  return `
    <div class="card-sm rink-profile-card">
      <div class="card-head">
        <div>
          <h3 class="card-title">${escapeHtml(rinkName || "Rink profile")}</h3>
          <div class="muted">${escapeHtml(sheetLabel ? `Sheet ${sheetLabel}` : "Venue level profile")}</div>
        </div>
        <div class="pill-row">
          ${latest.speedEstimate ? `<span class="badge mono">${escapeHtml(speedText(latest.speedEstimate))}</span>` : ""}
          ${latest.curlLabel ? `<span class="type-chip type-other">${escapeHtml(latest.curlLabel)}</span>` : ""}
        </div>
      </div>
      <div class="summary-list">
        <div class="summary-row"><span class="summary-name">Latest note</span><span class="summary-count">${escapeHtml(fmtDate(String(latest.recordedAt).slice(0, 10), false))}</span></div>
        ${avgCurl !== null ? `<div class="summary-row"><span class="summary-name">Avg curl last 3</span><span class="summary-count">${escapeHtml(String(avgCurl))} turns</span></div>` : ""}
        ${latest.frostLevel ? `<div class="summary-row"><span class="summary-name">Frost</span><span class="summary-count">${escapeHtml(latest.frostLevel)}</span></div>` : ""}
        ${latest.hackCondition ? `<div class="summary-row"><span class="summary-name">Hacks</span><span class="summary-count">${escapeHtml(latest.hackCondition)}</span></div>` : ""}
      </div>
      <div class="event-notes">${escapeHtml(commonNote || latest.notes || "No detailed note saved yet.")}</div>
    </div>
  `;
}

function renderLineupAssignmentRows(lineup, slots) {
  return slots.map(({ key, label }) => `
    <div class="form-row">
      <label class="form-label" for="lineup-${escapeHtml(key)}">${escapeHtml(label)}</label>
      <input type="text" id="lineup-${escapeHtml(key)}" value="${escapeHtml(lineup?.assignments?.[key] || "")}" placeholder="${escapeHtml(`${label} player`)}" />
    </div>
  `).join("");
}

function renderLineupSummaryRows(lineup) {
  const filledPrimary = LINEUP_PRIMARY_SLOTS.filter(({ key }) => asString(lineup?.assignments?.[key])).length;
  const filledSupport = LINEUP_SUPPORT_SLOTS.filter(({ key }) => asString(lineup?.assignments?.[key])).length;
  const preset = getLineupPresetById(lineup?.presetId);
  return `
    <div class="summary-row"><span class="summary-name">Primary slots</span><span class="summary-count">${escapeHtml(String(filledPrimary))}/4</span></div>
    <div class="summary-row"><span class="summary-name">Support slots</span><span class="summary-count">${escapeHtml(String(filledSupport))}/2</span></div>
    <div class="summary-row"><span class="summary-name">Preset</span><span class="summary-count">${escapeHtml(preset?.name || "Custom")}</span></div>
  `;
}

function renderLineupEditorCard(eventItem, lineup) {
  const workingLineup = lineup || normalizeLineup({ eventId: eventItem.id });
  const presetOptions = getLineupPresetsList()
    .slice()
    .sort((a, b) => a.name.localeCompare(b.name))
    .map((preset) => `<option value="${escapeHtml(preset.id)}"${preset.id === workingLineup.presetId ? " selected" : ""}>${escapeHtml(preset.name)}</option>`)
    .join("");
  return `
    <div class="card-sm lineup-card">
      <div class="card-head">
        <div>
          <h3 class="card-title">Lineup</h3>
          <p class="card-copy">Track who played where, who subbed in, and which preset fits this draw.</p>
        </div>
        <div class="pill-row">
          <span class="type-chip">${escapeHtml(getLineupSummary(workingLineup))}</span>
        </div>
      </div>
      <div class="lineup-toolbar">
        <div class="form-row" style="margin-bottom:0;">
          <label class="form-label" for="lineupPresetSelect">Preset</label>
          <select id="lineupPresetSelect">
            <option value="">Custom lineup</option>
            ${presetOptions}
          </select>
        </div>
        <div class="lineup-toolbar-actions">
          <button type="button" class="btn btn-ghost btn-sm" data-action="load-lineup-preset">Load Preset</button>
          <button type="button" class="btn btn-ghost btn-sm" data-action="save-lineup-preset">Save As Preset</button>
          <button type="button" class="btn btn-ghost btn-sm" data-action="clear-lineup">Clear</button>
        </div>
      </div>
      <div class="lineup-grid">
        ${renderLineupAssignmentRows(workingLineup, LINEUP_PRIMARY_SLOTS)}
      </div>
      <div class="lineup-grid lineup-grid-support">
        ${renderLineupAssignmentRows(workingLineup, LINEUP_SUPPORT_SLOTS)}
      </div>
      <div class="form-row">
        <label class="form-label" for="lineup-opponents">Opponent Roster</label>
        <textarea id="lineup-opponents" placeholder="Skip, vice, notable spare, or any matchup note.">${escapeHtml(workingLineup.opponents || "")}</textarea>
      </div>
      <div class="form-row">
        <label class="form-label" for="lineup-notes">Lineup Notes</label>
        <textarea id="lineup-notes" placeholder="Rotation plan, communication note, or why this lineup mattered.">${escapeHtml(workingLineup.notes || "")}</textarea>
      </div>
      <div class="summary-list lineup-summary-list">
        ${renderLineupSummaryRows(workingLineup)}
      </div>
      <div class="linked-actions">
        <button type="button" class="btn btn-primary btn-sm" data-action="save-lineup">Save Lineup</button>
      </div>
    </div>
  `;
}

function renderBonspielDrawCards(bonspielId) {
  const draws = getBonspielDraws(bonspielId);
  if (!draws.length) {
    return renderEmpty("calendar", "No draws linked yet. Add child events and assign this bonspiel as the parent.", null, "No draws linked");
  }
  return `
    <div class="bonspiel-draw-grid">
      ${draws.map((draw) => {
        const drawGame = getGamesByEventId(draw.id)[0] || state.games.find((item) => item.date === draw.date && asString(item.opponent) === asString(draw.opponent)) || null;
        const drawLineup = getLineupByEventId(draw.id);
        return `
          <div class="card-sm bonspiel-draw-card" data-event-id="${escapeHtml(draw.id)}" data-action="select-event" data-id="${escapeHtml(draw.id)}" tabindex="0" role="button" aria-pressed="false">
            <div class="card-head">
              <div>
                <h3 class="card-title">${escapeHtml(draw.title)}</h3>
                <div class="muted">${escapeHtml(fmtDate(draw.date, false))}${draw.time ? ` • ${escapeHtml(fmtTime(draw.time))}` : ""}</div>
              </div>
              <div class="pill-row">
                ${draw.sheet ? `<span class="badge mono">Sheet ${escapeHtml(draw.sheet)}</span>` : ""}
                ${drawGame && drawGame.result ? `<span class="result-badge ${resultClass(drawGame.result)}">${escapeHtml(drawGame.result)}</span>` : ""}
              </div>
            </div>
            <div class="event-notes">${escapeHtml(draw.opponent || draw.notes || "No opponent logged yet.")}</div>
            <div class="muted">${escapeHtml(getLineupSummary(drawLineup))}</div>
          </div>
        `;
      }).join("")}
    </div>
  `;
}

function renderBonspielCard(item) {
  const bonspielId = item.type === "bonspiel" ? item.id : item.bonspielId;
  if (!bonspielId) return "";
  const parentEvent = item.type === "bonspiel" ? item : getEventById(bonspielId);
  const bonspiel = getBonspielById(bonspielId) || normalizeBonspiel({
    id: bonspielId,
    title: parentEvent?.title || item.title,
    startDate: parentEvent?.date || item.date,
    endDate: parentEvent?.date || item.date,
    venue: parentEvent?.rink || item.rink,
    notes: parentEvent?.notes || item.notes
  });
  if (!parentEvent) return "";
  if (item.type !== "bonspiel") {
    return `
      <div class="card-sm bonspiel-detail-card">
        <div class="card-head">
          <div>
            <h3 class="card-title">Bonspiel Context</h3>
            <p class="card-copy">${escapeHtml(parentEvent.title)}</p>
          </div>
          <button type="button" class="btn btn-ghost btn-sm" data-action="jump-to-parent" data-id="${escapeHtml(parentEvent.id)}">Open Parent</button>
        </div>
        <div class="summary-list">
          <div class="summary-row"><span class="summary-name">Window</span><span class="summary-count">${escapeHtml(fmtDate(bonspiel.startDate, false))}${bonspiel.endDate && bonspiel.endDate !== bonspiel.startDate ? ` to ${escapeHtml(fmtDate(bonspiel.endDate, false))}` : ""}</span></div>
          <div class="summary-row"><span class="summary-name">Venue</span><span class="summary-count">${escapeHtml(bonspiel.venue || parentEvent.rink || "Not set")}</span></div>
          <div class="summary-row"><span class="summary-name">Stage</span><span class="summary-count">${escapeHtml(bonspiel.bracketStage || "Not set")}</span></div>
        </div>
        ${bonspiel.travel ? `<div class="event-notes">${escapeHtml(bonspiel.travel)}</div>` : ""}
      </div>
    `;
  }
  return `
    <div class="card-sm bonspiel-detail-card">
      <div class="card-head">
        <div>
          <h3 class="card-title">Bonspiel Dashboard</h3>
          <p class="card-copy">${escapeHtml(bonspiel.title)}</p>
        </div>
        <div class="pill-row">
          <span class="type-chip type-bonspiel">${escapeHtml(getBonspielDraws(bonspiel.id).length)} draw${getBonspielDraws(bonspiel.id).length === 1 ? "" : "s"}</span>
        </div>
      </div>
      <div class="summary-list">
        <div class="summary-row"><span class="summary-name">Window</span><span class="summary-count">${escapeHtml(fmtDate(bonspiel.startDate, false))}${bonspiel.endDate && bonspiel.endDate !== bonspiel.startDate ? ` to ${escapeHtml(fmtDate(bonspiel.endDate, false))}` : ""}</span></div>
        <div class="summary-row"><span class="summary-name">Venue</span><span class="summary-count">${escapeHtml(bonspiel.venue || item.rink || "Not set")}</span></div>
        <div class="summary-row"><span class="summary-name">Hotel</span><span class="summary-count">${escapeHtml(bonspiel.hotel || "Not set")}</span></div>
        <div class="summary-row"><span class="summary-name">Budget</span><span class="summary-count">${escapeHtml(bonspiel.budget || "Not set")}</span></div>
        <div class="summary-row"><span class="summary-name">Stage</span><span class="summary-count">${escapeHtml(bonspiel.bracketStage || "Not set")}</span></div>
      </div>
      ${bonspiel.teammates ? `<div class="event-notes"><strong>Roster:</strong> ${escapeHtml(bonspiel.teammates)}</div>` : ""}
      ${bonspiel.travel ? `<div class="event-notes"><strong>Travel:</strong> ${escapeHtml(bonspiel.travel)}</div>` : ""}
      ${bonspiel.packing ? `<div class="event-notes"><strong>Packing:</strong> ${escapeHtml(bonspiel.packing)}</div>` : ""}
      <div class="card-head" style="margin-top:6px;">
        <div>
          <h3 class="card-title">Linked Draws</h3>
          <p class="card-copy">Each draw stays editable as its own event, planner record, lineup, and game log.</p>
        </div>
      </div>
      ${renderBonspielDrawCards(bonspiel.id)}
    </div>
  `;
}

function getPlannerDefaults(date) {
  const linkedEvent = getPlannerLinkedEvent(date, getPlannerEntryForDate(date));
  return {
    id: "",
    eventId: linkedEvent?.id || "",
    date,
    time: linkedEvent?.time || "",
    rink: linkedEvent?.rink || uiPrefs.plannerTemplate.rink || "",
    rinkId: linkedEvent?.rinkId || "",
    sheet: linkedEvent?.sheet || "",
    sheetId: linkedEvent?.sheetId || "",
    opponent: linkedEvent?.opponent || linkedEvent?.title || uiPrefs.plannerTemplate.opponent || "",
    position: linkedEvent?.position || uiPrefs.plannerTemplate.position || "",
    goalOne: "",
    goalTwo: "",
    goalThree: "",
    goals: "",
    scoreUs: "",
    scoreThem: "",
    ice: "",
    drawRating: null,
    takeoutRating: null,
    communicationRating: null,
    sweepingRating: null,
    mentalRating: null,
    keyTakeaways: "",
    nextFocus: "",
    reflection: "",
    keyShot: "",
    prepCompletedAt: "",
    reviewCompletedAt: "",
    checklist: loadChecklistDefaults()
  };
}

function getPlannerReviewLabel(entry) {
  const status = getPlannerReviewStatus(entry);
  if (status === "complete") return "Review complete";
  if (status === "partial") return "Review partial";
  return "Review pending";
}

function getPlannerGoalSummary(entry) {
  const goals = getPlannerGoals(entry);
  return goals.length ? goals.join(" • ") : "No goals entered yet.";
}

function renderPlannerGoalList(entry) {
  const goals = getPlannerGoals(entry);
  if (!goals.length) return '<div class="report-note">No goals logged.</div>';
  return `
    <div class="report-lines">
      ${goals.map((goal, index) => `<div><strong>Goal ${index + 1}:</strong> ${escapeHtml(goal)}</div>`).join("")}
    </div>
  `;
}

function renderPlannerReviewDetails(entry) {
  const ratingPairs = [
    ["Draw", entry.drawRating],
    ["Takeout", entry.takeoutRating],
    ["Communication", entry.communicationRating],
    ["Sweeping", entry.sweepingRating],
    ["Mental", entry.mentalRating]
  ].filter(([, value]) => Number.isFinite(Number(value)));
  const lines = [];
  if (ratingPairs.length) lines.push(`<div><strong>Ratings:</strong> ${escapeHtml(ratingPairs.map(([label, value]) => `${label} ${value}/5`).join(" • "))}</div>`);
  lines.push(`<div><strong>Key Shot:</strong> ${escapeHtml(entry.keyShot || "—")}</div>`);
  lines.push(`<div><strong>Ice Notes:</strong> ${escapeHtml(entry.ice || "—")}</div>`);
  lines.push(`<div><strong>Key Takeaways:</strong></div>`);
  lines.push(`<div class="report-note">${escapeHtml(entry.keyTakeaways || entry.reflection || "No post game review logged.")}</div>`);
  lines.push(`<div><strong>Next Focus:</strong> ${escapeHtml(entry.nextFocus || "—")}</div>`);
  return `<div class="report-lines">${lines.join("")}</div>`;
}

function renderSuggestedNext() {
  const target = document.getElementById("suggestedNextStrip");
  if (!target) return;
  const today = todayStr();
  const upcoming = getUpcomingEvents()[0];
  const todayPlanner = getPlannerEntryForDate(today);
  if (currentView === "planner") {
    const hasEntry = plannerEntryHasContent(getPlannerEntryForDate(plannerDate));
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

function renderExportButtonLabel() {
  const button = document.getElementById("exportBtn");
  if (!button) return;
  button.textContent = `Export (${uiPrefs.lastExportAt ? `last: ${relativeTimeFromIso(uiPrefs.lastExportAt)}` : "never"})`;
}

function renderViewContext() {
  const target = document.getElementById("viewContext");
  if (!target) return;
  let html = "";
  if (currentView === "calendar" && selectedEventId) {
    const event = state.events.find((item) => item.id === selectedEventId);
    if (event) {
      html = `<button type="button" class="view-context-link" data-view="calendar">Calendar</button><span class="view-context-sep">→</span><span>Event: ${escapeHtml(event.title)}</span>`;
    }
  } else if (currentView === "games") {
    const contextGame = state.games.find((item) => item.id === (printedGameId || expandedGameId));
    if (contextGame) {
      const label = printedGameId ? `Report: vs ${contextGame.opponent || "Unknown Opponent"}` : `Detail: vs ${contextGame.opponent || "Unknown Opponent"}`;
      html = `<button type="button" class="view-context-link" data-view="games">Games</button><span class="view-context-sep">→</span><span>${escapeHtml(label)}</span>`;
    }
  }
  target.innerHTML = html;
  target.classList.toggle("is-hidden", !html);
}

function renderEventCard(item, selected = false) {
  const shortDate = fmtDateShort(item.date);
  const parentBonspiel = item.bonspielId ? getEventById(item.bonspielId) : null;
  return `
    <div class="event-item${selected ? " is-selected" : ""}" data-event-id="${escapeHtml(item.id)}" data-action="select-event" data-id="${escapeHtml(item.id)}" tabindex="0" role="button" aria-pressed="${selected ? "true" : "false"}">
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
          ${parentBonspiel ? `<span class="type-chip">Bonspiel draw</span>` : ""}
          ${item.position ? `<span class="position-badge ${positionClass(item.position)}">${escapeHtml(item.position)}</span>` : ""}
        </div>
        ${item.notes || parentBonspiel ? `<div class="event-notes">${escapeHtml(parentBonspiel ? `${parentBonspiel.title}${item.notes ? ` • ${item.notes}` : ""}` : item.notes)}</div>` : ""}
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
    target.innerHTML = renderEmpty("calendar", "No events match the current filter.", null, "No events in view");
    renderSelectedEvent();
    renderViewContext();
    return;
  }
  if (!selectedEventId || !state.events.find(item => item.id === selectedEventId)) {
    selectedEventId = items[0].id;
  }
  target.innerHTML = items.map(item => renderEventCard(item, item.id === selectedEventId)).join("");
  renderSelectedEvent();
  renderViewContext();
}

function renderSelectedEvent() {
  const target = document.getElementById("eventDetail");
  const item = state.events.find(entry => entry.id === selectedEventId);
  if (!item) {
    target.className = "empty";
    target.innerHTML = renderEmpty("calendar", "Select an event to inspect details.", { modal: "event", label: "Add Event" }, "No event selected");
    return;
  }
  const linkedPlanner = getPlannerEntryByEventId(item.id) || getPlannerEntryForDate(item.date);
  const linkedGames = getGamesByEventId(item.id).length ? getGamesByEventId(item.id) : state.games.filter(entry => entry.date === item.date);
  const linkedIce = state.ice.filter(entry => entry.eventId === item.id || entry.date === item.date);
  const linkedLineup = getLineupByEventId(item.id);
  const linkedBonspiel = item.type === "bonspiel" ? getBonspielById(item.id) : item.bonspielId ? getBonspielById(item.bonspielId) : null;
  const rinkProfile = getLatestRinkProfile(item.rinkId, item.sheetId);
  const plannerReviewLabel = linkedPlanner ? getPlannerReviewLabel(linkedPlanner) : "Not started";
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
          <span class="summary-count">${escapeHtml(plannerReviewLabel)}</span>
        </div>
        <div class="summary-row">
          <span class="summary-name">Lineup</span>
          <span class="summary-count">${escapeHtml(getLineupSummary(linkedLineup))}</span>
        </div>
        <div class="summary-row">
          <span class="summary-name">Bonspiel</span>
          <span class="summary-count">${escapeHtml(item.type === "bonspiel" ? `${getBonspielDraws(item.id).length} draws linked` : linkedBonspiel ? linkedBonspiel.title : "Standalone")}</span>
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
      ${linkedPlanner ? `<div class="event-notes">${escapeHtml(getPlannerGoalSummary(linkedPlanner))}</div>` : ""}
    </div>
    ${renderBonspielCard(item)}
    ${renderLineupEditorCard(item, linkedLineup)}
    ${renderRinkProfileCard(rinkProfile, item.rink || getRinkById(item.rinkId)?.name || "Rink profile", item.sheet, "No rink memory yet for this venue")}
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
    : renderEmpty("calendar", "No upcoming events.", { modal: "event", label: "Add Event" }, "Calendar is open");

  const plannerEntries = getPlannerEntriesList().slice().sort((a, b) => a.date.localeCompare(b.date));
  const futurePlanner = plannerEntries.filter((item) => item.date >= todayStr());
  const plannerEntry = futurePlanner[0] || plannerEntries[plannerEntries.length - 1] || null;
  const activePlannerKey = plannerEntry?.date || "";
  const plannerLinkedEvent = plannerEntry ? getPlannerLinkedEvent(plannerEntry.date, plannerEntry) : null;
  const plannerProfile = plannerLinkedEvent ? getLatestRinkProfile(plannerLinkedEvent.rinkId, plannerLinkedEvent.sheetId) : plannerEntry?.rinkId ? getLatestRinkProfile(plannerEntry.rinkId, plannerEntry.sheetId) : null;
  const plannerReviewLabel = plannerEntry ? getPlannerReviewLabel(plannerEntry) : "";
  plannerSnapshot.innerHTML = plannerEntry
    ? `
      <div class="card-sm">
        <div class="pill-row">
          <span class="badge mono">${escapeHtml(fmtDate(activePlannerKey))}</span>
          ${plannerEntry.position ? `<span class="position-badge ${positionClass(plannerEntry.position)}">${escapeHtml(plannerEntry.position)}</span>` : ""}
          <span class="type-chip">${escapeHtml(plannerReviewLabel)}</span>
        </div>
        <h3 class="card-title" style="margin-top:10px;">${escapeHtml(plannerEntry.opponent || "No opponent set")}</h3>
        <div class="muted">${plannerEntry.time ? escapeHtml(fmtTime(plannerEntry.time)) : "No time set"}${plannerEntry.rink ? ` • ${escapeHtml(plannerEntry.rink)}` : ""}</div>
        <div class="event-notes" style="margin-top:10px;">${escapeHtml(getPlannerGoalSummary(plannerEntry))}</div>
        ${plannerEntry.checklist && plannerEntry.checklist.some(item => item.checked) ? `<div class="muted" style="margin-top:8px;">Checklist complete: ${escapeHtml(String(plannerEntry.checklist.filter(item => item.checked).length))}/${escapeHtml(String(plannerEntry.checklist.length))}</div>` : ""}
        ${getPlannerReviewStatus(plannerEntry) !== "none" ? `<div class="muted" style="margin-top:8px;">${escapeHtml(plannerEntry.nextFocus || plannerEntry.keyTakeaways || plannerEntry.reflection || "Review captured for this event.")}</div>` : ""}
      </div>
      ${plannerProfile ? renderRinkProfileCard(plannerProfile, plannerEntry.rink || plannerLinkedEvent?.rink || "Rink profile", plannerEntry.sheet || plannerLinkedEvent?.sheet, "No rink memory yet") : ""}
    `
    : renderEmpty("note", "No planner entries saved yet.", null, "No planner entries yet");

  document.getElementById("dash-games").innerHTML = state.games.length
    ? state.games.slice().sort((a, b) => b.date.localeCompare(a.date)).slice(0, 3).map(item => `
      <div class="card-sm">
        <div class="card-head">
          <div>
            <h3 class="card-title">vs ${escapeHtml(item.opponent || "Unknown Opponent")}</h3>
            <div class="muted">${escapeHtml(fmtDate(item.date))}</div>
          </div>
          <div class="pill-row">
            ${(item.us !== null && item.them !== null) ? `<span class="score-pill">${escapeHtml(String(item.us))}-${escapeHtml(String(item.them))}</span>` : ""}
            ${item.result ? `<span class="result-badge ${resultClass(item.result)}">${escapeHtml(item.result)}</span>` : ""}
          </div>
        </div>
        <div class="event-notes">${escapeHtml(item.notes || item.keyShot || "No notes saved.")}</div>
      </div>
    `).join("")
    : renderEmpty("stone", "No games logged yet.", { modal: "game", label: "Log Game" }, "Game log is empty");

  const latestIce = state.ice.slice().sort((a, b) => b.date.localeCompare(a.date))[0];
  const latestProfile = latestIce ? getLatestRinkProfile(latestIce.rinkId, latestIce.sheetId) : ((state.rinkConditionEntries || []).length ? getLatestRinkProfile(state.rinkConditionEntries[0].rinkId, state.rinkConditionEntries[0].sheetId) : null);
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
      ${latestProfile ? renderRinkProfileCard(latestProfile, latestIce.rink || getRinkById(latestIce.rinkId)?.name || "Rink profile", latestIce.sheet, "No rink memory yet") : ""}
    `
    : renderEmpty("ice", "No ice notes saved yet.", { modal: "ice", label: "Add Ice Notes" }, "No ice notes yet");
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
        item.us !== null ? String(item.us) : "",
        item.them !== null ? String(item.them) : "",
        item.shotPct !== null ? String(item.shotPct) : ""
      ].join(" ").toLowerCase().includes(gameQuery);
    })
    .sort((a, b) => gameSort === "oldest" ? a.date.localeCompare(b.date) : b.date.localeCompare(a.date));
  if (!items.length) {
    tbody.innerHTML = "";
    empty.classList.remove("is-hidden");
  } else {
    empty.classList.add("is-hidden");
    tbody.innerHTML = items.map(item => `
      <tr class="log-row${expandedGameId === item.id ? " is-expanded" : ""}" tabindex="0" role="button" data-action="toggle-game-expand" data-id="${escapeHtml(item.id)}" aria-expanded="${expandedGameId === item.id ? "true" : "false"}">
        <td class="mono">${escapeHtml(fmtDate(item.date))}</td>
        <td><strong>${escapeHtml(item.opponent || "Unknown Opponent")}</strong><br /><span class="muted">${escapeHtml(item.rink || "No rink saved")}</span><br /><span class="mobile-row-hint">Tap to expand</span></td>
        <td>${(item.us !== null && item.them !== null) ? `<span class="score-pill">${escapeHtml(String(item.us))}-${escapeHtml(String(item.them))}</span>` : '<span class="muted">—</span>'}</td>
        <td>${item.shotPct !== null ? `<span class="badge mono">${escapeHtml(String(item.shotPct))}%</span>` : '<span class="muted">—</span>'}</td>
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
  renderViewContext();
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
    empty.classList.remove("is-hidden");
  } else {
    empty.classList.add("is-hidden");
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
    : renderEmpty("broom", "No drill patterns yet.", null, "No practice pattern yet");
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
    empty.classList.remove("is-hidden");
  } else {
    empty.classList.add("is-hidden");
    list.innerHTML = items.map(item => `
      <div class="card-sm">
        <div class="card-head">
          <div>
            <h3 class="card-title">${escapeHtml(item.rink || "Unknown Rink")}</h3>
            <div class="muted">${escapeHtml(fmtDate(item.date))}${item.sheet ? ` • Sheet ${escapeHtml(item.sheet)}` : ""}</div>
          </div>
          <div class="inline-actions">
            <button type="button" class="btn btn-ghost btn-sm" data-open-modal="ice" data-id="${escapeHtml(item.id)}">Edit</button>
            <button type="button" class="btn btn-danger btn-sm" data-action="delete-entry" data-type="ice" data-id="${escapeHtml(item.id)}">Delete</button>
          </div>
        </div>
        <div class="pill-row">
          <span class="badge mono">${escapeHtml(speedText(item.speed))}</span>
          ${item.curl ? `<span class="type-chip type-other">${escapeHtml(item.curl)}</span>` : ""}
          ${item.frostLevel ? `<span class="type-chip type-practice">${escapeHtml(`Frost ${item.frostLevel}`)}</span>` : ""}
          ${item.confidence ? `<span class="badge mono">${escapeHtml(`Conf ${item.confidence}/5`)}</span>` : ""}
        </div>
        ${item.notes ? `<div class="event-notes" style="margin-top:10px;">${escapeHtml(item.notes)}</div>` : ""}
        ${(item.pebbleFeel || item.hackCondition) ? `<div class="muted" style="margin-top:8px;">${escapeHtml([item.pebbleFeel ? `Pebble ${item.pebbleFeel}` : "", item.hackCondition ? `Hacks ${item.hackCondition}` : ""].filter(Boolean).join(" • "))}</div>` : ""}
      </div>
    `).join("");
  }

  const byRink = {};
  items.forEach(item => {
    const name = item.rink || "Unknown Rink";
    byRink[name] = (byRink[name] || 0) + 1;
  });
  const summary = Object.entries(byRink).sort((a, b) => b[1] - a[1]);
  const recentTimeline = (state.rinkConditionEntries || [])
    .slice()
    .sort((a, b) => `${b.recordedAt}`.localeCompare(`${a.recordedAt}`))
    .slice(0, 5);
  document.getElementById("rinkSummary").innerHTML = recentTimeline.length
    ? `
      <div class="summary-row"><div class="summary-name">Recent condition reads</div><div class="summary-count">${recentTimeline.length}</div></div>
      ${recentTimeline.map((entry) => `
        <div class="card-sm rink-timeline-card">
          <div class="summary-row">
            <span class="summary-name">${escapeHtml(getRinkById(entry.rinkId)?.name || "Unknown Rink")}</span>
            <span class="summary-count">${escapeHtml(fmtDate(String(entry.recordedAt).slice(0, 10), false))}</span>
          </div>
          <div class="pill-row">
            ${entry.speedEstimate ? `<span class="badge mono">${escapeHtml(speedText(entry.speedEstimate))}</span>` : ""}
            ${entry.curlLabel ? `<span class="type-chip type-other">${escapeHtml(entry.curlLabel)}</span>` : ""}
          </div>
          ${entry.notes ? `<div class="event-notes" style="margin-top:8px;">${escapeHtml(entry.notes)}</div>` : ""}
        </div>
      `).join("")}
      ${summary.map(([name, count]) => `
        <div class="summary-row">
          <div class="summary-name">${escapeHtml(name)}</div>
          <div class="summary-count">${count} note${count === 1 ? "" : "s"}</div>
        </div>
      `).join("")}
    `
    : renderEmpty("ice", "Start logging rink behavior to build memory.", null, "Rink memory starts here");
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
    empty.classList.remove("is-hidden");
  } else {
    empty.classList.add("is-hidden");
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
    : renderEmpty("issue", "Add your first issue to start tracking.", null, "No issues tracked yet");
}

function renderPlannerEntries() {
  const target = document.getElementById("planner-entries");
  const entries = getPlannerEntriesList()
    .filter((entry) => plannerEntryHasContent(entry))
    .slice()
    .sort((a, b) => b.date.localeCompare(a.date));
  const filtered = entries.filter((entry) => entry.date !== plannerDate).slice(0, 6);
  target.innerHTML = filtered.length
    ? filtered.map((entry) => `
      <div class="card-sm planner-entry-card" data-action="planner-jump" data-date="${escapeHtml(entry.date)}">
        <div class="card-head">
          <div>
            <h3 class="card-title">${escapeHtml(fmtDate(entry.date))}</h3>
            <div class="muted">${escapeHtml(entry.opponent || "No opponent set")}</div>
          </div>
          <div class="pill-row">
            ${entry.position ? `<span class="position-badge ${positionClass(entry.position)}">${escapeHtml(entry.position)}</span>` : ""}
            <span class="type-chip">${escapeHtml(getPlannerReviewLabel(entry))}</span>
          </div>
        </div>
        ${(entry.scoreUs || entry.scoreThem) ? `<div class="score-pill">${escapeHtml(entry.scoreUs || "0")}-${escapeHtml(entry.scoreThem || "0")}</div>` : ""}
        ${entry.checklist && entry.checklist.length ? `<div class="muted" style="margin-top:8px;">Checklist ${escapeHtml(String(entry.checklist.filter(item => item.checked).length))}/${escapeHtml(String(entry.checklist.length))}</div>` : ""}
        <div class="event-notes" style="margin-top:10px;">${escapeHtml(getPlannerGoalSummary(entry))}</div>
        ${getPlannerReviewStatus(entry) !== "none" ? `<div class="muted" style="margin-top:8px;">${escapeHtml((entry.nextFocus || entry.keyTakeaways || entry.reflection || "").slice(0, 120))}${(entry.nextFocus || entry.keyTakeaways || entry.reflection || "").length > 120 ? "…" : ""}</div>` : ""}
      </div>
    `).join("")
    : renderEmpty("note", "No other planner entries saved yet.", null, "No archived planner notes");
}

function updatePlannerLabel() {
  document.getElementById("planner-label").textContent = fmtDate(plannerDate);
}

function loadPlanner() {
  const savedEntry = getPlannerEntryForDate(plannerDate);
  const entry = savedEntry || getPlannerDefaults(plannerDate);
  document.getElementById("pg-time").value = entry.time || "";
  document.getElementById("pg-rink").value = entry.rink || "";
  document.getElementById("pg-opponent").value = entry.opponent || "";
  document.getElementById("pg-position").value = entry.position || "";
  const goals = getPlannerGoals(entry);
  document.getElementById("pg-goal-1").value = goals[0] || "";
  document.getElementById("pg-goal-2").value = goals[1] || "";
  document.getElementById("pg-goal-3").value = goals[2] || "";
  document.getElementById("pg-score-us").value = entry.scoreUs || "";
  document.getElementById("pg-score-them").value = entry.scoreThem || "";
  document.getElementById("pg-ice").value = entry.ice || "";
  document.getElementById("pg-rating-draw").value = entry.drawRating || "";
  document.getElementById("pg-rating-takeout").value = entry.takeoutRating || "";
  document.getElementById("pg-rating-communication").value = entry.communicationRating || "";
  document.getElementById("pg-rating-sweeping").value = entry.sweepingRating || "";
  document.getElementById("pg-rating-mental").value = entry.mentalRating || "";
  document.getElementById("pg-takeaways").value = entry.keyTakeaways || entry.reflection || "";
  document.getElementById("pg-next-focus").value = entry.nextFocus || "";
  document.getElementById("pg-keyshot").value = entry.keyShot || "";
  plannerChecklist = entry.checklist && entry.checklist.length ? cloneChecklist(entry.checklist) : loadChecklistDefaults();
  renderPlannerChecklist();
  renderPlannerStateStrip(Boolean(savedEntry));
  renderGameDayBanner();
  renderPlannerRinkProfile();
}

function renderPlannerStateStrip(hasSavedEntry) {
  const target = document.getElementById("plannerStateStrip");
  if (!target) return;
  const entry = getPlannerEntryForDate(plannerDate);
  const reviewLabel = entry ? getPlannerReviewLabel(entry) : "Review pending";
  target.innerHTML = hasSavedEntry
    ? renderStateStrip("active", "Planner entry in progress", `${reviewLabel}. Changes save in the background while you edit this date.`, { label: "Save Snapshot", attr: 'id="plannerStateSaveCopy" data-save-planner-inline="true"' })
    : renderStateStrip("empty", "Start this planner entry", "Defaults pulled from matching event timing and your recent rink memory.", { label: "Use Today", attr: 'data-action="planner-jump" data-date="' + escapeHtml(todayStr()) + '"' });
}

function renderPlannerRinkProfile() {
  const target = document.getElementById("plannerRinkProfile");
  if (!target) return;
  const plannerEntry = getPlannerEntryForDate(plannerDate) || getPlannerDefaults(plannerDate);
  const linkedEvent = getPlannerLinkedEvent(plannerDate, plannerEntry);
  const rinkId = plannerEntry.rinkId || linkedEvent?.rinkId || "";
  const sheetId = plannerEntry.sheetId || linkedEvent?.sheetId || "";
  const profile = rinkId ? getLatestRinkProfile(rinkId, sheetId) : null;
  if (!rinkId && !plannerEntry.rink && !linkedEvent?.rink) {
    target.innerHTML = "";
    return;
  }
  target.innerHTML = renderRinkProfileCard(
    profile,
    plannerEntry.rink || linkedEvent?.rink || getRinkById(rinkId)?.name || "Rink profile",
    plannerEntry.sheet || linkedEvent?.sheet || "",
    "No rink memory yet for this planner"
  );
}

function renderGameDayBanner() {
  const target = document.getElementById("gameDayBanner");
  const bridge = document.getElementById("plannerGameBridge");
  if (!target) return;
  if (bridge) bridge.innerHTML = "";
  const plannerEntry = getPlannerEntryForDate(plannerDate) || null;
  const linkedEvent = getPlannerLinkedEvent(plannerDate, plannerEntry);
  const plannerOpponent = asString(plannerEntry?.opponent);
  const plannerHasBridge = Boolean(plannerOpponent || linkedEvent);
  if (!linkedEvent && !plannerHasBridge) {
    target.innerHTML = "";
    return;
  }
  const opponent = plannerOpponent || linkedEvent?.opponent || linkedEvent?.title || "this game";
  const existingGame = state.games.find((item) => item.date === plannerDate && (!plannerOpponent || asString(item.opponent).toLowerCase() === plannerOpponent.toLowerCase()));
  if (existingGame) {
    target.innerHTML = renderStateStrip("completed", `Game already logged for ${opponent}`, `${fmtDate(plannerDate, false)}${linkedEvent?.rink ? ` • ${linkedEvent.rink}` : ""}`, { label: "Open Game Log", attr: 'data-view="games"' });
  } else if (linkedEvent) {
    target.innerHTML = renderStateStrip("completed", `Game day focus for ${linkedEvent.title}`, `${fmtDate(plannerDate, false)}${linkedEvent.time ? ` at ${fmtTime(linkedEvent.time)}` : ""}${linkedEvent.rink ? ` • ${linkedEvent.rink}` : ""}`, { label: "Open Event", attr: `data-open-modal="event" data-id="${escapeHtml(linkedEvent.id)}"` });
  } else {
    target.innerHTML = renderStateStrip("active", `Planner is ready for ${opponent}`, `${fmtDate(plannerDate, false)}${plannerEntry?.rink ? ` • ${plannerEntry.rink}` : ""}`, null);
  }
  if (bridge) {
    if (existingGame) {
      bridge.innerHTML = renderStateStrip("completed", "Game already in the log", "Use the game log to edit the saved result or print a report.", { label: "Open Game Log", attr: 'data-view="games"' });
    } else if (plannerHasBridge) {
      bridge.innerHTML = renderStateStrip("active", "Ready to log this game", "Use your planner date, opponent, rink, and position as the starting point.", { label: "Log This Game", attr: `data-action="planner-log-game" data-date="${escapeHtml(plannerDate)}"` });
    }
  }
}

function savePlanner(options = {}) {
  const existingEntry = getPlannerEntryForDate(plannerDate);
  const linkedEvent = getPlannerLinkedEvent(plannerDate, {
    date: plannerDate,
    rink: asString(document.getElementById("pg-rink").value),
    opponent: asString(document.getElementById("pg-opponent").value)
  });
  const goalOne = asString(document.getElementById("pg-goal-1").value);
  const goalTwo = asString(document.getElementById("pg-goal-2").value);
  const goalThree = asString(document.getElementById("pg-goal-3").value);
  const keyTakeaways = asString(document.getElementById("pg-takeaways").value);
  const nextFocus = asString(document.getElementById("pg-next-focus").value);
  const reviewRatings = {
    drawRating: document.getElementById("pg-rating-draw").value,
    takeoutRating: document.getElementById("pg-rating-takeout").value,
    communicationRating: document.getElementById("pg-rating-communication").value,
    sweepingRating: document.getElementById("pg-rating-sweeping").value,
    mentalRating: document.getElementById("pg-rating-mental").value
  };
  const entry = {
    eventId: linkedEvent?.id || "",
    date: plannerDate,
    time: asString(document.getElementById("pg-time").value),
    rink: asString(document.getElementById("pg-rink").value),
    rinkId: linkedEvent?.rinkId || "",
    sheet: linkedEvent?.sheet || "",
    sheetId: linkedEvent?.sheetId || "",
    opponent: asString(document.getElementById("pg-opponent").value),
    position: normalizePosition(document.getElementById("pg-position").value),
    goalOne,
    goalTwo,
    goalThree,
    goals: [goalOne, goalTwo, goalThree].filter(Boolean).join(" • "),
    scoreUs: asString(document.getElementById("pg-score-us").value),
    scoreThem: asString(document.getElementById("pg-score-them").value),
    ice: asString(document.getElementById("pg-ice").value),
    ...reviewRatings,
    keyTakeaways,
    nextFocus,
    reflection: keyTakeaways,
    keyShot: asString(document.getElementById("pg-keyshot").value),
    checklist: checklistHasMeaningfulState(plannerChecklist) ? cloneChecklist(plannerChecklist) : []
  };
  const hasPrepContent = [entry.time, entry.rink, entry.opponent, entry.position, entry.goalOne, entry.goalTwo, entry.goalThree, entry.ice].some((value) => asString(value)) || checklistHasMeaningfulState(entry.checklist);
  const reviewStatus = getPlannerReviewStatus(entry);
  entry.prepCompletedAt = hasPrepContent ? existingEntry?.prepCompletedAt || new Date().toISOString() : "";
  entry.reviewCompletedAt = reviewStatus !== "none" ? existingEntry?.reviewCompletedAt || new Date().toISOString() : "";
  if (plannerEntryHasContent(entry)) upsertPlannerEntryForDate(plannerDate, entry);
  else removePlannerEntryForDate(plannerDate);
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
    showPlannerSaveStatus("Saved ✓");
  } else {
    setStatus("Planner autosaved.", "success");
    showPlannerSaveStatus("Saved ✓");
  }
  return entry;
}

function printGameReport(gameId) {
  const game = state.games.find(item => item.id === gameId);
  if (!game) {
    setStatus("Could not find that game to print.", "error");
    return;
  }
  const plannerEntry = getPlannerEntryByEventId(game.eventId) || getPlannerEntryForDate(game.date) || null;
  const linkedLineup = game.lineupId
    ? (state.lineups || []).find((item) => item.id === game.lineupId) || null
    : getLineupByEventId(game.eventId);
  const iceEntries = state.ice.filter(item => item.date === game.date);
  const checklistItems = plannerEntry && plannerEntry.checklist ? plannerEntry.checklist : [];
  const checklistDone = checklistItems.filter(item => item.checked).length;
  const report = document.getElementById("printReport");
  printedGameId = gameId;
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
          <div class="report-metric">${game.us !== null && game.them !== null ? `${escapeHtml(String(game.us))}-${escapeHtml(String(game.them))}` : "—"}</div>
          <div class="report-subtitle">${escapeHtml(game.result || "No result logged")}${game.shotPct !== null ? ` • Shot ${escapeHtml(String(game.shotPct))}%` : ""}</div>
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
          <h3>Lineup</h3>
          ${linkedLineup ? `
            <div class="report-lines">
              ${LINEUP_ALL_SLOTS.filter(({ key }) => asString(linkedLineup.assignments?.[key])).map(({ key, label }) => `<div><strong>${escapeHtml(label)}:</strong> ${escapeHtml(linkedLineup.assignments[key])}</div>`).join("") || `<div><strong>Summary:</strong> ${escapeHtml(getLineupSummary(linkedLineup))}</div>`}
              <div><strong>Opponent Roster:</strong> ${escapeHtml(linkedLineup.opponents || "—")}</div>
              <div class="report-note">${escapeHtml(linkedLineup.notes || "No lineup notes saved.")}</div>
            </div>
          ` : '<div class="report-note">No lineup saved for this game.</div>'}
        </div>
      <div class="report-block">
        <h3>Planner Entry</h3>
        ${plannerEntry ? `
            ${renderPlannerGoalList(plannerEntry)}
            ${renderPlannerReviewDetails(plannerEntry)}
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
  renderViewContext();
  window.setTimeout(() => window.print(), 60);
}

function clearPrintReport() {
  const report = document.getElementById("printReport");
  report.innerHTML = "";
  report.setAttribute("aria-hidden", "true");
  document.body.classList.remove("printing-report");
  printedGameId = null;
  renderViewContext();
}
