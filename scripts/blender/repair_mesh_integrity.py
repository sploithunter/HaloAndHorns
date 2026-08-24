#!/usr/bin/env python3
"""Fill open boundary loops in a GLB and export a repaired copy.

Run with Blender, for example:

    blender --background --python scripts/blender/repair_mesh_integrity.py -- \
        --input model.glb --output model_repaired.glb --max-triangles 9990

The source is never modified. Coincident vertices are welded, boundary loops
are filled, the result is triangulated, and light decimation is applied only
when needed to respect the triangle ceiling.
"""

from __future__ import annotations

import argparse
import json
import sys
import tempfile
from pathlib import Path

import bmesh
import bpy
from mathutils import Vector


def parse_args() -> argparse.Namespace:
    argv = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--report", type=Path)
    parser.add_argument("--max-triangles", type=int, default=9990)
    parser.add_argument("--weld-ratio", type=float, default=1e-7)
    parser.add_argument("--min-component-faces", type=int, default=2)
    parser.add_argument(
        "--voxel-remesh-ratio",
        type=float,
        default=0.0,
        help="Optional voxel size as a fraction of the mesh diagonal",
    )
    return parser.parse_args(argv)


def triangle_count(obj: bpy.types.Object) -> int:
    depsgraph = bpy.context.evaluated_depsgraph_get()
    evaluated = obj.evaluated_get(depsgraph)
    mesh = evaluated.to_mesh()
    try:
        mesh.calc_loop_triangles()
        return len(mesh.loop_triangles)
    finally:
        evaluated.to_mesh_clear()


def add_closed_boundary_faces(bm: bmesh.types.BMesh) -> int:
    """Create one n-gon for each still-open simple boundary loop."""
    boundary = [edge for edge in bm.edges if edge.is_boundary]
    unseen = set(boundary)
    added = 0
    while unseen:
        seed = unseen.pop()
        component = {seed}
        stack = [seed]
        while stack:
            edge = stack.pop()
            for vertex in edge.verts:
                for linked in vertex.link_edges:
                    if linked in unseen and linked.is_boundary:
                        unseen.remove(linked)
                        component.add(linked)
                        stack.append(linked)

        adjacency: dict[bmesh.types.BMVert, list[bmesh.types.BMVert]] = {}
        for edge in component:
            a, b = edge.verts
            adjacency.setdefault(a, []).append(b)
            adjacency.setdefault(b, []).append(a)
        if len(adjacency) < 3 or any(len(neighbors) != 2 for neighbors in adjacency.values()):
            continue

        start = next(iter(adjacency))
        ordered = [start]
        previous = None
        current = start
        while True:
            candidates = [vertex for vertex in adjacency[current] if vertex is not previous]
            if not candidates:
                break
            nxt = candidates[0]
            if nxt is start:
                break
            if nxt in ordered:
                ordered = []
                break
            ordered.append(nxt)
            previous, current = current, nxt
        if len(ordered) != len(adjacency):
            continue
        try:
            bm.faces.new(ordered)
            added += 1
        except ValueError:
            continue
    return added


def remove_small_face_components(bm: bmesh.types.BMesh, minimum_faces: int) -> int:
    unseen = set(bm.faces)
    removed = 0
    while unseen:
        seed = unseen.pop()
        component = {seed}
        stack = [seed]
        while stack:
            face = stack.pop()
            for edge in face.edges:
                for linked in edge.link_faces:
                    if linked in unseen:
                        unseen.remove(linked)
                        component.add(linked)
                        stack.append(linked)
        if len(component) < minimum_faces:
            removed += len(component)
            bmesh.ops.delete(bm, geom=list(component), context="FACES")
    return removed


def remove_nonmanifold_extra_faces(bm: bmesh.types.BMesh) -> int:
    """Peel the smallest flap faces until no edge has more than two owners."""
    removed = 0
    while True:
        bad_edges = [edge for edge in bm.edges if len(edge.link_faces) > 2]
        if not bad_edges:
            return removed
        bad_set = set(bad_edges)
        candidates = {face for edge in bad_edges for face in edge.link_faces}
        victim = min(
            candidates,
            key=lambda face: (
                -sum(1 for edge in face.edges if edge in bad_set),
                face.calc_area(),
            ),
        )
        bmesh.ops.delete(bm, geom=[victim], context="FACES")
        removed += 1


def clean_mesh(
    obj: bpy.types.Object,
    *,
    weld_distance: float,
    area_epsilon: float,
    minimum_component_faces: int,
) -> dict[str, int]:
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bmesh.ops.remove_doubles(bm, verts=list(bm.verts), dist=weld_distance)
    bm.verts.ensure_lookup_table()
    bm.verts.index_update()
    seen_faces: set[tuple[int, ...]] = set()
    duplicate_faces = []
    for face in bm.faces:
        key = tuple(sorted(vertex.index for vertex in face.verts))
        if key in seen_faces:
            duplicate_faces.append(face)
        else:
            seen_faces.add(key)
    if duplicate_faces:
        # Retexture can split UV seams into coincident vertices and occasionally
        # emit the same geometric triangle twice. After welding, those copies
        # create 3+-face edges even though the source geometry was manifold.
        bmesh.ops.delete(bm, geom=duplicate_faces, context="FACES")
    nonmanifold_faces = remove_nonmanifold_extra_faces(bm)
    degenerate_faces = [
        face
        for face in bm.faces
        if len(set(face.verts)) < 3 or face.calc_area() <= area_epsilon
    ]
    if degenerate_faces:
        bmesh.ops.delete(bm, geom=degenerate_faces, context="FACES_ONLY")
    removed_component_faces = remove_small_face_components(bm, minimum_component_faces)
    boundary_edges = [edge for edge in bm.edges if edge.is_boundary]
    boundary_count = len(boundary_edges)
    filled_faces = 0
    if boundary_edges:
        # Cap each simple closed boundary independently before asking Blender's
        # bulk operators to handle irregular edge nets. Passing every boundary
        # loop to holes_fill at once can bridge unrelated openings and leave a
        # one-edge tear after triangulation/decimation.
        filled_faces += add_closed_boundary_faces(bm)
        remaining = [edge for edge in bm.edges if edge.is_boundary]
        result = bmesh.ops.holes_fill(bm, edges=remaining, sides=0)
        filled_faces += len(result.get("faces", []))
        remaining = [edge for edge in bm.edges if edge.is_boundary]
        if remaining:
            result = bmesh.ops.triangle_fill(bm, edges=remaining, use_beauty=True)
            filled_faces += len(result.get("faces", []))
        remaining = [edge for edge in bm.edges if edge.is_boundary]
        if remaining:
            result = bmesh.ops.edgenet_fill(
                bm,
                edges=remaining,
                mat_nr=0,
                use_smooth=False,
                sides=0,
            )
            filled_faces += len(result.get("faces", []))
        filled_faces += add_closed_boundary_faces(bm)
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    bmesh.ops.triangulate(bm, faces=list(bm.faces))
    bm.to_mesh(obj.data)
    bm.free()
    obj.data.update()
    return {
        "boundary_edges_found": boundary_count,
        "fill_faces_added": filled_faces,
        "duplicate_faces_removed": len(duplicate_faces),
        "nonmanifold_faces_removed": nonmanifold_faces,
        "degenerate_faces_removed": len(degenerate_faces),
        "small_component_faces_removed": removed_component_faces,
    }


def main() -> None:
    args = parse_args()
    source = args.input.resolve()
    output = args.output.resolve()
    report_path = args.report.resolve() if args.report else output.with_suffix(".repair.json")

    if not source.is_file():
        raise FileNotFoundError(source)
    if source == output:
        raise ValueError("--output must differ from --input")

    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(source))
    mesh_objects = [obj for obj in bpy.context.scene.objects if obj.type == "MESH"]
    if not mesh_objects:
        raise RuntimeError("No mesh objects found in input")

    bpy.ops.object.select_all(action="DESELECT")
    for obj in mesh_objects:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = mesh_objects[0]
    if len(mesh_objects) > 1:
        bpy.ops.object.join()
    obj = bpy.context.view_layer.objects.active
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)

    bounds = [obj.matrix_world @ Vector(corner) for corner in obj.bound_box]
    diagonal = max((a - b).length for a in bounds for b in bounds)
    weld_distance = max(diagonal * args.weld_ratio, 1e-9)

    raw_vertices = len(obj.data.vertices)
    area_epsilon = max(diagonal * diagonal * 1e-14, 1e-18)
    initial_cleanup = clean_mesh(
        obj,
        weld_distance=weld_distance,
        area_epsilon=area_epsilon,
        minimum_component_faces=args.min_component_faces,
    )

    voxel_size = 0.0
    if args.voxel_remesh_ratio > 0:
        voxel_size = diagonal * args.voxel_remesh_ratio
        obj.data.remesh_voxel_size = voxel_size
        obj.data.remesh_voxel_adaptivity = 0.0
        bpy.context.view_layer.objects.active = obj
        bpy.ops.object.voxel_remesh()

    repaired_triangles = triangle_count(obj)
    decimation_ratio = 1.0
    if repaired_triangles > args.max_triangles:
        decimation_target = max(100, args.max_triangles - 32)
        decimation_ratio = decimation_target / repaired_triangles
        modifier = obj.modifiers.new(name="Triangle ceiling", type="DECIMATE")
        modifier.decimate_type = "COLLAPSE"
        modifier.ratio = decimation_ratio
        modifier.use_collapse_triangulate = True
        bpy.context.view_layer.objects.active = obj
        bpy.ops.object.modifier_apply(modifier=modifier.name)

    final_cleanup = clean_mesh(
        obj,
        weld_distance=weld_distance,
        area_epsilon=area_epsilon,
        minimum_component_faces=args.min_component_faces,
    )
    with tempfile.TemporaryDirectory(prefix="meshy-repair-") as temp_dir:
        roundtrip = Path(temp_dir) / "roundtrip.glb"
        bpy.ops.object.select_all(action="DESELECT")
        obj.select_set(True)
        bpy.context.view_layer.objects.active = obj
        bpy.ops.export_scene.gltf(
            filepath=str(roundtrip),
            export_format="GLB",
            use_selection=True,
            export_apply=True,
        )
        bpy.ops.wm.read_factory_settings(use_empty=True)
        bpy.ops.import_scene.gltf(filepath=str(roundtrip))
        roundtrip_objects = [
            candidate for candidate in bpy.context.scene.objects if candidate.type == "MESH"
        ]
        if not roundtrip_objects:
            raise RuntimeError("No mesh objects found after GLB validation round trip")
        bpy.ops.object.select_all(action="DESELECT")
        for candidate in roundtrip_objects:
            candidate.select_set(True)
        bpy.context.view_layer.objects.active = roundtrip_objects[0]
        if len(roundtrip_objects) > 1:
            bpy.ops.object.join()
        obj = bpy.context.view_layer.objects.active
        roundtrip_cleanup = clean_mesh(
            obj,
            weld_distance=weld_distance,
            area_epsilon=area_epsilon,
            minimum_component_faces=args.min_component_faces,
        )
    final_triangles = triangle_count(obj)
    if final_triangles > args.max_triangles:
        raise RuntimeError(
            f"Repair produced {final_triangles} triangles, above ceiling {args.max_triangles}"
        )
    output.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.export_scene.gltf(
        filepath=str(output),
        export_format="GLB",
        use_selection=True,
        export_apply=True,
    )

    report = {
        "schema_version": 1,
        "input": str(source),
        "output": str(output),
        "raw_vertices": raw_vertices,
        "weld_distance": weld_distance,
        "initial_cleanup": initial_cleanup,
        "final_cleanup": final_cleanup,
        "roundtrip_cleanup": roundtrip_cleanup,
        "voxel_size": voxel_size,
        "triangles_after_fill": repaired_triangles,
        "decimation_ratio": decimation_ratio,
        "final_triangles": final_triangles,
        "max_triangles": args.max_triangles,
    }
    report_path.parent.mkdir(parents=True, exist_ok=True)
    report_path.write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps(report, indent=2))


if __name__ == "__main__":
    main()
