"""Blender: normalize an HH source pet and export its actual rig/clip as a portable GLB."""
import argparse
import sys
from pathlib import Path
import bpy
from mathutils import Vector

parser = argparse.ArgumentParser()
parser.add_argument("source")
parser.add_argument("output")
parser.add_argument("--height", type=float, default=1.1)
args = parser.parse_args(sys.argv[sys.argv.index("--") + 1:])
source = Path(args.source)
if source.suffix == ".blend":
    bpy.ops.wm.open_mainfile(filepath=str(source))
else:
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    bpy.ops.import_scene.gltf(filepath=str(source))
objects = [o for o in bpy.context.scene.objects if o.type in {"MESH", "ARMATURE", "EMPTY"}]
meshes = [o for o in objects if o.type == "MESH"]
points = [o.matrix_world @ Vector(v) for o in meshes for v in o.bound_box]
lo = Vector(tuple(min(p[i] for p in points) for i in range(3)))
hi = Vector(tuple(max(p[i] for p in points) for i in range(3)))
scale = args.height / (hi.z - lo.z)
root = bpy.data.objects.new("HH_Port_Normalization", None)
bpy.context.collection.objects.link(root)
for o in objects:
    if not o.parent or o.parent not in objects:
        matrix = o.matrix_world.copy()
        o.parent = root
        o.matrix_world = matrix
root.scale = (scale, scale, scale)
root.location = (-scale * (lo.x + hi.x) / 2, -scale * (lo.y + hi.y) / 2, -scale * lo.z)
# Canonical HH Blender quadrupeds face -Y; glTF forward is -Z (+Y in Blender).
if source.suffix == ".blend":
    root.rotation_euler.z = 3.141592653589793
bpy.ops.object.select_all(action="DESELECT")
for o in objects + [root]:
    o.select_set(True)
for o in objects:
    if o.type == "ARMATURE" and o.animation_data and o.animation_data.action:
        o.animation_data.action.name = "Attack"
# Unconnected white emission in the source Blender files is a viewport artifact.
# Preserve a real emission texture; otherwise export the lit albedo.
for material in bpy.data.materials:
    if material.use_nodes:
        for node in material.node_tree.nodes:
            if node.type == 'BSDF_PRINCIPLED' and not node.inputs['Emission Color'].is_linked:
                node.inputs['Emission Strength'].default_value = 0
Path(args.output).parent.mkdir(parents=True, exist_ok=True)
bpy.ops.export_scene.gltf(filepath=args.output, export_format="GLB", use_selection=True,
                          export_animations=True, export_apply=False)
print("HH_EXPORT", args.output, "height", args.height, "scale", scale)
