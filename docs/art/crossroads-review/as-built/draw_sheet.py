from pathlib import Path
import json,math,html,re
R=Path(__file__).resolve().parents[4];D=Path(__file__).resolve().parent
cfg=lambda n:json.loads((R/'configs'/n).read_text())
f=cfg('realm_crossroads_fishing.json');t=cfg('realm_crossroads_terrain.json'); survey=json.loads((D.parent/'fishing-capacity-qa/prepared-route.json').read_text())['survey']; gates=json.loads(json.loads((D/'native-gate-survey.json').read_text())['content'][0]['text'])['gates']
S=[]
def add(s):S.append(s)
def text(x,y,s,size=13,color='#233744',weight='normal',anchor='start'):
 s=re.sub(r'(?<=[0-9])(?=[A-Za-z]{2,})',' ',s)
 s=re.sub(r'\b([A-Za-z]{2,})(?=\d)',r'\1 ',s)
 add(f'<text x="{x}" y="{y}" font-size="{size}" fill="{color}" font-weight="{weight}" text-anchor="{anchor}">{html.escape(s)}</text>')
def line(x,y,x2,y2,color='#687a83',width=1,dash=''):
 add(f'<path d="M{x},{y} L{x2},{y2}" fill="none" stroke="{color}" stroke-width="{width}" stroke-dasharray="{dash}"/>')
def rect(x,y,w,h,fill='#fff',stroke='#718690',dash=''):
 add(f'<rect x="{x}" y="{y}" width="{w}" height="{h}" fill="{fill}" stroke="{stroke}" stroke-dasharray="{dash}"/>')
def P(x,z):return (550+x*1.6,400+z*1.6)
def path(points,color,width=2,dash=''):
 pp=[P(*a) for a in points];add('<polyline points="'+' '.join(f'{x},{y}' for x,y in pp)+f'" fill="none" stroke="{color}" stroke-width="{width}" stroke-dasharray="{dash}"/>')
def footprint(x,z,w,h,fill,stroke='#657c80'):
 a,b=P(x-w/2,z-h/2);rect(a,b,w*1.6,h*1.6,fill,stroke)
def label(x,z,s,size=12):
 a,b=P(x,z);text(a,b,s,size,anchor='middle')
def circle(x,z,r,fill,stroke='#64757b'):
 a,b=P(x,z);add(f'<circle cx="{a}" cy="{b}" r="{r*1.6}" fill="{fill}" stroke="{stroke}"/>')
add('<svg xmlns="http://www.w3.org/2000/svg" width="1540" height="1260" viewBox="0 0 1540 1260"><rect width="1540" height="1260" fill="#f8f6ef"/><g font-family="Arial,Helvetica,sans-serif">')
text(48,45,'CROSSROADS / AS-BUILT ARCHITECTURAL SURVEY',27,weight='bold');text(48,73,'R11 isolated preview • 8 September 2026 • dimensions in Roblox studs • source + native survey',15)
text(48,108,'A1  PLAN — north = −Z; Heaven west / Hell east',17,weight='bold')
# nominal safety centerline polygon, fill thematic halves separately clipped
pts=' '.join(f'{x},{y}' for x,y in [P(*a) for a in f['boundary']]);add(f'<defs><clipPath id="island"><polygon points="{pts}"/></clipPath></defs>');rect(60,140,490,520,'#e0e8ce','none');rect(550,140,480,520,'#ded0cb','none');add(f'<polygon points="{pts}" fill="#ece8d9" stroke="#304953" stroke-width="3" stroke-dasharray="7 4"/>')
# central usable areas
circle(0,-88,58,'#dfd8c5');circle(0,-88,38,'none');circle(0,-88,34,'#eee9db');circle(0,-88,11,'#80adae');label(0,-88,'FOUNTAIN',10);label(0,-119,'BRAGG Ø116',12);label(0,-56,'court Y4.44',11)
footprint(-120,18,64,90,'#d1dfa9');label(-120,15,'COIN FIELD',12);label(-120,26,'64 × 90 / Y4',11)
footprint(120,8,64,102,'#b5a1a0');label(120,4,'ARENA',13);label(120,15,'64 × 102',11);label(120,25,'Y4.38',11)
for x in [-120,120]:footprint(x,-61 if x<0 else -67,72,28,'#e9dfc6');label(x,-60 if x<0 else -66,'PAVILION',10)
# circulation source paths
path([(0,100),(0,62),(-40,42)],'#927344',7);path([(0,62),(40,42)],'#927344',7);path([(0,62),(0,-30)],'#927344',7)
path([(-60,-18),(-88,-18)],'#927344',5);path([(60,-18),(88,-18)],'#927344',5)
for x in [-1,1]:path([(x*16,80),(x*80,80)],'#927344',5)
circle(0,100,9,'#e7c967');label(0,120,'SPAWN (0,100) Y0',11)
# gates exact OBB footprint
for name,g in gates.items():
 cx,_,cz=g['center'];w,h,dep=g['size'];rx,_,rz=g['right'];lx,_,lz=g['look'];poly=[]
 for u,v in [(-1,-1),(1,-1),(1,1),(-1,1)]:poly.append(P(cx+u*w/2*rx+v*dep/2*lx,cz+u*w/2*rz+v*dep/2*lz))
 add('<polygon points="'+' '.join(f'{x},{y}' for x,y in poly)+'" fill="#b29b78" stroke="#4e514a"/>');label(cx,cz-16,'FARM & FIGHT' if cx<0 else 'PET SIEGE',11)
# Existing Bragg entry: eight treads, flanking built ramps (new proposal separate)
footprint(0,-18,26,16,'#e6dcc5')
for z in range(-24,-9,2):path([(-13,z),(13,z)],'#8e785a',.7)
for x in [-27,27]:footprint(x,-10,16,32,'none','#a98f67')
# original transition stairs/ramp ranges
for a in t['transitions']:
 if a['name'].startswith('Gallery'):continue # superseded rotunda layout
 if a['axis']=='x':x=(a['start']+a['finish'])/2;z=(a['cross_min']+a['cross_max'])/2;w=abs(a['finish']-a['start']);h=a['cross_max']-a['cross_min']
 else:z=(a['start']+a['finish'])/2;x=(a['cross_min']+a['cross_max'])/2;h=abs(a['finish']-a['start']);w=a['cross_max']-a['cross_min']
 footprint(x,z,w,h,'none','#a98f67')
 if a['kind']=='stairs':
  for q in range(1,8):
   if a['axis']=='x':path([(x-w/2+w*q/8,z-h/2),(x-w/2+w*q/8,z+h/2)],'#a98f67',.7)
   else:path([(x-w/2,z-h/2+h*q/8),(x+w/2,z-h/2+h*q/8)],'#a98f67',.7)
footprint(0,144,32,12,'#d6d6cc');label(0,150,'OVERLOOK Y−4',10)
# stands
for i,x in enumerate([164,174,184,194]):
 for z in [-12,28]:footprint(x,z,10,32,['#b8a79d','#b09c91','#a38c81','#94796e'][i])
 label(x,76,str([6,8,10,12][i]),10)
path([(159,8),(199,8)],'#eee3bf',12);label(179,59,'32 SEATS / 8 FREE',10);label(179,87,'TIER TOP Y',9)
# Newly applied arena access ramp: native dimensions supplied by owning agent
footprint(182,-60,8,32,'#c8d7ce','#456c68')
footprint(194,-60,8,32,'#c8d7ce','#456c68')
footprint(188,-80,20,8,'#c8d7ce','#456c68')
footprint(194,-36,8,16,'#c8d7ce','#456c68')
label(187,-89,'RAMP 1:8',10)
# ponds / station decks & figures/rods
for pond in f['ponds']:
 name=pond['name'];cx,cz=pond['center'];rx,rz=pond['radii'];a,b=P(cx,cz);add(f'<ellipse cx="{a}" cy="{b}" rx="{rx*1.6}" ry="{rz*1.6}" fill="'+('#8fbfc8' if cx<0 else '#9aaf9b')+'" stroke="#4c777f"/>')
 label(cx,cz-8,'HEAVEN' if cx<0 else 'HELL',12);label(cx,cz+3,f'{int(rx*2)} × {int(rz*2)}',12);label(cx,cz+14,f"{pond['spots']} STATIONS",10)
 sts=survey[name]['stations'];path([(s['back'][0],s['back'][2]) for s in sts]+[(sts[0]['back'][0],sts[0]['back'][2])],'#967241',2,'3 3')
 for s in sts:
  dx,_,dz=s['deck'];lx,lz=s['look'];right=(-lz,lx);pts=[]
  for u,v in [(-5,-6),(5,-6),(5,6),(-5,6)]:pts.append(P(dx+right[0]*u-lx*v,dz+right[1]*u-lz*v))
  add('<polygon points="'+' '.join(f'{x},{y}' for x,y in pts)+'" fill="#c6ab78" stroke="#655541" stroke-width=".7"/>')
  px,py=P(s['standing'][0],s['standing'][2]);add(f'<circle cx="{px}" cy="{py}" r="3.3" fill="#334c60"/>');label(dx-lx*10,dz-lz*10,str(s['index']),9)
footprint(-213,-85,22,14,'#d7bf91');label(-213,-99,'REST / 4 SEATS',10)
# key corridor callouts
path([(-158,50),(-158,-20)],'#cf773f',3);path([(205,40),(205,-30)],'#cf773f',3)
label(-150,100,'12.3 clear',11);label(216,98,'12 clear rear',11)
# plan overall dimensions
line(76,683,1024,683);line(76,677,76,689);line(1024,677,1024,689);text(550,704,'592 safety-wall centerline span (land extent nominal 600)',12,anchor='middle')
text(70,738,'0',11);line(84,732,244,732,'#263d47',3);line(84,726,84,738);line(164,726,164,738);line(244,726,244,738);text(155,751,'50',11);text(236,751,'100 studs',11)
# right column dimensions/key notes
text(1090,120,'MEASURED / BUILT',17,weight='bold')
notes=[('01  Gates','Centers X±40 / Z42.','Heaven 29.84 × 12.00 footprint;','top28.20. Hell29.93 × 13.01;','top28.06. Faces retained.'),('02  Openings','Travel anchors ±38.865,43.646.','Door clear6 × 9 is config intent,','not a fresh aperture survey.','Both thresholds navigation-passed.'),('03  Bragg','Court Ø116, center(0,−88).','Ring radii34–38 / floorY4.44.','Fountain Ø22; clear loopR22.','Gallery access reached in Play.'),('04  Occupied docks','18 decks10 × 12 / topY4.5.','Proxies5.5 high; footprints','4.246 × 1.232; no measured','figure / fixed-rod overlap.'),('05  Bank passages','Heaven12.3: deck rear−165','to wall west−152.7. Hell12:','stand back199 to deck rear211.','Bank-loop walking passed at24.'),('06  Built access ramp','Two 8 wide ×32run flights /1:8.','Top levels4→8→12; turn20 ×8.','Bridge8 ×16; max X198.67.','Underpass headroom7.5.')]
y=150
for title,*body in notes:
 text(1090,y,title,14,weight='bold');y+=22
 for s in body:text(1090,y,s,12);y+=18
 y+=15
# section details bottom
line(48,790,1492,790,'#647a80');text(48,820,'A2  STANDS / bank Y4',16,weight='bold')
for i,top in enumerate([6,8,10,12]):
 x=70+i*95;y=980-(top-4)*10;rect(x,y,95,980-y,'#b9aaa0');line(x+47,y,x+47,y-34,'#304958',3);text(x+47,y-42,f'Y{top}',13,anchor='middle')
line(70,980,450,980);text(70,1003,'10 / row; native Seat center = deck +1.75',13);text(70,1025,'Eye sample = deck +5.087; 16 existing aisle steps.',12);text(70,1047,'Aisle8 wide; front corridor7; rear corridor12.',12);text(70,1069,'Raised tiers7.5/10/12.5/15 NOT BUILT.',12,'#a04f37')
text(520,820,'A3  DOCK OCCUPANCY / typical',16,weight='bold');rect(555,845,150,180,'#c6ab78');rect(598,900,64,19,'#334c60');line(574,958,574,884,'#84602d',4);text(630,1048,'10 × 12 deck / Y4.5',13,anchor='middle');text(745,863,'Body:5.5 high',13);text(745,887,'rod:5.5 long, at rest',13);text(745,911,'~1.616 X gap',13);text(745,935,'back → Standing → back',12);text(745,959,'all18 access-passed',12);text(555,1070,'Geometry only; no18-client load certification.',12)
text(1090,820,'A4  ELEVATION DATUMS',16,weight='bold')
for i,s in enumerate(['0  Central arrival court / nominal datum','4  Activity banks / garden terrain','4.38  Current arena surface','4.44  Bragg floor','4.5  Dock walking surface','6 / 8 / 10 / 12  Spectator tiers','14.2  Shelter roof top','−4  Overlook; pond nominal bottom','0  Last native water-surface sample']):text(1090,850+i*25,s,12)
line(48,1120,1492,1120);text(48,1150,'STATUS KEY',14,weight='bold');text(180,1150,'Solid = authored footprint  •  ochre dashed = tested bank centerline  •  dark dashed = safety wall',13)
text(48,1180,'Plan is diagrammatic measured coordination, not a terrain contour survey. Organic assets omitted for legibility.',13)
text(48,1204,'Source/runtime differences, QA limits and the applied access ramp are documented in AS_BUILT.md. Scale applies to A1 only.',13)
text(48,1234,'No export hash, instance total or future construction is implied. Sheet generated from versioned source + native observations.',12,'#627780')
add('</g></svg>');(D/'crossroads-as-built.svg').write_text('\n'.join(S));(D/'index.html').write_text('<!doctype html><meta charset="utf-8"><title>Crossroads as-built</title><style>body{margin:0;background:#e5e3db}img{width:100%;height:auto}</style><img src="crossroads-as-built.svg" alt="Dimensioned Crossroads architectural sheet">')
