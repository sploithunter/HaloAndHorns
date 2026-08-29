"""Create a closed, rebaked Emberfang Gate from the stronger Meshi silhouette.

The source is kept as the high-detail appearance donor. A voxel remesh produces
closed topology, decimation returns it to a Roblox-sized triangle budget, and a
new atlas is baked from the original textured mesh onto fresh UVs.
"""

from __future__ import annotations

import argparse
import importlib.util
import json
import math
import sys
from pathlib import Path

import bpy
from mathutils import Vector


def parse_args() -> argparse.Namespace:
    argv = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", required=True)
    parser.add_argument("--output-dir", required=True)
    parser.add_argument("--target", type=int, default=17000)
    parser.add_argument("--voxel-ratio", type=float, default=0.002)
    parser.add_argument("--texture-size", type=int, default=1024)
    return parser.parse_args(argv)


def load_rebake_helpers():
    path = Path(__file__).with_name("rebake_for_roblox.py")
    spec = importlib.util.spec_from_file_location("rebake_helpers", path)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"Unable to load helper module: {path}")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def bounds_diagonal(obj: bpy.types.Object) -> float:
    points = [obj.matrix_world @ Vector(corner) for corner in obj.bound_box]
    return max((a - b).length for a in points for b in points)


def triangle_count(obj: bpy.types.Object) -> int:
    obj.data.calc_loop_triangles()
    return len(obj.data.loop_triangles)


def render_preview(
    obj: bpy.types.Object,
    output: Path,
    *,
    azimuth: float,
    rim_color=(1.0, 0.16, 0.025),
    exposure: float = 0.0,
    light_energy_scale: float = 1.0,
) -> None:
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x = 768
    scene.render.resolution_y = 768
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.render.filepath = str(output)
    scene.view_settings.exposure = exposure
    scene.world.use_nodes = True
    background = scene.world.node_tree.nodes.get("Background")
    background.inputs["Color"].default_value = (0.008, 0.010, 0.014, 1.0)
    background.inputs["Strength"].default_value = 0.24

    corners = [obj.matrix_world @ Vector(corner) for corner in obj.bound_box]
    low = Vector((min(p.x for p in corners), min(p.y for p in corners), min(p.z for p in corners)))
    high = Vector((max(p.x for p in corners), max(p.y for p in corners), max(p.z for p in corners)))
    center = (low + high) * 0.5
    size = high - low
    radius = max(size.x, size.y, size.z) * 0.5

    angle = math.radians(azimuth)
    distance = radius * 4.2
    bpy.ops.object.camera_add(location=(center.x + math.sin(angle) * distance, center.y - math.cos(angle) * distance, center.z + radius * 0.10))
    camera = bpy.context.active_object
    camera.name = "PreviewCamera"
    camera.data.type = "ORTHO"
    camera.data.ortho_scale = max(size.x, size.z) * 1.10
    camera.rotation_euler = (center - camera.location).to_track_quat("-Z", "Y").to_euler()
    scene.camera = camera

    def area(name, location, energy, color, area_size):
        bpy.ops.object.light_add(type="AREA", location=location)
        light = bpy.context.active_object
        light.name = name
        light.data.energy = energy
        light.data.color = color
        light.data.shape = "DISK"
        light.data.size = area_size
        light.rotation_euler = (center - light.location).to_track_quat("-Z", "Y").to_euler()

    area("Key", tuple(center + Vector((radius * 1.2, -radius * 1.6, radius * 1.4))), 2300.0 * light_energy_scale, (0.72, 0.82, 1.0), radius * 0.75)
    area("Fill", tuple(center + Vector((-radius * 1.4, -radius * 0.8, radius * 0.5))), 1300.0 * light_energy_scale, (0.45, 0.55, 0.80), radius * 0.9)
    area("Rim", tuple(center + Vector((0.0, radius * 1.4, radius * 1.0))), 2100.0 * light_energy_scale, rim_color, radius * 0.65)
    bpy.ops.render.render(write_still=True)

    for candidate in list(bpy.context.scene.objects):
        if candidate.type in {"CAMERA", "LIGHT"}:
            bpy.data.objects.remove(candidate, do_unlink=True)


def main() -> None:
    args = parse_args()
    source_path = Path(args.input).expanduser().resolve()
    out_dir = Path(args.output_dir).expanduser().resolve()
    out_dir.mkdir(parents=True, exist_ok=True)
    if not source_path.is_file():
        raise FileNotFoundError(source_path)

    helpers = load_rebake_helpers()
    helpers.clear_scene()
    source = helpers.import_mesh(source_path)
    source.name = "SOURCE_Meshy_Reference"
    original_triangles = helpers.face_count(source)

    bpy.ops.object.select_all(action="DESELECT")
    source.select_set(True)
    bpy.context.view_layer.objects.active = source
    bpy.ops.object.duplicate()
    target = bpy.context.active_object
    target.name = "EmberfangGate_Rebuilt"
    target.data = target.data.copy()
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)

    diagonal = bounds_diagonal(target)
    voxel_size = diagonal * args.voxel_ratio
    target.data.remesh_voxel_size = voxel_size
    target.data.remesh_voxel_adaptivity = 0.0
    bpy.context.view_layer.objects.active = target
    bpy.ops.object.voxel_remesh()
    voxel_triangles = triangle_count(target)

    final_triangles = helpers.decimate_to_target(
        target,
        args.target,
        0.02,
        weld_dist=max(diagonal * 1e-7, 1e-8),
        dissolve_dist=max(diagonal * 1e-8, 1e-9),
    )
    helpers.smart_uv(target)

    atlas = bpy.data.images.new("EmberfangGate_Atlas", args.texture_size, args.texture_size, alpha=False)
    helpers.bake_diffuse(source, target, atlas)
    atlas_path = out_dir / "emberfang_gate_atlas.png"
    atlas.filepath_raw = str(atlas_path)
    atlas.file_format = "PNG"
    atlas.save()
    atlas.pack()

    # Preserve the dark-stone read while allowing orange source pixels to illuminate themselves.
    material = target.data.materials[0]
    material.name = "EmberfangGate_Rebaked"
    nodes = material.node_tree.nodes
    links = material.node_tree.links
    bsdf = next(node for node in nodes if node.type == "BSDF_PRINCIPLED")
    texture = next(node for node in nodes if node.type == "TEX_IMAGE")
    bsdf.inputs["Roughness"].default_value = 0.58
    bsdf.inputs["Metallic"].default_value = 0.12
    links.new(texture.outputs["Color"], bsdf.inputs["Emission Color"])
    bsdf.inputs["Emission Strength"].default_value = 0.22

    source.hide_render = True
    source.hide_viewport = True
    split_edges = helpers.split_uv_seams(target)

    glb_path = out_dir / "emberfang_gate_rebuilt.glb"
    bpy.ops.object.select_all(action="DESELECT")
    target.select_set(True)
    bpy.context.view_layer.objects.active = target
    bpy.ops.export_scene.gltf(
        filepath=str(glb_path),
        export_format="GLB",
        use_selection=True,
        export_apply=True,
        export_yup=True,
        export_materials="EXPORT",
    )

    front_path = out_dir / "emberfang_gate_front.png"
    three_quarter_path = out_dir / "emberfang_gate_three_quarter.png"
    render_preview(target, front_path, azimuth=0.0)
    render_preview(target, three_quarter_path, azimuth=34.0)

    blend_path = out_dir / "emberfang_gate_rebuilt.blend"
    source.hide_viewport = False
    bpy.ops.wm.save_as_mainfile(filepath=str(blend_path))

    report = {
        "source": str(source_path),
        "original_triangles": original_triangles,
        "voxel_ratio": args.voxel_ratio,
        "voxel_size": voxel_size,
        "voxel_triangles": voxel_triangles,
        "final_triangles": final_triangles,
        "split_uv_seam_edges": split_edges,
        "atlas": str(atlas_path),
        "glb": str(glb_path),
        "blend": str(blend_path),
        "previews": [str(front_path), str(three_quarter_path)],
    }
    report_path = out_dir / "emberfang_gate_report.json"
    report_path.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print("EMBERFANG_REBUILD_REPORT=" + json.dumps(report))


if __name__ == "__main__":
    main()
