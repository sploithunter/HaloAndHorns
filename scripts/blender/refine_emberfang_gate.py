"""Add crisp architectural accents to the cleaned Meshi Emberfang gate.

The source-derived rebuild supplies the intricate silhouette. This pass overlays
the deliberately straight, readable shapes that the concept depends on: tower
plaques and ribs, layered ledges, a double arch band, and a strong central crest.
"""

from __future__ import annotations

import argparse
import importlib.util
import json
import sys
from pathlib import Path

import bpy
from mathutils import Vector


def parse_args() -> argparse.Namespace:
    argv = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", required=True)
    parser.add_argument("--output-dir", required=True)
    return parser.parse_args(argv)


def load_module(name: str, filename: str):
    path = Path(__file__).with_name(filename)
    spec = importlib.util.spec_from_file_location(name, path)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"Unable to load {path}")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def material(name: str, color, metallic: float, roughness: float, emission=None):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (*color, 1.0)
    bsdf.inputs["Metallic"].default_value = metallic
    bsdf.inputs["Roughness"].default_value = roughness
    if emission:
        bsdf.inputs["Emission Color"].default_value = (*emission[0], 1.0)
        bsdf.inputs["Emission Strength"].default_value = emission[1]
    return mat


def add_box(helpers, collection, name, center, size, mat, bevel=0.025):
    return helpers.add_box(collection, name, center, size, mat, bevel_width=bevel)


def add_pointed_frame(gate, helpers, collection, name, x, z, width, height, y, outer_mat, inner_mat):
    # The donor already supplies the inset surface. Only add a crisp frame so
    # its texture and sculptural irregularity remain visible.
    low = z - height * 0.5
    shoulder = z + height * 0.22
    apex = z + height * 0.5
    points = [
        (x - width * 0.5, low),
        (x - width * 0.5, shoulder),
        (x, apex),
        (x + width * 0.5, shoulder),
        (x + width * 0.5, low),
    ]
    gate.add_segmented_arch(helpers, collection, name + "_Frame", points, y - 0.11, 0.105, 0.10, outer_mat, 0.012)
    add_box(helpers, collection, name + "_FrameBottom", (x, y - 0.11, low), (width, 0.10, 0.105), outer_mat, 0.012)
    return None


def main() -> None:
    args = parse_args()
    input_path = Path(args.input).expanduser().resolve()
    output_dir = Path(args.output_dir).expanduser().resolve()
    output_dir.mkdir(parents=True, exist_ok=True)

    gate = load_module("emberfang_gate_builder", "build_emberfang_gate.py")
    render = load_module("emberfang_gate_rebuild", "rebuild_emberfang_from_meshy.py")
    helpers = gate.load_citadel_helpers()
    helpers.clear_scene()
    bpy.ops.import_scene.gltf(filepath=str(input_path))
    target = next(obj for obj in bpy.context.scene.objects if obj.type == "MESH")
    target.name = "EmberfangGate_SourceDerived"

    accents = bpy.data.collections.new("Crisp_Architectural_Accents")
    bpy.context.scene.collection.children.link(accents)
    iron = material("Obsidian Iron", (0.018, 0.022, 0.028), 0.58, 0.28)
    stone = material("Charcoal Stone", (0.045, 0.052, 0.062), 0.12, 0.58)
    bronze = material("Ember Bronze", (0.24, 0.075, 0.020), 0.72, 0.24)
    crimson = material("Crimson Enamel", (0.19, 0.010, 0.008), 0.18, 0.34)
    ember = material("Ember Glow", (0.36, 0.018, 0.003), 0.05, 0.24, ((1.0, 0.055, 0.004), 4.0))

    arch_y = -2.81
    # A crisp, layered Gothic arch on top of the preserved sculptural body.
    arch_points = [
        (-3.22, 2.10),
        (-3.18, 3.35),
        (-3.05, 4.55),
        (-2.72, 5.60),
        (-2.15, 6.46),
        (-1.36, 7.08),
        (0.0, 7.78),
        (1.36, 7.08),
        (2.15, 6.46),
        (2.72, 5.60),
        (3.05, 4.55),
        (3.18, 3.35),
        (3.22, 2.10),
    ]
    gate.add_segmented_arch(helpers, accents, "OuterArch", arch_points, arch_y - 0.01, 0.25, 0.20, iron, 0.025)
    gate.add_segmented_arch(helpers, accents, "EmberArch", arch_points, arch_y - 0.13, 0.055, 0.05, ember, 0.008)

    gate.add_hanging_finial(helpers, accents, "ArchKeystone", 0.0, arch_y - 0.15, 7.90, 1.14, 0.34, iron)

    # Apply bevels before joining, retaining a single selectable Roblox asset.
    overlay_objects = [obj for obj in accents.objects if obj.type == "MESH"]
    for obj in overlay_objects:
        bpy.context.view_layer.objects.active = obj
        obj.select_set(True)
        bpy.ops.object.convert(target="MESH")
        obj.select_set(False)

    bpy.ops.object.select_all(action="DESELECT")
    target.select_set(True)
    for obj in overlay_objects:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = target
    bpy.ops.object.join()
    target.name = "EmberfangGate_HybridRefined"

    glb_path = output_dir / "emberfang_gate_refined.glb"
    bpy.ops.object.select_all(action="DESELECT")
    target.select_set(True)
    bpy.context.view_layer.objects.active = target
    bpy.ops.export_scene.gltf(filepath=str(glb_path), export_format="GLB", use_selection=True, export_apply=True, export_yup=True)

    front_path = output_dir / "emberfang_gate_front.png"
    three_quarter_path = output_dir / "emberfang_gate_three_quarter.png"
    render.render_preview(target, front_path, azimuth=0.0)
    render.render_preview(target, three_quarter_path, azimuth=34.0)
    blend_path = output_dir / "emberfang_gate_refined.blend"
    bpy.ops.wm.save_as_mainfile(filepath=str(blend_path))

    target.data.calc_loop_triangles()
    report = {
        "input": str(input_path),
        "triangles": len(target.data.loop_triangles),
        "glb": str(glb_path),
        "blend": str(blend_path),
        "previews": [str(front_path), str(three_quarter_path)],
    }
    (output_dir / "emberfang_gate_report.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print("EMBERFANG_REFINEMENT_REPORT=" + json.dumps(report))


if __name__ == "__main__":
    main()
