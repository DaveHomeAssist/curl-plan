# CurlPlan

> Personal curling calendar, planner, game log, and ice notes.

## Product tag

`[CurlPlan]`

## Architecture

- Single-file HTML app (`index.html`)
- No build step, no dependencies
- localStorage for persistence
- Export/import via JSON

## Logging tier

**Medium app** — use inline `createLogger('[CurlPlan]')` helper when logging is needed.

## Key data collections

| Collection | Storage key      | Purpose                        |
| ---------- | ---------------- | ------------------------------ |
| events     | `curlplan-v1`    | Calendar events (all types)    |
| games      | `curlplan-v1`    | Game logs with shot % tracking |
| practice   | `curlplan-v1`    | Practice session logs          |
| notes      | `curlplan-v1`    | Ice condition notes per rink   |
| planner    | `curlplan-v1`    | Daily game planner state       |

All collections share one localStorage key as a single JSON blob.

## Views

1. **Today** — dashboard with stats, next event, planner snapshot, timeline, latest notes
2. **Calendar** — event queue, month snapshot (placeholder), event detail
3. **Games** — game log + performance stats
4. **Practice** — session log + drill focus summary
5. **Ice Notes** — rink condition log + rink memory
6. **Daily Planner** — pre-game planning and post-game reflection

## Conventions

- All HTML rendering uses `escapeHtml()` for XSS safety
- Modal-based CRUD for all entity types
- Demo data seeds on first load or reset
- Filter + search available on calendar view
