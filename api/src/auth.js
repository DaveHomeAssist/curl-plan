// Clerk JWT verification for the sync Worker.
// Verifies the Bearer token's RS256 signature against Clerk's PUBLIC JWKS
// (https://<issuer>/.well-known/jwks.json) — no Clerk secret key is needed server-side.
// Returns { userId } (the token `sub`) or null. On any failure → null (caller sends 401).
//
// In tests this whole module is replaced by a stub verifier; the crypto path below runs
// only against a live Clerk instance.

const b64urlToBytes = (s) => {
  s = s.replace(/-/g, "+").replace(/_/g, "/");
  while (s.length % 4) s += "=";
  const bin = atob(s);
  const out = new Uint8Array(bin.length);
  for (let i = 0; i < bin.length; i++) out[i] = bin.charCodeAt(i);
  return out;
};
const b64urlToString = (s) => new TextDecoder().decode(b64urlToBytes(s));

export function makeClerkVerifier(issuer, opts = {}) {
  const audience = opts.audience;
  if (!issuer || !audience) {
    // Not configured yet (placeholder deploy) — reject everything, loudly-ish.
    return async () => null;
  }
  const normalizedIssuer = issuer.replace(/\/+$/, "");
  const jwksUrl = normalizedIssuer + "/.well-known/jwks.json";
  const ttlMs = opts.jwksTtlMs ?? 10 * 60 * 1000;
  const clockSkewSec = opts.clockSkewSec ?? 30;
  const maxTokenAgeSec = opts.maxTokenAgeSec ?? 60 * 60;
  const now = opts.now || Date.now;
  const fetchJWKS = opts.fetch || globalThis.fetch;
  let cache = { at: 0, keys: null };

  async function jwks(forceRefresh = false) {
    const fresh = now() - cache.at < ttlMs;
    if (!forceRefresh && fresh && cache.keys) return cache.keys;
    const res = await fetchJWKS(jwksUrl, {
      headers: { "Cache-Control": forceRefresh ? "no-cache" : "max-age=0" },
    });
    if (!res.ok) throw new Error("jwks fetch failed");
    const data = await res.json();
    if (!Array.isArray(data.keys)) throw new Error("invalid jwks payload");
    cache = { at: now(), keys: data.keys };
    return cache.keys;
  }

  return async function verify(request) {
    try {
      const authz = request.headers.get("Authorization") || "";
      const m = authz.match(/^Bearer\s+(.+)$/i);
      if (!m) return null;
      const parts = m[1].split(".");
      if (parts.length !== 3) return null;
      const [h, p, sig] = parts;
      if (!h || !p || !sig) return null;
      const header = JSON.parse(b64urlToString(h));
      const payload = JSON.parse(b64urlToString(p));

      // claims
      const nowSec = Math.floor(now() / 1000);
      if (header.alg !== "RS256" || typeof header.kid !== "string" || !header.kid) return null;
      if (header.typ !== undefined && header.typ !== "JWT") return null;
      if (typeof payload.iss !== "string" || payload.iss.replace(/\/+$/, "") !== normalizedIssuer) return null;
      const audiences = Array.isArray(payload.aud) ? payload.aud : [payload.aud];
      if (!audiences.includes(audience)) return null;
      if (typeof payload.sub !== "string" || !payload.sub) return null;
      if (![payload.exp, payload.nbf, payload.iat].every(Number.isFinite)) return null;
      if (nowSec - clockSkewSec >= payload.exp) return null;
      if (nowSec + clockSkewSec < payload.nbf) return null;
      if (nowSec + clockSkewSec < payload.iat) return null;
      if (nowSec - payload.iat > maxTokenAgeSec + clockSkewSec) return null;

      // signature (RS256)
      let jwk = (await jwks()).find(k => k.kid === header.kid);
      if (!jwk) {
        cache = { at: 0, keys: null };
        jwk = (await jwks(true)).find(k => k.kid === header.kid);
      }
      if (!jwk) return null;
      if (jwk.kty !== "RSA" || jwk.use !== "sig") return null;
      if (jwk.alg !== undefined && jwk.alg !== "RS256") return null;
      if (Array.isArray(jwk.key_ops) && !jwk.key_ops.includes("verify")) return null;
      const key = await crypto.subtle.importKey(
        "jwk", jwk, { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" }, false, ["verify"]
      );
      const signed = new TextEncoder().encode(h + "." + p);
      const ok = await crypto.subtle.verify("RSASSA-PKCS1-v1_5", key, b64urlToBytes(sig), signed);
      if (!ok) return null;

      return { userId: payload.sub };
    } catch (e) {
      return null;
    }
  };
}
