class_name ChopSprites
extends Resource
## The sprite set of one choppable variant. The first idle tile is the
## trunk or bush; any companion tiles are stacked north in order.

const HIDDEN_ALT := 1

@export var idle_tiles: Array[String] = []
## Two hit frames, each as tall as the idle stack. Variants with equal
## frame sizes can share a sheet by choosing different rows.
@export var hit_sheet: Texture2D
@export var hit_row := 0
## Four tile-sized frames: two for the hit, then two for the fall.
@export var fx_sheet: Texture2D


func set_hit_tiles(map: TileMap, cell: Vector2i, hidden: bool) -> void:
	var from_alt := 0 if hidden else HIDDEN_ALT
	var to_alt := HIDDEN_ALT if hidden else 0
	for tile in idle_tiles:
		var atlas: Vector2i = TileCatalog.TILES[tile]["atlas"]
		if (
			map.get_cell_atlas_coords(1, cell) == atlas
			and map.get_cell_alternative_tile(1, cell) == from_alt
		):
			map.set_cell(1, cell, TileCatalog.SOURCE_ID, atlas, to_alt)
		cell += Vector2i.UP
