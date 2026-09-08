"""Extract conservative rectangular pool masks for Roblox scrolling Texture surfaces."""
import bpy,json,math
from pathlib import Path
from mathutils import Vector
from mathutils.bvhtree import BVHTree
ROOT=Path(__file__).resolve().parents[4]
bpy.ops.wm.open_mainfile(filepath=str(ROOT/'assets/exports/props/confluence/Confluence.blend'))
step=.21;result=[]
for obj in bpy.data.objects:
 if obj.type!='MESH' or '_Pool_' not in obj.name:continue
 verts=[obj.matrix_world@v.co for v in obj.data.vertices];faces=[list(p.vertices) for p in obj.data.polygons];tree=BVHTree.FromPolygons(verts,faces)
 xs=[v.x for v in verts];ys=[v.y for v in verts];level=sum(v.z for v in verts)/len(verts)
 rows={}
 for iy in range(math.floor(min(ys)/step),math.ceil(max(ys)/step)):
  good=[]
  for ix in range(math.floor(min(xs)/step),math.ceil(max(xs)/step)):
   valid=True
   for dx,dy in [(0.02,.02),(.98,.02),(.02,.98),(.98,.98),(.5,.5)]:
    hit,_,_,_=tree.ray_cast(Vector(((ix+dx)*step,(iy+dy)*step,level+1)),Vector((0,0,-1)))
    if hit is None:valid=False;break
   if valid:good.append(ix)
  runs=[]
  for ix in good:
   if runs and runs[-1][1]==ix:runs[-1][1]=ix+1
   else:runs.append([ix,ix+1])
  rows[iy]=runs
 active={};rects=[]
 for iy,runs in rows.items():
  keys={tuple(run) for run in runs}
  for k in list(active):
   if k not in keys:rects.append(active.pop(k))
  for lo,hi in keys:
   if (lo,hi) in active:active[(lo,hi)][3]=iy+1
   else:active[(lo,hi)]=[lo,hi,iy,iy+1]
 rects+=list(active.values())
 for x0,x1,y0,y1 in rects:
  result.append({'side':'water' if 'Water' in obj.name else 'lava','position':[round((x0+x1)*step/2,4),round(level+.012,4),round(-(y0+y1)*step/2,4)],'size':[round((x1-x0)*step,4),.012,round((y1-y0)*step,4)]})
out=ROOT/'configs/confluence_surface_tiles.json';out.write_text(json.dumps({'source':'Confluence.blend planar pool masks','cell':step,'tiles':result},separators=(',',':'))+'\n');print('TILES',len(result))
