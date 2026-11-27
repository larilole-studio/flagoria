#!/usr/bin/env python3
"""Draw the sand fringe overlay pieces (#101) into the tileset atlas.

A sand fringe piece is drawn on top of an inland sand cell and shows the
grass of its neighbours reaching into it, so sand and grass meet along a
soft edge instead of a square seam. SAND_FRINGE_<mask> uses the same
neighbour mask as the island pieces (docs/tiles.md), counted over the
neighbours that are not grass: N 1, NE 2, E 4, SE 8, S 16, SW 32, W 64,
NW 128, with a corner bit only when both of its sides are set.

Each piece is the inverse of ISLAND_BLOB_<mask>: grass (GRASS_A pixels)
where the island piece is empty, a darker grass rim where the island piece
has its outline, transparent where the island piece is grass. Mask 255 (no
grass neighbour) needs no piece, so there are 46. They fill row 14, then
columns 13-15 of rows 8-13, in ascending mask order. Rerunning rewrites the
same cells. Run from the repo root:
python3 tools/art/gen_sand_fringe_tiles.py (needs Pillow).
"""
import re

from PIL import Image

ATLAS = "art/flagoria/flagoria_tiles_v4.png"
CATALOG = "Scripts/world/tile_catalog.gd"
TILE = 16
GRASS_A = (5, 0)
OUTLINE = (42, 34, 56)
RIM = (63, 138, 60, 255)


def cells() -> list:
    out = [(x, 14) for x in range(28)]
    out += [(x, y) for y in range(8, 14) for x in range(13, 16)]
    return out


def blob_pieces() -> dict:
    text = open(CATALOG, encoding="utf-8").read()
    found = re.findall(r"const ISLAND_BLOB_(\d{3}) := Vector2i\((\d+), (\d+)\)", text)
    return {int(m): (int(x), int(y)) for m, x, y in found}


def crop(atlas: Image.Image, cell: tuple) -> Image.Image:
    x, y = cell[0] * TILE, cell[1] * TILE
    return atlas.crop((x, y, x + TILE, y + TILE))


def main() -> None:
    atlas = Image.open(ATLAS).convert("RGBA")
    grass = crop(atlas, GRASS_A).load()
    pieces = blob_pieces()
    masks = sorted(m for m in pieces if m != 255)
    slots = cells()
    assert len(masks) == len(slots) == 46, (len(masks), len(slots))
    for mask, slot in zip(masks, slots):
        blob = crop(atlas, pieces[mask]).load()
        tile = Image.new("RGBA", (TILE, TILE), (0, 0, 0, 0))
        px = tile.load()
        for y in range(TILE):
            for x in range(TILE):
                p = blob[x, y]
                if p[3] == 0:
                    px[x, y] = grass[x, y]
                elif p[:3] == OUTLINE:
                    px[x, y] = RIM
        atlas.paste(tile, (slot[0] * TILE, slot[1] * TILE))
    atlas.save(ATLAS)


if __name__ == "__main__":
    main()
