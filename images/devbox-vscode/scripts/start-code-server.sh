#!/usr/bin/env bash
# start-code-server.sh — canonical code-server launcher, single-sourced in this repo.
# COPY'd into both devbox-vscode and devbox-claude-vscode derivatives at
# /usr/local/bin/start-code-server.sh.
#
# Behavior:
#   - Binds 0.0.0.0 on port ${CODE_SERVER_PORT:-8080}.
#   - Auth: --auth password when a PASSWORD env var is present; else --auth none
#     (in-cluster default — protection is the consumer's NetworkPolicy/RBAC problem).
#   - Idempotent: no-op if code-server is already running (PID file check).
#   - Backgrounds code-server and returns promptly (postStart hook must not block).
set -uo pipefail

PORT="${CODE_SERVER_PORT:-8080}"
PIDFILE="/tmp/.code-server.pid"

if [ -f "$PIDFILE" ]; then
  PID=$(cat "$PIDFILE")
  if kill -0 "$PID" 2>/dev/null; then
    echo "start-code-server: code-server already running (pid $PID, port $PORT)"
    exit 0
  fi
fi

# Auth mode: --auth password when PASSWORD is set, --auth none otherwise.
AUTH_FLAG="--auth none"
if [ -n "${PASSWORD:-}" ]; then
  AUTH_FLAG="--auth password"
fi

echo "start-code-server: launching on 0.0.0.0:$PORT (auth=$AUTH_FLAG)"

code-server \
  $AUTH_FLAG \
  --bind-addr 0.0.0.0:"$PORT" \
  --user-data-dir /tmp/.vscode-server/data \
  --extensions-dir /tmp/.vscode-server/extensions \
  --data-dir /tmp/.vscode-server \
  /workspace &

CODE_PID=$!
echo "$CODE_PID" > "$PIDFILE"
echo "start-code-server: started (pid $CODE_PID, port $PORT)"
