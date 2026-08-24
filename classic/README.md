# CurlPlan Classic

## Support status

CurlPlan Classic is **retained and supported**. It is not an archive or a
migration-only surface. The root route is the canonical CurlPlan product preview;
`/classic/` is the canonical route for the local-first Calendar, Planner, Game
Log, Practice, and Ice Notes workflow.

Classic owns a separate browser-storage and offline boundary from the root
preview. Data stays in the current browser unless the user explicitly exports
it. Account creation, cloud sync, and cross-device recovery are not Classic
features and must not be inferred from the root or native account surfaces.

## Supported behavior

- Local Ice Notes, calendar events, games, practices, and planner entries remain
  editable and persist across reloads when browser storage is available.
- A failed primary write retains the last durable workspace and remains visible
  as a recovery state; it must not produce a success message.
- Reset creates a durable pre-reset snapshot. The restore control remains
  available after rerender and reload and requires confirmation before replacing
  the current workspace.
- Corrupt primary storage is left untouched until the user explicitly chooses
  to replace it.
- All overlays use one modal owner, hidden and inert closed state, trapped focus,
  Escape and scrim close, and invoker focus restoration.

## Verification

From the repository root:

```bash
node scripts/verify-split.js
node tests/run-stress.js
npx playwright test tests/browser/classic-*.spec.js
```

The browser suite covers Ice Notes create, edit, invalid input, failed storage,
reload, reset and restore, filtered calendar detail, modal focus, native control
semantics, and automated accessibility in both supported themes.
