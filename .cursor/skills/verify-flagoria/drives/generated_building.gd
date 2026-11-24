extends "res://.cursor/skills/verify-flagoria/bin/drive_base.gd"
## launch: --seed 49
## On-demand building (#26). Seed 49. B places a building at the hero.
## Two placements, each with a door, then the hero walks into a wall.


const STILL_FRAMES := 120
const ARRIVE_FRAMES := 240
const PATH_ATTEMPTS := 24
const CLOSE_PX := 3.0


func run() -> void:
	step("first")
	if not await start_game():
		done(false)
		return
	await _step_clear()
	if not await _wait_still():
		printerr("generated_building: hero did not stop after the first walk")
		done(false)
		return
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
	if not await _wait_still():
		printerr("generated_building: hero did not stop before leaving")
		done(false)
		return
	if not await _leave_through_door(buildings):
		printerr("generated_building: could not leave through the door")
		done(false)
		return
	await _step_clear()
	if not await _wait_still():
		printerr("generated_building: hero did not stop after the second walk")
		done(false)
		return
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
	if not blocked:
		printerr("generated_building: wall walk did not leave the hero beside a wall")
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
		await physics_frame
		await physics_frame
	for _i in ARRIVE_FRAMES:
		if buildings.record_count() > before:
			return true
		await physics_frame
	return false


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
		printerr("generated_building: no door to leave through")
		return false
	var door: Vector2i = doors[doors.size() - 1]
	var outside: Vector2i = door
	for step in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var nxt: Vector2i = door + step
		if not buildings.is_blocking(nxt) and buildings.piece_at(nxt) == "":
			outside = nxt
			break
	if outside == door:
		printerr("generated_building: door %s has no open outside cell" % door)
		return false
	# Interior floor cell facing the door, then the door, then the outside
	# centre. A raw cardinal hold from an off-centre pose clips the doorposts.
	var before: Vector2i = door - (outside - door)
	var attempts := 0
	for target in [before, door, outside]:
		while _hero_cell(map) != target and _hero_cell(map) != outside and attempts < PATH_ATTEMPTS:
			attempts += 1
			var here := _hero_cell(map)
			var nxt := _path_step(buildings, here, target)
			if nxt == here:
				await _arrive_at_cell(map, target)
				break
			await _arrive_at_cell(map, nxt)
		if _hero_cell(map) != target and _hero_cell(map) != outside:
			await _arrive_at_cell(map, target)
		if _hero_cell(map) == outside:
			return true
	printerr(
		"generated_building: leave ended at %s after %d steps, want outside %s (door %s)"
		% [_hero_cell(map), attempts, outside, door]
	)
	return false


func _path_step(buildings: GeneratedBuildings, here: Vector2i, goal: Vector2i) -> Vector2i:
	## First step of a floor-and-door walk from here to the goal.
	if here == goal:
		return goal
	var queue: Array[Vector2i] = [here]
	var prev := {here: here}
	var head := 0
	var steps: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	while head < queue.size():
		var cell: Vector2i = queue[head]
		head += 1
		if cell == goal:
			break
		for step in steps:
			var nxt: Vector2i = cell + step
			if prev.has(nxt):
				continue
			var piece := buildings.piece_at(nxt)
			if nxt != goal and piece != "floor" and piece != "door":
				continue
			if nxt != goal and buildings.is_blocking(nxt):
				continue
			prev[nxt] = cell
			queue.append(nxt)
	if not prev.has(goal):
		return here
	var step_cell := goal
	while prev[step_cell] != here:
		step_cell = prev[step_cell]
	return step_cell


func _walk_into_wall(buildings: GeneratedBuildings) -> bool:
	## Arrive at the nearest floor cell that 4-touches a wall, then press into
	## the wall. A 3-cell cardinal lunge plus "must move 2 px" fails when the
	## hero is already next to a wall, more than 3 cells from one, or still
	## carrying leftover speed from the previous walk.
	var map: TileMap = current_scene.get_node(WORLD_MAP)
	if not await _wait_still():
		printerr("generated_building: hero did not stop before the wall walk")
		return false
	var beside: Vector2i = _nearest_cell_beside_wall(buildings, _hero_cell(map))
	if beside == Vector2i.MAX:
		printerr("generated_building: no floor cell beside a wall from %s" % _hero_cell(map))
		return false
	var attempts := 0
	while _hero_cell(map) != beside and attempts < PATH_ATTEMPTS:
		attempts += 1
		var here := _hero_cell(map)
		var nxt := _path_step(buildings, here, beside)
		if nxt == here:
			break
		await _arrive_at_cell(map, nxt)
	if _hero_cell(map) != beside:
		await _arrive_at_cell(map, beside)
	if _hero_cell(map) != beside:
		printerr("generated_building: could not reach wall-side cell %s (at %s)" % [beside, _hero_cell(map)])
		return false
	var here := _hero_cell(map)
	var wall := Vector2i.ZERO
	for step in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		if _is_wall(buildings, here + step):
			wall = step
			break
	if wall == Vector2i.ZERO:
		printerr("generated_building: cell %s does not 4-touch a wall" % here)
		return false
	if not await _wait_still():
		printerr("generated_building: hero did not stop beside the wall at %s" % here)
		return false
	# From a centred floor cell, ~19 physics ticks (hold 20) close the ~6 px
	# gap to the wall face without crossing into the wall cell.
	await hold(_toward(here, here + wall), 20)
	_release_walk()
	await physics_frame
	var now := _hero_cell(map)
	var still_beside := false
	for step in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		if _is_wall(buildings, now + step):
			still_beside = true
	if not (still_beside and not _is_wall(buildings, now)):
		printerr("generated_building: after pressing into the wall, hero is at %s" % now)
		return false
	return true


func _hero_cell(map: TileMap) -> Vector2i:
	return map.local_to_map(map.to_local(hero().global_position))




func _release_walk() -> void:
	for action: String in ["ui_left", "ui_right", "ui_up", "ui_down"]:
		_action(action, false)


func _arrive_at_cell(map: TileMap, cell: Vector2i) -> bool:
	## Align the sideways axis first, then walk the axis that reaches the
	## cell. Walking the long axis first from an off-centre pose clips a
	## doorpost or wall corner. Hold only while the remaining distance is
	## greater than the current stopping distance, and check after every
	## physics tick: a hold-until-close then coast overshoots a 16 px cell,
	## and wall-clock waits starve under a tight CPU cap.
	var centre := map.to_global(map.map_to_local(cell))
	if not await _wait_still():
		printerr("generated_building: hero did not stop before walking to %s" % cell)
		return false
	if hero().global_position.distance_to(centre) <= 8.0:
		return true
	var here := _hero_cell(map)
	var primary := 0 if absi(cell.x - here.x) >= absi(cell.y - here.y) else 1
	if here == cell:
		var delta0: Vector2 = centre - hero().global_position
		primary = 0 if absf(delta0.x) >= absf(delta0.y) else 1
	for axis in [1 - primary, primary]:
		if not await _arrive_on_axis(centre, axis):
			_release_walk()
			printerr(
				"generated_building: arrive failed, want %s at %s, at %s (%s)"
				% [cell, centre, _hero_cell(map), hero().global_position]
			)
			return false
	if not await _wait_still():
		printerr("generated_building: hero did not stop after walking to %s" % cell)
		return false
	if _hero_cell(map) == cell or hero().global_position.distance_to(centre) <= 12.0:
		return true
	printerr(
		"generated_building: arrive failed, want %s at %s, at %s (%s)"
		% [cell, centre, _hero_cell(map), hero().global_position]
	)
	return false


func _arrive_on_axis(centre: Vector2, axis: int) -> bool:
	var remaining: float = centre[axis] - hero().global_position[axis]
	if absf(remaining) <= CLOSE_PX:
		return true
	var sign0 := signf(remaining)
	var friction: float = float(hero().FRICTION)
	var action := _axis_action(axis, remaining)
	var frames := 0
	var stalled := 0
	var last: float = hero().global_position[axis]
	while frames < ARRIVE_FRAMES:
		remaining = centre[axis] - hero().global_position[axis]
		if absf(remaining) <= CLOSE_PX or signf(remaining) != sign0:
			_action(action, false)
			break
		var speed: float = absf(hero().velocity[axis])
		var stop_dist: float = (speed * speed) / (2.0 * friction) if friction > 0.0 else 0.0
		if absf(remaining) > stop_dist + CLOSE_PX:
			_action(action, true)
		else:
			_action(action, false)
		await physics_frame
		frames += 1
		var now_pos: float = hero().global_position[axis]
		if absf(now_pos - last) < 0.25:
			stalled += 1
			if stalled >= 30 and absf(remaining) > 12.0:
				_action(action, false)
				printerr(
					"generated_building: stalled on axis %d at %s after %d frames, remaining %s"
					% [axis, hero().global_position, frames, remaining]
				)
				return false
		else:
			stalled = 0
			last = now_pos
	_action(action, false)
	return await _wait_still()


func _axis_action(axis: int, remaining: float) -> String:
	if axis == 0:
		return "ui_right" if remaining > 0.0 else "ui_left"
	return "ui_down" if remaining > 0.0 else "ui_up"


func _wait_still() -> bool:
	## Leftover walk speed is cleared in _physics_process. Bound the wait by
	## physics frames, not wall-clock time, so a tight CPU cap still gets a
	## full stop.
	for _i in STILL_FRAMES:
		if hero().velocity.length() <= 8.0:
			return true
		await physics_frame
	var left: float = hero().velocity.length()
	if left <= 20.0:
		return true
	printerr("generated_building: still moving at %s px/s after %d physics frames" % [left, STILL_FRAMES])
	return false


func _nearest_cell_beside_wall(buildings: GeneratedBuildings, start: Vector2i) -> Vector2i:
	var missing := Vector2i.MAX
	var queue: Array[Vector2i] = [start]
	var seen := {start: true}
	var head := 0
	var steps: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	while head < queue.size():
		var cell: Vector2i = queue[head]
		head += 1
		for step in steps:
			if _is_wall(buildings, cell + step):
				return cell
		for step in steps:
			var nxt: Vector2i = cell + step
			if seen.has(nxt):
				continue
			var piece := buildings.piece_at(nxt)
			if piece != "floor" and piece != "door":
				continue
			seen[nxt] = true
			queue.append(nxt)
	return missing


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
