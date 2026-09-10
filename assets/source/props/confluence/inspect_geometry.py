import bpy,math
from mathutils import Vector
from pathlib import Path
root=Path(__file__).resolve().parent
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
bpy.ops.import_scene.gltf(filepath=str(root/'closed/model.glb'))
o=next(o for o in bpy.context.scene.objects if o.type=='MESH');bpy.context.view_layer.objects.active=o
pts=[o.matrix_world@Vector(c) for c in o.bound_box];lo=Vector(tuple(min(p[i] for p in pts) for i in range(3)));hi=Vector(tuple(max(p[i] for p in pts) for i in range(3)));center=(lo+hi)*.5;dim=hi-lo
s=bpy.context.scene;s.render.engine='CYCLES';s.cycles.samples=16;s.render.resolution_x=800;s.render.resolution_y=650;s.render.resolution_percentage=100;s.world.color=(.3,.3,.3)
bpy.ops.object.light_add(type='AREA',location=center+Vector((5,-8,12)));bpy.context.object.data.energy=1800;bpy.context.object.data.shape='DISK';bpy.context.object.data.size=9
bpy.ops.object.camera_add();cam=bpy.context.object;cam.data.type='ORTHO';cam.data.ortho_scale=max(dim)*1.3;s.camera=cam
for name,a in [('front',0),('right',90),('back',180),('left',270)]:
 r=math.radians(a);cam.location=center+Vector((math.sin(r)*18,-math.cos(r)*18,12));cam.rotation_euler=(center-cam.location).to_track_quat('-Z','Y').to_euler();s.render.filepath=str(root/'closed'/f'check_{name}.png');bpy.ops.render.render(write_still=True)
