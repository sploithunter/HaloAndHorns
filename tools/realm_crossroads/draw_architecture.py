"""Draw the proposed R2 architecture independently of the existing Roblox bake."""
import json
import math
from pathlib import Path
from reportlab.pdfgen import canvas
from reportlab.lib.colors import HexColor, Color
from reportlab.lib.utils import ImageReader

ROOT = Path(__file__).resolve().parents[2]
D = json.loads((ROOT / "configs/realm_crossroads_design.json").read_text())
OUT = ROOT / "output/pdf"
OUT.mkdir(parents=True, exist_ok=True)
W, H = 1190.55, 841.89
c = canvas.Canvas(str(OUT / "Realm-Crossroads-Architecture-R2.pdf"), pagesize=(W, H))
c.setTitle("Realm Crossroads | Architectural proposal R2")
c.setAuthor("Halo & Horns")
INK = "#263F43"
MUTED = "#627577"
GREEN = "#DCE6CE"
ROCK = "#CBD2C7"
STONE = "#F5F0E2"
GOLD = "#B48A42"
BLUE = "#547E92"
RED = "#B87558"

def text(x, y, s, size=11, color=INK, align="left", bold=False):
    c.setFillColor(HexColor(color))
    c.setFont("Helvetica-Bold" if bold else "Helvetica", size)
    {"left": c.drawString, "center": c.drawCentredString, "right": c.drawRightString}[align](x, y, s)

def line(x1, y1, x2, y2, color=INK, width=1, dash=None):
    c.setStrokeColor(HexColor(color)); c.setLineWidth(width)
    c.setDash(dash or [])
    c.line(x1,y1,x2,y2); c.setDash([])

def rect(x,y,w,h,fill=None,stroke=INK,width=1):
    c.setLineWidth(width); c.setStrokeColor(HexColor(stroke))
    if fill: c.setFillColor(HexColor(fill))
    c.rect(x,y,w,h,fill=int(bool(fill)),stroke=1)

def poly(points,fill,stroke=INK,width=1):
    p=c.beginPath(); p.moveTo(*points[0])
    for q in points[1:]: p.lineTo(*q)
    p.close(); c.setLineWidth(width); c.setStrokeColor(HexColor(stroke)); c.setFillColor(HexColor(fill)); c.drawPath(p,fill=1,stroke=1)

def circle(x,y,r,fill=None,stroke=INK,width=1):
    c.setStrokeColor(HexColor(stroke)); c.setLineWidth(width)
    if fill:c.setFillColor(HexColor(fill))
    c.circle(x,y,r,fill=int(bool(fill)),stroke=1)

def dh(x1,x2,y,label,ext=None):
    if ext is not None:
        line(x1,ext,x1,y+5,MUTED,.5); line(x2,ext,x2,y+5,MUTED,.5)
    line(x1,y,x2,y,MUTED,.7)
    for x in (x1,x2):line(x-3,y-3,x+3,y+3,MUTED,.8)
    tw=c.stringWidth(label,"Helvetica",10)
    c.setFillColor(HexColor("#FFFFFF"));c.rect((x1+x2-tw)/2-4,y-4,tw+8,13,fill=1,stroke=0)
    text((x1+x2)/2,y-1,label,10,MUTED,"center")

def dv(x,y1,y2,label,ext=None):
    if ext is not None:
        line(ext,y1,x-4,y1,MUTED,.5);line(ext,y2,x-4,y2,MUTED,.5)
    line(x,y1,x,y2,MUTED,.7)
    for y in (y1,y2):line(x-3,y-3,x+3,y+3,MUTED,.8)
    c.saveState();c.translate(x-7,(y1+y2)/2);c.rotate(90);text(0,0,label,10,MUTED,"center");c.restoreState()

def sheet(number,title,subtitle):
    c.setFillColor(HexColor("#FFFFFF"));c.rect(0,0,W,H,fill=1,stroke=0)
    text(36,802,"HALO & HORNS / REALM CROSSROADS",12,MUTED,bold=True)
    text(36,769,title,25,bold=True)
    text(36,745,subtitle,11,MUTED)
    line(36,730,W-36,730,MUTED,.8)
    line(36,51,W-36,51,MUTED,.8)
    text(36,32,"R2  |  08 SEP 2026  |  PROPOSED - REVIEW BEFORE NEXT BAKE",10,MUTED)
    text(W-36,32,number+"  /  ALL DIMENSIONS IN ROBLOX STUDS",10,MUTED,"right")

def note(x,y,title,lines):
    text(x,y,title,12,bold=True)
    for k,s in enumerate(lines):text(x,y-19-15*k,s,10.5,MUTED)

# A-01: plan. Drawing coordinates use X right and Roblox Z down.
sheet("A-01","Site plan / more landscape, smaller architecture","Dimensioned plan. Keep the fast mode choice; expand the island around it. Concept art informs composition, not literal scale.")
S=1.65; OX=375; OY=410
def xy(x,z):return OX+x*S,OY-z*S
def worldrect(x,z,w,d,fill,stroke=INK):
    px,py=xy(x-w/2,z+d/2);rect(px,py,w*S,d*S,fill,stroke)
def worldpoly(points,fill,stroke=INK):poly([xy(*p) for p in points],fill,stroke)
def worldpath(points,width,fill):
    c.setStrokeColor(HexColor(fill));c.setLineWidth(width*S);c.setLineJoin(1)
    p=c.beginPath();p.moveTo(*xy(*points[0]))
    for pt in points[1:]:p.lineTo(*xy(*pt))
    c.drawPath(p)
worldpoly([(-150,-160),(150,-160),(180,-130),(180,130),(150,160),(-150,160),(-180,130),(-180,-130)],ROCK)
worldpoly([(-120,-135),(120,-135),(145,-110),(145,110),(120,135),(-120,135),(-145,110),(-145,-110)],GREEN)
worldrect(0,4,136,222,STONE,"#C8C1AB")
# Outer walks and ramp approaches are secondary and quieter than mode choices.
for side in (-1,1):
    worldpath([(side*18,92),(side*89,92),(side*126,55),(side*126,-58),(side*75,-95)],10,"#EDE8DB")
    worldpath([(side*36,-24),(side*84,-24)],10,"#EDE8DB")
    # 32-stud ramp run accommodates a 4-stud rise at 1:8.
    for x in (49,57,65,73,81):
        a,b=xy(side*x,-19);d,e=xy(side*x,-29);line(a,b,d,e,"#B5B29D",.6)
    worldpath([(side*26,60),(side*26,22),(side*26,-35),(side*26,-88)],D['primary_path_width'],"#E7DCC2")
    worldpath([(0,100),(side*26,54)],D['primary_path_width'],"#E7DCC2")
for x,z,w,d in D['garden_reserves']:
    worldrect(x,z,w,d,"#CAD9B4","#839479")
    a,b=xy(x,z);text(a,b+5,"FUTURE REALM",9,INK,"center",True);text(a,b-9,"48 x 44 reserve",9,MUTED,"center");text(a,b-21,"+4 terrace",9,MUTED,"center")
# Low rectangular pools and planted margins echo the reference without filling the court.
for side in (-1,1):
    worldrect(side*60,24,10,40,"#CDE3E4",BLUE)
    worldrect(side*60,-35,10,36,GREEN,"#839479")
for n,((x,z),angle,label_) in enumerate(zip(D['gates'],D['gate_yaw'],['FARM & FIGHT','MERGE'])):
    px,py=xy(x,z)
    c.saveState();c.translate(px,py);c.rotate(angle)
    rect(-15*S,-10*S,30*S,20*S,"#EEE4CB","#C8C1AB")
    rect(-9*S,-3*S,4*S,6*S,ROCK);rect(5*S,-3*S,4*S,6*S,ROCK)
    line(-5*S,0,5*S,0,BLUE if n==0 else RED,2)
    c.restoreState()
    tx,ty=xy(-83 if n==0 else 83,64)
    text(tx,ty,label_,10,INK,"center",True)
    line(tx,ty+8,px,py, MUTED,.6)
sx,sy=xy(*D['spawn']);circle(sx,sy,10*S,STONE,GOLD,1.5)
text(sx,sy-5,"SPAWN",9,INK,"center",True)
line(sx,sy+19,sx,sy+35,INK,1.5);poly([(sx,sy+39),(sx-3,sy+33),(sx+3,sy+33)],INK)
fx,fy=xy(*D['landmark']);circle(fx,fy,10*S,"#CDE3E4",BLUE);circle(fx,fy,5*S,None,GOLD,2)
text(fx,fy-32,"LOW LANDMARK",9,INK,"center");text(fx,fy-44,"20 diameter / 12 high",9,MUTED,"center")
gx,gz,gw,gd,gh=D['gallery'];worldrect(gx,gz,gw,gd,STONE)
for i,x in enumerate([-45,-15,15,45]):
    for j in (-1,0,1):worldrect(x+j*7,gz+3,6,6,"#D7C093",GOLD)
    if i<3:
        a,b=xy(x+15,gz-gd/2);d,e=xy(x+15,gz+gd/2);line(a,b,d,e,MUTED,.6)
px,py=xy(0,-80);text(px,py,"CHAMPIONS GALLERY / 120 x 28",10,INK,"center",True)
for side in (-1,1):
    for x,z in [(158,94),(162,44),(162,-20),(153,-84),(114,-144),(75,-143),(125,118)]:
        a,b=xy(side*x,z);circle(a,b,7*S,"#B5C8A3","#779169");circle(a+2,b+2,4*S,None,"#8BA37D",.5)
text(*xy(0,-141),"REAR TERRACES +12",9,MUTED,"center")
text(*xy(0,144),"ARRIVAL OVERLOOK / LANDSCAPE BUFFER",9,MUTED,"center")
# A-A section line
a,b=xy(0,-128);d,e=xy(0,124);line(a,b,d,e,BLUE,.6,[4,5]);text(a+7,b,"A",11,BLUE, bold=True);text(d+7,e,"A",11,BLUE,bold=True)
dh(*[xy(x,0)[0] for x in (-180,180)],700,"360 overall",ext=674)
dv(61,*sorted([xy(0,z)[1] for z in (-160,160)]),"320 overall",ext=78)
dh(*[xy(x,0)[0] for x in (-145,145)],116,"290 walkable terrace",ext=145)
text(82,84,"0",9,MUTED);line(97,87,97+40*S,87,INK,3);line(97,82,97,92,INK);line(97+40*S,82,97+40*S,92,INK);text(97+40*S+8,84,"40 studs",9,MUTED)
# right-hand design brief and original art thumbnail
rx=742
ref=ROOT / D['reference_image']
assert ref.exists(), "Approved reference image is missing"
c.drawImage(ImageReader(str(ref)),rx,434,width=398,height=270,preserveAspectRatio=True,anchor='c',mask='auto')
text(rx,418,"REFERENCE: approved composition, not measured geometry",9,MUTED)
note(rx,390,"01 / Landscape holds the scale",["360 x 320 island; 290 x 270 walkable terrace.","Cliffs, planted shoulders, and overlooks surround the court.","The island grows; the buildings do not grow with it."])
note(rx,308,"02 / Choice remains immediate",["Gate centers: X +/-26, Z +54. Spawn: X 0, Z +100.","About 53 studs to either gate center: 3.3 seconds at 16/s.","Both entrances angle toward the arriving player."])
note(rx,226,"03 / Gallery is an optional destination",["Four 30-stud alcoves; 2 / 1 / 3 podiums in each.","Front edge Z -88; about 13 seconds via the side path.","No gameplay route requires visiting the gallery."])
note(rx,144,"04 / Keep the approach legible",["18-stud main walks; clear and level at both entrances.","Water and planting sit beside paths, not across them.","Garden changes of level use ramps, maximum 1:8."])
c.showPage()

# A-02 gateway front and passage section at matching scale
sheet("A-02","Gateway proportions / player first, landmark second","One shared architectural module for both modes. Angel and demon art uses the same size envelope. Elevation shown square-on.")
scale=13; bx=262; by=175
def ep(x,y):return bx+x*scale,by+y*scale
def er(x,y,w,h,fill,stroke=INK):
    a,b=ep(x,y);rect(a,b,w*scale,h*scale,fill,stroke)
line(78,by,560,by,INK,1.5)
er(-9,0,4,12,STONE);er(5,0,4,12,STONE)
# faceted arch lintel, opening is guaranteed clear to y=12
poly([ep(-9,12),ep(-9,14),ep(-6,16),ep(6,16),ep(9,14),ep(9,12)],STONE)
er(-9,14,18,3,"#263F43")
text(bx,by+15.1*scale,"MODE NAME",17,"#F5F0E2","center",True)
er(-10,17,20,1,"#DFD1AC")
er(-3,18,6,1,STONE)
# abstract art envelope, deliberately not a fake rendering of the final mesh
c.setDash([5,4]);rect(*ep(-4.5,19),9*scale,9*scale,None,BLUE);c.setDash([])
text(bx,by+24*scale,"AVATAR",13,BLUE,"center",True);text(bx,by+22.5*scale,"9 high envelope",10,BLUE,"center")
def person(x,y,s=13,color=INK):
    # 5.5-stud silhouette including head. R15 proportions vary; reference only.
    circle(x,y+4.9*s,.55*s,color,color)
    rect(x-.65*s,y+2.05*s,1.3*s,2.2*s,color,color)
    for side in (-1,1):
        line(x+side*.35*s,y+2.1*s,x+side*.4*s,y,color,.5*s)
        line(x+side*.8*s,y+3.9*s,x+side*1.05*s,y+2.1*s,color,.35*s)
person(*ep(0,0),s=scale)
text(bx,by-23,"5.5-stud avatar reference",11,MUTED,"center")
dh(*[ep(x,0)[0] for x in (-5,5)],by-48,"10 clear opening",ext=by)
dh(*[ep(x,0)[0] for x in (-9,9)],by-80,"18 structural width",ext=by)
dv(101,by,by+12*scale,"12 clear height",ext=ep(-9,0)[0])
dv(450,by,by+18*scale,"18 architecture",ext=ep(10,0)[0])
dv(493,by,by+28*scale,"28 total incl. avatar",ext=ep(4.5,0)[0])
text(90,687,"FRONT ELEVATION",12,bold=True)
text(90,665,"Opening is about 2.2 avatar-heights, not four.",11,MUTED)

# side section, clear passage and no plinth steps
xx=825; yy=175; ss=13
line(610,yy,1129,yy,INK,1.5)
rect(xx-3*ss,yy+12*ss,6*ss,6*ss,STONE)
c.setDash([5,4]);rect(xx-4.5*ss,yy+19*ss,9*ss,9*ss,None,BLUE);c.setDash([])
text(xx,yy+23*ss,"AVATAR",12,BLUE,"center")
person(xx-7*ss,yy,s=ss)
line(xx-8*ss,yy+6*ss,xx+7*ss,yy+6*ss,BLUE,1,[4,3])
text(xx+6*ss,yy+7*ss,"Clear passage",10,BLUE,"center")
dh(xx-3*ss,xx+3*ss,yy-48,"6 structural depth",ext=yy)
dh(xx-15*ss,xx+15*ss,yy-80,"30-wide landing (plan)",ext=None)
text(632,687,"SIDE SECTION",12,bold=True)
note(632,659,"Flat threshold",["No required stairs at the mode entrances.","Keep the full 10 x 12 opening clear of mesh, signs, and effects."])
text(625,604,"Art sits above the sign, with a 1-stud support zone.",11,MUTED)
text(625,585,"Match visible mesh bounds, not imported pivot or raw Size.",11,MUTED)
text(625,562,"Both modes share opening, sign, and avatar proportions.",11,MUTED)
c.showPage()

# A-03 section and iteration contract
sheet("A-03","Levels, sightlines, and the next-build contract","A-A longitudinal section through spawn, low landmark, and gallery. Equal horizontal and vertical scale; no height exaggeration.")
sx0=102; sz0=510; ss=2.7
def sec(z,y):return sx0+(160-z)*ss,sz0+y*ss
basepoints=[sec(160,-16),sec(-160,-16),sec(-160,12),sec(-120,12),sec(-120,0),sec(132,0),sec(160,0)]
poly(basepoints,ROCK)
line(*sec(132,0),*sec(-120,0),INK,1.4)
# gallery section and center landmark
a,b=sec(-88,0);rect(a,b,28*ss,22*ss,STONE)
text(a+14*ss,b+24*ss,"GALLERY",10,INK,"center",True)
a,b=sec(10,0);rect(a,b,20*ss,1*ss,"#CDE3E4",BLUE)
a,b=sec(2,0);rect(a,b,4*ss,12*ss,STONE)
line(*sec(6,12),*sec(-6,12),GOLD,2)
text(*sec(0,17),"LOW LANDMARK +12",10,INK,"center")
person(*sec(100,0),s=ss)
text(*sec(100,13),"SPAWN +0",10,INK,"center",True)
text(*sec(150,-24),"Cliff base -16",10,MUTED)
text(*sec(-143,21),"Rear +12",10,MUTED,"center")
# approximate eye to top of arcade; keep eye height explicit reference
line(*sec(100,5),*sec(-88,22),BLUE,1,[4,4])
text(295,610,"Arrival eye line (~5 studs) to gallery crown",11,BLUE)
dh(sec(100,0)[0],sec(-88,0)[0],451,"188 spawn to gallery front (direct projection)",ext=510)
text(102,426,"The gallery remains visible beyond the low center feature. Paths pass on both sides; the eye line is not the walking route.",11,MUTED)
line(36,400,W-36,400,MUTED,.8)
cols=[48,423,798]
note(cols[0],369,"PASS 1 / Ground and camera",["Build only footprint, terraces, flat paths, and spawn.","Use the coordinates on A-01; no art or portal VFX.","Place 5.5-stud avatar references at key locations.","Capture default third-person view at actual spawn.","Both gate placeholders must fit the first view."])
note(cols[1],369,"PASS 2 / Architectural masses",["Add the shared 10 x 12 doorway module from A-02.","Measure visible bounds after every mesh placement.","Keep the 18-stud routes and flat thresholds clear.","Check sign legibility at spawn without zooming.","Match both modes before adding decoration."])
note(cols[2],369,"PASS 3 / Landscape and identity",["Add terraces, mesh heads, water, and planting.","Keep landscape outside the arrival sightline.","Four gallery alcoves, each with 2 / 1 / 3 podiums.","Measure actual walk times and capture screenshots.","Change one dimension family per iteration."])
line(48,246,W-48,246,MUTED,.6)
note(48,221,"Acceptance checks before the next art pass",["1. Spawn to either entrance: target 3-4 seconds at 16 studs/s. Verify by walking; estimates exclude turns and acceleration.","2. Door opening: 10 wide x 12 high. Statue envelope: 9 high. No scaling the whole gateway to fix imported mesh size.","3. Gallery route: target 12-15 seconds. Keep optional exploration generous without stretching the first mode choice.","4. Main paths: at least 18 clear. Terrain rises beside the routes; garden ramps no steeper than 1:8.","5. Compare the same three cameras after every pass: arrival eye level, overhead plan, and gallery looking back to spawn.","6. Save each scale revision separately. Get walkthrough feedback before wiring production spawn, travel, or leaderboards."])
c.save()
print(OUT / "Realm-Crossroads-Architecture-R2.pdf")
