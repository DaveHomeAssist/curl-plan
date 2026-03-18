// CurlPlan actions, modal flows, persistence triggers, and full rerender
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
  });
  speedLabel.textContent = speedText(currentSpeed);
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
  if (window.location.hash !== `#${name}`) {
    window.history.replaceState(null, "", `#${name}`);
  }
  animateView(name);
  renderSuggestedNext();
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
  if (["event", "game", "practice", "ice"].includes(type)) {
    saveUiPrefs({ ...uiPrefs, quickLogType: type });
  }

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

function restoreDeletedEntry(type, snapshot) {
  const collectionName = collectionNameForType(type);
  const nextItems = state[collectionName].slice();
  nextItems.splice(snapshot.index, 0, snapshot.entry);
  state[collectionName] = nextItems;
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
  state[collectionName] = state[collectionName].filter(item => item.id !== id);
  if (type === "event" && selectedEventId === id) {
    selectedEventId = state.events[0] ? state.events[0].id : null;
  }
  saveState();
  renderAll();
  setStatus(`${type.charAt(0).toUpperCase() + type.slice(1)} deleted.`, "success");
  if (options.toast !== false) {
    showToast(`${type.charAt(0).toUpperCase() + type.slice(1)} deleted`, {
      actionLabel: "Undo",
      onAction: () => restoreDeletedEntry(type, { index, entry })
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
      pendingImportState = {
        fileName: file.name || "import.json",
        nextState,
        summary: {
          events: nextState.events.length,
          games: nextState.games.length,
          practice: nextState.practice.length,
          ice: nextState.ice.length,
          issues: nextState.issues.length,
          plannerEntries: Object.keys(nextState.plannerEntries).length
        }
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
  if (!target) return;
  if (!pendingImportState) {
    target.innerHTML = '<div class="empty"><div class="empty-icon">📦</div><div>No import is waiting for review.</div></div>';
    return;
  }
  target.innerHTML = `
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
      <div class="summary-row"><span class="summary-name">Issues</span><span class="summary-count">${pendingImportState.summary.issues}</span></div>
      <div class="summary-row"><span class="summary-name">Planner Entries</span><span class="summary-count">${pendingImportState.summary.plannerEntries}</span></div>
    </div>
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
}
