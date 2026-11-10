"""Blender: convert the config-owned HH egg mesh/texture cache into portable GLBs."""
import bpy,json,pathlib,struct,sys
from mathutils import Vector
ROOT=pathlib.Path(__file__).resolve().parents[3]
cache=pathlib.Path(sys.argv[sys.argv.index('--')+1])
source=json.loads((ROOT/'configs/spawn_merge_egg_sources.json').read_text())['parts']
height=json.loads((ROOT/'ports/spawn/world/scripts/lib/data/merge.yml').read_text())['eggHeight']
manifest=[]
for egg in source:
 bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
 identity=egg['mesh'].split('//')[-1]
 values=list(struct.iter_unpack('<8f',(cache/(identity+'.bin')).read_bytes()))
 meta=json.loads((cache/(identity+'.json')).read_text());center=meta['center'];scale=height/meta['size'][1]
 verts=[((v[0]-center[0])*scale,-(v[2]-center[2])*scale,(v[1]-center[1]+meta['size'][1]/2)*scale) for v in values]
 mesh=bpy.data.meshes.new(egg['eggId']);mesh.from_pydata(verts,[],[(i,i+1,i+2) for i in range(0,len(values),3)]);mesh.update()
 uv=mesh.uv_layers.new(name='UVMap')
 for i,v in enumerate(values):uv.data[i].uv=(v[6],1-v[7])
 mesh.normals_split_custom_set_from_vertices([(v[3],-v[5],v[4]) for v in values])
 obj=bpy.data.objects.new(egg['eggId'],mesh);bpy.context.collection.objects.link(obj)
 material=bpy.data.materials.new(egg['eggId']);material.use_nodes=True;nodes=material.node_tree.nodes;p=nodes.get('Principled BSDF')
 image=bpy.data.images.load(str(cache/(egg['texture'].split('//')[-1]+'.png')),check_existing=True)
 texture=nodes.new('ShaderNodeTexImage');texture.image=image;material.node_tree.links.new(texture.outputs['Color'],p.inputs['Base Color'])
 p.inputs['Roughness'].default_value=.5;mesh.materials.append(material)
 output=cache/(egg['eggId']+'.glb');bpy.ops.export_scene.gltf(filepath=str(output),export_format='GLB',export_animations=False)
 manifest.append({'eggId':egg['eggId'],'sourceFile':str(output),'height':height})
(cache/'eggs.json').write_text(json.dumps(manifest,indent=2));print('HH_EGGS',len(manifest))
