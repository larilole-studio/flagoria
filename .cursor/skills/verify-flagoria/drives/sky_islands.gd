extends "res://.cursor/skills/verify-flagoria/bin/drive_base.gd"
## Walk to the nearest generated shore and shoot the island edge.
## The player camera is already at gameplay zoom (0.7).
## launch: --seed 42

const SEARCH := 48


func run() -> void:
	if not await start_game():
		return
	step("island_edge")
	var map: TileMap = current_scene.get_node(WORLD_MAP)
	var origin := _hero_cell(map)
	var coast := _nearest_shore(map, origin)
	if not _beside_sea(map, coast):
		for y in range(-4, 5):
			for x in range(-4, 5):
				map.generate_chunk(Vector2(x * map.chunk_width, y * map.chunk_height))
		coast = _nearest_shore(map, origin)
	var player := hero()
	if player != null and _beside_sea(map, coast):
		player.global_position = map.to_global(map.map_to_local(coast))
	for _i in 8:
		await process_frame
	var cam := hero().get_node_or_null("Camera2D") as Camera2D
	var zoom_ok := cam != null and is_equal_approx(cam.zoom.x, 0.7)
	await snapshot("island_edge")
	var at_shore := _beside_sea(map, _hero_cell(map))
	print("sky_islands: shore=%s zoom=%s" % [at_shore, cam.zoom if cam else "none"])
	done(zoom_ok and at_shore)


func _hero_cell(map: TileMap) -> Vector2i:
	return map.local_to_map(map.to_local(hero().global_position))


func _nearest_shore(map: TileMap, origin: Vector2i) -> Vector2i:
	for r in range(1, SEARCH):
		for y in range(-r, r + 1):
			for x in range(-r, r + 1):
				if maxi(absi(x), absi(y)) != r:
					continue
				var cell := origin + Vector2i(x, y)
				if _beside_sea(map, cell) and map.is_walkable_land(cell):
					return cell
	return origin


func _beside_sea(map: TileMap, cell: Vector2i) -> bool:
	if not map.is_walkable_land(cell):
		return false
	for d in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		if _is_sea(map, cell + d):
			return true
	return false


func _is_sea(map: TileMap, cell: Vector2i) -> bool:
	if map.has_method("is_open_sea"):
		return map.is_open_sea(cell)
	return map.get_cell_atlas_coords(0, cell) == TileCatalog.WATER
