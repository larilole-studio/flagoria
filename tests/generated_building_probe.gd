extends SceneTree
## One peer of a generated-building session (#26).
## Host: --host --save --port --out. Client: --port --out.
## The host places one building. A client must not place its own.


var _errors := _ErrorLog.new()
var _placed := false
var _refused := false


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
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--port="):
			port = arg.trim_prefix("--port=").to_int()
		elif arg.begins_with("--save="):
			save = arg.trim_prefix("--save=")
		elif arg.begins_with("--out="):
			out = arg.trim_prefix("--out=")
		elif arg == "--host":
			host = true
	if port == 0 or out == "" or (host and save == "") or change_scene_to_file("res://flagoria_main.tscn") != OK:
		printerr("generated_building_probe: needs --port, --out, --save with --host, and the main scene")
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
			printerr("generated_building_probe: could not host %s: %s" % [save, error])
			quit(1)
			return
		main.add_player(1)
		_park_mobs(main)
	else:
		main.add_player_joined(port)
	var world: TileMap = main.get_node("World/worldMap")
	var buildings: GeneratedBuildings = main.get_node("World/GeneratedBuildings")
	var deadline := Time.get_ticks_msec() + 60000
	var next_write := 0
	while Time.get_ticks_msec() < deadline and not FileAccess.file_exists(out + ".stop"):
		if main.multiplayer == null or main.multiplayer.multiplayer_peer == null:
			break
		if not _peer_ready(main):
			await process_frame
			continue
		var me: Node2D = main.get_node_or_null("World/" + str(main.multiplayer.get_unique_id()))
		if host and not _placed and me != null and main.world_params != null:
			_placed = true
			var origin: Vector2i = world.local_to_map(me.position) + Vector2i(12, 2)
			if not buildings.generate(origin, 6, 5, 42, 0):
				printerr("generated_building_probe: host generate failed at %s" % origin)
		if not host and not _refused and buildings.record_count() > 0:
			_refused = not buildings.generate(Vector2i(0, 0), 6, 5, 1, 0)
		if Time.get_ticks_msec() >= next_write:
			_write(out, main, world, buildings, me)
			next_write = Time.get_ticks_msec() + 100
		await process_frame
	var fin: Node2D = null
	if _peer_ready(main):
		fin = main.get_node_or_null("World/" + str(main.multiplayer.get_unique_id()))
	_write(out, main, world, buildings, fin)
	quit(0)


func _park_mobs(main) -> void:
	for node in main.get_node("World/Mobs").get_children():
		if node is Mob:
			node.global_position = Vector2(100000, 100000)


func _peer_ready(main) -> bool:
	if main == null or main.multiplayer == null or main.multiplayer.multiplayer_peer == null:
		return false
	return main.multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED


func _write(out: String, main, world: TileMap, buildings: GeneratedBuildings, me: Node2D) -> void:
	if out == "" or main == null:
		return
	var cells := {}
	var door_clear := false
	var wall_blocked := false
	var saw_door := false
	var saw_wall := false
	if buildings != null and buildings.record_count() > 0:
		for cell in buildings.occupied_cells():
			var piece := buildings.piece_at(cell)
			var atlas := world.get_cell_atlas_coords(buildings.LAYER, cell)
			cells["%s,%s" % [cell.x, cell.y]] = {
				"piece": piece,
				"atlas": [atlas.x, atlas.y],
				"layer": world.get_cell_source_id(buildings.LAYER, cell),
			}
			if piece == "door":
				saw_door = true
				door_clear = not _hits(world, cell)
			elif piece == "wall_straight" or piece == "wall_corner" or piece == "window":
				saw_wall = true
				if _hits(world, cell):
					wall_blocked = true
	var file := FileAccess.open(out + ".tmp", FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify({
		"id": str(main.multiplayer.get_unique_id()) if _peer_ready(main) else "",
		"ready": main.world_params != null and me != null and buildings.record_count() > 0 and saw_door and saw_wall,
		"refused": _refused,
		"records": buildings.record_count(),
		"door_clear": door_clear,
		"wall_blocked": wall_blocked,
		"cells": cells,
		"errors": _errors.snapshot(),
	}))
	file.close()
	DirAccess.rename_absolute(out + ".tmp", out)


func _hits(world: TileMap, cell: Vector2i) -> bool:
	var query := PhysicsPointQueryParameters2D.new()
	query.collision_mask = 1
	query.position = world.to_global(world.map_to_local(cell))
	return not world.get_world_2d().direct_space_state.intersect_point(query, 1).is_empty()
