#!/usr/bin/env bash
set -euo pipefail

# Rebake ALL Meshy mission-decor props: decimate-first, bake-second (the
# 2026-07-13 pipeline — see docs/ASSET_PIPELINE.md "Decimate + re-bake").
#
# For every GLB in assets/source/props/meshy_mission_decor/ this produces in
# assets/exports/props/meshy_mission_decor/<name>/:
#   <name>_10k_baked.fbx   mesh, 10k tris, welded + degenerate-cleaned,
#                          mesh DATA named <name> (importer names by data)
#   <name>.png             2048px atlas baked onto the FINAL mesh's UVs
#   <name>_preview.png     lit verification render — EYEBALL EVERY ONE
#
# Then (manual, deliberate steps — uploads mint new asset ids):
#   1. node scripts/upload_models.js --fbx <fbx> --name <name>       (per prop)
#   2. node scripts/upload_icons.js --dir <pngs dir> --creator-group 15872767
#   3. Update scripts/mission_decor_model_ids.json + _texture_ids.json
#   4. Transplant the place prefabs (ReplicatedStorage.MissionProps +
#      Workspace._PropReview.MeshyDecor) via MCP Edit session, then SAVE.
#
# Usage:
#   bash scripts/rebake_mission_decor.sh              # all props
#   bash scripts/rebake_mission_decor.sh hell_skull_banner heaven_archive
#
# Env: BLENDER=/path/to/Blender (default: macOS app bundle)
#      TARGET_TRIS=10000  TEX_SIZE=2048

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BLENDER="${BLENDER:-/Applications/Blender.app/Contents/MacOS/Blender}"
SRC_DIR="${ROOT}/assets/source/props/meshy_mission_decor"
OUT_ROOT="${ROOT}/assets/exports/props/meshy_mission_decor"
TARGET_TRIS="${TARGET_TRIS:-10000}"
TEX_SIZE="${TEX_SIZE:-2048}"

if [[ ! -x "${BLENDER}" ]]; then
  echo "Blender not found at: ${BLENDER} (set BLENDER=...)" >&2
  exit 1
fi

props=("$@")
if [[ ${#props[@]} -eq 0 ]]; then
  for glb in "${SRC_DIR}"/*.glb; do
    props+=("$(basename "${glb}" .glb)")
  done
fi

fail=0
for prop in "${props[@]}"; do
  glb="${SRC_DIR}/${prop}.glb"
  if [[ ! -f "${glb}" ]]; then
    echo "SKIP ${prop}: no source ${glb}" >&2
    fail=1
    continue
  fi
  echo "=== ${prop} ==="
  "${BLENDER}" --background --python "${ROOT}/scripts/blender/rebake_for_roblox.py" -- \
    --input "${glb}" \
    --output "${OUT_ROOT}/${prop}" \
    --target "${TARGET_TRIS}" \
    --tex-size "${TEX_SIZE}" \
    2>&1 | grep -E '^(Source:|Baking|  atlas|  exported|  preview|Error|Traceback)' || true
  if [[ ! -f "${OUT_ROOT}/${prop}/${prop}_preview.png" ]]; then
    echo "FAILED ${prop}: no preview produced" >&2
    fail=1
  fi
done

echo
echo "Previews to review:"
ls "${OUT_ROOT}"/*/*_preview.png 2>/dev/null || true
exit "${fail}"
