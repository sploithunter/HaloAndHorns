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


def decimate_to_target(obj: bpy.types.Object, target_faces: int, tolerance: float) -> int:
    current = face_count(obj)
    if current <= target_faces:
        print(f"  already at {current} tris (target {target_faces}); skipping decimation")
        return current

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
            return current
        if current <= 0:
            raise RuntimeError("Decimation collapsed mesh to zero faces")

        ratio *= target_faces / current

    return current


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

    for line in (folder / f"{stem}.mtl").read_text(encoding="utf-8", errors="ignore").splitlines():
        if line.lower().startswith("map_kd"):
            texture_name = line.split(maxsplit=1)[1].strip()
            candidate = folder / texture_name
            if candidate.exists():
                return candidate

    images = sorted(
        p
        for p in folder.iterdir()
        if p.is_file() and p.suffix.lower() in {".png", ".jpg", ".jpeg", ".webp"}
    )
    return images[0] if images else None


def slugify(name: str) -> str:
    slug = re.sub(r"[^A-Za-z0-9._-]+", "_", name).strip("_")
    return slug or "mesh"


def export_fbx(obj: bpy.types.Object, output_path: Path) -> None:
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj

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
    entries: list[dict[str, int | str]],
) -> None:
    lines = [
        f"source: {source_mesh}",
        f"original_tris: {entries[0]['original_tris'] if entries else 'unknown'}",
        "",
    ]
    for entry in entries:
        lines.append(
            f"{entry['label']}: {entry['path']} ({entry['tris']} tris, target {entry['target']})"
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

    texture_path = find_texture_path(source_mesh)
    texture_copy_name = None
    if texture_path:
        texture_copy_name = f"{base_name}{texture_path.suffix.lower()}"
        shutil.copy2(texture_path, output_dir / texture_copy_name)
        print(f"Copied texture: {texture_path.name} -> {texture_copy_name}")
    else:
        print("Warning: no texture image found next to source mesh.")

    print(f"Source: {source_mesh}")
    print(f"Original triangle count: {original_tris}")
    print(f"Output directory: {output_dir}")

    manifest_entries: list[dict[str, int | str]] = []
    for target in targets:
        label = f"{target // 1000}k" if target % 1000 == 0 else f"{target}tris"
        export_name = f"{base_name}_{label}.fbx"
        export_path = output_dir / export_name

        print(f"\nBuilding {export_name} (target {target} tris)...")
        work_obj = duplicate_object(base_obj)
        final_tris = decimate_to_target(work_obj, target, args.tolerance)
        export_fbx(work_obj, export_path)

        manifest_entries.append(
            {
                "label": label,
                "path": export_name,
                "target": target,
                "tris": final_tris,
                "original_tris": original_tris,
            }
        )
        print(f"  exported {export_path.name}: {final_tris} tris")

        bpy.data.objects.remove(work_obj, do_unlink=True)

    write_manifest(output_dir, source_mesh, manifest_entries)
    print("\nDone.")


if __name__ == "__main__":
    main()
