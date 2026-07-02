"""Render a textured pet FBX to a PNG with transparent background.

Invoked headless by scripts/render_pet_previews.sh:

  blender --background --python render_pet_preview.py -- \\
    --input assets/exports/pets/emberling_basic/emberling_basic_5k.fbx \\
    --output assets/exports/pets/basic/emberling_basic.png
"""

from __future__ import annotations

import argparse
import math
import sys
from pathlib import Path

import bmesh
import bpy
from mathutils import Vector


def parse_args() -> argparse.Namespace:
    argv = sys.argv
    if "--" in argv:
        argv = argv[argv.index("--") + 1 :]
    else:
        argv = []

    parser = argparse.ArgumentParser(description="Render a pet mesh preview PNG.")
    parser.add_argument("--input", required=True, help="FBX/OBJ/GLB mesh file")
    parser.add_argument("--output", required=True, help="Output PNG path")
    parser.add_argument("--texture", help="Optional texture PNG (auto-detected from export dir)")
    parser.add_argument("--size", type=int, default=1024, help="Square render resolution")
    parser.add_argument(
        "--padding",
        type=float,
        default=1.18,
        help="Camera framing padding multiplier (default: 1.18)",
    )
    parser.add_argument(
        "--elevation",
        type=float,
        default=12.0,
        help="Camera elevation in degrees above horizon",
    )
    parser.add_argument(
        "--azimuth",
        type=float,
        default=0.0,
        help="Camera azimuth in degrees (0=front, 90=right)",
    )
    return parser.parse_args(argv)


def clear_scene() -> None:
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for block in (bpy.data.meshes, bpy.data.materials, bpy.data.images, bpy.data.cameras, bpy.data.lights):
        for item in list(block):
            if item.users == 0:
                block.remove(item)


def import_mesh(path: Path) -> list[bpy.types.Object]:
    suffix = path.suffix.lower()
    if suffix == ".obj":
        bpy.ops.wm.obj_import(filepath=str(path))
    elif suffix == ".fbx":
        bpy.ops.import_scene.fbx(filepath=str(path))
    elif suffix in {".glb", ".gltf"}:
        bpy.ops.import_scene.gltf(filepath=str(path))
    else:
        raise ValueError(f"Unsupported mesh format: {suffix}")

    meshes = [obj for obj in bpy.context.selected_objects if obj.type == "MESH"]
    if not meshes:
        raise RuntimeError(f"No mesh imported from {path}")
    return meshes


def find_texture(mesh_path: Path, explicit: str | None) -> Path | None:
    if explicit:
        path = Path(explicit).expanduser().resolve()
        if path.is_file():
            return path
        raise FileNotFoundError(f"Texture not found: {path}")

    folder = mesh_path.parent
    stem = mesh_path.stem
    for name in (
        f"{stem}.png",
        f"{folder.name}.png",
        stem.replace("_5k", "").replace("_10k", "").replace("_7500tris", "") + ".png",
    ):
        candidate = folder / name
        if candidate.is_file():
            return candidate

    images = sorted(p for p in folder.glob("*.png") if p.is_file())
    return images[0] if images else None


def ensure_material_with_texture(obj: bpy.types.Object, texture_path: Path) -> None:
    image = bpy.data.images.load(str(texture_path), check_existing=True)
    image.alpha_mode = "STRAIGHT"

    material = bpy.data.materials.new(name=f"{obj.name}_mat")
    material.use_nodes = True
    nodes = material.node_tree.nodes
    links = material.node_tree.links
    nodes.clear()

    output = nodes.new(type="ShaderNodeOutputMaterial")
    bsdf = nodes.new(type="ShaderNodeBsdfPrincipled")
    tex = nodes.new(type="ShaderNodeTexImage")
    tex.image = image
    tex.interpolation = "Smart"
    links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    links.new(tex.outputs["Alpha"], bsdf.inputs["Alpha"])
    material.blend_method = "OPAQUE"
    links.new(bsdf.outputs["BSDF"], output.inputs["Surface"])

    if obj.data.materials:
        obj.data.materials[0] = material
    else:
        obj.data.materials.append(material)


def scene_bounds(objects: list[bpy.types.Object]) -> tuple[Vector, Vector]:
    min_corner = Vector((math.inf, math.inf, math.inf))
    max_corner = Vector((-math.inf, -math.inf, -math.inf))
    for obj in objects:
        for corner in obj.bound_box:
            world = obj.matrix_world @ Vector(corner)
            min_corner.x = min(min_corner.x, world.x)
            min_corner.y = min(min_corner.y, world.y)
            min_corner.z = min(min_corner.z, world.z)
            max_corner.x = max(max_corner.x, world.x)
            max_corner.y = max(max_corner.y, world.y)
            max_corner.z = max(max_corner.z, world.z)
    return min_corner, max_corner


def center_objects(objects: list[bpy.types.Object]) -> tuple[Vector, float]:
    min_corner, max_corner = scene_bounds(objects)
    center = (min_corner + max_corner) / 2.0
    size = max_corner - min_corner
    radius = max(size.x, size.y, size.z) / 2.0
    for obj in objects:
        obj.location -= center
    return Vector((0.0, 0.0, 0.0)), max(radius, 0.01)


def setup_camera(radius: float, padding: float, elevation_deg: float, azimuth_deg: float) -> bpy.types.Object:
    bpy.ops.object.camera_add()
    camera = bpy.context.active_object
    camera.data.type = "ORTHO"
    camera.data.ortho_scale = radius * 2.0 * padding

    elev = math.radians(elevation_deg)
    azim = math.radians(azimuth_deg)
    distance = radius * 4.0
    x = distance * math.cos(elev) * math.sin(azim)
    y = -distance * math.cos(elev) * math.cos(azim)
    z = distance * math.sin(elev)
    camera.location = Vector((x, y, z))
    direction = Vector((0.0, 0.0, 0.0)) - camera.location
    camera.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
    bpy.context.scene.camera = camera
    return camera


def setup_lights(radius: float) -> None:
    def add_light(name: str, location: tuple[float, float, float], energy: float, size: float) -> None:
        bpy.ops.object.light_add(type="AREA", location=location)
        light = bpy.context.active_object
        light.name = name
        light.data.energy = energy
        light.data.size = size
        light.data.shape = "DISK"

    scale = max(radius, 0.5)
    add_light("Key", (scale * 2.4, -scale * 2.8, scale * 2.6), 900 * scale, scale * 1.6)
    add_light("Fill", (-scale * 2.8, -scale * 1.2, scale * 1.4), 320 * scale, scale * 2.2)
    add_light("Rim", (scale * 0.4, scale * 3.0, scale * 2.0), 420 * scale, scale * 1.4)


def configure_render(output_path: Path, size: int) -> None:
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x = size
    scene.render.resolution_y = size
    scene.render.resolution_percentage = 100
    scene.render.film_transparent = True
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"
    scene.render.image_settings.compression = 15
    scene.render.filepath = str(output_path)


# Homeworld bear exports keep the face in a dedicated UV island (gold atlas layout).
FACE_UV_BOUNDS = (0.20, 0.0, 1.0, 0.48)


def is_bear_homeworld_export(mesh_path: Path) -> bool:
    return "bear_homeworld" in mesh_path.as_posix()


def base_material_index(mesh: bpy.types.Mesh) -> int | None:
    for index, material in enumerate(mesh.materials):
        if material and "Base1" in material.name:
            return index
    return None


def remap_homeworld_face_uvs(objects: list[bpy.types.Object], *, front_y_max: float = -1.05) -> None:
    """Point front Base1 faces at the shared face UV island (blue eyes / snout).

    Roblox homeworld bears face -Y in the OBJ export (Studio forward).
    """
    u0, v0, u1, v1 = FACE_UV_BOUNDS

    for obj in objects:
        mesh = obj.data
        base_index = base_material_index(mesh)
        if base_index is None:
            continue

        bm = bmesh.new()
        bm.from_mesh(mesh)
        uv_layer = bm.loops.layers.uv.active
        if uv_layer is None:
            bm.free()
            continue

        front_loops: list[bmesh.types.BMLoop] = []
        for face in bm.faces:
            if face.material_index != base_index:
                continue
            normal = (obj.matrix_world.to_3x3() @ face.normal).normalized()
            y_avg = sum((obj.matrix_world @ loop.vert.co).y for loop in face.loops) / len(face.loops)
            if y_avg <= front_y_max and normal.y < -0.45:
                front_loops.extend(face.loops)

        if not front_loops:
            bm.free()
            continue

        xs = [(obj.matrix_world @ loop.vert.co).x for loop in front_loops]
        zs = [(obj.matrix_world @ loop.vert.co).z for loop in front_loops]
        x_min, x_max = min(xs), max(xs)
        z_min, z_max = min(zs), max(zs)
        x_span = max(x_max - x_min, 1e-4)
        z_span = max(z_max - z_min, 1e-4)

        for loop in front_loops:
            co = obj.matrix_world @ loop.vert.co
            u = u0 + (co.x - x_min) / x_span * (u1 - u0)
            # Eyes sit toward higher Z on the -Y-facing front plate.
            v = v0 + (co.z - z_min) / z_span * (v1 - v0)
            loop[uv_layer].uv = (u, v)

        bm.to_mesh(mesh)
        bm.free()
        mesh.update()
        print(f"Remapped homeworld face UVs on {obj.name} ({len(front_loops)} loops)")


def strip_roblox_outline_faces(objects: list[bpy.types.Object]) -> None:
    """Remove Outline* shell geometry — Roblox outline UVs are not standard 0-1 and render gray."""
    for obj in objects:
        mesh = obj.data
        outline_indices = {
            index
            for index, material in enumerate(mesh.materials)
            if material and "Outline" in material.name
        }
        if not outline_indices:
            continue
        bm = bmesh.new()
        bm.from_mesh(mesh)
        faces_to_delete = [face for face in bm.faces if face.material_index in outline_indices]
        if faces_to_delete:
            bmesh.ops.delete(bm, geom=faces_to_delete, context="FACES")
        bm.to_mesh(mesh)
        bm.free()
        mesh.update()


def fix_obj_mtl_materials(mesh_path: Path) -> None:
    """Wire map_Kd textures from Roblox-style OBJ/MTL exports into EEVEE materials."""
    folder = mesh_path.parent
    for mat in bpy.data.materials:
        if not mat or mat.users == 0:
            continue
        if "Outline" in mat.name:
            continue
        prefix = mat.name.replace("Mtl", "")
        tex_path = folder / f"{prefix}_diff.png"
        baked = folder / f"{prefix}_diff_baked.png"
        if baked.is_file():
            tex_path = baked
        if not tex_path.is_file():
            continue
        mat.use_nodes = True
        nodes = mat.node_tree.nodes
        links = mat.node_tree.links
        nodes.clear()
        output = nodes.new(type="ShaderNodeOutputMaterial")
        bsdf = nodes.new(type="ShaderNodeBsdfPrincipled")
        tex = nodes.new(type="ShaderNodeTexImage")
        tex.image = bpy.data.images.load(str(tex_path), check_existing=True)
        tex.image.alpha_mode = "STRAIGHT"
        tex.interpolation = "Smart"
        tex.extension = "REPEAT"
        links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
        if "Alpha" in tex.outputs and "Alpha" in bsdf.inputs:
            links.new(tex.outputs["Alpha"], bsdf.inputs["Alpha"])
        links.new(bsdf.outputs["BSDF"], output.inputs["Surface"])
        mat.blend_method = "OPAQUE"


def orient_roblox_obj_forward(objects: list[bpy.types.Object]) -> None:
    """Roblox Studio OBJ exports face -Y; rotate so front view matches in-game."""
    for obj in objects:
        obj.rotation_euler.z += math.pi


def uses_imported_obj_materials(mesh_path: Path, explicit_texture: Path | None) -> bool:
    if explicit_texture is not None:
        return False
    if mesh_path.suffix.lower() != ".obj":
        return False
    mtl_candidates = (
        mesh_path.with_suffix(".mtl"),
        mesh_path.parent / f"{mesh_path.stem}.mtl",
    )
    return any(path.is_file() for path in mtl_candidates)


def render_preview(
    mesh_path: Path,
    output_path: Path,
    *,
    texture_path: Path | None,
    size: int,
    padding: float,
    elevation: float,
    azimuth: float,
) -> None:
    clear_scene()
    objects = import_mesh(mesh_path)
    explicit = Path(texture_path).expanduser().resolve() if texture_path else None
    if uses_imported_obj_materials(mesh_path, explicit):
        print(f"Using OBJ/MTL materials from {mesh_path.parent.name}/")
        strip_roblox_outline_faces(objects)
        if is_bear_homeworld_export(mesh_path):
            remap_homeworld_face_uvs(objects)
        fix_obj_mtl_materials(mesh_path)
        orient_roblox_obj_forward(objects)
    else:
        texture = find_texture(mesh_path, str(explicit) if explicit else None)
        if texture is None:
            print(f"Warning: no texture found for {mesh_path}; rendering untextured.")
        else:
            for obj in objects:
                ensure_material_with_texture(obj, texture)

    _, radius = center_objects(objects)
    setup_camera(radius, padding, elevation, azimuth)
    setup_lights(radius)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    configure_render(output_path, size)
    bpy.ops.render.render(write_still=True)
    print(f"Rendered {output_path} ({size}x{size}) from {mesh_path.name}")


def main() -> None:
    args = parse_args()
    render_preview(
        Path(args.input).expanduser().resolve(),
        Path(args.output).expanduser().resolve(),
        texture_path=Path(args.texture).expanduser().resolve() if args.texture else None,
        size=args.size,
        padding=args.padding,
        elevation=args.elevation,
        azimuth=args.azimuth,
    )


if __name__ == "__main__":
    main()
