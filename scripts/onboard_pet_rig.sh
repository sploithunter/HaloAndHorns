#!/usr/bin/env bash
set -euo pipefail

# Onboard ONE Meshy pet rig zip: convert -> upload rig -> upload clips -> manifest.
#
#   scripts/onboard_pet_rig.sh <pet_id> <path/to/Meshy_AI_*_biped|quadruped.zip>
#
# Handles both zip flavors Meshy ships:
#   FBX zips: *_Character_output.fbx + *_Animation_<Name>_withSkin.fbx
#   GLB zips: *_Character_output.glb + *_Animation_<Name>_withSkin.glb
#             (GLBs bridge through scripts/blender/rig_glb_to_fbx.py — textures
#              get EMBEDDED so the rig upload arrives pre-textured)
#
# What it does:
#   1. rig  -> group Model asset via scripts/upload_models.js (id printed)
#   2. clip -> group Animation asset(s) via scripts/import_animation.sh,
#              named <skeleton>_<clipname>_<pet_id> in scripts/animation_ids.json
#   3. scripts/pet_rig_manifest.json entry (rig_asset + skeleton)
#
# WHAT IT CANNOT DO (the manual tail — see docs/PET_RIG_ONBOARDING.md):
#   4. configs/pets.lua: rig_class = "<skeleton>" on the pet (+ provenance comment)
#   5. configs/animations.lua: add walk/idle clips to the class pools (or a
#      clip_overrides entry if a clip misbehaves on this pet)
#   6. scripts/studio/rebuild_rigged_prebakes.luau: add { rig, height } entry
#      (height = the STATIC prebake's bbox Y — measure in Studio)
#   7. Studio (Edit, via MCP): install the prebake (run the rebuild script)
#   8. Play-verify: pet spawns rigged, walk track fires while moving
#   9. SAME-SESSION: capture ReplicatedStorage.Assets.Models from the BOOTED
#      RUNTIME -> assets/place/Models.rbxm, commit (the Rojo time-bomb rule)

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BLENDER="${BLENDER:-/Applications/Blender.app/Contents/MacOS/Blender}"

PET_ID="${1:?usage: onboard_pet_rig.sh <pet_id> <rig.zip>}"
ZIP="${2:?usage: onboard_pet_rig.sh <pet_id> <rig.zip>}"

case "$ZIP" in
  *biped*) SKELETON=biped ;;
  *quadruped*) SKELETON=quadruped ;;
  *) echo "cannot infer skeleton from zip name (want *_biped*/*_quadruped*)" >&2; exit 1 ;;
esac

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
unzip -o -q "$ZIP" -d "$TMP"

# ---- character ----
CHAR=$(find "$TMP" -name "*_Character_output.*" | head -1)
[ -n "$CHAR" ] || { echo "no *_Character_output.* in zip" >&2; exit 1; }
RIG_FBX="$TMP/${PET_ID}_rig.fbx"
if [[ "$CHAR" == *.glb ]]; then
  "$BLENDER" --background --python "$ROOT/scripts/blender/rig_glb_to_fbx.py" -- \
    --input "$CHAR" --output "$RIG_FBX" | grep -E "imported|exported"
else
  cp "$CHAR" "$RIG_FBX"
fi
echo "== uploading rig (${SKELETON})"
RIG_LINE=$(node "$ROOT/scripts/upload_models.js" --fbx "$RIG_FBX" --name "${PET_ID}_rig" | grep "^OK")
echo "$RIG_LINE"
RIG_ASSET=$(echo "$RIG_LINE" | grep -oE "[0-9]+$")

# ---- clips (every *_Animation_<Name>_withSkin.*) ----
find "$TMP" -name "*_Animation_*_withSkin.*" | while read -r CLIP; do
  BASE=$(basename "$CLIP")
  NAME=$(echo "$BASE" | sed -E "s/.*_Animation_(.+)_withSkin\..*/\1/" | tr "[:upper:]" "[:lower:]")
  CLIP_FBX="$TMP/${SKELETON}_${NAME}_${PET_ID}.fbx"
  if [[ "$CLIP" == *.glb ]]; then
    "$BLENDER" --background --python "$ROOT/scripts/blender/rig_glb_to_fbx.py" -- \
      --input "$CLIP" --output "$CLIP_FBX" --anim | grep -E "imported|exported"
  else
    cp "$CLIP" "$CLIP_FBX"
  fi
  echo "== uploading clip ${SKELETON}_${NAME}_${PET_ID}"
  bash "$ROOT/scripts/import_animation.sh" "$CLIP_FBX" | grep -E "OK|fixed" || true
done

# ---- manifest ----
python3 - "$PET_ID" "$RIG_ASSET" "$SKELETON" <<'EOF'
import json, sys
pet, rig, skel = sys.argv[1:4]
p = "scripts/pet_rig_manifest.json"
m = json.load(open(p))
m["pets"][pet] = {"rig_asset": rig, "skeleton": skel, "prebaked": False}
json.dump(m, open(p, "w"), indent=2)
print(f"manifest: {pet} -> rig {rig} ({skel})")
EOF

echo
echo "DONE (assets + manifest). Manual tail — docs/PET_RIG_ONBOARDING.md steps 4-9:"
echo "  rig asset: $RIG_ASSET  |  clips: see scripts/animation_ids.json"
