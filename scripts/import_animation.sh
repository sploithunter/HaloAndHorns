#!/usr/bin/env bash
# Meshy FBX animation clip -> published group-owned Roblox Animation asset. Zero Studio clicks.
#
#   scripts/import_animation.sh <clip.fbx> [<clip2.fbx> ...]
#
# Per file: anim2rbx --no-filter (keep ALL bones — the filter drops static root bones and
# orphans whole subtrees = "half the body animates") -> fix_anim_axes.luau (anim2rbx emits
# poses mirrored 180° about Y; measured against an Animation-Editor ground truth) -> Open Cloud
# Animation upload (group-owned). Ids land in scripts/animation_ids.json keyed by file basename.
#
# One-time per rig class: Meshy skeletons are shared per body type (biped/quadruped), so one
# clip set drives every pet of that class. VERIFY the first clip of a new rig class visually.
set -euo pipefail
cd "$(dirname "$0")/.."

BIN=scripts/bin/anim2rbx
if [ ! -x "$BIN" ]; then
  echo "fetching anim2rbx..."
  mkdir -p scripts/bin
  curl -sL -o scripts/bin/anim2rbx.zip \
    https://github.com/jiwonz/anim2rbx/releases/download/v0.2.0/anim2rbx-macos-aarch64.zip
  (cd scripts/bin && unzip -o anim2rbx.zip >/dev/null && rm anim2rbx.zip && chmod +x anim2rbx)
fi

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

for FBX in "$@"; do
  NAME=$(basename "$FBX" | sed -E 's/\.fbx$//i')
  echo "=== $NAME"
  "$BIN" --no-filter "$FBX" -o "$TMP/$NAME.raw.rbxm"
  mise exec -- lune run scripts/fix_anim_axes.luau "$TMP/$NAME.raw.rbxm" "$TMP/$NAME.rbxm"
  node scripts/upload_animations.js --rbxm "$TMP/$NAME.rbxm" --name "$NAME" --out scripts/animation_ids.json
done

echo "--- scripts/animation_ids.json"
cat scripts/animation_ids.json
