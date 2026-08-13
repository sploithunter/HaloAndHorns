"""Retarget a Quaternius AnimalArmature clip onto the canonical quadruped rig.

Usage: blender --background --python retarget_clip.py -- <pet_blend> <source_fbx> <clip_name> <out_prefix>
Copies rest-relative local rotations (matrix_basis) per mapped bone pair per
frame, plus height-scaled root motion from the Body bone.
"""
import bpy, math, os, sys
import mathutils as mu

SCRATCH = "/private/tmp/claude-501/-Users-jason-Documents-HaloAndHorns/35c99d45-e986-4baa-9686-67954732ee42/scratchpad"
argv = sys.argv[sys.argv.index("--") + 1:]
PET_BLEND, SRC_FBX, CLIP, OUT = argv[0], argv[1], argv[2], argv[3]

# canonical bone <- Quaternius bone (rotations); chains compressed
MAP = {
    "Spine1":      "Torso2",
    "Chest":       "Torso3",
    "Neck":        "Neck2",
    "Head":        "Head",
    "Tail1":       "Tail2",
    "Tail2":       "Tail5",
    "UpperLeg_FL": "FrontUpperLeg.L",
    "LowerLeg_FL": "FrontLowerLeg.L",
    "UpperLeg_FR": "FrontUpperLeg.R",
    "LowerLeg_FR": "FrontLowerLeg.R",
    "UpperLeg_HL": "BackLeg.L",
    "LowerLeg_HL": "BackUpperLeg.L",
    "Foot_HL":     "BackLowerLeg.L",
    "UpperLeg_HR": "BackLeg.R",
    "LowerLeg_HR": "BackUpperLeg.R",
    "Foot_HR":     "BackLowerLeg.R",
    # extra neck rotation folded into Root so the whole front lifts a little
    "Root":        "Torso",
}

bpy.ops.wm.open_mainfile(filepath=os.path.join(SCRATCH, PET_BLEND))
arm = bpy.data.objects["QuadrupedRig"]
mesh_obj = bpy.data.objects["PetMesh"]

# wipe the old clip
if arm.animation_data:
    arm.animation_data_clear()
for pb in arm.pose.bones:
    pb.rotation_mode = "QUATERNION"
    pb.rotation_quaternion = (1, 0, 0, 0)
arm.location = (0, 0, 0)

pre = set(bpy.data.objects)
bpy.ops.import_scene.fbx(filepath=SRC_FBX)
new_objs = [o for o in bpy.data.objects if o not in pre]
src = next(o for o in new_objs if o.type == "ARMATURE")

act = next(a for a in bpy.data.actions if a.name.endswith("|" + CLIP))
src.animation_data_create().action = act
if hasattr(src.animation_data, "action_slot") and getattr(act, "slots", None) and len(act.slots):
    src.animation_data.action_slot = act.slots[0]
f0, f1 = (int(v) for v in act.frame_range)
print("CLIP", act.name, f0, f1)

# height scale for root motion
def obj_height(o):
    zs = [(o.matrix_world @ v.co).z for v in o.data.vertices]
    return max(zs) - min(zs)
src_mesh = next((o for o in new_objs if o.type == "MESH"), None)
scale = (obj_height(mesh_obj) / obj_height(src_mesh)) if src_mesh else 1.0
print("ROOT_SCALE", round(scale, 3))

scene = bpy.context.scene
scene.frame_start = f0
scene.frame_end = f1

for f in range(f0, f1 + 1):
    scene.frame_set(f)
    # verify source pose actually evaluates (Blender 5 slotted-action guard)
    for tgt_name, src_name in MAP.items():
        spb = src.pose.bones.get(src_name)
        tpb = arm.pose.bones.get(tgt_name)
        if spb is None or tpb is None:
            continue
        q = spb.matrix_basis.to_quaternion()
        tpb.rotation_quaternion = q
        tpb.keyframe_insert("rotation_quaternion", frame=f)
    body = src.pose.bones.get("Body")
    if body is not None:
        loc = body.matrix_basis.to_translation() * scale
        # Body bone points up (+Z along bone Y); map bone-local (x,y,z)->(x,z,y)
        arm.location = (loc.x, -loc.y if abs(loc.y) > abs(loc.z) else -loc.z, max(loc.z, loc.y))
        arm.location = (loc.x, loc.y, loc.z)
        arm.keyframe_insert("location", frame=f)

# sanity: did the source clip actually move?
scene.frame_set(f0 + (f1 - f0) // 2)
mid = src.pose.bones["Head"].matrix_basis.to_quaternion()
print("SRC_HEAD_MID_ROT", [round(v, 3) for v in mid])

# remove source objects
for o in new_objs:
    bpy.data.objects.remove(o, do_unlink=True)

bpy.ops.wm.save_as_mainfile(filepath=os.path.join(SCRATCH, f"{OUT}.blend"))

# render
scene.render.engine = "BLENDER_EEVEE"
world = bpy.data.worlds.new("W")
world.use_nodes = True
world.node_tree.nodes["Background"].inputs[0].default_value = (0.55, 0.65, 0.75, 1)
world.node_tree.nodes["Background"].inputs[1].default_value = 0.7
scene.world = world
sun = bpy.data.objects.new("Sun", bpy.data.lights.new("Sun", "SUN"))
sun.data.energy = 3.0
sun.rotation_euler = (math.radians(50), 0, math.radians(-30))
scene.collection.objects.link(sun)
verts = [mesh_obj.matrix_world @ v.co for v in mesh_obj.data.vertices]
min_z = min(v.z for v in verts); max_z = max(v.z for v in verts)
min_y = min(v.y for v in verts); max_y = max(v.y for v in verts)
H = max_z - min_z
bpy.ops.mesh.primitive_plane_add(size=30, location=(0, 0, min_z - 0.01))
g = bpy.context.active_object
gm = bpy.data.materials.new("Ground")
gm.use_nodes = True
gm.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.35, 0.5, 0.3, 1)
g.data.materials.append(gm)
cam = bpy.data.objects.new("Cam2", bpy.data.cameras.new("Cam2"))
scene.collection.objects.link(cam)
scene.camera = cam
center = mu.Vector((0, (min_y + max_y) / 2 - 0.3, min_z + 0.45 * H))
cam.location = center + mu.Vector((1.0, -0.75, 0.28)).normalized() * max(H, max_y - min_y) * 2.6
cam.rotation_euler = (center - cam.location).to_track_quat("-Z", "Y").to_euler()
scene.render.resolution_x = 720
scene.render.resolution_y = 720
scene.render.fps = 24
scene.render.image_settings.file_format = "PNG"
frames_dir = os.path.join(SCRATCH, f"{OUT}_frames")
os.makedirs(frames_dir, exist_ok=True)
scene.render.filepath = os.path.join(frames_dir, "f_")
bpy.ops.render.render(animation=True)
print("FRAMES", frames_dir)
