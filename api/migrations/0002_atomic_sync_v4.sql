-- Run exactly once against a D1 database created with the original schema.
-- Existing documents are schema 3 on disk and migrate additively on their next
-- successful schema 4 compare-and-swap write.
ALTER TABLE state ADD COLUMN schema_version INTEGER NOT NULL DEFAULT 3;
ALTER TABLE state ADD COLUMN last_idempotency_key TEXT NOT NULL DEFAULT '';

CREATE TABLE sync_receipts (
  user_id TEXT NOT NULL,
  idempotency_key TEXT NOT NULL,
  request_fingerprint TEXT NOT NULL,
  response TEXT NOT NULL,
  created_at INTEGER NOT NULL,
  PRIMARY KEY (user_id, idempotency_key)
);

CREATE INDEX sync_receipts_created_at
  ON sync_receipts(created_at);
