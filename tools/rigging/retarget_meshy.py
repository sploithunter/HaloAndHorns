"""Retarget a Quaternius clip onto the Meshy-rigged doggy via world-space
rotation deltas: q_target_world = (q_src_pose_world @ q_src_rest_world^-1) @ q_tgt_rest_world.
Renders the original Meshy walk first, then the retargeted clip.
"""
import bpy, math, os, sys
import mathutils as mu

SCRATCH = "/private/tmp/claude-501/-Users-jason-Documents-HaloAndHorns/35c99d45-e986-4baa-9686-67954732ee42/scratchpad"
MESHY_GLB = "/Users/jason/Downloads/Meshy_AI_model_Animation_Walking_withSkin.glb"
WOLF_FBX = os.path.join(SCRATCH, "quaternius_animals/FBX/Wolf.fbx")
CLIP = "Attack"

# Meshy bone <- Quaternius bone (hierarchy order matters: parents first)
MAP = [
    ("Hips",        "Torso2"),
    ("chest",       "Torso3"),
    ("head",        "Head"),         # world delta folds the whole neck chain in
    ("tailstart",   "Tail2"),
    ("tail1",       "Tail4"),
    ("tail2",       "Tail6"),
    ("tail3",       "Tail8"),
    ("frontleg",    "FrontShoulder.L"),
    ("frontleg0",   "FrontUpperLeg.L"),
    ("frontleg1",   "FrontLowerLeg.L"),
    ("R_frontleg",  "FrontShoulder.R"),
    ("R_frontleg0", "FrontUpperLeg.R"),
    ("R_frontleg1", "FrontLowerLeg.R"),
    ("backleg",     "BackShoulder.L"),
    ("backleg0",    "BackLeg.L"),
    ("backleg1",    "BackUpperLeg.L"),
    ("backleg2",    "BackLowerLeg.L"),
    ("R_backleg",   "BackShoulder.R"),
    ("R_backleg0",  "BackLeg.R"),
    ("R_backleg1",  "BackUpperLeg.R"),
    ("R_backleg2",  "BackLowerLeg.R"),
]

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=MESHY_GLB)
tgt = next(o for o in bpy.data.objects if o.type == "ARMATURE")
# drop Meshy's junk Icosphere; keep only skinned meshes
for o in list(bpy.data.objects):
    if o.type == "MESH" and not o.vertex_groups:
        bpy.data.objects.remove(o, do_unlink=True)
tgt_meshes = [o for o in bpy.data.objects if o.type == "MESH"]
scene = bpy.context.scene

# the GLB comes in at 0.01 scale - blow it up to pet size (~1.6 world units)
bpy.context.view_layer.update()
cs = [o.matrix_world @ v.co for o in tgt_meshes for v in o.data.vertices]
h0 = max(c.z for c in cs) - min(c.z for c in cs)
tgt.scale = tuple(s * (1.62 / h0) for s in tgt.scale)
bpy.context.view_layer.update()
print("RESCALED from", round(h0, 4), "to ~1.62")

def world_bounds():
    import itertools
    cs = [o.matrix_world @ v.co for o in tgt_meshes for v in o.data.vertices]
    return (min(c.x for c in cs), max(c.x for c in cs),
            min(c.y for c in cs), max(c.y for c in cs),
            min(c.z for c in cs), max(c.z for c in cs))

def setup_render(tag, f0, f1):
    scene.render.engine = "BLENDER_EEVEE"
    if not scene.world:
        w = bpy.data.worlds.new("W"); w.use_nodes = True
        w.node_tree.nodes["Background"].inputs[0].default_value = (0.55, 0.65, 0.75, 1)
        w.node_tree.nodes["Background"].inputs[1].default_value = 0.7
        scene.world = w
    if "Sun" not in bpy.data.objects:
        sun = bpy.data.objects.new("Sun", bpy.data.lights.new("Sun", "SUN"))
        sun.data.energy = 3.0
        sun.rotation_euler = (math.radians(50), 0, math.radians(-30))
        scene.collection.objects.link(sun)
    x0, x1, y0, y1, z0, z1 = world_bounds()
    H = z1 - z0; L = y1 - y0
    if "Ground" not in bpy.data.objects:
        bpy.ops.mesh.primitive_plane_add(size=30, location=(0, 0, z0 - 0.002))
        g = bpy.context.active_object; g.name = "Ground"
        gm = bpy.data.materials.new("GroundM"); gm.use_nodes = True
        gm.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.35, 0.5, 0.3, 1)
        g.data.materials.append(gm)
    cam = bpy.data.objects.get("Cam")
    if cam is None:
        cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
        scene.collection.objects.link(cam)
    scene.camera = cam
    center = mu.Vector((0, (y0 + y1) / 2 - 0.3 * L, z0 + 0.45 * H))
    cam.location = center + mu.Vector((1.0, -0.75, 0.28)).normalized() * max(H, L) * 2.6
    cam.rotation_euler = (center - cam.location).to_track_quat("-Z", "Y").to_euler()
    scene.render.resolution_x = 720
    scene.render.resolution_y = 720
    scene.render.fps = 24
    scene.render.image_settings.file_format = "PNG"
    scene.frame_start = f0
    scene.frame_end = f1
    d = os.path.join(SCRATCH, f"{tag}_frames")
    os.makedirs(d, exist_ok=True)
    scene.render.filepath = os.path.join(d, "f_")
    bpy.ops.render.render(animation=True)
    print("FRAMES", d)

# ---------- 1) render Meshy's own walk ----------
walk = next((a for a in bpy.data.actions), None)
print("WALK_ACTION", walk.name if walk else None)
if walk and (tgt.animation_data is None or tgt.animation_data.action is None):
    tgt.animation_data_create().action = walk
f0, f1 = (int(v) for v in walk.frame_range)
setup_render("meshy_walk", f0, f1)

# ---------- 2) retarget wolf clip ----------
tgt.animation_data_clear()
for pb in tgt.pose.bones:
    pb.rotation_mode = "QUATERNION"
    pb.rotation_quaternion = (1, 0, 0, 0)
    pb.location = (0, 0, 0)

pre = set(bpy.data.objects)
bpy.ops.import_scene.fbx(filepath=WOLF_FBX)
new_objs = [o for o in bpy.data.objects if o not in pre]
src = next(o for o in new_objs if o.type == "ARMATURE")
# hide wolf from renders
for o in new_objs:
    o.hide_render = True

act = next(a for a in bpy.data.actions if a.name.endswith("|" + CLIP))
src.animation_data_create().action = act
if hasattr(src.animation_data, "action_slot") and getattr(act, "slots", None) and len(act.slots):
    src.animation_data.action_slot = act.slots[0]
cf0, cf1 = (int(v) for v in act.frame_range)
print("CLIP", act.name, cf0, cf1)

# rest world rotations (constant)
src_rest = {}
tgt_rest = {}
for tname, sname in MAP:
    sb = src.data.bones.get(sname)
    tb = tgt.data.bones.get(tname)
    if sb is None or tb is None:
        print("MISSING", tname, sname); continue
    src_rest[sname] = (src.matrix_world @ sb.matrix_local).to_quaternion()
    tgt_rest[tname] = (tgt.matrix_world @ tb.matrix_local).to_quaternion()

# root-motion scale from mesh heights
def obj_height(objs):
    zs = [(o.matrix_world @ v.co).z for o in objs for v in o.data.vertices]
    return max(zs) - min(zs)
src_meshes = [o for o in new_objs if o.type == "MESH"]
scale = obj_height(tgt_meshes) / obj_height(src_meshes)
print("ROOT_SCALE", round(scale, 3))

base_tgt_loc = tgt.location.copy()
for f in range(cf0, cf1 + 1):
    scene.frame_set(f)
    for tname, sname in MAP:
        if sname not in src_rest or tname not in tgt_rest:
            continue
        spb = src.pose.bones[sname]
        tpb = tgt.pose.bones[tname]
        q_src_pose = (src.matrix_world @ spb.matrix).to_quaternion()
        delta = q_src_pose @ src_rest[sname].inverted()
        q_tgt_world = delta @ tgt_rest[tname]
        # write via matrix assignment, preserving the bone's current head position
        bpy.context.view_layer.update()
        m = tpb.matrix.copy()
        loc = m.to_translation()
        rot_arm = (tgt.matrix_world.to_quaternion().inverted() @ q_tgt_world).to_matrix().to_4x4()
        rot_arm.translation = loc
        tpb.matrix = rot_arm
        tpb.keyframe_insert("rotation_quaternion", frame=f)
    body = src.pose.bones.get("Body")
    if body is not None:
        d = body.matrix_basis.to_translation() * scale
        tgt.location = base_tgt_loc + mu.Vector((d.x, d.y, d.z))
        tgt.keyframe_insert("location", frame=f)

for o in new_objs:
    bpy.data.objects.remove(o, do_unlink=True)
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(SCRATCH, "meshy_doggy_wolfattack.blend"))
setup_render("meshy_wolfattack", cf0, cf1)
