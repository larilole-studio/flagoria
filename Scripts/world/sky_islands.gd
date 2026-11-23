class_name SkyIslands
extends RefCounted
## Sky-island ground: open sea is an empty cell (the clear colour shows through),
## land is the Island terrain, and clouds sit on their own layer. Sea still
## blocks movement, on an invisible collision layer, the way the water tile did.
##
## Logical ground (ground_tile) stays water / sand / swamp / grass so biome
## coverage and Map Settings do not move. The tile that is drawn, and that
## predict_cell reports for a land cell, is an island-edge piece where any
## neighbour is sea, and the logical tile inland. Sand and swamp never touch
## the sky.

signal clouds_painted(window: Rect2i)

const SEA_LAYER := 8
const CLOUD_LAYER := 9
const _SIDES := [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]
const _SIDE_BIT := [1, 4, 16, 64]
const _CORNER := [Vector2i(1, -1), Vector2i(1, 1), Vector2i(-1, 1), Vector2i(-1, -1)]
const _CORNER_BIT := [2, 8, 32, 128]
## Corner bit is set only when both adjacent sides are land (docs/tiles.md).
const _CORNER_SIDES := [0, 1, 1, 2, 2, 3, 3, 0]

var _logical := {}
var _sea := {}
var _painted: Dictionary[Vector2i, bool] = {}
var _last_window := Rect2i()
var _painted_probe := Vector2i.MAX


func clear() -> void:
	_logical.clear()
	_clear_drawn()
	clouds_painted.emit(Rect2i())


func _clear_drawn() -> void:
	_sea.clear()
	_painted.clear()
	_last_window = Rect2i()
	_painted_probe = Vector2i.MAX


func invalidate_cell(cell: Vector2i) -> void:
	## An edit left generated tiles to restore when this cell is in the window.
	_painted.erase(cell)
	_invalidate_window_at(cell)


func _invalidate_window_at(cell: Vector2i) -> void:
	if _last_window.has_point(cell):
		_last_window = Rect2i()


func is_sea(cell: Vector2i) -> bool:
	return _sea.has(cell)


func sea_cells() -> Array:
	return _sea.keys()


func is_drawn(map, cell: Vector2i) -> bool:
	## A generated cell. Sea is empty on layer 0, so a missing tile is not enough.
	return map.get_cell_source_id(0, cell) != -1 or _sea.has(cell)


func is_open_sea(map, cell: Vector2i) -> bool:
	## Sky, a legacy water tile, and sea that has not been drawn yet.
	## A plank bridge is ground, not sky.
	if map._bridges.has_bridge(cell):
		return false
	if map.get_cell_atlas_coords(0, cell) == TileCatalog.WATER:
		return true
	if _sea.has(cell):
		return true
	if map.get_cell_source_id(0, cell) == -1:
		return logical_ground(map, cell) == TileCatalog.WATER
	return false


func ground_tile(map, alt: float, moist: float, chance: float, biome_id: int) -> Vector2i:
	## Logical layer-0 tile. With biomes on, BiomeCatalog.TERRAIN moves the beach
	## top and swamp moisture threshold per biome; off, Map Settings apply unchanged.
	var sand_top: float = map.sand_max_alt
	var swamp_special_top: float = map.swamp_special_alt
	var swamp_moist := 0.0
	if map.biome_frequency > 0.0:
		var band: float = BiomeCatalog.terrain(biome_id, "sand_band")
		sand_top = maxf(map.water_max_alt, map.sand_max_alt + band)
		swamp_special_top = map.swamp_special_alt + band
		swamp_moist = BiomeCatalog.terrain(biome_id, "swamp_moisture")
	if alt <= map.water_max_alt:
		return TileCatalog.WATER
	if alt < sand_top:
		return TileCatalog.SAND
	if alt > sand_top and moist < swamp_moist:
		if alt < swamp_special_top and chance < 0:
			return TileCatalog.SWAMP_SPECIAL
		return TileCatalog.SWAMP
	return map.get_random_ground_vec(chance)


func logical_ground(map, cell: Vector2i) -> Vector2i:
	if _logical.has(cell):
		return _logical[cell]
	var b: int = map.biome_at(cell)
	var tile := ground_tile(map, map.cell_altitude(cell, b), map.moisture.get_noise_2d(cell.x, cell.y),
			map.items_chance.get_noise_2d(cell.x, cell.y), b)
	_logical[cell] = tile
	return tile


func display_ground(map, cell: Vector2i) -> Vector2i:
	## The atlas predict_cell and the painter share, before a bridge or structure.
	## Sea stays TileCatalog.WATER here so every existing water check still matches;
	## the painter leaves that cell empty.
	var logical: Vector2i = logical_ground(map, cell)
	if logical == TileCatalog.WATER:
		return TileCatalog.WATER
	if touches_sky(map, cell):
		return _edge_atlas(_mask(map, cell), cell)
	return logical


func paint_window(map, center: Vector2i, size: Vector2i) -> void:
	# Native TileMap.clear() can bypass script methods. A painted cell always
	# has either a ground tile or a sea collider, even after gameplay edits.
	if _painted_probe != Vector2i.MAX and map.get_cell_source_id(0, _painted_probe) == -1 \
			and map.get_cell_source_id(SEA_LAYER, _painted_probe) == -1:
		_clear_drawn()
	var window := Rect2i(center - size / 2, size)
	if window == _last_window:
		return
	_last_window = window

	var cells: Array[Vector2i] = []
	var painted := Rect2i()
	for x in range(window.position.x, window.end.x):
		for y in range(window.position.y, window.end.y):
			var cell := Vector2i(x, y)
			if _painted.has(cell):
				continue
			_painted[cell] = true
			cells.append(cell)
			var bounds := Rect2i(cell, Vector2i.ONE)
			painted = painted.merge(bounds) if painted.has_area() else bounds

	if not cells.is_empty():
		_ensure_layers(map)
		_painted_probe = cells[0]
		for cell in cells:
			_paint_cell(map, cell)
	# Stamps are clipped and resolved in window order, including on revisits.
	if DisplayServer.get_name() != "headless":
		if not map.has_node("CloudMotion"):
			var motion := CloudMotion.attach(map, CLOUD_LAYER)
			clouds_painted.connect(motion.refresh)
		_paint_clouds(map, window.position, window.size.x, window.size.y)
		clouds_painted.emit(window)
	for cell in cells:
		var b: int = map.biome_at(cell)
		map.set_tile_type_z1(cell, map.cell_altitude(cell, b), map.moisture.get_noise_2d(cell.x, cell.y),
				map.temperature.get_noise_2d(cell.x, cell.y), map.items_chance.get_noise_2d(cell.x, cell.y), b)
	if painted.has_area():
		map.ground_changed.emit(painted)


func repaint_cell(map, cell: Vector2i) -> void:
	_ensure_layers(map)
	_paint_cell(map, cell)
	_invalidate_window_at(cell)


func _paint_cell(map, cell: Vector2i) -> void:
	if map._bridges.has_bridge(cell):
		_paint_bridge(map, cell)
		return
	var logical: Vector2i = logical_ground(map, cell)
	var shown: Vector2i = map._structures.ground_at(cell, display_ground(map, cell))
	if shown == TileCatalog.WATER:
		_paint_sea(map, cell)
		return
	_sea.erase(cell)
	map.erase_cell(SEA_LAYER, cell)
	map.set_cell(0, cell, TileCatalog.SOURCE_ID, shown)
	if _spawnable(logical) and map.spawn_point == Vector2i.ZERO:
		map.spawn_point = cell


func touches_sky(map, cell: Vector2i) -> bool:
	for d in _SIDES:
		if logical_ground(map, cell + d) == TileCatalog.WATER:
			return true
	for d in _CORNER:
		if logical_ground(map, cell + d) == TileCatalog.WATER:
			return true
	return false


func claim(map, cell: Vector2i, atlas: Vector2i) -> void:
	## Something else owns this cell (a floor, a door step). Drop the sky block.
	_ensure_layers(map)
	_sea.erase(cell)
	map.erase_cell(SEA_LAYER, cell)
	map.set_cell(0, cell, TileCatalog.SOURCE_ID, atlas)
	_invalidate_window_at(cell)


func _mask(map, cell: Vector2i) -> int:
	## Land-neighbour mask. N 1, NE 2, E 4, SE 8, S 16, SW 32, W 64, NW 128.
	var side_land: Array[bool] = []
	var mask := 0
	for i in _SIDES.size():
		var land := logical_ground(map, cell + _SIDES[i]) != TileCatalog.WATER
		side_land.append(land)
		if land:
			mask += _SIDE_BIT[i]
	for i in _CORNER.size():
		if side_land[_CORNER_SIDES[i * 2]] and side_land[_CORNER_SIDES[i * 2 + 1]]:
			mask += _CORNER_BIT[i]
	return mask


func _edge_atlas(mask: int, cell: Vector2i) -> Vector2i:
	## Base piece, or a wobble variant. The pick is a hash of the cell, so
	## every peer draws the same coast. Necks (masks 17 and 68) wobble less.
	var base := "ISLAND_BLOB_%03d" % mask
	if not TileCatalog.TILES.has(base):
		return TileCatalog.GRASS_A
	var names: Array[String] = [base]
	for i in range(1, 4):
		var wobble := "%s_W%d" % [base, i]
		if TileCatalog.TILES.has(wobble):
			names.append(wobble)
	if names.size() == 1:
		return TileCatalog.TILES[base]["atlas"]
	var variant_w := 0.25 if mask == 17 or mask == 68 else 0.4
	var total := 1.0 + variant_w * float(names.size() - 1)
	var roll := float(_hash(cell, 1) % 10000) / 10000.0 * total
	if roll < 1.0:
		return TileCatalog.TILES[base]["atlas"]
	var idx := 1 + int((roll - 1.0) / variant_w)
	return TileCatalog.TILES[names[mini(idx, names.size() - 1)]]["atlas"]


func _paint_sea(map, cell: Vector2i) -> void:
	map.erase_cell(0, cell)
	map.set_cell(SEA_LAYER, cell, TileCatalog.SOURCE_ID, TileCatalog.WATER)
	_sea[cell] = true


func _paint_bridge(map, cell: Vector2i) -> void:
	map.set_cell(0, cell, TileCatalog.SOURCE_ID, map._bridges.piece(cell))
	map.erase_cell(SEA_LAYER, cell)
	_sea.erase(cell)


func _spawnable(logical: Vector2i) -> bool:
	return logical != TileCatalog.WATER and logical != TileCatalog.SAND \
			and logical != TileCatalog.SWAMP and logical != TileCatalog.SWAMP_SPECIAL


func _ensure_layers(map) -> void:
	while map.get_layers_count() <= CLOUD_LAYER:
		map.add_layer(map.get_layers_count())
	map.set_layer_name(SEA_LAYER, "sea_collision")
	map.set_layer_enabled(SEA_LAYER, true)
	map.set_layer_modulate(SEA_LAYER, Color(1, 1, 1, 0))
	map.set_layer_z_index(SEA_LAYER, -1)
	if map.get_layer_name(CLOUD_LAYER) != "clouds":
		map.set_layer_name(CLOUD_LAYER, "clouds")
		map.set_layer_enabled(CLOUD_LAYER, true)
		map.set_layer_z_index(CLOUD_LAYER, -1)


func _paint_clouds(map, origin: Vector2i, w: int, h: int) -> void:
	var rect := Rect2i(origin, Vector2i(w, h))
	for x in w:
		for y in h:
			map.erase_cell(CLOUD_LAYER, origin + Vector2i(x, y))
	for x in w:
		for y in h:
			var cell := origin + Vector2i(x, y)
			if not _sea_foot(map, cell):
				continue
			var roll := _hash(cell, 9) % 84
			if roll == 0:
				_stamp(map, rect, cell, [Vector2i.ZERO], [TileCatalog.CLOUD_S])
			elif roll == 1:
				_stamp(map, rect, cell, [Vector2i.ZERO, Vector2i.RIGHT],
						[TileCatalog.CLOUD_M_0, TileCatalog.CLOUD_M_1])
			elif roll == 2:
				_stamp(map, rect, cell, [
					Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0),
					Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1)], [
					TileCatalog.CLOUD_L_0, TileCatalog.CLOUD_L_1, TileCatalog.CLOUD_L_2,
					TileCatalog.CLOUD_L_3, TileCatalog.CLOUD_L_4, TileCatalog.CLOUD_L_5])


func _stamp(map, rect: Rect2i, anchor: Vector2i, offsets: Array, atlases: Array) -> void:
	var cells: Array[Vector2i] = []
	for offset in offsets:
		var cell: Vector2i = anchor + offset
		if not rect.has_point(cell) or not _sea_foot(map, cell):
			return
		if map.get_cell_source_id(CLOUD_LAYER, cell) != -1:
			return
		cells.append(cell)
	for i in cells.size():
		map.set_cell(CLOUD_LAYER, cells[i], TileCatalog.SOURCE_ID, atlases[i])


func _sea_foot(map, cell: Vector2i) -> bool:
	## Clouds only on sky. A bridge, or any walkable tile, is never a cloud cell.
	if map._bridges.has_bridge(cell) or map.is_walkable_land(cell):
		return false
	return _sea.has(cell) or logical_ground(map, cell) == TileCatalog.WATER


func _hash(cell: Vector2i, salt: int) -> int:
	var n := (cell.x * 374761393) ^ (cell.y * 668265263) ^ (salt * 1274126177)
	n = (n ^ (n >> 13)) * 1274126177
	return n & 0x7fffffff
