#!/usr/bin/env python3
"""Redraw the palisade fronts and stone collars in the game atlas."""

import re

from PIL import Image, ImageDraw

from gen_stone_wall_tiles import ARMS, ATLAS, CATALOG, COLORS, wall

OUTLINE = (42, 34, 56, 255)


def arm_shape(name):
    shape = name.removeprefix("PALISADE_").replace("_IN_", "_OUT_")
    return shape.split("_JOIN_")[0].replace("GATE_V_OPEN", "GATE_V")


def palisade_front(source, name):
    image = source.copy()
    shape = arm_shape(name)
    arms = ARMS[shape]
    has_horizontal = not arms or "E" in arms or "W" in arms
    draw = ImageDraw.Draw(image)
    for y in range(16):
        for x in range(16):
            pixel = source.getpixel((x, y))
            if not pixel[3] or pixel == OUTLINE:
                continue
            south_arm = "S" in arms and 4 <= x <= 11 and y >= 11
            if has_horizontal and 10 <= y <= 14 and not south_arm:
                # The binding caps four exposed rows of end grain.
                if y == 10 or y == 14 or x % 4 == 3:
                    color = "wood_dark"
                elif y == 11 and x % 4 == 1:
                    color = "wood_light"
                else:
                    color = "wood"
                if shape.startswith("GATE_") and 3 <= x <= 12 and y < 14:
                    continue
                draw.point((x, y), fill=COLORS[color])
            elif ("N" in arms or "S" in arms) and x in (9, 10, 11):
                if shape == "GATE_V" and 4 <= y <= 12:
                    continue
                color = "wood" if x == 9 and y % 4 != 3 else "wood_dark"
                draw.point((x, y), fill=COLORS[color])
    return image


def collar(side):
    image = Image.new("RGBA", (16, 16))
    draw = ImageDraw.Draw(image)
    if side in "EW":
        stone = wall("H")
        if side == "W":
            image.paste(stone.crop((0, 0, 4, 16)), (0, 0))
            edge, bevel, inner = 3, 4, 7
        else:
            image.paste(stone.crop((12, 0, 16, 16)), (12, 0))
            edge, bevel, inner = 12, 11, 8
        draw.polygon(
            [(edge, 3), (bevel, 3), (inner, 6), (inner, 14), (bevel, 15), (edge, 15)],
            fill=COLORS["outline"],
        )
        draw.line((edge, 4, bevel, 4, inner, 7), fill=COLORS["light"])
        draw.polygon(
            [(edge, 5), (bevel, 5), (inner, 8), (inner, 10), (edge, 8)],
            fill=COLORS["stone"],
        )
        draw.polygon(
            [(edge, 10), (inner, 11), (inner, 13), (bevel, 14), (edge, 14)],
            fill=COLORS["dark"],
        )
        draw.line((edge, 9, inner, 11), fill=COLORS["wood_light"])
    else:
        stone = wall("V")
        if side == "N":
            image.paste(stone.crop((0, 0, 16, 4)), (0, 0))
            bounds = (3, 4, 12, 6)
            band = 5
        else:
            image.paste(stone.crop((0, 12, 16, 16)), (0, 12))
            bounds = (3, 9, 12, 11)
            band = 10
        draw.rectangle(bounds, fill=COLORS["outline"])
        draw.line((4, band, 9, band), fill=COLORS["wood_light"])
        draw.line((10, band, 11, band), fill=COLORS["wood_dark"])
    return image


def tile_box(x, y):
    return (16 * x, 16 * y, 16 * (x + 1), 16 * (y + 1))


def main():
    with Image.open(ATLAS) as source:
        atlas = source.convert("RGBA")
    cells = {
        name: (int(x), int(y))
        for name, x, y in re.findall(r"const (\w+) := Vector2i\((\d+), (\d+)\)", CATALOG.read_text())
    }
    for name, (x, y) in cells.items():
        if name.startswith("PALISADE_"):
            box = tile_box(x, y)
            atlas.paste(palisade_front(atlas.crop(box), name), box[:2])
    for axis in "HV":
        box = tile_box(*cells[f"ARCHER_POST_PALISADE_{axis}"])
        post = atlas.crop(box)
        run = atlas.crop(tile_box(*cells[f"PALISADE_{axis}"]))
        edges = [(0, 0, 1, 16), (15, 0, 16, 16)] if axis == "H" else [(0, 0, 16, 1), (0, 15, 16, 16)]
        for edge in edges:
            post.paste(run.crop(edge), edge[:2])
        atlas.paste(post, box[:2])
    for i, side in enumerate("NESW"):
        atlas.paste(collar(side), ((8 + i) * 16, 4 * 16))
    atlas.save(ATLAS, optimize=True)


if __name__ == "__main__":
    main()
