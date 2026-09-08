"""Blender-generated closed font silhouettes for native extruded Roblox CSG lettering.

Run with Blender --background --factory-startup --python <this file>.
Font geometry is sampled once; no font file is redistributed, uploaded or used at runtime.
"""
import json
from pathlib import Path
import bpy

ROOT = Path(__file__).resolve().parents[2]
cfg = json.loads((ROOT / 'configs/realm_crossroads_crests.json').read_text())
font = bpy.data.fonts.load(cfg['font_source'])
chars = set(''.join(line['text'] for t in cfg['themes'] for line in t['lines']))
chars.update(''.join(word for t in cfg['themes'] for word in t['captions']))
bragg = json.loads((ROOT / 'configs/realm_crossroads_bragg_plan.json').read_text())
chars.update(''.join(''.join(b.get('title_lines',[]))+b.get('scope','') for b in bragg['bays']))
chars.update('BRAGG CHAMPIONS UNCLAIMED PREVIEW FUTURE 123')
glyphs = {}
for char in sorted(chars - {' '}):
    curve = bpy.data.curves.new('Glyph_' + char, 'FONT')
    curve.body = char
    curve.font = font
    curve.resolution_u = cfg['curve_resolution']
    obj = bpy.data.objects.new('Glyph_' + char, curve)
    bpy.context.collection.objects.link(obj)
    bpy.ops.object.select_all(action='DESELECT')
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.convert(target='MESH')
    obj.data.calc_loop_triangles()
    verts = [(v.co.x,v.co.y) for v in obj.data.vertices]
    x0,y0 = min(v[0] for v in verts),min(v[1] for v in verts)
    x1,y1 = max(v[0] for v in verts),max(v[1] for v in verts)
    glyphs[char] = {'width':round((x1-x0)/(y1-y0),6), 'triangles':[
        [[round((verts[i][0]-(x0+x1)/2)/(y1-y0),6),round((verts[i][1]-(y0+y1)/2)/(y1-y0),6)] for i in tri.vertices]
        for tri in obj.data.loop_triangles]}
    bpy.data.objects.remove(obj,do_unlink=True)
out = ROOT / cfg['glyph_source']
out.write_text(json.dumps({'font':'Georgia Bold','generator':'Blender '+bpy.app.version_string,'glyphs':glyphs},separators=(',',':'))+'\n')
print(f'{len(glyphs)} glyphs; {sum(len(g["triangles"]) for g in glyphs.values())} triangles -> {out}')
