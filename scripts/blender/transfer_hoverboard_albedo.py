"""Transfer one hoverboard recolor onto another mesh's UVs.

Meshy retextured the same silhouette five times but issued a new unwrap
each time. Bake the source look onto the destination UVs so every skin
can share the uploaded Roblox mesh.

  /Applications/Blender.app/Contents/MacOS/Blender --background --python \
    scripts/blender/transfer_hoverboard_albedo.py -- \
    --dest assets/source/hoverboards/blue_gold.glb \
    --source assets/source/hoverboards/orange_black.glb \
    --output assets/exports/hoverboards/orange_black/orange_black.png
"""

from __future__ import annotations

import argparse
import math
import sys
from pathlib import Path

import bpy


def parse_args() -> argparse.Namespace:
    argv = sys.argv
    argv = argv[argv.index("--") + 1 :] if "--" in argv else []
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--dest", required=True)
    parser.add_argument("--source", required=True)
    parser.add_argument("--output", required=True)
    parser.add_argument("--tex-size", type=int, default=1024)
    parser.add_argument("--preview", default="")
    return parser.parse_args(argv)


def clear_scene() -> None:
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for block in (bpy.data.meshes, bpy.data.materials, bpy.data.images, bpy.data.armatures):
        for item in list(block):
            if item.users == 0:
                block.remove(item)


def import_mesh(path: Path) -> bpy.types.Object:
    bpy.ops.import_scene.gltf(filepath=str(path))
    meshes = [obj for obj in bpy.context.selected_objects if obj.type == "MESH"]
    if not meshes:
        raise RuntimeError(f"No mesh imported from {path}")
    if len(meshes) > 1:
        bpy.ops.object.select_all(action="DESELECT")
        for obj in meshes:
            obj.select_set(True)
        bpy.context.view_layer.objects.active = meshes[0]
        bpy.ops.object.join()
    obj = bpy.context.active_object
    obj.location = (0.0, 0.0, 0.0)
    obj.rotation_euler = (0.0, 0.0, 0.0)
    return obj


def bake_diffuse(source: bpy.types.Object, target: bpy.types.Object, image: bpy.types.Image) -> None:
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = 32

    mat = bpy.data.materials.new(name=f"{target.name}_baked")
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    tex_node = nodes.new("ShaderNodeTexImage")
    tex_node.image = image
    # Leave the image unconnected during bake so dest rays do not sample
    # the empty target atlas (Blender "circular dependency" warning).
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
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.samples = 24
    scene.render.resolution_x = 640
    scene.render.resolution_y = 640
    scene.render.filepath = str(out_path)
    scene.render.film_transparent = True

    center = obj.matrix_world.translation
    radius = max(obj.dimensions) * 1.6
    sun = bpy.data.objects.new("PreviewSun", bpy.data.lights.new("PreviewSun", "SUN"))
    sun.data.energy = 3.0
    sun.rotation_euler = (math.radians(50), 0, math.radians(30))
    bpy.context.collection.objects.link(sun)
    cam_data = bpy.data.cameras.new("PreviewCam")
    cam = bpy.data.objects.new("PreviewCam", cam_data)
    bpy.context.collection.objects.link(cam)
    cam.location = (center.x + radius, center.y - radius, center.z + radius * 0.55)
    direction = center - cam.location
    cam.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
    scene.camera = cam
    bpy.ops.render.render(write_still=True)


def main() -> None:
    args = parse_args()
    dest_path = Path(args.dest).expanduser().resolve()
    source_path = Path(args.source).expanduser().resolve()
    output = Path(args.output).expanduser().resolve()
    output.parent.mkdir(parents=True, exist_ok=True)

    clear_scene()
    dest = import_mesh(dest_path)
    dest.name = "Dest"
    source = import_mesh(source_path)
    source.name = "Source"

    image = bpy.data.images.new("HoverboardBake", width=args.tex_size, height=args.tex_size, alpha=True)
    image.generated_color = (0, 0, 0, 0)
    bake_diffuse(source, dest, image)
    image.filepath_raw = str(output)
    image.file_format = "PNG"
    image.save()
    print(f"wrote {output}")

    mat = dest.data.materials[0]
    nodes = mat.node_tree.nodes
    tex_node = next(n for n in nodes if n.type == "TEX_IMAGE")
    bsdf = next((n for n in nodes if n.type == "BSDF_PRINCIPLED"), None)
    if bsdf:
        mat.node_tree.links.new(tex_node.outputs["Color"], bsdf.inputs["Base Color"])

    if args.preview:
        preview = Path(args.preview).expanduser().resolve()
        preview.parent.mkdir(parents=True, exist_ok=True)
        render_preview(dest, preview)
        print(f"wrote {preview}")


if __name__ == "__main__":
    main()
