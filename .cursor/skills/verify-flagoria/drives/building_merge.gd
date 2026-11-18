extends "res://.cursor/skills/verify-flagoria/bin/drive_base.gd"
## launch: --seed 49
## Building merge (#27). Two flush footprints share a wall, then Shift+B removes
## the second and the first re-seals.


func run() -> void:
	step("place")
	if not await start_game():
		done(false)
		return
	await _walk_clear()
	var buildings: GeneratedBuildings = current_scene.get_node("World/GeneratedBuildings")
	var map: TileMap = current_scene.get_node(WORLD_MAP)
	var origin1 := map.local_to_map(map.to_local(hero().global_position))
	if not buildings.generate(origin1, 6, 5, 42, 0):
		printerr("building_merge: first generate failed")
		done(false)
		return
	await _walk_clear()
	var origin2 := origin1 + Vector2i(6, 0)
	if not buildings.generate(origin2, 6, 5, 43, 0):
		printerr("building_merge: second generate failed")
		done(false)
		return
	if buildings.record_count() != 2:
		printerr("building_merge: record count %s" % buildings.record_count())
		done(false)
		return
	await _walk_to_shared_wall(buildings, map, origin1)
	await snapshot("buildings-shared-wall")
	step("remove")
	hero().position = map.to_global(map.map_to_local(origin2 + Vector2i(3, 2)))
	await process_frame
	var key := InputEventKey.new()
	key.keycode = KEY_B
	key.physical_keycode = KEY_B
	key.shift_pressed = true
	key.pressed = true
	Input.parse_input_event(key)
	await process_frame
	await process_frame
	key.pressed = false
	Input.parse_input_event(key)
	await process_frame
	if buildings.record_count() != 1:
		printerr("building_merge: after remove records %s" % buildings.record_count())
		done(false)
		return
	await snapshot("building-resealed")
	done(true)


func _walk_clear() -> void:
	var start := hero().position
	var guard := 0
	while hero().position.distance_to(start) < 200.0 and guard < 36:
		await hold("ui_right", 10)
		guard += 1


func _walk_to_shared_wall(buildings: GeneratedBuildings, map: TileMap, origin1: Vector2i) -> void:
	var wall := origin1 + Vector2i(5, 2)
	var guard := 0
	while guard < 48:
		var here := map.local_to_map(map.to_local(hero().global_position))
		if here == wall or buildings.piece_at(here) in ["wall_straight", "wall_corner", "window"]:
			break
		var dx := wall.x - here.x
		var dy := wall.y - here.y
		var action := "ui_right" if absi(dx) >= absi(dy) and dx > 0 else \
				"ui_left" if absi(dx) >= absi(dy) and dx < 0 else \
				"ui_down" if dy > 0 else "ui_up"
		await hold(action, 8)
		guard += 1