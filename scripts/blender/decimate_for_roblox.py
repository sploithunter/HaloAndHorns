"""Decimate a mesh to Roblox-friendly triangle budgets and export FBX + texture.

Invoked headless by scripts/decimate_mesh.sh:

  blender --background --python decimate_for_roblox.py -- \\
    --input /path/to/model.obj \\
    --output /path/to/out_dir \\
    --targets 3000,5000,7500,10000
"""

from __future__ import annotations

import argparse
import re
import shutil
import sys
from pathlib import Path

import bpy

DEFAULT_TARGETS = (3000, 5000, 7500, 10000)
SUPPORTED_IMPORT_SUFFIXES = {".obj", ".fbx", ".glb", ".gltf"}


def parse_args() -> argparse.Namespace:
    argv = sys.argv
    if "--" in argv:
        argv = argv[argv.index("--") + 1 :]
    else:
        argv = []

    parser = argparse.ArgumentParser(description="Decimate meshes for Roblox import.")
    parser.add_argument("--input", required=True, help="OBJ/FBX/GLB file or folder containing one.")
    parser.add_argument("--output", required=True, help="Directory for decimated exports.")
    parser.add_argument(
        "--targets",
        default=",".join(str(t) for t in DEFAULT_TARGETS),
        help="Comma-separated triangle targets (default: 3000,5000,7500,10000).",
    )
    parser.add_argument(
        "--tolerance",
        type=float,
        default=0.03,
        help="Allowed relative face-count error after decimation (default: 0.03).",
    )
    parser.add_argument(
        "--scene-parts",
        type=int,
        default=1,
        help=(
            "Export the scene as this many spatial MeshParts, applying each triangle target per "
            "part. Use 4 for a four-part landmark (4 x 10k, not one 10k scene)."
        ),
    )
    return parser.parse_args(argv)


def resolve_input_path(raw: str) -> Path:
    path = Path(raw).expanduser().resolve()
    if not path.exists():
        raise FileNotFoundError(f"Input not found: {path}")

    if path.is_file():
        if path.suffix.lower() not in SUPPORTED_IMPORT_SUFFIXES:
            raise ValueError(f"Unsupported mesh format: {path.suffix}")
        return path

    candidates = sorted(
        p
        for p in path.iterdir()
        if p.is_file() and p.suffix.lower() in SUPPORTED_IMPORT_SUFFIXES
    )
    if not candidates:
        raise FileNotFoundError(f"No mesh file found in directory: {path}")
    if len(candidates) > 1:
        print(f"Multiple meshes in {path}; using {candidates[0].name}")
    return candidates[0]


def clear_scene() -> None:
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for block in (
        bpy.data.meshes,
        bpy.data.materials,
        bpy.data.images,
        bpy.data.armatures,
    ):
        for item in list(block):
            if item.users == 0:
                block.remove(item)


def import_mesh(path: Path) -> bpy.types.Object:
    suffix = path.suffix.lower()
    if suffix == ".obj":
        bpy.ops.wm.obj_import(filepath=str(path))
    elif suffix == ".fbx":
        bpy.ops.import_scene.fbx(filepath=str(path))
    elif suffix in {".glb", ".gltf"}:
        bpy.ops.import_scene.gltf(filepath=str(path))
    else:
        raise ValueError(f"Unsupported import format: {suffix}")

    meshes = [obj for obj in bpy.context.selected_objects if obj.type == "MESH"]
    if not meshes:
        raise RuntimeError(f"No mesh objects imported from {path}")

    if len(meshes) == 1:
        return meshes[0]

    bpy.ops.object.select_all(action="DESELECT")
    for obj in meshes:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = meshes[0]
    bpy.ops.object.join()
    return bpy.context.active_object


def weld_and_clean(obj: bpy.types.Object) -> None:
    """Shatter-incident guard (docs: blender-roblox prop pipeline): Meshy
    high-poly meshes ship with split vertices everywhere; naive collapse on
    them produces island confetti + degenerate tris that Roblox's server-side
    mesh processor mangles into shards. Weld BEFORE decimating."""
    import bmesh

    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=0.0004)
    bm.to_mesh(obj.data)
    bm.free()
    obj.data.validate()


def dissolve_degenerate(obj: bpy.types.Object) -> None:
    """Post-decimate cleanup: zero-area faces / zero-length edges out,
    loose verts gone, then validate — the other half of the shatter guard."""
    import bmesh

    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bmesh.ops.dissolve_degenerate(bm, edges=bm.edges, dist=1e-5)
    loose = [v for v in bm.verts if not v.link_faces]
    if loose:
        bmesh.ops.delete(bm, geom=loose, context="VERTS")
    bm.to_mesh(obj.data)
    bm.free()
    obj.data.validate()


def face_count(obj: bpy.types.Object) -> int:
    mesh = obj.data
    mesh.calc_loop_triangles()
    return len(mesh.loop_triangles)


def duplicate_object(obj: bpy.types.Object) -> bpy.types.Object:
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.duplicate()
    dup = bpy.context.active_object
    dup.name = f"{obj.name}_decimated"
    return dup


def split_spatial_parts(obj: bpy.types.Object, part_count: int) -> list[bpy.types.Object]:
    """Partition a decimated scene into balanced spatial chunks without dropping faces.

    Meshy often exports an architectural scene as one material/primitive even though Roblox must
    store it as several MeshParts. We first decimate the WHOLE scene to `parts * target` so detail
    is allocated globally, then split every triangle into one spatially coherent <=target chunk.
    """
    import bmesh

    if part_count <= 1:
        return [obj]

    # Make polygon count equal triangle count before balancing the chunks.
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bmesh.ops.triangulate(bm, faces=list(bm.faces))
    bm.to_mesh(obj.data)
    bm.free()
    obj.data.update()

    polygons = list(obj.data.polygons)
    if len(polygons) < part_count:
        raise RuntimeError(f"Cannot split {len(polygons)} faces into {part_count} scene parts")

    coords = [vertex.co for vertex in obj.data.vertices]
    extents = [
        max(co[axis] for co in coords) - min(co[axis] for co in coords)
        for axis in range(3)
    ]
    axis_order = sorted(range(3), key=lambda axis: extents[axis], reverse=True)
    polygon_order = sorted(
        range(len(polygons)),
        key=lambda index: tuple(polygons[index].center[axis] for axis in axis_order),
    )

    parts = []
    for part_index in range(part_count):
        start = part_index * len(polygon_order) // part_count
        finish = (part_index + 1) * len(polygon_order) // part_count
        keep = set(polygon_order[start:finish])

        part = duplicate_object(obj)
        part.name = f"{obj.name.rsplit('_part_', 1)[0]}_part_{part_index:02d}"
        part_bm = bmesh.new()
        part_bm.from_mesh(part.data)
        part_bm.faces.ensure_lookup_table()
        remove = [face for index, face in enumerate(part_bm.faces) if index not in keep]
        bmesh.ops.delete(part_bm, geom=remove, context="FACES")
        loose = [vertex for vertex in part_bm.verts if not vertex.link_faces]
        if loose:
            bmesh.ops.delete(part_bm, geom=loose, context="VERTS")
        part_bm.to_mesh(part.data)
        part_bm.free()
        part.data.validate()
        parts.append(part)

    return parts


def decimate_to_target(obj: bpy.types.Object, target_faces: int, tolerance: float) -> int:
    # ALWAYS weld+clean — passthrough meshes shatter too (2026-07-08: the
    # un-decimated diamond altar mangled on Roblox's re-fetch; the processor
    # chokes on split-vert/degenerate geometry regardless of tri count)
    weld_and_clean(obj)
    dissolve_degenerate(obj)
    current = face_count(obj)
    if current <= target_faces:
        print(f"  welded/cleaned -> {current} tris (target {target_faces}); no decimation needed")
        return current
    print(f"  welded split verts -> {current} tris")

    ratio = target_faces / current
    allowed_error = max(25, int(target_faces * tolerance))

    for attempt in range(18):
        modifier = obj.modifiers.new(name="Decimate", type="DECIMATE")
        modifier.decimate_type = "COLLAPSE"
        modifier.use_collapse_triangulate = True
        modifier.ratio = max(0.0001, min(1.0, ratio))
        applied_ratio = modifier.ratio

        bpy.context.view_layer.objects.active = obj
        bpy.ops.object.modifier_apply(modifier="Decimate")

        current = face_count(obj)
        delta = current - target_faces
        print(f"  attempt {attempt + 1}: ratio={applied_ratio:.5f} -> {current} tris")

        if abs(delta) <= allowed_error:
            dissolve_degenerate(obj)
            return face_count(obj)
        if current <= 0:
            raise RuntimeError("Decimation collapsed mesh to zero faces")

        ratio *= target_faces / current

    dissolve_degenerate(obj)
    return face_count(obj)


def find_texture_path(source_mesh: Path) -> Path | None:
    folder = source_mesh.parent
    stem = source_mesh.stem

    for pattern in (
        f"{stem}.png",
        f"{stem}.jpg",
        f"{stem}.jpeg",
        f"{stem}.webp",
    ):
        candidate = folder / pattern
        if candidate.exists():
            return candidate

    mtl = folder / f"{stem}.mtl"
    if mtl.exists():  # OBJ sidecar only — GLB/FBX inputs have no .mtl
        for line in mtl.read_text(encoding="utf-8", errors="ignore").splitlines():
            if line.lower().startswith("map_kd"):
                texture_name = line.split(maxsplit=1)[1].strip()
                candidate = folder / texture_name
                if candidate.exists():
                    return candidate
    return None


def sweep_folder_for_texture(source_mesh: Path) -> Path | None:
    """LAST resort: any image in the source folder. Only sane for a dedicated
    per-model folder (Meshy zip extract) — in a shared folder like ~/Downloads
    this happily grabs an unrelated image, so it ranks below embedded
    extraction and the caller warns loudly."""
    images = sorted(
        p
        for p in source_mesh.parent.iterdir()
        if p.is_file() and p.suffix.lower() in {".png", ".jpg", ".jpeg", ".webp"}
    )
    return images[0] if images else None


def extract_embedded_texture(obj: bpy.types.Object, output_dir: Path, base_name: str) -> str | None:
    """GLB/glTF embed textures instead of shipping loose files — unpack the
    base-color image so the Roblox TextureID upload has a file to point at.
    Prefers the image wired to Principled Base Color; falls back to the first
    image texture node."""
    base_color_img = None
    first_img = None
    for slot in obj.material_slots:
        mat = slot.material
        if not mat or not mat.use_nodes:
            continue
        for node in mat.node_tree.nodes:
            if node.type != "TEX_IMAGE" or not node.image:
                continue
            first_img = first_img or node.image
            for link in mat.node_tree.links:
                if (
                    link.from_node == node
                    and link.to_node.type == "BSDF_PRINCIPLED"
                    and link.to_socket.name == "Base Color"
                ):
                    base_color_img = base_color_img or node.image
    img = base_color_img or first_img
    if img is None:
        return None

    texture_copy_name = f"{base_name}.png"
    out_path = output_dir / texture_copy_name
    img_copy = img.copy()
    try:
        img_copy.filepath_raw = str(out_path)
        img_copy.file_format = "PNG"
        img_copy.save()
    finally:
        bpy.data.images.remove(img_copy)
    return texture_copy_name


def slugify(name: str) -> str:
    slug = re.sub(r"[^A-Za-z0-9._-]+", "_", name).strip("_")
    return slug or "mesh"


def export_fbx(objects: bpy.types.Object | list[bpy.types.Object], output_path: Path) -> None:
    if not isinstance(objects, list):
        objects = [objects]
    bpy.ops.object.select_all(action="DESELECT")
    for obj in objects:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = objects[0]

    output_path.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.export_scene.fbx(
        filepath=str(output_path),
        use_selection=True,
        apply_scale_options="FBX_SCALE_ALL",
        object_types={"MESH"},
        use_mesh_modifiers=True,
        mesh_smooth_type="FACE",
        path_mode="COPY",
        embed_textures=False,
        axis_forward="-Z",
        axis_up="Y",
    )


def write_manifest(
    output_dir: Path,
    source_mesh: Path,
    entries: list[dict[str, int | str | list[int]]],
) -> None:
    lines = [
        f"source: {source_mesh}",
        f"original_tris: {entries[0]['original_tris'] if entries else 'unknown'}",
        "",
    ]
    for entry in entries:
        part_suffix = ""
        if entry.get("part_tris"):
            part_suffix = "; per-part " + ",".join(str(value) for value in entry["part_tris"])
        lines.append(
            f"{entry['label']}: {entry['path']} ({entry['tris']} tris total, "
            f"target {entry['target']} per part{part_suffix})"
        )
    (output_dir / "manifest.txt").write_text("\n".join(lines) + "\n", encoding="utf-8")


def main() -> None:
    args = parse_args()
    source_mesh = resolve_input_path(args.input)
    output_dir = Path(args.output).expanduser().resolve()
    targets = [int(part.strip()) for part in args.targets.split(",") if part.strip()]
    if not targets:
        raise ValueError("Provide at least one triangle target.")

    output_dir.mkdir(parents=True, exist_ok=True)

    clear_scene()
    base_obj = import_mesh(source_mesh)
    original_tris = face_count(base_obj)
    base_name = slugify(source_mesh.stem)

    # GLB/glTF carry their own truth: prefer the EMBEDDED base-color atlas.
    # (2026-07-09 egg incident: a concept-art PNG sharing the mesh's stem
    # shadowed the real atlas and shipped as the texture — dark-blob renders.)
    texture_path = None
    if source_mesh.suffix.lower() not in {".glb", ".gltf"}:
        texture_path = find_texture_path(source_mesh)
    texture_copy_name = None
    if texture_path:
        texture_copy_name = f"{base_name}{texture_path.suffix.lower()}"
        shutil.copy2(texture_path, output_dir / texture_copy_name)
        print(f"Copied texture: {texture_path.name} -> {texture_copy_name}")
    else:
        # GLB/glTF ship textures EMBEDDED, not as sidecar files
        texture_copy_name = extract_embedded_texture(base_obj, output_dir, base_name)
        if texture_copy_name:
            print(f"Unpacked embedded texture -> {texture_copy_name}")
        elif source_mesh.suffix.lower() in {".glb", ".gltf"} and find_texture_path(source_mesh):
            texture_path = find_texture_path(source_mesh)
            texture_copy_name = f"{base_name}{texture_path.suffix.lower()}"
            shutil.copy2(texture_path, output_dir / texture_copy_name)
            print(f"Copied loose texture (no embedded found): {texture_copy_name}")
        else:
            swept = sweep_folder_for_texture(source_mesh)
            if swept:
                texture_copy_name = f"{base_name}{swept.suffix.lower()}"
                shutil.copy2(swept, output_dir / texture_copy_name)
                print(
                    f"WARNING: guessed texture by folder sweep: {swept.name} -> "
                    f"{texture_copy_name} — VERIFY this is the right image!"
                )
            else:
                print("Warning: no texture image found (loose, embedded, or in folder).")

    print(f"Source: {source_mesh}")
    print(f"Original triangle count: {original_tris}")
    print(f"Output directory: {output_dir}")

    if args.scene_parts < 1:
        raise ValueError("--scene-parts must be at least 1")

    manifest_entries: list[dict[str, int | str | list[int]]] = []
    for target in targets:
        label = f"{target // 1000}k" if target % 1000 == 0 else f"{target}tris"
        if args.scene_parts > 1:
            export_name = f"{base_name}_{args.scene_parts}x{label}.fbx"
        else:
            export_name = f"{base_name}_{label}.fbx"
        export_path = output_dir / export_name

        print(f"\nBuilding {export_name} (target {target} tris per part)...")
        scene = duplicate_object(base_obj)
        scene.name = base_name
        decimate_to_target(scene, target * args.scene_parts, args.tolerance)
        work_parts = split_spatial_parts(scene, args.scene_parts)
        if work_parts[0] is not scene:
            bpy.data.objects.remove(scene, do_unlink=True)
        part_tris = [face_count(part) for part in work_parts]
        if any(count > target for count in part_tris):
            raise RuntimeError(f"Scene split exceeded {target} tris in a part: {part_tris}")
        final_tris = sum(part_tris)
        export_fbx(work_parts, export_path)

        manifest_entries.append(
            {
                "label": label,
                "path": export_name,
                "target": target,
                "tris": final_tris,
                "original_tris": original_tris,
                "part_tris": part_tris,
            }
        )
        print(f"  exported {export_path.name}: {final_tris} tris ({part_tris})")

        for work_part in work_parts:
            bpy.data.objects.remove(work_part, do_unlink=True)

    write_manifest(output_dir, source_mesh, manifest_entries)
    print("\nDone.")


if __name__ == "__main__":
    main()
