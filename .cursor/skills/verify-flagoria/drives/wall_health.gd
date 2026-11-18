extends "res://.cursor/skills/verify-flagoria/bin/drive_base.gd"
## launch: --seed 11
## Solo host: a palisade line, then sword hits until it breaks.


const SETTLE := 15


func run() -> void:
	step("wall-line")
	if not await start_game():
		done(false)
		return
	var map: TileMap = current_scene.get_node(WORLD_MAP)
	var player: Node2D = hero()
	var interaction: Interaction = current_scene.get_node(INTERACTION)
	if not await wait_until(func() -> bool: return map.spawn_point != Vector2i.ZERO, 10.0):
		printerr("wall_health: spawn never set")
		done(false)
		return
	var line: Array[Vector2i] = _wall_line(map)
	if line.is_empty():
		line = _touch_line(map)
	if line.is_empty() or not map.place_wall_cells(line):
		printerr("wall_health: could not place a line")
		done(false)
		return
	var mid := line[1]
	map.generate_chunk(map.map_to_local(mid))
	await settle(SETTLE)
	await _look(map, mid)
	await snapshot("wall-line")
	step("wall-cracked")
	player.global_position = interaction.cell_center(mid + Vector2i(0, 1))
	await settle(SETTLE)
	await _swing(player, "Up", 0.0)
	if map._walls.hp(mid) != 2:
		printerr("wall_health: cracked hp want 2 got %d" % map._walls.hp(mid))
		done(false)
		return
	await settle(SETTLE)
	await snapshot("wall-cracked")
	step("wall-broken")
	await _swing(player, "Up", 0.0)
	await _swing(player, "Up", 0.0)
	if map.has_wall(mid):
		printerr("wall_health: middle cell still stands")
		done(false)
		return
	await settle(SETTLE)
	await snapshot("wall-broken")
	done(true)


func _touch_line(map: TileMap) -> Array[Vector2i]:
	var anchor := Vector2i.ZERO
	for id in map.placed_structures():
		if str(map.placed_structures()[id]["name"]) == "castle":
			anchor = map.placed_structures()[id]["anchor"]
			break
	if anchor == Vector2i.ZERO:
		return []
	var placer := ConstructionPlacer.new(map)
	for dy in range(-8, 9):
		for dx in range(-8, 9):
			var cell := anchor + Vector2i(dx, dy)
			if map.has_wall(cell) or map._structures.has_cell(cell):
				continue
			if map.get_cell_source_id(0, cell) == -1:
				map.generate_chunk(map.map_to_local(cell))
			if not map.predicted_clear(cell):
				continue
			var run: Array[Vector2i] = [cell, cell + Vector2i.RIGHT, cell + Vector2i.RIGHT * 2]
			if run.all(func(c: Vector2i) -> bool:
					return not map._structures.has_cell(c) and not map.has_wall(c)):
				return run
	return []


func _wall_line(map: TileMap) -> Array[Vector2i]:
	var front: Vector2i = map.spawn_point
	for r in range(6, 40):
		var start: Vector2i = front + Vector2i(r, 0)
		var run: Array[Vector2i] = [start, start + Vector2i.RIGHT, start + Vector2i.RIGHT * 2]
		if run.all(func(c: Vector2i) -> bool:
				return map.predicted_clear(c) and not map._structures.has_cell(c)):
			return run
	return []


func _swing(player: Node2D, direction: String, angle: float) -> void:
	player.attack_toward(direction, angle)
	while player.isAttacking:
		await process_frame
	for _i in 8:
		await physics_frame


func _look(map: TileMap, cell: Vector2i) -> void:
	var cam: Camera2D = hero().get_node("Camera2D")
	cam.global_position = map.to_global(map.map_to_local(cell))


func settle(frames: int) -> void:
	for _i in frames:
		await process_frame