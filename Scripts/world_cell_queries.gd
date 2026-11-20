extends RefCounted
## Checks terrain collision, occupancy and spawn cells on the map.


static func player_on_cell(map, cell: Vector2i) -> bool:
	## True when a player's body box (a CharacterBody2D next to this map) overlaps the cell.
	var cell_rect := Rect2(map.to_global(map.map_to_local(cell) - Vector2(8, 8)), Vector2(16, 16) * map.global_scale)
	for node in map.get_parent().get_children():
		if not node is CharacterBody2D:
			continue
		var body := node.get_node_or_null("CollisionShape2D") as CollisionShape2D
		if body and body.shape and (body.global_transform * body.shape.get_rect()).intersects(cell_rect):
			return true
	return false


static func mob_cells(map) -> Dictionary:
	## The cells under any mob's feet box (Mob.cells_under World/Mobs, next to
	## this map): a plant regrowing on one would trap that mob (#232).
	return Mob.cells_under(map.get_parent().get_node_or_null("Mobs"))


static func ground_is_walkable(map, atlas: Vector2i) -> bool:
	## True when the layer-0 tile at `atlas` has no collision.
	var src := map.tile_set.get_source(TileCatalog.SOURCE_ID) as TileSetAtlasSource
	var td := src.get_tile_data(atlas, 0) if src and src.has_tile(atlas) else null
	return td != null and td.get_collision_polygons_count(0) == 0


static func is_walkable_land(map, cell: Vector2i) -> bool:
	if map.get_cell_source_id(0, cell) == -1:
		return false
	var td = map.get_cell_tile_data(0, cell)
	if td == null:
		return false
	return td.get_collision_polygons_count(0) == 0


static func is_clear_ground(map, cell: Vector2i) -> bool:
	## Walkable ground with no tree, bush or stones on it; generates the cell's chunk first.
	if not map.is_drawn(cell):
		map.generate_chunk(map.map_to_local(cell))
	if not map.is_walkable_land(cell):
		return false
	if map.get_cell_source_id(1, cell) != -1:
		return false
	return map.get_cell_atlas_coords(map.GROUND_DECOR_LAYER, cell) != TileCatalog.STONES


static func resolve_player_spawn(map, origin_cell: Vector2i = Vector2i(0, 0), max_radius: int = 192) -> Vector2i:
	## Gate front, else the first search. A later castle must not move it.
	if map._castle_front != null:
		return map._castle_front
	if not map.has_meta(&"resolved_spawn"):
		map.set_meta(&"resolved_spawn", SpawnFinder.resolve_player_spawn(map, origin_cell, max_radius))
	return map.get_meta(&"resolved_spawn")
