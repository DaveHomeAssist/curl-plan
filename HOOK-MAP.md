# CurlPlan — Hook Map

> Reference for Codex when wiring JS behavior to the redesigned markup.
> All IDs and critical classes from the handoff spec are preserved.

---

## Interaction Strategy Change

The redesigned markup **removes all inline `onclick` handlers**. Instead, it uses `data-*` attributes for declarative binding. Codex should wire these with `addEventListener` or event delegation.

### Data attributes to bind

| Attribute              | Found on          | Expected behavior                              |
| ---------------------- | ----------------- | ---------------------------------------------- |
| `data-view="X"`       | `.nav-btn`        | Switch to `view-X`, toggle `.active` on button |
| `data-view-jump="X"`  | `.btn` in cards   | Same as above, from dashboard shortcut buttons |
| `data-open-modal="X"` | `.btn` triggers   | Add `.open` to overlay `#X`                    |
| `data-close-modal="X"`| `.modal-close`, cancel btns | Remove `.open` from overlay `#X`     |
| `data-filter="X"`     | `#filter-bar .btn`| Filter events, toggle `.active-filter`         |
| `data-planner-dir="N"`| `.date-nav-btn`   | Call `plannerNav(N)` with -1 or 1              |
| `data-speed="N"`      | `.speed-dot`      | Call `setSpeed(N)` for ice speed dots          |

---

## Shell & Navigation

| ID / selector    | Element       | Notes                                    |
| ---------------- | ------------- | ---------------------------------------- |
| `todayChip`      | `div`         | Receives formatted date string on load   |
| `#main-nav`      | `nav`         | Contains all `.nav-btn` elements         |
| `view-dashboard` | `section`     | Default `.active` view                   |
| `view-calendar`  | `section`     |                                          |
| `view-planner`   | `section`     |                                          |
| `view-games`     | `section`     |                                          |
| `view-practice`  | `section`     |                                          |
| `view-ice`       | `section`     |                                          |

---

## Dashboard

| ID              | Element | Populated by       |
| --------------- | ------- | ------------------ |
| `stat-games`    | `div`   | `games.length`     |
| `stat-wins`     | `div`   | W count            |
| `stat-upcoming` | `div`   | Future event count |
| `dash-upcoming` | `div`   | Next 3 events HTML |
| `dash-games`    | `div`   | Last 3 games HTML  |
| `dash-ice`      | `div`   | Latest ice note    |

---

## Calendar / Events

| ID / selector    | Element | Notes                                          |
| ---------------- | ------- | ---------------------------------------------- |
| `filter-bar`     | `div`   | Contains filter buttons with `data-filter`     |
| `event-list`     | `div`   | JS renders `.event-item` elements here         |
| `eventDetail`    | `div`   | JS renders selected event, lineup, and profile |

### CSS classes for rendered event items

- `.event-item` — outer container
- `.event-date-block` > `.event-day` + `.event-mon` — date badge
- `.event-info` > `.event-title` + `.event-meta` — content
- `.event-notes` — optional notes line
- `.type-chip` + `.type-league` / `.type-bonspiel` / `.type-practice` / `.type-other`
- `.pos-badge` + `.pos-lead` / `.pos-second` / `.pos-third` / `.pos-skip`
- `.btn-icon` — delete button

### Event detail lineup controls

| ID                | Element    | Notes                        |
| ----------------- | ---------- | ---------------------------- |
| `lineupPresetSelect` | `select` | current preset for event     |
| `lineup-lead`     | `input`    | lead assignment              |
| `lineup-second`   | `input`    | second assignment            |
| `lineup-vice`     | `input`    | vice assignment              |
| `lineup-skip`     | `input`    | skip assignment              |
| `lineup-alternate`| `input`    | alternate assignment         |
| `lineup-spare`    | `input`    | spare assignment             |
| `lineup-opponents`| `textarea` | opponent roster notes        |
| `lineup-notes`    | `textarea` | lineup notes                 |

### Bonspiel controls

| ID                | Element    | Notes                        |
| ----------------- | ---------- | ---------------------------- |
| `ev-bonspiel-parent` | `select` | parent bonspiel for child draw |
| `ev-bonspiel-end` | `input`    | end date for bonspiel parent |
| `ev-bonspiel-hotel` | `input`  | stay details                 |
| `ev-bonspiel-budget` | `input` | budget details               |
| `ev-bonspiel-teammates` | `textarea` | roster notes         |
| `ev-bonspiel-stage` | `input`  | bracket stage                |
| `ev-bonspiel-travel` | `textarea` | travel plan              |
| `ev-bonspiel-packing` | `textarea` | packing list            |

---

## Planner

| ID                | Element    | Notes                        |
| ----------------- | ---------- | ---------------------------- |
| `planner-label`   | `div`      | Shows formatted planner date |
| `plannerRinkProfile` | `div`    | JS renders compact rink profile card |
| `pg-time`         | `input`    | time                         |
| `pg-rink`         | `input`    | text                         |
| `pg-opponent`     | `input`    | text                         |
| `pg-position`     | `select`   |                              |
| `pg-goal-1`       | `input`    | first prep goal              |
| `pg-goal-2`       | `input`    | second prep goal             |
| `pg-goal-3`       | `input`    | third prep goal              |
| `pg-score-us`     | `input`    | number                       |
| `pg-score-them`   | `input`    | number                       |
| `pg-ice`          | `textarea` |                              |
| `pg-rating-draw`  | `select`   | draw weight rating           |
| `pg-rating-takeout` | `select` | takeout rating               |
| `pg-rating-communication` | `select` | communication rating |
| `pg-rating-sweeping` | `select` | sweeping rating             |
| `pg-rating-mental` | `select`  | mental game rating           |
| `pg-takeaways`    | `textarea` | post game review             |
| `pg-next-focus`   | `textarea` | carry forward note           |
| `pg-keyshot`      | `input`    | text                         |
| `planner-entries` | `div`      | JS renders history cards     |
| `save-planner-btn`| `button`   | Triggers `savePlanner()`     |

---

## Games

| ID            | Element  | Notes                        |
| ------------- | -------- | ---------------------------- |
| `game-table`  | `table`  | Contains thead + tbody       |
| `game-tbody`  | `tbody`  | JS renders `<tr>` rows here  |
| `games-empty` | `div`    | Shown when no games, `.hidden` by default |

### CSS classes for rendered game rows

- `.col-date` — date cell
- `.col-notes` — notes cell
- `.score-pill` — score display
- `.result-w` / `.result-l` / `.result-d` — result badge
- `.pos-badge` — position badge
- `.btn-icon` — delete button

---

## Practice

| ID               | Element | Notes                            |
| ---------------- | ------- | -------------------------------- |
| `practice-list`  | `div`   | JS renders `.card-sm` items here |
| `practice-empty` | `div`   | `.hidden` by default             |

### CSS classes for rendered items

- `.card-sm` — card wrapper
- `.type-chip.type-practice` — shot type chips
- `.btn-icon` — delete button

---

## Ice Notes

| ID          | Element | Notes                            |
| ----------- | ------- | -------------------------------- |
| `ice-list`  | `div`   | `.grid-auto`, JS renders cards   |
| `ice-empty` | `div`   | `.hidden` by default             |

### CSS classes for rendered items

- `.card-sm` — card wrapper
- `.btn-icon` — delete button

---

## Modals

| Overlay ID       | Save button ID      | Form field IDs                                        |
| ---------------- | ------------------- | ----------------------------------------------------- |
| `modal-event`    | `save-event-btn`    | `ev-name`, `ev-date`, `ev-time`, `ev-type`, `ev-position`, `ev-location`, `ev-sheet`, `ev-notes` |
| `modal-game`     | `save-game-btn`     | `gm-date`, `gm-opponent`, `gm-us`, `gm-them`, `gm-position`, `gm-rink`, `gm-keyshot`, `gm-notes` |
| `modal-practice` | `save-practice-btn` | `pr-date`, `pr-duration`, `pr-focus`, `pr-notes`      |
| `modal-ice`      | `save-ice-btn`      | `ice-date`, `ice-rink`, `ice-curl`, `ice-notes-text`  |

### Class hooks in modals

| Class        | Location          | Notes                              |
| ------------ | ----------------- | ---------------------------------- |
| `.pr-shot`   | Practice modal    | Checkbox inputs for shot types     |
| `.speed-dot` | Ice notes modal   | Dots with `data-speed="1"` thru 5  |
| `speed-dots` | Ice notes modal   | Container div (also has `id`)      |

### Ice modal additional fields

| ID               | Element | Notes                      |
| ---------------- | ------- | -------------------------- |
| `ice-sheet`      | `input` | Optional sheet label       |
| `ice-confidence` | `select`| Confidence 1 through 5     |
| `ice-frost`      | `select`| Frost severity             |
| `ice-pebble`     | `select`| Pebble feel                |
| `ice-hack`       | `select`| Hack condition             |

---

## Modal open/close pattern

```js
// Open — add .open to overlay
document.getElementById('modal-event').classList.add('open');

// Close — remove .open
document.getElementById('modal-event').classList.remove('open');

// Click-outside-to-close — overlay click
document.addEventListener('click', e => {
  if (e.target.classList.contains('overlay')) {
    e.target.classList.remove('open');
  }
});
```

---

## View switching pattern

```js
function showView(name) {
  document.querySelectorAll('.view').forEach(v => v.classList.remove('active'));
  document.querySelectorAll('.nav-btn').forEach(b => b.classList.remove('active'));
  document.getElementById('view-' + name).classList.add('active');
  document.querySelector(`.nav-btn[data-view="${name}"]`).classList.add('active');
}
```

---

## Skeleton → v1 rename map

These IDs existed in the skeleton but are **not present** in this markup. The skeleton's single-object data model (`curlplan-v1` localStorage key) and form-based CRUD are replaced by the v1 pattern (per-collection keys, modal-based CRUD).

| Skeleton ID        | v1 equivalent                  |
| ------------------ | ------------------------------ |
| `dashboardView`    | `view-dashboard`               |
| `calendarView`     | `view-calendar`                |
| `plannerView`      | `view-planner`                 |
| `gamesView`        | `view-games`                   |
| `practiceView`     | `view-practice`                |
| `notesView`        | `view-ice`                     |
| `statUpcoming`     | `stat-upcoming`                |
| `statGames`        | `stat-games`                   |
| `statPractice`     | (removed — replaced by wins)   |
| `statNotes`        | (removed — ice via dash-ice)   |
| `entryModal`       | Per-type: `modal-event`, etc.  |
| `entryForm`        | Per-type modal bodies          |
| `searchInput`      | (removed — filter-bar buttons) |
| `filterType`       | `filter-bar` buttons           |
