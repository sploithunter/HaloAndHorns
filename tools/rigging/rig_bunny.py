"""Sitter-variant fit: same canonical bone names, sitting rest topology."""
import bpy, math, os, sys
import mathutils as mu

SCRATCH = "/private/tmp/claude-501/-Users-jason-Documents-HaloAndHorns/35c99d45-e986-4baa-9686-67954732ee42/scratchpad"
PET = "bunny"
MESH_PATH = "/Users/jason/Documents/HaloAndHorns/assets/source/pets/bunny_basic.glb"

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=MESH_PATH)
mesh_obj = [o for o in bpy.data.objects if o.type == "MESH"][0]
mesh_obj.name = "PetMesh"
for o in list(bpy.data.objects):
    if o.type != "MESH":
        for child in o.children:
            child.parent = None
        bpy.data.objects.remove(o, do_unlink=True)
bpy.context.view_layer.objects.active = mesh_obj
bpy.ops.object.select_all(action="DESELECT")
mesh_obj.select_set(True)
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)

bpy.ops.object.mode_set(mode="EDIT")
bpy.ops.mesh.select_all(action="SELECT")
bpy.ops.mesh.remove_doubles(threshold=0.0001)
bpy.ops.object.mode_set(mode="OBJECT")
print("AFTER_WELD", len(mesh_obj.data.vertices))

verts = [mesh_obj.matrix_world @ v.co for v in mesh_obj.data.vertices]
min_x = min(v.x for v in verts); max_x = max(v.x for v in verts)
min_y = min(v.y for v in verts); max_y = max(v.y for v in verts)
min_z = min(v.z for v in verts); max_z = max(v.z for v in verts)
H = max_z - min_z
L = max_y - min_y
W = max_x - min_x
print("BOUNDS y", round(min_y,2), round(max_y,2), "z", round(min_z,2), round(max_z,2))

def zf(f): return min_z + f * H   # fraction of height
def yf(f): return min_y + f * L   # fraction of length (0=front/face, 1=rear)

# measured landmarks for the sitting stance
# band profile (2026-08-13): body/head crease at zf~0.35, skull sphere
# zf 0.37-0.70, ears above 0.70 (depth collapses). The skull is the sphere,
# NOT the top of the mesh - tall ears fooled the old top-30% heuristic.
head_verts = [v for v in verts if zf(0.37) < v.z < zf(0.72)]
head_c_y = sum(v.y for v in head_verts) / len(head_verts)
head_front_y = min(v.y for v in head_verts)
# haunch (hind leg) mass = bottom 30%, rear half
haunch = [v for v in verts if v.z < zf(0.30) and v.y > yf(0.45)]
haunch_cx = sum(abs(v.x) for v in haunch) / len(haunch)
haunch_cy = sum(v.y for v in haunch) / len(haunch)
# hind feet = bottom 12%, front half (sitting bunny feet point forward)
feet = [v for v in verts if v.z < zf(0.12) and v.y < yf(0.55)]
feet_cy = sum(v.y for v in feet) / len(feet) if feet else yf(0.35)
# front paw mass = mid height, front quarter
paws = [v for v in verts if zf(0.30) < v.z < zf(0.55) and v.y < yf(0.30)]
paw_cx = sum(abs(v.x) for v in paws) / len(paws) if paws else 0.15 * W
paw_cy = sum(v.y for v in paws) / len(paws) if paws else yf(0.2)
print("LANDMARKS haunch_cx", round(haunch_cx,2), "feet_cy", round(feet_cy,2), "paw_cx", round(paw_cx,2))

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

# vertical spine chain: pelvis low-rear, curving up to the crease at zf~0.35;
# Head bone runs through the measured skull sphere (ears ride via weights)
root_p   = mu.Vector((0, haunch_cy, zf(0.20)))
spine_p  = mu.Vector((0, yf(0.45), zf(0.28)))
chest_p  = mu.Vector((0, yf(0.40), zf(0.34)))
neck_p   = mu.Vector((0, yf(0.38), zf(0.36)))
head_end = mu.Vector((0, head_front_y + 0.02 * L, zf(0.62)))
bone("Root", root_p, spine_p)
bone("Spine1", spine_p, chest_p, "Root", True)
bone("Chest", chest_p, neck_p, "Spine1", True)
neck_end = mu.Vector((0, head_c_y, zf(0.46)))
bone("Neck", neck_p, neck_end, "Chest", True)
bone("Head", neck_end, head_end, "Neck", True)
# tail puff: rear, mid-low
bone("Tail1", mu.Vector((0, max_y - 0.12 * L, zf(0.32))), mu.Vector((0, max_y, zf(0.38))), "Root")
bone("Tail2", mu.Vector((0, max_y, zf(0.38))), mu.Vector((0, max_y + 0.05 * L, zf(0.42))), "Tail1", True)
# hind legs: hip on haunch top -> knee at haunch center-low -> foot forward
for tag, sx in (("HL", 1), ("HR", -1)):
    hip  = mu.Vector((sx * haunch_cx, haunch_cy, zf(0.32)))
    knee = mu.Vector((sx * haunch_cx * 1.1, haunch_cy + 0.02 * L, zf(0.14)))
    foot = mu.Vector((sx * haunch_cx * 0.9, feet_cy, zf(0.05)))
    bone(f"UpperLeg_{tag}", hip, knee, "Root")
    bone(f"LowerLeg_{tag}", knee, foot, f"UpperLeg_{tag}", True)
    bone(f"Foot_{tag}", foot, foot + mu.Vector((0, -0.08 * L, 0)), f"LowerLeg_{tag}", True)
# front paws: shoulder below the chin crease -> elbow -> paw
for tag, sx in (("FL", 1), ("FR", -1)):
    sh    = mu.Vector((sx * paw_cx, yf(0.33), zf(0.46)))
    elbow = mu.Vector((sx * paw_cx * 1.05, paw_cy + 0.03 * L, zf(0.40)))
    paw   = mu.Vector((sx * paw_cx, paw_cy, zf(0.34)))
    bone(f"UpperLeg_{tag}", sh, elbow, "Chest")
    bone(f"LowerLeg_{tag}", elbow, paw, f"UpperLeg_{tag}", True)
    bone(f"Foot_{tag}", paw, paw + mu.Vector((0, -0.06 * L, -0.02 * H)), f"LowerLeg_{tag}", True)
bpy.ops.object.mode_set(mode="OBJECT")

bpy.ops.object.select_all(action="DESELECT")
mesh_obj.select_set(True); arm_obj.select_set(True)
bpy.context.view_layer.objects.active = arm_obj
bpy.ops.object.parent_set(type="ARMATURE_AUTO")

def effective_groups(v):
    return [(g.group, g.weight) for g in v.groups if g.weight > 1e-6]

unweighted_ids = [v.index for v in mesh_obj.data.vertices if not effective_groups(v)]
print("UNWEIGHTED", len(unweighted_ids), "/", len(mesh_obj.data.vertices))
if unweighted_ids:
    kd_src = [(v.index, v.co) for v in mesh_obj.data.vertices if effective_groups(v)]
    kd = mu.kdtree.KDTree(len(kd_src))
    for i, (idx, co) in enumerate(kd_src):
        kd.insert(co, i)
    kd.balance()
    for vid in unweighted_ids:
        _, i, _ = kd.find(mesh_obj.data.vertices[vid].co)
        src_v = mesh_obj.data.vertices[kd_src[i][0]]
        for gi, w in effective_groups(src_v):
            mesh_obj.vertex_groups[gi].add([vid], w, "REPLACE")
    print("RESCUED", len(unweighted_ids))

# skull cleanup: the whole skull+ears (above the crease) belongs to Head/Neck.
# Exception: the paw lobes overlap the chin in z - a vert in the skull band
# keeps leg weights only if it is off-center AND low AND forward (a paw).
gidx = {g.name: g.index for g in mesh_obj.vertex_groups}
keep = {gidx["Head"], gidx["Neck"]}
leg_gis = {gidx[n] for n in gidx if n.startswith(("UpperLeg", "LowerLeg", "Foot"))}
fixed = 0
for v in mesh_obj.data.vertices:
    if v.co.z <= zf(0.40):
        continue
    dom = max(v.groups, key=lambda g: g.weight) if len(v.groups) else None
    if dom is None or dom.group in keep:
        continue
    is_paw = (dom.group in leg_gis and v.co.z < zf(0.55)
              and abs(v.co.x) > 0.08 * W and v.co.y < yf(0.30))
    if is_paw:
        continue
    # rump-top/tail geometry pokes above the crease at the rear - not skull
    if v.co.y > yf(0.55) and v.co.z < zf(0.60):
        continue
    neck_w = sum(g.weight for g in v.groups if g.group == gidx["Neck"])
    for g in list(v.groups):
        if g.group not in keep:
            mesh_obj.vertex_groups[g.group].remove([v.index])
    mesh_obj.vertex_groups[gidx["Head"]].add([v.index], max(0.0, 1.0 - neck_w), "REPLACE")
    fixed += 1
print("SKULL_REBOUND", fixed)

# feather the hard rebind seams: Laplacian smooth of deform weights
# (background-safe: no paint-mode operators)
me = mesh_obj.data
n_groups = len(mesh_obj.vertex_groups)
adj = [[] for _ in range(len(me.vertices))]
for e in me.edges:
    a, b = e.vertices
    adj[a].append(b); adj[b].append(a)

def weights_of(v):
    w = [0.0] * n_groups
    for g in v.groups:
        w[g.group] = g.weight
    return w

W_arr = [weights_of(v) for v in me.vertices]
smooth_ids = [v.index for v in me.vertices if v.co.z > zf(0.25)]
FACTOR, ITERS = 0.5, 3
for _ in range(ITERS):
    new = {}
    for vid in smooth_ids:
        nbrs = adj[vid]
        if not nbrs:
            continue
        avg = [sum(W_arr[nb][g] for nb in nbrs) / len(nbrs) for g in range(n_groups)]
        merged = [(1 - FACTOR) * W_arr[vid][g] + FACTOR * avg[g] for g in range(n_groups)]
        total = sum(merged)
        new[vid] = [w / total for w in merged] if total > 1e-9 else merged
    for vid, w in new.items():
        W_arr[vid] = w
for vid in smooth_ids:
    for g in range(n_groups):
        w = W_arr[vid][g]
        if w > 1e-5:
            mesh_obj.vertex_groups[g].add([vid], w, "REPLACE")
        else:
            mesh_obj.vertex_groups[g].remove([vid])
print("SMOOTHED", len(smooth_ids))

sys.path.insert(0, SCRATCH)
import anim_clip
bpy.context.view_layer.objects.active = arm_obj
bpy.ops.object.mode_set(mode="POSE")
for b in arm_obj.pose.bones:
    b.rotation_mode = "XYZ"
anim_clip.apply_attack_clip(arm_obj, arm_obj.pose.bones, scale=H / 1.62)
bpy.ops.object.mode_set(mode="OBJECT")

scene = bpy.context.scene
scene.render.fps = 24
scene.frame_start = 1
scene.frame_end = 156
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(SCRATCH, f"{PET}_rigged.blend"))

bpy.ops.object.select_all(action="DESELECT")
mesh_obj.select_set(True); arm_obj.select_set(True)
bpy.ops.export_scene.fbx(
    filepath=os.path.join(SCRATCH, f"{PET}_canonical_rig.fbx"),
    use_selection=True, add_leaf_bones=False, bake_anim=False,
    path_mode="COPY", embed_textures=True,
)

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
bpy.ops.mesh.primitive_plane_add(size=30, location=(0, 0, min_z - 0.01))
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
cam.location = center + mu.Vector((1.0, -0.75, 0.28)).normalized() * size * 2.6
cam.rotation_euler = (center - cam.location).to_track_quat("-Z", "Y").to_euler()
scene.render.resolution_x = 720
scene.render.resolution_y = 720
scene.render.image_settings.file_format = "PNG"
frames_dir = os.path.join(SCRATCH, f"{PET}_frames")
os.makedirs(frames_dir, exist_ok=True)
scene.render.filepath = os.path.join(frames_dir, "f_")
bpy.ops.render.render(animation=True)
print("FRAMES", frames_dir)
