"""Build a clean, editable Emberfang Gate from the supplied Meshi reference.

The gate keeps the Ember Citadel material language but is rebuilt from closed
primitive-derived pieces: two side towers, a pointed arch, banners, spires, and
restrained ember insets. The source GLB is preserved in a hidden Blender
collection and is never included in the Roblox export.

Headless usage:

  blender --background --factory-startup --python build_emberfang_gate.py -- \
    --input /path/to/Meshy_AI_Emberfang_Gate_texture.glb \
    --output-dir assets/exports/props/emberfang_gate
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
    parser.add_argument("--texture-size", type=int, default=512)
    parser.add_argument("--preview-size", type=int, default=1024)
    return parser.parse_args(argv)


def load_citadel_helpers():
    path = Path(__file__).with_name("build_ember_citadel.py")
    spec = importlib.util.spec_from_file_location("ember_citadel_helpers", path)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"Unable to load helper module: {path}")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def add_local_octagon(helpers, target, name, x, y, z, depth, radius_bottom, radius_top, mat, bevel_width=0.04):
    bpy.ops.mesh.primitive_cone_add(
        vertices=8,
        radius1=radius_bottom,
        radius2=radius_top,
        depth=depth,
        end_fill_type="NGON",
        location=(x, y, z),
        rotation=(0.0, 0.0, math.radians(22.5)),
    )
    obj = bpy.context.active_object
    obj.name = name
    helpers.set_material(obj, mat)
    helpers.bevel(obj, bevel_width)
    helpers.move_to_collection(obj, target)
    return obj


def add_extruded_profile(helpers, target, name, profile, depth, mat, y=0.0, bevel_width=0.025):
    """Create a closed prism from an x/z outline, facing the -Y camera."""
    half = depth * 0.5
    verts = [(x, y - half, z) for x, z in profile] + [(x, y + half, z) for x, z in profile]
    count = len(profile)
    faces = [tuple(reversed(range(count))), tuple(range(count, count * 2))]
    for index in range(count):
        nxt = (index + 1) % count
        faces.append((index, nxt, count + nxt, count + index))
    mesh = bpy.data.meshes.new(name + "_Mesh")
    mesh.from_pydata(verts, [], faces)
    mesh.validate()
    obj = bpy.data.objects.new(name, mesh)
    target.objects.link(obj)
    helpers.set_material(obj, mat)
    helpers.bevel(obj, bevel_width)
    return obj


def add_rect_beam(helpers, target, name, start, end, width, depth, mat, bevel_width=0.02):
    """Create a closed rectangular beam between two 3D points."""
    midpoint = (start + end) * 0.5
    direction = end - start
    bpy.ops.mesh.primitive_cube_add(location=midpoint)
    obj = bpy.context.active_object
    obj.name = name
    obj.dimensions = (width, depth, direction.length)
    obj.rotation_euler = direction.to_track_quat("Z", "Y").to_euler()
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    helpers.set_material(obj, mat)
    helpers.bevel(obj, bevel_width)
    helpers.move_to_collection(obj, target)
    return obj


def add_segmented_arch(helpers, target, name, points, y, width, depth, mat, bevel_width=0.018):
    for index, (start, end) in enumerate(zip(points, points[1:]), start=1):
        add_rect_beam(
            helpers,
            target,
            f"{name}_{index:02d}",
            Vector((start[0], y, start[1])),
            Vector((end[0], y, end[1])),
            width,
            depth,
            mat,
            bevel_width,
        )


def add_hanging_finial(helpers, target, name, x, y, top_z, height, radius, mat):
    """Create a downward-pointing Gothic finial."""
    bpy.ops.mesh.primitive_cylinder_add(
        vertices=8,
        radius=radius * 0.42,
        depth=height * 0.30,
        location=(x, y, top_z - height * 0.15),
    )
    collar = bpy.context.active_object
    collar.name = name + "_Collar"
    helpers.set_material(collar, mat)
    helpers.move_to_collection(collar, target)
    bpy.ops.mesh.primitive_cone_add(
        vertices=8,
        radius1=0.0,
        radius2=radius,
        depth=height * 0.72,
        location=(x, y, top_z - height * 0.66),
    )
    tip = bpy.context.active_object
    tip.name = name + "_Tip"
    helpers.set_material(tip, mat)
    helpers.move_to_collection(tip, target)


def add_diamond(helpers, target, name, x, y, z, width, height, depth, mat):
    profile = [
        (x, z + height * 0.5),
        (x + width * 0.5, z),
        (x, z - height * 0.5),
        (x - width * 0.5, z),
    ]
    return add_extruded_profile(helpers, target, name, profile, depth, mat, y=y, bevel_width=0.012)


def add_front_panel(helpers, target, name, x, z, width, height, depth, mat, y=-2.2, bevel_width=0.025):
    obj = helpers.add_pointed_panel(
        target,
        name,
        abs(y),
        0.0,
        z,
        width,
        height,
        depth,
        mat,
        bevel_width=bevel_width,
    )
    obj.location.x += x
    return obj


def build_gate(helpers, target, mats):
    stone = mats["stone"]
    iron = mats["iron"]
    bronze = mats["bronze"]
    crimson = mats["crimson"]
    ember = mats["ember"]
    flame = mats["flame"]
    hot = mats["flame_hot"]

    # Shared foundation keeps the two towers visually connected.
    helpers.add_box(target, "GateFoundation", (0.0, 0.0, 0.28), (21.0, 6.8, 0.56), stone, bevel_width=0.08)
    helpers.add_box(target, "GateFoundationTrim", (0.0, -0.05, 0.68), (20.2, 6.2, 0.22), iron, bevel_width=0.04)
    helpers.add_box(target, "GateThreshold", (0.0, -0.55, 1.02), (9.0, 1.15, 0.24), bronze, bevel_width=0.035)

    # Two matching side towers. Their bases are broad enough to read at a distance.
    for side, label in ((-1, "Left"), (1, "Right")):
        x = side * 7.15
        helpers.add_box(target, f"{label}Footing01", (x, 0.0, 0.42), (6.55, 6.20, 0.58), stone, bevel_width=0.06)
        helpers.add_box(target, f"{label}Footing02", (x, -0.08, 0.80), (5.85, 5.72, 0.36), iron, bevel_width=0.045)
        helpers.add_box(target, f"{label}Footing03", (x, -0.18, 1.08), (5.20, 5.28, 0.28), bronze, bevel_width=0.035)
        add_local_octagon(helpers, target, f"{label}Base", x, 0.0, 1.28, 1.10, 3.35, 3.05, stone, 0.06)
        add_local_octagon(helpers, target, f"{label}BaseBelt", x, 0.0, 2.0, 0.34, 2.78, 2.78, iron, 0.04)
        helpers.add_box(target, f"{label}Keep", (x, 0.0, 5.2), (4.55, 4.35, 6.35), stone, bevel_width=0.07)
        helpers.add_box(target, f"{label}KeepInset", (x, -2.22, 5.15), (3.55, 0.26, 5.75), iron, bevel_width=0.035)
        helpers.add_box(target, f"{label}KeepLowerBelt", (x, -2.36, 2.75), (4.25, 0.34, 0.34), bronze, bevel_width=0.025)
        helpers.add_box(target, f"{label}KeepUpperBelt", (x, -2.36, 7.60), (4.25, 0.34, 0.34), bronze, bevel_width=0.025)
        helpers.add_box(target, f"{label}KeepBelt", (x, 0.0, 8.48), (4.9, 4.7, 0.35), iron, bevel_width=0.045)

        for course_index, course_z in enumerate((3.22, 4.38, 5.54, 6.70), start=1):
            helpers.add_box(
                target,
                f"{label}MasonryCourse{course_index}",
                (x, -2.39, course_z),
                (3.52, 0.10, 0.075),
                stone,
                bevel_width=0.008,
            )

        for rib_index, rib_offset in enumerate((-1.68, 1.68), start=1):
            helpers.add_box(
                target,
                f"{label}FacadeRib{rib_index}",
                (x + rib_offset, -2.43, 5.28),
                (0.34, 0.38, 6.32),
                iron,
                bevel_width=0.025,
            )
            helpers.add_spire(
                target,
                f"{label}FacadeRibSpire{rib_index}",
                x + rib_offset,
                -2.43,
                8.46,
                0.70,
                0.16,
                iron,
            )
            add_diamond(
                helpers,
                target,
                f"{label}FacadeDiamond{rib_index}",
                x + rib_offset,
                -2.66,
                5.46,
                0.62,
                1.16,
                0.18,
                bronze,
            )

        # Projecting corner turrets give each side tower a deep, castellated silhouette.
        for turret_index, (corner_x, corner_y) in enumerate(
            ((x - 2.12, -2.05), (x + 2.12, -2.05), (x - 2.12, 2.05), (x + 2.12, 2.05)),
            start=1,
        ):
            helpers.add_box(
                target,
                f"{label}CornerTurret{turret_index}",
                (corner_x, corner_y, 5.15),
                (0.62, 0.72, 6.65),
                iron,
                bevel_width=0.03,
            )
            helpers.add_spire(
                target,
                f"{label}CornerTurretSpire{turret_index}",
                corner_x,
                corner_y,
                8.48,
                0.78,
                0.18,
                iron,
            )

        # Outer corner buttresses and small roofline spires.
        for offset, index in ((-1.85, 1), (1.85, 2)):
            helpers.add_box(
                target,
                f"{label}Buttress{index}",
                (x + side * offset, -0.05, 4.45),
                (0.62, 4.8, 7.4),
                iron,
                bevel_width=0.035,
            )
            helpers.add_spire(target, f"{label}ButtressSpire{index}", x + side * offset, -2.15, 8.7, 0.72, 0.22, iron)

        add_front_panel(helpers, target, f"{label}BannerOuter", x, 2.55, 2.0, 5.15, 0.22, iron, y=-2.28, bevel_width=0.04)
        add_front_panel(helpers, target, f"{label}BannerFrame", x, 2.72, 1.68, 4.82, 0.14, bronze, y=-2.40, bevel_width=0.03)
        add_front_panel(helpers, target, f"{label}Banner", x, 2.88, 1.30, 4.42, 0.08, crimson, y=-2.51, bevel_width=0.018)
        helpers.add_box(target, f"{label}RuneSpine", (x, -2.58, 5.2), (0.09, 0.07, 2.45), bronze, bevel_width=0.012)
        for index, z in enumerate((4.35, 5.20, 6.05), start=1):
            rune = helpers.add_box(target, f"{label}Rune{index}", (x, -2.63, z), (0.28, 0.08, 0.28), bronze, yaw=math.radians(45), bevel_width=0.015)
            rune.scale.x = 0.72

        # Upper turret and a three-spire crown on each side.
        add_local_octagon(helpers, target, f"{label}Turret", x, 0.0, 10.05, 2.35, 2.45, 2.20, stone, 0.055)
        add_local_octagon(helpers, target, f"{label}TurretInset", x, -0.03, 10.10, 1.86, 1.88, 1.76, iron, 0.035)
        add_local_octagon(helpers, target, f"{label}TurretBelt", x, 0.0, 11.34, 0.35, 2.68, 2.68, bronze, 0.04)
        add_front_panel(helpers, target, f"{label}TurretWindowOuter", x, 9.18, 1.18, 2.35, 0.14, iron, y=-2.08, bevel_width=0.025)
        add_front_panel(helpers, target, f"{label}TurretWindowGlow", x, 9.38, 0.72, 1.88, 0.08, ember, y=-2.18, bevel_width=0.014)
        add_front_panel(helpers, target, f"{label}RoofGableOuter", x, 10.55, 3.30, 4.52, 0.24, iron, y=-1.88, bevel_width=0.035)
        add_front_panel(helpers, target, f"{label}RoofGableFrame", x, 10.82, 2.52, 3.84, 0.16, bronze, y=-2.02, bevel_width=0.025)
        add_front_panel(helpers, target, f"{label}RoofGableGlow", x, 11.22, 1.08, 2.62, 0.10, ember, y=-2.14, bevel_width=0.016)
        for offset, index in ((-1.5, 1), (0.0, 2), (1.5, 3)):
            helpers.add_spire(
                target,
                f"{label}TurretSpire{index}",
                x + offset,
                -1.96,
                14.48 if index == 2 else 13.58,
                1.18 if index == 2 else 0.82,
                0.22 if index == 2 else 0.17,
                iron,
            )

        # Repeated parapet teeth make the roofline read as constructed rather than a slab.
        for tooth_index, tooth_offset in enumerate((-2.05, -1.02, 1.02, 2.05), start=1):
            helpers.add_spire(
                target,
                f"{label}ParapetTooth{tooth_index}",
                x + tooth_offset,
                -2.0,
                8.58,
                0.40,
                0.11,
                iron,
            )

    # The broad spandrel wall is the principal mass connecting the towers. It keeps the
    # arch from reading as decorative ribbons suspended between two unrelated boxes.
    spandrel_outer = [
        (-6.10, 7.35), (-6.10, 11.65), (-5.42, 13.35), (-4.28, 15.10),
        (-2.82, 17.00), (-1.45, 18.15), (0.0, 18.72), (1.45, 18.15),
        (2.82, 17.00), (4.28, 15.10), (5.42, 13.35), (6.10, 11.65), (6.10, 7.35),
    ]
    spandrel_inner = [
        (4.42, 7.35), (4.42, 7.92), (4.08, 9.16), (3.28, 10.57),
        (2.16, 11.76), (1.06, 12.65), (0.0, 13.34), (-1.06, 12.65),
        (-2.16, 11.76), (-3.28, 10.57), (-4.08, 9.16), (-4.42, 7.92), (-4.42, 7.35),
    ]
    add_extruded_profile(
        helpers,
        target,
        "CentralSpandrel",
        spandrel_outer + spandrel_inner,
        2.85,
        stone,
        y=0.25,
        bevel_width=0.055,
    )
    helpers.add_box(target, "SpandrelLowerBeltLeft", (-5.35, -1.20, 8.12), (1.55, 0.40, 0.42), iron, bevel_width=0.035)
    helpers.add_box(target, "SpandrelLowerBeltRight", (5.35, -1.20, 8.12), (1.55, 0.40, 0.42), iron, bevel_width=0.035)
    helpers.add_box(target, "SpandrelUpperBelt", (0.0, -1.20, 14.72), (8.2, 0.40, 0.36), bronze, bevel_width=0.03)

    # Recessed ember lancets fill the wall beside the arch, as in the reference façade.
    for side, label in ((-1, "Left"), (1, "Right")):
        add_front_panel(helpers, target, f"{label}SpandrelLancetOuter", side * 5.16, 9.20, 0.82, 2.68, 0.16, iron, y=-1.31, bevel_width=0.022)
        add_front_panel(helpers, target, f"{label}SpandrelLancetGlow", side * 5.16, 9.42, 0.42, 2.10, 0.08, ember, y=-1.43, bevel_width=0.012)
        add_front_panel(helpers, target, f"{label}UpperLancetOuter", side * 3.95, 12.35, 0.72, 2.22, 0.14, iron, y=-1.32, bevel_width=0.02)
        add_front_panel(helpers, target, f"{label}UpperLancetGlow", side * 3.95, 12.53, 0.34, 1.68, 0.07, ember, y=-1.43, bevel_width=0.01)

    # A single solid pointed arch band. The inner profile leaves the entrance open.
    outer = [
        (-5.42, 1.05), (-5.42, 8.05), (-5.05, 9.75), (-4.22, 11.45),
        (-3.02, 12.95), (-1.60, 14.25), (0.0, 15.18), (1.60, 14.25),
        (3.02, 12.95), (4.22, 11.45), (5.05, 9.75), (5.42, 8.05), (5.42, 1.05),
    ]
    inner = [
        (4.20, 1.05), (4.20, 7.92), (3.86, 9.28), (3.08, 10.78),
        (1.92, 12.06), (0.88, 12.98), (0.0, 13.72), (-0.88, 12.98),
        (-1.92, 12.06), (-3.08, 10.78), (-3.86, 9.28), (-4.20, 7.92), (-4.20, 1.05),
    ]
    add_extruded_profile(helpers, target, "PointedArchBand", outer + inner, 1.25, iron, y=-0.15, bevel_width=0.035)
    # Bronze and ember liners follow the same silhouette at the front face.
    add_extruded_profile(helpers, target, "PointedArchTrim", [
        (-4.83, 1.18), (-4.83, 7.98), (-4.45, 9.58), (-3.55, 11.15),
        (-2.34, 12.48), (-1.15, 13.50), (0.0, 14.18), (1.15, 13.50),
        (2.34, 12.48), (3.55, 11.15), (4.45, 9.58), (4.83, 7.98), (4.83, 1.18),
        (4.42, 1.18), (4.42, 7.90), (4.06, 9.08), (3.23, 10.48),
        (2.12, 11.70), (1.05, 12.58), (0.0, 13.25), (-1.05, 12.58),
        (-2.12, 11.70), (-3.23, 10.48), (-4.06, 9.08), (-4.42, 7.90), (-4.42, 1.18),
    ], 1.34, bronze, y=-0.84, bevel_width=0.022)
    add_extruded_profile(helpers, target, "EmberArchLiner", [
        (-4.52, 1.30), (-4.52, 7.92), (-4.18, 9.18), (-3.37, 10.60),
        (-2.28, 11.78), (-1.10, 12.72), (0.0, 13.42), (1.10, 12.72),
        (2.28, 11.78), (3.37, 10.60), (4.18, 9.18), (4.52, 7.92), (4.52, 1.30),
        (4.34, 1.30), (4.34, 7.86), (4.02, 9.05), (3.20, 10.43),
        (2.08, 11.60), (1.02, 12.46), (0.0, 13.12), (-1.02, 12.46),
        (-2.08, 11.60), (-3.20, 10.43), (-4.02, 9.05), (-4.34, 7.86), (-4.34, 1.30),
    ], 1.40, ember, y=-0.98, bevel_width=0.014)

    # Structural ribs sit proud of the broad arch and break the sweep into readable masonry bays.
    arch_path = [
        (-5.02, 1.18), (-5.02, 8.02), (-4.67, 9.53), (-3.88, 11.10),
        (-2.76, 12.52), (-1.43, 13.70), (0.0, 14.58), (1.43, 13.70),
        (2.76, 12.52), (3.88, 11.10), (4.67, 9.53), (5.02, 8.02), (5.02, 1.18),
    ]
    add_segmented_arch(helpers, target, "ArchStoneRib", arch_path, -1.31, 0.42, 0.34, stone, 0.025)
    inner_arch_path = [
        (-4.46, 1.24), (-4.46, 7.92), (-4.12, 9.13), (-3.31, 10.54),
        (-2.20, 11.72), (-1.08, 12.62), (0.0, 13.30), (1.08, 12.62),
        (2.20, 11.72), (3.31, 10.54), (4.12, 9.13), (4.46, 7.92), (4.46, 1.24),
    ]
    add_segmented_arch(helpers, target, "ArchIronRib", inner_arch_path, -1.52, 0.24, 0.22, iron, 0.014)

    outer_rake_path = [
        (-6.02, 11.50), (-5.34, 13.18), (-4.20, 14.92), (-2.76, 16.80),
        (-1.40, 17.94), (0.0, 18.48), (1.40, 17.94), (2.76, 16.80),
        (4.20, 14.92), (5.34, 13.18), (6.02, 11.50),
    ]
    add_segmented_arch(helpers, target, "SpandrelOuterRake", outer_rake_path, -1.30, 0.38, 0.32, iron, 0.022)

    for side, label in ((-1, "Left"), (1, "Right")):
        add_diamond(helpers, target, f"{label}SpandrelDiamond01", side * 5.52, -1.52, 12.42, 0.66, 1.28, 0.20, bronze)
        add_diamond(helpers, target, f"{label}SpandrelDiamond02", side * 4.35, -1.52, 14.72, 0.58, 1.12, 0.20, bronze)
        helpers.add_spire(target, f"{label}SpandrelSpire01", side * 5.15, -1.15, 13.55, 0.88, 0.16, iron)
        helpers.add_spire(target, f"{label}SpandrelSpire02", side * 3.62, -1.15, 16.18, 0.82, 0.15, iron)

    # Keystone cluster and downward finial mark the apex of the opening.
    bpy.ops.mesh.primitive_cone_add(vertices=4, radius1=0.62, radius2=0.30, depth=1.30, location=(0.0, -1.72, 13.90), rotation=(0.0, 0.0, math.radians(45)))
    keystone = bpy.context.active_object
    keystone.name = "ArchKeystoneDiamond"
    helpers.set_material(keystone, iron)
    helpers.move_to_collection(keystone, target)
    add_hanging_finial(helpers, target, "ArchHangingFinial", 0.0, -1.72, 13.35, 1.65, 0.34, bronze)

    # Heavy inner piers and wing buttresses visually transfer the arch load into the two towers.
    for side, label in ((-1, "Left"), (1, "Right")):
        x = side * 4.88
        helpers.add_box(target, f"{label}ArchPier", (x, -0.12, 4.55), (1.08, 2.10, 7.10), stone, bevel_width=0.045)
        helpers.add_box(target, f"{label}ArchPierRib", (x, -1.38, 4.68), (0.42, 0.38, 6.72), iron, bevel_width=0.025)
        helpers.add_spire(target, f"{label}ArchPierSpire", x, -1.38, 8.10, 0.92, 0.18, iron)
        add_rect_beam(
            helpers,
            target,
            f"{label}FlyingButtress",
            Vector((side * 5.32, 0.35, 10.05)),
            Vector((side * 2.52, 0.35, 14.35)),
            0.46,
            0.52,
            iron,
            0.025,
        )
        add_rect_beam(
            helpers,
            target,
            f"{label}FlyingButtressTrim",
            Vector((side * 5.20, -0.02, 10.15)),
            Vector((side * 2.44, -0.02, 14.42)),
            0.17,
            0.24,
            ember,
            0.012,
        )

    # Central crown above the gateway echoes the tower roofs in the reference.
    add_local_octagon(helpers, target, "GateCrownShoulder", 0.0, 0.0, 17.05, 0.82, 4.15, 3.52, stone, 0.06)
    helpers.add_box(target, "GateKeystone", (0.0, -1.30, 16.88), (1.08, 1.72, 1.65), iron, bevel_width=0.045)
    add_front_panel(helpers, target, "GateCrownOuter", 0.0, 16.18, 4.82, 6.22, 0.34, iron, y=-1.12, bevel_width=0.045)
    add_front_panel(helpers, target, "GateCrownFrame", 0.0, 16.48, 4.02, 5.55, 0.24, bronze, y=-1.32, bevel_width=0.035)
    add_front_panel(helpers, target, "GateCrownBanner", 0.0, 16.80, 3.12, 4.78, 0.16, crimson, y=-1.50, bevel_width=0.025)
    helpers.add_box(target, "GateCrownRuneSpine", (0.0, -1.68, 18.82), (0.11, 0.08, 2.55), bronze, bevel_width=0.014)
    for rune_index, z in enumerate((17.94, 18.82, 19.70), start=1):
        rune = helpers.add_box(target, f"GateCrownRune{rune_index}", (0.0, -1.60, z), (0.32, 0.08, 0.32), bronze, yaw=math.radians(45), bevel_width=0.015)
        rune.scale.x = 0.72

    # Forked ember sigil from the concept, layered over the crimson center panel.
    add_rect_beam(helpers, target, "GateCrownSigilStem", Vector((0.0, -1.76, 18.45)), Vector((0.0, -1.76, 20.30)), 0.15, 0.10, ember, 0.01)
    add_rect_beam(helpers, target, "GateCrownSigilLeft01", Vector((0.0, -1.76, 20.18)), Vector((-0.50, -1.76, 20.86)), 0.16, 0.10, ember, 0.01)
    add_rect_beam(helpers, target, "GateCrownSigilLeft02", Vector((-0.50, -1.76, 20.86)), Vector((-0.38, -1.76, 21.58)), 0.15, 0.10, ember, 0.01)
    add_rect_beam(helpers, target, "GateCrownSigilRight01", Vector((0.0, -1.76, 20.18)), Vector((0.50, -1.76, 20.86)), 0.16, 0.10, ember, 0.01)
    add_rect_beam(helpers, target, "GateCrownSigilRight02", Vector((0.50, -1.76, 20.86)), Vector((0.38, -1.76, 21.58)), 0.15, 0.10, ember, 0.01)

    helpers.add_spire(target, "GateCrownApex", 0.0, -1.10, 22.46, 1.52, 0.28, iron)
    for x, index in ((-3.28, 1), (-2.12, 2), (-1.10, 3), (1.10, 4), (2.12, 5), (3.28, 6)):
        base_z = 20.10 if abs(x) < 1.5 else 19.02 if abs(x) < 2.5 else 18.02
        helpers.add_spire(target, f"GateCrownSideSpire{index}", x, -1.08, base_z, 1.08 if abs(x) < 2.5 else 0.82, 0.18, iron)

    for index, x in enumerate((-3.55, -1.78, 0.0, 1.78, 3.55), start=1):
        helpers.add_spire(target, f"GateCrownParapetSpire{index}", x, -1.36, 17.45, 0.72 if x else 0.92, 0.14 if x else 0.18, iron)

    # A pair of small lancets and ribs flank the main crown panel.
    for side, label in ((-1, "Left"), (1, "Right")):
        add_front_panel(helpers, target, f"{label}CrownLancet", side * 3.12, 17.05, 0.78, 2.72, 0.10, ember, y=-1.34, bevel_width=0.015)
        add_rect_beam(
            helpers,
            target,
            f"{label}CrownRake",
            Vector((side * 4.08, -1.12, 16.82)),
            Vector((side * 2.08, -1.12, 21.55)),
            0.30,
            0.28,
            iron,
            0.018,
        )

    # Small ember arrow insets at the bases echo the reference without placing free-floating flames
    # in the walk-through opening.
    for side, label in ((-1, "Left"), (1, "Right")):
        add_diamond(helpers, target, f"{label}BaseEmberArrow", side * 7.15, -3.12, 0.92, 0.42, 0.68, 0.10, ember)


def setup_render(size, mats):
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x = size
    scene.render.resolution_y = size
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"
    scene.world.color = (0.018, 0.022, 0.032)
    scene.world.use_nodes = True
    background = scene.world.node_tree.nodes.get("Background")
    background.inputs["Color"].default_value = (0.018, 0.022, 0.032, 1.0)
    background.inputs["Strength"].default_value = 0.32

    bpy.ops.object.camera_add(location=(0.0, -34.0, 13.2))
    camera = bpy.context.active_object
    camera.name = "GatePreviewCamera"
    camera.data.type = "ORTHO"
    camera.data.ortho_scale = 28.0
    point_camera(camera, Vector((0.0, 0.0, 12.4)))
    scene.camera = camera

    def area(name, location, energy, color, area_size):
        bpy.ops.object.light_add(type="AREA", location=location)
        light = bpy.context.active_object
        light.name = name
        light.data.energy = energy
        light.data.color = color
        light.data.shape = "DISK"
        light.data.size = area_size
        point_camera(light, Vector((0.0, 0.0, 8.0)))

    area("Key", (10.0, -14.0, 17.0), 3000.0, (0.72, 0.82, 1.0), 8.0)
    area("Fill", (-12.0, -8.0, 8.0), 1800.0, (0.45, 0.55, 0.80), 9.0)
    area("Rim", (0.0, 10.0, 15.0), 2500.0, (1.0, 0.20, 0.035), 7.0)
    bpy.ops.object.light_add(type="POINT", location=(0.0, -1.0, 10.0))
    light = bpy.context.active_object
    light.name = "GateFlameLight"
    light.data.energy = 700.0
    light.data.color = (1.0, 0.12, 0.01)
    light.data.shadow_soft_size = 4.0
    return camera


def point_camera(obj, target):
    obj.rotation_euler = (target - obj.location).to_track_quat("-Z", "Y").to_euler()


def render_angles(camera, out_dir):
    scene = bpy.context.scene
    target = Vector((0.0, 0.0, 12.4))
    shots = {
        "front": Vector((0.0, -34.0, 13.2)),
        "three_quarter": Vector((21.0, -30.0, 13.8)),
        "back_three_quarter": Vector((-21.0, 30.0, 13.8)),
    }
    paths = []
    for label, position in shots.items():
        camera.location = position
        point_camera(camera, target)
        path = out_dir / f"emberfang_gate_{label}.png"
        scene.render.filepath = str(path)
        bpy.ops.render.render(write_still=True)
        paths.append(path)
    return paths


def side_sign(value):
    return -1.0 if value < 0 else 1.0


def main():
    args = parse_args()
    helpers = load_citadel_helpers()
    input_path = Path(args.input).expanduser().resolve()
    out_dir = Path(args.output_dir).expanduser().resolve()
    out_dir.mkdir(parents=True, exist_ok=True)
    if not input_path.is_file():
        raise FileNotFoundError(input_path)

    helpers.clear_scene()
    source = helpers.import_reference(input_path)
    images = helpers.build_textures(out_dir, args.texture_size)
    mats = {
        "stone": helpers.material("EmberfangGate_DarkStone", (0.11, 0.12, 0.145, 1.0), roughness=0.74, image=images["stone"]),
        "iron": helpers.material("EmberfangGate_BlackIron", (0.045, 0.052, 0.068, 1.0), metallic=0.72, roughness=0.31),
        "bronze": helpers.material("EmberfangGate_BurnishedBronze", (0.46, 0.17, 0.028, 1.0), metallic=0.82, roughness=0.27),
        "crimson": helpers.material("EmberfangGate_Crimson", (0.40, 0.012, 0.022, 1.0), roughness=0.68, image=images["crimson"]),
        "ember": helpers.material("EmberfangGate_Ember", (0.85, 0.035, 0.002, 1.0), roughness=0.34, image=images["ember"], emission=(1.0, 0.04, 0.001, 1.0), emission_strength=4.0),
        "flame": helpers.material("EmberfangGate_Flame", (1.0, 0.12, 0.002, 1.0), roughness=0.18, emission=(1.0, 0.035, 0.001, 1.0), emission_strength=3.8),
        "flame_hot": helpers.material("EmberfangGate_FlameHot", (1.0, 0.52, 0.015, 1.0), roughness=0.15, emission=(1.0, 0.20, 0.002, 1.0), emission_strength=3.2),
    }

    editable = helpers.collection("REBUILT_EmberfangGate")
    build_gate(helpers, editable, mats)
    export_collection = helpers.collection("EXPORT_EmberfangGate")
    export_objects = helpers.duplicate_for_export(editable, export_collection)
    camera = setup_render(args.preview_size, mats)

    source.hide_render = True
    export_collection.hide_render = True
    export_collection.hide_viewport = True
    previews = render_angles(camera, out_dir)

    export_collection.hide_viewport = False
    bpy.ops.object.select_all(action="DESELECT")
    for obj in export_objects:
        obj.hide_set(False)
        obj.select_set(True)
    glb_path = out_dir / "emberfang_gate_clean.glb"
    bpy.ops.export_scene.gltf(filepath=str(glb_path), export_format="GLB", use_selection=True, export_apply=True, export_yup=True, export_materials="EXPORT")
    export_collection.hide_viewport = True

    blend_path = out_dir / "emberfang_gate_clean.blend"
    bpy.ops.wm.save_as_mainfile(filepath=str(blend_path))
    report = {
        "source": str(input_path),
        "source_preserved_collection": source.name,
        "editable_collection": editable.name,
        "export_collection": export_collection.name,
        "dimensions_blender_units": {"width": 21.0, "depth": 6.8, "height": 26.0},
        "export": helpers.mesh_stats(export_objects),
        "materials": [obj.data.materials[0].name for obj in export_objects if obj.data.materials],
        "previews": [str(path) for path in previews],
        "blend": str(blend_path),
        "glb": str(glb_path),
    }
    report_path = out_dir / "emberfang_gate_report.json"
    report_path.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print("EMBERFANG_GATE_REPORT=" + json.dumps(report))


if __name__ == "__main__":
    main()
