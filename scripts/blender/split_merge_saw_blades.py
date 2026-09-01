"""Split a Merge saw-blade bulwark into a stationary base and pivoted rotors.

The accepted Meshy assets are not authored consistently: tiers 1 and 4 contain
many loose shells, while tiers 2 and 3 are each a single watertight component.
Separating by loose parts therefore cannot produce a usable rig.  This script
partitions the *existing* faces around calibrated axle volumes instead.  It
does not remesh, decimate, normalize, or rescale the source, so the original
UVs, texture, proportions, and triangle budget survive unchanged.

Run with Blender:

    blender --background --python scripts/blender/split_merge_saw_blades.py -- \
      --tier 1 --input /path/to/model.glb --output-dir /path/to/tier1/rigged

Outputs:
  - model.blend: packed editable source with Base + Blade01..BladeNN
  - model.glb: neutral-pose multi-object exchange file
  - model.fbx: neutral-pose Roblox import file
  - report.json: bounds, pivots, axes, and triangle accounting
  - preview.png / preview_parts.png: visual verification renders
"""

from __future__ import annotations

import argparse
from collections import defaultdict
import json
import math
import sys
from dataclasses import dataclass
from pathlib import Path

import bmesh
import bpy
from mathutils import Matrix, Vector


@dataclass(frozen=True)
class Rotor:
    center: tuple[float, float, float]
    radius: float
    half_thickness: float


@dataclass(frozen=True)
class TierSpec:
    axis: str
    rotors: tuple[Rotor, ...]
    component_partition: bool = False


# These values are in the untouched GLB's local space.  The fourth Meshy asset
# interpreted the reference as four disks on a shared longitudinal axle, so its
# rotation axis is X; tiers 1-3 face the player and rotate around Y.
TIER_SPECS: dict[int, TierSpec] = {
    1: TierSpec(
        axis="Y",
        rotors=(Rotor((0.030, 0.000, 0.055), 0.415, 0.073),),
        component_partition=True,
    ),
    2: TierSpec(
        axis="Y",
        rotors=(
            Rotor((-0.550, -0.043, 0.025), 0.330, 0.062),
            Rotor((0.550, -0.043, 0.025), 0.330, 0.062),
        ),
    ),
    3: TierSpec(
        axis="Y",
        rotors=(
            Rotor((-0.550, -0.110, 0.000), 0.315, 0.065),
            Rotor((0.000, -0.110, 0.025), 0.370, 0.065),
            Rotor((0.550, -0.110, 0.000), 0.315, 0.065),
        ),
    ),
    4: TierSpec(
        axis="X",
        rotors=(
            Rotor((-0.717, 0.000, 0.015), 0.385, 0.070),
            Rotor((-0.236, 0.000, 0.015), 0.385, 0.070),
            Rotor((0.233, 0.000, 0.015), 0.385, 0.070),
            Rotor((0.737, 0.000, 0.015), 0.385, 0.070),
        ),
        component_partition=True,
    ),
}


def parse_args() -> argparse.Namespace:
    argv = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--tier", type=int, choices=sorted(TIER_SPECS), required=True)
    parser.add_argument("--input", required=True, help="Accepted textured GLB.")
    parser.add_argument("--output-dir", required=True)
    return parser.parse_args(argv)


def clear_scene() -> None:
    bpy.ops.wm.read_factory_settings(use_empty=True)


def import_source(path: Path) -> bpy.types.Object:
    bpy.ops.import_scene.gltf(filepath=str(path))
    meshes = [obj for obj in bpy.context.scene.objects if obj.type == "MESH"]
    if not meshes:
        raise RuntimeError(f"No mesh objects imported from {path}")
    bpy.ops.object.select_all(action="DESELECT")
    for obj in meshes:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = meshes[0]
    if len(meshes) > 1:
        bpy.ops.object.join()
    source = bpy.context.view_layer.objects.active
    source.name = "Source"
    # Bake only the importer transform.  This keeps the GLB's native dimensions
    # while giving every output object an identity scale for predictable pivots.
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    return source


def triangle_count(mesh: bpy.types.Mesh) -> int:
    return sum(max(len(poly.vertices) - 2, 0) for poly in mesh.polygons)


def object_bounds(obj: bpy.types.Object) -> tuple[Vector, Vector]:
    points = [obj.matrix_world @ Vector(corner) for corner in obj.bound_box]
    return (
        Vector((min(point.x for point in points), min(point.y for point in points), min(point.z for point in points))),
        Vector((max(point.x for point in points), max(point.y for point in points), max(point.z for point in points))),
    )


def in_rotor_volume(point: Vector, rotor: Rotor, axis: str) -> bool:
    center = Vector(rotor.center)
    delta = point - center
    if axis == "Y":
        axial = abs(delta.y)
        radial = math.hypot(delta.x, delta.z)
    elif axis == "X":
        axial = abs(delta.x)
        radial = math.hypot(delta.y, delta.z)
    else:
        raise ValueError(f"Unsupported rotation axis: {axis}")
    return axial <= rotor.half_thickness and radial <= rotor.radius


def classify_faces(source: bpy.types.Object, spec: TierSpec) -> list[int]:
    assignments: list[int] = []
    for polygon in source.data.polygons:
        point = source.matrix_world @ polygon.center
        matches = [
            index
            for index, rotor in enumerate(spec.rotors, start=1)
            if in_rotor_volume(point, rotor, spec.axis)
        ]
        if not matches:
            assignments.append(0)
            continue
        if len(matches) == 1:
            assignments.append(matches[0])
            continue
        # Overlapping calibrated volumes are resolved by normalized radial
        # distance so a face is still assigned exactly once.
        def score(index: int) -> float:
            rotor = spec.rotors[index - 1]
            center = Vector(rotor.center)
            delta = point - center
            radial = math.hypot(delta.x, delta.z) if spec.axis == "Y" else math.hypot(delta.y, delta.z)
            return radial / rotor.radius

        assignments.append(min(matches, key=score))
    if not spec.component_partition:
        return assignments
    return classify_loose_components(source, spec, assignments)


def classify_loose_components(
    source: bpy.types.Object, spec: TierSpec, face_assignments: list[int]
) -> list[int]:
    """Keep disconnected hard-surface shells intact for tiers 1 and 4.

    The GLB importer duplicates vertices at UV and hard-normal seams, so edge
    connectivity is reconstructed from quantized positions rather than raw
    vertex indices.  A component becomes a blade only when it lives in the
    axle slab *and* reaches the saw's outer radius; this prevents foundation
    plates and bearing arches from being swept into a rotating rotor.
    """

    def vertex_key(index: int) -> tuple[int, int, int]:
        point = source.matrix_world @ source.data.vertices[index].co
        return tuple(round(value * 1_000_000) for value in point)

    parent = list(range(len(source.data.polygons)))

    def find(value: int) -> int:
        while parent[value] != value:
            parent[value] = parent[parent[value]]
            value = parent[value]
        return value

    def union(left: int, right: int) -> None:
        left_root, right_root = find(left), find(right)
        if left_root != right_root:
            parent[right_root] = left_root

    edge_owner: dict[tuple[tuple[int, int, int], tuple[int, int, int]], int] = {}
    for polygon in source.data.polygons:
        vertices = list(polygon.vertices)
        for offset, left_index in enumerate(vertices):
            right_index = vertices[(offset + 1) % len(vertices)]
            edge = tuple(sorted((vertex_key(left_index), vertex_key(right_index))))
            previous = edge_owner.get(edge)
            if previous is None:
                edge_owner[edge] = polygon.index
            else:
                union(polygon.index, previous)

    components: dict[int, list[int]] = defaultdict(list)
    for index in range(len(source.data.polygons)):
        components[find(index)].append(index)

    resolved = [0] * len(face_assignments)
    for polygon_indices in components.values():
        points = [
            source.matrix_world @ source.data.polygons[index].center
            for index in polygon_indices
        ]
        best: tuple[float, int] | None = None
        for rotor_index, rotor in enumerate(spec.rotors, start=1):
            center = Vector(rotor.center)
            if spec.axis == "Y":
                axial_values = [abs(point.y - center.y) for point in points]
                radial_values = [math.hypot(point.x - center.x, point.z - center.z) for point in points]
            else:
                axial_values = [abs(point.x - center.x) for point in points]
                radial_values = [math.hypot(point.y - center.y, point.z - center.z) for point in points]
            inside = sum(
                axial <= rotor.half_thickness * 1.25 and radial <= rotor.radius * 1.12
                for axial, radial in zip(axial_values, radial_values, strict=True)
            )
            fraction_inside = inside / len(points)
            outer_reach = max(radial_values) / rotor.radius
            mean_reach = (sum(radial_values) / len(radial_values)) / rotor.radius
            upper_reach = max(point.z for point in points) - center.z
            # Saw shells reach well above their axle and toward their calibrated
            # outer radius. Foundation plates and bearing arches do not.
            if (
                fraction_inside >= 0.45
                and outer_reach >= 0.58
                and (
                    upper_reach >= rotor.radius * 0.48
                    or mean_reach >= 0.62
                )
            ):
                score = fraction_inside + min(outer_reach, 1.2) * 0.15
                if best is None or score > best[0]:
                    best = (score, rotor_index)
        wanted = best[1] if best else 0
        for index in polygon_indices:
            resolved[index] = wanted
    return resolved


def retain_face_group(obj: bpy.types.Object, assignments: list[int], wanted: int) -> None:
    bm = bmesh.new()
    try:
        bm.from_mesh(obj.data)
        bm.faces.ensure_lookup_table()
        if len(bm.faces) != len(assignments):
            raise RuntimeError("Face order changed while duplicating source mesh")
        doomed = [face for face, group in zip(bm.faces, assignments, strict=True) if group != wanted]
        bmesh.ops.delete(bm, geom=doomed, context="FACES")
        loose = [vertex for vertex in bm.verts if not vertex.link_faces]
        if loose:
            bmesh.ops.delete(bm, geom=loose, context="VERTS")
        bm.to_mesh(obj.data)
    finally:
        bm.free()
    obj.data.update()


def set_origin_without_moving(obj: bpy.types.Object, origin: Vector) -> None:
    # Geometry moves into origin-local space while the object moves to the old
    # geometry position, so its world-space appearance remains identical.
    obj.data.transform(Matrix.Translation(-origin))
    obj.location = origin
    obj.data.update()


def build_parts(source: bpy.types.Object, tier: int) -> tuple[bpy.types.Object, list[bpy.types.Object]]:
    spec = TIER_SPECS[tier]
    assignments = classify_faces(source, spec)
    parts: list[bpy.types.Object] = []
    for group in range(0, len(spec.rotors) + 1):
        obj = source.copy()
        obj.data = source.data.copy()
        bpy.context.collection.objects.link(obj)
        retain_face_group(obj, assignments, group)
        if group == 0:
            obj.name = "Base"
            obj.data.name = "BaseMesh"
            obj["SawBladePart"] = "Base"
        else:
            rotor = spec.rotors[group - 1]
            obj.name = f"Blade{group:02d}"
            obj.data.name = f"Blade{group:02d}Mesh"
            set_origin_without_moving(obj, Vector(rotor.center))
            obj["SawBladePart"] = "Blade"
            obj["RotationAxis"] = spec.axis
            obj["RotorIndex"] = group
            obj["AxleCenter"] = list(rotor.center)
        parts.append(obj)

    bpy.data.objects.remove(source, do_unlink=True)
    base = parts[0]
    blades = parts[1:]
    base["SawBladeTier"] = tier
    base["BladeCount"] = len(blades)
    return base, blades


def create_root(tier: int, base: bpy.types.Object, blades: list[bpy.types.Object]) -> bpy.types.Object:
    root = bpy.data.objects.new(f"SawBladeTier{tier}", None)
    bpy.context.collection.objects.link(root)
    root["SawBladeRigVersion"] = 1
    root["BladeCount"] = len(blades)
    for obj in (base, *blades):
        obj.parent = root
    return root


def setup_render(objects: list[bpy.types.Object], output: Path) -> None:
    minimum = Vector((math.inf, math.inf, math.inf))
    maximum = Vector((-math.inf, -math.inf, -math.inf))
    for obj in objects:
        low, high = object_bounds(obj)
        minimum.x, minimum.y, minimum.z = min(minimum.x, low.x), min(minimum.y, low.y), min(minimum.z, low.z)
        maximum.x, maximum.y, maximum.z = max(maximum.x, high.x), max(maximum.y, high.y), max(maximum.z, high.z)
    center = (minimum + maximum) / 2
    span = maximum - minimum

    bpy.ops.object.camera_add()
    camera = bpy.context.active_object
    camera.data.type = "ORTHO"
    camera.data.ortho_scale = max(span.x / (16 / 9), span.z) * 1.70
    camera.location = center + Vector((span.x * 0.85, -max(span.x, 1.0) * 1.9, span.z * 1.15))
    camera.rotation_euler = (center - camera.location).to_track_quat("-Z", "Y").to_euler()
    bpy.context.scene.camera = camera

    for name, location, energy, size in (
        ("Key", center + Vector((-1.2, -2.0, 2.2)), 75, 2.0),
        ("Fill", center + Vector((1.8, -0.8, 1.0)), 28, 2.5),
        ("Rim", center + Vector((0.0, 2.0, 1.7)), 48, 1.5),
    ):
        bpy.ops.object.light_add(type="AREA", location=location)
        light = bpy.context.active_object
        light.name = name
        light.data.energy = energy
        light.data.shape = "DISK"
        light.data.size = size

    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x = 1280
    scene.render.resolution_y = 720
    scene.render.resolution_percentage = 100
    scene.render.film_transparent = True
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"
    scene.render.image_settings.compression = 15
    scene.render.filepath = str(output)
    scene.view_settings.look = "AgX - Medium High Contrast"


def render_previews(base: bpy.types.Object, blades: list[bpy.types.Object], output_dir: Path) -> None:
    objects = [base, *blades]
    setup_render(objects, output_dir / "preview.png")
    bpy.ops.render.render(write_still=True)

    original_materials = {obj: list(obj.data.materials) for obj in objects}
    def debug_material(name: str, color: tuple[float, float, float, float]) -> bpy.types.Material:
        material = bpy.data.materials.new(name)
        material.diffuse_color = color
        material.use_nodes = True
        material.node_tree.nodes.get("Principled BSDF").inputs["Base Color"].default_value = color
        material.node_tree.nodes.get("Principled BSDF").inputs["Roughness"].default_value = 0.65
        return material

    debug_base = debug_material("DebugBase", (0.025, 0.035, 0.055, 1.0))
    debug_colors = (
        (1.0, 0.16, 0.08, 1.0),
        (1.0, 0.52, 0.04, 1.0),
        (0.95, 0.90, 0.08, 1.0),
        (0.55, 0.20, 1.0, 1.0),
    )
    base.data.materials.clear()
    base.data.materials.append(debug_base)
    for index, blade in enumerate(blades):
        material = debug_material(
            f"DebugBlade{index + 1:02d}", debug_colors[index % len(debug_colors)]
        )
        blade.data.materials.clear()
        blade.data.materials.append(material)
    bpy.context.scene.render.filepath = str(output_dir / "preview_parts.png")
    bpy.ops.render.render(write_still=True)

    for obj, materials in original_materials.items():
        obj.data.materials.clear()
        for material in materials:
            obj.data.materials.append(material)


def export_assets(output_dir: Path, root: bpy.types.Object, parts: list[bpy.types.Object]) -> None:
    bpy.ops.object.select_all(action="DESELECT")
    root.select_set(True)
    for obj in parts:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = root

    bpy.ops.export_scene.gltf(
        filepath=str(output_dir / "model.glb"),
        export_format="GLB",
        use_selection=True,
        export_apply=False,
        export_extras=True,
    )
    bpy.ops.export_scene.fbx(
        filepath=str(output_dir / "model.fbx"),
        use_selection=True,
        object_types={"EMPTY", "MESH"},
        use_mesh_modifiers=True,
        add_leaf_bones=False,
        bake_anim=False,
        axis_forward="-Z",
        axis_up="Y",
    )


def write_report(
    output_dir: Path,
    source_path: Path,
    tier: int,
    source_bounds: tuple[Vector, Vector],
    source_triangles: int,
    base: bpy.types.Object,
    blades: list[bpy.types.Object],
) -> None:
    spec = TIER_SPECS[tier]
    try:
        source_label = str(source_path.relative_to(Path.cwd().resolve()))
    except ValueError:
        source_label = str(source_path)
    part_rows = []
    for obj in (base, *blades):
        low, high = object_bounds(obj)
        part_rows.append(
            {
                "name": obj.name,
                "triangles": triangle_count(obj.data),
                "origin": list(obj.location),
                "bounds": {"min": list(low), "max": list(high)},
                "rotation_axis": obj.get("RotationAxis"),
            }
        )
    low, high = source_bounds
    output_triangles = sum(row["triangles"] for row in part_rows)
    report = {
        "schema_version": 1,
        "source": source_label,
        "tier": tier,
        "rotation_axis": spec.axis,
        "blade_count": len(blades),
        "source_bounds": {"min": list(low), "max": list(high)},
        "source_triangles": source_triangles,
        "output_triangles": output_triangles,
        "triangle_accounting_exact": source_triangles == output_triangles,
        "parts": part_rows,
    }
    (output_dir / "report.json").write_text(f"{json.dumps(report, indent=2)}\n", encoding="utf-8")
    if source_triangles != output_triangles:
        raise RuntimeError(f"Triangle accounting mismatch: {source_triangles} -> {output_triangles}")


def main() -> int:
    args = parse_args()
    source_path = Path(args.input).expanduser().resolve()
    output_dir = Path(args.output_dir).expanduser().resolve()
    if not source_path.is_file():
        raise FileNotFoundError(source_path)
    output_dir.mkdir(parents=True, exist_ok=True)

    clear_scene()
    source = import_source(source_path)
    source_bounds = object_bounds(source)
    source_triangles = triangle_count(source.data)
    base, blades = build_parts(source, args.tier)
    root = create_root(args.tier, base, blades)

    render_previews(base, blades, output_dir)
    export_assets(output_dir, root, [base, *blades])
    bpy.ops.file.pack_all()
    bpy.ops.wm.save_as_mainfile(filepath=str(output_dir / "model.blend"), compress=True)
    write_report(
        output_dir,
        source_path,
        args.tier,
        source_bounds,
        source_triangles,
        base,
        blades,
    )
    print(f"Split saw-blade tier {args.tier}: Base + {len(blades)} blade rotor(s)")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as error:
        print(f"saw-blade splitter error: {error}", file=sys.stderr)
        raise
