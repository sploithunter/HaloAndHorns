#!/usr/bin/env bash
# Keep configs/build_info.lua synchronized with the checkout for manual Studio
# publishes. Rojo observes the generated file and pushes each refresh to Studio.
set -euo pipefail
cd "$(dirname "$0")/.."

INTERVAL="${STAMP_WATCH_INTERVAL_SECONDS:-1}"
LAST_SIGNATURE=""

signature() {
    {
        git rev-parse HEAD
        git rev-parse --abbrev-ref HEAD
        git status --porcelain --untracked-files=normal -- . \
            ':(exclude)configs/build_info.lua'
    } | cksum
}

while true; do
    CURRENT_SIGNATURE="$(signature)"
    if [ "$CURRENT_SIGNATURE" != "$LAST_SIGNATURE" ]; then
        bash scripts/stamp_build.sh
        bash scripts/verify_build_stamp.sh
        LAST_SIGNATURE="$(signature)"
    fi

    if [ -n "${STAMP_WATCH_ONCE:-}" ]; then
        exit 0
    fi
    sleep "$INTERVAL"
done
