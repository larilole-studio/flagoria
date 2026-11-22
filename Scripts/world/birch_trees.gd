class_name BirchTrees
extends RefCounted
## Two-cell birch trees on CONTINENTAL broadleaf land (biomes on only). The
## bottom cell blocks like TREE; the top draws on layer 1 one tile north with
## no collision. TileMap calls these helpers from set_tile_type_z1 and
## predict_cell; TreeCuts clears the top when the bottom is chopped.

const _WorldMap := preload("res://Scripts/world/TileMap.gd")
const BOTTOM := TileCatalog.TREE_BIRCH_BOTTOM
const TOP := TileCatalog.TREE_BIRCH_TOP
const NORTH := Vector2i(0, -1)


static func top_cell(bottom: Vector2i) -> Vector2i:
	return bottom + NORTH


static func bottom_would_grow(map: _WorldMap, cell: Vector2i, alt: float, moist: float, chance: float, biome_id: int) -> bool:
	## True when plant_tile would be a plain oak here and the birch chance band
	## passes (before top-cell placement rules).
	if map.biome_frequency <= 0.0:
		return false
	var tree_chance := map.tree_min_chance + BiomeCatalog.plants(biome_id, "tree_chance")
	if not (moist > 0 and alt > map.tree_min_alt and chance > tree_chance):
		return false
	if moist > map.bushy_tree_min_moist + BiomeCatalog.plants(biome_id, "bushy_moist"):
		return false
	return chance > map.birch_min_chance + BiomeCatalog.plants(biome_id, "birch_chance")


static func top_can_hold(map: _WorldMap, top: Vector2i) -> bool:
	## Walkable land above a birch bottom with no other layer-1 plant there in
	## the generated map (flowers and stones on decor still allowed).
	var ground: Vector2i
	if map.get_cell_source_id(0, top) != -1:
		ground = map.get_cell_atlas_coords(0, top)
	else:
		var b := map.biome_at(top)
		var alt := map.cell_altitude(top, b)
		var moist := map.moisture.get_noise_2d(top.x, top.y)
		var chance := map.items_chance.get_noise_2d(top.x, top.y)
		ground = map.ground_tile(alt, moist, chance, b)
	if not map.ground_is_walkable(ground):
		return false
	if map.biome_frequency > 0.0 and (ground == TileCatalog.SAND or map._sky.logical_ground(map, top) == TileCatalog.SAND):
		return false
	var b := map.biome_at(top)
	var alt := map.cell_altitude(top, b)
	var moist := map.moisture.get_noise_2d(top.x, top.y)
	var chance := map.items_chance.get_noise_2d(top.x, top.y)
	return PlantPicker.plant_tile(map, alt, moist, chance, b) == _WorldMap.NO_PLANT


static func bottom_can_place(map: _WorldMap, bottom: Vector2i) -> bool:
	return top_can_hold(map, top_cell(bottom))


static func canopy_for(map: _WorldMap, cell: Vector2i, generated_only: bool = false) -> Vector2i:
	## Sprout selection and untouched-map counts use generated foliage only.
	if map.biome_frequency <= 0.0:
		return _WorldMap.NO_PLANT
	var below := cell - NORTH
	if not generated_only and foliage_blocked(map, below):
		return _WorldMap.NO_PLANT
	var b := map.biome_at(below)
	var alt := map.cell_altitude(below, b)
	var moist := map.moisture.get_noise_2d(below.x, below.y)
	var chance := map.items_chance.get_noise_2d(below.x, below.y)
	var ground := map.ground_tile(alt, moist, chance, b)
	if ground == TileCatalog.SAND or not map.ground_is_walkable(ground):
		return _WorldMap.NO_PLANT
	if bottom_would_grow(map, below, alt, moist, chance, b) and bottom_can_place(map, below):
		return TOP
	if not generated_only and map.tree_sprouts().tile_or(below, _WorldMap.NO_PLANT) == BOTTOM \
			and PlantPicker.plant_tile(map, alt, moist, chance, b) == _WorldMap.NO_PLANT:
		return TOP
	return _WorldMap.NO_PLANT


static func foliage_blocked(map: _WorldMap, cell: Vector2i) -> bool:
	return map.has_cut(cell) or map._structures.has_cell(cell) or map.has_wall(cell) \
			or map.has_bridge(cell) or map._object_removals.has_removed(cell)


static func paint_top(map: _WorldMap, bottom: Vector2i) -> void:
	var top := top_cell(bottom)
	if foliage_blocked(map, top):
		return
	map.set_cell(1, top, TileCatalog.SOURCE_ID, TOP)


static func clear_top(map: _WorldMap, bottom: Vector2i) -> void:
	var top := top_cell(bottom)
	if map.get_cell_atlas_coords(1, top) == TOP:
		map.erase_cell(1, top)
	map.invalidate_painted_cell(top)


static func is_tree_tile(atlas: Vector2i) -> bool:
	return atlas == BOTTOM


static func foliage_tile(map: _WorldMap, cell: Vector2i, alt: float, moist: float, chance: float, biome_id: int, beach: bool, generated_only: bool = false) -> Vector2i:
	## Layer-1 plant from noise before sprouts and stones; birch canopy wins first.
	var canopy := canopy_for(map, cell, generated_only)
	if canopy != _WorldMap.NO_PLANT:
		return canopy
	if map.biome_frequency <= 0.0 or not beach:
		var tile := PlantPicker.plant_tile(map, alt, moist, chance, biome_id)
		if tile == TileCatalog.TREE and bottom_would_grow(map, cell, alt, moist, chance, biome_id) \
				and bottom_can_place(map, cell):
			return BOTTOM
		return tile
	return _WorldMap.NO_PLANT


static func paint_bottom(map: _WorldMap, bottom: Vector2i) -> void:
	map.set_cell(1, bottom, TileCatalog.SOURCE_ID, BOTTOM)
	paint_top(map, bottom)
