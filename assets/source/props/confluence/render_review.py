import bpy
from pathlib import Path
from mathutils import Vector
root=Path(__file__).resolve().parents[4];out=root/'assets/exports/props/confluence'
bpy.ops.wm.open_mainfile(filepath=str(out/'Confluence.blend'))
for m in bpy.data.materials:
 if m.name in ['Preview court','Scale figure ivory','Scale figure joints','Dimension gold']:
  c=m.diffuse_color[:];m.use_nodes=True;m.node_tree.nodes.get('Principled BSDF').inputs['Base Color'].default_value=c
s=bpy.context.scene;cam=s.camera
for name,loc,target,zoom in [('Confluence-Walkthrough',(23,-34,23),(-1,0,2.5),32),('Confluence-Plan',(0,-6,45),(0,-.5,1),38),('Confluence-Rear',(-22,31,21),(0,0,2.5),32),('Confluence-Pedestrian',(23,-34,14),(0,0,3),32)]:
 cam.location=loc;cam.rotation_euler=(Vector(target)-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.ortho_scale=zoom;s.render.filepath=str(out/(name+'.png'));bpy.ops.render.render(write_still=True)
bpy.ops.file.pack_all();bpy.ops.wm.save_as_mainfile(filepath=str(out/'Confluence.blend'),compress=True)
