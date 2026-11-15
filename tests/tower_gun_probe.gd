extends SceneTree
## One peer of a tower-gun session (#37). Host: --host --save --port --out.
## Client: --port --out --mode=place. Late joiner: --port --out --mode=watch.
## The client places a tower with StructureRequests. The host pins itself
## from a phase file (out + ".phase": "in" or "out"). No timed sleep.


var _errors := _ErrorLog.new()
var _place_error := ""
var _want := Vector2.INF
var _anchor := Vector2i.ZERO
var _chose := false
var _placed := false


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
	var mode := "watch"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--port="):
			port = arg.trim_prefix("--port=").to_int()
		elif arg.begins_with("--save="):
			save = arg.trim_prefix("--save=")
		elif arg.begins_with("--out="):
			out = arg.trim_prefix("--out=")
		elif arg.begins_with("--mode="):
			mode = arg.trim_prefix("--mode=")
		elif arg == "--host":
			host = true
	if port == 0 or out == "" or (host and save == "") or change_scene_to_file("res://flagoria_main.tscn") != OK:
		printerr("tower_gun_probe: needs --port, --out, --save with --host, and the main scene")
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
			printerr("tower_gun_probe: could not host %s: %s" % [save, error])
			quit(1)
			return
		main.add_player(1)
		_park_mobs(main)
		_stop_regen(main)
	else:
		main.add_player_joined(port)
	var world = main.get_node("World/worldMap")
	var outside_since := 0
	var outside_health := -1
	var held := false
	var dropped_outside := false
	var deadline := Time.get_ticks_msec() + 90000
	var next_write := 0
	while Time.get_ticks_msec() < deadline and not FileAccess.file_exists(out + ".stop"):
		if main.multiplayer == null:
			break
		var me: Node2D = main.get_node_or_null("World/" + str(main.multiplayer.get_unique_id()))
		var ready := main.world_params != null and me != null
		if host:
			_park_mobs(main)
			_stop_regen(main)
			var phase := FileAccess.get_file_as_string(out + ".phase").strip_edges() if FileAccess.file_exists(out + ".phase") else ""
			var info := _tower_wood(world)
			if ready and not info.is_empty() and phase in ["in", "out"]:
				var centre: Vector2 = world.to_global(world.map_to_local(info["flag"]))
				var dir := _away(centre, _other_flags(world, info["flag"]))
				var at := centre + dir * (48.0 if phase == "in" else 128.0)
				_pin(me, at)
				var hp := _hp(me)
				if phase == "out":
					var now := Time.get_ticks_msec()
					if outside_since == 0:
						outside_since = now
						outside_health = hp
					elif hp < outside_health:
						dropped_outside = true
					elif not dropped_outside and now - outside_since >= 2000 and hp >= outside_health:
						held = true
				else:
					outside_since = 0
					outside_health = -1
					held = false
		elif mode == "place" and ready and _place_error == "":
			if not _castles_seen(world, main.multiplayer.get_unique_id()):
				pass
			elif not _chose:
				var anchor: Variant = _find_anchor(world)
				if anchor is Vector2i:
					_anchor = anchor
					_want = main.get_node("World/Interaction").cell_center(anchor) + Vector2(0, 40)
					_pin(me, _want)
					_chose = true
				else:
					_place_error = "no tower spot far from the castles"
			elif not _placed and FileAccess.file_exists(out + ".go"):
				var inventory: Inventory = main.get_node("Inventory")
				inventory.add(Inventory.WOOD, 10)
				var one: Array[Vector2i] = [_anchor]
				if not main.get_node("World/StructureRequests").place(BuildCosts.TOWER, one):
					_place_error = "place was not sent"
				else:
					_placed = true
			elif _placed and _tower_owner(world) == main.multiplayer.get_unique_id():
				var info := _tower_wood(world)
				var centre: Vector2 = world.to_global(world.map_to_local(info["flag"]))
				var dir := _away(centre, _other_flags(world, info["flag"]))
				_pin(me, centre + dir * 200.0)
		if Time.get_ticks_msec() >= next_write:
			_write(out, main, world, me, held, dropped_outside)
			next_write = Time.get_ticks_msec() + 100
		await process_frame
	var fin: Node2D = null
	if main.multiplayer != null:
		fin = main.get_node_or_null("World/" + str(main.multiplayer.get_unique_id()))
	_write(out, main, world, fin, held, dropped_outside)
	quit(0)


func _park_mobs(main) -> void:
	for node in main.get_node("World/Mobs").get_children():
		if node is Mob:
			node.set_physics_process(false)
			node.global_position = Vector2(100000, 100000)


func _stop_regen(main) -> void:
	## Regen restores one half-heart every 5 s from the moment a player
	## spawns. The late joiner starts only after the hit and the outside
	## hold, and a loaded runner can take longer than the rest of that
	## window to reach ready. Both peers then report full health and the
	## check cannot tell a synced hit from a miss. heal() runs on the
	## server only, so stopping these timers keeps the damaged value.
	var world: Node = main.get_node_or_null("World")
	if world == null:
		return
	for node in world.get_children():
		if node is CharacterBody2D:
			var timer := node.get_node_or_null("regen_timer") as Timer
			if timer:
				timer.stop()


func _pin(body: Node2D, at: Vector2) -> void:
	body.set_physics_process(false)
	var shape := body.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape:
		shape.disabled = true
	body.global_position = at


func _hp(body: Node) -> int:
	var health := body.get_node_or_null("Health") as PlayerHealth
	return health.health if health != null else -1


func _peer_id(main) -> String:
	if main == null or main.multiplayer == null:
		return ""
	return str(main.multiplayer.get_unique_id())


func _tower_wood(world) -> Dictionary:
	var placed: Dictionary = world.placed_structures()
	var towers: Dictionary = world._structures.towers()
	for id in placed.keys():
		if str(placed[id]["name"]) == "tower_wood" and towers.has(id):
			return {"id": int(id), "flag": towers[id][0], "owner": int(placed[id]["owner"])}
	return {}


func _tower_owner(world) -> int:
	var info := _tower_wood(world)
	return int(info["owner"]) if not info.is_empty() else -1


func _other_flags(world, except: Vector2i) -> Array:
	var out: Array = []
	var towers: Dictionary = world._structures.towers()
	for id in towers:
		for cell in towers[id]:
			if cell != except:
				out.append(world.to_global(world.map_to_local(cell)))
	return out


func _away(centre: Vector2, others: Array) -> Vector2:
	var dir := Vector2.RIGHT
	var nearest := INF
	var from := Vector2.ZERO
	for other in others:
		var d: float = centre.distance_to(other)
		if d < nearest:
			nearest = d
			from = other
	if nearest < INF / 2.0:
		var delta := centre - from
		if absf(delta.x) >= absf(delta.y):
			dir = Vector2.RIGHT if delta.x >= 0.0 else Vector2.LEFT
		else:
			dir = Vector2.DOWN if delta.y >= 0.0 else Vector2.UP
	return dir


func _castles_seen(world, my_id: int) -> bool:
	var host := false
	var mine := false
	for entry in world.placed_structures().values():
		if str(entry["name"]) != "castle":
			continue
		if int(entry["owner"]) == 1:
			host = true
		if int(entry["owner"]) == my_id:
			mine = true
	return host and mine


func _find_anchor(world) -> Variant:
	var spawn: Vector2i = world.resolve_player_spawn()
	for r in range(12, 90):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if maxi(absi(dx), absi(dy)) != r:
					continue
				var anchor := spawn + Vector2i(dx, dy)
				var one: Array[Vector2i] = [anchor]
				if not ConstructionPlacer.new(world).can_place_geometry(BuildCosts.TOWER, one).is_empty():
					continue
				var flag := anchor + Vector2i(0, -1)
				var centre: Vector2 = world.to_global(world.map_to_local(flag))
				var others := _other_flags(world, flag)
				var dir := _away(centre, others)
				if _corridor(world, flag, dir) and _clear_of(centre + dir * 48.0, others, 96.0) \
						and _clear_of(centre + dir * 128.0, others, 96.0) \
						and _clear_of(centre, others, 96.0):
					return anchor
	return null


func _corridor(world, flag: Vector2i, dir: Vector2) -> bool:
	## Clear land just outside the ring, along `dir`, including the stand at 8 cells.
	var step := Vector2i(int(dir.x), int(dir.y))
	for i in range(2, 9):
		var cell := flag + step * i
		if not world.predicted_clear(cell):
			return false
		if world.has_wall(cell) or world._structures.has_cell(cell):
			return false
	return true


func _clear_of(at: Vector2, others: Array, gap: float) -> bool:
	for other in others:
		if at.distance_to(other) < gap:
			return false
	return true


func _write(out: String, main, world, me: Node2D, held: bool, dropped_outside: bool) -> void:
	if out == "":
		return
	var players := {}
	var host_health := -1
	if main != null:
		var host: Node = main.get_node_or_null("World/1")
		if host != null:
			host_health = _hp(host)
		for node in main.get_node("World").get_children():
			if node is CharacterBody2D and str(node.name).is_valid_int():
				players[str(node.name)] = [node.global_position.x, node.global_position.y]
	var info := _tower_wood(world) if world != null else {}
	var file := FileAccess.open(out + ".tmp", FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify({
		"id": _peer_id(main),
		"ready": main != null and main.world_params != null and me != null,
		"self_health": _hp(me) if me != null else -1,
		"host_health": host_health,
		"want": [_want.x, _want.y] if _want != Vector2.INF else [],
		"anchor": [_anchor.x, _anchor.y] if _chose else [],
		"placed": _placed,
		"tower_owner": int(info["owner"]) if not info.is_empty() else -1,
		"held": held,
		"dropped_outside": dropped_outside,
		"players": players,
		"place_error": _place_error,
		"errors": _errors.snapshot(),
	}))
	file.close()
	DirAccess.rename_absolute(out + ".tmp", out)
