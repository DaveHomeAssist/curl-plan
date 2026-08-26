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
  if (!issuer) {
    // Not configured yet (placeholder deploy) — reject everything, loudly-ish.
    return async () => null;
  }
  const jwksUrl = issuer.replace(/\/+$/, "") + "/.well-known/jwks.json";
  const ttlMs = opts.jwksTtlMs || 10 * 60 * 1000;
  const skewSec = opts.clockSkewSec || 60; // small tolerance for client/worker clock drift
  // Origins allowed as the token's authorized party (Clerk `azp`); [] = skip the check.
  const authorizedParties = (opts.authorizedParties || []).filter(Boolean);
  let cache = { at: 0, keys: null };

  async function jwks() {
    const fresh = Date.now() - cache.at < ttlMs;
    if (fresh && cache.keys) return cache.keys;
    const res = await fetch(jwksUrl);
    if (!res.ok) throw new Error("jwks fetch failed");
    const data = await res.json();
    cache = { at: Date.now(), keys: data.keys || [] };
    return cache.keys;
  }

  return async function verify(request) {
    try {
      const authz = request.headers.get("Authorization") || "";
      const m = authz.match(/^Bearer\s+(.+)$/i);
      if (!m) return null;
      const [h, p, sig] = m[1].split(".");
      if (!h || !p || !sig) return null;
      const header = JSON.parse(b64urlToString(h));
      const payload = JSON.parse(b64urlToString(p));
      if (header.alg !== "RS256") return null; // pin the algorithm we verify with

      // claims — expiry and issuer are REQUIRED, not optional-if-present
      const nowSec = Math.floor(Date.now() / 1000);
      if (typeof payload.exp !== "number" || nowSec >= payload.exp + skewSec) return null;
      if (typeof payload.nbf === "number" && nowSec < payload.nbf - skewSec) return null;
      if (typeof payload.iss !== "string" || payload.iss.replace(/\/+$/, "") !== issuer.replace(/\/+$/, "")) return null;
      // authorized party (Clerk sets `azp` to the requesting web origin)
      if (authorizedParties.length && payload.azp && !authorizedParties.includes(payload.azp)) return null;
      if (!payload.sub) return null;

      // signature (RS256)
      const jwk = (await jwks()).find(k => k.kid === header.kid);
      if (!jwk) return null;
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
