#!/usr/bin/env bash
# Planted at /tools/opencode by the dispatcher. The kubeopencode controller
# invokes it with its hardcoded server command:
#
#     claude-agent-boot.sh serve --port <N> --hostname <H>
#
# It boots Claude Code behind a health shim so the controller's startup/readiness
# (HTTP GET /session/status) and liveness (TCP) probes pass. It NEVER starts or
# references opencode.
set -uo pipefail

PORT=""
HOST="0.0.0.0"

# Parse --port / --hostname from argv; ignore the `serve` verb and anything else.
while [ "$#" -gt 0 ]; do
  case "$1" in
    --port)        PORT="$2"; shift 2 ;;
    --port=*)      PORT="${1#*=}"; shift ;;
    --hostname)    HOST="$2"; shift 2 ;;
    --hostname=*)  HOST="${1#*=}"; shift ;;
    *)             shift ;;
  esac
done
: "${PORT:?claude-agent-boot: --port is required}"

# Surface the bootstrap CLAUDE.md into the workspace if the controller mounted it.
if [ -f /bootstrap/CLAUDE.md ]; then
  cp /bootstrap/CLAUDE.md /workspace/CLAUDE.md
fi

# Health shim: python3-stdlib HTTP server answering 200 to any path, bound to
# <host>:<port>. Satisfies the controller's HTTP /session/status probe and TCP
# liveness — both are not overridable.
python3 - "$HOST" "$PORT" <<'PYEOF' &
import sys
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

host, port = sys.argv[1], int(sys.argv[2])

class Handler(BaseHTTPRequestHandler):
    def _ok(self):
        body = b"ok"
        self.send_response(200)
        self.send_header("Content-Type", "text/plain")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        self._ok()

    def do_HEAD(self):
        self.send_response(200)
        self.end_headers()

    def log_message(self, *args):
        pass

ThreadingHTTPServer((host, port), Handler).serve_forever()
PYEOF
SHIM_PID=$!

# Start Claude Code in a tmux session named `main`, cwd /workspace. HOME is
# writable (/tmp per the devbox contract), so ~/.claude persists for the pod's
# lifetime. A mounted /etc/claude-code/managed-settings.json is read natively by
# Claude Code — we do not touch it.
tmux new-session -d -s main -c /workspace 'claude' || true

# Keep PID 1 alive on the shim; if it dies, the pod should restart.
wait "$SHIM_PID"
