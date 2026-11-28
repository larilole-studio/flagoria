extends "res://tests/helpers/test_helpers.gd"


func _test_soldier_command_range() -> int:
	print("-- test_soldier_command_range")
	var units: Array[Soldier] = []
	for row in [
		["east", 2, Vector2(40, 0), 3],
		["south", 2, Vector2(0, 24), 3],
		["outside", 2, Vector2(0, 25), 3],
		["foreign", 3, Vector2.ZERO, 3],
		["fallen", 2, Vector2.ZERO, 0],
	]:
		var unit := Soldier.new()
		unit.name = row[0]
		unit.owner_peer = row[1]
		unit.position = row[2]
		unit.hp = row[3]
		units.append(unit)
	var names := SoldierCommand.names_in_range(units, 2, Vector2.ZERO, 40)
	for unit in units:
		unit.free()
	if names != PackedStringArray(["east", "south"]):
		printerr("FAIL soldier_command_range: selected %s" % [names])
		return 1
	print("PASS test_soldier_command_range")
	return 0


func _test_soldier_command_host_rules() -> int:
	print("-- test_soldier_command_host_rules")
	var scene = load("res://flagoria_main.tscn").instantiate()
	root.add_child(scene)
	var world: TileMap = scene.get_node("World/worldMap")
	scene.world_params = _spawn_params(11, 0.0)
	world.apply_map_params(scene.world_params)
	var requests: SoldierRequests = scene.get_node("World/Soldiers")
	var owner := Node2D.new()
	owner.name = "1"
	world.get_parent().add_child(owner)
	var start: Vector2i = world.resolve_player_spawn()
	var pos := world.to_global(world.map_to_local(start))
	for row in [["own", 1, 3], ["foreign", 2, 3], ["fallen", 1, 0]]:
		requests.spawn_saved(
			{"name": row[0], "owner": row[1], "hp": row[2], "pos": pos, "order": "hold"}
		)
	var own := requests.get_node("own") as Soldier
	var foreign := requests.get_node("foreign") as Soldier
	var fallen := requests.get_node("fallen") as Soldier
	var ok := not requests.host_move(1, PackedStringArray(["own"]), Vector2.INF)
	ok = ok and not requests.host_move(1, PackedStringArray(["unknown", "foreign", "fallen"]), pos)
	ok = ok and requests.host_move(1, PackedStringArray(["own", "own", "foreign"]), pos)
	ok = ok and own.order == "move" and own.move_target == pos
	ok = ok and foreign.order == "hold" and fallen.order == "hold"
	var saved := SoldierSaves.capture(scene)
	ok = ok and saved[0]["order"] == "hold" and saved[0]["pos"] == [pos.x, pos.y]
	requests.host_set_order(1)
	ok = ok and own.order == "follow" and foreign.order == "hold"
	scene.queue_free()
	await process_frame
	if not ok:
		printerr("FAIL soldier_command_host_rules: move validation, save, or Follow override")
		return 1
	print("PASS test_soldier_command_host_rules")
	return 0
