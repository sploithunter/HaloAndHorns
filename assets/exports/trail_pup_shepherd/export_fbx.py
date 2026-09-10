import bpy,sys,json
from pathlib import Path
from mathutils import Vector
root=Path(sys.argv[sys.argv.index('--')+1]).resolve()
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
bpy.ops.import_scene.gltf(filepath=str(root/'model.glb'))
objs=[o for o in bpy.context.scene.objects if o.type=='MESH']
bpy.ops.object.select_all(action='DESELECT')
for o in objs:o.select_set(True)
bpy.context.view_layer.objects.active=objs[0];bpy.ops.object.join();o=bpy.context.object
bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
verts=[v.co.copy() for v in o.data.vertices];lo=Vector(tuple(min(v[i] for v in verts) for i in range(3)));hi=Vector(tuple(max(v[i] for v in verts) for i in range(3)));center=(lo+hi)/2
factor=1/max(hi-lo)
for v in o.data.vertices:v.co=(v.co-center)*factor
for mat in o.data.materials:
 for n in mat.node_tree.nodes:
  if n.type=='TEX_IMAGE' and n.image and n.image.colorspace_settings.name=='sRGB':
   n.image.filepath_raw=str(root/'albedo.png');n.image.file_format='PNG';n.image.save()
bpy.ops.export_scene.fbx(filepath=str(root/'trail_pup.fbx'),use_selection=True,object_types={'MESH'},apply_scale_options='FBX_SCALE_ALL',axis_forward='-Z',axis_up='Y',bake_space_transform=True,path_mode='COPY',embed_textures=False)
(root/'export.json').write_text(json.dumps({'original_bounds':[list(lo),list(hi)],'scale':factor,'triangles':sum(len(p.vertices)-2 for p in o.data.polygons)},indent=2))
