extends SceneTree
## Raid wall damage and the disabled setting over real peers (#529).
## The host waits for the normal raid clock and mob physics to run.
##   -- --port=N --out=PATH --role=host --seed=11 --raids=on
##   -- --port=N --out=PATH --role=join --seed=11 --raids=off


var _out := ""
var _errors := _ErrorLog.new()
var _raids := false
var _armed := false
var _phase := 0
var _hp := -1
var _cell := Vector2i.ZERO
var _assigned := false
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
		settings.raid_interval_s = 0.25  # Short fixture interval below the menu minimum.
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
			await _arm(main)
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
	var settings = root.get_node("GameSettings")
	var requests: StructureRequests = main.get_node("World/StructureRequests")
	var player: Node2D = main.get_node("World/1")
	var inventory: Inventory = main.get_node("Inventory")
	var anchor := Vector2i(22, -15)
	var origin := Vector2i(19, -19)
	_cell = Vector2i(22, -13)
	world.generate_chunk(world.map_to_local(anchor))
	var spawn := player.global_position
	player.global_position = world.to_global(world.map_to_local(anchor + Vector2i(0, 2)))
	inventory.add(Inventory.WOOD, 10)
	var placed := requests.place(BuildCosts.TOWER, [anchor])
	player.global_position = spawn
	var ring: Array[Vector2i] = []
	for offset in 7:
		ring.append(origin + Vector2i(offset, 0))
		ring.append(origin + Vector2i(offset, 6))
		if offset > 0 and offset < 6:
			ring.append(origin + Vector2i(0, offset))
			ring.append(origin + Vector2i(6, offset))
	if not placed or not world.place_wall_cells(ring):
		_note = "could not place seed-11 city"
		return
	cities.rebuild()
	for peer_id in main.multiplayer.get_peers():
		requests.sync_to_peer(peer_id)
	var mobs: MobSpawner = main.get_node("World/Mobs")
	mobs.set_physics_process(false)
	mobs.clear_mobs()
	var mob := mobs.spawner.spawn({
		"name": "raid_fixture", "type": MobCatalog.SLIME, "seed": 11,
		"pos": world.map_to_local(Vector2i(22, -12)),
	}) as Mob
	if mob == null:
		_note = "could not spawn raider"
		return
	settings.set_raids_enabled(_raids, false)
	var deadline := Time.get_ticks_msec() + 5000
	var off_done := Engine.get_physics_frames() + 30  # Half a second at 60 Hz.
	var key := WorldSave.cell_key(_cell)
	while Time.get_ticks_msec() < deadline:
		_hp = int(_walls(main).get(key, -1))
		_assigned = _assigned or (mob.state != Mob.State.CHASE and mob.pinned())
		if (_raids and _hp == 2 and _assigned) or (not _raids and Engine.get_physics_frames() >= off_done):
			settings.set_raids_enabled(false, false)
			return
		await process_frame
	_note = "raid clock or strike did not reach the expected state"


func _walls(main) -> Dictionary:
	var walls := {}
	var world = main.get_node_or_null("World/worldMap")
	if world != null:
		for chunk: Dictionary in StructureSaves.to_changes(world).values():
			for key: String in chunk:
				if chunk[key].has("wall"):
					walls[key] = chunk[key].get("hp", 3)
	return walls


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
		"cell": WorldSave.cell_key(_cell),
		"assigned": _assigned,
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
