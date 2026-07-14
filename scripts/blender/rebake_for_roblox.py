"""Decimate a Meshy mesh AND re-bake its texture onto the decimated UVs.

The 2026-07-13 lesson (mission-decor thrones): decimate_for_roblox.py welds +
decimates but ships the ORIGINAL atlas — welding merges the split verts that
carried Meshy's UV seams, so the old atlas can never match the new mesh and
the prop renders as UV kaleidoscope. The fix is order-of-operations: decimate
FIRST, give the result fresh UVs, THEN bake the hi-poly's appearance onto
those UVs (Cycles selected-to-active, DIFFUSE color only — same albedo-
transfer idiom as the ascension altar bake).

Invoked headless:

  blender --background --python rebake_for_roblox.py -- \
    --input assets/source/props/meshy_mission_decor/hell_infernal_throne.glb \
    --output assets/exports/props/meshy_mission_decor/hell_infernal_throne \
    --target 10000 --tex-size 2048

Outputs into --output:
  <name>_<label>_baked.fbx   (mesh DATA named <name> — importer names by data)
  <name>.png                 (the re-baked atlas, overwrites the stale one)
  <name>_preview.png         (verify-by-render turntable still)
"""

from __future__ import annotations

import argparse
import math
import re
import sys
from pathlib import Path

import bpy

SUPPORTED_IMPORT_SUFFIXES = {".obj", ".fbx", ".glb", ".gltf"}


def parse_args() -> argparse.Namespace:
    argv = sys.argv
    argv = argv[argv.index("--") + 1 :] if "--" in argv else []
    parser = argparse.ArgumentParser(description="Decimate + re-bake for Roblox.")
    parser.add_argument("--input", required=True)
    parser.add_argument("--output", required=True)
    parser.add_argument("--target", type=int, default=10000)
    parser.add_argument("--tolerance", type=float, default=0.03)
    parser.add_argument("--tex-size", type=int, default=2048)
    # SHATTER-RESISTANT overrides (2026-07-14, diamond altar: 3 uploads, 3
    # shatters — some meshes need a heavier scrub before Roblox's processor
    # keeps them intact):
    parser.add_argument("--weld-dist", type=float, default=0.0004)
    parser.add_argument("--dissolve-dist", type=float, default=1e-5)
    return parser.parse_args(argv)


def clear_scene() -> None:
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for block in (bpy.data.meshes, bpy.data.materials, bpy.data.images, bpy.data.armatures):
        for item in list(block):
            if item.users == 0:
                block.remove(item)


def import_mesh(path: Path) -> bpy.types.Object:
    suffix = path.suffix.lower()
    if suffix == ".obj":
        bpy.ops.wm.obj_import(filepath=str(path))
    elif suffix == ".fbx":
        bpy.ops.import_scene.fbx(filepath=str(path))
    elif suffix in {".glb", ".gltf"}:
        bpy.ops.import_scene.gltf(filepath=str(path))
    else:
        raise ValueError(f"Unsupported import format: {suffix}")
    meshes = [obj for obj in bpy.context.selected_objects if obj.type == "MESH"]
    if not meshes:
        raise RuntimeError(f"No mesh objects imported from {path}")
    if len(meshes) == 1:
        return meshes[0]
    bpy.ops.object.select_all(action="DESELECT")
    for obj in meshes:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = meshes[0]
    bpy.ops.object.join()
    return bpy.context.active_object


def weld_and_clean(obj: bpy.types.Object, dist: float = 0.0004) -> None:
    """Shatter guard — weld split verts BEFORE decimating (see decimate_for_roblox)."""
    import bmesh

    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=dist)
    bm.to_mesh(obj.data)
    bm.free()
    obj.data.validate()


def dissolve_degenerate(obj: bpy.types.Object, dist: float = 1e-5) -> None:
    import bmesh

    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bmesh.ops.dissolve_degenerate(bm, edges=bm.edges, dist=dist)
    loose = [v for v in bm.verts if not v.link_faces]
    if loose:
        bmesh.ops.delete(bm, geom=loose, context="VERTS")
    bm.to_mesh(obj.data)
    bm.free()
    obj.data.validate()


def face_count(obj: bpy.types.Object) -> int:
    obj.data.calc_loop_triangles()
    return len(obj.data.loop_triangles)


def decimate_to_target(
    obj: bpy.types.Object,
    target_faces: int,
    tolerance: float,
    weld_dist: float = 0.0004,
    dissolve_dist: float = 1e-5,
) -> int:
    weld_and_clean(obj, weld_dist)
    dissolve_degenerate(obj, dissolve_dist)
    current = face_count(obj)
    if current <= target_faces:
        print(f"  welded/cleaned -> {current} tris; no decimation needed")
        return current
    print(f"  welded split verts -> {current} tris")
    ratio = target_faces / current
    allowed_error = max(25, int(target_faces * tolerance))
    for attempt in range(18):
        modifier = obj.modifiers.new(name="Decimate", type="DECIMATE")
        modifier.decimate_type = "COLLAPSE"
        modifier.use_collapse_triangulate = True
        modifier.ratio = max(0.0001, min(1.0, ratio))
        bpy.context.view_layer.objects.active = obj
        bpy.ops.object.modifier_apply(modifier="Decimate")
        current = face_count(obj)
        print(f"  attempt {attempt + 1}: -> {current} tris")
        if abs(current - target_faces) <= allowed_error:
            dissolve_degenerate(obj, dissolve_dist)
            return face_count(obj)
        if current <= 0:
            raise RuntimeError("Decimation collapsed mesh to zero faces")
        ratio *= target_faces / current
    dissolve_degenerate(obj, dissolve_dist)
    return face_count(obj)


def slugify(name: str) -> str:
    slug = re.sub(r"[^A-Za-z0-9._-]+", "_", name).strip("_")
    return slug or "mesh"


def smart_uv(obj: bpy.types.Object) -> None:
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=math.radians(66), island_margin=0.003)
    bpy.ops.object.mode_set(mode="OBJECT")


def bake_diffuse(source: bpy.types.Object, target: bpy.types.Object, image: bpy.types.Image) -> None:
    """Cycles selected-to-active: transfer the hi-poly's albedo onto target's fresh UVs."""
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = 16

    # target wears ONE new material whose image node is the bake destination
    mat = bpy.data.materials.new(name=f"{target.name}_baked")
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    tex_node = nodes.new("ShaderNodeTexImage")
    tex_node.image = image
    bsdf = next(n for n in nodes if n.type == "BSDF_PRINCIPLED")
    mat.node_tree.links.new(tex_node.outputs["Color"], bsdf.inputs["Base Color"])
    nodes.active = tex_node
    tex_node.select = True
    target.data.materials.clear()
    target.data.materials.append(mat)

    dims = source.dimensions
    extrusion = max(dims.x, dims.y, dims.z) * 0.02

    bpy.ops.object.select_all(action="DESELECT")
    source.select_set(True)
    target.select_set(True)
    bpy.context.view_layer.objects.active = target
    bpy.ops.object.bake(
        type="DIFFUSE",
        pass_filter={"COLOR"},
        use_selected_to_active=True,
        cage_extrusion=extrusion,
        margin=16,
    )


def render_preview(obj: bpy.types.Object, out_path: Path) -> None:
    """Verify-by-render: one lit still of the baked result."""
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.samples = 32
    scene.render.resolution_x = 640
    scene.render.resolution_y = 640
    scene.render.filepath = str(out_path)

    center = obj.matrix_world.translation
    radius = max(obj.dimensions) * 1.6

    sun = bpy.data.objects.new("PreviewSun", bpy.data.lights.new("PreviewSun", "SUN"))
    sun.data.energy = 3.0
    sun.rotation_euler = (math.radians(50), 0, math.radians(30))
    bpy.context.collection.objects.link(sun)

    cam_data = bpy.data.cameras.new("PreviewCam")
    cam = bpy.data.objects.new("PreviewCam", cam_data)
    bpy.context.collection.objects.link(cam)
    offset = (radius, -radius, radius * 0.55)
    cam.location = (center.x + offset[0], center.y + offset[1], center.z + offset[2])
    direction = center - cam.location
    cam.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
    scene.camera = cam

    world = scene.world or bpy.data.worlds.new("PreviewWorld")
    scene.world = world
    world.use_nodes = True
    bg = world.node_tree.nodes.get("Background")
    if bg:
        bg.inputs[0].default_value = (0.18, 0.18, 0.2, 1.0)
        bg.inputs[1].default_value = 1.0

    bpy.ops.render.render(write_still=True)
    bpy.data.objects.remove(sun, do_unlink=True)
    bpy.data.objects.remove(cam, do_unlink=True)


def export_fbx(obj: bpy.types.Object, output_path: Path) -> None:
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    output_path.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.export_scene.fbx(
        filepath=str(output_path),
        use_selection=True,
        apply_scale_options="FBX_SCALE_ALL",
        object_types={"MESH"},
        use_mesh_modifiers=True,
        mesh_smooth_type="FACE",
        path_mode="COPY",
        embed_textures=False,
        axis_forward="-Z",
        axis_up="Y",
    )


def main() -> None:
    args = parse_args()
    source_path = Path(args.input).expanduser().resolve()
    if source_path.suffix.lower() not in SUPPORTED_IMPORT_SUFFIXES:
        raise ValueError(f"Unsupported mesh format: {source_path.suffix}")
    output_dir = Path(args.output).expanduser().resolve()
    output_dir.mkdir(parents=True, exist_ok=True)
    base_name = slugify(source_path.stem)

    clear_scene()
    source = import_mesh(source_path)
    original_tris = face_count(source)
    print(f"Source: {source_path} ({original_tris} tris)")

    # TARGET: duplicate -> weld/decimate/clean -> fresh UVs
    bpy.ops.object.select_all(action="DESELECT")
    source.select_set(True)
    bpy.context.view_layer.objects.active = source
    bpy.ops.object.duplicate()
    target = bpy.context.active_object
    target.name = f"{base_name}_baked"

    final_tris = decimate_to_target(
        target, args.target, args.tolerance, args.weld_dist, args.dissolve_dist
    )
    if final_tris > 17500:
        raise RuntimeError(f"{final_tris} tris exceeds the 17.5k single-MeshPart budget")
    smart_uv(target)

    image = bpy.data.images.new(f"{base_name}_atlas", args.tex_size, args.tex_size, alpha=False)
    print(f"Baking {args.tex_size}px atlas from hi-poly onto {final_tris}-tri mesh...")
    bake_diffuse(source, target, image)

    png_path = output_dir / f"{base_name}.png"
    image.filepath_raw = str(png_path)
    image.file_format = "PNG"
    image.save()
    print(f"  atlas saved: {png_path}")

    # hide the hi-poly so it can't leak into export/preview
    source.hide_render = True
    bpy.data.objects.remove(source, do_unlink=True)

    # importer names MeshParts by mesh DATA name
    target.data.name = base_name
    target.name = base_name

    label = f"{args.target // 1000}k" if args.target % 1000 == 0 else f"{args.target}tris"
    fbx_path = output_dir / f"{base_name}_{label}_baked.fbx"
    export_fbx(target, fbx_path)
    print(f"  exported: {fbx_path} ({final_tris} tris)")

    render_preview(target, output_dir / f"{base_name}_preview.png")
    print(f"  preview: {output_dir / (base_name + '_preview.png')}")
    print("Done.")


if __name__ == "__main__":
    main()
