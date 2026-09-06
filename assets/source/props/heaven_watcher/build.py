"""Asset-local preview/export companion; reuse canonical UV seam and FBX helpers.

blender --background --python assets/source/props/heaven_watcher/build.py -- input.glb output_dir
"""
import json
import math
import sys
from pathlib import Path

import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[4]
sys.path.insert(0, str(ROOT / "scripts/blender"))
from rebake_for_roblox import export_fbx, split_uv_seams

args = sys.argv[sys.argv.index("--") + 1 :]
source, output = Path(args[0]).resolve(), Path(args[1]).resolve()
output.mkdir(parents=True, exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(source))
meshes = [obj for obj in bpy.context.scene.objects if obj.type == "MESH"]
bpy.ops.object.select_all(action="DESELECT")
for obj in meshes:
    obj.select_set(True)
bpy.context.view_layer.objects.active = meshes[0]
if len(meshes) > 1:
    bpy.ops.object.join()
head = bpy.context.object
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
corners = [Vector(corner) for corner in head.bound_box]
low = Vector(tuple(min(v[i] for v in corners) for i in range(3)))
high = Vector(tuple(max(v[i] for v in corners) for i in range(3)))
center = (low + high) / 2
for vertex in head.data.vertices:
    vertex.co -= center
head.name = head.data.name = "HeavenFace"
head.data.update()

# Imported Meshy glTF faces Blender -Y, which the canonical FBX conversion maps
# to Roblox -Z. Keep geometry unrotated; confirm using cardinal and Studio views.
images = []
for material in head.data.materials:
    if material and material.use_nodes:
        for node in material.node_tree.nodes:
            if node.type == "TEX_IMAGE" and node.image:
                image = node.image
                if image.name not in images:
                    images.append(image.name)
                    image.filepath_raw = str(output / (image.name.split(".")[0] + ".png"))
                    image.file_format = "PNG"
                    image.save()

seams = split_uv_seams(head) if head.data.uv_layers else 0
uvs_by_vertex = {}
if head.data.uv_layers:
    for loop in head.data.loops:
        uv = head.data.uv_layers.active.data[loop.index].uv
        uvs_by_vertex.setdefault(loop.vertex_index, set()).add(tuple(round(v, 6) for v in uv))
uv_conflicts = sum(len(uvs) > 1 for uvs in uvs_by_vertex.values())
if uv_conflicts:
    raise RuntimeError(f"UV-safe export failed: {uv_conflicts} vertices have multiple UVs")
head.data.calc_loop_triangles()
report = {"source": str(source), "triangles": len(head.data.loop_triangles),
          "vertices": len(head.data.vertices), "size_blender": list(head.dimensions),
          "front_blender": "-Y", "front_roblox_expected": "-Z",
          "pivot": "bounds center", "uv_seam_edges_split": seams,
          "vertices_with_multiple_uvs": uv_conflicts, "images": images,
          "texture_sizes": {img.name: list(img.size) for img in bpy.data.images if img.name in images}}
export_fbx(head, output / "HeavenFace.fbx")
bpy.ops.export_scene.gltf(filepath=str(output / "HeavenFace.glb"), export_format="GLB", use_selection=True)
bpy.ops.wm.save_as_mainfile(filepath=str(output / "HeavenFace.blend"))
(output / "build.json").write_text(json.dumps(report, indent=2) + "\n")

scene = bpy.context.scene
scene.render.engine = "CYCLES"
scene.cycles.samples = 24
scene.render.resolution_x = scene.render.resolution_y = 768
scene.render.resolution_percentage = 100
scene.render.film_transparent = False
scene.world = bpy.data.worlds.new("ReviewWorld")
scene.world.use_nodes = True
scene.world.node_tree.nodes["Background"].inputs[0].default_value = (.15, .18, .23, 1)
scene.world.node_tree.nodes["Background"].inputs[1].default_value = .6
radius = max(head.dimensions)
for name, location, energy in [("Key", (2,-3,3), 90), ("Fill", (-3,-2,1), 40), ("Back", (0,3,2), 70)]:
    data = bpy.data.lights.new(name, "AREA")
    data.energy, data.size = energy * radius * radius, radius * 2
    obj = bpy.data.objects.new(name, data)
    scene.collection.objects.link(obj)
    obj.location = Vector(location) * radius
    obj.rotation_euler = (-obj.location).to_track_quat("-Z", "Y").to_euler()
cam = bpy.data.objects.new("ReviewCamera", bpy.data.cameras.new("ReviewCamera"))
scene.collection.objects.link(cam)
scene.camera = cam
cam.data.type = "ORTHO"
cam.data.ortho_scale = radius * 1.2
for name, angle in [("front", 0), ("right",90), ("back",180), ("left",270)]:
    az = math.radians(angle)
    cam.location = Vector((math.sin(az), -math.cos(az), 0)) * radius * 3
    cam.rotation_euler = (-cam.location).to_track_quat("-Z", "Y").to_euler()
    scene.render.filepath = str(output / ("preview_" + name + ".png"))
    bpy.ops.render.render(write_still=True)
print(json.dumps(report, indent=2))
