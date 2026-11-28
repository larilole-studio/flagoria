#!/usr/bin/env python3
"""Redraw the stone and moss walls in the game atlas. Requires Pillow."""

import re
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
ATLAS = ROOT / "art/flagoria/flagoria_tiles_v4.png"
CATALOG = ROOT / "Scripts/world/tile_catalog.gd"
COLORS = {
    "outline": "#2a2238",
    "shadow": "#3d3a5c",
    "light": "#c9cfd6",
    "stone": "#8e97a3",
    "dark": "#5b6270",
    "moss_light": "#6fbf3a",
    "moss_dark": "#3f8a3c",
    "wood_light": "#e0a96b",
    "wood": "#b06f3c",
    "wood_dark": "#74452a",
    "gold": "#f2b632",
    "gold_light": "#ffe680",
}
ARMS = {
    "POST": "",
    "END_N": "S",
    "END_E": "W",
    "END_S": "N",
    "END_W": "E",
    "H": "EW",
    "V": "NS",
    "CORNER_OUT_NW": "ES",
    "CORNER_OUT_NE": "SW",
    "CORNER_OUT_SW": "NE",
    "CORNER_OUT_SE": "NW",
    "T_N": "ESW",
    "T_E": "NSW",
    "T_S": "NEW",
    "T_W": "NES",
    "CROSS": "NESW",
    "GATE_H": "EW",
    "GATE_H_OPEN": "EW",
    "GATE_V": "NS",
    "H_DMG_CRACK": "EW",
    "H_DMG_CHUNK": "EW",
    "V_DMG_CRACK": "NS",
    "H_BREACH": "EW",
}


def wall(name, moss=False):
    arms = ARMS[name.replace("_IN_", "_OUT_")]
    horizontal = not arms or "E" in arms or "W" in arms
    image = Image.new("RGBA", (16, 16))
    draw = ImageDraw.Draw(image)

    def filled(x, y):
        band = (
            horizontal
            and (x >= 3 or "W" in arms)
            and (x <= 12 or "E" in arms)
            and 3 <= y <= 15
        )
        north = "N" in arms and y <= (3 if horizontal else 15)
        south = "S" in arms and y >= (8 if horizontal else 3)
        return band or (3 <= x <= 12 and (north or south))

    for y in range(16):
        for x in range(16):
            if not filled(x, y):
                continue
            if any(
                not filled(x + dx, y + dy)
                for dx, dy in ((0, -1), (1, 0), (0, 1), (-1, 0))
            ):
                color = "outline"
            elif horizontal and not ("S" in arms and 3 <= x <= 12 and y >= 8):
                if y <= 7:
                    color = "stone" if (x + 2 * (y >= 6)) % 8 == 6 else "light"
                elif y == 8:
                    color = "dark"
                elif y == 9:
                    color = "light" if x % 8 < 5 else "stone"
                elif y in (11, 14) or (x + 4 * (y >= 12)) % 8 == 6:
                    color = "dark"
                else:
                    color = "stone"
            elif x < 10:
                # The six-column cap gives way to two columns of shaded side.
                color = "stone" if y % 4 == 3 or x == 9 else "light"
            else:
                color = "stone" if x == 10 and y % 4 != 3 else "dark"

            if moss and color not in ("outline", "shadow") and 1 < x < 14 and 1 < y < 14:
                if (x + 2 * (y // 4)) % 9 in (1, 2, 3) and y % 4 in (0, 1):
                    color = "moss_light" if color == "light" else "moss_dark"
            draw.point((x, y), fill=COLORS[color])

    if "_IN_" in name:
        # Short recessed mortar line on the inside of the elbow.
        x = 8 if "E" in arms else 5
        y = 6 if "S" in arms else 9
        draw.line((x, y, x + 2, y), fill=COLORS["dark"])
    if name.startswith("GATE_"):
        draw_gate(draw, name)
    if name.endswith(("CRACK", "CHUNK", "BREACH")):
        draw_damage(draw, name)
    return image


def draw_gate(draw, name):
    if name == "GATE_V":
        draw.rectangle((3, 6, 12, 11), fill=COLORS["outline"])
        draw.rectangle((4, 7, 11, 10), fill=COLORS["wood"])
        draw.line((4, 7, 11, 7), fill=COLORS["wood_light"])
        draw.line((8, 8, 8, 10), fill=COLORS["wood_dark"])
        draw.point((7, 9), fill=COLORS["gold"])
        return

    draw.rectangle((3, 9, 12, 15), fill=COLORS["outline"])
    draw.line((4, 9, 11, 9), fill=COLORS["wood_dark"])
    if name == "GATE_H_OPEN":
        draw.rectangle((5, 10, 10, 15), fill=(0, 0, 0, 0))
        draw.line((4, 10, 4, 14), fill=COLORS["wood"])
        draw.line((11, 10, 11, 14), fill=COLORS["wood_dark"])
        draw.point((4, 11), fill=COLORS["wood_light"])
        return

    draw.rectangle((4, 10, 11, 14), fill=COLORS["wood"])
    draw.line((4, 10, 11, 10), fill=COLORS["wood_light"])
    draw.line((4, 13, 11, 13), fill=COLORS["wood_dark"])
    draw.line((8, 10, 8, 14), fill=COLORS["outline"])
    draw.point([(6, 12), (9, 12)], fill=COLORS["gold"])


def draw_damage(draw, name):
    crack = [(7, 4), (6, 7), (8, 9), (6, 12), (8, 14)]
    if name == "V_DMG_CRACK":
        crack = [(4, 5), (6, 6), (7, 8), (10, 8), (11, 10)]
    draw.line(crack, fill=COLORS["outline"])
    if name in ("H_DMG_CHUNK", "H_BREACH"):
        draw.polygon([(5, 3), (11, 3), (11, 6), (8, 8), (6, 7)], fill=(0, 0, 0, 0))
        draw.line([(5, 4), (6, 8), (8, 9), (11, 7), (11, 4)], fill=COLORS["outline"])
    if name == "H_BREACH":
        draw.polygon([(6, 9), (8, 10), (10, 8), (11, 15), (5, 15)], fill=(0, 0, 0, 0))
        draw.line([(6, 9), (5, 14), (5, 15)], fill=COLORS["outline"])
        draw.line([(10, 9), (10, 13), (11, 15)], fill=COLORS["outline"])


def archer_post(axis):
    image = wall(axis)
    draw = ImageDraw.Draw(image)
    draw.rectangle((2, 1, 13, 14), fill=COLORS["outline"])
    draw.rectangle((3, 2, 12, 13), fill=COLORS["wood_dark"])
    draw.rectangle((3, 2, 12, 8), fill=COLORS["wood_light"])
    draw.rectangle((4, 3, 11, 7), fill=COLORS["wood"])
    draw.line((3, 8, 12, 8), fill=COLORS["outline"])
    draw.line((4, 9, 11, 9), fill=COLORS["wood"])
    draw.rectangle((7, 10, 8, 13), fill=COLORS["outline"])
    draw.point((7, 5), fill=COLORS["gold_light"])
    return image


def main():
    with Image.open(ATLAS) as source:
        atlas = source.convert("RGBA")
    for name, x, y in re.findall(r"const (\w+) := Vector2i\((\d+), (\d+)\)", CATALOG.read_text()):
        if name.startswith("WALL_MOSS_"):
            image = wall(name.removeprefix("WALL_MOSS_"), moss=True)
        elif name.startswith("WALL_"):
            image = wall(name.removeprefix("WALL_"))
        elif name in ("ARCHER_POST_STONE_H", "ARCHER_POST_STONE_V"):
            image = archer_post(name[-1])
        else:
            continue
        atlas.paste(image, (16 * int(x), 16 * int(y)))
    atlas.save(ATLAS, optimize=True)


if __name__ == "__main__":
    main()
