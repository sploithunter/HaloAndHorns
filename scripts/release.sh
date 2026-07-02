#!/usr/bin/env bash
#
# release.sh — publish the place to Roblox via Open Cloud. No GUI, no cookie.
#
# Secrets/IDs are read from the environment and NEVER hardcoded:
#   ROBLOX_OPEN_CLOUD_KEY  Open Cloud API key with place-publish scope
#                          (create at https://create.roblox.com/credentials)
#   ROBLOX_UNIVERSE_ID     target universe id
#   ROBLOX_PLACE_ID        target place id (the asset id to publish to)
#
# Usage:
#   mise run release                 # publish
#   DRY_RUN=1 mise run release        # validate + print the command, do NOT publish
#
# The script refuses (non-zero) if any required variable is unset, so it can
# never publish with missing/blank credentials.

set -euo pipefail

# Load local secrets if present (.env.local is gitignored). Put the three
# ROBLOX_* vars there so the key is never typed on the command line or committed.
if [ -f .env.local ]; then
    set -a
    # shellcheck disable=SC1091
    . ./.env.local
    set +a
fi

: "${ROBLOX_OPEN_CLOUD_KEY:?refusing to publish: set ROBLOX_OPEN_CLOUD_KEY (Open Cloud API key)}"
: "${ROBLOX_UNIVERSE_ID:?refusing to publish: set ROBLOX_UNIVERSE_ID}"
: "${ROBLOX_PLACE_ID:?refusing to publish: set ROBLOX_PLACE_ID}"

# Safety denylist: places with a Studio-authored map must NEVER be rojo-upload'd.
# A `rojo build` produces an empty Workspace, so uploading it would WIPE the map.
# Publish those via `mise run publish-studio` (AppleScript) instead. Place IDs are
# public, so listing them here is safe.
#   133323124203350  Halo & Horns (game place — authored ring map)
ROJO_UPLOAD_DENYLIST="133323124203350"
for denied in $ROJO_UPLOAD_DENYLIST; do
    if [ "${ROBLOX_PLACE_ID}" = "${denied}" ]; then
        echo "ERROR: refusing to rojo-upload to place ${ROBLOX_PLACE_ID} (authored-map game place)." >&2
        echo "  rojo upload builds an empty Workspace and would WIPE the authored map." >&2
        echo "  Publish the game with:  mise run publish-studio" >&2
        exit 1
    fi
done

echo "Release target: universe ${ROBLOX_UNIVERSE_ID}, place ${ROBLOX_PLACE_ID} (Open Cloud)"

if [ -n "${DRY_RUN:-}" ]; then
    echo "[dry-run] would run:"
    echo "  rojo upload --api_key *** --universe_id ${ROBLOX_UNIVERSE_ID} --asset_id ${ROBLOX_PLACE_ID}"
    echo "[dry-run] no upload performed."
    exit 0
fi

exec mise exec -- rojo upload \
    --api_key "${ROBLOX_OPEN_CLOUD_KEY}" \
    --universe_id "${ROBLOX_UNIVERSE_ID}" \
    --asset_id "${ROBLOX_PLACE_ID}"
