extends "res://.cursor/skills/verify-flagoria/bin/drive_base.gd"
## launch: --seed 49
## On-demand building (#26). Seed 49. B places a building at the hero.
## Two placements, each with a door, then the hero walks into a wall.


func run() -> void:
	step("first")
	if not await start_game():
		done(false)
		return
	await _step_clear()
	if not await _place():
		printerr("generated_building: first building did not appear")
		done(false)
		return
	var buildings: GeneratedBuildings = current_scene.get_node("World/GeneratedBuildings")
	var first_door := buildings.door_cells().size()
	await snapshot("building-one")
	if first_door != 1:
		printerr("generated_building: first door count %s" % first_door)
		done(false)
		return
	step("second")
	if not await _leave_through_door(buildings):
		printerr("generated_building: could not leave through the door")
		done(false)
		return
	await _step_clear()
	if not await _place():
		printerr("generated_building: second building did not appear")
		done(false)
		return
	await snapshot("building-two")
	if buildings.record_count() != 2 or buildings.door_cells().size() != 2:
		printerr("generated_building: records %s doors %s" % [buildings.record_count(), buildings.door_cells().size()])
		done(false)
		return
	if buildings.grid_of(0) == buildings.grid_of(1):
		printerr("generated_building: the two layouts match")
		done(false)
		return
	step("wall")
	var blocked := await _walk_into_wall(buildings)
	await snapshot("wall-block")
	print("generated_building: doors %s blocked %s" % [buildings.door_cells().size(), blocked])
	done(blocked)


func _place() -> bool:
	var buildings: GeneratedBuildings = current_scene.get_node("World/GeneratedBuildings")
	var before := buildings.record_count()
	for pressed in [true, false]:
		var key := InputEventKey.new()
		key.keycode = KEY_B
		key.physical_keycode = KEY_B
		key.pressed = pressed
		Input.parse_input_event(key)
		await process_frame
		await process_frame
	return await wait_until(func() -> bool: return buildings.record_count() > before, 5.0)


func _step_clear() -> void:
	## One direction until it stops, then a turn, so the walk does not undo
	## itself. Far enough that the next footprint misses the last one and the
	## starting castle.
	var start := hero().position
	var dirs: Array[String] = ["ui_right", "ui_down", "ui_left", "ui_up"]
	var idx := 0
	var guard := 0
	while hero().position.distance_to(start) < 220.0 and guard < 40:
		var before := hero().position
		await hold(dirs[idx], 12)
		guard += 1
		if hero().position.distance_to(before) < 4.0:
			idx = (idx + 1) % dirs.size()


func _leave_through_door(buildings: GeneratedBuildings) -> bool:
	var map: TileMap = current_scene.get_node(WORLD_MAP)
	var doors := buildings.door_cells()
	if doors.is_empty():
		return false
	var door: Vector2i = doors[doors.size() - 1]
	for _i in 24:
		var here := map.local_to_map(map.to_local(hero().global_position))
		if here == door:
			break
		var nxt := _path_step(buildings, here, door)
		if nxt == here:
			break
		await hold(_toward(here, nxt), 8)
	await hold(_away_from_building(map, buildings, door), 16)
	var outside := map.local_to_map(map.to_local(hero().global_position))
	return buildings.piece_at(outside) != "floor"


func _path_step(buildings: GeneratedBuildings, here: Vector2i, door: Vector2i) -> Vector2i:
	## First step of a floor-and-door walk from here to the door.
	if here == door:
		return door
	var queue: Array[Vector2i] = [here]
	var prev := {here: here}
	var head := 0
	var steps: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	while head < queue.size():
		var cell: Vector2i = queue[head]
		head += 1
		if cell == door:
			break
		for step in steps:
			var nxt: Vector2i = cell + step
			if prev.has(nxt):
				continue
			var piece := buildings.piece_at(nxt)
			if piece != "floor" and piece != "door":
				continue
			prev[nxt] = cell
			queue.append(nxt)
	if not prev.has(door):
		return here
	var step_cell := door
	while prev[step_cell] != here:
		step_cell = prev[step_cell]
	return step_cell


func _walk_into_wall(buildings: GeneratedBuildings) -> bool:
	var map: TileMap = current_scene.get_node(WORLD_MAP)
	var here := map.local_to_map(map.to_local(hero().global_position))
	var action := "ui_right"
	var found := false
	for dist in [1, 2, 3]:
		if found:
			break
		for step in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			if _is_wall(buildings, here + step * dist):
				action = _toward(here, here + step)
				found = true
				break
	var x0 := hero().position
	await hold(action, 36)
	var now := map.local_to_map(map.to_local(hero().global_position))
	var beside := false
	for step in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		if _is_wall(buildings, now + step):
			beside = true
	return found and beside and not _is_wall(buildings, now) and hero().position.distance_to(x0) > 2.0


func _is_wall(buildings: GeneratedBuildings, cell: Vector2i) -> bool:
	var piece := buildings.piece_at(cell)
	return piece == "wall_straight" or piece == "wall_corner" or piece == "window"


func _toward(here: Vector2i, target: Vector2i) -> String:
	var dx := target.x - here.x
	var dy := target.y - here.y
	if absi(dx) >= absi(dy) and dx != 0:
		return "ui_right" if dx > 0 else "ui_left"
	if dy > 0:
		return "ui_down"
	if dy < 0:
		return "ui_up"
	return "ui_right"


func _away_from_building(map: TileMap, buildings: GeneratedBuildings, door: Vector2i) -> String:
	for step in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var next: Vector2i = door + step
		if not buildings.is_blocking(next) and buildings.piece_at(next) == "":
			return _toward(door, next)
	return "ui_down"
