"""Ground truth for the Meshy doggy walk: render the GLB's own animation in
Blender (true side view) and dump per-frame world positions of head/hips/feet.
"""
import bpy, json, math, os
import mathutils as mu

SCRATCH = "/private/tmp/claude-501/-Users-jason-Documents-HaloAndHorns/35c99d45-e986-4baa-9686-67954732ee42/scratchpad"
GLB = "/Users/jason/Downloads/Meshy_AI_model_Animation_Walking_withSkin.glb"

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=GLB)
arm = next(o for o in bpy.data.objects if o.type == "ARMATURE")
for o in list(bpy.data.objects):
    if o.type == "MESH" and not o.vertex_groups:
        bpy.data.objects.remove(o, do_unlink=True)
mesh = next(o for o in bpy.data.objects if o.type == "MESH")

# normalize to pet size
bpy.context.view_layer.update()
cs = [mesh.matrix_world @ v.co for v in mesh.data.vertices]
h0 = max(c.z for c in cs) - min(c.z for c in cs)
arm.scale = tuple(s * (1.62 / h0) for s in arm.scale)
bpy.context.view_layer.update()

act = next(a for a in bpy.data.actions)
ad = arm.animation_data or arm.animation_data_create()
ad.action = act
if hasattr(ad, "action_slot") and getattr(act, "slots", None) and len(act.slots):
    ad.action_slot = act.slots[0]
f0, f1 = (int(v) for v in act.frame_range)

scene = bpy.context.scene
scene.frame_start = f0
scene.frame_end = f1
scene.render.fps = 24

# ---- positional trace ----
TRACK = ["head", "Hips", "frontleg1", "R_frontleg1", "backleg2", "R_backleg2",
         "frontleg2", "R_frontleg2"]
trace = []
for f in range(f0, f1 + 1):
    scene.frame_set(f)
    dg = bpy.context.evaluated_depsgraph_get()
    arm_ev = arm.evaluated_get(dg)
    row = {"frame": f}
    for bname in TRACK:
        pb = arm_ev.pose.bones.get(bname)
        if pb:
            wp = arm_ev.matrix_world @ pb.head
            row[bname] = [round(wp.x, 4), round(wp.y, 4), round(wp.z, 4)]
    trace.append(row)
with open(os.path.join(SCRATCH, "meshy_walk_truth.json"), "w") as fjson:
    json.dump(trace, fjson)
print("TRACE_WRITTEN", len(trace), "frames")

# ---- true side-view render ----
scene.render.engine = "BLENDER_EEVEE"
w = bpy.data.worlds.new("W"); w.use_nodes = True
w.node_tree.nodes["Background"].inputs[0].default_value = (0.6, 0.65, 0.7, 1)
w.node_tree.nodes["Background"].inputs[1].default_value = 0.8
scene.world = w
sun = bpy.data.objects.new("Sun", bpy.data.lights.new("Sun", "SUN"))
sun.data.energy = 3.0
sun.rotation_euler = (math.radians(60), 0, math.radians(-20))
scene.collection.objects.link(sun)
cs = [mesh.matrix_world @ v.co for v in mesh.data.vertices]
min_z = min(c.z for c in cs); max_z = max(c.z for c in cs)
min_y = min(c.y for c in cs); max_y = max(c.y for c in cs)
center = mu.Vector((0, (min_y + max_y) / 2, (min_z + max_z) / 2))
cam_data = bpy.data.cameras.new("Cam")
cam_data.type = "ORTHO"
cam_data.ortho_scale = (max_z - min_z) * 2.2
cam = bpy.data.objects.new("Cam", cam_data)
scene.collection.objects.link(cam)
scene.camera = cam
cam.location = center + mu.Vector((6, 0, 0))  # pure +X side view, head pointing left (-Y)
cam.rotation_euler = (center - cam.location).to_track_quat("-Z", "Y").to_euler()
scene.render.resolution_x = 720
scene.render.resolution_y = 720
scene.render.image_settings.file_format = "PNG"
d = os.path.join(SCRATCH, "truth_frames")
os.makedirs(d, exist_ok=True)
scene.render.filepath = os.path.join(d, "f_")
bpy.ops.render.render(animation=True)
print("FRAMES", d)
