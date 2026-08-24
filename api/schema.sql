-- CurlPlan sync schema v4. State and its idempotency receipt commit in one D1
-- batch; the revision predicate is the compare-and-swap boundary.
-- Apply with:  wrangler d1 execute curlplan --file=./schema.sql   (see api/README.md)
CREATE TABLE IF NOT EXISTS state (
  user_id    TEXT PRIMARY KEY,   -- Clerk user id (JWT `sub`)
  doc        TEXT NOT NULL,      -- JSON: canonical merged AppState v4
  rev        INTEGER NOT NULL DEFAULT 0,
  schema_version INTEGER NOT NULL DEFAULT 4,
  updated_at INTEGER NOT NULL DEFAULT 0,
  last_idempotency_key TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS sync_receipts (
  user_id TEXT NOT NULL,
  idempotency_key TEXT NOT NULL,
  request_fingerprint TEXT NOT NULL,
  response TEXT NOT NULL,
  created_at INTEGER NOT NULL,
  PRIMARY KEY (user_id, idempotency_key)
);

CREATE INDEX IF NOT EXISTS sync_receipts_created_at
  ON sync_receipts(created_at);
