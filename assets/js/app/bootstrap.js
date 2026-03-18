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

