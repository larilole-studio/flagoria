extends SceneTree
## Lifecycle for headless peers that publish live JSON snapshots.

const HostListen = preload("res://tests/helpers/test_helpers.gd")

var probe_port: int
var probe_out: String
var _options: Dictionary = {}
var _next_snapshot := 0
var _errors := _ErrorLog.new()


func _init() -> void:
	for arg in OS.get_cmdline_user_args():
		var parts := arg.split("=", true, 1)
		_options[parts[0]] = parts[1] if parts.size() == 2 else ""
	probe_port = option("--port").to_int()
	probe_out = option("--out")


func _initialize() -> void:
	OS.add_logger(_errors)
	call_deferred("_run")


func option(key: String, default: String = "") -> String:
	return _options.get(key, default)


func has_option(key: String) -> bool:
	return _options.has(key)


func open_game(hosting: bool) -> Node:
	if probe_port <= 0 or probe_out.is_empty():
		return null
	if hosting:
		HostListen.arm_host(probe_out)
	if change_scene_to_file("res://flagoria_main.tscn") != OK:
		return null
	await process_frame
	await process_frame
	return current_scene


func host_game(main, params: MapGenParams) -> Error:
	var error: Error = main.setup_server(params, probe_port)
	if error == OK:
		main.add_player(1)
	return error


func host_saved_game(main, path: String) -> String:
	var map_gen = root.get_node("MapGen")
	var error: String = map_gen.load_map_inputs(path)
	if error.is_empty() and host_game(main, map_gen.params.duplicate_params()) != OK:
		return "could not start listening"
	return error


func host_dedicated(main, params: MapGenParams) -> Error:
	return main.start_dedicated_server(probe_port, params)


func host_listening() -> void:
	HostListen.mark_host_listening(probe_out)


func join_game(main: Node) -> void:
	await HostListen.join_when_host_listening(main, probe_port, probe_out)


func game_active(main, deadline: int) -> bool:
	return is_instance_valid(main) and main.is_inside_tree() \
			and Time.get_ticks_msec() < deadline and not FileAccess.file_exists(probe_out + ".stop")


func wait_for_peers(main, count: int, timeout_ms: int) -> bool:
	var deadline := Time.get_ticks_msec() + timeout_ms
	while game_active(main, deadline):
		if main.multiplayer.has_multiplayer_peer() and main.multiplayer.get_peers().size() >= count:
			return true
		await process_frame
	return false


func snapshot_due(main) -> bool:
	var now := Time.get_ticks_msec()
	if not is_instance_valid(main) or not main.is_inside_tree() or now < _next_snapshot:
		return false
	_next_snapshot = now + 100
	return true


func local_player(main) -> Node2D:
	if main.multiplayer == null or not main.multiplayer.has_multiplayer_peer():
		return null
	return main.get_node_or_null("World/" + str(main.multiplayer.get_unique_id()))


func write_result(data: Dictionary) -> void:
	var tmp := probe_out + ".tmp"
	var file := FileAccess.open(tmp, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(data))
	file.close()
	DirAccess.rename_absolute(tmp, probe_out)


func finish(main, snapshot: Callable) -> void:
	# Disconnects can replace the scene before the stop marker arrives.
	# Read the scene and publish the last snapshot before asking Godot to quit.
	if not is_instance_valid(main) or not main.is_inside_tree():
		quit(1)
		return
	snapshot.call()
	quit(0)


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
