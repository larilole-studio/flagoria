extends SceneTree
## One peer of a day/night sync session (#558).
##   -- --port=N --out=PATH           join localhost:N
##   -- --port=N --out=PATH --host    listen host, then seek the night hold
## Writes PATH every 100 ms: phase, elapsed, tint, and the first errors.
## Quits when PATH.stop exists. Waits on that file, never on a timer.

var _out := ""
var _errors := _ErrorLog.new()


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
	var host := false
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--port="):
			port = arg.trim_prefix("--port=").to_int()
		elif arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=")
		elif arg == "--host":
			host = true
	if port == 0 or _out == "" or change_scene_to_file("res://flagoria_main.tscn") != OK:
		printerr("day_night_probe: needs --port, --out and the main scene")
		quit(1)
		return
	await process_frame
	await process_frame
	var main := current_scene
	if host:
		var params := MapGenParams.make_defaults()
		params.altitude_seed = 11
		params.moisture_seed = 12
		params.temperature_seed = 13
		params.items_seed = 14
		params.biome_seed = 15
		main.setup_server(params, port)
		main.add_player(1)
		root.get_node("DayNight").seek_phase("night")
	else:
		main.add_player_joined(port)
	var deadline := Time.get_ticks_msec() + 90000
	var next_write := 0
	while Time.get_ticks_msec() < deadline and not FileAccess.file_exists(_out + ".stop"):
		if not is_instance_valid(main):
			printerr("day_night_probe: match ended")
			quit(1)
			return
		if Time.get_ticks_msec() >= next_write:
			next_write = Time.get_ticks_msec() + 100
			_write()
		await process_frame
	_write()
	quit(0)


func _write() -> void:
	var state: Dictionary = root.get_node("DayNight").report()
	state["errors"] = _errors.snapshot()
	var tmp := _out + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify(state))
	f.close()
	DirAccess.rename_absolute(tmp, _out)
