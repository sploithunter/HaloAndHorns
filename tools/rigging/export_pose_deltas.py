"""Dump the Meshy walk as per-frame, per-bone LOCAL pose deltas (matrix_basis)
plus the bone hierarchy — feedstock for building a Roblox KeyframeSequence
directly, bypassing anim2rbx.
"""
import bpy, json, os

SCRATCH = "/private/tmp/claude-501/-Users-jason-Documents-HaloAndHorns/35c99d45-e986-4baa-9686-67954732ee42/scratchpad"
GLB = "/Users/jason/Downloads/Meshy_AI_model_Animation_Walking_withSkin.glb"

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=GLB)
arm = next(o for o in bpy.data.objects if o.type == "ARMATURE")

act = next(a for a in bpy.data.actions)
ad = arm.animation_data or arm.animation_data_create()
ad.action = act
if hasattr(ad, "action_slot") and getattr(act, "slots", None) and len(act.slots):
    ad.action_slot = act.slots[0]
f0, f1 = (int(v) for v in act.frame_range)
scene = bpy.context.scene
fps = 24.0

hierarchy = {}
for b in arm.data.bones:
    hierarchy[b.name] = b.parent.name if b.parent else ""

frames = []
for f in range(f0, f1 + 1):
    scene.frame_set(f)
    row = {"time": (f - f0) / fps, "bones": {}}
    for pb in arm.pose.bones:
        mb = pb.matrix_basis
        loc = mb.to_translation()
        q = mb.to_quaternion()
        row["bones"][pb.name] = {
            "pos": [round(loc.x, 6), round(loc.y, 6), round(loc.z, 6)],
            "quat": [round(q.w, 6), round(q.x, 6), round(q.y, 6), round(q.z, 6)],
        }
    frames.append(row)

with open(os.path.join(SCRATCH, "walk_pose_deltas.json"), "w") as fh:
    json.dump({"hierarchy": hierarchy, "fps": fps, "frames": frames}, fh)
print("WROTE", len(frames), "frames,", len(hierarchy), "bones")