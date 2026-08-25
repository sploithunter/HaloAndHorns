#!/usr/bin/env bash
set -euo pipefail

# Rebuild Roblox-ready FBX + 2K atlas + preview files from the selected,
# post-texture-integrity-passed Layer 3 GLBs. Source GLBs remain ignored local
# pipeline artifacts; the exports and production manifest are the durable inputs.

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BLENDER=/Applications/Blender.app/Contents/MacOS/Blender
REBAKE="$ROOT/scripts/blender/rebake_for_roblox.py"

rebake_one() {
    local realm="$1"
    local name="$2"
    local model="$3"
    local extra=()
    # The voxel-closed watch shrine is already watertight. The generic 0.0004
    # weld collapses one nearby edge into a three-face junction during FBX
    # conversion, so preserve its clean topology with the narrow guard.
    if [[ "$name" == "dreadspire_watch_shrine" ]]; then
        extra=(--weld-dist 0.000001 --dissolve-dist 0.0000001)
    fi
    "$BLENDER" --background --python "$REBAKE" -- \
        --input "$ROOT/$model" \
        --output "$ROOT/assets/exports/props/layer_3/$realm/$name" \
        --target 9999 \
        --tex-size 2048 \
        "${extra[@]}" >/dev/null
}

count=0
while read -r realm name model; do
    rebake_one "$realm" "$name" "$model" &
    count=$((count + 1))
    if (( count % 2 == 0 )); then
        wait
    fi
done <<'MODELS'
heaven empyrean_hibiscus assets/source/props/layer_3/heaven/empyrean_hibiscus/meshy_t2_3800_texture_attempt_1/model.glb
heaven jade_lantern_bloom assets/source/props/layer_3/heaven/jade_lantern_bloom/meshy_t2_3800_repaired_voxel_texture_attempt_1/model.glb
heaven luminous_canopy_tree assets/source/props/layer_3/heaven/luminous_canopy_tree/meshy_t2_4300_repaired_texture_attempt_1/model.glb
heaven petal_spire assets/source/props/layer_3/heaven/petal_spire/meshy_t2_3800_repaired_texture_attempt_1/model.glb
heaven rootlight_vine assets/source/props/layer_3/heaven/rootlight_vine/meshy_t2_3800_repaired_voxel_texture_attempt_1/model.glb
heaven living_root_pavilion assets/source/props/layer_3/heaven/living_root_pavilion/meshy_t2_9000_repaired_texture_attempt_1/model.glb
heaven pearlroot_boulder assets/source/props/layer_3/heaven/pearlroot_boulder/meshy_t2_4000_texture_attempt_1/model.glb
heaven bloomstone_shelf assets/source/props/layer_3/heaven/bloomstone_shelf/meshy_t2_3800_repaired_voxel_texture_attempt_1/model.glb
heaven empyrean_bloom_cactus assets/source/props/layer_3/heaven/empyrean_bloom_cactus/meshy_t2_4000_texture_attempt_1/model.glb
hell dreadthorn_tree assets/source/props/layer_3/hell/dreadthorn_tree/meshy_t2_4400_repaired_voxel_texture_attempt_1/model.glb
hell abyss_orchid assets/source/props/layer_3/hell/abyss_orchid/meshy_t2_3200_texture_attempt_1/model.glb
hell violet_bramble assets/source/props/layer_3/hell/violet_bramble/meshy_t2_3800_repaired_voxel_texture_attempt_1/model.glb
hell blood_reed assets/source/props/layer_3/hell/blood_reed/meshy_t2_3800_texture_attempt_2/model.glb
hell ember_thorn_cluster assets/source/props/layer_3/hell/ember_thorn_cluster/meshy_t2_3800_texture_attempt_1/model.glb
hell obsidian_spike_plant assets/source/props/layer_3/hell/obsidian_spike_plant/meshy_t2_3800_repaired_texture_attempt_1/model.glb
hell dreadspire_watch_shrine assets/source/props/layer_3/hell/dreadspire_watch_shrine/meshy_t2_9000_repaired_voxel_texture_attempt_1/model.glb
hell obsidian_gatehouse assets/source/props/layer_3/hell/obsidian_gatehouse/meshy_t2_9000_repaired_voxel_texture_attempt_1/model.glb
hell dreadspire_faultstone assets/source/props/layer_3/hell/dreadspire_faultstone/meshy_t2_3600_repaired_voxel_texture_attempt_1/model.glb
hell dreadspire_razorstone assets/source/props/layer_3/hell/dreadspire_razorstone/meshy_t2_3400_repaired_voxel_texture_attempt_1/model.glb
hell dreadspire_thorn_cactus assets/source/props/layer_3/hell/dreadspire_thorn_cactus/meshy_t2_4400_repaired_voxel_texture_attempt_1/model.glb
MODELS
wait
