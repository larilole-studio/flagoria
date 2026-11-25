class_name WallBuilder
extends RefCounted
## Free-form palisades solved with structure walls and tower rings (#276, #414).
## Pieces on layer 1. Each stone side draws its own CAP_COLLAR_* on the next
## cap layer, in N, E, S, W order. Caps add no collision.

const _WorldMap := preload("res://Scripts/world/TileMap.gd")

const CAP_LAYER := 3
const CAP_LAYER_2 := 4
const CAP_LAYER_3 := 5
const CAP_LAYER_4 := 6
const CAP_LAYERS: Array[int] = [3, 4, 5, 6]
const MAX_HP := 3
const NO_WALL := Vector2i(1 << 20, 0)

## Free-form wall cells -> WallSolver entry ({"family": PALISADE, ...}).
var _wall_cells: Dictionary = {}
## Free-form cell -> remaining hit points (#35).
var _hp: Dictionary = {}
## Solved TileCatalog atlas at each free-form cell (for redraw).
var _pieces: Dictionary = {}
## Free-form cell -> full CAP_COLLAR_* list (N, E, S, W order).
var _caps: Dictionary = {}
var _map: _WorldMap


func _init(map: _WorldMap) -> void:
	_map = map


func has_wall(cell: Vector2i) -> bool:
	return _wall_cells.has(cell)


func free_cells() -> Array:
	return _wall_cells.keys()


func hp(cell: Vector2i) -> int:
	## Remaining hits on a free-form wall, or -1 when `cell` is not one.
	if not _wall_cells.has(cell):
		return -1
	return int(_hp.get(cell, MAX_HP))


func piece(cell: Vector2i) -> Vector2i:
	## Atlas at `cell` (has_wall must be true).
	return _pieces[cell]


func piece_or(cell: Vector2i, default: Vector2i) -> Vector2i:
	return _pieces.get(cell, default)


func cap_names(cell: Vector2i) -> Array:
	## Collar names on this free-form cell, or empty.
	return (_caps.get(cell, []) as Array).duplicate()


func clear() -> void:
	_wall_cells.clear()
	_pieces.clear()
	_caps.clear()
	_hp.clear()


func erase_cells(cells: Array[Vector2i]) -> bool:
	## Remove free-form walls on `cells` and re-solve the whole junction set.
	## True when at least one cell was a free-form wall.
	var removed := false
	for cell in cells:
		if not _wall_cells.has(cell):
			continue
		_erase_free(cell)
		removed = true
	if removed:
		resolve()
	return removed


func place_cells(cells: Array[Vector2i]) -> bool:
	## Write plain palisade walls on `cells` and re-solve. False and nothing
	## written when `cells` is empty or any cell is already a free-form wall.
	if cells.is_empty():
		return false
	for cell in cells:
		if _wall_cells.has(cell):
			return false
	for cell in cells:
		_wall_cells[cell] = {"family": WallSolver.PALISADE}
		_hp[cell] = MAX_HP
	resolve()
	return true


func damage(cell: Vector2i) -> int:
	## One sword hit on a free-form palisade (#35). Returns the remainder, or
	## -1 when `cell` is not a free-form wall. Does not erase; the host erases at 0.
	if not _wall_cells.has(cell):
		return -1
	var left: int = hp(cell) - 1
	_hp[cell] = left
	_paint_free(cell)
	return left


func set_hp(cell: Vector2i, amount: int) -> void:
	## Host sync: apply remaining hits after replace_from_host.
	if not _wall_cells.has(cell):
		return
	_hp[cell] = clampi(amount, 0, MAX_HP)
	_paint_free(cell)


func nearest_in_arc(origin: Vector2, direction: float, reach: float, arc: float) -> Vector2i:
	## Nearest free-form wall in the sword arc (#35), same walk as
	## ObjectRemovals.cells_in_arc. Returns NO_WALL when none qualify.
	var best := NO_WALL
	var best_dist := INF
	var half := arc * 0.5
	var cell_px: float = float(_map.tile_set.tile_size.x) * _map.global_scale.x
	var radius := int(ceil(reach / cell_px)) + 1
	var centre := _map.local_to_map(_map.to_local(origin))
	for dy in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			var cell := centre + Vector2i(dx, dy)
			if not _wall_cells.has(cell):
				continue
			var offset := _map.to_global(_map.map_to_local(cell)) - origin
			if offset.length() > reach or offset.length() <= 0.001:
				continue
			if absf(angle_difference(direction, offset.angle())) > half:
				continue
			if offset.length() < best_dist:
				best_dist = offset.length()
				best = cell
	return best


func replace_from_host(cells: Array) -> void:
	## Make the free-form chain exactly `cells` and re-solve with the auto
	## junctions. The host already checked the chain (#498).
	var keep := {}
	for cell in cells:
		if cell is Vector2i:
			keep[cell] = true
	var removed := false
	for cell: Vector2i in _wall_cells.keys():
		if keep.has(cell):
			continue
		_erase_free(cell)
		removed = true
	var added := false
	for cell: Vector2i in keep:
		if _wall_cells.has(cell):
			continue
		_wall_cells[cell] = {"family": WallSolver.PALISADE}
		_hp[cell] = MAX_HP
		added = true
	if added or removed:
		resolve()


func paint_cell(cell: Vector2i) -> void:
	## Redraw one free-form wall after a chunk draw. has_wall must be true.
	_map.set_cell(1, cell, TileCatalog.SOURCE_ID, _display_atlas(cell))
	_paint_caps(cell)


func resolve() -> void:
	## Solve free-form walls, auto structure walls and tower rings as one set.
	## Repaint every cell whose piece or cap list changed, including a corner
	## that flips when a loop closes far from the edited cell.
	var all := _union()
	var solved := WallSolver.solve(all)
	var capmap := WallSolver.caps(all)
	for cell: Vector2i in _wall_cells:
		var name: String = solved.get(cell, "PALISADE_POST")
		var atlas: Vector2i = TileCatalog.TILES[name]["atlas"]
		var caps: Array = capmap.get(cell, [])
		var changed: bool = (
			not _pieces.has(cell) or _pieces[cell] != atlas or not _same(caps, _caps.get(cell, []))
		)
		_pieces[cell] = atlas
		if caps.is_empty():
			_caps.erase(cell)
		else:
			_caps[cell] = caps.duplicate()
		if changed:
			_paint_free(cell)
	for cell: Vector2i in _map._structures.auto_cells():
		if solved.has(cell):
			_map._structures.apply_solved(cell, solved[cell])


func _union() -> Dictionary:
	var all := {}
	var autos: Dictionary = _map._structures.auto_cells()
	for cell: Vector2i in autos:
		all[cell] = autos[cell]
	for cell: Vector2i in _wall_cells:
		all[cell] = _wall_cells[cell]
	return all


func _paint_free(cell: Vector2i) -> void:
	_map.forget_cut(cell)
	_map._predict_cache.erase(cell)
	if not _map.is_drawn(cell):
		return
	_map.erase_cell(1, cell)
	_map.erase_cell(_WorldMap.GROUND_DECOR_LAYER, cell)
	_map.set_cell(1, cell, TileCatalog.SOURCE_ID, _display_atlas(cell))
	_paint_caps(cell)


func _paint_caps(cell: Vector2i) -> void:
	## One existing collar tile per stone side. Unused layers are cleared.
	var caps: Array = _caps.get(cell, [])
	for i in CAP_LAYERS.size():
		var layer: int = CAP_LAYERS[i]
		if i < caps.size():
			_map.set_cell(layer, cell, TileCatalog.SOURCE_ID, TileCatalog.TILES[caps[i]]["atlas"])
		elif _map.get_cell_source_id(layer, cell) != -1:
			_map.erase_cell(layer, cell)


func _erase_free(cell: Vector2i) -> void:
	_wall_cells.erase(cell)
	_pieces.erase(cell)
	_caps.erase(cell)
	_hp.erase(cell)
	_map.tree_sprouts().untouch(cell)
	_map.invalidate_painted_cell(cell)
	_erase_tiles(cell)


func _erase_tiles(cell: Vector2i) -> void:
	if _map.get_cell_source_id(1, cell) != -1:
		_map.erase_cell(1, cell)
	for layer in CAP_LAYERS:
		if _map.get_cell_source_id(layer, cell) != -1:
			_map.erase_cell(layer, cell)


static func _same(a: Array, b: Array) -> bool:
	if a.size() != b.size():
		return false
	for i in a.size():
		if a[i] != b[i]:
			return false
	return true


func _display_atlas(cell: Vector2i) -> Vector2i:
	## Solved piece in `_pieces`, with crack or chunk overlay when damaged (#35).
	var base: Vector2i = _pieces[cell]
	var amount: int = hp(cell)
	if amount >= MAX_HP:
		return base
	var name := atlas_wall_name(base)
	if not (name.ends_with("_H") or name.ends_with("_V")):
		return base
	var dmg := name
	if amount == 2:
		dmg = name + "_DMG_CRACK"
	elif amount == 1:
		dmg = name + "_DMG_CHUNK" if name.ends_with("_H") else name + "_DMG_CRACK"
	if not TileCatalog.TILES.has(dmg):
		return base
	var atlas: Vector2i = TileCatalog.TILES[dmg]["atlas"]
	if _tile_blocks(atlas):
		return atlas
	return base


func _tile_blocks(atlas: Vector2i) -> bool:
	var src := _map.tile_set.get_source(TileCatalog.SOURCE_ID) as TileSetAtlasSource
	if src == null or not src.has_tile(atlas):
		return false
	return src.get_tile_data(atlas, 0).get_collision_polygons_count(0) > 0


static func _atlas_wall_name(atlas: Vector2i) -> String:
	return atlas_wall_name(atlas)


static func atlas_wall_name(atlas: Vector2i) -> String:
	## WALL_*, PALISADE_* or TOWER_STONE_* name at `atlas`, or "".
	for name: String in TileCatalog.TILES:
		if (
			not name.begins_with("WALL_")
			and not name.begins_with("PALISADE_")
			and not name.begins_with("TOWER_STONE_")
		):
			continue
		if TileCatalog.TILES[name]["atlas"] == atlas:
			return name
	return ""
