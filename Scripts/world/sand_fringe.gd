class_name SandFringe
extends RefCounted
## Sand fringe overlay pieces (docs/tiles.md#sand-fringe). SAND_FRINGE_<mask>
## is drawn over an inland sand cell, on SkyIslands.FRINGE_LAYER, and shows the
## grass of its neighbours reaching into it. The mask is the island-piece mask
## over the neighbours that are not grass; 255 (no grass) has no piece.
## tools/art/gen_sand_fringe_tiles.py draws them in this order: row 14 left to
## right, then columns 13-15 of rows 8-13.

const MASKS := [
	0,
	1,
	4,
	5,
	7,
	16,
	17,
	20,
	21,
	23,
	28,
	29,
	31,
	64,
	65,
	68,
	69,
	71,
	80,
	81,
	84,
	85,
	87,
	92,
	93,
	95,
	112,
	113,
	116,
	117,
	119,
	124,
	125,
	127,
	193,
	197,
	199,
	209,
	213,
	215,
	221,
	223,
	241,
	245,
	247,
	253
]


static func atlas(index: int) -> Vector2i:
	if index < 28:
		return Vector2i(index, 14)
	return Vector2i(13 + (index - 28) % 3, 8 + (index - 28) / 3)


static func with_pieces(core: Dictionary, source_id: int) -> Dictionary:
	## TileCatalog.TILES plus one SAND_FRINGE_<mask> entry per mask.
	var t := core.duplicate()
	for i in MASKS.size():
		t["SAND_FRINGE_%03d" % MASKS[i]] = {"source_id": source_id, "atlas": atlas(i)}
	return t
