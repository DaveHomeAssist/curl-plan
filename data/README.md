# CurlPlan seed data

## `season-seed.json` — the canonical demo season

Single source of truth for the demo season shared by **both** apps (curlers, stops,
spiels, locker feed, and the `me` identity). Edit this file by hand, then run
`node scripts/gen-seed.js` from the repo root to regenerate:

- `ios/CurlPlan/Seed.generated.swift` (native `enum Seed`)
- the marker-delimited `SEED` block in `index.html` (web)

Never hand-edit the generated outputs. `node scripts/gen-seed.js --check` (CI) fails if
they're stale. This is what keeps the web and iOS apps from drifting.

## `curling-clubs.json`

Seed dataset for **location / club choices** (club pickers, location autocomplete,
map placement). 166 clubs across 42 US states.

- **Source:** Notion — `HUB | Curling → Curling Clubs + Bonspiels → DB | Curling Clubs`.
- **Regenerate:** re-export the Notion "All Clubs" view and re-run the normalization
  (slug id, sort by state then name, drop empty fields).

### Shape

```jsonc
{
  "version": 1,
  "source": "Notion — DB | Curling Clubs (HUB | Curling)",
  "count": 166,
  "clubs": [
    {
      "id": "rocket-city-curling-club", // slug of name, unique
      "name": "Rocket City Curling Club",
      "city": "Huntsville",
      "state": "Alabama",
      "region": "Southeast",           // USCA region
      "association": "GNCC",           // GNCC | USCA At-Large | Unaffiliated | ""
      "iceType": "Arena",              // Dedicated | Dedicated (shared) | Arena | Arena/Outdoor | Outdoor | Paper
      "sheets": 5,                      // optional
      "yearFounded": 2018,              // optional
      "venue": "Huntsville Ice Sports Center", // optional
      "website": "https://…",          // optional (present for ~9 clubs)
      "address": "…",                  // optional
      "uscaMember": true,               // optional, present only when true
      "lat": 34.69627,                  // optional (162/166 geocoded)
      "lng": -86.59084
    }
  ]
}
```

Fields are omitted when empty, so guard for `undefined` on the optional keys.
`id` is stable per club name and safe to use as a select value or foreign key.
