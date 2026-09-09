"""Independent FBX reimport: topology handled by repo checker; verify UV/skin/atlas."""
import bpy,json,math
from pathlib import Path
from collections import defaultdict
R=Path.cwd()/'assets/source/props/crossroads_pond_fish/final'
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
bpy.ops.import_scene.fbx(filepath=str(R/'PearlPondFish.fbx'))
meshes=[o for o in bpy.context.scene.objects if o.type=='MESH'];assert len(meshes)==1
obj=meshes[0];rig=next(o for o in bpy.context.scene.objects if o.type=='ARMATURE')
assert {'Root','Tail'}<=set(rig.data.bones.keys())
uv=obj.data.uv_layers.active;assert uv;mapping=defaultdict(set)
for loop in obj.data.loops:mapping[loop.vertex_index].add(tuple(round(x,6) for x in uv.data[loop.index].uv))
conflicts=sum(len(x)>1 for x in mapping.values());assert conflicts==0,conflicts
images=[{'name':i.name,'size':list(i.size)} for i in bpy.data.images if i.type!='RENDER_RESULT' and i.name!='Viewer Node'];assert images and all(i['size']==[1024,1024] for i in images),images
weights=[sum(g.weight for g in v.groups) for v in obj.data.vertices];assert all(abs(w-1)<0.0001 for w in weights)
def evaluated():
 bpy.context.view_layer.update();deps=bpy.context.evaluated_depsgraph_get();e=obj.evaluated_get(deps);m=e.to_mesh();points=[e.matrix_world@v.co for v in m.vertices];e.to_mesh_clear();return points
before=evaluated();bone=rig.pose.bones['Tail'];bone.rotation_mode='XYZ';bone.rotation_euler.z=math.radians(12);after=evaluated();movement=[(a-b).length for a,b in zip(after,before)];assert max(movement)>0.05
report={'fbx_reimport':True,'bones':list(rig.data.bones.keys()),'skin_weights_normalized':True,'uv_conflicting_vertices':conflicts,'embedded_images':images,'tail_local_axis':'Z','tail_pose_max_vertex_displacement':max(movement),'tail_pose_max_world_x_displacement':max(abs(a.x-b.x) for a,b in zip(after,before)),'clips':len(bpy.data.actions)}
(R/'export_validation.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report))
