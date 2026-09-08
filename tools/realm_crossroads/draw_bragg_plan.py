"""Dimensioned design-only Bragg Rotunda plate; does not change Studio geometry."""
import json, math
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

ROOT=Path(__file__).resolve().parents[2]
C=json.loads((ROOT/'configs/realm_crossroads_bragg_plan.json').read_text())
OUT=ROOT/'output/realm_crossroads/Bragg-Rotunda-R6-Plan.png'
im=Image.new('RGB',(1500,1000),'#f7f3e9');d=ImageDraw.Draw(im)
font='/System/Library/Fonts/Supplemental/Arial.ttf'
bold='/System/Library/Fonts/Supplemental/Arial Bold.ttf'
def text(x,y,s,size=20,fill='#293f43',strong=False,anchor=None):
    d.text((x,y),s,font=ImageFont.truetype(bold if strong else font,size),fill=fill,anchor=anchor)
cx,cy,scale=375,420,4.7
def point(x,z):return (cx+x*scale,cy+z*scale)
def circle(r,fill,outline=None,width=1):
    q=r*scale;d.ellipse((cx-q,cy-q,cx+q,cy+q),fill=fill,outline=outline,width=width)
text(45,34,'BRAGG ROTUNDA',34,strong=True)
text(45,80,'R6 authored preview  /  14 alcoves  /  8 initial rankings',21)
text(45,113,'Each alcove holds a complete 2 – 1 – 3 podium group.',18)
circle(C['outer_radius'],'#d1d8c1','#68786b',3)
circle(54,'#eee6d6','#b4aa94',2)
circle(36,'#e1dac9','#c3b699',2)
circle(33,'#f4efe1','#c3b699',2)
circle(C['fountain_radius']+2,'#b79b67')
circle(C['fountain_radius'],'#84bfc4','#477d82',3)
circle(3,'#e2d3af','#927444',2)
text(cx,cy+64,'FOUNTAIN',17,strong=True,anchor='mm')
text(cx,cy+86,'18 studs across',15,anchor='mm')
text(cx,cy+113,'Low sculpture; open sightlines',14,anchor='mm')
for bay in C['bays']:
    angle=math.radians(33.75+(bay['number']-1)*22.5)
    radial=(math.sin(angle),math.cos(angle));tangent=(-math.cos(angle),math.sin(angle))
    wx,wz=radial[0]*C['podium_radius'],radial[1]*C['podium_radius']
    def local(x,z):return point(wx+tangent[0]*x+radial[0]*z,wz+tangent[1]*x+radial[1]*z)
    active=bay['phase']=='initial';siege=bay['source'] in ('new_tracking','new_shared_tracking')
    fill='#bdcba9' if active else '#dedfd8'
    if siege:fill='#cfa48b'
    d.polygon([local(-9,-5),local(9,-5),local(9,5),local(-9,5)],fill=fill,outline='#6e766b',width=2)
    for x,rank,col in [(-5,2,'#c2c9c9'),(0,1,'#d6b367'),(5,3,'#b78a6a')]:
        if active:
            d.polygon([local(x-1.8,-1.8),local(x+1.8,-1.8),local(x+1.8,1.8),local(x-1.8,1.8)],fill=col,outline='#6a6b63')
            px,py=local(x,0);text(px,py,str(rank),12,strong=True,anchor='mm')
    px,py=point(radial[0]*60,radial[1]*60)
    d.ellipse((px-12,py-12,px+12,py+12),fill='#293f43' if active else '#959d93')
    text(px,py,str(bay['number']),14,'#ffffff',True,'mm')
# The southern two angular slots form a wide open entrance.
x0,z0=point(-13,51);x1,z1=point(13,58)
d.rectangle((x0,z0,x1,z1),fill='#eee6d6')
ax,az=point(-35,54);bx,bz=point(35,62)
d.rectangle((ax,az,bx,bz),fill='#eee6d6',outline='#9f8155')
for n in range(9):
    x,z=point(-13,62+n*2);xx,zz=point(13,62+n*2)
    d.line((x,z,xx,zz),fill='#9f8155',width=2)
text(cx,809,'ENTRY +4',18,strong=True,anchor='mm')
text(cx,835,'8 steps',17,anchor='mm')
# Alternate accessible walking routes flank the stairs.
for side in [-1,1]:
    pts=[point(side*19,62),point(side*35,62),point(side*35,94),point(side*19,94)]
    d.polygon(pts,fill='#b0d0d3',outline='#548b93')
    px,py=point(side*27,80);text(px,py,'1:8',16,strong=True,anchor='mm')
text(47,893,'116-stud diameter • floor +4 • entry 26 studs wide',18,strong=True)
text(47,925,'~5.4 seconds from spawn to the entry at speed 24',18)
text(47,955,'Built in isolated preview. Rankings not connected.',16,fill='#806849')
text(735,159,'INITIAL DISPLAY',23,strong=True)
y=200
for b in [x for x in C['bays'] if x['phase']=='initial']:
    d.rounded_rectangle((735,y+2,769,y+31),7,fill='#a8694c' if b['source'] in ('new_tracking','new_shared_tracking') else '#627b59')
    text(752,y+16,str(b['number']),17,'white',True,'mm')
    text(786,y+1,b['name'],21,strong=True)
    text(786,y+27,'All Realms — new boss tracking' if b['source']=='new_shared_tracking' else ('Pet Siege — new tracking' if b['source']=='new_tracking' else 'Existing ranking / existing saved score'),15,fill='#677471')
    y+=62
text(735,711,'SIX RESERVE ALCOVES',23,strong=True)
text(735,748,'Gardens in bays 2 / 4 / 6 / 9 / 11 / 13',18)
text(735,779,'Three Heaven gardens / three Hell relic displays',18)
text(735,810,'Existing flower, horned skull and lantern assets',18)
text(735,865,'18-stud alcoves face inward around the fountain.',18)
text(735,896,'Build room for 14 groups; populate 8 initially.',18)
text(735,927,'Load nearby figures to preserve the avatar budget.',18)
OUT.parent.mkdir(parents=True,exist_ok=True);im.save(OUT);print(OUT)
