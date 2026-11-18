extends SceneTree
## One peer of a building-merge session (#27). Seed 49. Host places two flush
## buildings, removes the second, and a late joiner replays the list.


var _errors := _ErrorLog.new()
var _step := 0
var _merge_wait := 0
var _origin1 := Vector2i.ZERO
var _seam_snapshot := {}


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
		printerr("building_merge_probe: needs --port, --out, --save with --host, and the main scene")
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
			printerr("building_merge_probe: could not host %s: %s" % [save, error])
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
		if not host and buildings.record_count() >= 2 and _seam_snapshot.is_empty():
			_origin1 = _infer_origin1(buildings)
			_seam_snapshot = _seam_cells(buildings)
		if host:
			var me: Node2D = main.get_node_or_null("World/" + str(main.multiplayer.get_unique_id()))
			if me != null and main.world_params != null:
				if _step == 0:
					_origin1 = world.local_to_map(me.position) + Vector2i(10, 2)
					if buildings.generate(_origin1, 6, 5, 42, 0):
						_step = 1
				elif _step == 1 and buildings.record_count() >= 1:
					var origin2 := _origin1 + Vector2i(6, 0)
					if buildings.generate(origin2, 6, 5, 43, 0):
						_step = 2
				elif _step == 2 and buildings.record_count() >= 2:
					if _seam_snapshot.is_empty():
						_seam_snapshot = _seam_cells(buildings)
					_merge_wait += 1
					if _merge_wait > 900:
						_step = 3
				elif _step == 3:
					if buildings.remove_at(1):
						_step = 4
		if Time.get_ticks_msec() >= next_write:
			_write(out, main, world, buildings)
			next_write = Time.get_ticks_msec() + 100
		await process_frame
	_write(out, main, world, buildings)
	quit(0)


func _park_mobs(main) -> void:
	for node in main.get_node("World/Mobs").get_children():
		if node is Mob:
			node.global_position = Vector2(100000, 100000)


func _peer_ready(main) -> bool:
	if main == null or main.multiplayer == null or main.multiplayer.multiplayer_peer == null:
		return false
	return main.multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED


func _write(out: String, main, world: TileMap, buildings: GeneratedBuildings) -> void:
	if out == "" or main == null:
		return
	var cells := {}
	var seam := _seam_snapshot if not _seam_snapshot.is_empty() else _seam_cells(buildings)
	if buildings != null:
		for cell in buildings.occupied_cells():
			var piece := buildings.piece_at(cell)
			cells["%s,%s" % [cell.x, cell.y]] = piece
	var file := FileAccess.open(out + ".tmp", FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify({
		"id": str(main.multiplayer.get_unique_id()) if _peer_ready(main) else "",
		"merged": not _seam_snapshot.is_empty(),
		"resealed": buildings.record_count() == 1 and _second_gone(buildings),
		"records": buildings.record_count(),
		"step": _step,
		"cells": cells,
		"seam": seam,
		"errors": _errors.snapshot(),
	}))
	file.close()
	DirAccess.rename_absolute(out + ".tmp", out)


func _second_gone(buildings: GeneratedBuildings) -> bool:
	if buildings == null or buildings.record_count() != 1:
		return false
	if _origin1 == Vector2i.ZERO:
		_origin1 = _infer_origin1(buildings)
	var o2 := _origin1 + Vector2i(6, 0)
	return buildings.piece_at(o2) == ""


func _infer_origin1(buildings: GeneratedBuildings) -> Vector2i:
	var origin := Vector2i(1 << 29, 1 << 29)
	for cell in buildings.occupied_cells():
		origin.x = mini(origin.x, cell.x)
		origin.y = mini(origin.y, cell.y)
	return origin


func _seam_cells(buildings: GeneratedBuildings) -> Dictionary:
	var seam := {}
	if _origin1 == Vector2i.ZERO or buildings == null:
		return seam
	for y in 5:
		var left := _origin1 + Vector2i(5, y)
		var right := _origin1 + Vector2i(6, y)
		seam["%s,%s" % [left.x, left.y]] = buildings.piece_at(left)
		seam["%s,%s" % [right.x, right.y]] = buildings.piece_at(right)
	return seam