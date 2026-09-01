#!/usr/bin/env python3
"""Replace broken extracted saw rotors with clean symmetric Blender geometry.

The Meshy source only modeled surfaces that were visible around the housings.
Once those rotors were separated and animated, hidden spindle gaps and orphaned
teeth became visible.  This repair keeps the accepted textured base, removes
rotor fragments from the narrow axle band, and rebuilds each affected rotor as
one complete low-poly object.
"""

from __future__ import annotations

import argparse
import json
import math
import sys
from dataclasses import dataclass
from pathlib import Path

import bmesh
import bpy
from mathutils import Vector


@dataclass(frozen=True)
class Rotor:
    center: tuple[float, float, float]
    radius: float
    half_thickness: float


@dataclass(frozen=True)
class RepairSpec:
    rotors: tuple[Rotor, ...]
    tooth_counts: tuple[int, ...]
    disc_color: tuple[float, float, float, float]
    tooth_color: tuple[float, float, float, float]
    accent_color: tuple[float, float, float, float]
    hub_color: tuple[float, float, float, float]
    accent_ring: bool


SPECS: dict[int, RepairSpec] = {
    1: RepairSpec(
        rotors=(Rotor((0.030, 0.000, 0.055), 0.415, 0.073),),
        tooth_counts=(16,),
        disc_color=(0.34, 0.105, 0.035, 1.0),
        tooth_color=(0.50, 0.18, 0.055, 1.0),
        accent_color=(0.20, 0.055, 0.020, 1.0),
        hub_color=(0.035, 0.042, 0.050, 1.0),
        accent_ring=False,
    ),
    3: RepairSpec(
        rotors=(
            Rotor((-0.550, -0.110, 0.000), 0.315, 0.065),
            Rotor((0.000, -0.110, 0.025), 0.370, 0.065),
            Rotor((0.550, -0.110, 0.000), 0.315, 0.065),
        ),
        tooth_counts=(14, 16, 14),
        disc_color=(0.020, 0.024, 0.030, 1.0),
        tooth_color=(0.035, 0.043, 0.052, 1.0),
        accent_color=(0.80, 0.245, 0.020, 1.0),
        hub_color=(0.095, 0.055, 0.025, 1.0),
        accent_ring=True,
    ),
}


def parse_args() -> argparse.Namespace:
    argv = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--tier", type=int, choices=sorted(SPECS), required=True)
    parser.add_argument("--input", required=True)
    parser.add_argument("--output-dir", required=True)
    return parser.parse_args(argv)


def material(name: str, color: tuple[float, float, float, float], metallic: float, roughness: float) -> bpy.types.Material:
    result = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    result.diffuse_color = color
    result.use_nodes = True
    principled = result.node_tree.nodes.get("Principled BSDF")
    principled.inputs["Base Color"].default_value = color
    principled.inputs["Metallic"].default_value = metallic
    principled.inputs["Roughness"].default_value = roughness
    return result


class MeshBuilder:
    def __init__(self) -> None:
        self.vertices: list[tuple[float, float, float]] = []
        self.faces: list[tuple[int, ...]] = []
        self.materials: list[int] = []

    def add_prism_ring(self, inner: float, outer: float, depth: float, segments: int, material_index: int) -> None:
        start = len(self.vertices)
        half = depth / 2
        for y in (-half, half):
            for radius in (inner, outer):
                for index in range(segments):
                    angle = math.tau * index / segments
                    self.vertices.append((radius * math.cos(angle), y, radius * math.sin(angle)))

        def vertex(side: int, radius_index: int, index: int) -> int:
            return start + side * segments * 2 + radius_index * segments + index % segments

        for index in range(segments):
            nxt = index + 1
            # Front and rear annulus faces.
            self.faces.append((vertex(0, 0, index), vertex(0, 1, index), vertex(0, 1, nxt), vertex(0, 0, nxt)))
            self.materials.append(material_index)
            self.faces.append((vertex(1, 0, nxt), vertex(1, 1, nxt), vertex(1, 1, index), vertex(1, 0, index)))
            self.materials.append(material_index)
            # Inner and outer walls.
            self.faces.append((vertex(0, 0, nxt), vertex(1, 0, nxt), vertex(1, 0, index), vertex(0, 0, index)))
            self.materials.append(material_index)
            self.faces.append((vertex(0, 1, index), vertex(1, 1, index), vertex(1, 1, nxt), vertex(0, 1, nxt)))
            self.materials.append(material_index)

    def add_cylinder(self, radius: float, depth: float, segments: int, material_index: int) -> None:
        self.add_prism_ring(0.0, radius, depth, segments, material_index)

    def add_teeth(self, root_radius: float, outer_radius: float, depth: float, count: int, material_index: int) -> None:
        half = depth / 2
        step = math.tau / count
        for index in range(count):
            center = index * step
            root_half = step * 0.34
            tip_half = step * 0.19
            points = (
                (root_radius * math.cos(center - root_half), root_radius * math.sin(center - root_half)),
                (outer_radius * math.cos(center - tip_half), outer_radius * math.sin(center - tip_half)),
                (outer_radius * math.cos(center + tip_half), outer_radius * math.sin(center + tip_half)),
                (root_radius * math.cos(center + root_half), root_radius * math.sin(center + root_half)),
            )
            start = len(self.vertices)
            for y in (-half, half):
                self.vertices.extend((x, y, z) for x, z in points)
            self.faces.extend(
                (
                    (start, start + 1, start + 2, start + 3),
                    (start + 7, start + 6, start + 5, start + 4),
                    (start, start + 4, start + 5, start + 1),
                    (start + 1, start + 5, start + 6, start + 2),
                    (start + 2, start + 6, start + 7, start + 3),
                    (start + 3, start + 7, start + 4, start),
                )
            )
            self.materials.extend((material_index,) * 6)


def remove_old_rotor_fragments(base: bpy.types.Object, spec: RepairSpec) -> int:
    mesh = bmesh.new()
    mesh.from_mesh(base.data)
    doomed = []
    for face in mesh.faces:
        center = face.calc_center_median()
        for rotor in spec.rotors:
            delta = center - Vector(rotor.center)
            radial = math.hypot(delta.x, delta.z)
            rotor_band = abs(delta.y) <= rotor.half_thickness * 1.35 and radial <= rotor.radius * 1.16
            # Tier 1's old front spindle cap sat outside the narrow blade band
            # and became visibly off-center once the complete hub rotated.
            tier_one_spindle = (
                len(spec.rotors) == 1
                and radial <= rotor.radius * 0.34
                and abs(delta.y) <= 0.26
            )
            if rotor_band or tier_one_spindle:
                doomed.append(face)
                break
    if doomed:
        bmesh.ops.delete(mesh, geom=doomed, context="FACES")
        loose = [vertex for vertex in mesh.verts if not vertex.link_faces]
        if loose:
            bmesh.ops.delete(mesh, geom=loose, context="VERTS")
    mesh.to_mesh(base.data)
    mesh.free()
    base.data.update()
    return len(doomed)


def build_rotor(tier: int, rotor_index: int, rotor: Rotor, tooth_count: int, materials: list[bpy.types.Material]) -> bpy.types.Object:
    builder = MeshBuilder()
    radius = rotor.radius
    disc_depth = rotor.half_thickness * 1.42
    builder.add_cylinder(radius * 0.79, disc_depth, 32, 0)
    builder.add_teeth(radius * 0.75, radius, disc_depth * 0.96, tooth_count, 1)
    if SPECS[tier].accent_ring:
        builder.add_prism_ring(radius * 0.57, radius * 0.72, disc_depth * 1.12, 28, 2)
    else:
        builder.add_prism_ring(radius * 0.62, radius * 0.76, disc_depth * 1.08, 24, 2)
    # Symmetric hub, collar, and axle cover all formerly hidden spindle faces.
    builder.add_cylinder(radius * 0.235, disc_depth * 1.65, 20, 3)
    builder.add_cylinder(radius * 0.145, disc_depth * 2.15, 16, 2)
    builder.add_cylinder(radius * 0.080, max(disc_depth * 3.10, 0.245), 14, 3)

    mesh = bpy.data.meshes.new(f"Blade{rotor_index:02d}RepairedMesh")
    mesh.from_pydata(builder.vertices, [], builder.faces)
    mesh.update(calc_edges=True)
    for item in materials:
        mesh.materials.append(item)
    for polygon, material_index in zip(mesh.polygons, builder.materials, strict=True):
        polygon.material_index = material_index
        polygon.use_smooth = False
    uv_layer = mesh.uv_layers.new(name="PaletteUV")
    palette_uvs = (
        (0.25, 0.75),
        (0.75, 0.75),
        (0.25, 0.25),
        (0.75, 0.25),
    )
    for polygon in mesh.polygons:
        uv = palette_uvs[polygon.material_index]
        for loop_index in polygon.loop_indices:
            uv_layer.data[loop_index].uv = uv

    result = bpy.data.objects.new(f"Blade{rotor_index:02d}", mesh)
    bpy.context.collection.objects.link(result)
    result.location = rotor.center
    result["SawBladePart"] = "Blade"
    result["RotationAxis"] = "Y"
    result["RobloxRotationAxis"] = "Z"
    result["RotorIndex"] = rotor_index
    result["AxleCenter"] = list(rotor.center)
    return result


def write_palette_texture(output: Path, colors: tuple[tuple[float, float, float, float], ...]) -> None:
    width = height = 256
    pixels: list[float] = []
    # UV origin is bottom-left: hub/accent occupy the lower half.
    for y in range(height):
        for x in range(width):
            if y >= height // 2:
                color = colors[0] if x < width // 2 else colors[1]
            else:
                color = colors[2] if x < width // 2 else colors[3]
            pixels.extend(color)
    image = bpy.data.images.new(output.stem, width=width, height=height, alpha=True)
    image.pixels.foreach_set(pixels)
    image.filepath_raw = str(output)
    image.file_format = "PNG"
    image.save()


def object_bounds(objects: list[bpy.types.Object]) -> tuple[Vector, Vector]:
    low = Vector((math.inf, math.inf, math.inf))
    high = Vector((-math.inf, -math.inf, -math.inf))
    for obj in objects:
        for corner in obj.bound_box:
            point = obj.matrix_world @ Vector(corner)
            for axis in range(3):
                low[axis] = min(low[axis], point[axis])
                high[axis] = max(high[axis], point[axis])
    return low, high


def setup_render(objects: list[bpy.types.Object], output: Path) -> None:
    for obj in list(bpy.context.scene.objects):
        if obj.type in {"CAMERA", "LIGHT"}:
            bpy.data.objects.remove(obj, do_unlink=True)
    low, high = object_bounds(objects)
    center = (low + high) / 2
    span = high - low
    bpy.ops.object.camera_add()
    camera = bpy.context.active_object
    camera.data.type = "ORTHO"
    camera.data.ortho_scale = max(span.x / (16 / 9), span.z) * 1.55
    camera.location = center + Vector((span.x * 0.75, -max(span.x, 1.0) * 1.75, span.z * 1.05))
    camera.rotation_euler = (center - camera.location).to_track_quat("-Z", "Y").to_euler()
    bpy.context.scene.camera = camera
    for name, offset, energy, size in (
        ("Key", (-1.2, -2.0, 2.2), 85, 2.0),
        ("Fill", (1.8, -0.8, 1.0), 32, 2.5),
        ("Rim", (0.0, 2.0, 1.7), 55, 1.5),
    ):
        bpy.ops.object.light_add(type="AREA", location=center + Vector(offset))
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


def export_assets(output_dir: Path, root: bpy.types.Object, parts: list[bpy.types.Object]) -> None:
    bpy.ops.object.select_all(action="DESELECT")
    root.select_set(True)
    for part in parts:
        part.select_set(True)
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


def triangle_count(obj: bpy.types.Object) -> int:
    obj.data.calc_loop_triangles()
    return len(obj.data.loop_triangles)


def main() -> int:
    args = parse_args()
    source = Path(args.input).expanduser().resolve()
    output_dir = Path(args.output_dir).expanduser().resolve()
    output_dir.mkdir(parents=True, exist_ok=True)
    bpy.ops.wm.open_mainfile(filepath=str(source))

    spec = SPECS[args.tier]
    base = bpy.data.objects.get("Base")
    root = bpy.data.objects.get(f"SawBladeTier{args.tier}")
    if base is None or root is None:
        raise RuntimeError("Expected Base and tier root objects in source blend")

    removed_faces = remove_old_rotor_fragments(base, spec)
    for obj in list(bpy.data.objects):
        if obj.type == "MESH" and obj.name.startswith("Blade"):
            bpy.data.objects.remove(obj, do_unlink=True)

    materials = [
        material(f"Tier{args.tier}Disc", spec.disc_color, 0.55, 0.40),
        material(f"Tier{args.tier}Teeth", spec.tooth_color, 0.68, 0.32),
        material(f"Tier{args.tier}Accent", spec.accent_color, 0.62, 0.34),
        material(f"Tier{args.tier}Hub", spec.hub_color, 0.78, 0.28),
    ]
    blades = [
        build_rotor(args.tier, index, rotor, spec.tooth_counts[index - 1], materials)
        for index, rotor in enumerate(spec.rotors, start=1)
    ]
    for blade in blades:
        blade.parent = root
    root["SawBladeRigVersion"] = 2
    root["BladeCount"] = len(blades)
    root["RepairMethod"] = "SymmetricProceduralRotor"

    write_palette_texture(
        output_dir / f"tier{args.tier}_blade_palette.png",
        (spec.disc_color, spec.tooth_color, spec.accent_color, spec.hub_color),
    )

    setup_render([base, *blades], output_dir / "preview.png")
    bpy.ops.render.render(write_still=True)
    export_assets(output_dir, root, [base, *blades])
    bpy.ops.file.pack_all()
    bpy.ops.wm.save_as_mainfile(filepath=str(output_dir / "model.blend"), compress=True)

    report = {
        "schema_version": 1,
        "tier": args.tier,
        "source": str(source),
        "repair_method": "symmetric_procedural_rotor",
        "removed_base_faces": removed_faces,
        "roblox_rotation_axis": "Z",
        "parts": [
            {"name": part.name, "triangles": triangle_count(part)}
            for part in (base, *blades)
        ],
    }
    (output_dir / "report.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(f"Repaired tier {args.tier}: removed {removed_faces} orphan faces; rebuilt {len(blades)} rotor(s)")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as error:
        print(f"saw-blade rotor repair error: {error}", file=sys.stderr)
        raise
