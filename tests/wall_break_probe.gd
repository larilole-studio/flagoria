extends SceneTree
const HostListen = preload("res://tests/helpers/test_helpers.gd")
## Two-player wall damage probe (#35).
## Host: --host --save --port --out. Client: --port --out [--phase=...].


var _errors := _ErrorLog.new()
var _place_error := ""
var _out := ""
var _target := Vector2i(1 << 20, 0)
var _phase_done := ""
var _saw_hp2 := false


class _ErrorLog extends Logger:
	var lines: Array[String] = []
	var _lock := Mutex.new()

	func _log_error(function: String, _file: String, _line: int, code: String, rationale: String,
			_editor_notify: bool, _error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		_lock.lock()
		if lines.size() < 5:
			lines.append("%s: %s" % [function, rationale if rationale != "" else code])
		_lock.unlock()

	func snapshot() -> Array[String]:
		_lock.lock()
		var copy := lines.duplicate()
		_lock.unlock()
		return copy


func _initialize() -> void:
	OS.add_logger(_errors)
	call_deferred("_run")


func _run() -> void:
	var port := 0
	var save := ""
	var out := ""
	var host := false
	var phase := "work"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--port="):
			port = arg.trim_prefix("--port=").to_int()
		elif arg.begins_with("--save="):
			save = arg.trim_prefix("--save=")
		elif arg.begins_with("--out="):
			out = arg.trim_prefix("--out=")
		elif arg.begins_with("--phase="):
			phase = arg.trim_prefix("--phase=")
		elif arg == "--host":
			host = true
	_out = out
	if host:
		HostListen.arm_host(out)
	if port == 0 or out == "" or (host and save == "") or change_scene_to_file("res://flagoria_main.tscn") != OK:
		printerr("wall_break_probe: needs --port, --out, --save with --host, and the main scene")
		quit(1)
		return
	await process_frame
	await process_frame
	var main = current_scene
	main.get_node("CanvasLayer2/MainMenu").hide()
	if host:
		var map_gen = root.get_node("MapGen")
		var error: String = map_gen.load_map_inputs(save)
		if error != "" or main.setup_server(map_gen.params.duplicate_params(), port) != OK:
			printerr("wall_break_probe: could not host %s: %s" % [save, error])
			quit(1)
			return
		main.add_player(1)
		_park_mobs(main)
		HostListen.mark_host_listening(out)
	else:
		await HostListen.join_when_host_listening(main, port, out)
	var world = main.get_node("World/worldMap")
	var work := "idle"
	var deadline := Time.get_ticks_msec() + 90000
	var next_write := 0
	while Time.get_ticks_msec() < deadline and not FileAccess.file_exists(out + ".stop"):
		if main.multiplayer == null:
			break
		var me: Node2D = main.get_node_or_null("World/" + str(main.multiplayer.get_unique_id()))
		var ready := main.world_params != null and me != null
		if host and _target.x != 1 << 20 and world._walls.hp(_target) == 2:
			_saw_hp2 = true
		if not host and work == "idle" and ready and phase in ["work", "watch"]:
			work = "busy"
			_place_error = await _prepare_break(main, world, me)
			if phase == "work":
				_phase_done = await _break_sequence(main, world, me)
			work = "done"
		if Time.get_ticks_msec() >= next_write:
			_write(out, main, world, me)
			next_write = Time.get_ticks_msec() + 100
		await process_frame
	var fin: Node2D = null
	if main.multiplayer != null:
		fin = main.get_node_or_null("World/" + str(main.multiplayer.get_unique_id()))
	_write(out, main, world, fin)
	quit(0)


func _prepare_break(main, world, me: Node2D) -> String:
	var inventory: Inventory = main.get_node("Inventory")
	var requests = main.get_node("World/StructureRequests")
	var interaction: Interaction = main.get_node("World/Interaction")
	inventory.add(Inventory.WOOD, 4)
	if not await _until(func() -> bool: return _has_castle(world), 15000):
		return "no castle on the map"
	world.generate_chunk(world.map_to_local(world.resolve_player_spawn()))
	var spot: Vector2i = _castle_touch(world)
	if spot.x == 1 << 20:
		spot = _spawn_touch(world)
	if spot.x == 1 << 20:
		return "no wall spot"
	_target = spot
	me.global_position = interaction.cell_center(spot) + Vector2(0, 48)
	if not await _until(func() -> bool: return _host_sees(me), 8000):
		return "host did not ack position"
	var one: Array[Vector2i] = [spot]
	if not requests.place(BuildCosts.WALL_BLOCK, one):
		return "wall place not sent"
	if not await _until(func() -> bool: return world.has_wall(spot), 8000):
		return "wall not applied"
	return ""


func _break_sequence(main, world, me: Node2D) -> String:
	var spot: Vector2i = _target
	var interaction: Interaction = main.get_node("World/Interaction")
	me.global_position = interaction.cell_center(spot + Vector2i(0, 1))
	if not await _until(func() -> bool: return _host_sees(me), 5000):
		return "could not stand south"
	await _swing(me, "Down", 0.0)  # away from the wall to the south
	await _until_frames(15)
	if world._walls.hp(spot) != WallBuilder.MAX_HP:
		return "far swing dropped hp"
	me.global_position = interaction.cell_center(spot + Vector2i(0, 1))
	await _swing(me, "Up", 0.0)
	if not await _until(func() -> bool: return world._walls.hp(spot) == 2, 8000):
		return "first hit hp want 2 got %d" % world._walls.hp(spot)
	_saw_hp2 = true
	await _until_frames(25)
	await _swing(me, "Up", 0.0)
	await _until_frames(20)
	await _swing(me, "Up", 0.0)
	if not await _until(func() -> bool: return not world.has_wall(spot), 5000):
		return "wall still present after break"
	return ""


func _swing(me: Node2D, direction: String, angle: float) -> void:
	if me.has_method("attack_animation"):
		me.attack_animation.rpc(direction, angle)
	var until := Time.get_ticks_msec() + 3000
	while Time.get_ticks_msec() < until and me.isAttacking:
		await process_frame
	for _i in 5:
		await process_frame


func _spawn_touch(world) -> Vector2i:
	var placer := ConstructionPlacer.new(world)
	var spawn: Vector2i = world.resolve_player_spawn()
	for r in range(0, 32):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if maxi(absi(dx), absi(dy)) != r:
					continue
				var cell := spawn + Vector2i(dx, dy)
				if world.has_wall(cell) or world._structures.has_cell(cell):
					continue
				if world.get_cell_source_id(0, cell) == -1 or not world.predicted_clear(cell):
					continue
				var one: Array[Vector2i] = [cell]
				if placer.can_place_geometry(BuildCosts.WALL_BLOCK, one).is_empty():
					return cell
	return Vector2i(1 << 20, 0)


func _has_castle(world) -> bool:
	for id in world.placed_structures():
		if str(world.placed_structures()[id]["name"]) == "castle":
			return true
	return false


func _castle_touch(world) -> Vector2i:
	var anchor := Vector2i.ZERO
	var found := false
	for id in world.placed_structures():
		if str(world.placed_structures()[id]["name"]) == "castle":
			anchor = world.placed_structures()[id]["anchor"]
			found = true
			break
	if not found:
		return Vector2i(1 << 20, 0)
	var placer := ConstructionPlacer.new(world)
	for dy in range(-8, 9):
		for dx in range(-8, 9):
			var cell := anchor + Vector2i(dx, dy)
			if world.has_wall(cell) or world._structures.has_cell(cell):
				continue
			if world.get_cell_source_id(0, cell) == -1 or not world.predicted_clear(cell):
				continue
			var one: Array[Vector2i] = [cell]
			if placer.can_place_geometry(BuildCosts.WALL_BLOCK, one).is_empty():
				return cell
	return Vector2i(1 << 20, 0)


func _host_sees(me: Node2D) -> bool:
	var path := _out.get_base_dir().path_join("p0.json")
	if not FileAccess.file_exists(path):
		return false
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not data is Dictionary:
		return false
	var peer := str(me.get_parent().multiplayer.get_unique_id())
	var pos = data.get("peers", {}).get(peer, null)
	if not pos is Array or pos.size() < 2:
		return false
	return Vector2(float(pos[0]), float(pos[1])).distance_to(me.global_position) <= 4.0


func _until(cond: Callable, ms: int) -> bool:
	var until := Time.get_ticks_msec() + ms
	while Time.get_ticks_msec() < until:
		if cond.call():
			return true
		await process_frame
	return cond.call()


func _until_frames(n: int) -> void:
	for _i in n:
		await process_frame


func _park_mobs(main) -> void:
	for node in main.get_node("World/Mobs").get_children():
		if node is Mob:
			node.global_position = Vector2(100000, 100000)


func _write(out: String, main, world, me: Node2D) -> void:
	if out == "":
		return
	var walls: Array = []
	var damaged: Array = []
	if main != null and main.world_params != null:
		var cells: Array = world._walls._wall_cells.keys()
		cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
			return a.x < b.x or (a.x == b.x and a.y < b.y))
		for cell: Vector2i in cells:
			var piece := WallBuilder._atlas_wall_name(world._walls.piece(cell))
			var paint := WallBuilder._atlas_wall_name(world.get_cell_atlas_coords(1, cell))
			var hp: int = world._walls.hp(cell)
			walls.append([cell.x, cell.y, piece, paint, hp])
			if hp < WallBuilder.MAX_HP:
				damaged.append([cell.x, cell.y, hp])
			if hp == 2:
				_saw_hp2 = true
		if _target.x == 1 << 20 and not walls.is_empty():
			_target = Vector2i(int(walls[0][0]), int(walls[0][1]))
		if _target.x != 1 << 20:
			damaged.append([_target.x, _target.y, world._walls.hp(_target) if world.has_wall(_target) else -1])
	var peers := {}
	var world_root: Node = main.get_node_or_null("World") if main != null else null
	if world_root != null:
		for child in world_root.get_children():
			if child is CharacterBody2D and str(child.name).is_valid_int():
				peers[str(child.name)] = [child.global_position.x, child.global_position.y]
	var file := FileAccess.open(out + ".tmp", FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify({
		"id": str(main.multiplayer.get_unique_id()) if main != null and main.multiplayer != null else "",
		"ready": main != null and main.world_params != null and me != null,
		"place_error": _place_error,
		"phase_done": _phase_done,
		"saw_hp2": _saw_hp2,
		"target": [_target.x, _target.y],
		"walls": walls,
		"damaged": damaged,
		"peers": peers,
		"errors": _errors.snapshot(),
	}))
	file.close()
	DirAccess.rename_absolute(out + ".tmp", out)