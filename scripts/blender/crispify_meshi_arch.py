"""Conservatively planarize the original low-poly Emberfang Gate.

Unlike the voxel-rebuild experiments, this pass keeps the original triangle
budget, UVs, texture, and silhouette. It detects connected architectural patches
whose triangles already point almost entirely along X/Y/Z and snaps only their
dominant coordinate to a shared plane. Small ornaments and curved arch surfaces
are left untouched.
"""

from __future__ import annotations

import argparse
import importlib.util
import json
import math
import sys
from collections import defaultdict, deque
from pathlib import Path

import bpy
import bmesh
from mathutils import Vector


def parse_args() -> argparse.Namespace:
    argv = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", required=True)
    parser.add_argument("--output-dir", required=True)
    parser.add_argument("--slug", default="emberfang_gate")
    parser.add_argument("--theme", choices=("hell", "heaven"), default="hell")
    parser.add_argument("--axis-threshold", type=float, default=0.965)
    parser.add_argument("--normal-angle", type=float, default=10.0)
    parser.add_argument("--plane-band", type=float, default=0.075)
    parser.add_argument("--min-patch-area", type=float, default=0.16)
    parser.add_argument("--min-patch-faces", type=int, default=3)
    parser.add_argument("--max-snap", type=float, default=0.12)
    return parser.parse_args(argv)


def load_render_helpers():
    path = Path(__file__).with_name("rebuild_emberfang_from_meshy.py")
    spec = importlib.util.spec_from_file_location("emberfang_render_helpers", path)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"Unable to load {path}")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def clear_scene() -> None:
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)


def import_largest_mesh(path: Path, object_name: str) -> bpy.types.Object:
    bpy.ops.import_scene.gltf(filepath=str(path))
    meshes = [obj for obj in bpy.context.scene.objects if obj.type == "MESH"]
    if not meshes:
        raise RuntimeError(f"No mesh in {path}")
    target = max(meshes, key=lambda obj: len(obj.data.polygons))
    for obj in meshes:
        if obj is not target:
            bpy.data.objects.remove(obj, do_unlink=True)
    target.name = object_name
    bpy.context.view_layer.objects.active = target
    target.select_set(True)
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    return target


def merge_exact_duplicates(target: bpy.types.Object) -> int:
    before = len(target.data.vertices)
    bpy.context.view_layer.objects.active = target
    target.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.mesh.remove_doubles(threshold=2e-6)
    bpy.ops.object.mode_set(mode="OBJECT")
    return before - len(target.data.vertices)


def remove_degenerate_geometry(target: bpy.types.Object) -> int:
    mesh = target.data
    bm = bmesh.new()
    bm.from_mesh(mesh)
    degenerate = [face for face in bm.faces if face.calc_area() <= 1e-10]
    removed = len(degenerate)
    if degenerate:
        bmesh.ops.delete(bm, geom=degenerate, context="FACES")
    bmesh.ops.triangulate(bm, faces=list(bm.faces), quad_method="BEAUTY", ngon_method="BEAUTY")
    bm.to_mesh(mesh)
    bm.free()
    mesh.update()
    return removed


def planarize_axis_patches(target: bpy.types.Object, args: argparse.Namespace) -> dict:
    mesh = target.data
    mesh.update()
    centers = [poly.center.copy() for poly in mesh.polygons]
    normals = [poly.normal.copy() for poly in mesh.polygons]
    areas = [poly.area for poly in mesh.polygons]

    edge_faces: dict[tuple[int, int], list[int]] = defaultdict(list)
    for poly in mesh.polygons:
        for edge in poly.edge_keys:
            edge_faces[tuple(sorted(edge))].append(poly.index)
    neighbors: list[set[int]] = [set() for _ in mesh.polygons]
    for face_indices in edge_faces.values():
        if len(face_indices) == 2:
            a, b = face_indices
            neighbors[a].add(b)
            neighbors[b].add(a)

    candidates: dict[int, tuple[int, int]] = {}
    for poly in mesh.polygons:
        normal = normals[poly.index]
        magnitudes = (abs(normal.x), abs(normal.y), abs(normal.z))
        axis = max(range(3), key=magnitudes.__getitem__)
        if magnitudes[axis] >= args.axis_threshold:
            candidates[poly.index] = (axis, 1 if normal[axis] >= 0.0 else -1)

    visited: set[int] = set()
    patches = []
    cosine_limit = math.cos(math.radians(args.normal_angle))
    for seed, seed_key in candidates.items():
        if seed in visited:
            continue
        queue = deque([seed])
        visited.add(seed)
        patch = []
        while queue:
            current = queue.popleft()
            patch.append(current)
            axis, _sign = candidates[current]
            for neighbor in neighbors[current]:
                if neighbor in visited or candidates.get(neighbor) != seed_key:
                    continue
                if normals[current].dot(normals[neighbor]) < cosine_limit:
                    continue
                if abs(centers[current][axis] - centers[neighbor][axis]) > args.plane_band:
                    continue
                visited.add(neighbor)
                queue.append(neighbor)
        patch_area = sum(areas[index] for index in patch)
        if len(patch) >= args.min_patch_faces and patch_area >= args.min_patch_area:
            patches.append((seed_key[0], patch, patch_area))

    proposals: dict[tuple[int, int], tuple[float, float]] = {}
    accepted = []
    for axis, patch, patch_area in patches:
        total_area = sum(areas[index] for index in patch)
        plane = sum(centers[index][axis] * areas[index] for index in patch) / total_area
        vertex_indices = {vertex for face_index in patch for vertex in mesh.polygons[face_index].vertices}
        moved = 0
        max_delta = 0.0
        for vertex_index in vertex_indices:
            current = mesh.vertices[vertex_index].co[axis]
            delta = plane - current
            if abs(delta) > args.max_snap:
                continue
            key = (vertex_index, axis)
            previous = proposals.get(key)
            if previous is None or patch_area > previous[1]:
                proposals[key] = (plane, patch_area)
                moved += 1
                max_delta = max(max_delta, abs(delta))
        accepted.append(
            {
                "axis": "XYZ"[axis],
                "faces": len(patch),
                "area": patch_area,
                "vertices": moved,
                "max_delta": max_delta,
            }
        )

    displacement_sum = 0.0
    moved_vertices = set()
    for (vertex_index, axis), (plane, _weight) in proposals.items():
        vertex = mesh.vertices[vertex_index]
        displacement_sum += abs(plane - vertex.co[axis])
        vertex.co[axis] = plane
        moved_vertices.add(vertex_index)
    mesh.update()
    for polygon in mesh.polygons:
        polygon.use_smooth = False

    return {
        "candidate_faces": len(candidates),
        "accepted_patches": len(accepted),
        "moved_vertices": len(moved_vertices),
        "coordinate_snaps": len(proposals),
        "mean_coordinate_displacement": displacement_sum / max(len(proposals), 1),
        "largest_patches": sorted(accepted, key=lambda patch: patch["area"], reverse=True)[:20],
    }


def tune_original_materials(target: bpy.types.Object) -> None:
    """Keep the source palette, but remove plastic shading and smoothing."""
    for material in target.data.materials:
        if material is None or not material.use_nodes:
            continue
        bsdf = material.node_tree.nodes.get("Principled BSDF")
        if bsdf is None:
            continue
        bsdf.inputs["Metallic"].default_value = 0.10
        bsdf.inputs["Roughness"].default_value = 0.67
        if "Coat Weight" in bsdf.inputs:
            bsdf.inputs["Coat Weight"].default_value = 0.0


def render_closeup(target: bpy.types.Object, output: Path, theme: str) -> None:
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x = 768
    scene.render.resolution_y = 768
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.render.filepath = str(output)
    scene.view_settings.exposure = -0.15 if theme == "heaven" else 0.0
    scene.world.use_nodes = True
    background = scene.world.node_tree.nodes.get("Background")
    background.inputs["Color"].default_value = (0.008, 0.010, 0.014, 1.0)
    background.inputs["Strength"].default_value = 0.24

    corners = [target.matrix_world @ Vector(corner) for corner in target.bound_box]
    low = Vector((min(p.x for p in corners), min(p.y for p in corners), min(p.z for p in corners)))
    high = Vector((max(p.x for p in corners), max(p.y for p in corners), max(p.z for p in corners)))
    size = high - low
    light_energy_scale = (max(size.x, size.z) / 12.0) ** 2
    focus = Vector((low.x + size.x * 0.18, (low.y + high.y) * 0.5, low.z + size.z * 0.46))
    camera_distance = max(size.x, size.z) * 1.15
    bpy.ops.object.camera_add(location=(focus.x, low.y - camera_distance, focus.z + size.z * 0.03))
    camera = bpy.context.active_object
    camera.data.type = "ORTHO"
    camera.data.ortho_scale = size.z * 0.53
    camera.rotation_euler = (focus - camera.location).to_track_quat("-Z", "Y").to_euler()
    scene.camera = camera

    rim_color = (0.12, 0.55, 1.0) if theme == "heaven" else (1.0, 0.12, 0.02)
    for name, location, energy, color, size in (
        (
            "Key",
            tuple(focus + Vector((size.x * 0.30, -size.z * 0.55, size.z * 0.42))),
            1700.0 * light_energy_scale,
            (0.70, 0.82, 1.0),
            size.z * 0.42,
        ),
        (
            "Rim",
            tuple(focus + Vector((-size.x * 0.10, size.z * 0.35, size.z * 0.28))),
            1900.0 * light_energy_scale,
            rim_color,
            size.z * 0.34,
        ),
    ):
        bpy.ops.object.light_add(type="AREA", location=location)
        light = bpy.context.active_object
        light.name = name
        light.data.energy = energy
        light.data.color = color
        light.data.size = size
        light.rotation_euler = (focus - light.location).to_track_quat("-Z", "Y").to_euler()
    bpy.ops.render.render(write_still=True)
    for obj in list(scene.objects):
        if obj.type in {"CAMERA", "LIGHT"}:
            bpy.data.objects.remove(obj, do_unlink=True)


def main() -> None:
    args = parse_args()
    input_path = Path(args.input).expanduser().resolve()
    output_dir = Path(args.output_dir).expanduser().resolve()
    output_dir.mkdir(parents=True, exist_ok=True)
    helpers = load_render_helpers()
    clear_scene()
    object_name = "".join(part.capitalize() for part in args.slug.split("_")) + "_CrispMeshi"
    target = import_largest_mesh(input_path, object_name)
    target.data.calc_loop_triangles()
    original_triangles = len(target.data.loop_triangles)
    merged_vertices = merge_exact_duplicates(target)
    planar_report = planarize_axis_patches(target, args)
    removed_degenerate_faces = remove_degenerate_geometry(target)
    tune_original_materials(target)

    glb_path = output_dir / f"{args.slug}_crisp.glb"
    bpy.ops.object.select_all(action="DESELECT")
    target.select_set(True)
    bpy.context.view_layer.objects.active = target
    bpy.ops.export_scene.gltf(
        filepath=str(glb_path), export_format="GLB", use_selection=True, export_apply=True, export_yup=True
    )

    front_path = output_dir / f"{args.slug}_front.png"
    three_quarter_path = output_dir / f"{args.slug}_three_quarter.png"
    closeup_path = output_dir / f"{args.slug}_tower_closeup.png"
    rim_color = (0.12, 0.55, 1.0) if args.theme == "heaven" else (1.0, 0.16, 0.025)
    max_dimension = max(target.dimensions)
    light_energy_scale = (max_dimension / 12.0) ** 2
    exposure = -0.15 if args.theme == "heaven" else 0.0
    helpers.render_preview(
        target,
        front_path,
        azimuth=0.0,
        rim_color=rim_color,
        exposure=exposure,
        light_energy_scale=light_energy_scale,
    )
    helpers.render_preview(
        target,
        three_quarter_path,
        azimuth=34.0,
        rim_color=rim_color,
        exposure=exposure,
        light_energy_scale=light_energy_scale,
    )
    render_closeup(target, closeup_path, args.theme)
    blend_path = output_dir / f"{args.slug}_crisp.blend"
    bpy.ops.wm.save_as_mainfile(filepath=str(blend_path))

    target.data.calc_loop_triangles()
    report = {
        "input": str(input_path),
        "slug": args.slug,
        "theme": args.theme,
        "original_triangles": original_triangles,
        "final_triangles": len(target.data.loop_triangles),
        "merged_exact_duplicate_vertices": merged_vertices,
        "removed_degenerate_faces": removed_degenerate_faces,
        "settings": {
            "axis_threshold": args.axis_threshold,
            "normal_angle": args.normal_angle,
            "plane_band": args.plane_band,
            "min_patch_area": args.min_patch_area,
            "min_patch_faces": args.min_patch_faces,
            "max_snap": args.max_snap,
        },
        "planarization": planar_report,
        "glb": str(glb_path),
        "blend": str(blend_path),
        "previews": [str(front_path), str(three_quarter_path), str(closeup_path)],
    }
    (output_dir / f"{args.slug}_report.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print("EMBERFANG_CRISP_REPORT=" + json.dumps(report))


if __name__ == "__main__":
    main()
