"""Verify final FBX has one UV coordinate per position vertex for Open Cloud."""
import bpy,json,argparse,sys
from pathlib import Path
from collections import defaultdict
parser=argparse.ArgumentParser();parser.add_argument('--directory',default='assets/source/props/crossroads_fossil/final_v2')
args=parser.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [])
root=Path.cwd()/args.directory
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
bpy.ops.import_scene.fbx(filepath=str(root/'CrossroadsFossil.fbx'))
report=[]
for obj in bpy.context.scene.objects:
 if obj.type!='MESH':continue
 uv=obj.data.uv_layers.active
 assert uv,'Missing UVs'
 mapping=defaultdict(set)
 for loop in obj.data.loops:
  mapping[loop.vertex_index].add(tuple(round(x,6) for x in uv.data[loop.index].uv))
 conflicts=sum(len(v)>1 for v in mapping.values())
 report.append({'name':obj.name,'uv_conflicting_vertices':conflicts,'vertices':len(obj.data.vertices)})
 assert conflicts==0,report
(root/'uv_guard.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps(report))
