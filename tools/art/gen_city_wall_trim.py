#!/usr/bin/env python3
"""Generate the two team trim textures from the stone wall atlas."""

import re

from PIL import Image

from gen_stone_wall_tiles import ARMS, ATLAS, CATALOG, COLORS

TEAMS = {
    "blue": ("#3b6fe0", "#26439a"),
    "red": ("#e04a4a", "#992e3e"),
}


def rgba(hex_color):
    return tuple(bytes.fromhex(hex_color[1:])) + (255,)


def trim(source, name, colors):
    shape = name.removeprefix("ARCHER_POST_STONE_")
    if name.startswith("WALL_"):
        shape = name.removeprefix("WALL_").removeprefix("MOSS_")
    arms = ARMS[shape.replace("_IN_", "_OUT_")]
    has_horizontal = not arms or "W" in arms or "E" in arms
    light, dark = map(rgba, colors)
    stones = {rgba(COLORS[color]) for color in ("light", "stone", "dark")}
    image = Image.new("RGBA", (16, 16))
    for y in range(16):
        for x in range(16):
            if source.getpixel((x, y)) not in stones:
                continue
            south_arm = "S" in arms and 3 <= x <= 12 and y >= 8
            north_arm = "N" in arms and y <= 6
            vertical = 3 <= x <= 12 and (not has_horizontal or north_arm or south_arm)
            if vertical and x in (9, 10):
                image.putpixel((x, y), light if x == 9 else dark)
            elif has_horizontal and not south_arm and y in (6, 7, 9, 10):
                image.putpixel((x, y), light if y in (6, 9) else dark)
    return image


def main():
    with Image.open(ATLAS) as source:
        atlas = source.convert("RGBA")
    for team, colors in TEAMS.items():
        sheet = Image.new("RGBA", atlas.size)
        for name, col, row in re.findall(r"const (\w+) := Vector2i\((\d+), (\d+)\)", CATALOG.read_text()):
            if not name.startswith(("WALL_", "ARCHER_POST_STONE_")):
                continue
            x, y = 16 * int(col), 16 * int(row)
            source = atlas.crop((x, y, x + 16, y + 16))
            sheet.paste(trim(source, name, colors), (x, y))
        sheet.save(ATLAS.with_name(f"city_wall_trim_{team}.png"), optimize=True)


if __name__ == "__main__":
    main()
