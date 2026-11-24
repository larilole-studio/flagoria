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


func host_saved_game(main, path: String, before_player: Callable = Callable()) -> String:
	var map_gen = root.get_node("MapGen")
	var error: String = map_gen.load_map_inputs(path)
	if not error.is_empty():
		return error
	if not before_player.is_valid():
		return (
			""
			if host_game(main, map_gen.params.duplicate_params()) == OK
			else "could not start listening"
		)
	if main.setup_server(map_gen.params.duplicate_params(), probe_port) != OK:
		return "could not start listening"
	error = before_player.call()
	if error.is_empty():
		main.add_player(1)
	return error


func host_dedicated(main, params: MapGenParams) -> Error:
	return main.start_dedicated_server(probe_port, params)


func host_listening() -> void:
	HostListen.mark_host_listening(probe_out)


func join_game(main: Node) -> void:
	await HostListen.join_when_host_listening(main, probe_port, probe_out)


func game_active(main, deadline: int) -> bool:
	return (
		is_instance_valid(main)
		and main.is_inside_tree()
		and Time.get_ticks_msec() < deadline
		and not FileAccess.file_exists(probe_out + ".stop")
	)


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


func wait_for_state(predicate: Callable, timeout_ms: int) -> bool:
	var deadline := Time.get_ticks_msec() + timeout_ms
	while not predicate.call():
		if Time.get_ticks_msec() >= deadline or FileAccess.file_exists(probe_out + ".stop"):
			return false
		await process_frame
	return true


func host_snapshot() -> Dictionary:
	return HostListen.read_probe_result(probe_out.get_base_dir().path_join("p0.json"))


func install_round_trip(main: Node) -> void:
	var peer := ReliableRoundTrip.new()
	peer.name = "ProbeRoundTrip"
	main.add_child(peer)


func wait_for_round_trip(main: Node) -> bool:
	# The default reliable channel orders this after earlier gameplay RPCs.
	var peer: ReliableRoundTrip = main.get_node("ProbeRoundTrip")
	var sequence := peer.reply + 1
	peer.acknowledge.rpc_id(1, sequence)
	return await wait_for_state(func() -> bool: return peer.reply == sequence, 5000)


func park_mobs(main: Node) -> void:
	for node in main.get_node("World/Mobs").get_children():
		if node is Mob:
			node.global_position = Vector2(100000, 100000)


func castle_touch(world) -> Vector2i:
	# A synced castle can be available before the client's first chunk refresh.
	# Use predicted terrain, as the placement rules do, so painting can lag.
	var placer := ConstructionPlacer.new(world)
	for entry in world.placed_structures().values():
		if str(entry["name"]) != "castle":
			continue
		var anchor: Vector2i = entry["anchor"]
		var rejected := {"predicted_clear false": 0}
		for dy in range(-8, 9):
			for dx in range(-8, 9):
				var cell := anchor + Vector2i(dx, dy)
				if not world.predicted_clear(cell):
					rejected["predicted_clear false"] += 1
					continue
				var one: Array[Vector2i] = [cell]
				var reasons := placer.can_place_geometry(BuildCosts.WALL_BLOCK, one)
				if reasons.is_empty():
					return cell
				for reason in reasons:
					rejected[reason] = rejected.get(reason, 0) + 1
		printerr("castle_touch: no clear cell at castle %s (rejections %s)" % [anchor, rejected])
		break
	return Vector2i(1 << 20, 0)


func host_sees_position(peer_id: String, where: Vector2) -> bool:
	var pos = host_snapshot().get("peers", {}).get(peer_id)
	if not pos is Array or pos.size() < 2:
		return false
	return Vector2(float(pos[0]), float(pos[1])).distance_to(where) <= 4.0


func peer_positions(main: Node) -> Dictionary:
	var positions := {}
	for child in main.get_node("World").get_children():
		if child is CharacterBody2D and str(child.name).is_valid_int():
			positions[str(child.name)] = [child.global_position.x, child.global_position.y]
	return positions


class ReliableRoundTrip:
	extends Node
	var reply := 0

	@rpc("any_peer", "call_remote", "reliable")
	func acknowledge(sequence: int) -> void:
		var sender := multiplayer.get_remote_sender_id()
		if multiplayer.is_server():
			acknowledge.rpc_id(sender, sequence)
		elif sender == 1:
			reply = sequence


class _ErrorLog:
	extends Logger
	var lines: Array[String] = []
	var _lock := Mutex.new()

	func _log_error(
		function: String,
		_file: String,
		_line: int,
		code: String,
		rationale: String,
		_editor_notify: bool,
		_error_type: int,
		_script_backtraces: Array[ScriptBacktrace]
	) -> void:
		_lock.lock()
		if lines.size() < 5:
			lines.append("%s: %s" % [function, rationale if rationale != "" else code])
		_lock.unlock()

	func snapshot() -> Array[String]:
		_lock.lock()
		var copy := lines.duplicate()
		_lock.unlock()
		return copy
