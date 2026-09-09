"""Original fish mesh: exact envelope, fresh packed atlas, small two-bone tail rig.
Blender --background --python <this file> -- --input .../textured/model.glb --output .../final
Only asset source/export work; no network or Studio operations.
"""
import bpy, json, math, argparse, sys, importlib.util
from pathlib import Path
from mathutils import Vector, Matrix
ROOT=Path.cwd(); C=json.loads((ROOT/'configs/realm_crossroads_pond_fish.json').read_text())
p=argparse.ArgumentParser();p.add_argument('--input',default=C['source_dir']+'/textured_closed/model.glb');p.add_argument('--output',default=C['source_dir']+'/final');a=p.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [])
OUT=ROOT/a.output;OUT.mkdir(parents=True,exist_ok=True)
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
bpy.ops.import_scene.gltf(filepath=str(ROOT/a.input))
meshes=[o for o in bpy.context.scene.objects if o.type=='MESH'];bpy.ops.object.select_all(action='DESELECT')
for o in meshes:o.select_set(True)
bpy.context.view_layer.objects.active=meshes[0];bpy.ops.object.join();obj=bpy.context.object;obj.name='PearlPondFish';obj.data.name='PearlPondFish'
bpy.ops.object.transform_apply(location=False,rotation=True,scale=True)
points=[obj.matrix_world@v.co for v in obj.data.vertices];lo=Vector([min(p[i] for p in points) for i in range(3)]);hi=Vector([max(p[i] for p in points) for i in range(3)]);center=(lo+hi)/2;size=hi-lo
# Original source head is -X. Blender +Y exports to native Roblox -Z.
rotation=Matrix.Rotation(math.radians(C['source_rotation_z_degrees']),4,'Z')
native=C['dimensions_xyz'];target=Vector((native[2],native[0],native[1]))
for v in obj.data.vertices:
 pos=obj.matrix_world@v.co-center;v.co=rotation@Vector([pos[i]*target[i]/size[i] for i in range(3)])
obj.matrix_world=Matrix.Identity(4);obj.data.update();bpy.context.view_layer.update()
spec=importlib.util.spec_from_file_location('helper',ROOT/'scripts/blender/rebake_for_roblox.py');helper=importlib.util.module_from_spec(spec);spec.loader.exec_module(helper)
helper.split_uv_seams(obj)
nodes=[n for m in obj.data.materials if m and m.use_nodes for n in m.node_tree.nodes if n.type=='TEX_IMAGE' and n.image]
for i,img in enumerate(list(dict.fromkeys(n.image for n in nodes))):
 img.scale(C['texture_resolution'],C['texture_resolution']);dest=OUT/f'texture_{i}.png';img.filepath_raw=str(dest);img.file_format='PNG';img.save()
 fresh=bpy.data.images.load(str(dest),check_existing=False);fresh.colorspace_settings.name=img.colorspace_settings.name
 for n in nodes:
  if n.image==img:n.image=fresh
 fresh.pack()
 if img.users==0:bpy.data.images.remove(img)
for m in obj.data.materials:
 if m and m.use_nodes:
  for n in m.node_tree.nodes:
   if n.type=='BSDF_PRINCIPLED':n.inputs['Metallic'].default_value=C['material_metallic'];n.inputs['Roughness'].default_value=C['material_roughness']
obj.data.calc_loop_triangles();triangles=len(obj.data.loop_triangles);assert triangles<=C['max_triangles']
rigcfg=C['rig'];armdata=bpy.data.armatures.new('PondFishRig');rig=bpy.data.objects.new('PondFishRig',armdata);bpy.context.collection.objects.link(rig)
bpy.context.view_layer.objects.active=rig;obj.select_set(False);rig.select_set(True);bpy.ops.object.mode_set(mode='EDIT')
body=armdata.edit_bones.new(rigcfg['body_bone']);body.head=(0,0,0);body.tail=(0,rigcfg['body_tip_blender_y'],0)
tail=armdata.edit_bones.new(rigcfg['tail_bone']);tail.head=(0,rigcfg['tail_hinge_blender_y'],0);tail.tail=(0,rigcfg['tail_tip_blender_y'],0);tail.parent=body
bpy.ops.object.mode_set(mode='OBJECT');obj.parent=rig
bodygroup=obj.vertex_groups.new(name=rigcfg['body_bone']);tailgroup=obj.vertex_groups.new(name=rigcfg['tail_bone'])
for v in obj.data.vertices:
 weight=max(0,min(1,(rigcfg['blend_start_blender_y']-v.co.y)/(rigcfg['blend_start_blender_y']-rigcfg['blend_end_blender_y'])));weight=weight*weight*(3-2*weight)
 if weight<1:bodygroup.add([v.index],1-weight,'REPLACE')
 if weight>0:tailgroup.add([v.index],weight,'REPLACE')
modifier=obj.modifiers.new('TailSkin','ARMATURE');modifier.object=rig
bpy.ops.object.select_all(action='DESELECT');obj.select_set(True);rig.select_set(True);bpy.context.view_layer.objects.active=obj
bpy.ops.export_scene.fbx(filepath=str(OUT/'PearlPondFish.fbx'),use_selection=True,object_types={'MESH','ARMATURE'},apply_scale_options='FBX_SCALE_ALL',path_mode='COPY',embed_textures=True,axis_forward='-Z',axis_up='Y',add_leaf_bones=False,bake_anim=False)
bpy.ops.export_scene.gltf(filepath=str(OUT/'PearlPondFish.glb'),use_selection=True,export_format='GLB')
scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=32;scene.render.resolution_x=1000;scene.render.resolution_y=800;scene.render.resolution_percentage=100;scene.world.color=(.22,.22,.22);scene.view_settings.view_transform='AgX'
for name,loc,power in [('Key',(4,4,6),500),('Fill',(-4,1,3),300),('Rim',(0,-4,5),500)]:
 d=bpy.data.lights.new(name,'AREA');d.energy=power;d.size=4;o=bpy.data.objects.new(name,d);scene.collection.objects.link(o);o.location=loc;o.rotation_euler=(-o.location).to_track_quat('-Z','Y').to_euler()
c=bpy.data.cameras.new('Review');cam=bpy.data.objects.new('Review',c);scene.collection.objects.link(cam);scene.camera=cam;c.type='ORTHO';c.ortho_scale=4
for name,loc in [('side',(4,0,1.5)),('opposite',(-4,0,1.5)),('front',(0,4,1)),('top',(0,0,5))]:
 cam.location=loc;cam.rotation_euler=(-cam.location).to_track_quat('-Z','Y').to_euler();scene.render.filepath=str(OUT/(name+'.png'));bpy.ops.render.render(write_still=True)
pose=rig.pose.bones[rigcfg['tail_bone']];pose.rotation_mode='XYZ';pose.rotation_euler.z=math.radians(rigcfg['review_wag_degrees']);bpy.context.view_layer.update()
cam.location=(0,0,5);cam.rotation_euler=(-cam.location).to_track_quat('-Z','Y').to_euler();scene.render.filepath=str(OUT/'tail_pose_top.png');bpy.ops.render.render(write_still=True);pose.rotation_euler.z=0;bpy.context.view_layer.update()
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'PearlPondFish.blend'))
bpy.ops.wm.open_mainfile(filepath=str(OUT/'PearlPondFish.blend'))
images=[{'name':i.name,'size':list(i.size)} for i in bpy.data.images if i.packed_file];assert images and all(i['size']==[C['texture_resolution']]*2 for i in images)
report={'triangles':triangles,'dimensions_roblox_xyz':native,'pivot':'center','native_forward_expected':'-Z','bones':[b.name for b in bpy.data.armatures['PondFishRig'].bones],'animation_clips':len(bpy.data.actions),'packed_images':images,'native_validation':'pending root-owned insertion and tail deformation check'}
(OUT/'report.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report))
