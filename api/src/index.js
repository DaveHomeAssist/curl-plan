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
      // Atomic revision-checked write: lands only if the stored rev is still rev - 1
      // (rev 1 = first write, must insert). Returns false when a concurrent write won.
      async put(userId, doc, rev) {
        const res = rev === 1
          ? await env.DB.prepare(
              "INSERT INTO state (user_id, doc, rev, updated_at) VALUES (?, ?, ?, ?) " +
              "ON CONFLICT(user_id) DO NOTHING"
            ).bind(userId, JSON.stringify(doc), rev, Date.now()).run()
          : await env.DB.prepare(
              "UPDATE state SET doc = ?, rev = ?, updated_at = ? WHERE user_id = ? AND rev = ?"
            ).bind(JSON.stringify(doc), rev, Date.now(), userId, rev - 1).run();
        return ((res.meta && res.meta.changes) || 0) > 0;
      },
    };

    // Authorized parties for the token's `azp` claim: explicit list, else the CORS
    // origin when it is pinned ("*" means unconfigured — skip the check).
    const azp = env.CLERK_AUTHORIZED_PARTIES || (env.CORS_ORIGIN && env.CORS_ORIGIN !== "*" ? env.CORS_ORIGIN : "");
    const verifyAuth = makeClerkVerifier(env.CLERK_ISSUER, {
      authorizedParties: azp.split(",").map(s => s.trim()).filter(Boolean),
    });

    return handleRequest(request, {
      db,
      verifyAuth,
      now: () => Date.now(),
      corsOrigin: env.CORS_ORIGIN || "*",
    });
  },
};
