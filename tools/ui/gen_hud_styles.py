#!/usr/bin/env python3
"""Generate menu-palette discs and the sand reference for the in-match HUD."""

import math
from pathlib import Path

from gen_hud_e4 import icon_svg, render_discs

OUT = Path(__file__).resolve().parents[2] / "art/ui/hud_styles"
# Original sand reference palette.
INK, PAPER, WHITE = "#2a2238", "#e7d7b1", "#ffffff"
WARM, WOOD, LIGHT_GOLD = "#e0a96b", "#74452a", "#ffe680"
SAND = dict(face=PAPER, down=WARM, edge=INK, light=WHITE, mark=INK, detail=WOOD,
            shadow=True)

# Main menu theme colors from art/ui/main_menu_theme.tres.
SAGE, SAGE_LIGHT, DEEP = "#5F7160", "#8D977F", "#345A52"
MAUVE, MENU_INK, OFF_WHITE = "#4E484A", "#141B1B", "#F2EAF1"
GOLD, SLIDER, SLIDER_LIGHT, TAN = "#FFE18D", "#548789", "#79B8CE", "#8E7C73"


def menu_style(face, down, mark=OFF_WHITE, *, light=OFF_WHITE, ghost=False):
    return dict(face=face, down=down, edge=MENU_INK, light=light, mark=mark,
                shadow=not ghost, ghost=ghost, menu_palette=True,
                accent=GOLD, charge=OFF_WHITE)


SAGE_DISC = menu_style(SAGE, DEEP)
DEEP_DISC = menu_style(DEEP, MENU_INK)
GOLD_DISC = menu_style(GOLD, TAN, MENU_INK)
BUILD_DISC = menu_style(TAN, SAGE_LIGHT, MENU_INK)
ROLE = dict(SAGE_DISC, roles={
    "attack": GOLD_DISC,
    "build": BUILD_DISC,
    "pick": BUILD_DISC,
    "close": BUILD_DISC,
    "map": menu_style(SLIDER, SLIDER_LIGHT, MENU_INK),
    "menu": menu_style(MENU_INK, DEEP, GOLD),
    "wheel": DEEP_DISC,
})
DISABLED = menu_style(MAUVE, MAUVE, SAGE_LIGHT)
GHOST = menu_style(MENU_INK, MENU_INK, light=GOLD, ghost=True)
STYLES = {
    "sage": SAGE_DISC,
    "sage-light": menu_style(SAGE_LIGHT, TAN, MENU_INK),
    "deep": DEEP_DISC,
    "role": ROLE,
    "shadow": SAND,
    "ghost": GHOST,
}


def icon_colors(mark, shade, edge):
    return dict(main=mark, shade=shade, acc=mark, acc2=mark, wood=mark,
                wood2=edge, red=mark, out=edge)


def circle(doc, x, y, radius, fill, *, stroke="none", width=0, opacity=1):
    doc.add(f'<circle cx="{x}" cy="{y}" r="{radius}" fill="{fill}" fill-opacity="{opacity}"'
            f' stroke="{stroke}" stroke-width="{width}"/>')


def minimal_disc(doc, style, cx, cy, radius, pressed):
    ghost = style.get("ghost", False)
    if style.get("shadow"):
        shadow_radius = radius + 6
        doc.defs.append(
            f'<radialGradient id="shadow">'
            f'<stop offset="{(radius - 4) / shadow_radius}" stop-color="{style["edge"]}" stop-opacity=".48"/>'
            f'<stop offset="1" stop-color="{style["edge"]}" stop-opacity="0"/>'
            f'</radialGradient>'
        )
        circle(doc, cx, cy + (2 if pressed else 5), shadow_radius, "url(#shadow)")
    opacity = 0 if ghost else 1
    circle(doc, cx, cy, radius, style["down"] if pressed else style["face"],
           stroke=style["edge"], width=4.5, opacity=opacity)
    if ghost:
        rim = OFF_WHITE if pressed else style["light"]
        circle(doc, cx, cy, radius, "none", stroke=rim, width=2.6 if pressed else 1.7)
    elif not pressed:
        light = doc.grad([(0, style["light"], 0.42), (0.6, style["light"], 0)])
        circle(doc, cx, cy, radius - 3.8, "none", stroke=light, width=1.6)


def minimal_button(doc, style, cx, cy, r, face_key, icon, icon_scale=1.25,
                   pressed=False, selected=False, charge=None):
    style = style.get("roles", {}).get(face_key, style)
    accent = style.get("accent", LIGHT_GOLD)
    cy += 2 if pressed else 0
    minimal_disc(doc, style, cx, cy, r - 3, pressed)
    if charge is not None:
        # An outer arc gives Attack its charge and aim cues.
        angle = math.tau * charge
        x = cx + (r + 3) * math.sin(angle)
        y = cy - (r + 3) * math.cos(angle)
        arc = f"M{cx} {cy - r - 3} A{r + 3} {r + 3} 0 {int(charge > 0.5)} 1 {x} {y}"
        stroke = accent if charge > 0.8 else style.get("charge", WHITE)
        for color, width in ((style["edge"], 4), (stroke, 2)):
            doc.add(f'<path d="{arc}" fill="none" stroke="{color}"'
                    f' stroke-width="{width}" stroke-linecap="round"/>')
    elif selected or face_key == "close":
        ring_radius = r - 3
        if style.get("ghost"):
            ring_radius -= 5
            circle(doc, cx, cy, ring_radius, "none", stroke=style["edge"], width=4.5)
        circle(doc, cx, cy, ring_radius, "none", stroke=accent, width=2.4)

    if style.get("menu_palette"):
        mark = style["mark"]
        edge = OFF_WHITE if mark == MENU_INK else MENU_INK
        shade = DEEP if mark == MENU_INK else GOLD
        if mark == SAGE_LIGHT:
            shade = SAGE_LIGHT
        colors = icon_colors(mark, shade, edge)
        colors["#FFFFFF"] = OFF_WHITE
        if icon == "map":
            colors.update(acc2=edge, red=edge)
        if icon == "build":
            colors.update(wood=edge, shade=mark)
        icon_svg(doc, icon, cx, cy, (r - 4) * icon_scale, colors,
                 ow=2.5 if mark == MENU_INK else 4.5)
        return

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
    for name, style in STYLES.items():
        if style.get("menu_palette"):
            disabled = DISABLED
            if style["ghost"]:
                disabled = menu_style(MAUVE, MAUVE, SAGE_LIGHT, light=SAGE_LIGHT, ghost=True)
            style = dict(style, disabled_style=disabled)
        render_discs(OUT / name, style, minimal_button, minimal_joystick)


if __name__ == "__main__":
    main()
