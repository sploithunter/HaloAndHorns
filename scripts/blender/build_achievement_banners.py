"""Build two editable, bone-rigged achievement banners for Roblox.

The meshes share one UV and skeleton contract so a single client renderer can
print heraldic achievement artwork into the cloth and a single motion driver
can add restrained flutter. No simulation is baked: the exported bones remain
cheap and deterministic in Roblox.

Headless usage:

  blender --background --factory-startup --python build_achievement_banners.py -- \
    --output-dir assets/source/props/achievement_banners/generated
"""

from __future__ import annotations

import argparse
import json
import math
import sys
from pathlib import Path

import bpy
import numpy as np
from mathutils import Vector


BONE_NAMES = (
    "ClothUpper",
    "ClothMidUpper",
    "ClothMiddle",
    "ClothMidLower",
    "ClothTip",
)

GLYPHS = {
    "A": ("01110", "10001", "10001", "11111", "10001", "10001", "10001"),
    "B": ("11110", "10001", "10001", "11110", "10001", "10001", "11110"),
    "C": ("01111", "10000", "10000", "10000", "10000", "10000", "01111"),
    "D": ("11110", "10001", "10001", "10001", "10001", "10001", "11110"),
    "E": ("11111", "10000", "10000", "11110", "10000", "10000", "11111"),
    "F": ("11111", "10000", "10000", "11110", "10000", "10000", "10000"),
    "G": ("01111", "10000", "10000", "10111", "10001", "10001", "01111"),
    "H": ("10001", "10001", "10001", "11111", "10001", "10001", "10001"),
    "I": ("11111", "00100", "00100", "00100", "00100", "00100", "11111"),
    "J": ("00111", "00010", "00010", "00010", "10010", "10010", "01100"),
    "K": ("10001", "10010", "10100", "11000", "10100", "10010", "10001"),
    "L": ("10000", "10000", "10000", "10000", "10000", "10000", "11111"),
    "M": ("10001", "11011", "10101", "10101", "10001", "10001", "10001"),
    "N": ("10001", "11001", "10101", "10011", "10001", "10001", "10001"),
    "O": ("01110", "10001", "10001", "10001", "10001", "10001", "01110"),
    "P": ("11110", "10001", "10001", "11110", "10000", "10000", "10000"),
    "Q": ("01110", "10001", "10001", "10001", "10101", "10010", "01101"),
    "R": ("11110", "10001", "10001", "11110", "10100", "10010", "10001"),
    "S": ("01111", "10000", "10000", "01110", "00001", "00001", "11110"),
    "T": ("11111", "00100", "00100", "00100", "00100", "00100", "00100"),
    "U": ("10001", "10001", "10001", "10001", "10001", "10001", "01110"),
    "V": ("10001", "10001", "10001", "10001", "10001", "01010", "00100"),
    "W": ("10001", "10001", "10001", "10101", "10101", "10101", "01010"),
    "X": ("10001", "10001", "01010", "00100", "01010", "10001", "10001"),
    "Y": ("10001", "10001", "01010", "00100", "00100", "00100", "00100"),
    "Z": ("11111", "00001", "00010", "00100", "01000", "10000", "11111"),
    "0": ("01110", "10001", "10011", "10101", "11001", "10001", "01110"),
    "1": ("00100", "01100", "00100", "00100", "00100", "00100", "01110"),
    "2": ("01110", "10001", "00001", "00010", "00100", "01000", "11111"),
    "3": ("11110", "00001", "00001", "01110", "00001", "00001", "11110"),
    "4": ("00010", "00110", "01010", "10010", "11111", "00010", "00010"),
    "5": ("11111", "10000", "10000", "11110", "00001", "00001", "11110"),
    "6": ("01110", "10000", "10000", "11110", "10001", "10001", "01110"),
    "7": ("11111", "00001", "00010", "00100", "01000", "01000", "01000"),
    "8": ("01110", "10001", "10001", "01110", "10001", "10001", "01110"),
    "9": ("01110", "10001", "10001", "01111", "00001", "00001", "01110"),
    "-": ("00000", "00000", "00000", "11111", "00000", "00000", "00000"),
    " ": ("00000",) * 7,
}

VARIANTS = {
    "champion_standard": {
        "shape": "shield",
        "title": "LEVEL",
        "value": "100",
        "footer": "REALM CHAMPION",
        "base": (0.035, 0.105, 0.265),
        "deep": (0.018, 0.035, 0.095),
        "accent": (0.96, 0.72, 0.20),
        "ink": (1.00, 0.93, 0.68),
    },
    "victory_swallowtail": {
        "shape": "swallowtail",
        "title": "WAVE",
        "value": "250",
        "footer": "BATTLE HONORS",
        "base": (0.30, 0.022, 0.035),
        "deep": (0.075, 0.008, 0.014),
        "accent": (0.94, 0.45, 0.10),
        "ink": (1.00, 0.84, 0.48),
    },
}


def parse_args() -> argparse.Namespace:
    argv = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    parser = argparse.ArgumentParser()
    parser.add_argument("--output-dir", required=True)
    parser.add_argument("--texture-size", type=int, default=512)
    parser.add_argument("--preview-size", type=int, default=768)
    return parser.parse_args(argv)


def clear_scene() -> None:
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for datablocks in (bpy.data.meshes, bpy.data.curves, bpy.data.armatures, bpy.data.materials, bpy.data.images):
        for block in list(datablocks):
            if block.users == 0:
                datablocks.remove(block)


def blend_pixel(canvas: np.ndarray, mask: np.ndarray, color, alpha=1.0) -> None:
    if not np.any(mask):
        return
    a = float(alpha)
    canvas[mask, :3] = canvas[mask, :3] * (1.0 - a) + np.asarray(color) * a
    canvas[mask, 3] = 1.0


def rectangle(canvas: np.ndarray, x0, y0, x1, y1, color, alpha=1.0) -> None:
    height, width = canvas.shape[:2]
    xa, xb = max(0, int(x0)), min(width, int(x1))
    ya, yb = max(0, int(y0)), min(height, int(y1))
    if xa >= xb or ya >= yb:
        return
    region = canvas[ya:yb, xa:xb]
    region[:, :, :3] = region[:, :, :3] * (1.0 - alpha) + np.asarray(color) * alpha
    region[:, :, 3] = 1.0


def ellipse(canvas: np.ndarray, cx, cy, rx, ry, angle, color, alpha=1.0) -> None:
    height, width = canvas.shape[:2]
    radius = int(max(rx, ry) + 3)
    x0, x1 = max(0, int(cx - radius)), min(width, int(cx + radius + 1))
    y0, y1 = max(0, int(cy - radius)), min(height, int(cy + radius + 1))
    yy, xx = np.mgrid[y0:y1, x0:x1]
    cosine, sine = math.cos(angle), math.sin(angle)
    dx, dy = xx - cx, yy - cy
    local_x = cosine * dx + sine * dy
    local_y = -sine * dx + cosine * dy
    local_mask = (local_x / rx) ** 2 + (local_y / ry) ** 2 <= 1.0
    mask = np.zeros((height, width), dtype=bool)
    mask[y0:y1, x0:x1] = local_mask
    blend_pixel(canvas, mask, color, alpha)


def polygon(canvas: np.ndarray, points, color, alpha=1.0) -> None:
    height, width = canvas.shape[:2]
    xs = [p[0] for p in points]
    ys = [p[1] for p in points]
    x0, x1 = max(0, int(min(xs))), min(width - 1, int(max(xs)))
    y0, y1 = max(0, int(min(ys))), min(height - 1, int(max(ys)))
    yy, xx = np.mgrid[y0 : y1 + 1, x0 : x1 + 1]
    inside = np.zeros_like(xx, dtype=bool)
    previous = points[-1]
    for current in points:
        x_a, y_a = previous
        x_b, y_b = current
        crossing = ((y_a > yy) != (y_b > yy)) & (
            xx < (x_b - x_a) * (yy - y_a) / ((y_b - y_a) + 1e-9) + x_a
        )
        inside ^= crossing
        previous = current
    mask = np.zeros((height, width), dtype=bool)
    mask[y0 : y1 + 1, x0 : x1 + 1] = inside
    blend_pixel(canvas, mask, color, alpha)


def draw_text(canvas, text, center_x, top_y, max_width, cell, color, shadow) -> None:
    text = text.upper()
    units = max(1, len(text) * 6 - 1)
    scale = max(1, min(int(cell), int(max_width / units)))
    total_width = units * scale
    origin_x = int(center_x - total_width * 0.5)
    for char_index, char in enumerate(text):
        glyph = GLYPHS.get(char, GLYPHS[" "])
        base_x = origin_x + char_index * 6 * scale
        for row, bits in enumerate(glyph):
            for column, bit in enumerate(bits):
                if bit != "1":
                    continue
                x = base_x + column * scale
                y = int(top_y) + row * scale
                rectangle(canvas, x + 2, y + 2, x + scale + 2, y + scale + 2, shadow, 0.82)
                rectangle(canvas, x, y, x + scale, y + scale, color, 1.0)
                if scale >= 4:
                    rectangle(canvas, x, y, x + scale, y + 1, (1.0, 0.96, 0.78), 0.48)


def build_preview_texture(path: Path, size: int, style: dict) -> bpy.types.Image:
    yy, xx = np.mgrid[0:size, 0:size]
    base = np.asarray(style["base"])
    deep = np.asarray(style["deep"])
    vertical = np.clip(0.82 + 0.16 * np.cos((yy / size) * math.pi), 0.0, 1.0)
    fold = 0.93 + 0.07 * np.sin((xx / size) * math.pi * 8.0 + (yy / size) * 0.8)
    grain = (((xx * 37 + yy * 19 + (xx * yy) % 17) % 31) / 30.0 - 0.5) * 0.045
    tone = vertical * fold + grain
    canvas = np.empty((size, size, 4), dtype=np.float32)
    canvas[:, :, :3] = np.clip(deep + (base - deep) * tone[:, :, None], 0.0, 1.0)
    canvas[:, :, 3] = 1.0

    # Woven warp/weft catches light without pretending to be a flat UI panel.
    canvas[::4, :, :3] = np.clip(canvas[::4, :, :3] * 1.10, 0.0, 1.0)
    canvas[:, 1::5, :3] = np.clip(canvas[:, 1::5, :3] * 0.91, 0.0, 1.0)

    accent, ink = style["accent"], style["ink"]
    shadow = tuple(float(c) * 0.20 for c in style["deep"])
    margin = size * 0.055
    rectangle(canvas, margin, margin, size - margin, margin + 10, accent)
    rectangle(canvas, margin, size - margin - 10, size - margin, size - margin, accent)
    rectangle(canvas, margin, margin, margin + 10, size - margin, accent)
    rectangle(canvas, size - margin - 10, margin, size - margin, size - margin, accent)
    rectangle(canvas, margin + 15, margin + 15, size - margin - 15, margin + 19, ink, 0.62)
    rectangle(canvas, margin + 15, size - margin - 19, size - margin - 15, size - margin - 15, ink, 0.62)

    # Heraldic shield, crown diamond, and laurels make the copy part of a crest.
    cx = size * 0.5
    shield = [
        (cx - size * 0.20, size * 0.29),
        (cx + size * 0.20, size * 0.29),
        (cx + size * 0.16, size * 0.66),
        (cx, size * 0.78),
        (cx - size * 0.16, size * 0.66),
    ]
    polygon(canvas, shield, shadow, 0.52)
    inner = [(cx + (x - cx) * 0.90, size * 0.04 + y * 0.92) for x, y in shield]
    polygon(canvas, inner, style["base"], 0.88)
    polygon(
        canvas,
        [(cx, size * 0.11), (cx + 22, size * 0.16), (cx, size * 0.21), (cx - 22, size * 0.16)],
        accent,
    )

    for side in (-1, 1):
        for index in range(9):
            progress = index / 8.0
            angle = (-0.95 + progress * 1.85) * side
            leaf_x = cx + side * (size * 0.265 - 36 * math.sin(progress * math.pi))
            leaf_y = size * (0.33 + progress * 0.38)
            ellipse(canvas, leaf_x, leaf_y, 18, 7, angle, accent, 0.95)

    ribbon_y = size * 0.235
    rectangle(canvas, size * 0.18, ribbon_y, size * 0.82, ribbon_y + size * 0.115, shadow, 0.85)
    polygon(canvas, [(size * 0.12, ribbon_y + 8), (size * 0.18, ribbon_y + 8), (size * 0.18, ribbon_y + 48), (size * 0.10, ribbon_y + 62)], accent, 0.82)
    polygon(canvas, [(size * 0.88, ribbon_y + 8), (size * 0.82, ribbon_y + 8), (size * 0.82, ribbon_y + 48), (size * 0.90, ribbon_y + 62)], accent, 0.82)
    draw_text(canvas, style["title"], cx, ribbon_y + 10, size * 0.54, 7, ink, shadow)
    draw_text(canvas, style["value"], cx, size * 0.40, size * 0.48, 14, ink, shadow)
    draw_text(canvas, style["footer"], cx, size * 0.81, size * 0.70, 5, ink, shadow)

    image = bpy.data.images.new(path.stem, width=size, height=size, alpha=True)
    image.pixels.foreach_set(np.flipud(canvas).ravel())
    image.filepath_raw = str(path)
    image.file_format = "PNG"
    image.save()
    return image


def make_material(name: str, color, metallic=0.0, roughness=0.55, image=None):
    material = bpy.data.materials.new(name)
    material.use_nodes = True
    bsdf = material.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (*color, 1.0)
    bsdf.inputs["Metallic"].default_value = metallic
    bsdf.inputs["Roughness"].default_value = roughness
    if image is not None:
        node = material.node_tree.nodes.new("ShaderNodeTexImage")
        node.image = image
        node.interpolation = "Linear"
        material.node_tree.links.new(node.outputs["Color"], bsdf.inputs["Base Color"])
    return material


def bottom_z(shape: str, x: float, half_width: float, top: float, height: float) -> float:
    normalized = min(1.0, abs(x) / half_width)
    base = top - height
    if shape == "shield":
        return base + 0.92 * normalized**1.65
    # Deep points at the edges, a restrained notch at center.
    return base + 1.35 * (1.0 - normalized) ** 1.45


def build_cloth(shape: str, material, width=5.2, height=7.4, columns=16, rows=24):
    top = 4.25
    half_width = width * 0.5
    vertices, faces, uvs = [], [], []
    for row in range(rows + 1):
        t = row / rows
        for column in range(columns + 1):
            u = column / columns
            x = (u - 0.5) * width
            z_end = bottom_z(shape, x, half_width, top, height)
            z = top + (z_end - top) * t
            # A modeled rest ripple makes even a motion-disabled banner read as cloth.
            y = -0.055 + 0.11 * math.sin(u * math.tau * 2.0 + 0.45) * math.sin(t * math.pi)
            y += 0.035 * math.sin(t * math.tau * 1.5 + u * 2.2) * t
            vertices.append((x, y, z))
            uvs.append((u, 1.0 - t))
    stride = columns + 1
    for row in range(rows):
        for column in range(columns):
            a = row * stride + column
            b = a + 1
            c = a + stride + 1
            d = a + stride
            faces.append((a, d, c, b))  # normals toward Blender -Y / preview camera

    mesh = bpy.data.meshes.new("Cloth_Mesh")
    mesh.from_pydata(vertices, [], faces)
    mesh.validate(verbose=True)
    cloth = bpy.data.objects.new("Cloth", mesh)
    bpy.context.collection.objects.link(cloth)
    cloth.data.materials.append(material)
    cloth["AchievementPrintUV"] = "UVMap:0..1"
    cloth["RobloxDoubleSided"] = True

    uv_layer = mesh.uv_layers.new(name="UVMap")
    for polygon_data in mesh.polygons:
        for loop_index in polygon_data.loop_indices:
            uv_layer.data[loop_index].uv = uvs[mesh.loops[loop_index].vertex_index]
    for polygon_data in mesh.polygons:
        polygon_data.use_smooth = True
    return cloth, top, height


def build_armature(cloth, top, height):
    data = bpy.data.armatures.new("AchievementBannerRig")
    armature = bpy.data.objects.new("AchievementBannerRig", data)
    bpy.context.collection.objects.link(armature)
    armature.show_in_front = True
    armature.data.display_type = "STICK"
    armature["BoneContract"] = ",".join(BONE_NAMES)
    bpy.context.view_layer.objects.active = armature
    armature.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")
    root = data.edit_bones.new("BannerRoot")
    root.head = (0.0, 0.0, top + 0.62)
    root.tail = (0.0, 0.0, top + 0.06)
    root.use_deform = False
    parent = root
    for index, name in enumerate(BONE_NAMES):
        bone = data.edit_bones.new(name)
        bone.head = (0.0, 0.0, top - height * index / len(BONE_NAMES))
        bone.tail = (0.0, 0.0, top - height * (index + 1) / len(BONE_NAMES))
        bone.parent = parent
        bone.use_connect = index > 0
        parent = bone
    bpy.ops.object.mode_set(mode="OBJECT")

    groups = [cloth.vertex_groups.new(name=name) for name in BONE_NAMES]
    columns = 16
    rows = 24
    for row in range(rows + 1):
        position = (row / rows) * (len(BONE_NAMES) - 1)
        first = min(len(BONE_NAMES) - 1, int(math.floor(position)))
        second = min(len(BONE_NAMES) - 1, first + 1)
        blend = position - first
        indices = [row * (columns + 1) + column for column in range(columns + 1)]
        groups[first].add(indices, 1.0 - blend, "REPLACE")
        if second != first and blend > 0.0:
            groups[second].add(indices, blend, "ADD")
    modifier = cloth.modifiers.new("AchievementBannerRig", "ARMATURE")
    modifier.object = armature
    modifier.use_deform_preserve_volume = True
    cloth.parent = armature
    return armature


def add_box(name, location, scale, material):
    bpy.ops.mesh.primitive_cube_add(location=location)
    obj = bpy.context.active_object
    obj.name = name
    obj.scale = (scale[0] * 0.5, scale[1] * 0.5, scale[2] * 0.5)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.data.materials.append(material)
    bevel = obj.modifiers.new("SoftEdges", "BEVEL")
    bevel.width = 0.035
    bevel.segments = 2
    return obj


def build_mount(top, gold, wood, dark):
    parts = []
    bpy.ops.mesh.primitive_cylinder_add(vertices=16, radius=0.14, depth=6.45, location=(0, 0, top + 0.34), rotation=(0, math.pi / 2, 0))
    rod = bpy.context.active_object
    rod.data.materials.append(wood)
    parts.append(rod)
    for side in (-1, 1):
        bpy.ops.mesh.primitive_cone_add(vertices=12, radius1=0.30, radius2=0.06, depth=0.62, location=(side * 3.52, 0, top + 0.34), rotation=(0, math.pi / 2, 0))
        finial = bpy.context.active_object
        finial.rotation_euler[1] *= side
        finial.data.materials.append(gold)
        parts.append(finial)
        parts.append(add_box("Bracket", (side * 2.62, 0.42, top + 0.52), (0.24, 0.86, 0.48), dark))
        parts.append(add_box("WallPlate", (side * 2.62, 0.78, top + 0.52), (0.72, 0.14, 1.16), gold))
    for x in (-2.05, -1.02, 0.0, 1.02, 2.05):
        bpy.ops.mesh.primitive_torus_add(major_radius=0.14, minor_radius=0.045, major_segments=12, minor_segments=6, location=(x, -0.005, top + 0.08), rotation=(math.pi / 2, 0, 0))
        loop = bpy.context.active_object
        loop.data.materials.append(gold)
        parts.append(loop)
    bpy.ops.object.select_all(action="DESELECT")
    for part in parts:
        part.select_set(True)
    bpy.context.view_layer.objects.active = rod
    bpy.ops.object.join()
    rod.name = "Mount"
    return rod


def point_at(obj, target) -> None:
    obj.rotation_euler = (Vector(target) - obj.location).to_track_quat("-Z", "Y").to_euler()


def setup_preview(size: int, cloth_material, gold_material):
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x = size
    scene.render.resolution_y = size
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"
    scene.render.film_transparent = False
    scene.view_settings.look = "AgX - Medium High Contrast"
    scene.world.color = (0.018, 0.022, 0.035)
    wall = add_box("PreviewWall", (0, 1.08, 0.55), (10.4, 0.22, 10.6), make_material("PreviewStone", (0.10, 0.115, 0.14), roughness=0.88))
    wall.hide_select = True
    add_box("PreviewLintel", (0, 0.92, 5.15), (9.6, 0.36, 0.34), gold_material)

    bpy.ops.object.camera_add(location=(0, -16.0, 0.85))
    camera = bpy.context.active_object
    camera.name = "BannerPreviewCamera"
    camera.data.type = "ORTHO"
    camera.data.ortho_scale = 10.2
    point_at(camera, (0, 0, 0.5))
    scene.camera = camera

    def area(name, location, energy, color, area_size):
        bpy.ops.object.light_add(type="AREA", location=location)
        light = bpy.context.active_object
        light.name = name
        light.data.energy = energy
        light.data.color = color
        light.data.shape = "DISK"
        light.data.size = area_size
        point_at(light, (0, 0, 0.3))

    area("Key", (-5.5, -7.0, 8.0), 1050, (1.0, 0.88, 0.66), 5.0)
    area("Fill", (6.0, -5.0, 2.5), 760, (0.46, 0.65, 1.0), 5.5)
    area("Rim", (0, 3.5, 5.5), 900, (1.0, 0.45, 0.18), 4.0)
    return camera


def export_fbx(path: Path, cloth, mount, armature) -> None:
    bpy.ops.object.mode_set(mode="OBJECT") if bpy.context.object and bpy.context.object.mode != "OBJECT" else None
    bpy.ops.object.select_all(action="DESELECT")
    for obj in (cloth, mount, armature):
        obj.select_set(True)
    bpy.context.view_layer.objects.active = armature
    bpy.ops.export_scene.fbx(
        filepath=str(path),
        use_selection=True,
        object_types={"MESH", "ARMATURE"},
        apply_scale_options="FBX_SCALE_ALL",
        use_mesh_modifiers=True,
        mesh_smooth_type="FACE",
        add_leaf_bones=False,
        path_mode="COPY",
        embed_textures=True,
        bake_anim=False,
        axis_forward="-Z",
        axis_up="Y",
    )


def render_previews(out_dir: Path, slug: str, camera, armature):
    scene = bpy.context.scene
    # The source file and FBX remain in rest pose; this temporary pose proves the weighted silhouette.
    pose_angles = (0.8, 1.35, 2.0, 2.65, 3.2)
    for index, name in enumerate(BONE_NAMES):
        armature.pose.bones[name].rotation_mode = "XYZ"
        armature.pose.bones[name].rotation_euler[0] = math.radians(pose_angles[index])
        armature.pose.bones[name].rotation_euler[1] = math.radians(math.sin(index * 0.9) * 1.1)
    bpy.context.view_layer.update()
    paths = []
    shots = {
        "front": ((0.0, -16.0, 0.85), (0.0, 0.0, 0.5), 10.2),
        "angle": ((7.6, -14.0, 2.7), (0.0, 0.0, 0.6), 10.8),
    }
    for label, (position, target, ortho) in shots.items():
        camera.location = position
        camera.data.ortho_scale = ortho
        point_at(camera, target)
        path = out_dir / f"{slug}_{label}.png"
        scene.render.filepath = str(path)
        bpy.ops.render.render(write_still=True)
        paths.append(path)
    return paths


def mesh_report(cloth, armature):
    weighted = 0
    for vertex in cloth.data.vertices:
        if vertex.groups and abs(sum(group.weight for group in vertex.groups) - 1.0) < 1e-4:
            weighted += 1
    return {
        "vertices": len(cloth.data.vertices),
        "quads": len(cloth.data.polygons),
        "uv_layers": [layer.name for layer in cloth.data.uv_layers],
        "weighted_vertices": weighted,
        "bone_names": [bone.name for bone in armature.data.bones],
    }


def build_variant(root: Path, slug: str, style: dict, texture_size: int, preview_size: int):
    clear_scene()
    variant_dir = root / slug
    variant_dir.mkdir(parents=True, exist_ok=True)
    texture_path = variant_dir / f"{slug}_preview_albedo.png"
    texture = build_preview_texture(texture_path, texture_size, style)
    cloth_mat = make_material("AchievementCloth", style["base"], roughness=0.72, image=texture)
    gold = make_material("Mount_BurnishedGold", (0.58, 0.29, 0.055), metallic=0.78, roughness=0.28)
    wood = make_material("Mount_DarkWood", (0.15, 0.048, 0.022), metallic=0.02, roughness=0.58)
    dark = make_material("Mount_BlackIron", (0.045, 0.052, 0.065), metallic=0.82, roughness=0.32)

    cloth, top, height = build_cloth(style["shape"], cloth_mat)
    armature = build_armature(cloth, top, height)
    mount = build_mount(top, gold, wood, dark)
    cloth["AchievementBannerVariant"] = slug
    mount["AchievementBannerVariant"] = slug
    armature["AchievementBannerVariant"] = slug
    camera = setup_preview(preview_size, cloth_mat, gold)

    fbx_path = variant_dir / f"{slug}.fbx"
    export_fbx(fbx_path, cloth, mount, armature)
    blend_path = variant_dir / f"{slug}.blend"
    bpy.ops.wm.save_as_mainfile(filepath=str(blend_path))
    previews = render_previews(variant_dir, slug, camera, armature)
    report = {
        "schema_version": 1,
        "variant": slug,
        "shape": style["shape"],
        "dimensions_blender_units": {"width": 7.04, "depth": 0.92, "height": 8.36},
        "contract": {
            "cloth_mesh": "Cloth",
            "mount_mesh": "Mount",
            "armature": "AchievementBannerRig",
            "root_bone": "BannerRoot",
            "deform_bones": list(BONE_NAMES),
            "texture_uv": "UVMap",
            "front_axis": "-Y",
        },
        "mesh": mesh_report(cloth, armature),
        "files": {
            "blend": blend_path.name,
            "fbx": fbx_path.name,
            "preview_albedo": texture_path.name,
            "previews": [path.name for path in previews],
        },
        "fbx_bytes": fbx_path.stat().st_size,
    }
    report_path = variant_dir / f"{slug}_report.json"
    report_path.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    return report


def main() -> None:
    args = parse_args()
    output = Path(args.output_dir).expanduser().resolve()
    output.mkdir(parents=True, exist_ok=True)
    reports = []
    for slug, style in VARIANTS.items():
        reports.append(build_variant(output, slug, style, args.texture_size, args.preview_size))
    manifest = {
        "schema_version": 1,
        "generator": "scripts/blender/build_achievement_banners.py",
        "variants": reports,
    }
    manifest_path = output / "achievement_banners_manifest.json"
    manifest_path.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    print("ACHIEVEMENT_BANNER_REPORT=" + json.dumps(manifest))


if __name__ == "__main__":
    main()
