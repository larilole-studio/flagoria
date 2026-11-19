class_name GeneratedBuildings
extends Node
## Host-only on-demand building (#26). Neighbour blending (#27).

## Own layer. generate_chunk rewrites layers 0 and 1, so pieces cannot live there.
const LAYER := 7
const DEBUG_KEY := KEY_B
const STYLE_COUNT := 2

const BLOCKING := {
	"wall_straight": true,
	"wall_corner": true,
	"window": true,
	"roof_edge": true,
	"roof_fill": true,
}
const WALKABLE := {
	"floor": true,
	"door": true,
}
## Style 0 uses each piece's authored tile. Style 1 remaps the stone shell
## onto the moss set. Floor and roof tiles stay put.
const STYLE_TILES: Array = [
	{},
	{
		"WALL_H": "WALL_MOSS_H",
		"WALL_CORNER_OUT_NW": "WALL_MOSS_CORNER_OUT_NW",
		"WALL_GATE_H_OPEN": "WALL_MOSS_GATE_H_OPEN",
		"WALL_H_DMG_CRACK": "WALL_MOSS_H_BREACH",
	},
]

var _records: Array[Dictionary] = []
var _grids := {}
var _door_steps: Dictionary[Vector2i, bool] = {}
var _pieces := {}
var _repainting := false


static func mix_seed(seed_value: int, style: int) -> int:
	return int(seed_value) + int(style) * 0x85EBCA6B


static func tile_name_for(piece_id: String, style: int) -> String:
	var piece := BuildingBlockCatalog.by_id(piece_id)
	if piece == null:
		return ""
	var name := piece.tile_name
	var index := clampi(style, 0, STYLE_COUNT - 1)
	var table: Dictionary = STYLE_TILES[index]
	var mapped := str(table.get(name, name))
	if not TileCatalog.TILES.has(mapped):
		return name
	return mapped


static func layout_cells(width: int, height: int, seed_value: int, style: int) -> Array:
	## One cell dict per footprint cell, or empty when the solve fails.
	## Two calls with the same arguments return the same tiles.
	var grid := layout_grid(width, height, seed_value, style)
	if grid.is_empty():
		return []
	var out: Array = []
	for y in grid.size():
		var row: Array = grid[y]
		for x in row.size():
			var piece_id := str(row[x])
			out.append({
				"x": x,
				"y": y,
				"piece": piece_id,
				"tile": tile_name_for(piece_id, style),
			})
	return out


static func layout_grid(width: int, height: int, seed_value: int, style: int) -> Array:
	var solved := WfcBuildingConstraints.solve_building(
			width, height, mix_seed(seed_value, style))
	if not solved.ok:
		return []
	return solved.grid


func _ready() -> void:
	set_process_unhandled_input(true)
	var map := _map()
	if map != null and not map.ground_changed.is_connected(_on_ground_changed):
		map.ground_changed.connect(_on_ground_changed)
	ensure_layer(map)


func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	var key := event as InputEventKey
	if key.keycode != DEBUG_KEY and key.physical_keycode != DEBUG_KEY:
		return
	if not _is_host():
		return
	if key.shift_pressed:
		if remove_at_player():
			get_viewport().set_input_as_handled()
		return
	if generate_at_player():
		get_viewport().set_input_as_handled()


func generate_at_player() -> bool:
	## Host: one building centred on the local player, using MapGen params.
	if not _is_host():
		return false
	var body := _local_player()
	if body == null:
		return false
	var params := get_node("/root/MapGen").params as MapGenParams
	var width := clampi(int(params.building_width), 4, 16)
	var height := clampi(int(params.building_height), 4, 16)
	var style := clampi(int(params.building_style), 0, STYLE_COUNT - 1)
	var map := _map()
	var origin := map.local_to_map(map.to_local(body.global_position))
	origin -= Vector2i(width / 2, height / 2)
	return generate(origin, width, height, _seed_for(params, origin), style)


func generate(origin: Vector2i, width: int, height: int, seed_value: int, style: int) -> bool:
	## Host only. Overlap refuses. Full-edge touch merges with the lowest-index neighbour.
	if not _is_host():
		return false
	width = clampi(width, 4, 16)
	height = clampi(height, 4, 16)
	style = clampi(style, 0, STYLE_COUNT - 1)
	var record := {
		"seed": int(seed_value),
		"width": width,
		"height": height,
		"style": style,
		"x": origin.x,
		"y": origin.y,
	}
	for existing in _records:
		if BuildingMerge.rectangles_overlap(existing, record):
			return false
	if _has_record(record):
		return true
	if not WfcBuildingConstraints.solve_building(
			width, height, mix_seed(seed_value, style)).ok:
		return false
	_records.append(record)
	_rebuild_from_records()
	_broadcast_all()
	return true


func remove_at(index: int) -> bool:
	if not _is_host():
		return false
	if index < 0 or index >= _records.size():
		return false
	_records.remove_at(index)
	_rebuild_from_records()
	_broadcast_all()
	return true


func remove_at_player() -> bool:
	if not _is_host():
		return false
	var map := _map()
	var body := _local_player()
	if map == null or body == null:
		return false
	var cell := map.local_to_map(map.to_local(body.global_position))
	var index := _record_covering(cell)
	return remove_at(index) if index >= 0 else false


func sync_to_peer(peer_id: int) -> void:
	## Join snapshot. Sent after map params, on the same reliable channel.
	if _records.is_empty() or not multiplayer.is_server():
		return
	receive_generated_buildings.rpc_id(peer_id, _records.duplicate(true))


func record_count() -> int:
	return _records.size()


func grid_of(index: int) -> Array:
	if index < 0 or index >= _records.size():
		return []
	return _grids.get(_key(_records[index]), [])


func piece_at(cell: Vector2i) -> String:
	return str(_pieces.get(cell, ""))


func is_blocking(cell: Vector2i) -> bool:
	return BLOCKING.has(piece_at(cell))


func occupied_cells() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for key in _pieces.keys():
		out.append(key)
	return out


func door_cells() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for key in _pieces.keys():
		if str(_pieces[key]) == "door":
			out.append(key)
	return out


func ensure_layer(map: TileMap) -> void:
	if map == null:
		return
	if map.get_layers_count() <= LAYER:
		map.add_layer(map.get_layers_count())
	map.set_layer_name(LAYER, "buildings")
	map.set_layer_enabled(LAYER, true)
	map.set_layer_z_index(LAYER, 0)


@rpc("authority", "reliable", "call_remote")
func receive_generated_building(record: Dictionary) -> void:
	if multiplayer.get_remote_sender_id() != 1:
		return
	var stored := _stored_record(record)
	if not _has_record(stored):
		_records.append(stored)
	_rebuild_from_records()


@rpc("authority", "reliable", "call_remote")
func receive_generated_buildings(records: Array) -> void:
	if multiplayer.get_remote_sender_id() != 1:
		return
	_repainting = true
	_records.clear()
	for record in records:
		if record is Dictionary:
			_records.append(_stored_record(record))
	_rebuild_from_records()
	_repainting = false


func _rebuild_from_records() -> void:
	_grids.clear()
	for i in _records.size():
		var record := _records[i]
		var grid: Array = _layout_for(record)
		var merge_idx := BuildingMerge.find_merge_neighbour(_records, record, i)
		if merge_idx >= 0:
			var earlier := _records[merge_idx]
			var earlier_grid: Array = _grids.get(_key(earlier), _layout_for(earlier))
			var merged := BuildingMerge.merge_grids(earlier, earlier_grid, record, grid)
			if merged.get("ok", false):
				_grids[_key(earlier)] = merged.earlier_grid
				grid = merged.later_grid
		_grids[_key(record)] = grid
	_rebuild_paint()


func _rebuild_paint() -> void:
	var map := _map()
	ensure_layer(map)
	for cell in _pieces:
		map.erase_cell(LAYER, cell)
		map.invalidate_painted_cell(cell)
	for cell in _door_steps:
		map.invalidate_painted_cell(cell)
	_pieces.clear()
	_door_steps.clear()
	for record in _records:
		_paint_record(record)


func _layout_for(record: Dictionary) -> Array:
	return layout_grid(int(record.width), int(record.height), int(record.seed), int(record.style))


func _paint_record(record: Dictionary) -> void:
	var key := _key(record)
	var grid: Array = _grids.get(key, [])
	if grid.is_empty():
		push_warning("GeneratedBuildings: no grid for %s" % key)
		return
	var map := _map()
	ensure_layer(map)
	var origin := Vector2i(int(record.x), int(record.y))
	var style := int(record.style)
	for y in grid.size():
		var row: Array = grid[y]
		for x in row.size():
			var piece_id := str(row[x])
			var cell := origin + Vector2i(x, y)
			_pieces[cell] = piece_id
			_paint_cell(map, cell, piece_id, style)
			_clear_cover(map, cell, piece_id)
			if piece_id == "door":
				_clear_door_exit(map, cell, x, y, row.size(), grid.size())


func _paint_cell(map: TileMap, cell: Vector2i, piece_id: String, style: int) -> void:
	var tile_name := tile_name_for(piece_id, style)
	if tile_name == "":
		map.erase_cell(LAYER, cell)
		return
	var atlas: Vector2i = TileCatalog.TILES[tile_name]["atlas"]
	var alt := 0
	if BLOCKING.has(piece_id):
		alt = _solid_alternative(map, atlas)
	map.set_cell(LAYER, cell, TileCatalog.SOURCE_ID, atlas, alt)


func _clear_cover(map: TileMap, cell: Vector2i, piece_id: String) -> void:
	## Chunk refresh rewrites layers 0 and 1. Drop plants on the footprint, and
	## keep floor and door cells walkable after that rewrite.
	map.erase_cell(1, cell)
	map.erase_cell(map.GROUND_DECOR_LAYER, cell)
	if WALKABLE.has(piece_id) and not map.is_walkable_land(cell):
		map.claim_ground(cell, TileCatalog.GRASS_A)


func _clear_door_exit(map: TileMap, door: Vector2i, x: int, y: int, width: int, height: int) -> void:
	## The cell just outside the door stays open, so a tree or the shore does
	## not seal the only way in.
	var steps: Array[Vector2i] = []
	if x == 0:
		steps.append(Vector2i(-1, 0))
	if x == width - 1:
		steps.append(Vector2i(1, 0))
	if y == 0:
		steps.append(Vector2i(0, -1))
	if y == height - 1:
		steps.append(Vector2i(0, 1))
	for step in steps:
		var cell := door + step
		if _pieces.has(cell):
			continue
		_door_steps[cell] = true
		map.erase_cell(1, cell)
		map.erase_cell(map.GROUND_DECOR_LAYER, cell)
		if not map.is_walkable_land(cell):
			map.claim_ground(cell, TileCatalog.GRASS_A)


func _solid_alternative(map: TileMap, atlas: Vector2i) -> int:
	## A full-cell collision alternative when the authored tile does not cover
	## its centre. Alternative 0 is left alone, so a walkable dock tile stays
	## walkable everywhere else.
	var source := map.tile_set.get_source(TileCatalog.SOURCE_ID) as TileSetAtlasSource
	var count := source.get_alternative_tiles_count(atlas)
	for index in count:
		var alt := source.get_alternative_tile_id(atlas, index)
		var data := source.get_tile_data(atlas, alt)
		if data != null and _covers_center(data):
			return alt
	var created := source.create_alternative_tile(atlas)
	var tile := source.get_tile_data(atlas, created)
	tile.add_collision_polygon(0)
	tile.set_collision_polygon_points(0, 0, PackedVector2Array([
		Vector2(-8, -8), Vector2(8, -8), Vector2(8, 8), Vector2(-8, 8),
	]))
	return created


func _covers_center(data: TileData) -> bool:
	for index in data.get_collision_polygons_count(0):
		var points := data.get_collision_polygon_points(0, index)
		if Geometry2D.is_point_in_polygon(Vector2.ZERO, points):
			return true
	return false


func _on_ground_changed(_rect: Rect2i) -> void:
	if _repainting:
		return
	_repainting = true
	for record in _records:
		_paint_record(record)
	_repainting = false


func _broadcast_all() -> void:
	var peer := multiplayer.multiplayer_peer
	if peer == null or peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
		return
	if not multiplayer.is_server():
		return
	receive_generated_buildings.rpc(_records.duplicate(true))


func _has_record(record: Dictionary) -> bool:
	var want := _key(record)
	for existing in _records:
		if _key(existing) == want:
			return true
	return false


func _stored_record(record: Dictionary) -> Dictionary:
	return {
		"seed": int(record.get("seed", 0)),
		"width": int(record.get("width", 0)),
		"height": int(record.get("height", 0)),
		"style": int(record.get("style", 0)),
		"x": int(record.get("x", 0)),
		"y": int(record.get("y", 0)),
	}


func _record_covering(cell: Vector2i) -> int:
	for i in _records.size():
		var record := _records[i]
		var origin := Vector2i(int(record.x), int(record.y))
		var rect := Rect2i(origin, Vector2i(int(record.width), int(record.height)))
		if rect.has_point(cell):
			return i
	return -1


func _key(record: Dictionary) -> String:
	return "%s:%s:%s:%s:%s:%s" % [
		int(record.get("seed", 0)), int(record.get("width", 0)), int(record.get("height", 0)),
		int(record.get("style", 0)), int(record.get("x", 0)), int(record.get("y", 0)),
	]


func _seed_for(params: MapGenParams, origin: Vector2i) -> int:
	var n := _records.size() + 1
	var mixed := int(params.items_seed) ^ (n * 0x9E3779B9)
	mixed ^= origin.x * 0x45D9F3B
	mixed ^= origin.y * 0x119DE1F3
	return mixed & 0x7FFFFFFF


func _is_host() -> bool:
	return multiplayer.is_server()


func _local_player() -> Node2D:
	return get_node_or_null("../" + str(multiplayer.get_unique_id())) as Node2D


func _map() -> TileMap:
	return get_node_or_null("../worldMap") as TileMap