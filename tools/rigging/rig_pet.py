import bpy, math, os, sys
import mathutils as mu

SCRATCH = "/private/tmp/claude-501/-Users-jason-Documents-HaloAndHorns/35c99d45-e986-4baa-9686-67954732ee42/scratchpad"
argv = sys.argv[sys.argv.index("--") + 1:]
PET = argv[0]
MESH_PATH = argv[1]

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=MESH_PATH)
mesh_obj = [o for o in bpy.data.objects if o.type == "MESH"][0]
mesh_obj.name = "PetMesh"

# clear any transforms/parents from the GLB scene graph
for o in list(bpy.data.objects):
    if o.type not in ("MESH",):
        for child in o.children:
            child.parent = None
        bpy.data.objects.remove(o, do_unlink=True)
bpy.context.view_layer.objects.active = mesh_obj
bpy.ops.object.select_all(action="DESELECT")
mesh_obj.select_set(True)
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)

# --- weld
bpy.ops.object.mode_set(mode="EDIT")
bpy.ops.mesh.select_all(action="SELECT")
bpy.ops.mesh.remove_doubles(threshold=0.0001)
bpy.ops.object.mode_set(mode="OBJECT")
print("AFTER_WELD", len(mesh_obj.data.vertices))

# --- facing detection: the head end has far more mesh mass than the tail end
def world_verts():
    return [mesh_obj.matrix_world @ v.co for v in mesh_obj.data.vertices]

verts = world_verts()
ys = [v.y for v in verts]
min_y, max_y = min(ys), max(ys)
L0 = max_y - min_y
neg_end = sum(1 for v in verts if v.y < min_y + 0.25 * L0)
pos_end = sum(1 for v in verts if v.y > max_y - 0.25 * L0)
print("FACING neg_end", neg_end, "pos_end", pos_end)
if pos_end > neg_end:
    # head is at +Y; rotate 180 so head faces -Y like the canonical rig expects
    mesh_obj.rotation_euler.z = math.radians(180)
    bpy.ops.object.transform_apply(rotation=True)
    print("ROTATED to face -Y")
    verts = world_verts()

xs = [v.x for v in verts]; ys = [v.y for v in verts]; zs = [v.z for v in verts]
min_x, max_x = min(xs), max(xs)
min_y, max_y = min(ys), max(ys)
min_z, max_z = min(zs), max(zs)
H = max_z - min_z
L = max_y - min_y

# --- leg clusters
leg_band = [v for v in verts if v.z < min_z + 0.30 * H]
mid_y = (min_y + max_y) / 2
legs = {}
for tag, xsign, front in (("FL", 1, True), ("FR", -1, True), ("HL", 1, False), ("HR", -1, False)):
    cluster = [v for v in leg_band
               if (v.x > 0) == (xsign > 0)
               and ((v.y < mid_y) if front else (v.y > mid_y))]
    if not cluster:
        raise RuntimeError("empty leg cluster " + tag)
    legs[tag] = (sum(v.x for v in cluster) / len(cluster), sum(v.y for v in cluster) / len(cluster))
    print("LEG", tag, round(legs[tag][0], 3), round(legs[tag][1], 3), "n=", len(cluster))

front_y = (legs["FL"][1] + legs["FR"][1]) / 2
hind_y = (legs["HL"][1] + legs["HR"][1]) / 2

# skull cluster: everything forward of the front shoulders, above the knees
# (chibi pets have huge heads - use the full cluster so the centroid is honest)
head_verts = [v for v in verts if v.y < front_y - 0.05 * L and v.z > min_z + 0.20 * H]
if not head_verts:
    head_verts = [v for v in verts if v.y < front_y and v.z > min_z + 0.20 * H]
head_c = mu.Vector((0, sum(v.y for v in head_verts) / len(head_verts),
                    sum(v.z for v in head_verts) / len(head_verts)))
head_top_z = max(v.z for v in head_verts)
# aim the head bone through the skull center, ending high near the top of the
# skull mass so heat weighting owns the whole head (ears included)
head_c.z = (head_c.z + head_top_z) / 2
head_front_y = min(v.y for v in head_verts)

tail_verts = [v for v in verts if v.y > hind_y + 0.08 * L and v.z > min_z + 0.30 * H]
tail_tip_y = max(v.y for v in tail_verts) if tail_verts else max_y
tail_tip_z = max((v.z for v in tail_verts if v.y > tail_tip_y - 0.05 * L), default=min_z + 0.6 * H)

spine_z = min_z + 0.52 * H
foot_z = min_z + 0.03 * H
knee_z = min_z + 0.18 * H
hip_z = min_z + 0.40 * H

# --- canonical armature (identical names/hierarchy across all pets)
arm_data = bpy.data.armatures.new("QuadrupedRig")
arm_obj = bpy.data.objects.new("QuadrupedRig", arm_data)
bpy.context.scene.collection.objects.link(arm_obj)
bpy.context.view_layer.objects.active = arm_obj
bpy.ops.object.mode_set(mode="EDIT")
eb = arm_data.edit_bones

def bone(name, head, tail, parent=None, connect=False):
    b = eb.new(name)
    b.head = head; b.tail = tail
    if parent:
        b.parent = eb[parent]; b.use_connect = connect
    return b

bone("Root",   (0, hind_y, spine_z), (0, (hind_y + front_y) / 2, spine_z))
bone("Spine1", (0, (hind_y + front_y) / 2, spine_z), (0, front_y, spine_z), "Root", True)
bone("Chest",  (0, front_y, spine_z), (0, front_y - 0.08 * L, spine_z + 0.04 * H), "Spine1", True)
neck_start = mu.Vector((0, front_y - 0.08 * L, spine_z + 0.04 * H))
neck_end = neck_start.lerp(head_c, 0.5)
bone("Neck", neck_start, neck_end, "Chest", True)
bone("Head", neck_end, (0, head_front_y, head_c.z), "Neck", True)
tail_mid = mu.Vector((0, (hind_y + tail_tip_y) / 2, spine_z + 0.10 * H))
bone("Tail1", (0, hind_y + 0.03 * L, spine_z), tail_mid, "Root")
bone("Tail2", tail_mid, (0, tail_tip_y, tail_tip_z), "Tail1", True)
for tag, parent in (("FL", "Chest"), ("FR", "Chest"), ("HL", "Root"), ("HR", "Root")):
    cx, cy = legs[tag]
    bone(f"UpperLeg_{tag}", (cx, cy, hip_z), (cx, cy, knee_z), parent)
    bone(f"LowerLeg_{tag}", (cx, cy, knee_z), (cx, cy, foot_z), f"UpperLeg_{tag}", True)
    bone(f"Foot_{tag}", (cx, cy, foot_z), (cx, cy - 0.05 * L, foot_z), f"LowerLeg_{tag}", True)
bpy.ops.object.mode_set(mode="OBJECT")

# --- auto-skin
bpy.ops.object.select_all(action="DESELECT")
mesh_obj.select_set(True); arm_obj.select_set(True)
bpy.context.view_layer.objects.active = arm_obj
bpy.ops.object.parent_set(type="ARMATURE_AUTO")
def effective_groups(v):
    return [(g.group, g.weight) for g in v.groups if g.weight > 1e-6]

unweighted_ids = [v.index for v in mesh_obj.data.vertices if not effective_groups(v)]
print("UNWEIGHTED", len(unweighted_ids), "/", len(mesh_obj.data.vertices))

# rescue orphans (disconnected shells like inner ears / claws): copy weights
# from the nearest weighted vertex so they follow the same bones
if unweighted_ids:
    kd_src = [(v.index, v.co) for v in mesh_obj.data.vertices if effective_groups(v)]
    kd = mu.kdtree.KDTree(len(kd_src))
    for i, (idx, co) in enumerate(kd_src):
        kd.insert(co, i)
    kd.balance()
    for vid in unweighted_ids:
        co = mesh_obj.data.vertices[vid].co
        _, i, _ = kd.find(co)
        src_v = mesh_obj.data.vertices[kd_src[i][0]]
        for gi, w in effective_groups(src_v):
            mesh_obj.vertex_groups[gi].add([vid], w, "REPLACE")
    still = sum(1 for v in mesh_obj.data.vertices if not effective_groups(v))
    print("RESCUED", len(unweighted_ids) - still, "REMAINING", still)

# --- skull cleanup: heat weighting on chibi heads leaks torso bones into the
# skull; any skull-region vert dominated by a torso/leg bone is rebound to Head
# (Neck contribution is preserved so the neck blend stays smooth)
gidx = {g.name: g.index for g in mesh_obj.vertex_groups}
head_gi = gidx["Head"]
neck_gi = gidx["Neck"]
keep = {head_gi, neck_gi}
neck_start_y = neck_start.y
neck_start_z = neck_start.z
fixed = 0
for v in mesh_obj.data.vertices:
    if v.co.y < neck_start_y and v.co.z > neck_start_z:
        dom = max(v.groups, key=lambda g: g.weight) if len(v.groups) else None
        if dom is not None and dom.group not in keep:
            neck_w = sum(g.weight for g in v.groups if g.group == neck_gi)
            for g in list(v.groups):
                if g.group not in keep:
                    mesh_obj.vertex_groups[g.group].remove([v.index])
            mesh_obj.vertex_groups[head_gi].add([v.index], max(0.0, 1.0 - neck_w), "REPLACE")
            fixed += 1
print("SKULL_REBOUND", fixed)

# --- apply the SHARED clip (same keyframes as the doggy, scaled root motion)
sys.path.insert(0, SCRATCH)
import anim_clip
bpy.context.view_layer.objects.active = arm_obj
bpy.ops.object.mode_set(mode="POSE")
for b in arm_obj.pose.bones:
    b.rotation_mode = "XYZ"
anim_clip.apply_attack_clip(arm_obj, arm_obj.pose.bones, scale=H / 1.62)
bpy.ops.object.mode_set(mode="OBJECT")
print("ACTION", arm_obj.animation_data.action.name if arm_obj.animation_data else None)

scene = bpy.context.scene
scene.render.fps = 24
scene.frame_start = 1
scene.frame_end = 156

bpy.ops.wm.save_as_mainfile(filepath=os.path.join(SCRATCH, f"{PET}_rigged.blend"))

# --- FBX export (rest pose, no anim baked)
bpy.ops.object.select_all(action="DESELECT")
mesh_obj.select_set(True); arm_obj.select_set(True)
bpy.ops.export_scene.fbx(
    filepath=os.path.join(SCRATCH, f"{PET}_canonical_rig.fbx"),
    use_selection=True, add_leaf_bones=False, bake_anim=False,
    path_mode="COPY", embed_textures=True,
)

# --- render the shared animation
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

ground_z = min_z - 0.01
bpy.ops.mesh.primitive_plane_add(size=30, location=(0, 0, ground_z))
ground = bpy.context.active_object
gmat = bpy.data.materials.new("Ground")
gmat.use_nodes = True
gmat.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.35, 0.5, 0.3, 1)
ground.data.materials.append(gmat)

cam = bpy.data.objects.new("Cam2", bpy.data.cameras.new("Cam2"))
scene.collection.objects.link(cam)
scene.camera = cam
size = max(H, L)
center = mu.Vector((0, (min_y + max_y) / 2 - 0.4, min_z + 0.45 * H))
cam.location = center + mu.Vector((1.0, -0.75, 0.28)).normalized() * size * 2.9
cam.rotation_euler = (center - cam.location).to_track_quat("-Z", "Y").to_euler()

scene.render.resolution_x = 720
scene.render.resolution_y = 720
scene.render.image_settings.file_format = "PNG"
frames_dir = os.path.join(SCRATCH, f"{PET}_frames")
os.makedirs(frames_dir, exist_ok=True)
scene.render.filepath = os.path.join(frames_dir, "f_")
bpy.ops.render.render(animation=True)
print("FRAMES", frames_dir)
