"""Generate ten states for the elven Hunter Focus Arc artwork."""

from pathlib import Path
from PIL import Image, ImageDraw
import math


ROOT = Path(__file__).parent
OUT = ROOT / "Images"
OUT.mkdir(exist_ok=True)
W, H, S = 140, 100, 6
CX, CY = 70, 75
START, END = 190, 350
GROUPS = ((190, 242), (245, 295), (298, 350))


def point(radius, angle):
    a = math.radians(angle)
    return CX + radius * math.cos(a), CY + radius * math.sin(a)


def pxbox(radius):
    return tuple(round(v * S) for v in (
        CX - radius, CY - radius, CX + radius, CY + radius
    ))


def arc(draw, radius, color, width, start=START, end=END):
    draw.arc(pxbox(radius), start, end, fill=color, width=round(width * S))


def ellipse(draw, cx, cy, radius, color, outline=None, outline_width=1):
    draw.ellipse(((cx-radius)*S, (cy-radius)*S,
                  (cx+radius)*S, (cy+radius)*S),
                 fill=color, outline=outline,
                 width=round(outline_width*S))


def leaf(draw, angle, radius, length, width, color):
    a = math.radians(angle)
    cx, cy = point(radius, angle)
    tx, ty = -math.sin(a), math.cos(a)
    nx, ny = math.cos(a), math.sin(a)
    polygon = [
        (cx - tx*length/2, cy - ty*length/2),
        (cx + nx*width/2, cy + ny*width/2),
        (cx + tx*length/2, cy + ty*length/2),
        (cx - nx*width/2, cy - ny*width/2),
    ]
    draw.polygon([(round(x*S), round(y*S)) for x, y in polygon], fill=color)
    draw.line(((cx-tx*length*.35)*S, (cy-ty*length*.35)*S,
               (cx+tx*length*.35)*S, (cy+ty*length*.35)*S),
              fill=(39, 66, 55, 255), width=max(1, S//2))


for focus in range(10):
    canvas = Image.new("RGBA", (W*S, H*S), (0, 0, 0, 0))
    draw = ImageDraw.Draw(canvas)

    # Gold/silver frame stays fixed; the red track fills in three groups.
    arc(draw, 56, (11, 19, 19, 245), 17)
    arc(draw, 56, (116, 126, 113, 255), 14)
    arc(draw, 56, (172, 157, 112, 255), 11)
    arc(draw, 56, (29, 21, 23, 255), 8)
    for group_index, (start, end) in enumerate(GROUPS):
        arc(draw, 56, (63, 29, 27, 255), 6, start, end)
        filled = min(3, max(0, focus - group_index * 3))
        if filled:
            progress_end = start + (end - start) * filled / 3
            arc(draw, 56, (135, 23, 19, 255), 7, start, progress_end)
            arc(draw, 56, (211, 51, 35, 255), 5, start, progress_end)
            arc(draw, 56, (245, 119, 67, 240), 1.8, start, progress_end)
    arc(draw, 63, (208, 195, 145, 235), 2)
    arc(draw, 49, (98, 120, 101, 230), 1.1)

    # Relief leaves and two gold dividing marks separate each set of three.
    for angle in (213, 225, 260, 280, 315, 327):
        leaf(draw, angle, 64, 8.5, 4, (184, 174, 120, 255))
    draw.polygon([(70*S, 5*S), (74*S, 11*S), (70*S, 16*S), (66*S, 11*S)],
                 fill=(174, 163, 111, 255))
    draw.polygon([(70*S, 7*S), (72*S, 11*S), (70*S, 14*S), (68*S, 11*S)],
                 fill=(78, 159, 119, 255))
    for angle in (243.5, 296.5):
        inner = point(48, angle)
        outer = point(64, angle)
        draw.line((inner[0]*S, inner[1]*S, outer[0]*S, outer[1]*S),
                  fill=(224, 207, 142, 255), width=round(2.4*S))

    # Pointed leaf caps replace the previous heavy round end caps.
    for angle in (START, END):
        leaf(draw, angle, 56, 11, 6.5, (184, 175, 125, 255))
        x, y = point(56, angle)
        ellipse(draw, x, y, 2.3, (91, 136, 99, 255))

    # Nine high-contrast stones in visibly separated groups of three.
    for group_index, (start, end) in enumerate(GROUPS):
        for local_index in range(3):
            index = group_index * 3 + local_index
            angle = start + (end - start) * (local_index + 0.5) / 3
            x, y = point(40.5, angle)
            active = index < focus
            ellipse(draw, x, y, 5.7, (9, 18, 16, 250))
            ellipse(draw, x, y, 4.8, (211, 197, 140, 255))
            ellipse(draw, x, y, 3.6,
                    (114, 241, 153, 255) if active else (24, 57, 46, 255))
            if active:
                ellipse(draw, x-0.7, y-0.8, 1.35, (239, 255, 219, 255))

    canvas = canvas.resize((W, H), Image.Resampling.LANCZOS)
    canvas.save(OUT / f"focus_{focus}.tga")
    if focus == 9:
        canvas.resize((W*3, H*3), Image.Resampling.LANCZOS).save(ROOT / "preview.png")

# Opaque preview for chat and file viewers; game textures stay transparent.
preview_path = ROOT / "preview.png"
preview = Image.open(preview_path).convert("RGBA")
backdrop = Image.new("RGBA", preview.size, (22, 29, 28, 255))
backdrop.alpha_composite(preview)
backdrop.save(preview_path)
