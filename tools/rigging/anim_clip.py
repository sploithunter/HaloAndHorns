"""Shared attack clip for the canonical quadruped rig.

Keys the same animation onto any armature that has the canonical bone set.
`scale` scales the root-motion hop for pets of different heights.
"""
import math


def apply_attack_clip(arm, pb, scale=1.0):
    def key(bone, frame, rx=None, ry=None, rz=None):
        b = pb[bone]
        if rx is not None: b.rotation_euler.x = math.radians(rx)
        if ry is not None: b.rotation_euler.y = math.radians(ry)
        if rz is not None: b.rotation_euler.z = math.radians(rz)
        b.keyframe_insert("rotation_euler", frame=frame)

    def key_obj_loc(frame, x, y, z):
        arm.location = (x * scale, y * scale, z * scale)
        arm.keyframe_insert("location", frame=frame)

    # idle (1-36): tail wag + head bob
    for f in (1, 36, 150, 156):
        for name in ("Root", "Spine1", "Chest", "Neck", "Head",
                     "UpperLeg_FL", "UpperLeg_FR", "UpperLeg_HL", "UpperLeg_HR",
                     "LowerLeg_FL", "LowerLeg_FR", "LowerLeg_HL", "LowerLeg_HR"):
            key(name, f, 0, 0, 0)
    for i, f in enumerate(range(1, 42, 5)):
        key("Tail1", f, rz=18 if i % 2 == 0 else -18)
    key("Head", 10, rx=-6)
    key("Head", 24, rx=4)
    key("Head", 36, rx=0)

    # crouch windup (36-54)
    for tag in ("FL", "FR", "HL", "HR"):
        key(f"UpperLeg_{tag}", 36, rx=0); key(f"LowerLeg_{tag}", 36, rx=0)
        key(f"UpperLeg_{tag}", 54, rx=32); key(f"LowerLeg_{tag}", 54, rx=-42)
    key("Neck", 54, rx=12)
    key("Head", 54, rx=8)
    key("Tail1", 46, rz=0)
    key("Tail1", 54, rx=15)
    key_obj_loc(36, 0, 0, 0)
    key_obj_loc(54, 0, 0, -0.12)

    # pounce (54-72)
    key_obj_loc(63, 0, -0.45, 0.30)
    key_obj_loc(72, 0, -0.80, 0.0)
    for tag in ("FL", "FR"):
        key(f"UpperLeg_{tag}", 63, rx=-55)
        key(f"LowerLeg_{tag}", 63, rx=25)
        key(f"UpperLeg_{tag}", 72, rx=0)
        key(f"LowerLeg_{tag}", 72, rx=0)
    for tag in ("HL", "HR"):
        key(f"UpperLeg_{tag}", 63, rx=25)
        key(f"LowerLeg_{tag}", 63, rx=-15)
        key(f"UpperLeg_{tag}", 72, rx=0)
        key(f"LowerLeg_{tag}", 72, rx=0)
    key("Neck", 63, rx=-10)
    key("Head", 63, rx=-8)
    key("Neck", 72, rx=0)
    key("Head", 72, rx=0)

    # paw swipes (78-114)
    key("UpperLeg_FL", 78, rx=0); key("LowerLeg_FL", 78, rx=0)
    key("UpperLeg_FL", 87, rx=-85); key("LowerLeg_FL", 87, rx=55)
    key("UpperLeg_FL", 93, rx=-40); key("LowerLeg_FL", 93, rx=20)
    key("UpperLeg_FL", 96, rx=0); key("LowerLeg_FL", 96, rx=0)
    key("UpperLeg_FR", 96, rx=0); key("LowerLeg_FR", 96, rx=0)
    key("UpperLeg_FR", 105, rx=-85); key("LowerLeg_FR", 105, rx=55)
    key("UpperLeg_FR", 111, rx=-40); key("LowerLeg_FR", 111, rx=20)
    key("UpperLeg_FR", 114, rx=0); key("LowerLeg_FR", 114, rx=0)
    key("Chest", 78, rx=0); key("Chest", 87, rx=-6); key("Chest", 105, rx=-6); key("Chest", 114, rx=0)

    # head shake bite (114-138)
    key("Neck", 114, rz=0); key("Head", 114, rz=0)
    key("Neck", 120, rz=30); key("Head", 120, rz=25)
    key("Neck", 126, rz=-30); key("Head", 126, rz=-25)
    key("Neck", 132, rz=20); key("Head", 132, rz=18)
    key("Neck", 138, rz=0); key("Head", 138, rz=0)

    # settle + happy wag (138-156)
    for i, f in enumerate(range(138, 157, 4)):
        key("Tail1", f, rx=0, rz=22 if i % 2 == 0 else -22)
    key_obj_loc(156, 0, -0.80, 0.0)
