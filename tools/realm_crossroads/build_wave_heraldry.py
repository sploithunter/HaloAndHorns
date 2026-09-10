"""Controlled Blender relief contours; uses the existing native glyph/CSG pipeline.
Run Blender --background --factory-startup --python tools/realm_crossroads/build_wave_heraldry.py.
Writes triangle art data into the existing heraldry config and a local Blender review scene.
"""
import json
import math
from pathlib import Path
import bpy
from mathutils import Vector
from mathutils.geometry import tessellate_polygon

ROOT = Path(__file__).resolve().parents[2]
PATH = ROOT / 'configs/realm_crossroads_polish_heraldry.json'
cfg = json.loads(PATH.read_text())
e = cfg['emblems']
r = e['relief_recipe']
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)

def stroke(points, width):
    points = [Vector((x, y, 0)) for x, y in points]
    normals = []
    for a, b in zip(points, points[1:]):
        d = (b-a).normalized()
        normals.append(Vector((-d.y, d.x, 0)))
    sides = []
    for sign in (1, -1):
        side = []
        for i, p in enumerate(points):
            if i == 0:
                offset = normals[0]
            elif i == len(points)-1:
                offset = normals[-1]
            else:
                offset = (normals[i-1]+normals[i]).normalized()
                offset /= max(0.5, offset.dot(normals[i]))
            side.append(p+offset*(width/2)*sign)
        sides.append(side)
    polygon = sides[0]+list(reversed(sides[1]))
    triangles = tessellate_polygon([polygon])
    return [[[round((polygon[v] if isinstance(v, int) else v).x, 6), round((polygon[v] if isinstance(v, int) else v).y, 6)] for v in tri] for tri in triangles]

def wave(y, amplitude):
    return [[-r['wave_half_width']+2*r['wave_half_width']*i/r['samples'],
             y+amplitude*math.sin(2*math.pi*i/r['samples'])]
            for i in range(r['samples']+1)]

geometries = {
    'wave_peak': stroke(wave(r['peak_wave_y'], r['peak_wave_amplitude']), r['stroke_width'])
                 + stroke(r['peak_chevron'], r['stroke_width']),
    'wave_total': [tri for y in r['total_wave_ys']
                   for tri in stroke(wave(y, r['total_wave_amplitude']), r['stroke_width'])],
}
for index, (name, triangles) in enumerate(geometries.items()):
    vertices = [(p[0], 0, p[1]) for tri in triangles for p in tri]
    faces = [tuple(range(i, i+3)) for i in range(0,len(vertices),3)]
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(vertices, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    obj.location.x = index*3
    solid = obj.modifiers.new('Native relief depth', 'SOLIDIFY')
    solid.thickness = e['medal']['relief_depth']
    obj['native_plane'] = 'Roblox XY; front +Z; serialized planar triangles are authoritative'
    obj['meaning'] = 'single wave plus up-chevron; highest cleared' if name=='wave_peak' else 'stacked wave strokes; cumulative cleared, not a numeric score'
    for tri in triangles:
        assert all(math.hypot(*v)<e['medal']['face_radius'] for v in tri)
e['relief_geometry'] = {name:{'triangles':triangles} for name,triangles in geometries.items()}
e['relief_recipe']['generator'] = 'Blender '+bpy.app.version_string
PATH.write_text(json.dumps(cfg,indent=2)+'\n')
out = ROOT/r['preview_blend']
out.parent.mkdir(parents=True,exist_ok=True)
bpy.ops.wm.save_as_mainfile(filepath=str(out))
print(json.dumps({name:len(tri) for name,tri in geometries.items()}))
