# Issue Tracking Live Update System

> Architecture spec and implementation status for the dynamic issue tracker.
> Schema aligned to the ecosystem standard in `/Users/daverobertson/Desktop/Code/AGENTS.md`.

---

## Ecosystem Standard Alignment

This tracker implements the issue tracking schema defined in the root AGENTS.md. Any project that adopts an in-app tracker should follow these same conventions.

| Field | AGENTS.md Standard | In-App Implementation |
|---|---|---|
| ID format | Zero-padded 3-digit integer (`001`) | `nextIssueId()` generates `001`, `002`, etc. |
| Severity | `P1` / `P2` / `P3` | Select dropdown with descriptions |
| Status | `open` / `in-progress` / `resolved` / `deferred` | Select dropdown, lowercase values |
| Sort order | P1 issues float to top | `severityOrder` sort in `renderIssues()` |
| Resolved issues | Stay in table with `resolved` status | Rendered with green chip, not hidden |

Legacy values (`High`/`Med`/`Low`, `Active`/`Draft`) are auto-migrated by `normalizeIssueSeverity()` and `normalizeIssueStatus()`.

---

## Current State: v1 — Fully Dynamic CRUD

The issue tracker is a first-class data collection in CurlPlan, matching the same patterns used by Games, Practice, and Ice Notes.

### What is implemented

| Feature | Status | Notes |
|---|---|---|
| localStorage persistence | Done | `issues` array in `curlplan-v1` key |
| Add issue via modal | Done | `modal-issue` with component, severity, title, status, proposed fix |
| Edit issue | Done | Click "Edit" in table row, modal pre-fills |
| Delete issue | Done | Inline delete button + modal delete button with confirm |
| Auto-incrementing IDs | Done | `001` format, scans existing IDs for next number |
| Dynamic table rendering | Done | `renderIssues()` called from `renderAll()` |
| Live summary sidebar | Done | Counts by severity and status, updates on every change |
| P1-first sort | Done | P1 items always sort to top of table |
| Import/export | Done | Issues included in JSON export and validated on import |
| Legacy migration | Done | Old `High/Med/Low` and `Active/Draft` values auto-convert |
| Demo data seeding | Done | 3 seed issues (001, 002, 003) via `demoState()` |
| Schema normalization | Done | `normalizeIssue()` validates severity, status, ID |

### Data schema

```js
{
  id: "001",                // Zero-padded 3-digit, auto-generated
  component: "Service Worker",
  description: "Offline cache not updating on curlplan_v_1 edits.",
  severity: "P1",           // P1 | P2 | P3
  status: "open",           // open | in-progress | resolved | deferred
  proposedFix: "Version-string the cache name in sw.js."
}
```

### Severity mapping

| Severity | Meaning | CSS Class | Visual |
|---|---|---|---|
| P1 | Blocks usage or deploy | `.result-l` | Red/granite badge |
| P2 | Degrades core function | `.result-d` | Gray badge |
| P3 | Polish or edge case | `.result-w` | Green/leaf badge |

### Status mapping

| Status | CSS Class | Visual |
|---|---|---|
| open | `.type-chip` | Sky blue chip |
| in-progress | `.type-bonspiel` | Granite/orange chip |
| resolved | `.type-practice` | Green chip |
| deferred | `.type-other` | Muted gray chip |

---

## Planned: v2 — Live Update System

Real-time reactivity so the issue table updates without full re-renders, plus cross-tab sync.

### Planned features

| Feature | Priority | Complexity |
|---|---|---|
| StorageEvent listener for cross-tab sync | P1 | Low |
| Targeted DOM patching (update single row vs full innerHTML) | P2 | Med |
| Timestamp tracking (created, updated) | P2 | Low |
| Filter bar (open / in-progress / resolved / deferred / all) | P2 | Low |
| Issue count badge on nav tab | P3 | Low |
| Transition animations on row add/remove | P3 | Med |
| Inline status toggle (click chip to cycle) | P3 | Med |

### Cross-tab sync design

```js
window.addEventListener("storage", (e) => {
  if (e.key === STORAGE_KEY && e.newValue) {
    state = normalizeState(JSON.parse(e.newValue));
    renderAll();
  }
});
```

Zero-cost addition. Provides live updates when CurlPlan is open in multiple tabs.

### Targeted DOM patching design

```
1. On save/delete, identify the changed issue by ID
2. For edits: find the <tr> with matching data-id, update its cells
3. For adds: append a new <tr> to tbody
4. For deletes: remove the <tr> with matching data-id
5. Always re-render the summary sidebar (lightweight)
```

### Timestamp tracking design

```js
{
  id: "004",
  component: "...",
  // existing fields
  createdAt: "2026-03-18T14:30:00Z",
  updatedAt: "2026-03-18T15:45:00Z"
}
```

### Filter bar design

```html
<div class="filter-bar" id="issue-filter-bar">
  <button data-filter="all" class="btn btn-ghost btn-sm active-filter">All</button>
  <button data-filter="open" class="btn btn-ghost btn-sm">Open</button>
  <button data-filter="in-progress" class="btn btn-ghost btn-sm">In Progress</button>
  <button data-filter="resolved" class="btn btn-ghost btn-sm">Resolved</button>
  <button data-filter="deferred" class="btn btn-ghost btn-sm">Deferred</button>
</div>
```

---

## Planned: v3 — Cross-Project Issue Aggregation

Shared issue format allows a single dashboard to pull issues from multiple project exports.

### Shared issue schema

```js
{
  project: "CurlPlan",
  id: "001",
  component: "...",
  description: "...",
  severity: "P1",
  status: "open",
  proposedFix: "...",
  createdAt: "2026-03-18T14:30:00Z",
  updatedAt: "2026-03-18T15:45:00Z"
}
```

### Aggregation approach

Each project exports its issues array. An aggregator page:

1. Accepts multiple JSON files (drag and drop or file picker)
2. Merges issues into a unified table with a `project` column
3. Supports filtering by project, severity, and status
4. Exports the merged view as a single JSON

Each project stays self-contained. The aggregator provides the birds-eye view.

---

## Replication Guide for Other Projects

To add a dynamic issue tracker to another project in the ecosystem:

1. Add `issues: []` to the data schema and persistence layer
2. Copy the modal HTML template (`modal-issue`) and adjust the project styling
3. Implement `normalizeIssue()`, `normalizeIssueSeverity()`, `normalizeIssueStatus()`, and `nextIssueId()`
4. Implement `renderIssues()` with P1-first sorting
5. Wire into the existing modal open/close/save/delete system
6. Add `renderIssues()` to the main render loop

The normalizers include legacy value migration (`High` to `P1`, `Active` to `open`), so imported data from older formats converts automatically.

---

## File reference

| File | What |
|---|---|
| `index.html` | All HTML, CSS, and JS for the issue tracker |
| `ISSUE_TRACKING_LIVE_UPDATE.md` | This spec |
| `AGENTS.md` | Project level issue tracker (markdown, not in-app) |
| `/Users/daverobertson/Desktop/Code/AGENTS.md` | Root ecosystem standard defining the schema |

### Key locations in index.html

| Section | Description |
|---|---|
| `<nav>` — "UI Issues" tab | Nav button with `data-view="issues"` |
| `<section id="view-issues">` | Dynamic table container + summary sidebar |
| `<div id="modal-issue">` | Add/edit modal with form fields |
| `emptyState()` / `demoState()` | Schema definition and seed data |
| `normalizeIssue()` | Input validation, defaults, legacy migration |
| `nextIssueId()` | Auto-increment zero-padded 3-digit ID generator |
| `renderIssues()` | Table rendering with P1-first sort + summary sidebar |
| `saveIssue()` | Modal save handler |
| `openModal("issue")` | Pre-fill form for edit mode |
| `deleteEntry("issue")` | Collection-aware deletion |
