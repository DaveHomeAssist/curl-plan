#!/usr/bin/env node

import { cp, mkdtemp, rm } from "node:fs/promises";
import { tmpdir } from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { execFileSync } from "node:child_process";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const api = path.join(root, "api");
const wrangler = path.join(api, "node_modules", "wrangler", "wrangler-dist", "cli.js");
const scratch = await mkdtemp(path.join(tmpdir(), "curlplan-d1-migration-"));
const active = path.join(scratch, "active");
const backup = path.join(scratch, "pre-v4-backup");

try {
  run([
    "d1", "execute", "curlplan", "--local", "--persist-to", active,
    "--command",
    "CREATE TABLE state (user_id TEXT PRIMARY KEY, doc TEXT NOT NULL, rev INTEGER NOT NULL DEFAULT 0, updated_at INTEGER NOT NULL DEFAULT 0); " +
      "INSERT INTO state (user_id, doc, rev, updated_at) VALUES " +
      "('migration-user', '{\"posts\":[{\"id\":\"legacy\",\"at\":1}]}', 7, 1720000000000);",
    "--json",
  ]);
  await cp(active, backup, { recursive: true });

  run([
    "d1", "execute", "curlplan", "--local", "--persist-to", active,
    "--file", "./migrations/0002_atomic_sync_v4.sql", "--json",
  ]);

  const rows = query(active,
    "SELECT user_id, doc, rev, updated_at, schema_version, last_idempotency_key FROM state;");
  assert(rows.length === 1, "migration preserves exactly one seeded state row");
  assert(rows[0].user_id === "migration-user" && rows[0].rev === 7,
    "migration preserves user identity and revision");
  assert(rows[0].updated_at === 1720000000000 && rows[0].doc.includes("legacy"),
    "migration preserves timestamp and document bytes");
  assert(rows[0].schema_version === 3 && rows[0].last_idempotency_key === "",
    "migration assigns the safe schema 3 and empty idempotency defaults");

  const columns = query(active, "PRAGMA table_info(state);");
  assert(columns.map(column => column.name).join(",") ===
    "user_id,doc,rev,updated_at,schema_version,last_idempotency_key",
  "migration adds only the two planned state columns");

  const objects = query(active,
    "SELECT name, type FROM sqlite_master WHERE name IN " +
      "('sync_receipts', 'sync_receipts_created_at') ORDER BY name;");
  assert(objects.length === 2 && objects[0].name === "sync_receipts" && objects[0].type === "table" &&
      objects[1].name === "sync_receipts_created_at" && objects[1].type === "index",
  "migration creates the receipt table and pruning index");

  run([
    "d1", "execute", "curlplan", "--local", "--persist-to", active,
    "--command",
    "INSERT INTO sync_receipts " +
      "(user_id, idempotency_key, request_fingerprint, response, created_at) " +
      "VALUES ('migration-user', 'receipt-1', 'fingerprint', '{}', 1720000000001);",
    "--json",
  ]);
  const receipts = query(active,
    "SELECT user_id, idempotency_key FROM sync_receipts;");
  assert(receipts.length === 1 && receipts[0].idempotency_key === "receipt-1",
    "migrated receipt table accepts the Worker contract");

  const backupColumns = query(backup, "PRAGMA table_info(state);");
  assert(!backupColumns.some(column => column.name === "schema_version") &&
      !backupColumns.some(column => column.name === "last_idempotency_key"),
  "the pre-migration backup remains an independently readable rollback source");

  console.log("verify-d1-migration: pre-v4 data, additive schema, receipts, and rollback source pass ✓");
} finally {
  await rm(scratch, { recursive: true, force: true });
}

function query(persistTo, sql) {
  return run([
    "d1", "execute", "curlplan", "--local", "--persist-to", persistTo,
    "--command", sql, "--json",
  ]).flatMap(result => result.results || []);
}

function run(args) {
  const output = execFileSync(process.execPath, [wrangler, ...args], {
    cwd: api,
    encoding: "utf8",
    maxBuffer: 8 * 1024 * 1024,
    timeout: 30_000,
    env: { ...process.env, CI: "1", WRANGLER_SEND_METRICS: "false" },
  });
  return JSON.parse(output);
}

function assert(condition, message) {
  if (!condition) throw new Error(message);
  console.log(`  ✓ ${message}`);
}
