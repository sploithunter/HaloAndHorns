"""Rebuild the Ember Citadel concept as a clean, Roblox-ready gothic tower.

The supplied Meshy GLB is preserved in a hidden reference collection inside the
.blend, but is not exported. Its topology is intentionally not reused: the source
contains hundreds of disconnected shells and open/non-manifold edges. The rebuilt
asset uses closed primitive-derived forms, a small material set, generated PBR-ish
textures, and a six-MeshPart consolidated GLB export.

Headless usage:

  blender --background --factory-startup --python build_ember_citadel.py -- \
    --input /path/to/Meshy_AI_Ember_Citadel_texture.glb \
    --output-dir assets/exports/props/ember_citadel \
    --middle-extension 4
"""

from __future__ import annotations

import argparse
import json
import math
import random
import sys
from pathlib import Path

import bpy
from mathutils import Vector


def parse_args() -> argparse.Namespace:
    argv = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", required=True)
    parser.add_argument("--output-dir", required=True)
    parser.add_argument("--texture-size", type=int, default=512)
    parser.add_argument("--preview-size", type=int, default=1024)
    parser.add_argument(
        "--middle-extension",
        type=float,
        default=0.0,
        help="Additional studs inserted through the central shaft/banner section.",
    )
    return parser.parse_args(argv)


def clear_scene() -> None:
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for collection in list(bpy.data.collections):
        if collection.name != "Collection":
            bpy.data.collections.remove(collection)


def collection(name: str) -> bpy.types.Collection:
    found = bpy.data.collections.get(name)
    if found:
        return found
    found = bpy.data.collections.new(name)
    bpy.context.scene.collection.children.link(found)
    return found


def move_to_collection(obj: bpy.types.Object, target: bpy.types.Collection) -> None:
    for owner in list(obj.users_collection):
        owner.objects.unlink(obj)
    target.objects.link(obj)


def import_reference(path: Path) -> bpy.types.Collection:
    target = collection("SOURCE_Meshy_Reference")
    before = set(bpy.context.scene.objects)
    bpy.ops.import_scene.gltf(filepath=str(path))
    imported = [obj for obj in bpy.context.scene.objects if obj not in before]
    for obj in imported:
        move_to_collection(obj, target)
    target.hide_render = True
    target.hide_viewport = True
    return target


def generated_image(
    name: str,
    path: Path,
    size: int,
    pixel_fn,
) -> bpy.types.Image:
    image = bpy.data.images.new(name=name, width=size, height=size, alpha=True)
    pixels: list[float] = []
    for y in range(size):
        for x in range(size):
            r, g, b, a = pixel_fn(x, y, size)
            pixels.extend((r, g, b, a))
    image.pixels.foreach_set(pixels)
    image.filepath_raw = str(path)
    image.file_format = "PNG"
    image.save()
    image.pack()
    return image


def build_textures(out_dir: Path, size: int) -> dict[str, bpy.types.Image]:
    rng = random.Random(813)
    noise = [rng.uniform(-1.0, 1.0) for _ in range(size * size)]

    def stone(x: int, y: int, n: int):
        row_h = max(12, n // 10)
        brick_w = max(20, n // 5)
        row = y // row_h
        shifted_x = x + (brick_w // 2 if row % 2 else 0)
        mortar = min(y % row_h, row_h - 1 - (y % row_h), shifted_x % brick_w, brick_w - 1 - (shifted_x % brick_w))
        grain = noise[y * n + x] * 0.035
        broad = 0.018 * math.sin(x * 0.11) * math.cos(y * 0.07)
        if mortar < max(1, n // 180):
            base = 0.035 + grain * 0.2
        else:
            base = 0.145 + grain + broad
        return (base * 0.88, base * 0.92, base, 1.0)

    def crimson(x: int, y: int, n: int):
        grain = noise[y * n + x] * 0.025
        weave = 0.015 * math.sin(x * 0.55) + 0.01 * math.sin(y * 0.31)
        edge = min(x, n - 1 - x) / max(1, n * 0.18)
        shade = 0.78 + 0.22 * min(1.0, edge)
        return ((0.38 + grain + weave) * shade, 0.014, 0.021, 1.0)

    def ember(x: int, y: int, n: int):
        value = 0.5 + 0.5 * math.sin(x * 0.13 + math.sin(y * 0.08) * 4.0)
        value *= 0.65 + 0.35 * math.sin(y * 0.045) ** 2
        hot = value > 0.52
        return (
            1.0 if hot else 0.52,
            0.10 + 0.58 * max(0.0, value - 0.30),
            0.005,
            1.0,
        )

    return {
        "stone": generated_image("EmberCitadel_Stone", out_dir / "ember_citadel_stone.png", size, stone),
        "crimson": generated_image(
            "EmberCitadel_Crimson", out_dir / "ember_citadel_crimson.png", size, crimson
        ),
        "ember": generated_image("EmberCitadel_Ember", out_dir / "ember_citadel_ember.png", size, ember),
    }


def material(
    name: str,
    color: tuple[float, float, float, float],
    *,
    metallic: float = 0.0,
    roughness: float = 0.6,
    image: bpy.types.Image | None = None,
    emission: tuple[float, float, float, float] | None = None,
    emission_strength: float = 0.0,
) -> bpy.types.Material:
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    mat.diffuse_color = color
    nodes = mat.node_tree.nodes
    links = mat.node_tree.links
    bsdf = next(node for node in nodes if node.type == "BSDF_PRINCIPLED")
    bsdf.inputs["Base Color"].default_value = color
    bsdf.inputs["Metallic"].default_value = metallic
    bsdf.inputs["Roughness"].default_value = roughness
    if image:
        tex = nodes.new("ShaderNodeTexImage")
        tex.image = image
        tex.interpolation = "Linear"
        tex.extension = "REPEAT"
        links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    if emission:
        bsdf.inputs["Emission Color"].default_value = emission
        bsdf.inputs["Emission Strength"].default_value = emission_strength
        if image:
            links.new(tex.outputs["Color"], bsdf.inputs["Emission Color"])
    return mat


def set_material(obj: bpy.types.Object, mat: bpy.types.Material) -> None:
    obj.data.materials.clear()
    obj.data.materials.append(mat)


def bevel(obj: bpy.types.Object, width: float, segments: int = 2) -> None:
    if width <= 0:
        return
    modifier = obj.modifiers.new(name="EdgeSoftening", type="BEVEL")
    modifier.width = width
    modifier.segments = segments
    modifier.limit_method = "ANGLE"
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.modifier_apply(modifier=modifier.name)


def add_box(
    target: bpy.types.Collection,
    name: str,
    location: tuple[float, float, float],
    dimensions: tuple[float, float, float],
    mat: bpy.types.Material,
    *,
    yaw: float = 0.0,
    bevel_width: float = 0.04,
) -> bpy.types.Object:
    bpy.ops.mesh.primitive_cube_add(location=location, rotation=(0.0, 0.0, yaw))
    obj = bpy.context.active_object
    obj.name = name
    obj.dimensions = dimensions
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    set_material(obj, mat)
    bevel(obj, bevel_width)
    move_to_collection(obj, target)
    return obj


def add_octagon(
    target: bpy.types.Collection,
    name: str,
    z: float,
    depth: float,
    radius_bottom: float,
    radius_top: float,
    mat: bpy.types.Material,
    *,
    bevel_width: float = 0.04,
) -> bpy.types.Object:
    bpy.ops.mesh.primitive_cone_add(
        vertices=8,
        radius1=radius_bottom,
        radius2=radius_top,
        depth=depth,
        end_fill_type="NGON",
        location=(0.0, 0.0, z),
        rotation=(0.0, 0.0, math.radians(22.5)),
    )
    obj = bpy.context.active_object
    obj.name = name
    set_material(obj, mat)
    bevel(obj, bevel_width)
    move_to_collection(obj, target)
    return obj


def add_spire(
    target: bpy.types.Collection,
    name: str,
    x: float,
    y: float,
    base_z: float,
    shaft_height: float,
    radius: float,
    mat: bpy.types.Material,
) -> None:
    bpy.ops.mesh.primitive_cylinder_add(
        vertices=8,
        radius=radius,
        depth=shaft_height,
        location=(x, y, base_z + shaft_height * 0.5),
    )
    shaft = bpy.context.active_object
    shaft.name = name + "_Shaft"
    set_material(shaft, mat)
    move_to_collection(shaft, target)
    bpy.ops.mesh.primitive_cone_add(
        vertices=8,
        radius1=radius * 1.45,
        radius2=0.0,
        depth=shaft_height * 1.3,
        location=(x, y, base_z + shaft_height * 1.65),
    )
    tip = bpy.context.active_object
    tip.name = name + "_Tip"
    set_material(tip, mat)
    move_to_collection(tip, target)


def add_pointed_panel(
    target: bpy.types.Collection,
    name: str,
    radius: float,
    yaw: float,
    base_z: float,
    width: float,
    height: float,
    thickness: float,
    mat: bpy.types.Material,
    *,
    bevel_width: float = 0.025,
) -> bpy.types.Object:
    shoulder = height * 0.72
    front = -thickness * 0.5
    back = thickness * 0.5
    profile = [
        (-width * 0.5, 0.0),
        (width * 0.5, 0.0),
        (width * 0.5, shoulder),
        (0.0, height),
        (-width * 0.5, shoulder),
    ]
    verts = [(x, front, z) for x, z in profile] + [(x, back, z) for x, z in profile]
    faces = [(0, 1, 2, 3, 4), (9, 8, 7, 6, 5)]
    for i in range(5):
        j = (i + 1) % 5
        faces.append((i, 5 + i, 5 + j, j))
    mesh = bpy.data.meshes.new(name + "_Mesh")
    mesh.from_pydata(verts, [], faces)
    mesh.validate()
    obj = bpy.data.objects.new(name, mesh)
    target.objects.link(obj)
    obj.rotation_euler.z = yaw
    obj.location = (math.sin(yaw) * radius, -math.cos(yaw) * radius, base_z)
    set_material(obj, mat)
    bevel(obj, bevel_width)
    return obj


def add_beam(
    target: bpy.types.Collection,
    name: str,
    start: Vector,
    end: Vector,
    radius: float,
    mat: bpy.types.Material,
) -> bpy.types.Object:
    midpoint = (start + end) * 0.5
    direction = end - start
    bpy.ops.mesh.primitive_cylinder_add(vertices=6, radius=radius, depth=direction.length, location=midpoint)
    obj = bpy.context.active_object
    obj.name = name
    obj.rotation_euler = direction.to_track_quat("Z", "Y").to_euler()
    set_material(obj, mat)
    move_to_collection(obj, target)
    return obj


def add_flame_tongue(
    target: bpy.types.Collection,
    name: str,
    base_z: float,
    height: float,
    radius: float,
    sway: tuple[float, float],
    mat: bpy.types.Material,
) -> bpy.types.Object:
    sides = 7
    levels = 6
    verts: list[tuple[float, float, float]] = []
    for level in range(levels):
        t = level / (levels - 1)
        ring_radius = radius * (1.0 - t) ** 0.72 + 0.035
        center_x = sway[0] * math.sin(t * math.pi * 0.9) * t
        center_y = sway[1] * math.sin(t * math.pi * 0.9) * t
        for side in range(sides):
            angle = math.tau * side / sides + t * 1.1
            verts.append(
                (
                    center_x + math.cos(angle) * ring_radius,
                    center_y + math.sin(angle) * ring_radius,
                    base_z + height * t,
                )
            )
    faces: list[tuple[int, ...]] = [tuple(reversed(range(sides)))]
    for level in range(levels - 1):
        for side in range(sides):
            nxt = (side + 1) % sides
            a = level * sides + side
            b = level * sides + nxt
            c = (level + 1) * sides + nxt
            d = (level + 1) * sides + side
            faces.append((a, b, c, d))
    faces.append(tuple(range((levels - 1) * sides, levels * sides)))
    mesh = bpy.data.meshes.new(name + "_Mesh")
    mesh.from_pydata(verts, [], faces)
    mesh.validate()
    obj = bpy.data.objects.new(name, mesh)
    target.objects.link(obj)
    set_material(obj, mat)
    return obj


def radial_point(radius: float, yaw: float, z: float) -> Vector:
    return Vector((math.sin(yaw) * radius, -math.cos(yaw) * radius, z))


def build_tower(
    target: bpy.types.Collection,
    mats: dict[str, bpy.types.Material],
    middle_extension: float = 0.0,
) -> None:
    extension = max(0.0, float(middle_extension))
    upper_shift = extension
    middle_center_shift = extension * 0.5
    stone = mats["stone"]
    iron = mats["iron"]
    bronze = mats["bronze"]
    crimson = mats["crimson"]
    ember = mats["ember"]
    flame = mats["flame"]

    # Broad, readable octagonal foundation and front stair.
    add_octagon(target, "Foundation_01", 0.30, 0.60, 4.90, 4.90, stone, bevel_width=0.08)
    add_octagon(target, "Foundation_02", 0.82, 0.46, 4.55, 4.42, iron, bevel_width=0.06)
    add_octagon(target, "Foundation_03", 1.22, 0.38, 4.15, 4.05, stone, bevel_width=0.055)
    for i in range(4):
        add_box(
            target,
            f"FrontStep_{i + 1:02d}",
            (0.0, -4.56 + i * 0.34, 0.14 + i * 0.12),
            (4.0 - i * 0.32, 0.78, 0.28 + i * 0.03),
            stone,
            bevel_width=0.035,
        )

    # Lower keep and its eight corner buttresses.
    add_octagon(target, "LowerKeep", 3.05, 3.35, 3.82, 3.55, stone, bevel_width=0.075)
    add_octagon(target, "LowerKeep_Belt", 4.73, 0.42, 4.08, 4.08, iron, bevel_width=0.05)
    for index in range(8):
        yaw = math.tau * index / 8
        point = radial_point(3.65, yaw, 2.9)
        add_box(
            target,
            f"LowerButtress_{index + 1:02d}",
            tuple(point),
            (0.66, 0.84, 3.65),
            stone,
            yaw=yaw,
            bevel_width=0.045,
        )
        add_spire(
            target,
            f"LowerSpire_{index + 1:02d}",
            point.x,
            point.y,
            4.72,
            0.82,
            0.28,
            iron,
        )

    # Glowing lower lancets framed in bronze.
    for index in range(4):
        yaw = math.tau * index / 4
        add_pointed_panel(target, f"LowerWindowOuter_{index + 1:02d}", 3.55, yaw, 1.92, 1.42, 1.95, 0.20, iron)
        add_pointed_panel(target, f"LowerWindowFrame_{index + 1:02d}", 3.64, yaw, 2.02, 1.12, 1.68, 0.15, bronze)
        add_pointed_panel(target, f"LowerWindowGlow_{index + 1:02d}", 3.73, yaw, 2.16, 0.70, 1.26, 0.08, ember)

    # Tall central shaft with readable vertical ribs and banners.
    add_octagon(
        target,
        "CentralShaft",
        8.85 + middle_center_shift,
        7.75 + extension,
        2.92,
        2.68,
        stone,
        bevel_width=0.07,
    )
    add_octagon(target, "ShaftLowerBelt", 5.15, 0.38, 3.28, 3.28, iron, bevel_width=0.045)
    add_octagon(target, "ShaftUpperBelt", 12.55 + upper_shift, 0.48, 3.32, 3.32, iron, bevel_width=0.05)
    for index in range(8):
        yaw = math.tau * index / 8
        point = radial_point(2.78, yaw, 8.88 + middle_center_shift)
        add_box(
            target,
            f"ShaftRib_{index + 1:02d}",
            tuple(point),
            (0.32, 0.42, 7.25 + extension),
            iron,
            yaw=yaw,
            bevel_width=0.025,
        )

    for index in range(4):
        yaw = math.tau * index / 4
        add_pointed_panel(target, f"BannerOuterArch_{index + 1:02d}", 2.76, yaw, 5.86, 2.58, 6.02 + extension, 0.22, iron, bevel_width=0.045)
        add_pointed_panel(target, f"BannerFrame_{index + 1:02d}", 2.87, yaw, 6.02, 2.20, 5.66 + extension, 0.14, bronze, bevel_width=0.035)
        add_pointed_panel(target, f"CrimsonBanner_{index + 1:02d}", 2.98, yaw, 6.20, 1.76, 5.20 + extension, 0.08, crimson, bevel_width=0.02)
        # Simple gold rune: a vertical spine and three diamonds.
        normal = radial_point(1.0, yaw, 0.0)
        center = radial_point(3.01, yaw, 8.72 + middle_center_shift)
        add_box(
            target,
            f"BannerRuneSpine_{index + 1:02d}",
            tuple(center),
            (0.09, 0.08, 2.42),
            bronze,
            yaw=yaw,
            bevel_width=0.015,
        )
        for rune_index, z in enumerate((7.80 + middle_center_shift, 8.72 + middle_center_shift, 9.64 + middle_center_shift), start=1):
            rune_center = radial_point(3.075, yaw, z)
            rune = add_box(
                target,
                f"BannerRune_{index + 1:02d}_{rune_index:02d}",
                tuple(rune_center),
                (0.34, 0.07, 0.34),
                bronze,
                yaw=yaw + math.radians(45),
                bevel_width=0.018,
            )
            rune.scale.x = 0.72

    for index in range(8):
        yaw = math.tau * index / 8
        point = radial_point(3.08, yaw, 12.72 + upper_shift)
        add_spire(
            target,
            f"ShaftParapetSpire_{index + 1:02d}",
            point.x,
            point.y,
            12.64 + upper_shift,
            0.58,
            0.17,
            iron,
        )

    # Shoulder, flared brazier balcony, and the cage around the flame.
    add_octagon(target, "CrownShoulder", 13.05 + upper_shift, 0.70, 3.16, 2.64, stone, bevel_width=0.06)
    add_octagon(target, "BrazierBowl", 13.92 + upper_shift, 1.10, 2.35, 3.58, iron, bevel_width=0.065)
    add_octagon(target, "BrazierRim", 14.56 + upper_shift, 0.32, 3.78, 3.78, bronze, bevel_width=0.045)
    add_octagon(target, "BrazierCoal", 14.73 + upper_shift, 0.16, 2.62, 2.62, ember, bevel_width=0.02)

    apex = Vector((0.0, 0.0, 19.25 + upper_shift))
    for index in range(8):
        yaw = math.tau * index / 8
        base = radial_point(2.72, yaw, 14.70 + upper_shift)
        add_spire(target, f"CrownSpire_{index + 1:02d}", base.x, base.y, 14.66 + upper_shift, 1.02, 0.17, iron)
        beam_start = radial_point(2.20, yaw, 16.30 + upper_shift)
        add_beam(target, f"CrownArch_{index + 1:02d}", beam_start, apex, 0.105, iron)
        add_box(
            target,
            f"CrownPillar_{index + 1:02d}",
            tuple(radial_point(2.20, yaw, 15.52 + upper_shift)),
            (0.22, 0.26, 1.70),
            iron,
            yaw=yaw,
            bevel_width=0.018,
        )

        inner = radial_point(1.58, yaw + math.radians(22.5), 14.72 + upper_shift)
        add_spire(
            target,
            f"InnerCrownSpire_{index + 1:02d}",
            inner.x,
            inner.y,
            14.70 + upper_shift,
            1.32,
            0.13,
            iron,
        )

    add_spire(target, "CrownApex", 0.0, 0.0, 18.92 + upper_shift, 0.74, 0.23, iron)
    add_flame_tongue(target, "FlameCore", 14.76 + upper_shift, 3.65, 0.92, (0.32, 0.10), flame)
    add_flame_tongue(target, "FlameLeft", 14.76 + upper_shift, 2.78, 0.68, (-0.68, 0.20), ember)
    add_flame_tongue(target, "FlameRight", 14.76 + upper_shift, 2.48, 0.58, (0.70, -0.24), flame)
    hot = add_flame_tongue(target, "FlameHotCore", 14.76 + upper_shift, 2.38, 0.46, (-0.12, -0.06), mats["flame_hot"])
    hot.location.y = -0.12

    # Restrained lava seams give the dark mass readable contrast at game distance.
    for index in range(8):
        yaw = math.tau * index / 8
        for z in (1.55, 4.92, 12.82 + upper_shift, 14.52 + upper_shift):
            point = radial_point(3.98 if z < 5.0 else 3.16, yaw, z)
            add_box(
                target,
                f"EmberSeam_{index + 1:02d}_{int(z * 10):03d}",
                tuple(point),
                (0.16, 0.09, 0.34),
                ember,
                yaw=yaw,
                bevel_width=0.012,
            )


def duplicate_for_export(
    source: bpy.types.Collection,
    target: bpy.types.Collection,
) -> list[bpy.types.Object]:
    copies: list[bpy.types.Object] = []
    for obj in source.objects:
        if obj.type != "MESH":
            continue
        copy = obj.copy()
        copy.data = obj.data.copy()
        copy.animation_data_clear()
        target.objects.link(copy)
        copies.append(copy)

    grouped: dict[str, list[bpy.types.Object]] = {}
    for obj in copies:
        mat = obj.data.materials[0] if obj.data.materials else None
        key = mat.name if mat else "Unassigned"
        grouped.setdefault(key, []).append(obj)

    consolidated: list[bpy.types.Object] = []
    for mat_name, objects in grouped.items():
        bpy.ops.object.select_all(action="DESELECT")
        for obj in objects:
            obj.hide_set(False)
            obj.select_set(True)
        bpy.context.view_layer.objects.active = objects[0]
        bpy.ops.object.join()
        joined = bpy.context.active_object
        joined.name = "EmberCitadel_" + mat_name.replace("EmberCitadel_", "")
        joined.data.name = joined.name + "_Mesh"
        joined.data.validate()
        consolidated.append(joined)
    return consolidated


def add_preview_scene(editable: bpy.types.Collection, mats: dict[str, bpy.types.Material]) -> bpy.types.Collection:
    target = collection("PREVIEW_ONLY")
    floor = add_octagon(target, "PreviewPlinth", -0.16, 0.24, 7.2, 7.2, mats["preview"], bevel_width=0.08)
    floor.scale.z = 1.0
    return target


def point_camera(camera: bpy.types.Object, target: Vector) -> None:
    camera.rotation_euler = (target - camera.location).to_track_quat("-Z", "Y").to_euler()


def setup_render(size: int, mats: dict[str, bpy.types.Material], height: float) -> bpy.types.Object:
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x = size
    scene.render.resolution_y = size
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"
    scene.render.film_transparent = False
    scene.world.color = (0.018, 0.022, 0.032)
    world = scene.world
    world.use_nodes = True
    background = world.node_tree.nodes.get("Background")
    background.inputs["Color"].default_value = (0.018, 0.022, 0.032, 1.0)
    background.inputs["Strength"].default_value = 0.28

    bpy.ops.object.camera_add(location=(13.5, -22.0, 11.0))
    camera = bpy.context.active_object
    camera.name = "PreviewCamera"
    camera.data.type = "ORTHO"
    camera.data.ortho_scale = max(22.0, height * 1.07)
    point_camera(camera, Vector((0.0, 0.0, height * 0.47)))
    scene.camera = camera

    def area(name: str, location: tuple[float, float, float], energy: float, color, size_value: float):
        bpy.ops.object.light_add(type="AREA", location=location)
        light = bpy.context.active_object
        light.name = name
        light.data.energy = energy
        light.data.color = color
        light.data.shape = "DISK"
        light.data.size = size_value
        point_camera(light, Vector((0.0, 0.0, 8.0)))

    area("Key", (9.0, -12.0, 16.0), 2500.0, (0.72, 0.82, 1.0), 7.0)
    area("Fill", (-10.0, -7.0, 9.0), 1550.0, (0.45, 0.55, 0.80), 8.0)
    area("Rim", (3.0, 9.0, 15.0), 2200.0, (1.0, 0.20, 0.035), 6.0)
    bpy.ops.object.light_add(type="POINT", location=(0.0, 0.0, 16.0))
    fire_light = bpy.context.active_object
    fire_light.name = "FlameLight"
    fire_light.data.energy = 800.0
    fire_light.data.color = (1.0, 0.12, 0.01)
    fire_light.data.shadow_soft_size = 3.0
    return camera


def render_angles(camera: bpy.types.Object, out_dir: Path, height: float, extension: float) -> list[Path]:
    scene = bpy.context.scene
    target = Vector((0.0, 0.0, height * 0.47))
    shots = {
        "front": Vector((0.0, -25.0, 10.4 + extension * 0.45)),
        "three_quarter": Vector((14.5, -22.0, 11.2 + extension * 0.45)),
        "back_three_quarter": Vector((-15.0, 21.0, 12.0 + extension * 0.45)),
    }
    paths: list[Path] = []
    for label, position in shots.items():
        camera.location = position
        point_camera(camera, target)
        path = out_dir / f"ember_citadel_{label}.png"
        scene.render.filepath = str(path)
        bpy.ops.render.render(write_still=True)
        paths.append(path)
    return paths


def mesh_stats(objects: list[bpy.types.Object]) -> dict[str, int]:
    vertices = 0
    polygons = 0
    triangles = 0
    for obj in objects:
        vertices += len(obj.data.vertices)
        polygons += len(obj.data.polygons)
        obj.data.calc_loop_triangles()
        triangles += len(obj.data.loop_triangles)
    return {
        "mesh_parts": len(objects),
        "vertices": vertices,
        "polygons": polygons,
        "triangles": triangles,
    }


def main() -> None:
    args = parse_args()
    extension = max(0.0, float(args.middle_extension))
    height = 20.62 + extension
    input_path = Path(args.input).expanduser().resolve()
    out_dir = Path(args.output_dir).expanduser().resolve()
    out_dir.mkdir(parents=True, exist_ok=True)
    if not input_path.is_file():
        raise FileNotFoundError(input_path)

    clear_scene()
    source = import_reference(input_path)
    images = build_textures(out_dir, args.texture_size)
    mats = {
        "stone": material(
            "EmberCitadel_DarkStone",
            (0.11, 0.12, 0.145, 1.0),
            roughness=0.74,
            image=images["stone"],
        ),
        "iron": material(
            "EmberCitadel_BlackIron",
            (0.045, 0.052, 0.068, 1.0),
            metallic=0.72,
            roughness=0.31,
        ),
        "bronze": material(
            "EmberCitadel_BurnishedBronze",
            (0.46, 0.17, 0.028, 1.0),
            metallic=0.82,
            roughness=0.27,
        ),
        "crimson": material(
            "EmberCitadel_Crimson",
            (0.40, 0.012, 0.022, 1.0),
            roughness=0.68,
            image=images["crimson"],
        ),
        "ember": material(
            "EmberCitadel_Ember",
            (0.85, 0.035, 0.002, 1.0),
            roughness=0.34,
            image=images["ember"],
            emission=(1.0, 0.04, 0.001, 1.0),
            emission_strength=4.0,
        ),
        "flame": material(
            "EmberCitadel_Flame",
            (1.0, 0.12, 0.002, 1.0),
            roughness=0.18,
            emission=(1.0, 0.035, 0.001, 1.0),
            emission_strength=3.8,
        ),
        "flame_hot": material(
            "EmberCitadel_FlameHot",
            (1.0, 0.52, 0.015, 1.0),
            roughness=0.15,
            emission=(1.0, 0.20, 0.002, 1.0),
            emission_strength=3.2,
        ),
        "preview": material(
            "Preview_Plinth",
            (0.014, 0.018, 0.026, 1.0),
            metallic=0.20,
            roughness=0.46,
        ),
    }

    editable = collection("REBUILT_EmberCitadel")
    build_tower(editable, mats, extension)
    export_collection = collection("EXPORT_EmberCitadel")
    export_objects = duplicate_for_export(editable, export_collection)
    preview = add_preview_scene(editable, mats)
    camera = setup_render(args.preview_size, mats, height)

    # Render only the editable asset and preview plinth.
    source.hide_render = True
    export_collection.hide_render = True
    export_collection.hide_viewport = True
    previews = render_angles(camera, out_dir, height, extension)

    # Export only the consolidated material groups.
    export_collection.hide_viewport = False
    bpy.ops.object.select_all(action="DESELECT")
    for obj in export_objects:
        obj.hide_set(False)
        obj.select_set(True)
    glb_path = out_dir / "ember_citadel_clean.glb"
    bpy.ops.export_scene.gltf(
        filepath=str(glb_path),
        export_format="GLB",
        use_selection=True,
        export_apply=True,
        export_yup=True,
        export_materials="EXPORT",
    )
    export_collection.hide_viewport = True

    blend_path = out_dir / "ember_citadel_clean.blend"
    bpy.ops.wm.save_as_mainfile(filepath=str(blend_path))
    report = {
        "source": str(input_path),
        "source_preserved_collection": source.name,
        "editable_collection": editable.name,
        "export_collection": export_collection.name,
        "dimensions_blender_units": {"width": 9.8, "depth": 9.8, "height": height},
        "middle_extension": extension,
        "export": mesh_stats(export_objects),
        "materials": [obj.data.materials[0].name for obj in export_objects if obj.data.materials],
        "previews": [str(path) for path in previews],
        "blend": str(blend_path),
        "glb": str(glb_path),
    }
    report_path = out_dir / "ember_citadel_report.json"
    report_path.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print("EMBER_CITADEL_REPORT=" + json.dumps(report))


if __name__ == "__main__":
    main()
