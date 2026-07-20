"""Convert a Meshy rig/animation GLB to a Roblox-uploadable FBX.

Meshy sometimes ships rig zips as GLB (e.g. Meshy_AI_<name>_biped.zip with
*_Character_output.glb + *_Animation_Walking_withSkin.glb) instead of FBX.
Roblox Open Cloud model upload and anim2rbx both want FBX, so this bridges:

  blender --background --python scripts/blender/rig_glb_to_fbx.py -- \
      --input <in.glb> --output <out.fbx> [--anim]

- Textures are EMBEDDED in the FBX (path_mode COPY + embed) so the uploaded
  Model arrives pre-textured — the cinder_golemite rig upload was grey and
  needed a manual TextureID patch; never again.
- add_leaf_bones=False: extra "_end" leaf bones would change the skeleton
  and break the shared-clip-per-rig-class contract (identical bone names).
- --anim additionally bakes the GLB's animation into the FBX (for the
  walk-clip GLB feeding scripts/import_animation.sh).
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

import bpy


def parse_args() -> argparse.Namespace:
    argv = sys.argv
    argv = argv[argv.index("--") + 1 :] if "--" in argv else []
    parser = argparse.ArgumentParser(description="Meshy rig GLB -> FBX.")
    parser.add_argument("--input", required=True)
    parser.add_argument("--output", required=True)
    parser.add_argument("--anim", action="store_true", help="bake the GLB's animation into the FBX")
    parser.add_argument(
        "--no-embed",
        action="store_true",
        help="bare FBX: no embedded textures (the bobby-pet upload class — bind a separate Image at runtime)",
    )
    parser.add_argument(
        "--add-root-bone",
        action="store_true",
        help="BONE ARMOR for static props: add a single root bone with all vertices "
        "weighted to it, so Roblox treats the mesh as SKINNED and skips the "
        "delayed re-encode/optimizer pass that shatters static uploads "
        "(2026-07-15 finding: skinned meshes never rot, statics roulette)",
    )
    return parser.parse_args(argv)


def main() -> None:
    args = parse_args()
    src = Path(args.input).expanduser().resolve()
    dst = Path(args.output).expanduser().resolve()
    dst.parent.mkdir(parents=True, exist_ok=True)

    bpy.ops.wm.read_factory_settings(use_empty=True)
    if src.suffix.lower() == ".fbx":
        bpy.ops.import_scene.fbx(filepath=str(src))
    else:
        bpy.ops.import_scene.gltf(filepath=str(src))

    meshes = [o for o in bpy.data.objects if o.type == "MESH"]
    arms = [o for o in bpy.data.objects if o.type == "ARMATURE"]
    if not meshes:
        raise RuntimeError(f"no mesh in {src}")
    print(f"imported: {len(meshes)} mesh(es), {len(arms)} armature(s)")

    if args.add_root_bone and not arms:
        arm_data = bpy.data.armatures.new("Armature")
        arm_obj = bpy.data.objects.new("Armature", arm_data)
        bpy.context.collection.objects.link(arm_obj)
        bpy.context.view_layer.objects.active = arm_obj
        bpy.ops.object.mode_set(mode="EDIT")
        bone = arm_data.edit_bones.new("Root")
        bone.head = (0, 0, 0)
        bone.tail = (0, 0.5, 0)
        bpy.ops.object.mode_set(mode="OBJECT")
        for mesh_obj in meshes:
            vg = mesh_obj.vertex_groups.new(name="Root")
            vg.add(range(len(mesh_obj.data.vertices)), 1.0, "REPLACE")
            mod = mesh_obj.modifiers.new("Armature", "ARMATURE")
            mod.object = arm_obj
            mesh_obj.parent = arm_obj
        print("bone armor: root bone added, all verts weighted")

    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.export_scene.fbx(
        filepath=str(dst),
        use_selection=True,
        object_types={"MESH", "ARMATURE"},
        apply_scale_options="FBX_SCALE_ALL",
        mesh_smooth_type="FACE",
        add_leaf_bones=False,
        path_mode="COPY",
        embed_textures=not args.no_embed,
        bake_anim=bool(args.anim),
        axis_forward="-Z",
        axis_up="Y",
    )
    print(f"exported: {dst} ({dst.stat().st_size} bytes)")


if __name__ == "__main__":
    main()
