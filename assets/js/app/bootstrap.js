// CurlPlan event wiring and app bootstrap
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
    closeModal(event.target.id);
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
      if (currentView !== "calendar") showView("calendar");
      renderEventList();
    }
    if (action === "delete-entry") {
      const { type, id } = actionButton.dataset;
      if (type && id) deleteEntry(type, id);
    }
    if (action === "planner-jump") {
      plannerDate = actionButton.dataset.date;
      saveUiPrefs({ ...uiPrefs, lastPlannerDate: plannerDate });
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
        queuePlannerAutosave();
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
        queuePlannerAutosave();
      }
    }
    if (action === "planner-check-remove") {
      const index = Number(actionButton.dataset.index);
      plannerChecklist = plannerChecklist.filter((_, itemIndex) => itemIndex !== index);
      saveChecklistDefaults(plannerChecklist);
      renderPlannerChecklist();
      queuePlannerAutosave();
    }
    if (action === "planner-check-reset") {
      plannerChecklist = cloneChecklist(DEFAULT_PLANNER_CHECKLIST);
      saveChecklistDefaults(DEFAULT_PLANNER_CHECKLIST);
      renderPlannerChecklist();
      document.getElementById("plannerChecklistInput").value = "";
      queuePlannerAutosave();
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
        queuePlannerAutosave();
      }
    }
    if (action === "toggle-game-expand") {
      expandedGameId = expandedGameId === actionButton.dataset.id ? null : actionButton.dataset.id;
      renderGames();
    }
    if (action === "confirm-import") {
      confirmImportPreview();
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

document.addEventListener("dblclick", event => {
  const eventCard = event.target.closest("[data-event-id]");
  if (eventCard?.dataset.eventId) {
    openModal("event", eventCard.dataset.eventId);
    return;
  }
  const gameRow = event.target.closest("[data-action='toggle-game-expand']");
  if (gameRow?.dataset.id) {
    openModal("game", gameRow.dataset.id);
  }
});

searchInput.addEventListener("input", renderEventList);

[
  ["gameSearchInput", "input", renderGames],
  ["gameSortSelect", "change", renderGames],
  ["practiceSearchInput", "input", renderPractice],
  ["practiceSortSelect", "change", renderPractice],
  ["iceSearchInput", "input", renderIce],
  ["iceSortSelect", "change", renderIce]
].forEach(([id, eventName, handler]) => {
  const el = document.getElementById(id);
  if (!el) return;
  el.addEventListener(eventName, handler);
});

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

document.addEventListener("click", event => {
  const inlineSave = event.target.closest("[data-save-planner-inline]");
  if (!inlineSave) return;
  markWorking(inlineSave, 300);
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
  else if (validViews.includes(currentView)) showView(currentView);
});

window.addEventListener("hashchange", () => {
  const validViews = ["dashboard", "calendar", "planner", "games", "practice", "ice", "issues"];
  const hashView = window.location.hash.slice(1);
  if (validViews.includes(hashView) && hashView !== currentView) showView(hashView);
});

document.addEventListener("keydown", (event) => {
  const openOverlay = document.querySelector(".overlay.open");
  const activeElement = document.activeElement;
  const isTyping = activeElement && /^(INPUT|TEXTAREA|SELECT)$/.test(activeElement.tagName);
  const mod = event.metaKey || event.ctrlKey;

  if (mod && event.key === "Enter" && openOverlay) {
    event.preventDefault();
    openOverlay.querySelector("[data-save-modal]")?.click();
    return;
  }

  if (event.key === "Escape") {
    if (openOverlay) closeModal(openOverlay.id);
    return;
  }

  if (event.key === "?" && !mod) {
    event.preventDefault();
    openModal("shortcuts");
    return;
  }

  if (event.key === "/" && !mod && !isTyping) {
    event.preventDefault();
    const searchMap = {
      calendar: "searchInput",
      games: "gameSearchInput",
      practice: "practiceSearchInput",
      ice: "iceSearchInput"
    };
    const searchId = searchMap[currentView] || "searchInput";
    document.getElementById(searchId)?.focus();
    return;
  }

  if (isTyping && !mod) return;

  const viewKeys = {
    1: "dashboard",
    2: "calendar",
    3: "planner",
    4: "games",
    5: "practice",
    6: "ice",
    7: "issues"
  };
  if (viewKeys[event.key]) {
    event.preventDefault();
    showView(viewKeys[event.key]);
    return;
  }

  if (!mod && event.key.toLowerCase() === "n") {
    event.preventDefault();
    openModal("event");
    return;
  }
  if (!mod && event.key.toLowerCase() === "g") {
    event.preventDefault();
    openModal("game");
    return;
  }
  if (!mod && event.key.toLowerCase() === "r") {
    event.preventDefault();
    openModal("practice");
    return;
  }
  if (!mod && event.key.toLowerCase() === "i") {
    event.preventDefault();
    openModal("ice");
    return;
  }

  if (event.key === "Enter" && activeElement?.matches("[data-event-id]")) {
    event.preventDefault();
    openModal("event", activeElement.dataset.eventId);
    return;
  }

  if (event.key === "Enter" && activeElement?.matches("[data-action='toggle-game-expand']")) {
    event.preventDefault();
    openModal("game", activeElement.dataset.id);
  }
});

document.getElementById("plannerChecklistInput").addEventListener("keydown", (event) => {
  if (event.key !== "Enter") return;
  event.preventDefault();
  document.querySelector('[data-action="planner-check-add"]').click();
});

const queuePlannerAutosave = debounce(() => {
  if (currentView !== "planner") return;
  savePlanner({ silent: true });
}, 500);

[
  "pg-time",
  "pg-rink",
  "pg-opponent",
  "pg-position",
  "pg-goals",
  "pg-score-us",
  "pg-score-them",
  "pg-ice",
  "pg-reflection",
  "pg-keyshot"
].forEach(id => {
  document.getElementById(id)?.addEventListener("input", queuePlannerAutosave);
  document.getElementById(id)?.addEventListener("change", queuePlannerAutosave);
});

window.addEventListener("beforeunload", () => {
  if (currentView === "planner") savePlanner({ silent: true });
});

window.addEventListener("afterprint", clearPrintReport);
