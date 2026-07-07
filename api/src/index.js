// CurlPlan sync Worker (Cloudflare Workers, modules format).
// Thin adapter: wires the D1 binding + Clerk verifier into the pure handler.
// Deploy: see api/README.md. Config: api/wrangler.toml (D1 binding, CLERK_ISSUER, CORS_ORIGIN).
import { handleRequest } from "./handler.js";
import { makeClerkVerifier } from "./auth.js";

export default {
  async fetch(request, env) {
    const db = {
      async get(userId) {
        const row = await env.DB.prepare("SELECT doc, rev FROM state WHERE user_id = ?")
          .bind(userId).first();
        return row ? { doc: JSON.parse(row.doc), rev: row.rev } : null;
      },
      async put(userId, doc, rev) {
        await env.DB.prepare(
          "INSERT INTO state (user_id, doc, rev, updated_at) VALUES (?, ?, ?, ?) " +
          "ON CONFLICT(user_id) DO UPDATE SET doc = excluded.doc, rev = excluded.rev, updated_at = excluded.updated_at"
        ).bind(userId, JSON.stringify(doc), rev, Date.now()).run();
      },
    };

    const verifyAuth = makeClerkVerifier(env.CLERK_ISSUER);

    return handleRequest(request, {
      db,
      verifyAuth,
      now: () => Date.now(),
      corsOrigin: env.CORS_ORIGIN || "*",
    });
  },
};
