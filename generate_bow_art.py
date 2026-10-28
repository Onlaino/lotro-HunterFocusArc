"""Generate ten Lunar Bow Focus textures for the Hunter Focus Arc plugin."""

from pathlib import Path
import math

from PIL import Image, ImageDraw, ImageFilter, ImageFont


ROOT = Path(__file__).parent
OUT = ROOT / "Images" / "Bow"
OUT.mkdir(parents=True, exist_ok=True)

W, H, SCALE = 140, 100, 6
CX, CY = 70, 84
START, END = 201, 339
GROUPS = ((201, 241), (250, 290), (299, 339))
ANGLES = (207, 221, 235, 256, 270, 284, 305, 319, 333)

try:
    NUMBER_FONT = ImageFont.truetype("C:/Windows/Fonts/georgiab.ttf", 16 * SCALE)
except OSError:
    NUMBER_FONT = ImageFont.truetype("DejaVuSerif-Bold.ttf", 16 * SCALE)


def point(radius, angle):
    radians = math.radians(angle)
    return CX + radius * math.cos(radians), CY + radius * math.sin(radians)


def ellipse(draw, x, y, radius, fill, outline=None, outline_width=1):
    bounds = tuple(round(v * SCALE) for v in (
        x - radius, y - radius, x + radius, y + radius
    ))
    draw.ellipse(bounds, fill=fill, outline=outline,
                 width=round(outline_width * SCALE))


def arc(draw, radius, start, end, fill, width):
    bounds = tuple(round(v * SCALE) for v in (
        CX - radius, CY - radius, CX + radius, CY + radius
    ))
    draw.arc(bounds, start, end, fill=fill, width=round(width * SCALE))


def line(draw, vertices, fill, width):
    draw.line([(round(x * SCALE), round(y * SCALE)) for x, y in vertices],
              fill=fill, width=round(width * SCALE), joint="curve")


def polygon(draw, vertices, fill):
    draw.polygon([(round(x * SCALE), round(y * SCALE)) for x, y in vertices],
                 fill=fill)


def arrowhead(draw, angle, active):
    x, y = point(42, angle)
    radians = math.radians(angle)
    normal = (math.cos(radians), math.sin(radians))
    tangent = (-math.sin(radians), math.cos(radians))

    def vertex(outward, sideways):
        return (x + normal[0] * outward + tangent[0] * sideways,
                y + normal[1] * outward + tangent[1] * sideways)

    outer = (vertex(5.8, 0), vertex(-0.7, 4.2),
             vertex(-5.6, 0), vertex(-0.7, -4.2))
    inner = (vertex(4.5, 0), vertex(-0.8, 2.9),
             vertex(-4.2, 0), vertex(-0.8, -2.9))
    polygon(draw, outer, (205, 228, 215, 255))
    polygon(draw, inner, (104, 249, 231, 255) if active else
            (25, 70, 75, 255))
    line(draw, (vertex(2.7, 0), vertex(-2.1, 0)),
         (232, 255, 244, 255) if active else (62, 112, 112, 255), 0.7)


def render(focus):
    size = (W * SCALE, H * SCALE)
    canvas = Image.new("RGBA", size, (0, 0, 0, 0))
    glow = Image.new("RGBA", size, (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow)

    for group_index, (start, end) in enumerate(GROUPS):
        filled = min(3, max(0, focus - group_index * 3))
        if filled:
            arc(gd, 57, start, start + (end - start) * filled / 3,
                (69, 240, 225, 130), 9)
    for index, angle in enumerate(ANGLES):
        if index < focus:
            x, y = point(42, angle)
            ellipse(gd, x, y, 6, (64, 255, 222, 150))
    if focus == 9:
        ellipse(gd, CX, CY - 60, 16, (75, 247, 224, 90))
    canvas.alpha_composite(glow.filter(ImageFilter.GaussianBlur(2 * SCALE)))
    draw = ImageDraw.Draw(canvas)

    # Sculpted silver bow limbs with a dark channel for the Focus line.
    arc(draw, 62, START, END, (7, 27, 29, 255), 9)
    arc(draw, 62, START, END, (103, 139, 131, 255), 6)
    arc(draw, 62, START, END, (220, 237, 216, 255), 2)
    arc(draw, 57, START, END, (18, 56, 60, 255), 8)
    arc(draw, 57, START, END, (36, 91, 94, 255), 4)
    for group_index, (start, end) in enumerate(GROUPS):
        filled = min(3, max(0, focus - group_index * 3))
        if filled:
            progress_end = start + (end - start) * filled / 3
            arc(draw, 57, start, progress_end, (43, 184, 187, 255), 5.2)
            arc(draw, 57, start, progress_end, (177, 255, 237, 255), 1.2)
    arc(draw, 48, 205, 335, (80, 132, 127, 180), 1)

    # String tension changes with Focus. It is drawn under the arrowheads.
    left = point(62, START)
    right = point(62, END)
    middle = (CX, left[1] + 1.5 + 8 * focus / 9)
    line(draw, (left, middle, right), (8, 35, 37, 255), 3.2)
    line(draw, (left, middle, right), (196, 230, 215, 255), 1.2)
    ellipse(draw, middle[0], middle[1], 2.2,
            (139, 237, 216, 255) if focus else (104, 148, 137, 255),
            (229, 245, 220, 255), 0.7)

    # Two radial separators make the groups of three clear.
    for angle in (245.5, 294.5):
        a = point(37, angle)
        b = point(66, angle)
        line(draw, (a, b), (11, 39, 42, 255), 4.5)
        line(draw, (a, b), (217, 236, 216, 255), 2)
        ellipse(draw, b[0], b[1], 1.4, (244, 247, 217, 255))

    for angle in (START, END):
        x, y = point(62, angle)
        side = -1 if angle == START else 1
        polygon(draw, ((x - 2.5, y - 2.7), (x + 2.5, y - 2.7),
                       (x + side * 7.5, y + 7), (x + side, y + 1)),
                (184, 218, 197, 255))

    for index, angle in enumerate(ANGLES):
        arrowhead(draw, angle, index < focus)

    crest_y = CY - 60
    ellipse(draw, CX, crest_y, 13.5, (8, 30, 33, 255))
    ellipse(draw, CX, crest_y, 12.5, (210, 230, 210, 255))
    ellipse(draw, CX, crest_y, 10.6, (26, 70, 73, 255))
    if focus == 9:
        draw.arc(tuple(round(v * SCALE) for v in (
            CX - 16, crest_y - 16, CX + 16, crest_y + 16
        )), 112, 248, fill=(174, 255, 237, 255), width=round(2.2 * SCALE))
        draw.arc(tuple(round(v * SCALE) for v in (
            CX - 16, crest_y - 16, CX + 16, crest_y + 16
        )), 292, 428, fill=(174, 255, 237, 255), width=round(2.2 * SCALE))
        ellipse(draw, CX, crest_y - 17, 1.5, (255, 250, 211, 255))
    draw.text((CX * SCALE, crest_y * SCALE), str(focus),
              font=NUMBER_FONT, anchor="mm", fill=(255, 247, 215, 255),
              stroke_width=round(0.7 * SCALE),
              stroke_fill=(13, 37, 39, 255))

    return canvas.resize((W, H), Image.Resampling.LANCZOS)


for level in range(10):
    texture = render(level)
    texture.save(OUT / f"focus_{level}.tga")
    if level == 6:
        preview = texture.resize((W * 4, H * 4), Image.Resampling.LANCZOS)
        backdrop = Image.new("RGBA", preview.size, (22, 29, 28, 255))
        backdrop.alpha_composite(preview)
        backdrop.save(ROOT / "preview-bow.png")
