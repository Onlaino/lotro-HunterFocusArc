"""Generate pre-rendered 140x100 LOTRO Focus textures for form/style pairs.

The original Moon Arc and Moon Bow artwork is kept unchanged. All other
combinations have ten Focus frames and a transparent RGBA TGA image.
"""

from pathlib import Path
import math
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).parent
OUT = ROOT / "Images" / "Variants"
S, W, H = 4, 140, 100

PALETTES = {
    "moon": {"metal": "#c8ded5", "bright": "#8deae5", "low": "#345a60", "dark": "#122c32", "number": "#fff4d7"},
    "sun": {"metal": "#e8c287", "bright": "#ffd076", "low": "#694b30", "dark": "#39291f", "number": "#fff1cf"},
    "forest": {"metal": "#d8c98a", "bright": "#a9e791", "low": "#416347", "dark": "#243b2c", "number": "#fff4cf"},
    "shadow": {"metal": "#b1a9c4", "bright": "#d0aaff", "low": "#55446b", "dark": "#292439", "number": "#fff0e3"},
}
FORMS = ("arc", "bow", "quiver", "sigil", "fan", "line", "branch")
try:
    FONT = ImageFont.truetype("C:/Windows/Fonts/georgiab.ttf", 16*S)
except OSError:
    FONT = ImageFont.truetype("DejaVuSerif-Bold.ttf", 16*S)


def rgba(value, opacity=255):
    value = value.removeprefix("#")
    return tuple(int(value[i:i+2], 16) for i in (0, 2, 4)) + (opacity,)


def points(*pairs):
    return [(round(x*S), round(y*S)) for x, y in pairs]


def line(d, pairs, color, width):
    d.line(points(*pairs), fill=rgba(color), width=max(1, round(width*S)), joint="curve")


def polygon(d, pairs, color, outline=None):
    p = points(*pairs)
    d.polygon(p, fill=rgba(color))
    if outline:
        d.line(p + p[:1], fill=rgba(outline), width=S)


def dot(d, x, y, radius, color, outline=None, width=1):
    box = tuple(round(v*S) for v in (x-radius, y-radius, x+radius, y+radius))
    d.ellipse(box, fill=rgba(color), outline=rgba(outline) if outline else None,
              width=max(1, round(width*S)))


def arc(d, cx, cy, radius, start, end, color, width):
    box = tuple(round(v*S) for v in (cx-radius, cy-radius, cx+radius, cy+radius))
    d.arc(box, start, end, fill=rgba(color), width=max(1, round(width*S)))


def badge(d, x, y, focus, palette, radius=12):
    dot(d, x, y, radius+1.5, palette["dark"], palette["metal"], 1.8)
    d.text((round(x*S), round(y*S)), str(focus), font=FONT,
           anchor="mm", fill=rgba(palette["number"]),
           stroke_width=2, stroke_fill=rgba(palette["dark"]))


def jewel(d, x, y, active, palette, size=4):
    color = palette["bright"] if active else palette["low"]
    polygon(d, ((x,y-size),(x+size*.75,y),(x,y+size),(x-size*.75,y)),
            color, palette["metal"])
    if active:
        dot(d, x, y-1, .7, "#ffffff")


def flourish(d, x, y, palette, style):
    if style == "moon":
        arc(d, x, y, 6, 60, 280, palette["metal"], 1.4)
    elif style == "sun":
        for a in range(0, 360, 45):
            r=math.radians(a)
            line(d, ((x+7*math.cos(r),y+7*math.sin(r)),
                     (x+11*math.cos(r),y+11*math.sin(r))), palette["bright"], 1)
    elif style == "forest":
        for side in (-1, 1):
            polygon(d, ((x+side*3,y),(x+side*10,y-4),(x+side*7,y+3)),
                    palette["bright"], palette["metal"])
    else:
        for side in (-1, 1):
            polygon(d, ((x+side*2,y-6),(x+side*8,y+2),(x+side*4,y)),
                    palette["metal"], palette["bright"])


def render_arc(d, focus, p, style, bow=False):
    cx,cy = 70, 82
    radius = 58 if bow else 60
    groups = ((199,241),(249,291),(299,341)) if bow else ((190,240),(245,295),(300,350))
    start,end=groups[0][0],groups[-1][1]
    arc(d,cx,cy,radius,start,end,p["dark"],9)
    arc(d,cx,cy,radius,start,end,p["metal"],3)
    arc(d,cx,cy,radius-5,start,end,p["low"],6)
    for group,(a,b) in enumerate(groups):
        n=max(0,min(3,focus-group*3))
        if n:
            arc(d,cx,cy,radius-5,a,a+(b-a)*n/3,p["bright"],5)
        for k in range(3):
            angle=math.radians(a+(k+.5)*(b-a)/3)
            x=cx+(radius-18)*math.cos(angle)
            y=cy+(radius-18)*math.sin(angle)
            jewel(d,x,y,group*3+k<focus,p,4.4)
    for angle in ((245,295) if bow else (242.5,297.5)):
        a=math.radians(angle)
        line(d,((cx+(radius-10)*math.cos(a),cy+(radius-10)*math.sin(a)),
                (cx+(radius+6)*math.cos(a),cy+(radius+6)*math.sin(a))),p["metal"],2)
    if bow:
        a=math.radians(start); b=math.radians(end)
        left=(cx+radius*math.cos(a),cy+radius*math.sin(a))
        right=(cx+radius*math.cos(b),cy+radius*math.sin(b))
        middle=(cx,57+8*focus/9)
        line(d,(left,middle,right),p["dark"],3)
        line(d,(left,middle,right),p["metal"],1.2)
    crest_y=21 if not bow else 22
    flourish(d,cx,crest_y-8,p,style)
    badge(d,cx,crest_y,focus,p)


def render_quiver(d, focus, p, style):
    # Three tied bundles of three arrows, read from left to right.
    xs=(12,24,36,55,67,79,98,110,122)
    d.rounded_rectangle(tuple(round(v*S) for v in (6,58,134,81)),
                        radius=4*S,fill=rgba(p["dark"]),
                        outline=rgba(p["metal"]),width=S)
    for i,x in enumerate(xs):
        active=i<focus
        shaft=p["bright"] if active else p["low"]
        line(d,((x,70),(x,27)),p["dark"],5)
        line(d,((x,70),(x,27)),shaft,2.5)
        polygon(d,((x,13),(x+4.5,30),(x,26),(x-4.5,30)),
                shaft,p["metal"])
        jewel(d,x,69,active,p,3.3)
    for x in (45.5,88.5):
        line(d,((x,16),(x,80)),p["metal"],2)
    badge(d,70,85,focus,p,10)


def render_sigil(d, focus, p, style):
    top=(70,16); left=(10,87); right=(130,87)
    sides=((left,top),(top,right),(left,right))
    for group,(a,b) in enumerate(sides):
        line(d,(a,b),p["dark"],7)
        line(d,(a,b),p["metal"],3)
        n=max(0,min(3,focus-group*3))
        if n:
            t=n/3
            end=(a[0]+(b[0]-a[0])*t,a[1]+(b[1]-a[1])*t)
            line(d,(a,end),p["bright"],2)
        for k in range(3):
            t=(k+1)/4
            jewel(d,a[0]+(b[0]-a[0])*t,a[1]+(b[1]-a[1])*t,
                  group*3+k<focus,p,3.5)
    flourish(d,70,13,p,style)
    badge(d,70,62,focus,p)


def render_fan(d, focus, p, style):
    cx,cy=70,85
    angles=(198,215,232,250,270,290,308,325,342)
    for i,angle in enumerate(angles):
        a=math.radians(angle)
        ux,uy=math.cos(a),math.sin(a)
        end=(cx+ux*69,cy+uy*69)
        near=(cx+ux*61,cy+uy*61)
        color=p["bright"] if i<focus else p["low"]
        line(d,((cx,cy),end),p["dark"],5)
        line(d,((cx,cy),end),color,2.5)
        tx,ty=-uy,ux
        polygon(d,(end,(near[0]+tx*3.5,near[1]+ty*3.5),
                   (near[0]-tx*3.5,near[1]-ty*3.5)),color,p["metal"])
    for angle in (241,299):
        a=math.radians(angle)
        line(d,((cx,cy),(cx+math.cos(a)*75,cy+math.sin(a)*75)),p["metal"],1.5)
    flourish(d,cx,cy-23,p,style)
    badge(d,cx,cy,focus,p,10)


def render_line(d, focus, p, style):
    # A low-profile rail with nine round Focus cells in three clear groups.
    xs=(17,28,39,55,66,77,93,104,115)
    y=62
    d.rounded_rectangle(tuple(round(v*S) for v in (11,56,121,68)),
                        radius=5*S, fill=rgba(p["dark"]),
                        outline=rgba(p["metal"]), width=S)
    line(d,((14,y),(118,y)),p["low"],2.3)
    if focus:
        line(d,((14,y),(xs[focus-1],y)),p["bright"],2.8)
    for x in (47,85):
        line(d,((x,53),(x,71)),p["metal"],1.5)
    for index,x in enumerate(xs):
        active=index<focus
        dot(d,x,y,4.2,p["bright"] if active else p["low"],p["metal"],1.2)
        if active:
            dot(d,x-1,y-1,1.1,p["number"])
    badge(d,66,36,focus,p,10)


def render_branch(d, focus, p, style):
    # A low, gently curved Elven branch; three carved knots separate leaves.
    coords=((17,65),(28,62),(39,64),(55,66),(66,63),
            (77,65),(93,62),(104,64),(115,61))
    stem=((9,68),(28,62),(49,65),(67,63),(85,66),(105,63),(129,59))
    line(d,stem,p["dark"],6)
    line(d,stem,p["metal"],2)
    if focus:
        active_stem=((9,68),) + tuple((x,y) for x,y in stem[1:]
                                if x < coords[focus-1][0]) + (coords[focus-1],)
        line(d,active_stem,p["bright"],1.8)
    for x,y in ((47,64),(85,66)):
        dot(d,x,y,2.6,p["dark"],p["metal"],1)
        line(d,((x,y-6),(x,y+6)),p["metal"],1)
    for index,(x,y) in enumerate(coords):
        side=-1 if index%2==0 else 1
        tip=(x+side*2,y-12)
        base=(x,y)
        line(d,(base,tip),p["metal"],1)
        leaf=((tip[0],tip[1]-4),(tip[0]+5,tip[1]-1),
              (tip[0]+1,tip[1]+5),(tip[0]-4,tip[1]+1))
        active=index<focus
        polygon(d,leaf,p["bright"] if active else p["low"],p["metal"])
        if active:
            line(d,((tip[0],tip[1]-3),(tip[0]+.5,tip[1]+3)),p["number"],.6)
    # The central knot carries the number without raising the branch high.
    badge(d,69,36,focus,p,10)
    for sign in (-1,1):
        polygon(d,((69+sign*11,35),(69+sign*17,31),(69+sign*15,37)),
                p["metal"],p["bright"])


def render(form, style, focus):
    p=PALETTES[style]
    image=Image.new("RGBA",(W*S,H*S),(0,0,0,0))
    d=ImageDraw.Draw(image)
    if form in ("arc","bow"):
        render_arc(d,focus,p,style,bow=form=="bow")
    elif form=="quiver":
        render_quiver(d,focus,p,style)
    elif form=="sigil":
        render_sigil(d,focus,p,style)
    elif form=="line":
        render_line(d,focus,p,style)
    elif form=="branch":
        render_branch(d,focus,p,style)
    else:
        render_fan(d,focus,p,style)
    return image.resize((W,H),Image.Resampling.LANCZOS)


def main():
    # Keep the approved Moon Arc and Moon Bow art exactly as it is.
    combos=[(f,s) for f in FORMS for s in PALETTES
            if (f,s) not in (("arc","moon"),("bow","moon"))]
    for form,style in combos:
        directory=OUT/form/style
        directory.mkdir(parents=True,exist_ok=True)
        for focus in range(10):
            render(form,style,focus).save(directory/f"focus_{focus}.tga")
    # A contact sheet helps review the actual game-sized textures.
    sheet=Image.new("RGB",(len(FORMS)*220,4*160),(22,27,29))
    draw=ImageDraw.Draw(sheet)
    for row,style in enumerate(PALETTES):
        for col,form in enumerate(FORMS):
            original=(ROOT/"Images"/("Bow" if form=="bow" else "")/"focus_6.tga")
            art=Image.open(original).convert("RGBA") if style=="moon" and form in ("arc","bow") and original.exists() else render(form,style,6)
            sheet.paste(art,(col*220+40,row*160+34),art)
            draw.text((col*220+12,row*160+8),f"{form} / {style}",fill=(235,224,200))
    sheet.save(ROOT/"variants-contact-sheet.png")
    print(f"Generated {len(combos)*10} TGA frames")


if __name__=="__main__":
    main()
