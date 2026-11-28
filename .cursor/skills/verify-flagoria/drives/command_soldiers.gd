## fixture
extends "res://.cursor/skills/verify-flagoria/bin/drive_base.gd"
## launch: --seed 7
## Spawn the troops in Hold, then command them using real touch input.


func run() -> void:
	if not await start_game():
		return
	var map: TileMap = current_scene.get_node(WORLD_MAP)
	var requests: SoldierRequests = current_scene.get_node("World/Soldiers")
	var command: SoldierCommand = hero().get_node("SoldierCommand")
	await hold("ui_down", 8)
	await hold("ui_right", 38)
	await hold("ui_up", 22)
	if not await wait_until(func() -> bool: return hero().velocity.is_zero_approx(), 3.0):
		done(false)
		return
	var origin := map.local_to_map(map.to_local(hero().global_position))
	var setup := _layout(map, origin)
	if setup.is_empty():
		printerr("command_soldiers: no clear formation near the spawn")
		done(false)
		return
	var peer := get_multiplayer().get_unique_id()
	var starts: Array[Vector2] = []
	for i in 3:
		starts.append(map.to_global(map.map_to_local(setup[i])))
		requests.spawn_saved(
			{"name": "command_%d" % i, "owner": peer, "pos": starts[i], "order": "hold", "seed": i}
		)
	var troops := requests.soldiers()
	var target := map.to_global(map.map_to_local(setup[3]))
	var want := PackedStringArray(["command_0", "command_1"])
	await tap_key(KEY_4)
	step("drag-select-two-of-three")
	var attack = get_first_node_in_group(AttackAim.ATTACK_BUTTON_GROUP)
	var at: Vector2 = root.get_final_transform() * attack.aim_center()
	var end := at + Vector2(-40, 0)
	_touch(at, true)
	await process_frame
	var drag := InputEventScreenDrag.new()
	drag.index = 0
	drag.position = end
	drag.relative = end - at
	Input.parse_input_event(drag)
	await process_frame
	var ok := command.preview_names() == want
	await snapshot("command-range")
	_touch(end, false)
	await process_frame
	ok = ok and command.selected_names == want
	if not ok:
		printerr("command_soldiers: selection %s, expected %s" % [command.selected_names, want])
		done(false)
		return

	step("tap-map-and-hold")
	await tap_cell(setup[3])
	var first: Soldier = troops[0]
	var second: Soldier = troops[1]
	var third: Soldier = troops[2]
	ok = await wait_until(func() -> bool: return first.position.distance_to(starts[0]) > 8.0, 1.0)
	ok = ok and first.order == "move" and second.order == "move" and third.order == "hold"
	await snapshot("command-moving")
	var arrived := await wait_until(
		func() -> bool: return first.order == "hold" and second.order == "hold", 5.0
	)
	var first_stop := first.position
	var second_stop := second.position
	await snapshot("command-arrived")
	await wait_until(func() -> bool: return false, 0.3)
	ok = (
		ok
		and arrived
		and first_stop.distance_to(target) <= 16.0
		and second_stop.distance_to(target) <= 16.0
		and first_stop.distance_to(second_stop) >= 12.0
		and first_stop.distance_to(starts[0]) > 16.0
		and second_stop.distance_to(starts[1]) > 16.0
		and first.position == first_stop
		and second.position == second_stop
		and third.position == starts[2]
	)
	if not ok:
		printerr(
			(
				"command_soldiers: target %s, stops %s and %s, third %s"
				% [target, first_stop, second_stop, third.position]
			)
		)
	done(ok)


func _touch(pos: Vector2, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = 0
	event.position = pos
	event.pressed = pressed
	Input.parse_input_event(event)


func _layout(map: TileMap, origin: Vector2i) -> Array[Vector2i]:
	var starts: Array[Vector2i] = []
	var outside: Array[Vector2i] = []
	for y in range(-4, 5):
		for x in range(-5, 6):
			var cell := origin + Vector2i(x, y)
			if cell == origin or not map.predicted_clear(cell):
				continue
			var d := Vector2(x, y / 0.6).length()
			if d <= 2.2:
				starts.append(cell)
			elif d >= 4.0:
				outside.append(cell)
	for y in range(-3, 4):
		for x in range(-4, 5):
			var target := origin + Vector2i(x, y)
			if Vector2(x, y).length() < 3.0 or not map.predicted_clear(target):
				continue
			var neighbors: Array[Vector2i] = []
			for dir in [Vector2i.UP, Vector2i.LEFT, Vector2i.RIGHT, Vector2i.DOWN]:
				if map.predicted_clear(target + dir):
					neighbors.append(target + dir)
			if neighbors.is_empty():
				continue
			var supports: Array[Vector2i] = []
			for from in starts:
				if (
					Vector2(target - from).length() > 2.0
					and _clear_line(map, from, target)
					and neighbors.all(func(n): return _clear_line(map, from, n))
				):
					supports.append(from)
			if supports.size() >= 2:
				for third in outside:
					if Vector2(third - target).length() >= 2.0:
						return [supports[0], supports[1], third, target]
	return []


func _clear_line(map: TileMap, from: Vector2i, to: Vector2i) -> bool:
	var start: Vector2 = map.map_to_local(from)
	var end: Vector2 = map.map_to_local(to)
	for n in 13:
		var pos := start.lerp(end, n / 12.0)
		for foot in [Vector2(-6, -5), Vector2(6, -5), Vector2(-6, 0), Vector2(6, 0)]:
			if not map.predicted_clear(map.local_to_map(pos + foot)):
				return false
	return true
