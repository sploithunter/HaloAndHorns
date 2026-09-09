"""Blender-only cleanup, fixed-envelope source/FBX export, UV seam guard and 4 views.
Run from repo root: Blender --background --python .../prepare_asset.py
Input is accepted Meshy textured GLB. No API, credentials, Studio or uploads.
"""
import bpy, json, math, importlib.util, argparse, sys
from pathlib import Path
from mathutils import Vector, Matrix
ROOT=Path.cwd()
C=json.loads((ROOT/'configs/crossroads_fossil.json').read_text())
parser=argparse.ArgumentParser();parser.add_argument('--input',default=C['source_dir']+'/textured/model.glb');parser.add_argument('--output',default=C['source_dir']+'/final_v2');args=parser.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [])
OUT=ROOT/args.output
OUT.mkdir(parents=True,exist_ok=True)
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
source=ROOT/args.input
if not source.exists() and args.input==C['source_dir']+'/textured/model.glb':
 source=ROOT/C['source_dir']/'final_v2/CrossroadsFossil.blend'
if source.suffix=='.blend':
 assert source.resolve()!= (OUT/'CrossroadsFossil.blend').resolve(),'Use --output with a new directory when rebuilding the retained blend'
 with bpy.data.libraries.load(str(source),link=False) as (available,loaded):
  loaded.objects=['CrossroadsFossil']
 for loaded_object in loaded.objects:
  if loaded_object is not None:bpy.context.scene.collection.objects.link(loaded_object)
else:
 bpy.ops.import_scene.gltf(filepath=str(source))
meshes=[o for o in bpy.context.scene.objects if o.type=='MESH']
assert meshes,'No meshes'
bpy.ops.object.select_all(action='DESELECT')
for o in meshes:o.select_set(True)
bpy.context.view_layer.objects.active=meshes[0]
bpy.ops.object.join(); obj=bpy.context.object
obj.name='CrossroadsFossil';obj.data.name='CrossroadsFossil'
bpy.ops.object.transform_apply(location=False,rotation=True,scale=True)
world=[obj.matrix_world@Vector(v) for v in obj.bound_box]
lo=Vector(tuple(min(v[i] for v in world) for i in range(3)))
hi=Vector(tuple(max(v[i] for v in world) for i in range(3)))
size=hi-lo
# Roblox XYZ envelope [width,height,depth] -> Blender XYZ [width,depth,height].
limits=C['max_size_xyz']; factor=min(limits[0]/size.x,limits[2]/size.y,limits[1]/size.z)
for v in obj.data.vertices:
 p=obj.matrix_world@v.co
 v.co=Vector(((p.x-(lo.x+hi.x)/2)*factor,(p.y-(lo.y+hi.y)/2)*factor,(p.z-lo.z)*factor))
obj.matrix_world=Matrix.Identity(4)
obj.data.update()
bpy.context.view_layer.update()
# Texture UVs stay unchanged. Re-split seam vertices after import, before FBX.
spec=importlib.util.spec_from_file_location('rebake_helpers',ROOT/'scripts/blender/rebake_for_roblox.py')
helpers=importlib.util.module_from_spec(spec);spec.loader.exec_module(helpers)
seams=helpers.split_uv_seams(obj) if obj.data.uv_layers.active else 0
textures=[]
# Packed GLTF images retain their original bytes after scale/save. Load the saved
# PNG into a NEW image datablock and bind that image before packing/exporting.
image_nodes=[node for material in obj.data.materials if material and material.use_nodes
 for node in material.node_tree.nodes if node.type=='TEX_IMAGE' and node.image]
originals=list(dict.fromkeys(node.image for node in image_nodes))
for i,img in enumerate(originals):
 dest=OUT/f'texture_{i}.png'
 colorspace=img.colorspace_settings.name
 if max(img.size)>C['texture_resolution']:
  ratio=C['texture_resolution']/max(img.size)
  img.scale(max(1,round(img.size[0]*ratio)),max(1,round(img.size[1]*ratio)))
 img.filepath_raw=str(dest);img.file_format='PNG';img.save()
 fresh=bpy.data.images.load(str(dest),check_existing=False)
 fresh.colorspace_settings.name=colorspace
 assert list(fresh.size)==[C['texture_resolution']]*2,list(fresh.size)
 for node in image_nodes:
  if node.image==img:node.image=fresh
 fresh.pack()
 assert fresh.packed_file is not None
 if img.users==0:bpy.data.images.remove(img)
 textures.append(dest.name)
obj.data.calc_loop_triangles();triangles=len(obj.data.loop_triangles)
assert triangles<=C['max_triangles'],triangles
assert triangles==6952,'Texture-only revision must preserve accepted geometry'
# Archive editable mesh with original material slots and packed texture maps.
scene=bpy.context.scene
scene.render.engine='CYCLES';scene.cycles.samples=32
scene.render.resolution_x=1024;scene.render.resolution_y=1024;scene.render.resolution_percentage=100
scene.world.color=(0.22,0.22,0.22)
scene.view_settings.view_transform='AgX'
scene.render.image_settings.file_format='PNG'
scene.render.film_transparent=False
center=Vector((0,0,obj.dimensions.z/2))
for name,loc,energy,size in [('Key',(-7,-7,12),1500,7),('Fill',(8,-2,8),1000,6),('Rim',(1,8,10),1500,5)]:
 data=bpy.data.lights.new(name,'AREA');data.energy=energy;data.shape='DISK';data.size=size
 light=bpy.data.objects.new(name,data);scene.collection.objects.link(light);light.location=loc;light.rotation_euler=(center-light.location).to_track_quat('-Z','Y').to_euler()
camdata=bpy.data.cameras.new('ReviewCamera');cam=bpy.data.objects.new('ReviewCamera',camdata);scene.collection.objects.link(cam)
camdata.type='ORTHO';camdata.ortho_scale=max(obj.dimensions)*1.45;scene.camera=cam
bpy.ops.object.select_all(action='DESELECT');obj.select_set(True);bpy.context.view_layer.objects.active=obj
helpers.export_fbx(obj,OUT/'CrossroadsFossil.fbx')
bpy.ops.export_scene.gltf(filepath=str(OUT/'CrossroadsFossil.glb'),use_selection=True,export_format='GLB')
report={'name':obj.name,'triangles':triangles,'mesh_objects':1,'material_slots':len(obj.data.materials),'dimensions_blender_xyz':list(obj.dimensions),'dimensions_roblox_xyz':[obj.dimensions.x,obj.dimensions.z,obj.dimensions.y],'pivot':'bottom_center','uv_seam_edges_split':seams,'textures':textures,'config':str(C['generator']),'native_validation':'pending root-owned asset-only inspection'}
(OUT/'report.json').write_text(json.dumps(report,indent=2)+'\n')
for name,loc in [('front',(0,-15,8)),('right',(15,0,8)),('back',(0,15,8)),('left',(-15,0,8)),('hero',(11,-15,10))]:
 cam.location=loc;cam.rotation_euler=(center-cam.location).to_track_quat('-Z','Y').to_euler()
 scene.render.filepath=str(OUT/f'{name}.png');bpy.ops.render.render(write_still=True)
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'CrossroadsFossil.blend'))
print(json.dumps(report))

# Reopen from disk: in-memory scaled pixels are insufficient validation.
bpy.ops.wm.open_mainfile(filepath=str(OUT/'CrossroadsFossil.blend'))
packed=[{'name':img.name,'size':list(img.size),'packed':img.packed_file is not None}
 for img in bpy.data.images if img.packed_file is not None]
assert packed and all(i['size']==[C['texture_resolution']]*2 for i in packed),packed
(OUT/'packed_texture_check.json').write_text(json.dumps({'reopened_blend':True,'images':packed},indent=2)+'\n')
print('REOPENED_PACKED_TEXTURE_PASS',json.dumps(packed))
