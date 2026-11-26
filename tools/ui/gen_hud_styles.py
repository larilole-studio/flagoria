#!/usr/bin/env python3
"""Generate opaque pixel HUD discs, reusing the Candy Glass icon silhouettes."""

import io
from functools import cache
from pathlib import Path

import cairosvg
from PIL import Image, ImageDraw

from gen_hud_e4 import DENSITY, Doc, icon_svg

OUT = Path(__file__).resolve().parents[2] / "art/ui/hud_styles"
INK, PAPER, SAND, PARCHMENT_EDGE = "#2a2238", "#e7d7b1", "#cbb98a", "#8a5a32"
FACE, EDGE, HI, WOOD = "#e0a96b", "#74452a", "#ffe680", "#b06f3c"
STONE, SKY, GOLD, THATCH = "#8e97a3", "#7cc8f2", "#f2b632", "#e8c968"
GRASS, GRASS_HI, GRASS_DARK, LEAF = "#6fbf3a", "#b6e04c", "#3f8a3c", "#24604a"
STYLES = {
    "wood": (FACE, EDGE, HI),
    "parchment": (PAPER, SAND, THATCH),
    "stone": (STONE, INK, PAPER),
    "pixel": (GOLD, PARCHMENT_EDGE, HI),
    "banner": (LEAF, INK, GOLD),
}
BASIC = ("normal", "pressed", "disabled")
TOGGLE = BASIC + ("selected", "selected_pressed")
DISCS = [
    ("map", 24, "map", TOGGLE),
    ("menu", 24, "menu", BASIC),
    ("build", 24, "build", TOGGLE),
    ("rotate", 24, "rotate", BASIC),
    ("run", 32, "run", BASIC),
    ("attack", 40, "sword", ("idle", "pressed", "aim", "disabled")),
    ("joystick_base", 56, None, ("normal", "disabled")),
    ("joystick_knob", 24, None, ("normal", "active", "disabled")),
]
DISCS += [(f"wheel_{icon}", 24, icon, TOGGLE) for icon in ("sword", "chop", "bow")]
DISCS += [
    (f"pick_{icon}", 24, icon, TOGGLE)
    for icon in ("plank", "wall", "tower", "castle", "guard", "barracks", "mine", "demolish")
]


def silhouette(draw, style, units, inset, y, color):
    """Draw each profile on an integer grid, with the bevel underneath."""
    span = units - 1 - 2 * inset

    def point(x, z):
        return inset + round(x * span / 22), inset + y + round(z * span / 22)

    profiles = {
        "wood": [(6, 0), (16, 0), (22, 6), (22, 16), (16, 22), (6, 22), (0, 16), (0, 6)],
        "parchment": [(6, 0), (15, 0), (20, 4), (22, 9), (22, 16), (16, 22),
                      (7, 22), (2, 18), (2, 15), (0, 13), (0, 7)],
        "stone": [(6, 0), (15, 0), (21, 4), (22, 12), (20, 18), (14, 22),
                  (5, 21), (0, 15), (1, 5)],
        "banner": [(4, 0), (18, 0), (22, 4), (22, 14), (18, 19), (11, 22),
                   (4, 19), (0, 14), (0, 4)],
    }
    if style == "pixel":
        draw.ellipse([point(0, 0), point(22, 22)], fill=color)
    else:
        draw.polygon([point(x, z) for x, z in profiles[style]], fill=color)


def decorate(draw, style, units, y, state, bevel, light):
    """Draw surface details in face-relative coordinates."""
    def point(x, z):
        return round(x * (units - 1) / 23), y + round(z * (units - 1) / 23)

    def line(points, color):
        draw.line([point(x, z) for x, z in points], fill=color)

    if style == "wood":
        line([(7, 4), (15, 4), (18, 7)], light)
        line([(4, 9), (19, 9)], WOOD)
        line([(4, 15), (19, 15)], WOOD)
        line([(8, 18), (14, 18), (16, 17)], bevel)
    elif style == "parchment":
        draw.polygon([point(15, 3), point(20, 8), point(15, 7)], fill=bevel)
        line([(15, 3), (15, 7), (20, 8)], PARCHMENT_EDGE)
        line([(5, 12), (5, 16), (8, 18)], bevel)
    elif style == "stone":
        draw.polygon([point(7, 3), point(15, 3), point(17, 5),
                      point(8, 5), point(5, 9), point(5, 6)], fill=light)
        line([(18, 13), (17, 15), (18, 17), (14, 19)], bevel)
        line([(5, 14), (7, 15), (6, 17)], PAPER)
    elif style == "pixel":
        line([(7, 5), (10, 5)], light)
        line([(8, 18), (15, 18), (18, 15)], bevel)
    else:
        for x, z in [(6, 4), (10, 4), (14, 4), (17, 4), (4, 7), (19, 7),
                     (4, 11), (19, 11), (5, 15), (18, 15), (8, 17), (15, 17), (11, 19)]:
            draw.point(point(x, z), fill=light)
    if state.endswith("disabled"):
        line([(8, 17), (15, 17)], INK)


@cache
def glyph(icon, size, style, disabled):
    """Rasterize only the glyph, then snap coverage and colors to the pixel palette."""
    main = GOLD if style == "banner" else INK
    detail = LEAF if style == "banner" else PAPER
    accent = THATCH if style == "banner" else EDGE
    if disabled:
        main, detail, accent = INK, PAPER, INK
    colors = dict(main=main, shade=main, acc=accent, acc2=main, wood=accent,
                  wood2=detail, red=main, out=main)
    if icon == "map":
        colors.update(main=PAPER, shade=FACE, acc2=EDGE, red=INK, out=INK)
        if style == "banner" and not disabled:
            colors.update(main=GOLD, shade=THATCH, acc2=LEAF, red=LEAF, out=LEAF)
    if icon == "build" and not disabled:
        colors.update(shade=detail, acc2=accent)
    doc = Doc()
    icon_svg(doc, icon, 50, 50, 90, colors, ow=1.6)
    svg = doc.svg().replace("#FFFFFF", detail).encode()
    png = cairosvg.svg2png(bytestring=svg, output_width=size, output_height=size)
    image = Image.open(io.BytesIO(png)).convert("RGBA")
    palette = Image.new("P", (1, 1))
    rgb = [bytes.fromhex(color[1:]) for color in dict.fromkeys([*colors.values(), detail])]
    palette.putpalette(b"".join((rgb * 256)[:256]))
    snapped = image.convert("RGB").quantize(palette=palette, dither=Image.Dither.NONE)
    snapped = snapped.convert("RGBA")
    snapped.putalpha(image.getchannel("A").point(lambda alpha: 255 if alpha >= 128 else 0))
    return snapped


def render(style, name, units, icon, state):
    image = Image.new("RGBA", (units, units))
    draw = ImageDraw.Draw(image)
    disabled = state == "disabled"
    pressed = state.endswith("pressed") or state == "active"
    selected = state.startswith("selected") or state in ("aim", "active")
    face, bevel, light = STYLES[style]
    if style == "pixel" and name in ("run", "joystick_base", "map"):
        face, bevel, light = GRASS, GRASS_DARK, GRASS_HI
    if disabled:
        face, bevel, light = STONE, INK, SAND
    y = int(pressed)
    silhouette(draw, style, units, 0, 0, INK)
    ring = SKY if style == "pixel" else GOLD
    silhouette(draw, style, units, 1, 0, ring if selected else bevel)
    silhouette(draw, style, units, 2, y - 1, face)
    decorate(draw, style, units, y, state, bevel, light)
    center = units // 2
    if icon:
        size = round(units * (0.65 if name.startswith("pick_") else 0.60))
        stamp = glyph("close" if name == "build" and selected else icon, size, style, disabled)
        image.alpha_composite(stamp, ((units - size) // 2, (units - size) // 2 + y - 1))
    elif name == "joystick_base":
        draw.ellipse((12, 12, 43, 43), fill=bevel, outline=INK, width=1)
        for dx, dy in [(0, -18), (17, 0), (0, 17), (-18, 0)]:
            x, z = center + dx, center + dy
            draw.rectangle((x - 1, z - 1, x + 1, z + 1), fill=light)
    else:
        draw.rectangle((center - 2, center + y - 3, center + 1, center + y), fill=light)
    return image.resize((units * DENSITY,) * 2, Image.Resampling.NEAREST)


def main():
    for style in STYLES:
        folder = OUT / style
        folder.mkdir(parents=True, exist_ok=True)
        for name, units, icon, states in DISCS:
            for state in states:
                render(style, name, units, icon, state).save(folder / f"{name}_{state}.png")


if __name__ == "__main__":
    main()
