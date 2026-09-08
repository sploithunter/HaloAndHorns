"""R3 asset evaluation and inset-face doorway study. Does not modify Roblox."""
import json
from pathlib import Path
from reportlab.pdfgen import canvas
from reportlab.lib.colors import HexColor
from reportlab.lib.utils import ImageReader

ROOT=Path(__file__).resolve().parents[2]
D=json.loads((ROOT/'configs/realm_crossroads_gate_study.json').read_text())
OUT=ROOT/'output/pdf';OUT.mkdir(parents=True,exist_ok=True)
W,H=1190.55,841.89
c=canvas.Canvas(str(OUT/'Realm-Crossroads-Gate-Study-R3.pdf'),pagesize=(W,H))
c.setTitle('Realm Crossroads | Existing gate evaluation R3')
INK='#263F43';MUTED='#647577';BLUE='#507D91';GOLD='#B28B49'
def txt(x,y,s,size=11,color=INK,bold=False,center=False):
 c.setFillColor(HexColor(color));c.setFont('Helvetica-Bold' if bold else 'Helvetica',size)
 (c.drawCentredString if center else c.drawString)(x,y,s)
def line(x,y,a,b,color=MUTED,width=1):
 c.setStrokeColor(HexColor(color));c.setLineWidth(width);c.line(x,y,a,b)
def rect(x,y,w,h,fill=None,stroke=INK):
 c.setStrokeColor(HexColor(stroke));c.setLineWidth(.8)
 if fill:c.setFillColor(HexColor(fill))
 c.rect(x,y,w,h,stroke=1,fill=int(bool(fill)))
def poly(points,fill,stroke=INK):
 p=c.beginPath();p.moveTo(*points[0])
 for pt in points[1:]:p.lineTo(*pt)
 p.close();c.setFillColor(HexColor(fill));c.setStrokeColor(HexColor(stroke));c.drawPath(p,fill=1,stroke=1)
def header(n,title,sub):
 txt(36,802,'HALO & HORNS / REALM CROSSROADS',12,MUTED,True)
 txt(36,769,title,24,INK,True);txt(36,745,sub,11,MUTED)
 line(36,730,W-36,730)
 line(36,51,W-36,51)
 txt(36,32,'R3  |  08 SEP 2026  |  EXISTING-ASSET STUDY - NOT YET BAKED',10,MUTED)
 txt(1008,32,n,10,MUTED)
def notes(x,y,title,lines):
 txt(x,y,title,12,INK,True)
 for i,t in enumerate(lines):txt(x,y-20-i*16,t,10.5,MUTED)

header('A-04 / ASSET STUDY','Reuse the bay-end arches','Four existing Merge assets inspected in the active Studio session. Source captures retain the current gameplay overlay.')
for i,a in enumerate(D['candidates']):
 col=i%2;row=i//2;x=36+col*389;y=440-row*288
 txt(x,y+254,a['name'],13,INK,True)
 c.drawImage(ImageReader(str(ROOT/f"docs/art/realm_crossroads/gate-study/{a['key']}.jpg")),x,y+55,width=371,height=173,mask='auto')
 w,h,d=a['size'];txt(x,y+33,f'Current mesh: {w:.1f} W x {h:.1f} H x {d:.1f} D',10.5)
 if row==0:
  s=D['trial_uniform_scale'];txt(x,y+15,f'At 30%: {w*s:.1f} W x {h*s:.1f} H x {d*s:.1f} D',10.5,BLUE)
 else:
  s=24/h;txt(x,y+15,f'At 24 high: {w*s:.1f} wide x {d*s:.1f} deep',10.5,BLUE)
rx=837
notes(rx,690,'Preferred / bay-end pair',[
 'Matched pointed arches and side towers.',
 'White/gold and dark/ember identities.',
 'Architectural silhouette suits the court.',
 'Trial size: 25-30% of Merge scale.',
 'Faces go inside, not on the roof.'
])
notes(rx,563,'Alternative / return rings',[
 'Strong portal identity; existing transit FX.',
 'More like freestanding travel stations.',
 'Deep bases and raised steps need fitting.',
 'Keep as a fallback or future side portal.'
])
notes(rx,452,'Aperture is the constraint',[
 'At 30%, bay frames are about 30 x 28.',
 'Sampled base gaps shrink to ~5.4-6 wide.',
 'The arch widens higher up, then tapers.',
 'R2\'s 10 x 12 opening is not established.',
 'A scaled character test is still required.'
])
notes(rx,324,'Preserve the real art',[
 'Use visible mesh bounds for scale.',
 'Hell lightning hooks inflate Model height',
 'to 414 studs; that is not the gate height.',
 'Keep SurfaceAppearance texture maps.',
 'Copy art without gameplay hooks.'
])
notes(rx,196,'Evidence limits',[
 'Read-only inspection during Merge Play.',
 'Sizes: native MeshPart dimensions.',
 'Openings: coarse collision ray samples.',
 'No source gate or live routing changed.'
])
c.showPage()

header('A-05 / INSET FACE','One arch, one face, one clear choice','Doorway study supersedes the roof-mounted face on A-02. See A-06 for the wider entrance spacing and local lighting proposal.')
# Architectural silhouette is diagrammatic; source captures on A-04 are the actual art.
S=15;cx=298;cy=155
def p(x,y):return cx+x*S,cy+y*S
outline=[(-15,0),(-15,3),(-12,3),(-12,19),(-13,19),(-11,22),(-10,19),(-9,19),(-9,22),(-6,22),(-6,25),(-2,25),(0,28),(2,25),(6,25),(6,22),(9,22),(9,19),(10,19),(11,22),(13,19),(12,19),(12,3),(15,3),(15,0)]
poly([p(*pt) for pt in outline],'#EEE8DA')
# Measured Hell center gap: approximate 30% profile, full-depth collision projection.
rows=[(0,5.4),(.9,5.7),(2.1,6.6),(3.3,8.7),(3.9,9),(6.9,9.6),(8.1,9),(10.5,8.4),(11.7,7.5),(12.3,4.5),(12.9,0)]
hole=[p(-w/2,y) for y,w in rows]+[p(w/2,y) for y,w in reversed(rows)]
poly(hole,'#FFFFFF',BLUE)
# Place the face within the arch at conversational height.
fh=D['face_height'];fy=D['face_center_height']
c.setFillColor(HexColor('#D9E7E7'));c.setStrokeColor(HexColor(BLUE))
c.ellipse(*p(-2,fy-fh/2),*p(2,fy+fh/2),fill=1,stroke=1)
for ex in [-.65,.65]:
 c.setFillColor(HexColor(BLUE));c.circle(*p(ex,fy+.3),.15*S,fill=1,stroke=0)
line(*p(-.55,fy-.8),*p(.55,fy-.8),BLUE,1)
txt(cx,cy+fy*S-31,'FACE',9,BLUE,True,True)
# Small player alongside at the same scale.
px,py=p(-17,0)
c.setFillColor(HexColor(INK));c.circle(px,py+4.95*S,.5*S,fill=1,stroke=0)
rect(px-.6*S,py+2*S,1.2*S,2.2*S,INK)
for side in [-1,1]:line(px+side*.32*S,py+2*S,px+side*.4*S,py,INK,5)
line(34,cy,558,cy,INK,1.2)
txt(43,cy-24,'5.5-stud player',10,MUTED)
line(*p(-15,-3),*p(15,-3),MUTED,.6)
txt(cx,cy-3*S+4,'~30 outer width at 30%',11,MUTED,center=True)
line(*p(17,0),*p(17,28),MUTED,.6)
c.saveState();c.translate(*p(18,14));c.rotate(90);txt(0,0,'~28 total height; no extra head above',10,MUTED,center=True);c.restoreState()
txt(40,692,'ARCH + FACE / DIAGRAMMATIC ELEVATION',12,INK,True)
txt(40,672,'Silhouette simplified; sampled opening is approximate.',10.5,MUTED)
txt(40,652,'Use the existing textured mesh, not this outline, for the build.',10.5,MUTED)
# Callouts and interaction contract
notes(636,689,'Face placement',[
 'Start with a 5-stud-tall face, centered about 6.5 above floor.',
 'Keep it inside the opening and slightly behind its front plane.',
 'The face is non-colliding; it can recede or fade when entering.',
 'Fit each face to its visible bounds; do not enlarge the arch for it.'
])
notes(636,572,'Two ways to enter - proposed',[
 'Approach: the face looks toward the player and offers Talk / Enter.',
 'Talk: brief description of the mode, with an explicit Enter action.',
 'Step through: cross a defined threshold to enter directly.',
 'No forced conversation, and no teleport merely for standing nearby.'
])
notes(636,455,'Make the destination unmistakable',[
 'Keep FARM & FIGHT and MERGE visible on separate small signs.',
 'The face and Heaven/Hell styling identify the host, not all mode content.',
 'Use restrained portal effects behind the face so the mode name reads.'
])
notes(636,354,'Next isolated fitting pass',[
 '1. Clone only the two arch meshes with their appearance maps.',
 '2. Trial 25%, 30%, and 35% sizes beside the same reference avatar.',
 '3. Walk the threshold; inspect stair lips and narrow collision at the base.',
 '4. Fit a level landing and verify a comfortable clear passage.',
 '5. Re-measure final footprint before changing the courtyard drawing.'
])
notes(636,212,'Do not carry Merge behavior into the hub',[
 'No enemy spawn hooks, bay IDs, original return triggers, or lightning',
 'marker towers. New hub interactions need their own destination binding.',
 'Keep all proposed routing disabled until the scale review is complete.'
])
c.showPage()
header('A-06 / APPROACH LIGHT','Wider entrances, short walks, distinct atmosphere','Focused arrival-plan detail. The proposed 360 x 320 island and rear gallery remain; the two gate centers move farther apart.')
L=D['layout_proposal'];S=3;cx=322;cy=620
def plan(x,z):return cx+x*S,cy-z*S
txt(40,692,'ARRIVAL COURT / DIMENSIONED DETAIL',12,INK,True)
txt(40,672,'Gate centers X +/-40, Z +42; spawn X 0, Z +100.',10.5,MUTED)
# Neutral main routes, before the colored transition zones.
for gx,gz in L['gates']:
 line(*plan(*L['spawn']),*plan(gx,gz),'#E9E5DA',18*S)
 line(*plan(gx,gz),*plan(gx,-5),'#E9E5DA',18*S)
for i,((gx,gz),yaw) in enumerate(zip(L['gates'],L['gate_yaw'])):
 x,y=plan(gx,gz);col='#78A7A3' if i==0 else '#B16F61';fill='#E1EFDF' if i==0 else '#F1DEDC'
 c.setLineWidth(.8);c.setFillColor(HexColor(fill));c.setStrokeColor(HexColor(col));c.circle(x,y,26*S,fill=1,stroke=1)
 c.setFillColor(HexColor('#BED5B3' if i==0 else '#D2A497'));c.circle(x,y,10*S,fill=1,stroke=1)
 # An oriented art footprint, not a new gate design.
 c.saveState();c.translate(x,y);c.rotate(yaw)
 rect(-15*S,-6.5*S,30*S,13*S,None,col)
 rect(-15*S,-6.5*S,5*S,13*S,'#ECE6D9',col)
 rect(10*S,-6.5*S,5*S,13*S,'#ECE6D9',col)
 c.restoreState()
 name='HEAVEN / FARM & FIGHT' if i==0 else 'HELL / MERGE'
 txt(x,y+91,name,11,INK,True,True)
 txt(x,y-108,'26-stud transition radius',10,col,center=True)
 txt(x,y-122,'Full theme within 10',10,col,center=True)
 # Last approach stays direct.
 a,b=plan(gx*.75,gz+(100-gz)*.25)
 line(a,b,x,y,col,1)
# Center separation and neutral gap dimension bars.
x1,y=plan(-40,0);x2,_=plan(40,0)
line(x1,636,x2,636,MUTED,.7)
for x in [x1,x2]:line(x,631,x,641,MUTED,.7)
txt((x1+x2)/2,643,'80 gate-center separation',10,MUTED,center=True)
left,yy=plan(-14,42);right,_=plan(14,42)
line(left,yy-60,right,yy-60,MUTED,.7)
txt(cx,yy-78,'28 neutral gap',10,INK,center=True)
x,y=plan(*L['spawn']);c.setFillColor(HexColor('#F5F0E2'));c.setStrokeColor(HexColor(GOLD));c.circle(x,y,10*S,fill=1,stroke=1)
txt(x,y-4,'SPAWN',11,INK,True,True)
txt(x,y-47,'Neutral daylight',11,MUTED,center=True)
txt(x,y-68,'~70.5 studs / 4.4 sec to either gate center',11,INK,center=True)
txt(x,y-85,'Entry threshold can sit a few studs before the center.',10,MUTED,center=True)
txt(cx,600,'Neutral route',10,MUTED,center=True);txt(cx,585,'to gallery',10,MUTED,center=True)
txt(42,128,'Scale: 1 drawing interval = 20 studs',10,MUTED)
line(42,108,102,108,INK,3);line(42,103,42,113,INK);line(102,103,102,113,INK)
notes(654,690,'Heaven approach',[
 'Soft golden light, pale sky tint, clean warm highlights.',
 'Brighten gradually through the final approach.',
 'Keep the face and mode name readable; avoid glare.'
])
notes(654,586,'Hell approach',[
 'Cooler/darker ambience with warm ember highlights.',
 'Increase contrast gradually; keep the walking surface legible.',
 'Let the face and arch glow carry the focal point.'
])
notes(654,482,'Neutral arrival and gallery',[
 'Both zones stop before the center strip; no direct theme clash.',
 'Restore the base look when leaving a gate approach.',
 'Use distance-based easing rather than a hard boundary.'
])
notes(654,378,'Keep the first choice fast',[
 'An 80-stud separation allows wider mesh landings and planting.',
 'Direct routes keep the first choice to about four seconds.',
 'Verify both mode signs in the actual default spawn camera.',
 'If clipped, adjust depth or camera framing before widening again.'
])
notes(654,258,'Implementation contract for later',[
 'Use the existing client atmosphere system as the integration point.',
 'Each player sees their own transition; do not change all players.',
 'Scope hub zones so Farm & Fight layer lighting cannot fight them.',
 'Animate numeric lighting/tint; handle sky changes deliberately.',
 'This is a proposed layout and lighting study, not a live effect.'
])
c.save()
print(OUT/'Realm-Crossroads-Gate-Study-R3.pdf')
