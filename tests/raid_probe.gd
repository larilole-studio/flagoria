extends SceneTree
## One peer of a raid session (#529). The host places a palisade city and
## applies RaidDirector.advance directly, so the test does not wait out the
## 45 s interval. With raids on, one strike drops a wall below 3 hp. With
## raids off, that hp stays 3.
##   -- --port=N --out=PATH --role=host --seed=11 --raids=on
##   -- --port=N --out=PATH --role=join --seed=11 --raids=off


var _out := ""
var _errors := _ErrorLog.new()
var _raids := false
var _armed := false
var _phase := 0
var _hp := -1
var _cell := Vector2i.ZERO
var _has_cell := false
var _assigned := 0
var _note := ""


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
	var role := "join"
	var seed_value := 11
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--port="):
			port = arg.trim_prefix("--port=").to_int()
		elif arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=")
		elif arg.begins_with("--role="):
			role = arg.trim_prefix("--role=")
		elif arg.begins_with("--seed="):
			seed_value = arg.trim_prefix("--seed=").to_int()
		elif arg.begins_with("--raids="):
			_raids = arg.trim_prefix("--raids=") == "on"
	if port == 0 or _out == "" or change_scene_to_file("res://flagoria_main.tscn") != OK:
		printerr("raid_probe: needs --port, --out and the main scene")
		quit(1)
		return
	await process_frame
	await process_frame
	var main = current_scene
	main.get_node("CanvasLayer2/MainMenu").hide()
	if role == "host":
		var settings = root.get_node("GameSettings")
		settings.set_mob_rate(1.0, false)
		settings.set_raids_enabled(false, false)
		settings.set_raid_interval_s(45, false)
		settings.set_raid_group(8, false)
		settings.set_raid_radius_cells(96, false)
		if main.setup_server(_params(seed_value), port) != OK:
			printerr("raid_probe: could not host")
			quit(1)
			return
		main.add_player(1)
	else:
		main.add_player_joined(port)
	var deadline := Time.get_ticks_msec() + 45000
	var next_write := 0
	while Time.get_ticks_msec() < deadline and not FileAccess.file_exists(_out + ".stop"):
		if role == "host" and not _armed and FileAccess.file_exists(_out + ".go"):
			_armed = true
			_arm(main)
			_phase = 1
		if Time.get_ticks_msec() >= next_write:
			_write(main)
			next_write = Time.get_ticks_msec() + 100
		await process_frame
	_write(main)
	quit(0)


func _params(seed_value: int) -> MapGenParams:
	var params := MapGenParams.make_defaults()
	params.biome_frequency = 0.0
	params.altitude_seed = seed_value
	params.moisture_seed = seed_value
	params.temperature_seed = seed_value
	params.items_seed = seed_value
	params.biome_seed = seed_value
	return params


func _arm(main) -> void:
	var world = main.get_node("World/worldMap")
	var cities: Cities = main.get_node("World/Cities")
	var director: RaidDirector = main.get_node("World/RaidDirector")
	var settings = root.get_node("GameSettings")
	var city := _place_city(world, cities)
	if city.is_empty():
		_note = "no palisade city"
		return
	var wall: Vector2i = city["wall"]
	_cell = wall
	_has_cell = true
	_hp = world._walls.hp(wall)
	if not _raids:
		director.advance(settings.raid_interval_s)
		_hp = world._walls.hp(wall)
		_assigned = 0
		_publish(main)
		return
	var mob := _raider(main, world, city["stand"])
	if mob == null:
		_note = "no mob"
		return
	settings.set_raids_enabled(true, false)
	director.advance(settings.raid_interval_s)
	_assigned = 1 if mob._raid_cell != Mob.RAID_NONE else 0
	if _assigned == 0:
		_note = "raid did not assign"
		settings.set_raids_enabled(false, false)
		return
	mob._step_raid(1.0)
	if mob._raid_strikes.is_empty():
		_note = "raid did not strike"
		settings.set_raids_enabled(false, false)
		return
	_cell = mob._raid_strikes[0]
	_hp = world._walls.hp(_cell)
	mob.clear_raid()
	settings.set_raids_enabled(false, false)
	director.advance(0.0)
	_publish(main)


func _publish(main) -> void:
	var requests = main.get_node("World/StructureRequests")
	for peer_id in main.multiplayer.get_peers():
		requests.sync_to_peer(int(peer_id))


func _raider(main, world, stand: Vector2i) -> Mob:
	var mobs_node: Node = main.get_node("World/Mobs")
	var best: Mob = null
	for child in mobs_node.get_children():
		if child is Mob and not (child as Mob).is_queued_for_deletion() \
				and (child as Mob).state != Mob.State.DYING:
			if best == null or str(child.name) < str(best.name):
				best = child
	if best == null:
		return null
	for child in mobs_node.get_children():
		if child is Mob and child != best:
			(child as Mob).state = Mob.State.CHASE
	best.global_position = world.to_global(world.map_to_local(stand))
	best.state = Mob.State.IDLE
	best._calm = 0.0
	return best


func _place_city(world, cities: Cities) -> Dictionary:
	var tower: Structure = StructurePlacer.load_named("tower_wood")
	for cell in world.get_used_cells(0):
		var origin: Vector2i = cell
		if not _clear_rect(world, origin, Vector2i(7, 7)):
			continue
		if not world._structures.can_place(tower, origin + Vector2i(3, 4), 0, true, false).is_empty():
			continue
		var id: int = world._structures.place_from_host(tower, origin + Vector2i(3, 4), 1)
		if id <= 0:
			continue
		var ring := _perimeter(origin, origin + Vector2i(6, 6))
		if not world.place_wall_cells(ring):
			continue
		cities.rebuild()
		if not cities.cities.has(id):
			continue
		var spot := _straight(world, origin, ring)
		if spot.is_empty():
			continue
		spot["id"] = id
		return spot
	return {}


func _straight(world, origin: Vector2i, ring: Array[Vector2i]) -> Dictionary:
	var centre := origin + Vector2i(3, 3)
	for cell in ring:
		var at: Vector2i = cell
		var piece := WallBuilder._atlas_wall_name(world._walls.piece(at))
		if not (piece.ends_with("_H") or piece.ends_with("_V")):
			continue
		var away := at - centre
		var step := Vector2i(signi(away.x), signi(away.y))
		if step == Vector2i.ZERO or (step.x != 0 and step.y != 0):
			continue
		var stand := at + step
		if world.has_wall(stand) or world._structures.has_cell(stand):
			continue
		var ground: Vector2i = world.predict_cell(stand)[0]
		if not world.ground_is_walkable(ground):
			continue
		return {"wall": at, "stand": stand}
	return {}


func _clear_rect(world, origin: Vector2i, size: Vector2i) -> bool:
	for y in size.y:
		for x in size.x:
			var cell := origin + Vector2i(x, y)
			if world.has_wall(cell) or world._structures.has_cell(cell):
				return false
			if world.get_cell_source_id(0, cell) == -1 or not world.predicted_clear(cell):
				return false
	return true


func _perimeter(lo: Vector2i, hi: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for x in range(lo.x, hi.x + 1):
		out.append(Vector2i(x, lo.y))
		out.append(Vector2i(x, hi.y))
	for y in range(lo.y + 1, hi.y):
		out.append(Vector2i(lo.x, y))
		out.append(Vector2i(hi.x, y))
	return out


func _walls(main) -> Array:
	var rows := []
	var world = main.get_node_or_null("World/worldMap")
	if world == null:
		return rows
	for cell: Vector2i in world._walls._wall_cells:
		rows.append([cell.x, cell.y, world._walls.hp(cell)])
	return rows


func _names_ready(main) -> bool:
	var me := ""
	if main.multiplayer != null:
		me = str(main.multiplayer.get_unique_id())
	return main.get_node_or_null("World/" + me) != null and main.world_params != null


func _write(main) -> void:
	var data := {
		"ready": _names_ready(main),
		"phase": _phase,
		"hp": _hp,
		"x": _cell.x,
		"y": _cell.y,
		"has_cell": _has_cell,
		"assigned": _assigned,
		"raids": _raids,
		"walls": _walls(main),
		"note": _note,
		"errors": _errors.snapshot(),
	}
	var tmp := _out + ".tmp"
	var file := FileAccess.open(tmp, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(data))
	file.close()
	if FileAccess.file_exists(_out):
		DirAccess.remove_absolute(_out)
	DirAccess.rename_absolute(tmp, _out)
