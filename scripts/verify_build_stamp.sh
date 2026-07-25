#!/usr/bin/env bash
# Refuse a build/publish when the generated build marker does not describe the
# current checkout. This validates the file Rojo is expected to sync; the Studio
# publish path separately verifies that a Rojo client is connected and gives it
# time to apply the update before clicking Publish.
set -euo pipefail
cd "$(dirname "$0")/.."

STAMP="configs/build_info.lua"
EXPECTED_COMMIT="$(git rev-parse --short HEAD)"
EXPECTED_BRANCH="$(git rev-parse --abbrev-ref HEAD)"

if [ ! -f "$STAMP" ]; then
    echo "ERROR: missing $STAMP; run: mise run stamp" >&2
    exit 1
fi

ACTUAL_COMMIT="$(sed -n 's/^[[:space:]]*commit = "\([^"]*\)".*/\1/p' "$STAMP" | head -n 1)"
ACTUAL_BRANCH="$(sed -n 's/^[[:space:]]*branch = "\([^"]*\)".*/\1/p' "$STAMP" | head -n 1)"

if [ "$ACTUAL_COMMIT" != "$EXPECTED_COMMIT" ] || [ "$ACTUAL_BRANCH" != "$EXPECTED_BRANCH" ]; then
    echo "ERROR: stale build stamp." >&2
    echo "  expected: $EXPECTED_COMMIT ($EXPECTED_BRANCH)" >&2
    echo "  actual:   ${ACTUAL_COMMIT:-missing} (${ACTUAL_BRANCH:-missing})" >&2
    echo "  repair:   mise run stamp" >&2
    exit 1
fi

echo "[stamp] verified $ACTUAL_COMMIT ($ACTUAL_BRANCH)"
