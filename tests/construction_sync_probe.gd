extends "res://tests/helpers/probe_base.gd"
## The builder receives --wood and --stone. A host builder waits for a .build command.

var _structure: StringName
var _turns := 0
var _refused_wood := -1
var _place_error := ""


func _run() -> void:
	_structure = StringName(option("--structure"))
	var host := has_option("--host")
	var save := option("--save")
	var wood := option("--wood").to_int()
	var stone := option("--stone").to_int()
	_turns = option("--turns").to_int()
	if (
		_structure not in [BuildCosts.CASTLE, BuildCosts.BARRACKS, BuildCosts.GUARD_POST]
		or (host and save.is_empty())
	):
		printerr("construction_sync_probe: needs a supported --structure and --save with --host")
		quit(1)
		return
	var main = await open_game(host)
	if main == null:
		printerr("construction_sync_probe: needs --port, --out and the main scene")
		quit(1)
		return
	main.get_node("CanvasLayer2/MainMenu").hide()
	if host:
		var error := host_saved_game(main, save)
		if not error.is_empty():
			printerr("construction_sync_probe: could not host %s: %s" % [save, error])
			quit(1)
			return
		host_listening()
	else:
		await join_game(main)
	var world = main.get_node("World/worldMap")
	var should_place := wood > 0
	var deadline := Time.get_ticks_msec() + 90000
	while game_active(main, deadline):
		var me := local_player(main)
		if snapshot_due(main):
			_write(main, world, me)
		if (
			should_place
			and main.world_params != null
			and me != null
			and (not host or FileAccess.file_exists(probe_out + ".build"))
		):
			should_place = false
			_place_error = await _do_place(main, world, me, wood, stone)
		await process_frame
	finish(main, func() -> void: _write(main, world, local_player(main)))


func _do_place(main, world, me: Node2D, wood: int, stone: int) -> String:
	var interaction: Interaction = main.get_node("World/Interaction")
	var requests = main.get_node("World/StructureRequests")
	var inventory: Inventory = main.get_node("Inventory")
	var land: Variant = _search(world, func(cell: Vector2i) -> bool: return _anchor_ok(world, cell))
	if land == null:
		return "no clear %s anchor" % _structure
	var water: Variant = _search(
		world,
		func(cell: Vector2i) -> bool:
			return world.predict_cell(cell)[0] == TileCatalog.WATER and not world.has_bridge(cell)
	)
	if water == null:
		return "no water cell"
	var err := await _wait_host_position(
		main, me, interaction.cell_center(water) + Vector2(0, 48), 5000
	)
	if err != "":
		return err
	var before := inventory.count_of(Inventory.WOOD)
	inventory.add(Inventory.WOOD, wood)
	inventory.add(Inventory.STONE, stone - 1)
	var bad: Array[Vector2i] = [water]
	requests.place(_structure, bad)
	if not await _until(
		func() -> bool: return inventory.count_of(Inventory.WOOD) == before + wood, 8000
	):
		return "refused request did not settle wood"
	_refused_wood = inventory.count_of(Inventory.WOOD)
	if _refused_wood != before + wood:
		return "refused request spent wood (%d -> %d)" % [before + wood, _refused_wood]
	err = await _wait_host_position(
		main,
		me,
		interaction.cell_center(land) + (Vector2(-48, 0) if _turns == 1 else Vector2(0, 48)),
		5000
	)
	if err != "":
		return err
	var one: Array[Vector2i] = [land]
	var builder: int = main.multiplayer.get_unique_id()
	var before_count := _owned_count(world, builder)
	# Ordered on the same reliable channel. If the first request writes the site,
	# the second cannot charge the funded price, so the balance assertion fails.
	if requests.place(_structure, one, _turns) == main.multiplayer.is_server():
		return "unexpected result for the request short one stone"
	inventory.add(Inventory.STONE, 1)
	if not requests.place(_structure, one, _turns):
		return "place was not sent"
	if not await _until(func() -> bool: return _owned_count(world, builder) > before_count, 8000):
		return "built %s was not applied" % _structure
	return ""


func _wait_host_position(main, me: Node2D, where: Vector2, ms: int) -> String:
	var sync := me.get_node_or_null("MultiplayerSynchronizer")
	if sync is MultiplayerSynchronizer:
		(sync as MultiplayerSynchronizer).replication_interval = 0.0
	var peer_id := str(main.multiplayer.get_unique_id())
	var until := Time.get_ticks_msec() + ms
	while Time.get_ticks_msec() < until:
		me.global_position = where
		if me is CharacterBody2D:
			me.velocity = Vector2.ZERO
		if main.multiplayer.is_server() or _host_sees_position(peer_id, where, 4.0):
			return ""
		await process_frame
	return "host did not ack the player at %s" % where


func _host_sees_position(peer_id: String, where: Vector2, slack: float) -> bool:
	var path := probe_out.get_base_dir().path_join("p0.json")
	if not FileAccess.file_exists(path):
		return false
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not data is Dictionary:
		return false
	var pos = data.get("peers", {}).get(peer_id, null)
	if not pos is Array or pos.size() < 2:
		return false
	return Vector2(float(pos[0]), float(pos[1])).distance_to(where) <= slack


func _until(cond: Callable, ms: int) -> bool:
	var until := Time.get_ticks_msec() + ms
	while Time.get_ticks_msec() < until:
		if cond.call():
			return true
		await process_frame
	return cond.call()


func _owned_count(world, owner: int) -> int:
	var n := 0
	for p in world.placed_structures().values():
		if str(p["name"]) == _structure and int(p["owner"]) == owner:
			n += 1
	return n


func _search(world, pred: Callable) -> Variant:
	var spawn: Vector2i = world.resolve_player_spawn()
	for r in range(0, 64):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if maxi(absi(dx), absi(dy)) != r:
					continue
				var cell := spawn + Vector2i(dx, dy)
				if pred.call(cell):
					return cell
	return null


func _anchor_ok(world, cell: Vector2i) -> bool:
	if _structure == BuildCosts.CASTLE:
		for entry in world.placed_structures().values():
			if str(entry["name"]) == "castle" and entry["anchor"].distance_to(cell) < 14:
				return false
	var one: Array[Vector2i] = [cell]
	return ConstructionPlacer.new(world).can_place_geometry(_structure, one, _turns).is_empty()


func _write(main, world, me: Node2D) -> void:
	var inventory: Inventory = main.get_node("Inventory")
	var peers := {}
	for child in main.get_node("World").get_children():
		if child is CharacterBody2D and str(child.name).is_valid_int():
			peers[str(child.name)] = [child.global_position.x, child.global_position.y]
	var structures: Array = world.structures_for_sync()
	structures.sort_custom(func(a: Array, b: Array) -> bool: return str(a) < str(b))
	write_result(
		{
			"id": str(me.name) if me != null else "",
			"ready": main.world_params != null and me != null,
			"wood": inventory.count_of(Inventory.WOOD),
			"stone": inventory.count_of(Inventory.STONE),
			"refused_wood": _refused_wood,
			"place_error": _place_error,
			"peers": peers,
			"sync": structures,
			"errors": _errors.snapshot(),
		}
	)
