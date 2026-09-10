"""Reproducible Meshy-derived fountain refinement. Run with Blender --background --python."""
import bpy, bmesh, math, json, numpy as np
from pathlib import Path
from mathutils import Vector
from mathutils.bvhtree import BVHTree
ROOT=Path(__file__).resolve().parents[4]
CFG=json.loads((ROOT/'configs/confluence_fountain.json').read_text())
SRC=ROOT/'assets/source/props/confluence/textured/model.glb'
OUT=ROOT/CFG['export_directory'];OUT.mkdir(parents=True,exist_ok=True)
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
bpy.ops.import_scene.gltf(filepath=str(SRC));obj=next(o for o in bpy.context.scene.objects if o.type=='MESH')
bpy.context.view_layer.objects.active=obj;bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
verts=[v.co for v in obj.data.vertices];lo=Vector([min(v[i] for v in verts) for i in range(3)]);hi=Vector([max(v[i] for v in verts) for i in range(3)])
scale=CFG['diameter_studs']/max(hi.x-lo.x,hi.y-lo.y);sz=min(scale,CFG['height_limit_studs']*.975/(hi.z-lo.z))
for v in obj.data.vertices:v.co=Vector(((v.co.x-(hi.x+lo.x)/2)*scale,(v.co.y-(hi.y+lo.y)/2)*scale,(v.co.z-lo.z)*sz))
obj.data.update()
original=next(i for i in bpy.data.images if i.size[0]==2048)
a=np.array(original.pixels[:],dtype=np.float32).reshape(2048,2048,4)
a=a.reshape(1024,2,1024,2,4).mean(axis=(1,3))
def save_image(name,data):
 h,w,_=data.shape;im=bpy.data.images.new(name,width=w,height=h,alpha=True);im.pixels.foreach_set(data.ravel());im.filepath_raw=str(OUT/(name+'.png'));im.file_format='PNG';im.save();return im
ivory=save_image('Confluence_Ivory',a)
b=a.copy();b[:,:,:3]*=np.array([.19,.17,.19]);obsidian=save_image('Confluence_Obsidian',b)
b=a.copy();b[:,:,:3]*=np.array([1,.74,.34]);gold=save_image('Confluence_Gold',b)
y,x=np.mgrid[0:1024,0:1024].astype(float)/1024
wave=np.sin(x*92+np.sin(y*32)*2)+np.sin(y*91+np.sin(x*27)*2)
caustic=np.exp(-abs(wave)*9)
water=np.ones((1024,1024,4),np.float32);water[:,:,:3]=np.array([.10,.47,.61])+caustic[:,:,None]*np.array([.38,.41,.34]);wat=save_image('Confluence_Water',water)
vein=np.exp(-abs(np.sin(x*139+np.sin(y*83)*1.8)+np.sin(y*143+np.sin(x*79)*1.7))*7)
lava=np.ones((1024,1024,4),np.float32);lava[:,:,:3]=np.array([.10,.018,.008])+vein[:,:,None]*np.array([.9,.28,.016]);lav=save_image('Confluence_Lava',lava)
def material(name,im,metal=0,rough=.55,emit=0):
 m=bpy.data.materials.new(name);m.use_nodes=True;n=m.node_tree.nodes;p=n.get('Principled BSDF');p.inputs['Metallic'].default_value=metal;p.inputs['Roughness'].default_value=rough;t=n.new('ShaderNodeTexImage');t.image=im;m.node_tree.links.new(t.outputs['Color'],p.inputs['Base Color'])
 if emit:m.node_tree.links.new(t.outputs['Color'],p.inputs['Emission Color']);p.inputs['Emission Strength'].default_value=emit
 return m
mats={'Heaven':material('Ivory carved stone',ivory,.08,.68),'Hell':material('Obsidian carved stone',obsidian,.16,.73),'Crown':material('Aged halo gold',gold,.65,.32),'Water':material('Pearl flowing water',wat,.12,.23,.12),'Lava':material('Molten lava',lav,.05,.4,1.7)}
uv=obj.data.uv_layers.active.data
source_normals=[n.vector.copy() for n in obj.data.corner_normals]
buckets={}
for p in obj.data.polygons:
 c=p.center;side='Heaven' if c.x<0 else 'Hell';r=math.hypot(c.x,c.y)
 if c.z>5.1:name='Crown'
 elif c.z<1:name=side+'_Foundation'
 elif r<8.8 and c.z>2.5:name=side+'_Spillways'
 elif r>9.4 and c.z>2.5:name=side+'_RimOrnaments'
 else:name=side+'_Basin'
 buckets.setdefault(name,[]).append(p)
 # Thin fluid skins copied only from broad upward-facing inner terrace floors.
 if r<9.2 and r>2.1 and p.normal.z>.84 and max(obj.data.vertices[i].co.z for i in p.vertices)-min(obj.data.vertices[i].co.z for i in p.vertices)<.23 and max(math.hypot(obj.data.vertices[i].co.x,obj.data.vertices[i].co.y) for i in p.vertices)<9.6 and (2.10<c.z<2.42 or 2.68<c.z<2.91 or 3.66<c.z<3.91):
  buckets.setdefault('Water_Surface' if c.x<0 else 'Lava_Surface',[]).append(p)
assets=[]
def build(name,polys):
 fluid=name.startswith(('Water','Lava'));v=[];faces=[];tex=[];normals=[]
 for p in polys:
  inds=[]
  for li in p.loop_indices:
   co=obj.data.vertices[obj.data.loops[li].vertex_index].co.copy();co.z+=.028 if fluid else 0;inds.append(len(v));v.append(co)
   normals.append(tuple(source_normals[li]))
   tex.append(((co.x+11)/22,(co.y+11)/22) if fluid else tuple(uv[li].uv))
  faces.append(inds)
 mesh=bpy.data.meshes.new('Confluence_'+name);mesh.from_pydata(v,[],faces);mesh.update();layer=mesh.uv_layers.new()
 for p in mesh.polygons:
  p.use_smooth=not fluid
  for li in p.loop_indices:layer.data[li].uv=tex[mesh.loops[li].vertex_index]
 mesh.normals_split_custom_set(normals)
 o=bpy.data.objects.new('Confluence_'+name,mesh);bpy.context.collection.objects.link(o);key='Water' if name.startswith('Water') else 'Lava' if name.startswith('Lava') else 'Crown' if name=='Crown' else name.split('_')[0];mesh.materials.append(mats[key]);assets.append(o)
for name,polys in buckets.items():
 if not name.startswith(('Water','Lava')):build(name,polys)
# Curved thin sheets follow actual descending Meshy terrace edges; these are separate meshes.
bvh=BVHTree.FromObject(obj,bpy.context.evaluated_depsgraph_get())
def top(r,a):
 loc,n,_,_=bvh.ray_cast(Vector((math.cos(a)*r,math.sin(a)*r,12)),Vector((0,0,-1)))
 return loc.z if loc else None
# Raycast planar pools into the authored basins; prevents triangle-colored walls or fluid holes.
fluid_grids={};grid=.07
for iy in range(-132,132):
 for ix in range(-132,132):
  px=(ix+.5)*grid;py=(iy+.5)*grid;rad=math.hypot(px,py)
  if rad>9.15 or rad<2.08:continue
  hit,normal,_,_=bvh.ray_cast(Vector((px,py,12)),Vector((0,0,-1)))
  if hit is None or normal.z<.7:continue
  level=2.31 if 2.05<hit.z<2.30 else 2.88 if 2.65<hit.z<2.87 and rad<7.7 else 3.89 if 3.65<hit.z<3.88 and rad<5.5 else None
  if level is None:continue
  key=('Water' if px<0 else 'Lava',level);fluid_grids.setdefault(key,[]).append((ix,iy))
for (side,level),cells in fluid_grids.items():
 vs=[];fs=[];keys={}
 for ix,iy in cells:
  face=[]
  for xy in [(ix,iy),(ix+1,iy),(ix+1,iy+1),(ix,iy+1)]:
   if xy not in keys:keys[xy]=len(vs);vs.append((xy[0]*grid,xy[1]*grid,level))
   face.append(keys[xy])
  fs.append(face)
 me=bpy.data.meshes.new(f'Confluence_{side}_Pool_{level}');me.from_pydata(vs,[],fs);me.update()
 bm=bmesh.new();bm.from_mesh(me);bmesh.ops.dissolve_limit(bm,angle_limit=.001,use_dissolve_boundaries=False,verts=list(bm.verts),edges=list(bm.edges));bmesh.ops.triangulate(bm,faces=list(bm.faces));bm.to_mesh(me);bm.free();me.update()
 layer=me.uv_layers.new()
 for p in me.polygons:
  for li in p.loop_indices:
   co=me.vertices[me.loops[li].vertex_index].co;layer.data[li].uv=((co.x+11)/22,(co.y+11)/22)
 o=bpy.data.objects.new(me.name,me);bpy.context.collection.objects.link(o);me.materials.append(mats[side]);assets.append(o)
falls=[]
for deg in [15,165,195,345]:
 angle=math.radians(deg);prev=None;last=-9
 for r in np.arange(2.2,8.8,.16):
  h=top(r,angle)
  if prev and h and .38<prev[1]-h<2 and r-last>.7 and 2<h<4.3:
   rr=float(r-.05);hh=float(prev[1]+.04);bottom=float(h+.04);side='Water' if math.cos(angle)<0 else 'Lava';name=f'Confluence_{side}_Fall_{deg}_{len(falls)}';vv=[];ff=[];tt=[]
   for j in range(13):
    t=j/12;rad=rr+.17*math.sin(t*math.pi/2);height=hh-(hh-bottom)*t
    for k in [-1,1]:
     aa=angle+k*.095;vv.append((math.cos(aa)*rad,math.sin(aa)*rad,height));tt.append(((k+1)/2*.28,t*.07))
    if j:ff.append((2*j-2,2*j-1,2*j+1,2*j))
   me=bpy.data.meshes.new(name);me.from_pydata(vv,[],ff);me.update();layer=me.uv_layers.new()
   for p in me.polygons:
    p.use_smooth=True
    for li in p.loop_indices:layer.data[li].uv=tt[me.loops[li].vertex_index]
   o=bpy.data.objects.new(name,me);bpy.context.collection.objects.link(o);me.materials.append(mats[side]);assets.append(o);falls.append({'name':name,'radius':rr,'angle_degrees':deg,'top':hh,'bottom':bottom});last=r
  prev=(r,h) if h else None
bpy.data.objects.remove(obj,do_unlink=True)
# All export vertices have exactly one UV; no seam welding or post-texture decimation.
bpy.ops.object.select_all(action='DESELECT')
for o in assets:o.select_set(True)
bpy.context.view_layer.objects.active=assets[0]
bpy.ops.export_scene.gltf(filepath=str(OUT/'Confluence.glb'),export_format='GLB',use_selection=True,export_apply=True,export_yup=True)
bpy.ops.export_scene.fbx(filepath=str(OUT/'Confluence.fbx'),use_selection=True,object_types={'MESH'},apply_scale_options='FBX_SCALE_ALL',mesh_smooth_type='FACE',path_mode='COPY',embed_textures=True,axis_forward='-Z',axis_up='Y',bake_anim=False)
report={'footprint_studs':[22,22],'height_studs':7.8,'origin':'foundation underside; GLB/FBX +Y up; Blender +Z up','heaven':'negative X','hell':'positive X','meshy_geometry_task':'01a0831a-7165-7132-b0fb-75790f85e721','meshy_texture_task':'01a0831b-f137-74e0-a57e-297651f7b726','mesh_parts':[],'falls':falls,'runtime_effects':'Static fluid meshes; emissive Blender preview. No Roblox runtime script installed.'}
for o in assets:o.data.calc_loop_triangles();report['mesh_parts'].append({'name':o.name,'triangles':len(o.data.loop_triangles),'vertices':len(o.data.vertices)})
(OUT/'manifest.json').write_text(json.dumps(report,indent=2)+'\n')
# Studio-like neutral ground and a 5.2-stud segmented humanoid scale figure, excluded from exports.
def simplemat(name,color):
 m=bpy.data.materials.new(name);m.diffuse_color=(*color,1);m.use_nodes=True;m.node_tree.nodes.get('Principled BSDF').inputs['Base Color'].default_value=(*color,1);return m
floor=simplemat('Preview court',(.24,.25,.25));dummy=simplemat('Scale figure ivory',(.74,.78,.8));joints=simplemat('Scale figure joints',(.11,.14,.18))
def box(name,loc,sz,mat):
 bpy.ops.mesh.primitive_cube_add(size=1,location=loc);o=bpy.context.object;o.name=name;o.dimensions=sz;bpy.ops.object.transform_apply(location=False,rotation=False,scale=True);o.data.materials.append(mat);b=o.modifiers.new('Soft corners','BEVEL');b.width=.06;b.segments=2;return o
box('ReviewGround',(0,0,-.16),(200,200,.3),floor)
# Segmented R15-proportioned measuring mannequin, total height exactly 5.2.
dx,dy=-12.8,-4
for label,z,w,d,h in [('LowerTorso',2.35,1.15,.65,.65),('UpperTorso',3.1,1.4,.72,.9)]:box('Scale_'+label,(dx,dy,z),(w,d,h),dummy)
for side in [-1,1]:
 for label,z,h in [('UpperLeg',1.5,.85),('LowerLeg',.68,.75),('Foot',.2,.35)]:box('Scale_'+label,(dx+side*.36,dy-(.16 if label=='Foot' else 0),z),(.55,.68,h),dummy)
 for label,z,h in [('UpperArm',3.07,.8),('LowerArm',2.29,.7),('Hand',1.78,.32)]:box('Scale_'+label,(dx+side*1,dy,z),(.48,.5,h),dummy)
bpy.ops.mesh.primitive_uv_sphere_add(segments=16,ring_count=8,radius=1,location=(dx,dy,4.65));head=bpy.context.object;head.name='Scale_Head';head.scale=(.49,.46,.55);head.data.materials.append(dummy)
box('Scale_Neck',(dx,dy,3.82),(.5,.45,.58),dummy)
# Lighting belongs to review scene only.
s=bpy.context.scene;s.render.engine='CYCLES';s.cycles.samples=48;s.cycles.use_denoising=True;s.render.resolution_x=1500;s.render.resolution_y=1100;s.render.resolution_percentage=100;s.world.color=(.28,.28,.28)
for name,loc,power,color,size in [('Key',(-9,-13,23),4000,(1,.88,.72),12),('Fill',(10,-4,14),2200,(.7,.83,1),10),('Rim',(2,13,18),3500,(1,.76,.56),9)]:
 bpy.ops.object.light_add(type='AREA',location=loc);o=bpy.context.object;o.name='Review_'+name;o.data.energy=power;o.data.color=color;o.data.shape='DISK';o.data.size=size;o.rotation_euler=(Vector((0,0,2))-o.location).to_track_quat('-Z','Y').to_euler()
bpy.ops.object.camera_add();cam=bpy.context.object;cam.name='ReviewCamera';cam.data.type='ORTHO';s.camera=cam
# Dimension guide in review scene only.
guide=simplemat('Dimension gold',(.65,.45,.16))
box('Dimension_Diameter',(0,-12,.055),(22,.045,.035),guide)
for gx in [-11,11]:box('Dimension_Tick',(gx,-12,.055),(.045,.55,.035),guide)
bpy.ops.object.text_add(location=(-2,-13,.08));label=bpy.context.object;label.name='Review_Dimension';label.data.body='22 STUDS';label.data.size=.7;label.data.extrude=.005;label.data.materials.append(guide)
for name,loc,target,zoom in [('Confluence-Walkthrough',(23,-34,23),(-1,0,2.5),32),('Confluence-Plan',(0,-6,45),(0,-.5,1),38),('Confluence-Rear',(-22,31,21),(0,0,2.5),32),('Confluence-Pedestrian',(23,-34,14),(0,0,3),32)]:
 cam.location=loc;cam.rotation_euler=(Vector(target)-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.ortho_scale=zoom;s.render.filepath=str(OUT/(name+'.png'));bpy.ops.render.render(write_still=True)
bpy.ops.file.pack_all();bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'Confluence.blend'),compress=True)
print('CONFLUENCE_REPORT',json.dumps(report))
