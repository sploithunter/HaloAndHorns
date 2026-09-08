"""Rear-angle review of the exact editable rod source, not part of uploaded meshes."""
from pathlib import Path
import bpy
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[4]
for realm in ('heaven','hell'):
 folder=ROOT/'assets/exports/props/fishing_rods'/realm
 bpy.ops.wm.open_mainfile(filepath=str(folder/(realm+'.blend')))
 scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=24
 scene.render.resolution_x=600;scene.render.resolution_y=1000;scene.render.resolution_percentage=100
 scene.world.color=(.2,.2,.2);scene.render.film_transparent=True
 bpy.ops.object.camera_add(location=(-5,10,4));camera=bpy.context.object;camera.data.type='ORTHO';camera.data.ortho_scale=6.3
 camera.rotation_euler=(Vector((0,0,2.75))-camera.location).to_track_quat('-Z','Y').to_euler();scene.camera=camera
 for position,power in [((-3,5,7),800),((4,0,4),600),((-2,-4,7),900)]:
  bpy.ops.object.light_add(type='AREA',location=position);light=bpy.context.object;light.data.energy=power;light.data.size=4
  light.rotation_euler=(Vector((0,0,2.7))-light.location).to_track_quat('-Z','Y').to_euler()
 scene.render.filepath=str(folder/'review-reverse.png');bpy.ops.render.render(write_still=True)
