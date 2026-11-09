#!/usr/bin/env bash
# Launch the locally built frontend with the agent debug server enabled,
# so a local agent can query frame times, logs and screenshots from the
# running game (see docs/nx2/debug-mcp.md). The owner starts and stops
# the emulator; agents never do.
#
# Usage: tools/local/play.sh [game file]
set -euo pipefail
cd "$(dirname "$0")/../.."

BIN=""
for cand in build/local/bin/yuzu build/release/bin/yuzu build/local/yuzu build/release/yuzu; do
  if [ -x "$cand" ]; then BIN="$cand"; break; fi
done
if [ -z "$BIN" ]; then
  echo "no local build found — run tools/local/build.sh first" >&2
  exit 1
fi

export EDEN_NX2_DEBUG_SERVER="${EDEN_NX2_DEBUG_SERVER:-127.0.0.1:6545}"
echo "debug server: $EDEN_NX2_DEBUG_SERVER"
echo "agent check: python3 tools/nx2/debug_mcp.py --server $EDEN_NX2_DEBUG_SERVER --call '{\"method\":\"status\"}'"
exec "$BIN" "$@"
