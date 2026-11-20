extends "res://tests/helpers/probe_base.gd"
## One peer of a multi-peer spawn session, run as its own headless process by
## test_spawn_late_join in tests/world/test_spawn.gd.
##   -- --port=N --out=PATH              join localhost:N through the Join path
##   -- --port=N --out=PATH --host       listen host with its own player
##   -- --port=N --out=PATH --dedicated  dedicated server, no player
## Every 100 ms it writes PATH (JSON): its peer id, the spawn point, every
## player's position and respawn count as this peer sees them, the last
## respawn spot its own player was sent and, on the server, the spot it
## picked for each player that joined, how many deaths its own player had
## and the first engine errors this process logged. It quits once PATH.stop exists. The server also kills every player
## in one frame once PATH.kill exists, so they all respawn together, and
## again each time the text in PATH.kill changes. While PATH.walk exists,
## this peer holds the input action named in it (for example ui_right), so
## its own player walks through the normal movement code.

var _id := 0
var _picked := {}
var _respawned_at := Vector2.INF
var _origin := Vector2.INF
var _kill_text = null
var _deaths := 0
var _walking := ""
var _points_before_map := false


func _run() -> void:
	var mode := "host" if has_option("--host") else ("dedicated" if has_option("--dedicated") else "join")
	var main = await open_game(mode != "join")
	if main == null:
		printerr("late_join_probe: needs --port=N, --out=PATH and the main scene")
		quit(1)
		return
	var world: Node = main.get_node("World")
	if mode != "join":
		# The server sets a player's spot before adding it to the tree.
		world.child_entered_tree.connect(func(node: Node) -> void:
			if node is CharacterBody2D:
				_picked[str(node.name)] = [node.position.x, node.position.y])
	if mode == "host":
		if host_game(main, _session_params()) == OK:
			host_listening()
	elif mode == "dedicated":
		if host_dedicated(main, _session_params()) == OK:
			host_listening()
	else:
		await join_game(main)
	var points := main.get_node_or_null("Points") as Points
	if points:
		# The kill snapshot must not ride ahead of the map: totals_received
		# before world_params means this peer got points first.
		points.totals_received.connect(func() -> void:
			if main.world_params == null:
				_points_before_map = true)
	_id = main.multiplayer.get_unique_id()
	var deadline := Time.get_ticks_msec() + 90000
	while game_active(main, deadline):
		var me: Node = world.get_node_or_null(str(_id))
		if me and not me.health.respawned.is_connected(_on_respawned):
			me.health.respawned.connect(_on_respawned)
			me.health.health_changed.connect(_on_health_changed)
		if mode != "join" and FileAccess.file_exists(probe_out + ".kill") \
				and FileAccess.get_file_as_string(probe_out + ".kill") != _kill_text:
			_kill_text = FileAccess.get_file_as_string(probe_out + ".kill")
			for child in world.get_children():
				if child is CharacterBody2D:
					child.health.set_health_now(0)
		var walk := FileAccess.get_file_as_string(probe_out + ".walk").strip_edges() \
				if FileAccess.file_exists(probe_out + ".walk") else ""
		if walk != _walking:
			if _walking != "":
				Input.action_release(_walking)
			if walk != "" and InputMap.has_action(walk):
				Input.action_press(walk)
			_walking = walk
		if snapshot_due(main):
			_write(main, world)
		await process_frame
	finish(main, func() -> void: _write(main, world))


func _session_params() -> MapGenParams:
	var params: MapGenParams = root.get_node("MapGen").params.duplicate_params()
	params.altitude_seed = 11
	params.moisture_seed = 11
	params.temperature_seed = 11
	params.items_seed = 11
	params.biome_seed = 11
	return params


func _on_respawned(at: Vector2) -> void:
	_respawned_at = at


func _on_health_changed(current: int, _maximum: int) -> void:
	if current == 0:
		_deaths += 1


func _write(main: Node, world: Node) -> void:
	if _origin == Vector2.INF and main.world_params != null:
		var map = world.get_node("worldMap")
		_origin = map.map_to_local(map.resolve_player_spawn())
	var players := {}
	for child in world.get_children():
		if child is CharacterBody2D:
			players[str(child.name)] = {
				"pos": [child.position.x, child.position.y],
				"respawns": child.health.respawn_count,
			}
	var mobs: Array = []
	var mob_root := world.get_node_or_null("Mobs")
	if mob_root:
		for child in mob_root.get_children():
			mobs.append(str(child.name))
		mobs.sort()
	var points := main.get_node_or_null("Points") as Points
	var state := {
		"id": str(_id),
		"origin": [_origin.x, _origin.y] if _origin != Vector2.INF else null,
		"picked": _picked,
		"respawned_at": [_respawned_at.x, _respawned_at.y] if _respawned_at != Vector2.INF else null,
		"deaths": _deaths,
		"errors": _errors.snapshot(),
		"players": players,
		"mobs": mobs,
		"host_points": points.total_of(1) if points else 0,
		"points_before_map": _points_before_map,
	}
	write_result(state)
