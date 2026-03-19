// CurlPlan actions, modal flows, persistence triggers, and full rerender
let modalDirtyState = {
  modalId: "",
  baseline: "",
  dirty: false
};
let plannerGamePrefillDate = "";
let plannerGameToastTargetId = "";

function setModalTitle(type, isEdit) {
  const labels = {
    event: ["Add Event", "Edit Event"],
    game: ["Log Game", "Edit Game"],
    practice: ["Log Practice", "Edit Practice"],
    ice: ["Add Ice Notes", "Edit Ice Notes"],
    issue: ["Add Issue", "Edit Issue"]
  };
  const target = document.getElementById(`${type}ModalTitle`);
  if (!target || !labels[type]) return;
  target.textContent = labels[type][isEdit ? 1 : 0];
}

function showPlannerSaveStatus(message = "Saved") {
  const target = document.getElementById("plannerSaveStatus");
  if (!target) return;
  target.textContent = message;
  target.classList.add("is-visible");
  window.clearTimeout(target._hideTimer);
  target._hideTimer = window.setTimeout(() => {
    target.classList.remove("is-visible");
  }, 1500);
}

function isDirtyTrackableModal(modalId) {
  return ["modal-event", "modal-game", "modal-practice", "modal-ice", "modal-issue"].includes(modalId);
}

function serializeModalFields(modalId) {
  const overlay = document.getElementById(modalId);
  if (!overlay) return "";
  const values = Array.from(overlay.querySelectorAll("input, select, textarea")).map((field) => {
    const key = field.id || field.name || field.type || field.tagName;
    if (field.type === "checkbox" || field.type === "radio") {
      return [key, Boolean(field.checked)];
    }
    return [key, field.value];
  });
  if (modalId === "modal-ice") {
    values.push(["speed", currentSpeed]);
  }
  return JSON.stringify(values);
}

function resetModalDirty(modalId) {
  if (!isDirtyTrackableModal(modalId)) {
    modalDirtyState = { modalId: "", baseline: "", dirty: false };
    return;
  }
  modalDirtyState = {
    modalId,
    baseline: serializeModalFields(modalId),
    dirty: false
  };
}

function markModalDirty(modalId) {
  if (!isDirtyTrackableModal(modalId) || modalDirtyState.modalId !== modalId) return;
  modalDirtyState.dirty = serializeModalFields(modalId) !== modalDirtyState.baseline;
}

function bindModalDirtyTracking(modalId) {
  const overlay = document.getElementById(modalId);
  if (!overlay || !isDirtyTrackableModal(modalId) || overlay.dataset.dirtyBound === "true") return;
  const syncDirty = () => markModalDirty(modalId);
  overlay.querySelectorAll("input, select, textarea").forEach((field) => {
    field.addEventListener("input", syncDirty);
    field.addEventListener("change", syncDirty);
  });
  overlay.dataset.dirtyBound = "true";
}

function plannerNav(dir) {
  const date = new Date(`${plannerDate}T00:00:00`);
  date.setDate(date.getDate() + Number(dir));
  plannerDate = [date.getFullYear(), String(date.getMonth() + 1).padStart(2, "0"), String(date.getDate()).padStart(2, "0")].join("-");
  saveUiPrefs({ ...uiPrefs, lastPlannerDate: plannerDate });
  updatePlannerLabel();
  loadPlanner();
  renderPlannerEntries();
}

function setSpeed(value) {
  currentSpeed = Number(value);
  document.querySelectorAll(".speed-dot").forEach(dot => {
    dot.classList.toggle("active", Number(dot.dataset.speed) <= currentSpeed);
    dot.setAttribute("aria-checked", Number(dot.dataset.speed) === currentSpeed ? "true" : "false");
  });
  speedLabel.textContent = speedText(currentSpeed);
  markModalDirty("modal-ice");
}

function getBonspielParentEvents(excludeEventId = "") {
  return state.events
    .filter((item) => item.type === "bonspiel" && item.id !== excludeEventId)
    .slice()
    .sort(compareDateTime);
}

function renderBonspielParentOptions(selectedId = "", excludeEventId = "") {
  const target = document.getElementById("ev-bonspiel-parent");
  if (!target) return;
  const options = ['<option value="">Standalone event</option>']
    .concat(getBonspielParentEvents(excludeEventId).map((item) => `<option value="${escapeHtml(item.id)}"${item.id === selectedId ? " selected" : ""}>${escapeHtml(item.title)} • ${escapeHtml(fmtDate(item.date, false))}</option>`));
  target.innerHTML = options.join("");
}

function getBonspielModalDraft(eventId = "") {
  const eventType = normalizeType(document.getElementById("ev-type").value);
  const parentId = eventType === "bonspiel" ? "" : asString(document.getElementById("ev-bonspiel-parent").value);
  return normalizeBonspiel({
    id: eventId || createId(),
    title: asString(document.getElementById("ev-name").value),
    startDate: asString(document.getElementById("ev-date").value),
    endDate: asString(document.getElementById("ev-bonspiel-end").value) || asString(document.getElementById("ev-date").value),
    rinkId: "",
    venue: asString(document.getElementById("ev-location").value),
    hotel: asString(document.getElementById("ev-bonspiel-hotel").value),
    travel: asString(document.getElementById("ev-bonspiel-travel").value),
    packing: asString(document.getElementById("ev-bonspiel-packing").value),
    budget: asString(document.getElementById("ev-bonspiel-budget").value),
    teammates: asString(document.getElementById("ev-bonspiel-teammates").value),
    bracketStage: asString(document.getElementById("ev-bonspiel-stage").value),
    notes: asString(document.getElementById("ev-notes").value),
    parentId
  });
}

function showView(name) {
  currentView = name;
  saveUiPrefs({ ...uiPrefs, lastView: name });
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
  if (name === "calendar") {
    currentFilter = uiPrefs.calendarFilter || "all";
    if (filterType) filterType.value = currentFilter;
    document.querySelectorAll("#filter-bar [data-filter]").forEach(button => {
      button.classList.toggle("active-filter", button.dataset.filter === currentFilter);
    });
  }
  if (window.location.hash !== `#${name}`) {
    window.history.replaceState(null, "", `#${name}`);
  }
  animateView(name);
  renderSuggestedNext();
  renderViewContext();
}

function resetModal(type) {
  modalState[type] = null;
  if (type === "event") {
    setModalTitle("event", false);
    renderBonspielParentOptions("", "");
    document.getElementById("ev-name").value = "";
    document.getElementById("ev-date").value = todayStr();
    document.getElementById("ev-time").value = "";
    document.getElementById("ev-type").value = "league";
    document.getElementById("ev-position").value = "";
    document.getElementById("ev-location").value = "";
    document.getElementById("ev-sheet").value = "";
    document.getElementById("ev-notes").value = "";
    document.getElementById("ev-bonspiel-parent").value = "";
    document.getElementById("ev-bonspiel-end").value = todayStr();
    document.getElementById("ev-bonspiel-hotel").value = "";
    document.getElementById("ev-bonspiel-budget").value = "";
    document.getElementById("ev-bonspiel-teammates").value = "";
    document.getElementById("ev-bonspiel-stage").value = "";
    document.getElementById("ev-bonspiel-travel").value = "";
    document.getElementById("ev-bonspiel-packing").value = "";
    document.getElementById("eventDeleteBtn").classList.add("hidden");
  }
  if (type === "game") {
    setModalTitle("game", false);
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
    setModalTitle("practice", false);
    document.getElementById("pr-date").value = todayStr();
    document.getElementById("pr-duration").value = "60 min";
    document.querySelectorAll(".pr-shot").forEach(input => input.checked = false);
    document.getElementById("pr-focus").value = "";
    document.getElementById("pr-notes").value = "";
    document.getElementById("practiceDeleteBtn").classList.add("hidden");
  }
  if (type === "ice") {
    setModalTitle("ice", false);
    document.getElementById("ice-date").value = todayStr();
    document.getElementById("ice-rink").value = "";
    document.getElementById("ice-sheet").value = "";
    document.getElementById("ice-confidence").value = "";
    document.getElementById("ice-curl").value = "";
    document.getElementById("ice-frost").value = "";
    document.getElementById("ice-pebble").value = "";
    document.getElementById("ice-hack").value = "";
    document.getElementById("ice-notes-text").value = "";
    document.getElementById("iceDeleteBtn").classList.add("hidden");
    setSpeed(0);
  }
  if (type === "issue") {
    setModalTitle("issue", false);
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
  if (["event", "game", "practice", "ice"].includes(type)) {
    saveUiPrefs({ ...uiPrefs, quickLogType: type });
  }

  if (type === "event" && item) {
    setModalTitle("event", true);
    renderBonspielParentOptions(item.bonspielId || "", item.id);
    const bonspiel = item.type === "bonspiel" ? getBonspielById(item.id) : item.bonspielId ? getBonspielById(item.bonspielId) : null;
    document.getElementById("ev-name").value = item.title;
    document.getElementById("ev-date").value = item.date;
    document.getElementById("ev-time").value = item.time;
    document.getElementById("ev-type").value = item.type;
    document.getElementById("ev-position").value = item.position;
    document.getElementById("ev-location").value = item.rink;
    document.getElementById("ev-sheet").value = item.sheet;
    document.getElementById("ev-notes").value = item.notes;
    document.getElementById("ev-bonspiel-parent").value = item.type === "bonspiel" ? "" : item.bonspielId || "";
    document.getElementById("ev-bonspiel-end").value = bonspiel?.endDate || item.date;
    document.getElementById("ev-bonspiel-hotel").value = bonspiel?.hotel || "";
    document.getElementById("ev-bonspiel-budget").value = bonspiel?.budget || "";
    document.getElementById("ev-bonspiel-teammates").value = bonspiel?.teammates || "";
    document.getElementById("ev-bonspiel-stage").value = bonspiel?.bracketStage || "";
    document.getElementById("ev-bonspiel-travel").value = bonspiel?.travel || "";
    document.getElementById("ev-bonspiel-packing").value = bonspiel?.packing || "";
    document.getElementById("eventDeleteBtn").classList.remove("hidden");
  }

  if (type === "game" && item) {
    setModalTitle("game", true);
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
    setModalTitle("practice", true);
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
    setModalTitle("ice", true);
    document.getElementById("ice-date").value = item.date;
    document.getElementById("ice-rink").value = item.rink;
    document.getElementById("ice-sheet").value = item.sheet || "";
    document.getElementById("ice-confidence").value = item.confidence || "";
    document.getElementById("ice-curl").value = item.curl;
    document.getElementById("ice-frost").value = item.frostLevel || "";
    document.getElementById("ice-pebble").value = item.pebbleFeel || "";
    document.getElementById("ice-hack").value = item.hackCondition || "";
    document.getElementById("ice-notes-text").value = item.notes;
    document.getElementById("iceDeleteBtn").classList.remove("hidden");
    setSpeed(item.speed);
  }

  if (type === "issue" && item) {
    setModalTitle("issue", true);
    document.getElementById("is-component").value = item.component;
    document.getElementById("is-severity").value = item.severity;
    document.getElementById("is-description").value = item.description;
    document.getElementById("is-status").value = item.status;
    document.getElementById("is-fix").value = item.proposedFix;
    document.getElementById("issueDeleteBtn").classList.remove("hidden");
  }

  clearFieldErrors(modalId);
  overlay.classList.add("open");
  bindModalDirtyTracking(modalId);
  resetModalDirty(modalId);
  trapFocus(overlay);
  focusFirstField(modalId);
}

function closeModal(modalId) {
  const overlay = document.getElementById(modalId);
  if (overlay && isDirtyTrackableModal(modalId) && modalDirtyState.modalId === modalId && modalDirtyState.dirty) {
    if (!window.confirm("Discard unsaved changes?")) return;
  }
  if (overlay) overlay.classList.remove("open");
  resetModalDirty("");
  releaseFocusTrap();
}

function upsertEntry(collectionName, entry) {
  const index = state[collectionName].findIndex(item => item.id === entry.id);
  if (index >= 0) state[collectionName][index] = entry;
  else state[collectionName].push(entry);
  saveState();
  renderAll();
}

function clearLineupFieldErrors() {
  const target = document.getElementById("eventDetail");
  if (!target) return;
  target.querySelectorAll(".has-error").forEach((row) => row.classList.remove("has-error"));
  target.querySelectorAll(".field-error").forEach((el) => el.remove());
}

function readLineupDraft(eventId) {
  const existing = getLineupByEventId(eventId);
  const assignments = LINEUP_ALL_SLOTS.reduce((acc, { key }) => {
    acc[key] = asString(document.getElementById(`lineup-${key}`)?.value);
    return acc;
  }, {});
  return {
    id: existing?.id || createId(),
    eventId,
    presetId: asString(document.getElementById("lineupPresetSelect")?.value),
    assignments,
    opponents: asString(document.getElementById("lineup-opponents")?.value),
    notes: asString(document.getElementById("lineup-notes")?.value)
  };
}

function lineupHasContent(entry) {
  if (!entry || typeof entry !== "object") return false;
  const filledAssignments = LINEUP_ALL_SLOTS.some(({ key }) => asString(entry.assignments?.[key]));
  return filledAssignments || asString(entry.opponents) || asString(entry.notes);
}

function validateLineupEntry(entry) {
  clearLineupFieldErrors();
  const seenNames = new Map();
  let hasError = false;
  LINEUP_ALL_SLOTS.forEach(({ key, label }) => {
    const value = asString(entry.assignments?.[key]);
    if (!value) return;
    const lowered = value.toLowerCase();
    if (seenNames.has(lowered)) {
      markFieldError(`lineup-${key}`, `${label} duplicates ${seenNames.get(lowered)}`);
      hasError = true;
      return;
    }
    seenNames.set(lowered, label);
  });
  if (hasError) setStatus("Each lineup slot needs a unique player name.", "error");
  return !hasError;
}

function syncEventLineup(eventId, lineupId) {
  state.events = state.events.map((item) => item.id === eventId ? { ...item, lineupId } : item);
  state.games = state.games.map((item) => item.eventId === eventId ? { ...item, lineupId } : item);
}

function saveLineup(options = {}) {
  const eventId = options.eventId || selectedEventId;
  const event = state.events.find((item) => item.id === eventId);
  if (!event) {
    setStatus("Select an event before saving a lineup.", "error");
    return null;
  }
  const entry = normalizeLineup({
    ...readLineupDraft(eventId),
    presetId: options.presetId || asString(document.getElementById("lineupPresetSelect")?.value)
  });
  if (!validateLineupEntry(entry)) return null;
  if (!lineupHasContent(entry)) {
    state.lineups = (state.lineups || []).filter((item) => item.eventId !== eventId);
    syncEventLineup(eventId, "");
    saveState();
    renderAll();
    if (!options.silent) {
      setStatus("Lineup cleared.", "success");
      showToast("Lineup cleared");
    }
    return null;
  }
  const existing = getLineupByEventId(eventId);
  const nextEntry = {
    ...(existing || {}),
    ...entry,
    id: existing?.id || entry.id || createId(),
    eventId
  };
  state.lineups = (state.lineups || []).filter((item) => item.eventId !== eventId).concat(nextEntry);
  syncEventLineup(eventId, nextEntry.id);
  saveState();
  renderAll();
  if (!options.silent) {
    setStatus("Lineup saved.", "success");
    showToast("Lineup saved");
  }
  return nextEntry;
}

function loadLineupPresetIntoForm(presetId) {
  const preset = getLineupPresetById(presetId);
  if (!preset) {
    setStatus("Choose a saved lineup preset first.", "error");
    return;
  }
  document.getElementById("lineupPresetSelect").value = preset.id;
  LINEUP_ALL_SLOTS.forEach(({ key }) => {
    const field = document.getElementById(`lineup-${key}`);
    if (field) field.value = preset.assignments?.[key] || "";
  });
  if (document.getElementById("lineup-notes")) document.getElementById("lineup-notes").value = preset.notes || "";
  setStatus("Lineup preset loaded.", "success");
}

function saveLineupPreset() {
  const eventId = selectedEventId;
  const event = state.events.find((item) => item.id === eventId);
  if (!event) {
    setStatus("Select an event before saving a lineup preset.", "error");
    return;
  }
  const draft = normalizeLineup(readLineupDraft(eventId));
  if (!validateLineupEntry(draft)) return;
  if (!lineupHasContent(draft)) {
    setStatus("Add at least one player or lineup note before saving a preset.", "error");
    return;
  }
  const activePreset = getLineupPresetById(draft.presetId);
  const suggestedName = activePreset?.name || `${event.title} Core`;
  const name = asString(window.prompt("Save lineup preset as", suggestedName));
  if (!name) return;
  const preset = normalizeLineupPreset({
    id: activePreset?.id || createId(),
    name,
    assignments: draft.assignments,
    notes: draft.notes
  });
  state.lineupPresets = getLineupPresetsList()
    .filter((item) => item.id !== preset.id)
    .concat(preset)
    .sort((a, b) => a.name.localeCompare(b.name));
  saveLineup({ presetId: preset.id, silent: true });
  setStatus("Lineup preset saved.", "success");
  showToast("Lineup preset saved");
}

function clearLineupDraft() {
  LINEUP_ALL_SLOTS.forEach(({ key }) => {
    const field = document.getElementById(`lineup-${key}`);
    if (field) field.value = "";
  });
  if (document.getElementById("lineupPresetSelect")) document.getElementById("lineupPresetSelect").value = "";
  if (document.getElementById("lineup-opponents")) document.getElementById("lineup-opponents").value = "";
  if (document.getElementById("lineup-notes")) document.getElementById("lineup-notes").value = "";
  clearLineupFieldErrors();
  setStatus("Lineup draft cleared.", "success");
}

function collectionNameForType(type) {
  return type === "issue" ? "issues" : type === "ice" ? "ice" : type === "practice" ? "practice" : type === "game" ? "games" : "events";
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
  const type = normalizeType(document.getElementById("ev-type").value);
  const bonspielParentId = type === "bonspiel" ? "" : asString(document.getElementById("ev-bonspiel-parent").value);
  const entry = {
    id: modalState.event || createId(),
    title,
    type,
    status: existing?.status || "scheduled",
    date,
    time: asString(document.getElementById("ev-time").value),
    rinkId: existing?.rinkId || "",
    rink: asString(document.getElementById("ev-location").value),
    team: existing ? existing.team : "",
    opponent: existing ? existing.opponent : "",
    position: normalizePosition(document.getElementById("ev-position").value),
    sheetId: existing?.sheetId || "",
    sheet: asString(document.getElementById("ev-sheet").value),
    bonspielId: bonspielParentId,
    lineupId: existing?.lineupId || "",
    notes: asString(document.getElementById("ev-notes").value)
  };
  const eventIndex = state.events.findIndex((item) => item.id === entry.id);
  if (eventIndex >= 0) state.events[eventIndex] = entry;
  else state.events.push(entry);
  if (type === "bonspiel") {
    const bonspielEntry = normalizeBonspiel({
      id: entry.id,
      title,
      startDate: date,
      endDate: asString(document.getElementById("ev-bonspiel-end").value) || date,
      rinkId: entry.rinkId,
      venue: entry.rink,
      hotel: asString(document.getElementById("ev-bonspiel-hotel").value),
      travel: asString(document.getElementById("ev-bonspiel-travel").value),
      packing: asString(document.getElementById("ev-bonspiel-packing").value),
      budget: asString(document.getElementById("ev-bonspiel-budget").value),
      teammates: asString(document.getElementById("ev-bonspiel-teammates").value),
      bracketStage: asString(document.getElementById("ev-bonspiel-stage").value),
      notes: entry.notes
    });
    state.bonspiels = (state.bonspiels || []).filter((item) => item.id !== entry.id).concat(bonspielEntry);
  } else {
    state.bonspiels = (state.bonspiels || []).filter((item) => item.id !== entry.id);
    state.events = state.events.map((item) => item.bonspielId === entry.id ? { ...item, bonspielId: bonspielParentId } : item);
  }
  selectedEventId = entry.id;
  saveState();
  renderAll();
  resetModalDirty("modal-event");
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
  const shotPct = shotPctRaw === "" ? null : Math.max(0, Math.min(100, Number(shotPctRaw)));
  const linkedEvent = getPlannerLinkedEvent(date, {
    date,
    opponent,
    rink: asString(document.getElementById("gm-rink").value)
  });
  const entry = {
    id: modalState.game || createId(),
    eventId: existing?.eventId || linkedEvent?.id || "",
    date,
    opponent,
    us,
    them,
    result: computeResult(us, them),
    position: normalizePosition(document.getElementById("gm-position").value),
    positionPlayed: normalizePosition(document.getElementById("gm-position").value),
    rinkId: existing?.rinkId || "",
    rink: asString(document.getElementById("gm-rink").value),
    lineupId: existing?.lineupId || linkedEvent?.lineupId || "",
    keyShot: asString(document.getElementById("gm-keyshot").value),
    notes: asString(document.getElementById("gm-notes").value),
    shotPct: Number.isFinite(shotPct) ? shotPct : existing ? existing.shotPct : null
  };
  upsertEntry("games", entry);
  resetModalDirty("modal-game");
  closeModal("modal-game");
  setStatus("Game saved.", "success");
  if (plannerGamePrefillDate && plannerGamePrefillDate === entry.date) {
    plannerGamePrefillDate = "";
    plannerGameToastTargetId = entry.id;
    showToast("Game logged", {
      actionLabel: "View Game Log",
      onAction: () => {
        expandedGameId = plannerGameToastTargetId;
        showView("games");
        renderGames();
      }
    });
  } else {
    showToast("Game saved");
  }
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
    eventId: "",
    date,
    duration: asString(document.getElementById("pr-duration").value) || "60 min",
    shots: Array.from(document.querySelectorAll(".pr-shot:checked")).map(input => input.value),
    focus: asString(document.getElementById("pr-focus").value),
    notes: asString(document.getElementById("pr-notes").value)
  };
  entry.eventId = getPlannerLinkedEvent(date, { date })?.id || "";
  upsertEntry("practice", entry);
  resetModalDirty("modal-practice");
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
    eventId: existing?.eventId || getPlannerLinkedEvent(date, {
      date,
      rink: asString(document.getElementById("ice-rink").value),
      sheet: asString(document.getElementById("ice-sheet").value)
    })?.id || "",
    date,
    rinkId: existing?.rinkId || "",
    rink: asString(document.getElementById("ice-rink").value),
    sheetId: existing?.sheetId || "",
    sheet: asString(document.getElementById("ice-sheet").value),
    speed: currentSpeed,
    curl: asString(document.getElementById("ice-curl").value),
    frostLevel: asString(document.getElementById("ice-frost").value),
    pebbleFeel: asString(document.getElementById("ice-pebble").value),
    hackCondition: asString(document.getElementById("ice-hack").value),
    confidence: normalizeConfidence(document.getElementById("ice-confidence").value),
    notes: asString(document.getElementById("ice-notes-text").value)
  };
  upsertEntry("ice", entry);
  const storedIce = state.ice.find((item) => item.id === entry.id) || entry;
  const existingConditionIndex = (state.rinkConditionEntries || []).findIndex((item) => item.sourceIceId === entry.id);
  const linkedCondition = normalizeRinkConditionEntry({
    id: existingConditionIndex >= 0 ? state.rinkConditionEntries[existingConditionIndex].id : createId(),
    sourceIceId: storedIce.id,
    eventId: storedIce.eventId,
    rinkId: storedIce.rinkId,
    sheetId: storedIce.sheetId,
    recordedAt: `${storedIce.date}T12:00:00`,
    speedEstimate: storedIce.speed,
    curl: storedIce.curl,
    frostLevel: storedIce.frostLevel,
    pebbleFeel: storedIce.pebbleFeel,
    hackCondition: storedIce.hackCondition,
    confidence: storedIce.confidence,
    notes: storedIce.notes
  });
  if (existingConditionIndex >= 0) state.rinkConditionEntries[existingConditionIndex] = linkedCondition;
  else state.rinkConditionEntries.push(linkedCondition);
  saveState();
  renderAll();
  resetModalDirty("modal-ice");
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
  resetModalDirty("modal-issue");
  closeModal("modal-issue");
  setStatus("Issue saved.", "success");
  showToast("Issue saved");
}

function restoreDeletedEntry(type, snapshot) {
  const collectionName = collectionNameForType(type);
  const nextItems = state[collectionName].slice();
  nextItems.splice(snapshot.index, 0, snapshot.entry);
  state[collectionName] = nextItems;
  if (type === "event" && Array.isArray(snapshot.relatedLineups) && snapshot.relatedLineups.length) {
    state.lineups = (state.lineups || []).concat(snapshot.relatedLineups);
    const restoredLineupIds = snapshot.relatedLineups.map((item) => item.id);
    state.games = state.games.map((item) => {
      const restoredLineup = snapshot.relatedLineups.find((lineup) => lineup.eventId === item.eventId || restoredLineupIds.includes(item.lineupId));
      return restoredLineup ? { ...item, lineupId: restoredLineup.id } : item;
    });
  }
  if (type === "event" && snapshot.relatedBonspiel) {
    state.bonspiels = (state.bonspiels || []).filter((item) => item.id !== snapshot.relatedBonspiel.id).concat(snapshot.relatedBonspiel);
  }
  if (type === "event" && Array.isArray(snapshot.relatedBonspielChildren) && snapshot.relatedBonspielChildren.length) {
    const childIds = new Set(snapshot.relatedBonspielChildren.map((item) => item.id));
    state.events = state.events.map((item) => childIds.has(item.id) ? { ...item, bonspielId: snapshot.entry.id } : item);
  }
  if (type === "event") {
    selectedEventId = snapshot.entry.id;
  }
  saveState();
  renderAll();
  setStatus(`${type.charAt(0).toUpperCase() + type.slice(1)} restored.`, "success");
}

function deleteEntry(type, id, options = {}) {
  const collectionName = collectionNameForType(type);
  const index = state[collectionName].findIndex(item => item.id === id);
  if (index < 0) return;
  const entry = clone(state[collectionName][index]);
  const relatedLineups = type === "event" ? clone((state.lineups || []).filter((item) => item.eventId === id)) : [];
  const relatedBonspiel = type === "event" ? clone(getBonspielById(id)) : null;
  const relatedBonspielChildren = type === "event" ? clone(state.events.filter((item) => item.bonspielId === id)) : [];
  state[collectionName] = state[collectionName].filter(item => item.id !== id);
  if (type === "ice") {
    state.rinkConditionEntries = (state.rinkConditionEntries || []).filter((item) => item.sourceIceId !== id);
  }
  if (type === "event") {
    const removedLineups = relatedLineups.map((item) => item.id);
    state.lineups = (state.lineups || []).filter((item) => item.eventId !== id);
    state.games = state.games.map((item) => removedLineups.includes(item.lineupId) ? { ...item, lineupId: "" } : item);
    state.bonspiels = (state.bonspiels || []).filter((item) => item.id !== id);
    state.events = state.events.map((item) => item.bonspielId === id ? { ...item, bonspielId: "" } : item);
  }
  if (type === "event" && selectedEventId === id) {
    selectedEventId = state.events[0] ? state.events[0].id : null;
  }
  saveState();
  renderAll();
  setStatus(`${type.charAt(0).toUpperCase() + type.slice(1)} deleted.`, "success");
  if (options.toast !== false) {
    showToast(`${type.charAt(0).toUpperCase() + type.slice(1)} deleted`, {
      actionLabel: "Undo",
      onAction: () => restoreDeletedEntry(type, { index, entry, relatedLineups, relatedBonspiel, relatedBonspielChildren })
    });
  }
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
  deleteEntry(type, id);
  resetModalDirty(`modal-${type}`);
  closeModal(`modal-${type}`);
}

function findPlannerLinkedEvent(date, plannerEntry) {
  return getPlannerLinkedEvent(date, plannerEntry);
}

function openGameModalFromPlanner(date = plannerDate) {
  const plannerEntry = getPlannerEntryForDate(date) || getPlannerDefaults(date);
  const linkedEvent = findPlannerLinkedEvent(date, plannerEntry);
  const opponent = asString(plannerEntry.opponent) || asString(linkedEvent?.opponent) || asString(linkedEvent?.title);
  const existingGame = state.games.find((game) => {
    if (game.date !== date) return false;
    if (!opponent) return true;
    return asString(game.opponent).toLowerCase() === opponent.toLowerCase();
  });
  if (existingGame) {
    expandedGameId = existingGame.id;
    showView("games");
    renderGames();
    setStatus("Game already logged for this date.", "success");
    showToast("Game already logged", {
      actionLabel: "View",
      onAction: () => {
        expandedGameId = existingGame.id;
        showView("games");
        renderGames();
      }
    });
    return;
  }
  openModal("game");
  document.getElementById("gm-date").value = date;
  document.getElementById("gm-opponent").value = opponent;
  document.getElementById("gm-rink").value = asString(plannerEntry.rink) || asString(linkedEvent?.rink);
  document.getElementById("gm-position").value = plannerEntry.position || linkedEvent?.position || "";
  resetModalDirty("modal-game");
  plannerGamePrefillDate = date;
}

function exportData() {
  const blob = new Blob([JSON.stringify(state, null, 2)], { type: "application/json" });
  const url = URL.createObjectURL(blob);
  const link = document.createElement("a");
  link.href = url;
  link.download = "curlplan-data.json";
  link.click();
  URL.revokeObjectURL(url);
  saveUiPrefs({ ...uiPrefs, lastExportAt: new Date().toISOString() });
  renderExportButtonLabel();
  setStatus("Export ready.", "success");
  showToast("Export ready");
}

function importData(file) {
  if (!file) return;
  const reader = new FileReader();
  reader.onload = () => {
    try {
      const parsed = migrateRaw(JSON.parse(reader.result));
      const warnings = [];
      let previewError = "";
      let nextState;
      try {
        nextState = normalizeState(parsed, { strict: true, warnings });
      } catch (error) {
        previewError = error instanceof Error ? error.message : "This file may not be a valid CurlPlan export.";
        nextState = normalizeState(parsed, { warnings });
      }
      pendingImportState = {
        fileName: file.name || "import.json",
        nextState,
        summary: {
          events: nextState.events.length,
          games: nextState.games.length,
          practice: nextState.practice.length,
          ice: nextState.ice.length,
          rinks: nextState.rinks.length,
          sheets: nextState.sheets.length,
          rinkConditionEntries: nextState.rinkConditionEntries.length,
          issues: nextState.issues.length,
          plannerEntries: nextState.plannerEntries.length
        },
        warnings,
        error: previewError
      };
      renderImportPreview();
      openModal("import-preview");
    } catch (error) {
      setStatus(error instanceof Error ? error.message : "Import failed.", "error");
      showToast(error instanceof Error ? error.message : "Import failed");
    }
  };
  reader.readAsText(file);
}

function resetDemoData() {
  const previousState = clone(state);
  const previousPrefs = clone(uiPrefs);
  localStorage.removeItem(CHECKLIST_DEFAULTS_KEY);
  saveState(clone(demoState()));
  selectedEventId = state.events[0] ? state.events[0].id : null;
  plannerDate = todayStr();
  plannerChecklist = cloneChecklist(DEFAULT_PLANNER_CHECKLIST);
  saveUiPrefs({ ...uiPrefs, lastPlannerDate: plannerDate, plannerTemplate: defaultUiPrefs().plannerTemplate });
  renderAll();
  setStatus("Demo data restored.", "success");
  showToast("Demo data restored", {
    actionLabel: "Undo",
    onAction: () => {
      saveState(previousState);
      saveUiPrefs(previousPrefs);
      selectedEventId = state.events[0] ? state.events[0].id : null;
      plannerDate = previousPrefs.lastPlannerDate || todayStr();
      renderAll();
      setStatus("Previous workspace restored.", "success");
    }
  });
}

function renderImportPreview() {
  const target = document.getElementById("importPreviewBody");
  const confirmButton = document.getElementById("confirmImportBtn");
  if (!target) return;
  if (!pendingImportState) {
    target.innerHTML = renderEmpty("inbox", "No import is waiting for review.", null, "Import inbox is clear");
    if (confirmButton) {
      confirmButton.classList.remove("btn-danger");
      confirmButton.classList.add("btn-primary");
    }
    return;
  }
  const hasValidationRisk = Boolean(pendingImportState.error || pendingImportState.warnings?.length);
  if (confirmButton) {
    confirmButton.classList.toggle("btn-danger", hasValidationRisk);
    confirmButton.classList.toggle("btn-primary", !hasValidationRisk);
  }
  target.innerHTML = `
    ${pendingImportState.error ? `
      <div class="state-strip state-warning">
        <div class="state-copy-block">
          <div class="state-kicker">Validation warning</div>
          <strong>This file may not be a valid CurlPlan export</strong>
          <span>${escapeHtml(pendingImportState.error)}</span>
        </div>
      </div>
    ` : ""}
    <div class="state-strip state-strip-inline">
      <div class="state-copy-block">
        <div class="state-kicker">Ready to import</div>
        <strong>${escapeHtml(pendingImportState.fileName)}</strong>
        <span>This will replace the current workspace. A restore action will stay available right after import.</span>
      </div>
    </div>
    <div class="grid-2">
      <div class="summary-row"><span class="summary-name">Events</span><span class="summary-count">${pendingImportState.summary.events}</span></div>
      <div class="summary-row"><span class="summary-name">Games</span><span class="summary-count">${pendingImportState.summary.games}</span></div>
      <div class="summary-row"><span class="summary-name">Practice Sessions</span><span class="summary-count">${pendingImportState.summary.practice}</span></div>
      <div class="summary-row"><span class="summary-name">Ice Notes</span><span class="summary-count">${pendingImportState.summary.ice}</span></div>
      <div class="summary-row"><span class="summary-name">Rinks</span><span class="summary-count">${pendingImportState.summary.rinks}</span></div>
      <div class="summary-row"><span class="summary-name">Sheets</span><span class="summary-count">${pendingImportState.summary.sheets}</span></div>
      <div class="summary-row"><span class="summary-name">Condition Entries</span><span class="summary-count">${pendingImportState.summary.rinkConditionEntries}</span></div>
      <div class="summary-row"><span class="summary-name">Issues</span><span class="summary-count">${pendingImportState.summary.issues}</span></div>
      <div class="summary-row"><span class="summary-name">Planner Entries</span><span class="summary-count">${pendingImportState.summary.plannerEntries}</span></div>
    </div>
    ${pendingImportState.warnings?.length ? `
      <div class="card-sm">
        <div class="state-kicker">Validation notes</div>
        <ul class="stack">
          ${pendingImportState.warnings.map((warning) => `<li>⚠ ${escapeHtml(warning)}</li>`).join("")}
        </ul>
      </div>
    ` : ""}
  `;
}

function confirmImportPreview() {
  if (!pendingImportState) return;
  const previousState = clone(state);
  saveState(pendingImportState.nextState);
  selectedEventId = state.events[0] ? state.events[0].id : null;
  plannerDate = todayStr();
  saveUiPrefs({ ...uiPrefs, lastPlannerDate: plannerDate });
  renderAll();
  closeModal("modal-import-preview");
  setStatus("Import complete.", "success");
  showToast("Import complete", {
    actionLabel: "Undo",
    onAction: () => {
      saveState(previousState);
      selectedEventId = state.events[0] ? state.events[0].id : null;
      renderAll();
      setStatus("Import undone.", "success");
    }
  });
  pendingImportState = null;
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
  renderSuggestedNext();
  renderExportButtonLabel();
  renderViewContext();
}
