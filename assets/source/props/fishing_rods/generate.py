"""Precision-built fishing props, source-first; no network or Studio side effects."""
import bpy, bmesh, json, math
from pathlib import Path
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[4]
HERE=Path(__file__).resolve().parent
OUT=ROOT/'assets/exports/props/fishing_rods'
R=json.loads((HERE/'recipe.json').read_text())
all_reports={}

def clear():
 bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)

def cylinder(name,a,b,r1,r2,mat):
 a,b=Vector(a),Vector(b)
 bpy.ops.mesh.primitive_cone_add(vertices=R['sides'],radius1=r1,radius2=r2,depth=(b-a).length,end_fill_type='NGON',location=(a+b)/2)
 o=bpy.context.object;o.name=name;o.rotation_euler=(b-a).to_track_quat('Z','Y').to_euler();o.data.materials.append(mat);return o

def torus(name,at,major,minor,mat,rotate=(0,0,0)):
 bpy.ops.mesh.primitive_torus_add(major_segments=R['ring_segments'],minor_segments=R['ring_tube_segments'],location=at,major_radius=major,minor_radius=minor,rotation=rotate)
 o=bpy.context.object;o.name=name;o.data.materials.append(mat);return o

def curve_tube(name,points,radii,mat):
 verts=[];faces=[];s=R['sides']
 for p,r in zip(points,radii):
  for j in range(s):
   a=j*math.tau/s;verts.append((p[0]+r*math.cos(a),p[1]+r*math.sin(a),p[2]))
 for k in range(len(points)-1):
  for j in range(s):faces.append((k*s+j,k*s+(j+1)%s,(k+1)*s+(j+1)%s,(k+1)*s+j))
 faces.append(tuple(reversed(range(s))));faces.append(tuple((len(points)-1)*s+j for j in range(s)))
 m=bpy.data.meshes.new(name);m.from_pydata(verts,[],faces);m.update();o=bpy.data.objects.new(name,m);bpy.context.collection.objects.link(o);o.data.materials.append(mat);return o

def aim(o,target):o.rotation_euler=(Vector(target)-o.location).to_track_quat('-Z','Y').to_euler()
for realm in ('heaven','hell'):
 clear();folder=OUT/realm;folder.mkdir(parents=True,exist_ok=True)
 palette=R['palettes'][realm]
 image=bpy.data.images.new(realm+'_rod_palette',width=256,height=256,alpha=True)
 pixels=[]
 for y in range(256):
  for x in range(256):
   c=palette[x//64];grain=1+0.025*math.sin(y*0.7+x*0.21)+0.013*math.cos(x*1.9)
   pixels.extend([min(1,v*grain) for v in c]+[1])
 image.pixels=pixels;image.filepath_raw=str(folder/(realm+'_albedo.png'));image.file_format='PNG';image.save();image.pack()
 mats=[]
 for i,title in enumerate(('IvoryBone','Metal','Grip','Accent')):
  m=bpy.data.materials.new(realm+'_'+title);m.use_nodes=True;p=m.node_tree.nodes.get('Principled BSDF');p.inputs['Metallic'].default_value=0.72 if i==1 else 0.05;p.inputs['Roughness'].default_value=0.30 if i==1 else 0.52
  tex=m.node_tree.nodes.new('ShaderNodeTexImage');tex.image=image;m.node_tree.links.new(tex.outputs['Color'],p.inputs['Base Color']);m.diffuse_color=(*palette[i],1);mats.append(m)
 grip=R['grip'];cylinder('Grip', (0,0,grip['bottom']),(0,0,grip['top']),grip['radius'],grip['radius']*.90,mats[2])
 cylinder('ButtPommel',(0,0,0),(0,0,.12),.11,.12,mats[1])
 for j in range(grip['wrap_count']):
  z=.15+j*.081;torus('GripBinding',(0,0,z),.105,.009,mats[1] if j in (0,8) else mats[2])
 shaft=R['shaft'];points=[];radii=[]
 for i in range(shaft['segments']+1):
  t=i/shaft['segments'];points.append((shaft['curve_x']*t*t,shaft['curve_y']*t*t,shaft['bottom']+(shaft['top']-shaft['bottom'])*t));radii.append(shaft['radii'][0]*(1-t)+shaft['radii'][1]*t)
 curve_tube('TaperedShaft',points,radii,mats[0])
 for z in (1.0,1.48,2.4,3.65):
  t=(z-shaft['bottom'])/(shaft['top']-shaft['bottom']);x=shaft['curve_x']*t*t;y=shaft['curve_y']*t*t;r=shaft['radii'][0]*(1-t)+shaft['radii'][1]*t
  cylinder('Ferrule',(x,y,z-.055),(x,y,z+.055),r+.018,r+.018,mats[1])
 reel=R['reel'];rx,ry,rz=reel['center'];rad=reel['radius']
 cylinder('ReelMount',(0,0,1.16),(rx,ry,rz),.065,.065,mats[1])
 cylinder('ReelSpool',(rx,ry-.075,rz),(rx,ry+.075,rz),rad*.65,rad*.65,mats[2])
 for side in (-1,1):
  torus('ReelRim',(rx,ry+side*reel['depth']/2,rz),rad,.022,mats[1],(math.pi/2,0,0))
  for j in range(reel['spoke_count']):
   a=j*math.tau/reel['spoke_count'];cylinder('ReelSpoke',(rx+.07*math.cos(a),ry+side*.1,rz+.07*math.sin(a)),(rx+rad*math.cos(a),ry+side*.1,rz+rad*math.sin(a)),.016,.016,mats[1])
 cylinder('ReelAxle',(rx,ry-.15,rz),(rx,ry+.15,rz),.043,.043,mats[1])
 cylinder('ReelCrank',(0,ry-.15,rz),(.19,ry-.18,rz-.11),.025,.025,mats[1]);cylinder('CrankKnob',(.19,ry-.18,rz-.11),(.19,ry-.28,rz-.11),.048,.04,mats[2])
 for z,major in R['guides']:
  t=(z-shaft['bottom'])/(shaft['top']-shaft['bottom']);x=shaft['curve_x']*t*t;y=shaft['curve_y']*t*t
  cylinder('GuideStem',(x,y,z),(x,y-.11,z),.012,.012,mats[1]);torus('LineEyelet',(x,y-.11,z),major,.011,mats[1])
 # Small rigid ornament leaves/horns are separate watertight components, no baked line.
 if realm=='heaven':
  for side in (-1,1):
   for j in range(3):
    z=1.45+j*.12;x=side*(.11+j*.05)
    curve_tube('FeatherFinial',[(side*.05,.04,z),(x,.045,z+.17),(side*(.16+j*.06),.04,z+.34)],[.027,.038,.002],mats[0])
 else:
  for side in (-1,1):
   curve_tube('BoneShoulder',[(side*.06,.03,1.38),(side*.17,.025,1.54),(side*.22,.01,1.76),(side*.13,0,1.96)],[.045,.046,.029,.003],mats[0])
 torus('AccentCollar',(0,0,1.43),.09,.018,mats[3])
 meshes=[o for o in bpy.context.scene.objects if o.type=='MESH']
 # Smart unwrap each closed component, pack each material inside a padded atlas stripe.
 for o in meshes:
  bpy.ops.object.select_all(action='DESELECT');o.select_set(True);bpy.context.view_layer.objects.active=o;bpy.ops.object.transform_apply(location=False,rotation=True,scale=True)
  bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='SELECT');bpy.ops.uv.smart_project(angle_limit=1.15,island_margin=.02);bpy.ops.object.mode_set(mode='OBJECT')
  index=mats.index(o.data.materials[0]);uv=o.data.uv_layers.active
  for v in uv.data:v.uv.x=(index+.05+.90*v.uv.x)/4;v.uv.y=.05+.9*v.uv.y
  for poly in o.data.polygons:poly.use_smooth=True
 # Join into semantic groups, keeping visible editing structure and separate future reel.
 families={'Grip':[],'Reel':[],'Guides':[],'Shaft':[],'Ornaments':[]}
 for o in meshes:
  name=o.name
  key='Reel' if name.startswith(('Reel','Crank')) else 'Guides' if name.startswith(('Guide','LineEyelet')) else 'Grip' if name.startswith(('Grip','Butt')) else 'Shaft' if name.startswith(('Tapered','Ferrule')) else 'Ornaments'
  families[key].append(o)
 exports=[]
 for key,objects in families.items():
  bpy.ops.object.select_all(action='DESELECT')
  for o in objects:o.select_set(True)
  bpy.context.view_layer.objects.active=objects[0];bpy.ops.object.join();o=bpy.context.object;o.name=realm.title()+'Rod_'+key
  bpy.context.scene.cursor.location=(0,0,0);bpy.ops.object.origin_set(type='ORIGIN_CURSOR');exports.append(o)
 for name,location in R['attachments_blender'].items():
  o=bpy.data.objects.new(name,None);bpy.context.collection.objects.link(o);o.location=location;o.empty_display_size=.15
 # Maintain editable source. Export vertex-split copies separately for Open Cloud UV fidelity.
 bpy.ops.wm.save_as_mainfile(filepath=str(folder/(realm+'.blend')))
 total=0;component=[]
 for o in exports:
  o.data.calc_loop_triangles();tri=len(o.data.loop_triangles);total+=tri;component.append({'name':o.name,'triangles':tri})
 bounds=[o.matrix_world@Vector(c) for o in exports for c in o.bound_box]
 low=[min(v[i] for v in bounds) for i in range(3)];high=[max(v[i] for v in bounds) for i in range(3)]
 report={'realm':realm,'triangles':total,'components':component,'bounds_blender':{'min':low,'max':high,'size':[high[i]-low[i] for i in range(3)]},'attachments_blender':R['attachments_blender'],'uv':'Smart-projected, padded material-stripe atlas; FBX copy splits per-corner vertices','source_units':'1 Blender unit = intended 1 stud','rigged':False}
 (folder/'geometry.json').write_text(json.dumps(report,indent=2)+'\n');all_reports[realm]=report
 bpy.ops.object.select_all(action='DESELECT')
 for o in exports:o.select_set(True)
 bpy.ops.export_scene.gltf(filepath=str(folder/(realm+'.glb')),export_format='GLB',use_selection=True,export_apply=True)
 # OpenCloud FBX can collapse per-corner UVs: separate every polygon corner in upload mesh.
 for o in exports:
  old=o.data;verts=[];faces=[];uvs=[];normals=[];mi=[]
  for poly in old.polygons:
   face=[]
   for li in poly.loop_indices:
    face.append(len(verts));verts.append(tuple(old.vertices[old.loops[li].vertex_index].co));uvs.append(tuple(old.uv_layers.active.data[li].uv));normals.append(tuple(old.corner_normals[li].vector))
   faces.append(face);mi.append(poly.material_index)
  me=bpy.data.meshes.new(old.name+'_Upload');me.from_pydata(verts,[],faces);me.update();layer=me.uv_layers.new()
  for mat in old.materials:me.materials.append(mat)
  for poly,index in zip(me.polygons,mi):
   poly.material_index=index;poly.use_smooth=True
   for li in poly.loop_indices:layer.data[li].uv=uvs[me.loops[li].vertex_index]
  me.normals_split_custom_set_from_vertices(normals);o.data=me
 bpy.ops.export_scene.fbx(filepath=str(folder/(realm+'.fbx')),use_selection=True,object_types={'MESH'},apply_scale_options='FBX_SCALE_ALL',mesh_smooth_type='FACE',path_mode='COPY',embed_textures=True,axis_forward='-Z',axis_up='Y',bake_anim=False)
 # Review camera and lighting are excluded from assets.
 scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=R['render']['samples'];scene.render.resolution_x=R['render']['width'];scene.render.resolution_y=R['render']['height'];scene.render.resolution_percentage=100
 scene.world.color=(.20,.20,.20);scene.render.image_settings.file_format='PNG'
 bpy.ops.object.camera_add(location=(6,-12,4));camera=bpy.context.object;camera.data.type='ORTHO';camera.data.ortho_scale=6.3;aim(camera,(0,0,2.75));scene.camera=camera
 for pos,power,size in [((3,-5,8),750,5),((-4,-1,4),500,4),((2,4,6),900,3)]:
  bpy.ops.object.light_add(type='AREA',location=pos);light=bpy.context.object;light.data.energy=power;light.data.shape='DISK';light.data.size=size;aim(light,(0,0,2.5))
 scene.render.film_transparent=True;scene.render.filepath=str(folder/'review.png');bpy.ops.render.render(write_still=True)
(ROOT/'assets/manifest/realm_crossroads_fishing_rods.json').write_text(json.dumps({'schema_version':1,'status':'local_source_generated','creator_group_id':15872767,'provenance':'Original precise Blender geometry; no external model or generated image used.','models':all_reports},indent=2)+'\n')
print('FISHING_RODS_GENERATED',json.dumps({k:v['triangles'] for k,v in all_reports.items()}))
