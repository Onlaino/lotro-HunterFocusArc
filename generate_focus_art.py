"""Generate the ten Moon Hunter Focus states for LOTRO."""

from pathlib import Path
import math

from PIL import Image, ImageDraw, ImageFilter, ImageFont


ROOT = Path(__file__).parent
OUT = ROOT / "Images"
OUT.mkdir(exist_ok=True)

W, H, SCALE = 140, 100, 6
CX, CY = 70, 79
START, END = 190, 350
GROUPS = ((190, 240), (245, 295), (300, 350))

try:
    NUMBER_FONT = ImageFont.truetype("C:/Windows/Fonts/georgiab.ttf", 16 * SCALE)
except OSError:
    NUMBER_FONT = ImageFont.truetype("DejaVuSerif-Bold.ttf", 16 * SCALE)


def point(radius, angle):
    radians = math.radians(angle)
    return CX + radius * math.cos(radians), CY + radius * math.sin(radians)


def box(radius):
    return tuple(round(v * SCALE) for v in (
        CX - radius, CY - radius, CX + radius, CY + radius
    ))


def arc(draw, radius, color, width, start=START, end=END):
    draw.arc(box(radius), start, end, fill=color, width=round(width * SCALE))


def ellipse(draw, x, y, radius, color, outline=None, outline_width=1):
    bounds = tuple(round(v * SCALE) for v in (
        x - radius, y - radius, x + radius, y + radius
    ))
    draw.ellipse(bounds, fill=color, outline=outline,
                 width=round(outline_width * SCALE))


def polygon(draw, vertices, color):
    draw.polygon([(round(x * SCALE), round(y * SCALE)) for x, y in vertices],
                 fill=color)


def leaf(draw, angle, radius, length, width, color):
    radians = math.radians(angle)
    x, y = point(radius, angle)
    tangent = (-math.sin(radians), math.cos(radians))
    normal = (math.cos(radians), math.sin(radians))
    polygon(draw, (
        (x - tangent[0] * length / 2, y - tangent[1] * length / 2),
        (x + normal[0] * width / 2, y + normal[1] * width / 2),
        (x + tangent[0] * length / 2, y + tangent[1] * length / 2),
        (x - normal[0] * width / 2, y - normal[1] * width / 2),
    ), color)


def stone(draw, x, y, active):
    # Dark bezel, silver rim and a pointed moonstone keep empty cells visible.
    outer = ((x, y - 6.1), (x + 4.5, y), (x, y + 6.1), (x - 4.5, y))
    rim = ((x, y - 5.1), (x + 3.7, y), (x, y + 5.1), (x - 3.7, y))
    core = ((x, y - 4.1), (x + 2.8, y), (x, y + 4.1), (x - 2.8, y))
    polygon(draw, outer, (8, 25, 27, 255))
    polygon(draw, rim, (186, 210, 204, 255))
    polygon(draw, core, (117, 252, 231, 255) if active else (24, 64, 68, 255))
    if active:
        polygon(draw, ((x - 0.9, y - 2.4), (x, y - 3.1),
                       (x + 0.5, y - 1.4), (x - 0.4, y - 0.3)),
                (239, 255, 250, 255))


def render(focus):
    size = (W * SCALE, H * SCALE)
    canvas = Image.new("RGBA", size, (0, 0, 0, 0))

    # Draw the soft light first so its blur never muddies the crisp frame.
    glow = Image.new("RGBA", size, (0, 0, 0, 0))
    glow_draw = ImageDraw.Draw(glow)
    for group_index, (start, end) in enumerate(GROUPS):
        filled = min(3, max(0, focus - group_index * 3))
        if filled:
            progress_end = start + (end - start) * filled / 3
            arc(glow_draw, 55, (64, 225, 211, 115), 11, start, progress_end)
        for local_index in range(filled):
            angle = start + (end - start) * (local_index + 0.5) / 3
            x, y = point(40.5, angle)
            ellipse(glow_draw, x, y, 7, (71, 255, 222, 160))
    canvas.alpha_composite(glow.filter(ImageFilter.GaussianBlur(2.1 * SCALE)))
    draw = ImageDraw.Draw(canvas)

    # Silver arch with a dark recess for the active cyan line.
    arc(draw, 58.5, (6, 23, 26, 255), 8)
    arc(draw, 58.5, (93, 125, 126, 255), 5.8)
    arc(draw, 58.5, (213, 230, 215, 255), 2.1)
    arc(draw, 55, (14, 45, 49, 255), 10.5)
    arc(draw, 55, (25, 67, 70, 255), 7.3)
    for group_index, (start, end) in enumerate(GROUPS):
        filled = min(3, max(0, focus - group_index * 3))
        if filled:
            progress_end = start + (end - start) * filled / 3
            arc(draw, 55, (20, 125, 125, 255), 7.5, start, progress_end)
            arc(draw, 55, (76, 222, 211, 255), 5.2, start, progress_end)
            arc(draw, 55, (174, 255, 233, 255), 1.2, start, progress_end)
    arc(draw, 64, (163, 193, 181, 235), 1.5)
    arc(draw, 48, (65, 113, 111, 235), 1)

    # Quiet branch tips and two explicit separators for the 3+3+3 groups.
    for angle in (214, 226, 314, 326):
        leaf(draw, angle, 64, 6.5, 2.5, (146, 181, 171, 230))
    for angle in (242.5, 297.5):
        inner = point(47, angle)
        outer = point(64, angle)
        draw.line((inner[0] * SCALE, inner[1] * SCALE,
                   outer[0] * SCALE, outer[1] * SCALE),
                  fill=(220, 236, 217, 255), width=round(2.3 * SCALE))
    for angle in (START, END):
        leaf(draw, angle, 58, 9, 5.5, (178, 210, 197, 255))

    # Nine moonstones. Their dark centres remain distinct at zero Focus.
    for group_index, (start, end) in enumerate(GROUPS):
        for local_index in range(3):
            index = group_index * 3 + local_index
            angle = start + (end - start) * (local_index + 0.5) / 3
            x, y = point(40.5, angle)
            stone(draw, x, y, index < focus)

    # Small medallion overlaps the arch at its apex without clipping the art.
    ellipse(draw, 70, 21, 13.5, (7, 25, 27, 255))
    ellipse(draw, 70, 21, 12.5, (190, 216, 205, 255))
    ellipse(draw, 70, 21, 10.4, (20, 47, 49, 255))
    draw.text((70 * SCALE, 21 * SCALE), str(focus), font=NUMBER_FONT,
              anchor="mm", fill=(255, 245, 208, 255),
              stroke_width=round(0.8 * SCALE),
              stroke_fill=(14, 34, 34, 255))

    return canvas.resize((W, H), Image.Resampling.LANCZOS)


for level in range(10):
    texture = render(level)
    texture.save(OUT / f"focus_{level}.tga")
    if level == 6:
        preview = texture.resize((W * 4, H * 4), Image.Resampling.LANCZOS)
        backdrop = Image.new("RGBA", preview.size, (22, 29, 28, 255))
        backdrop.alpha_composite(preview)
        backdrop.save(ROOT / "preview.png")
