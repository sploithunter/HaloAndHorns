"""R4 grading plan, derived from the same config as the Studio terrain bake."""
import json
from pathlib import Path
from html import escape

ROOT = Path(__file__).resolve().parents[2]
C = json.loads((ROOT / 'configs/realm_crossroads_terrain.json').read_text())
OUT = ROOT / 'output/realm_crossroads/Realm-Crossroads-Grading-R4.svg'
S = ['<svg xmlns="http://www.w3.org/2000/svg" width="1250" height="850" viewBox="0 0 1250 850">',
     '<rect width="1250" height="850" fill="#f8f5ed"/>',
     '<style>text{font-family:Arial,sans-serif;fill:#263f43} .label{font-size:14px} .small{font-size:12px}</style>']
def text(x,y,t,size=14):
    S.append(f'<text x="{x}" y="{y}" font-size="{size}">{escape(t)}</text>')
def line(x,y,xx,yy,color='#263f43',width=2):
    S.append(f'<path d="M{x},{y} L{xx},{yy}" fill="none" stroke="{color}" stroke-width="{width}"/>')
def rect(x,z,w,d,color,stroke='#627577'):
    S.append(f'<rect x="{390+x*1.75}" y="{402+z*1.75}" width="{w*1.75}" height="{d*1.75}" fill="{color}" stroke="{stroke}"/>')
text(40,44,'REALM CROSSROADS / R4 GRADING PLAN',26)
text(40,73,'All dimensions in Roblox studs. Spawn/court datum = 0. Island 360 × 320.',15)
rect(-180,-160,360,320,'#afbba2')
rect(-136,-132,272,264,'#e2e9cd')
rect(-80,-88,160,224,'#f5f0e2')
rect(-96,-132,192,44,'#d8dfba')
rect(-64,136,128,16,'#cadce1')
rect(-60,-116,120,28,'#d4cfc0')
text(304,219,'CHAMPIONS +4',16)
for t in C['transitions']:
    a,b=sorted([t['start'],t['finish']]);lo,hi=t['cross_min'],t['cross_max']
    x,z,w,d=(a,lo,b-a,hi-lo) if t['axis']=='x' else (lo,a,hi-lo,b-a)
    rect(x,z,w,d,'#dfb46f' if t['kind']=='stairs' else '#92bac3')
    if t['kind']=='stairs':
        for n in range(1,t['steps']):
            v=a+(b-a)*n/t['steps']
            if t['axis']=='x':line(390+v*1.75,402+lo*1.75,390+v*1.75,402+hi*1.75,'#776243',1)
            else:line(390+lo*1.75,402+v*1.75,390+hi*1.75,402+v*1.75,'#776243',1)
for x in [-80,80]:
    for a,b in C['retaining_segments']['side_z']:line(390+x*1.75,402+a*1.75,390+x*1.75,402+b*1.75,'#8b6045',4)
for a,b in C['retaining_segments']['gallery_x']:line(390+a*1.75,248,390+b*1.75,248,'#8b6045',4)
for a,b in C['retaining_segments']['overlook_x']:line(390+a*1.75,640,390+b*1.75,640,'#8b6045',4)
for x,name in [(-40,'FARM'),(40,'MERGE')]:
    px,py=390+x*1.75,402+42*1.75
    S.append(f'<circle cx="{px}" cy="{py}" r="45.5" fill="none" stroke="#8d9789" stroke-dasharray="5 4"/>')
    rect(x-15,36,30,12,'#c6b185')
    text(px-20,py-20,name,12)
    line(390,577,px,py,'#a99c73',2)
text(365,589,'SPAWN',13)
text(278,624,'0',13)
text(322,678,'OVERLOOK -4',14)
text(170,350,'GARDEN +4',14)
text(539,350,'GARDEN +4',14)
text(353,355,'COURT 0',14)
text(310,151,'PLANTED RIM +12',14)
line(75,710,705,710);text(337,737,'360 studs',15)
text(760,123,'EDGE AND ROUTE TYPES',20)
items=[('Main arrival / both gates','Level at 0; no stair on the choice route.'),
('Gardens / Champions gallery','+4 above court; retain with vertical stone faces.'),
('Stairs (gold)','8 risers × 0.5 high; 2-stud treads; run 16.'),
('Ramps (blue)','4-stud rise over 32; slope 1:8; width 16.'),
('Lower overlook','-4; paired ramps and a central stair.'),
('Outer planted rim','+12 target; slopes from +4, about 1:2–1:2.5.'),
('Island perimeter','Steep voxel rock cliff down to underside -24.'),
('Retaining walls (brown)','Vertical architectural skin; terrain behind it.')]
for i,(a,b) in enumerate(items):text(760,164+i*55,a,16);text(760,185+i*55,b,12)
text(760,645,'SECTION / COURT TO GARDEN',17)
line(765,729,810,729)
for i in range(8):
    x=810+i*14;y=729-i*5
    line(x,y,x,y-5,'#8b6045');line(x,y-5,x+14,y-5,'#8b6045')
line(922,689,992,689);text(771,752,'0',13);text(946,680,'+4',13)
line(1020,729,1190,689,'#528d9b',3)
text(1036,752,'Ramp: run 32 / rise 4',13)
text(40,798,'Voxel grades support all terraces. Precise treads and retaining faces use stone skins over the terrain.',15)
text(40,822,'R4 is a walkable architectural blockout; landscaping, cliff shaping, gallery detail and travel interactions remain for later passes.',12)
S.append('</svg>')
OUT.parent.mkdir(parents=True,exist_ok=True)
OUT.write_text('\n'.join(S))
print(OUT)
