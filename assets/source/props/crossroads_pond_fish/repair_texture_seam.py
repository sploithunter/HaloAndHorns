"""Close the four-edge texture-stage seam with a UV-interpolated center fan.
The generic quad fill picks an already occupied diagonal on this source. This
local fan avoids that edge without remeshing the fish or replacing its UV atlas.
"""
import bpy,bmesh,json
from pathlib import Path
from mathutils import Vector
R=Path.cwd()/'assets/source/props/crossroads_pond_fish'
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
bpy.ops.import_scene.gltf(filepath=str(R/'textured/model.glb'))
o=next(o for o in bpy.context.scene.objects if o.type=='MESH');bm=bmesh.new();bm.from_mesh(o.data)
bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=0.00000023807312333)
boundary=[e for e in bm.edges if e.is_boundary];assert len(boundary)==4,len(boundary)
uv=bm.loops.layers.uv.active;assert uv
start=boundary[0].verts[0];order=[start];last=None;current=start
for _ in range(3):
 edges=[e for e in current.link_edges if e in boundary and e!=last];e=edges[0];current=e.other_vert(current);order.append(current);last=e
assert len(set(order))==4
center=bm.verts.new(sum((v.co for v in order),Vector())/4)
uvs={v:next(loop[uv].uv.copy() for face in v.link_faces for loop in face.loops if loop.vert==v) for v in order};center_uv=sum(uvs.values(),Vector((0,0)))/4
for i,v in enumerate(order):
 w=order[(i+1)%4];face=bm.faces.new([v,w,center])
 for loop in face.loops:loop[uv].uv=center_uv if loop.vert==center else uvs[loop.vert]
bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(o.data);bm.free();o.data.update()
out=R/'textured_closed';out.mkdir(exist_ok=True)
bpy.ops.export_scene.gltf(filepath=str(out/'model.glb'),export_format='GLB')
(out/'repair.json').write_text(json.dumps({'input':'textured/model.glb','boundary_edges_before':4,'method':'four_triangle_center_fan','voxel_remesh':False,'uv_interpolated':True},indent=2)+'\n')
