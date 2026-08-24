// CurlPlan sync Worker (Cloudflare Workers, modules format).
// Thin adapter: wires the D1 binding + Clerk verifier into the pure handler.
// Deploy: see api/README.md. Config: api/wrangler.toml (D1 binding, Clerk claims, CORS origin).
import { handleRequest } from "./handler.js";
import { makeClerkVerifier } from "./auth.js";

export default {
  async fetch(request, env) {
    const db = {
      async get(userId) {
        const row = await env.DB.prepare("SELECT doc, rev, schema_version, updated_at FROM state WHERE user_id = ?")
          .bind(userId).first();
        return row ? {
          doc: JSON.parse(row.doc),
          rev: row.rev,
          schemaVersion: row.schema_version,
          updatedAt: row.updated_at,
        } : null;
      },
      async getReceipt(userId, idempotencyKey) {
        const row = await env.DB.prepare(
          "SELECT request_fingerprint, response FROM sync_receipts WHERE user_id = ? AND idempotency_key = ?"
        ).bind(userId, idempotencyKey).first();
        return row ? { fingerprint: row.request_fingerprint, response: JSON.parse(row.response) } : null;
      },
      async cas(userId, expectedRev, row, idempotencyKey, receipt) {
        const nextRev = row.rev;
        const stateCommit = env.DB.prepare(
          "INSERT INTO state (user_id, doc, rev, schema_version, updated_at, last_idempotency_key) " +
          "VALUES (?, ?, ?, ?, ?, ?) " +
          "ON CONFLICT(user_id) DO UPDATE SET doc = excluded.doc, rev = excluded.rev, " +
          "schema_version = excluded.schema_version, updated_at = excluded.updated_at, " +
          "last_idempotency_key = excluded.last_idempotency_key WHERE state.rev = ?"
        ).bind(userId, JSON.stringify(row.doc), nextRev, row.schemaVersion, row.updatedAt, idempotencyKey, expectedRev);
        const pruneReceipts = receipt.operation === "delete"
          ? env.DB.prepare(
            "DELETE FROM sync_receipts WHERE user_id = ? AND EXISTS " +
            "(SELECT 1 FROM state WHERE user_id = ? AND rev = ? AND last_idempotency_key = ?)"
          ).bind(userId, userId, nextRev, idempotencyKey)
          : env.DB.prepare(
            "DELETE FROM sync_receipts WHERE user_id = ? AND idempotency_key IN " +
            "(SELECT idempotency_key FROM sync_receipts WHERE user_id = ? " +
            "ORDER BY created_at DESC, idempotency_key DESC LIMIT -1 OFFSET 99) AND EXISTS " +
            "(SELECT 1 FROM state WHERE user_id = ? AND rev = ? AND last_idempotency_key = ?)"
          ).bind(userId, userId, userId, nextRev, idempotencyKey);
        const statements = await env.DB.batch([
          stateCommit,
          pruneReceipts,
          env.DB.prepare(
            "INSERT OR IGNORE INTO sync_receipts " +
            "(user_id, idempotency_key, request_fingerprint, response, created_at) " +
            "SELECT ?, ?, ?, ?, ? WHERE EXISTS " +
            "(SELECT 1 FROM state WHERE user_id = ? AND rev = ? AND last_idempotency_key = ?)"
          ).bind(userId, idempotencyKey, receipt.fingerprint, JSON.stringify(receipt.response), row.updatedAt,
            userId, nextRev, idempotencyKey),
        ]);
        return Number(statements[0]?.meta?.changes || 0) === 1;
      },
    };

    const verifyAuth = makeClerkVerifier(env.CLERK_ISSUER, {
      audience: env.CLERK_AUDIENCE,
    });

    return handleRequest(request, {
      db,
      verifyAuth,
      now: () => Date.now(),
      corsOrigin: env.CORS_ORIGIN || "",
    });
  },
};
