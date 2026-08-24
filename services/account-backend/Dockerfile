# CurlPlan account backend — minimal container.
# The service is a single zero-dependency Node ESM file with a JSON file store.
# Persist /data with a named volume so account state survives restarts.
FROM node:22-alpine@sha256:c610fcdfb1d5b4740dd70c284ed3cb16bb857e0f7166196e36a5501df7a3aa32

WORKDIR /app
COPY server.mjs ./server.mjs
RUN mkdir -p /data && chown node:node /data

ENV PORT=8787 \
    HOST=0.0.0.0 \
    CURLPLAN_ACCOUNT_BACKEND_STORE=/data/state.json \
    CURLPLAN_ACCOUNT_BACKEND_MODE=quarantined \
    CURLPLAN_ACCOUNT_BACKEND_ALLOWED_ORIGINS="" \
    CURLPLAN_ACCOUNT_BACKEND_TRUST_PROXY=false \
    CURLPLAN_ACCOUNT_BACKEND_REQUEST_TIMEOUT_MS=15000 \
    CURLPLAN_ACCOUNT_BACKEND_SESSION_TTL_MS=2592000000 \
    CURLPLAN_ACCOUNT_BACKEND_SIGN_IN_LIMIT=5 \
    CURLPLAN_ACCOUNT_BACKEND_SIGN_IN_WINDOW_MS=900000 \
    CURLPLAN_ACCOUNT_BACKEND_MAX_RATE_BUCKETS=10000 \
    CURLPLAN_ACCOUNT_BACKEND_MAX_ACCOUNTS=10000 \
    CURLPLAN_ACCOUNT_BACKEND_MAX_SESSIONS_PER_ACCOUNT=5

EXPOSE 8787
VOLUME ["/data"]
USER node

HEALTHCHECK --interval=30s --timeout=5s --start-period=5s --retries=3 \
    CMD node -e "fetch('http://127.0.0.1:8787/health').then(r=>{if(!r.ok)process.exit(1)}).catch(()=>process.exit(1))"

CMD ["node", "server.mjs"]
