extends SceneTree
## One peer of a night mob session (#559).
## The host seeks the night hold and ticks the ambient band once.
##   -- --port=N --out=PATH --role=host --seed=11
##   -- --port=N --out=PATH --role=join --seed=11
## Writes PATH every 100 ms. Quits when PATH.stop exists.


var _out := ""
var _errors := _ErrorLog.new()
var _ticked := false


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
	if port == 0 or _out == "" or change_scene_to_file("res://flagoria_main.tscn") != OK:
		printerr("night_mob_probe: needs --port, --out and the main scene")
		quit(1)
		return
	await process_frame
	await process_frame
	var main = current_scene
	main.get_node("CanvasLayer2/MainMenu").hide()
	if role == "host":
		root.get_node("GameSettings").set_mob_rate(1.0, false)
		if main.setup_server(_params(seed_value), port) != OK:
			printerr("night_mob_probe: could not host")
			quit(1)
			return
		main.add_player(1)
		root.get_node("DayNight").seek_phase("night")
	else:
		main.add_player_joined(port)
	var deadline := Time.get_ticks_msec() + 45000
	var next_write := 0
	while Time.get_ticks_msec() < deadline and not FileAccess.file_exists(_out + ".stop"):
		if role == "host" and not _ticked and _player_alive(main):
			main.get_node("World/Mobs").run_ambient_tick()
			_ticked = true
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


func _player_alive(main) -> bool:
	for child in main.get_node("World").get_children():
		if child is CharacterBody2D and Mob.is_alive(child):
			return true
	return false


func _rows(main) -> Array:
	var rows: Array = []
	var mobs_node: Node = main.get_node_or_null("World/Mobs")
	if mobs_node == null:
		return rows
	for child in mobs_node.get_children():
		if child is Mob and not child.is_queued_for_deletion():
			rows.append({
				"name": str(child.name),
				"type": str(child.mob_type),
				"x": int(round(child.home.x)),
				"y": int(round(child.home.y)),
			})
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return str(a["name"]) < str(b["name"]))
	return rows


func _write(main) -> void:
	var clock := root.get_node("DayNight")
	var data := {
		"ready": _player_alive(main),
		"phase": clock.phase(),
		"scale": clock.spawn_scale(),
		"ticked": _ticked,
		"rows": _rows(main),
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
