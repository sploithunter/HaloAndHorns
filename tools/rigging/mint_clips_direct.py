"""Retarget Quaternius Wolf clips onto the Meshy quadruped rig in Blender and
dump per-frame pose deltas (matrix_basis) per clip — feedstock for the direct
KeyframeSequence converter (no FBX, no anim2rbx).
"""
import bpy, json, os
import mathutils as mu

SCRATCH = "/private/tmp/claude-501/-Users-jason-Documents-HaloAndHorns/35c99d45-e986-4baa-9686-67954732ee42/scratchpad"
MESHY_GLB = "/Users/jason/Downloads/Meshy_AI_model_Animation_Walking_withSkin.glb"
WOLF_FBX = os.environ.get("SRC_FBX", os.path.join(SCRATCH, "quaternius_animals/FBX/Wolf.fbx"))
OUT = os.path.join(SCRATCH, "direct_clips")
os.makedirs(OUT, exist_ok=True)

if os.environ.get("CLIP_SPEC"):
    CLIPS = [tuple(p.split("=")) for p in os.environ["CLIP_SPEC"].split(",")]
else:
    CLIPS = [
        ("Idle", "quadruped_idle"), ("Idle_2", "quadruped_idle2"),
        ("Gallop", "quadruped_gallop"), ("Attack", "quadruped_attack"),
        ("Idle_HitReact_Left", "quadruped_hitreact_left"),
        ("Idle_HitReact_Right", "quadruped_hitreact_right"),
    ]
MAP = [
    ("Hips", "Torso2"), ("chest", "Torso3"), ("head", "Head"),
    ("tailstart", "Tail2"), ("tail1", "Tail4"), ("tail2", "Tail6"), ("tail3", "Tail8"),
    ("frontleg", "FrontShoulder.L"), ("frontleg0", "FrontUpperLeg.L"), ("frontleg1", "FrontLowerLeg.L"),
    ("R_frontleg", "FrontShoulder.R"), ("R_frontleg0", "FrontUpperLeg.R"), ("R_frontleg1", "FrontLowerLeg.R"),
    ("backleg", "BackShoulder.L"), ("backleg0", "BackLeg.L"), ("backleg1", "BackUpperLeg.L"), ("backleg2", "BackLowerLeg.L"),
    ("R_backleg", "BackShoulder.R"), ("R_backleg0", "BackLeg.R"), ("R_backleg1", "BackUpperLeg.R"), ("R_backleg2", "BackLowerLeg.R"),
]

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=MESHY_GLB)
tgt = next(o for o in bpy.data.objects if o.type == "ARMATURE")
for o in list(bpy.data.objects):
    if o.type == "MESH" and not o.vertex_groups:
        bpy.data.objects.remove(o, do_unlink=True)
tgt.animation_data_clear()
for a in list(bpy.data.actions):
    bpy.data.actions.remove(a)

pre = set(bpy.data.objects)
bpy.ops.import_scene.fbx(filepath=WOLF_FBX)
new_objs = [o for o in bpy.data.objects if o not in pre]
src = next(o for o in new_objs if o.type == "ARMATURE")

src_rest, tgt_rest = {}, {}
for tname, sname in MAP:
    sb = src.data.bones.get(sname)
    tb = tgt.data.bones.get(tname)
    if sb is None or tb is None:
        continue
    src_rest[sname] = (src.matrix_world @ sb.matrix_local).to_quaternion()
    tgt_rest[tname] = (tgt.matrix_world @ tb.matrix_local).to_quaternion()

hierarchy = {b.name: (b.parent.name if b.parent else "") for b in tgt.data.bones}
scene = bpy.context.scene

for clip_name, out_name in CLIPS:
    act = next(a for a in bpy.data.actions if a.name.endswith("|" + clip_name))
    ad = src.animation_data_create()
    ad.action = act
    if hasattr(ad, "action_slot") and getattr(act, "slots", None) and len(act.slots):
        ad.action_slot = act.slots[0]
    f0, f1 = (int(v) for v in act.frame_range)

    for pb in tgt.pose.bones:
        pb.rotation_mode = "QUATERNION"
        pb.rotation_quaternion = (1, 0, 0, 0)
        pb.location = (0, 0, 0)

    frames = []
    for f in range(f0, f1 + 1):
        scene.frame_set(f)
        # world-delta retarget onto meshy rig (proven visually in Blender)
        for tname, sname in MAP:
            if sname not in src_rest or tname not in tgt_rest:
                continue
            spb = src.pose.bones[sname]
            tpb = tgt.pose.bones[tname]
            delta = (src.matrix_world @ spb.matrix).to_quaternion() @ src_rest[sname].inverted()
            q_w = delta @ tgt_rest[tname]
            bpy.context.view_layer.update()
            m = tpb.matrix.copy()
            loc = m.to_translation()
            r = (tgt.matrix_world.to_quaternion().inverted() @ q_w).to_matrix().to_4x4()
            r.translation = loc
            tpb.matrix = r
        bpy.context.view_layer.update()
        row = {"time": (f - f0) / 24.0, "bones": {}}
        for pb in tgt.pose.bones:
            mb = pb.matrix_basis
            q = mb.to_quaternion()
            row["bones"][pb.name] = {"pos": [0.0, 0.0, 0.0],
                                     "quat": [round(q.w, 6), round(q.x, 6), round(q.y, 6), round(q.z, 6)]}
        frames.append(row)
    with open(os.path.join(OUT, out_name + ".json"), "w") as fh:
        json.dump({"hierarchy": hierarchy, "fps": 24.0, "frames": frames}, fh)
    print("DUMPED", out_name, len(frames), "frames")
print("ALL_DONE")