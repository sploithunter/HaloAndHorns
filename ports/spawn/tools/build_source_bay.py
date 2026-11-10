"""Blender conversion of config-owned Studio placements and exported mesh/image content."""
import json,sys,pathlib,struct,math
import bpy
from mathutils import Matrix,Vector
ROOT=pathlib.Path(__file__).resolve().parents[3]
root=pathlib.Path(sys.argv[sys.argv.index('--')+1])
tuning=json.loads((ROOT/'configs/spawn_merge_bay.json').read_text())['scene']
parts=json.loads((ROOT/'configs/spawn_merge_source_bay.json').read_text())['parts']
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
C=Matrix(((0,0,1),(1,0,0),(0,1,0)));scale=tuning['sourceTransform']['metersPerStud'];origin=Vector(tuning['sourceTransform']['origin'])
def position(v):return C@(Vector(v)-origin)*scale
meshcache={};materialcache={}
def image(t):
 p=root/(str(t).split('//')[-1]+'.png')
 return bpy.data.images.load(str(p),check_existing=True) if p.exists() else None
def material(part):
 key=json.dumps({k:part.get(k) for k in ('mesh','texture','surface','color','material','transparency')},sort_keys=True)
 if key in materialcache:return materialcache[key]
 m=bpy.data.materials.new('HH_'+part['name']+'_'+str(len(materialcache)));m.use_nodes=True;n=m.node_tree.nodes;links=m.node_tree.links;p=n.get('Principled BSDF')
 p.inputs['Base Color'].default_value=(*part['color'],1-part['transparency']);p.inputs['Roughness'].default_value=.38 if part['material']=='Marble' else .7
 if part['material'] in ('Metal','DiamondPlate'):p.inputs['Metallic'].default_value=.65
 if part['material']=='Neon':p.inputs['Emission Color'].default_value=(*part['color'],1);p.inputs['Emission Strength'].default_value=.5
 surf=part.get('surface') or {};tex=image(surf.get('color') or part.get('texture'))
 if tex:
  node=n.new('ShaderNodeTexImage');node.image=tex;links.new(node.outputs['Color'],p.inputs['Base Color']);links.new(node.outputs['Alpha'],p.inputs['Alpha'])
  m.surface_render_method='DITHERED'
 for channel,socket in [('roughness','Roughness'),('metalness','Metallic')]:
  tex=image(surf.get(channel))
  if tex:
   tex.colorspace_settings.name='Non-Color';node=n.new('ShaderNodeTexImage');node.image=tex;links.new(node.outputs['Color'],p.inputs[socket])
 tex=image(surf.get('normal'))
 if tex:
  tex.colorspace_settings.name='Non-Color';node=n.new('ShaderNodeTexImage');node.image=tex;normal=n.new('ShaderNodeNormalMap');links.new(node.outputs['Color'],normal.inputs['Color']);links.new(normal.outputs['Normal'],p.inputs['Normal'])
 materialcache[key]=m;return m
for i,part in enumerate(parts):
 mat=material(part)
 if part.get('mesh'):
  mid=part['mesh'].split('//')[-1];key=(mid,mat.name)
  if key not in meshcache:
   raw=(root/(mid+'.bin')).read_bytes();values=list(struct.iter_unpack('<8f',raw));meta=json.load(open(root/(mid+'.json')));center=Vector(meta['center'])
   verts=[C@(Vector(v[:3])-center) for v in values];faces=[(n,n+1,n+2) for n in range(0,len(verts),3)]
   mesh=bpy.data.meshes.new(mid);mesh.from_pydata(verts,[],faces);mesh.update();uv=mesh.uv_layers.new(name='UVMap')
   for j,v in enumerate(values):uv.data[j].uv=(v[6],1-v[7])
   mesh.normals_split_custom_set_from_vertices([C@Vector(v[3:6]) for v in values]);mesh.materials.append(mat);meshcache[key]=mesh
  obj=bpy.data.objects.new(part['name'],meshcache[key]);bpy.context.collection.objects.link(obj)
  ratio=[part['size'][k]/part['meshSize'][k] for k in range(3)]
 elif part.get('shape')=='Ball':
  bpy.ops.mesh.primitive_uv_sphere_add(segments=12,ring_count=8,radius=.5);obj=bpy.context.object;ratio=part['size'];obj.data.materials.append(mat)
 elif part['class']=='WedgePart':
  mesh=bpy.data.meshes.new(part['name']);mesh.from_pydata([(-.5,-.5,-.5),(.5,-.5,-.5),(-.5,.5,-.5),(.5,.5,-.5),(-.5,.5,.5),(.5,.5,.5)],[],[(0,1,3,2),(2,3,5,4),(0,2,4),(1,5,3),(0,4,5,1)])
  # Wedge vertices are in Roblox local space; convert before object transform.
  for v in mesh.vertices:v.co=C@v.co
  obj=bpy.data.objects.new(part['name'],mesh);bpy.context.collection.objects.link(obj);ratio=part['size'];obj.data.materials.append(mat)
 else:
  bpy.ops.mesh.primitive_cube_add(size=1);obj=bpy.context.object;ratio=part['size'];obj.data.materials.append(mat)
 cf=part['cf'];R=Matrix([cf[3:6],cf[6:9],cf[9:12]])
 obj.matrix_world=(C@R@Matrix.Diagonal(Vector(ratio))*scale@C.inverted()).to_4x4();obj.location=position(cf[:3]);obj['hh_group']=part.get('mesh','architecture').split('//')[-1];obj.name=part['path'].split('GeneratedMap_MergeEggVoxel.')[-1]
 if i%50==0:print('part',i,flush=True)
# Terrain heightfield is a sampled read of the authored Studio terrain, not an invented boundary.
terrainfile=ROOT/'configs/spawn_merge_source_terrain.json'
if terrainfile.exists():
 t=json.load(open(terrainfile));verts=[];faces=[]
 for x in range(t['nx']):
  for z in range(t['nz']):verts.append(position((t['x0']+(x+.5)*4,t['heights'][x*t['nz']+z],t['z0']+(z+.5)*4)))
 for x in range(t['nx']-1):
  for z in range(t['nz']-1):
   k=x*t['nz']+z;faces.append((k,k+t['nz'],k+t['nz']+1,k+1))
 mesh=bpy.data.meshes.new('StudioTerrain');mesh.from_pydata(verts,[],faces);obj=bpy.data.objects.new('StudioTerrain',mesh);bpy.context.collection.objects.link(obj)
 m=bpy.data.materials.new('StudioTerrain_Grass');m.diffuse_color=(*t['grassColor'],1);mesh.materials.append(m)
points=[o.matrix_world@Vector(v) for o in bpy.context.scene.objects if o.type=='MESH' for v in o.bound_box]
lo=[min(p[i] for p in points) for i in range(3)];hi=[max(p[i] for p in points) for i in range(3)]
# Blender X/Y/Z is glTF X/-Z/Y. Spawn's feet pivot centers XZ and rests at min Y.
feet={'x':(lo[0]+hi[0])/2,'y':lo[2],'z':-(lo[1]+hi[1])/2}
(root/'bay-placement.json').write_text(json.dumps({'feetPosition':feet,'boundsBlender':{'min':lo,'max':hi}},indent=2))
groups={}
for obj in bpy.context.scene.objects:
 if obj.type=='MESH':groups.setdefault(obj.get('hh_group','terrain'),[]).append(obj)
manifest=[]
for identity,objects in groups.items():
 bpy.ops.object.select_all(action='DESELECT')
 for obj in objects:obj.select_set(True)
 points=[obj.matrix_world@Vector(v) for obj in objects for v in obj.bound_box]
 lo=[min(p[i] for p in points) for i in range(3)];hi=[max(p[i] for p in points) for i in range(3)]
 feet={'x':(lo[0]+hi[0])/2,'y':lo[2],'z':-(lo[1]+hi[1])/2}
 output=root/(identity+'-placed.glb')
 bpy.ops.export_scene.gltf(filepath=str(output),export_format='GLB',use_selection=True,export_animations=False)
 manifest.append({'group':identity,'feetPosition':feet,'sourceFile':str(output),'parts':len(objects)})
(root/'groups.json').write_text(json.dumps(manifest,indent=2))
print('EXPORTED',len(manifest),'groups')
