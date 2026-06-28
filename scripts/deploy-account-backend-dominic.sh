#!/bin/sh
# Deploy the CurlPlan account backend to the dominic Tailscale host as a Docker
# container with a persistent named volume. Idempotent: re-run to ship updates.
#
# Requires: SSH access to `dominic` (see ~/.ssh/config) and Docker usable there
# without sudo. Node is NOT required on the host; the service runs in node:20-alpine.
set -eu

SSH_HOST="${SSH_HOST:-dominic}"
REMOTE_DIR="${REMOTE_DIR:-/home/davehomeassist/curlplan-account-backend}"
IMAGE="${IMAGE:-curlplan-account-backend:latest}"
CONTAINER="${CONTAINER:-curlplan-account-backend}"
VOLUME="${VOLUME:-curlplan-account-data}"
PORT="${PORT:-8787}"

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
SRC_DIR="$ROOT_DIR/services/account-backend"

echo "Deploying $SRC_DIR -> $SSH_HOST:$REMOTE_DIR"

ssh "$SSH_HOST" "mkdir -p '$REMOTE_DIR'"
scp "$SRC_DIR/server.mjs" "$SRC_DIR/Dockerfile" "$SSH_HOST:$REMOTE_DIR/"

ssh "$SSH_HOST" "sh -s" <<REMOTE
set -eu
cd '$REMOTE_DIR'
docker build -t '$IMAGE' .
docker rm -f '$CONTAINER' 2>/dev/null || true
docker volume create '$VOLUME' >/dev/null
docker run -d \
  --name '$CONTAINER' \
  --restart unless-stopped \
  -p $PORT:8787 \
  -v '$VOLUME':/data \
  '$IMAGE'
sleep 1
docker ps --filter "name=$CONTAINER" --format 'running: {{.Names}} {{.Status}} {{.Ports}}'
REMOTE

echo "Deployed. Health check:"
ssh "$SSH_HOST" "curl -fsS http://127.0.0.1:$PORT/health" && echo
echo "Reachable from this Mac over Tailscale at: http://$SSH_HOST:$PORT"
