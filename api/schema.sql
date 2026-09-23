-- CurlPlan sync — D1 (SQLite) schema. One converged state document per user.
-- Apply with:  wrangler d1 execute curlplan --file=./schema.sql   (see api/README.md)
CREATE TABLE IF NOT EXISTS state (
  user_id    TEXT PRIMARY KEY,   -- Clerk user id (JWT `sub`)
  doc        TEXT NOT NULL,      -- JSON: the merged AppState (v3)
  rev        INTEGER NOT NULL DEFAULT 0,
  updated_at INTEGER NOT NULL DEFAULT 0
);
