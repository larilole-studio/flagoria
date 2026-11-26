#!/usr/bin/env python3
"""Generate glass recolors and clean discs for the in-match HUD."""

import math
from pathlib import Path

from gen_hud_e4 import E4, icon_svg, render_discs

OUT = Path(__file__).resolve().parents[2] / "art/ui/hud_styles"
INK, PAPER, WHITE = "#2a2238", "#e7d7b1", "#ffffff"
SKY, OCEAN, DEEP_TEAL = "#7cc8f2", "#4a8fd6", "#24604a"
GRASS, LIME, LEAF = "#6fbf3a", "#b6e04c", "#3f8a3c"
THATCH, LIGHT_GOLD = "#e8c968", "#ffe680"
WARM, WOOD = "#e0a96b", "#74452a"

GLASS = {
    "teal": ((SKY, OCEAN, OCEAN, DEEP_TEAL), WHITE, SKY, INK),
    "leaf": ((LIME, GRASS, LEAF, DEEP_TEAL), PAPER, LIME, INK),
    "sand": ((PAPER, THATCH, WARM, WOOD), INK, WOOD, PAPER),
}


def icon_colors(mark, shade, edge):
    return dict(main=mark, shade=shade, acc=mark, acc2=mark, wood=mark,
                wood2=edge, red=mark, out=edge)


def glass_style(face, mark, shade, edge):
    colors = icon_colors(mark, shade, edge)
    # Keep small map markings readable on either a pale or ink glyph.
    colors.update(acc2=edge, red=edge)
    joy = dict(E4["joy"], base=face[1], edge=face[3], knob=face)
    return dict(E4, faces=dict.fromkeys(E4["faces"], face), out=face[3], ic=colors,
                sel=LIGHT_GOLD, ring=(INK, WHITE), joy=joy)


MINIMAL = {
    "flat": dict(face=DEEP_TEAL, down=INK, edge=INK, light=PAPER, mark=WHITE, detail=PAPER),
    "shadow": dict(face=PAPER, down=WARM, edge=INK, light=WHITE, mark=INK, detail=WOOD,
                   shadow=True),
    "ghost": dict(face=INK, down=INK, edge=INK, light=WHITE, mark=WHITE, detail=PAPER,
                  alpha=0.16),
}


def circle(doc, x, y, radius, fill, *, stroke="none", width=0, opacity=1):
    doc.add(f'<circle cx="{x}" cy="{y}" r="{radius}" fill="{fill}" fill-opacity="{opacity}"'
            f' stroke="{stroke}" stroke-width="{width}"/>')


def minimal_disc(doc, style, cx, cy, radius, pressed):
    ghost = "alpha" in style
    if style.get("shadow"):
        shadow_radius = radius + 6
        doc.defs.append(
            f'<radialGradient id="shadow">'
            f'<stop offset="{(radius - 4) / shadow_radius}" stop-color="{INK}" stop-opacity=".48"/>'
            f'<stop offset="1" stop-color="{INK}" stop-opacity="0"/>'
            f'</radialGradient>'
        )
        circle(doc, cx, cy + (2 if pressed else 5), shadow_radius, "url(#shadow)")
    opacity = (0.36 if pressed else style["alpha"]) if ghost else 1
    circle(doc, cx, cy, radius, style["down"] if pressed else style["face"],
           stroke=style["edge"], width=4.5, opacity=opacity)
    if ghost:
        circle(doc, cx, cy, radius, "none", stroke=style["light"], width=2)
    elif not pressed:
        light = doc.grad([(0, style["light"], 0.42), (0.6, style["light"], 0)])
        circle(doc, cx, cy, radius - 3.8, "none", stroke=light, width=1.6)


def minimal_button(doc, style, cx, cy, r, face_key, icon, icon_scale=1.25,
                   pressed=False, selected=False, charge=None):
    cy += 2 if pressed else 0
    minimal_disc(doc, style, cx, cy, r - 3, pressed)
    if charge is not None:
        # An outer arc gives Attack its charge and aim cues.
        angle = math.tau * charge
        x = cx + (r + 3) * math.sin(angle)
        y = cy - (r + 3) * math.cos(angle)
        arc = f"M{cx} {cy - r - 3} A{r + 3} {r + 3} 0 {int(charge > 0.5)} 1 {x} {y}"
        for color, width in ((INK, 4), (LIGHT_GOLD if charge > 0.8 else WHITE, 2)):
            doc.add(f'<path d="{arc}" fill="none" stroke="{color}"'
                    f' stroke-width="{width}" stroke-linecap="round"/>')
    elif selected or face_key == "close":
        circle(doc, cx, cy, r - 3, "none", stroke=LIGHT_GOLD, width=2.4)

    edge = PAPER if style["mark"] == INK else INK
    colors = icon_colors(style["mark"], style["detail"], edge)
    if icon == "map":
        colors.update(acc2=edge, red=edge)
    icon_svg(doc, icon, cx, cy, (r - 4) * icon_scale, colors, ow=4.5 if edge == INK else 2.5)


def minimal_joystick(doc, knob=False, active=False, *, style):
    minimal_disc(doc, style, 50, 49, 42 if knob else 45, active)
    if knob:
        circle(doc, 50, 49, 8, style["mark"], stroke=style["edge"], width=2)
    else:
        for x, y in ((50, 12), (87, 49), (50, 86), (13, 49)):
            circle(doc, x, y, 2.2, style["mark"], stroke=style["edge"], width=1.4)


def main():
    for name, colors in GLASS.items():
        render_discs(OUT / name, glass_style(*colors))
    for name, style in MINIMAL.items():
        render_discs(OUT / name, style, minimal_button, minimal_joystick)


if __name__ == "__main__":
    main()
