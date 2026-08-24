# CurlPlan account backend — minimal container.
# The service is a single zero-dependency Node ESM file with a JSON file store.
# Persist /data with a named volume so account state survives restarts.
FROM node:22-alpine@sha256:c610fcdfb1d5b4740dd70c284ed3cb16bb857e0f7166196e36a5501df7a3aa32

WORKDIR /app
COPY server.mjs ./server.mjs
RUN mkdir -p /data && chown node:node /data

ENV PORT=8787 \
    HOST=0.0.0.0 \
    CURLPLAN_ACCOUNT_BACKEND_STORE=/data/state.json

EXPOSE 8787
VOLUME ["/data"]
USER node

CMD ["node", "server.mjs"]
