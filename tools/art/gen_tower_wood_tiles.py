#!/usr/bin/env python3
"""Draw placeholder wooden-tower tiles (#273) into the tileset atlas.

Atlas cells (empty in v3 before this runs):
- TOWER_WOOD_POST (6, 7): a short palisade post
- TOWER_WOOD_WALL (7, 7): a short palisade wall segment

Rerunning rewrites the same cells. Run from the repo root:
python3 tools/art/gen_tower_wood_tiles.py (needs Pillow).
"""
from __future__ import annotations

import os

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
ATLAS = os.path.join(ROOT, "art", "flagoria", "flagoria_tiles_v4.png")
TILE = 16

# Wood palette (NinjaAdventure-adjacent browns).
OUTLINE = (0x14, 0x1B, 0x1B, 255)
WOOD_LIT = (0xC4, 0x8A, 0x4A, 255)
WOOD = (0x8D, 0x5A, 0x32, 255)
WOOD_SHADE = (0x5A, 0x38, 0x20, 255)
BAND = (0x6E, 0x45, 0x28, 255)

POST_CELL = (6, 7)
WALL_CELL = (7, 7)

def _blank() -> Image.Image:
    return Image.new("RGBA", (TILE, TILE), (0, 0, 0, 0))


def _post() -> Image.Image:
    img = _blank()
    px = img.load()
    # Vertical log with a flat top band.
    for y in range(2, 15):
        for x in range(5, 11):
            if x in (5, 10) or y in (2, 14):
                px[x, y] = OUTLINE
            elif y == 3:
                px[x, y] = BAND
            elif x in (6, 7):
                px[x, y] = WOOD_LIT
            elif x == 8:
                px[x, y] = WOOD
            else:
                px[x, y] = WOOD_SHADE
    return img


def _wall() -> Image.Image:
    img = _blank()
    px = img.load()
    for y in range(4, 14):
        for x in range(1, 15):
            if y in (4, 13) or x in (1, 14):
                px[x, y] = OUTLINE
            elif y == 5:
                px[x, y] = BAND
            elif (x + y) % 3 == 0:
                px[x, y] = WOOD_SHADE
            elif x % 2 == 0:
                px[x, y] = WOOD_LIT
            else:
                px[x, y] = WOOD
    return img


def _write_atlas() -> None:
    atlas = Image.open(ATLAS).convert("RGBA")
    for cell, tile in ((POST_CELL, _post()), (WALL_CELL, _wall())):
        atlas.paste(tile, (cell[0] * TILE, cell[1] * TILE))
    atlas.save(ATLAS)


def main() -> None:
    _write_atlas()
    print("wrote TOWER_WOOD_POST (6,7), TOWER_WOOD_WALL (7,7)")


if __name__ == "__main__":
    main()
