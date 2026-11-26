extends RefCounted
## Refreshes, paints and predicts generated map chunks.


static func refresh(map, delta):
	map.play_time += delta
	map.mine_production.advance(delta)
	map.count += 1
	if (map.count % map.chunk_refresh_frames) == 0:
		map.regrow_due()
		map._tree_cuts.sprouts.due()
	if (map.count % map.chunk_refresh_frames) == 0 and map.player_spawned:
		var current_player_id = str(map.multiplayer.get_unique_id())
		map.count = 0

		var curr_player = map.get_node_or_null("/root/Flagoria/World/" + str(current_player_id))
		if curr_player:
			map.generate_chunk(curr_player.position)


static func generate_chunk(map, position) -> void:
	map._sky.paint_window(
		map, map.local_to_map(position), Vector2i(map.chunk_width, map.chunk_height)
	)


static func invalidate_painted_cell(map, cell: Vector2i) -> void:
	map._predict_cache.erase(cell)
	map._sky.invalidate_cell(cell)


static func biome_at(map, cell: Vector2i) -> int:
	## Biome id at a cell. Frequency 0 keeps everything temperate (biomes off).
	if map.biome_frequency <= 0.0:
		return BiomeCatalog.TEMPERATE
	return BiomeCatalog.from_noise(map.biome.get_noise_2d(cell.x, cell.y), map.biome_edge)


static func get_random_ground_vec(map, chance):
	if chance < map.ground_chance_a:
		return TileCatalog.GRASS_A
	if chance < map.ground_chance_b:
		return TileCatalog.GRASS_B
	if chance < map.ground_chance_c:
		return TileCatalog.GRASS_C
	return TileCatalog.GRASS_D


static func set_tile_type_z1(
	map, pos_vec, alt, moist, _temp, chance, biome_id: int = BiomeCatalog.TEMPERATE
):
	if map._object_removals.has_removed(pos_vec):
		return
	if map._structures.has_cell(pos_vec):
		if map._structures.object_at(pos_vec) != map.NO_PLANT:
			map.set_cell(1, pos_vec, TileCatalog.SOURCE_ID, map._structures.object_at(pos_vec))
		return
	if map._walls.has_wall(pos_vec):
		map._walls.paint_cell(pos_vec)
		return
	if not map.is_walkable_land(pos_vec) or map._bridges.has_bridge(pos_vec):
		return
	if map._tree_cuts.has_cut(pos_vec):
		map.set_cell(
			map.GROUND_DECOR_LAYER, pos_vec, TileCatalog.SOURCE_ID, map._tree_cuts.leftover(pos_vec)
		)
		return
	var tile: Vector2i = BirchTrees.foliage_tile(
		map,
		pos_vec,
		alt,
		moist,
		chance,
		biome_id,
		(
			map.get_cell_atlas_coords(0, pos_vec) == TileCatalog.SAND
			or map._sky.logical_ground(map, pos_vec) == TileCatalog.SAND
		)
	)
	if map.starter_grove.has(pos_vec):
		tile = TileCatalog.TREE
	if tile == map.NO_PLANT:
		tile = map._tree_cuts.sprouts.tile_or(pos_vec, map.structure_tile(chance, biome_id))
	if tile != map.NO_PLANT and BirchTrees.is_tree_tile(tile):
		BirchTrees.paint_bottom(map, pos_vec)
		return
	if tile == TileCatalog.FLOWER or tile == TileCatalog.STONES:
		map.set_cell(map.GROUND_DECOR_LAYER, pos_vec, TileCatalog.SOURCE_ID, tile)
	elif tile != map.NO_PLANT:
		map.set_cell(1, pos_vec, TileCatalog.SOURCE_ID, tile)


static func predict_cell(map, cell: Vector2i) -> Array:
	## [ground atlas, plant or structure atlas or NO_PLANT] that generate_chunk puts at `cell`,
	## from the noise alone (no tiles placed), so code away from players can read terrain.
	if map._predict_cache.has(cell):
		return map._predict_cache[cell]
	var moist: float = map.moisture.get_noise_2d(cell.x, cell.y)
	var chance: float = map.items_chance.get_noise_2d(cell.x, cell.y)
	var b: int = map.biome_at(cell)
	var alt: float = map.cell_altitude(cell, b)
	var ground: Vector2i = map._bridges.piece_or(
		cell, map._structures.ground_at(cell, map._sky.display_ground(map, cell))
	)
	var top: Vector2i = map.NO_PLANT
	if map._structures.has_cell(cell):
		top = map._structures.object_at(cell)
	elif map._walls.has_wall(cell):
		top = map._walls.piece(cell)
	elif map._object_removals.has_removed(cell):
		top = map.NO_PLANT
	elif map.ground_is_walkable(ground) and not map._bridges.has_bridge(cell):
		top = BirchTrees.foliage_tile(
			map,
			cell,
			alt,
			moist,
			chance,
			b,
			ground == TileCatalog.SAND or map._sky.logical_ground(map, cell) == TileCatalog.SAND
		)
		if map.starter_grove.has(cell):
			top = TileCatalog.TREE
		if top == map.NO_PLANT:
			top = map._tree_cuts.sprouts.tile_or(cell, map.structure_tile(chance, b))
		if map._tree_cuts.has_cut(cell):
			top = map._tree_cuts.leftover(cell)
	var out := [ground, top]
	map._predict_cache[cell] = out
	return out


static func predicted_clear(map, cell: Vector2i) -> bool:
	## is_clear_ground from predict_cell: walkable, no tree, bush or stones.
	var p: Array = map.predict_cell(cell)
	if not map.ground_is_walkable(p[0]):
		return false
	return (
		p[1] == map.NO_PLANT or p[1] == TileCatalog.FLOWER or InteractableCatalog.is_leftover(p[1])
	)


static func repaint_ground_cell(map, cell: Vector2i) -> void:
	map._predict_cache.erase(cell)
	map._sky.repaint_cell(map, cell)
