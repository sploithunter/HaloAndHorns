"""Fail a geometry gate when a GLB/FBX/OBJ contains holes or non-manifold edges.

Run with Blender so the importer and ``bmesh`` topology are identical to the rest of the asset
pipeline:

    blender --background --python scripts/blender/check_mesh_integrity.py -- \
      --input /path/to/model.glb --report /path/to/integrity.json

The default gate is intentionally strict: every edge must belong to exactly two faces. This catches
open boundary loops (including gaping holes), wire edges, and edges shared by three or more faces.
Smart Topology assets may contain several separate objects/parts; each part is checked independently.
"""

from __future__ import annotations

import argparse
import json
import math
import sys
from collections import defaultdict, deque
from pathlib import Path
from typing import Any

import bmesh
import bpy

SUPPORTED_SUFFIXES = {".fbx", ".glb", ".gltf", ".obj"}


def parse_args() -> argparse.Namespace:
    argv = sys.argv
    argv = argv[argv.index("--") + 1 :] if "--" in argv else []
    parser = argparse.ArgumentParser(description="Check a mesh for holes and non-manifold topology.")
    parser.add_argument("--input", required=True, help="GLB/GLTF/FBX/OBJ file to inspect.")
    parser.add_argument("--report", help="Optional JSON report path.")
    parser.add_argument(
        "--max-boundary-edges",
        type=int,
        default=0,
        help="Maximum allowed edges with exactly one linked face (default: 0).",
    )
    parser.add_argument(
        "--max-non-manifold-edges",
        type=int,
        default=0,
        help="Maximum allowed wire or 3+-face edges (default: 0).",
    )
    return parser.parse_args(argv)


def clear_scene() -> None:
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)


def import_mesh(source: Path) -> list[bpy.types.Object]:
    suffix = source.suffix.lower()
    if suffix not in SUPPORTED_SUFFIXES:
        raise ValueError(f"Unsupported mesh format: {suffix}")
    if suffix in {".glb", ".gltf"}:
        bpy.ops.import_scene.gltf(filepath=str(source))
    elif suffix == ".fbx":
        bpy.ops.import_scene.fbx(filepath=str(source))
    else:
        bpy.ops.wm.obj_import(filepath=str(source))
    meshes = sorted((obj for obj in bpy.context.scene.objects if obj.type == "MESH"), key=lambda obj: obj.name)
    if not meshes:
        raise RuntimeError(f"No mesh objects imported from {source}")
    return meshes


def mesh_diagonal(bm: bmesh.types.BMesh) -> float:
    if not bm.verts:
        return 0.0
    xs = [vertex.co.x for vertex in bm.verts]
    ys = [vertex.co.y for vertex in bm.verts]
    zs = [vertex.co.z for vertex in bm.verts]
    return math.sqrt(
        (max(xs) - min(xs)) ** 2 + (max(ys) - min(ys)) ** 2 + (max(zs) - min(zs)) ** 2
    )


def boundary_components(edges: list[bmesh.types.BMEdge], diagonal: float) -> list[dict[str, Any]]:
    by_vertex: dict[bmesh.types.BMVert, list[bmesh.types.BMEdge]] = defaultdict(list)
    for edge in edges:
        for vertex in edge.verts:
            by_vertex[vertex].append(edge)

    remaining = set(edges)
    components = []
    while remaining:
        seed = remaining.pop()
        stack = [seed]
        component_edges = [seed]
        component_vertices = set(seed.verts)
        while stack:
            edge = stack.pop()
            for vertex in edge.verts:
                for neighbor in by_vertex[vertex]:
                    if neighbor in remaining:
                        remaining.remove(neighbor)
                        stack.append(neighbor)
                        component_edges.append(neighbor)
                        component_vertices.update(neighbor.verts)
        degrees = {
            vertex: sum(1 for edge in component_edges if vertex in edge.verts)
            for vertex in component_vertices
        }
        perimeter = sum(edge.calc_length() for edge in component_edges)
        components.append(
            {
                "edge_count": len(component_edges),
                "vertex_count": len(component_vertices),
                "closed_loop": bool(component_vertices) and all(degree == 2 for degree in degrees.values()),
                "perimeter": perimeter,
                "perimeter_to_mesh_diagonal": perimeter / diagonal if diagonal > 0 else None,
            }
        )
    return sorted(components, key=lambda item: item["perimeter"], reverse=True)


def face_component_count(bm: bmesh.types.BMesh) -> int:
    remaining = set(bm.faces)
    count = 0
    while remaining:
        count += 1
        seed = remaining.pop()
        queue = deque([seed])
        while queue:
            face = queue.popleft()
            for edge in face.edges:
                for neighbor in edge.link_faces:
                    if neighbor in remaining:
                        remaining.remove(neighbor)
                        queue.append(neighbor)
    return count


def inspect_object(obj: bpy.types.Object) -> dict[str, Any]:
    bm = bmesh.new()
    try:
        bm.from_mesh(obj.data)
        bm.verts.ensure_lookup_table()
        bm.edges.ensure_lookup_table()
        bm.faces.ensure_lookup_table()
        raw_vertices = len(bm.verts)
        diagonal = mesh_diagonal(bm)
        # GLB/FBX importers split vertices along hard-normal and UV seams. Those are not geometric
        # holes, so weld only position-identical vertices in this in-memory inspection copy before
        # counting boundary edges. The tolerance scales with the object and is intentionally tiny.
        weld_distance = max(diagonal * 1e-7, 1e-9)
        bmesh.ops.remove_doubles(bm, verts=list(bm.verts), dist=weld_distance)
        bm.verts.ensure_lookup_table()
        bm.edges.ensure_lookup_table()
        bm.faces.ensure_lookup_table()
        welded_vertices = len(bm.verts)
        diagonal = mesh_diagonal(bm)
        boundary = [edge for edge in bm.edges if len(edge.link_faces) == 1]
        wire = [edge for edge in bm.edges if len(edge.link_faces) == 0]
        multi_face = [edge for edge in bm.edges if len(edge.link_faces) > 2]
        epsilon_edge = max(diagonal * 1e-9, 1e-12)
        epsilon_area = max(diagonal * diagonal * 1e-12, 1e-18)
        zero_length = [edge for edge in bm.edges if edge.calc_length() <= epsilon_edge]
        zero_area = [face for face in bm.faces if face.calc_area() <= epsilon_area]
        return {
            "name": obj.name,
            "vertices": welded_vertices,
            "raw_vertices": raw_vertices,
            "welded_coincident_vertices": raw_vertices - welded_vertices,
            "inspection_weld_distance": weld_distance,
            "edges": len(bm.edges),
            "faces": len(bm.faces),
            "triangles": sum(max(len(face.verts) - 2, 0) for face in bm.faces),
            "face_components": face_component_count(bm),
            "bounds_diagonal": diagonal,
            "boundary_edges": len(boundary),
            "boundary_components": boundary_components(boundary, diagonal),
            "wire_edges": len(wire),
            "edges_with_three_or_more_faces": len(multi_face),
            "zero_length_edges": len(zero_length),
            "zero_area_faces": len(zero_area),
        }
    finally:
        bm.free()


def build_report(source: Path, objects: list[bpy.types.Object], args: argparse.Namespace) -> dict[str, Any]:
    reports = [inspect_object(obj) for obj in objects]
    totals = {
        key: sum(int(report[key]) for report in reports)
        for key in (
            "vertices",
            "edges",
            "faces",
            "triangles",
            "face_components",
            "boundary_edges",
            "wire_edges",
            "edges_with_three_or_more_faces",
            "zero_length_edges",
            "zero_area_faces",
        )
    }
    non_manifold = totals["wire_edges"] + totals["edges_with_three_or_more_faces"]
    failures = []
    if totals["boundary_edges"] > args.max_boundary_edges:
        failures.append(
            f"boundary edges {totals['boundary_edges']} exceed allowed {args.max_boundary_edges}"
        )
    if non_manifold > args.max_non_manifold_edges:
        failures.append(
            f"wire/3+-face edges {non_manifold} exceed allowed {args.max_non_manifold_edges}"
        )
    if totals["zero_length_edges"]:
        failures.append(f"zero-length edges: {totals['zero_length_edges']}")
    if totals["zero_area_faces"]:
        failures.append(f"zero-area faces: {totals['zero_area_faces']}")
    return {
        "schema_version": 1,
        "input": str(source),
        "passed": not failures,
        "limits": {
            "max_boundary_edges": args.max_boundary_edges,
            "max_non_manifold_edges": args.max_non_manifold_edges,
        },
        "totals": totals,
        "objects": reports,
        "failures": failures,
    }


def main() -> int:
    args = parse_args()
    source = Path(args.input).expanduser().resolve()
    if not source.is_file():
        raise FileNotFoundError(f"Mesh not found: {source}")
    if args.max_boundary_edges < 0 or args.max_non_manifold_edges < 0:
        raise ValueError("Allowed edge counts cannot be negative.")
    clear_scene()
    report = build_report(source, import_mesh(source), args)
    if args.report:
        report_path = Path(args.report).expanduser().resolve()
        report_path.parent.mkdir(parents=True, exist_ok=True)
        report_path.write_text(f"{json.dumps(report, indent=2)}\n", encoding="utf-8")
    print(json.dumps(report, indent=2))
    return 0 if report["passed"] else 2


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as error:  # Blender should surface a concise gate failure in CI logs.
        print(f"mesh integrity checker error: {error}", file=sys.stderr)
        raise
