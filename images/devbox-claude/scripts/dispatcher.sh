#!/usr/bin/env bash
# devbox-claude image default ENTRYPOINT. Two modes:
#
#   1. agentImage-init (TOOLS_DIR set): the kubeopencode controller runs the
#      image ENTRYPOINT with TOOLS_DIR=/tools expecting a binary copied to
#      /tools/opencode. Plant claude-agent-boot.sh there so the controller's
#      hardcoded `/tools/opencode serve …` boots Claude Code, then exit 0.
#
#   2. plain (no TOOLS_DIR): behave as an ordinary devbox entrypoint — exec the
#      passed command, or an interactive shell.
set -euo pipefail

if [ -n "${TOOLS_DIR:-}" ]; then
  install -m 0755 /usr/local/bin/claude-agent-boot.sh "${TOOLS_DIR}/opencode"
  echo "dispatcher: planted claude-agent-boot.sh at ${TOOLS_DIR}/opencode"
  exit 0
fi

if [ "$#" -gt 0 ]; then
  exec "$@"
fi
exec /bin/bash
