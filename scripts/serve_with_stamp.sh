#!/usr/bin/env bash
# Run Rojo with a companion process that refreshes build_info whenever HEAD or
# the working tree changes. This makes ordinary Studio File -> Publish carry a
# current marker instead of depending on people remembering a separate command.
set -euo pipefail
cd "$(dirname "$0")/.."

bash scripts/watch_build_stamp.sh &
STAMP_WATCHER_PID=$!

cleanup() {
    kill "$STAMP_WATCHER_PID" 2>/dev/null || true
    wait "$STAMP_WATCHER_PID" 2>/dev/null || true
}
trap cleanup EXIT INT TERM

rojo serve "$@"
