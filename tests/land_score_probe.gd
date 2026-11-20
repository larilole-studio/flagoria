extends "res://tests/helpers/probe_base.gd"
## One peer of a land-score session (#279).
## Host: --host --save --port --out. Client: --port --out --mode.
## The host scores city land. A ".drop" file hands the host castle to neutral.


var _dropped := false
var _client_tick_same := true


func _run() -> void:
	var save := option("--save")
	var host := has_option("--host")
	if host and save == "":
		printerr("land_score_probe: needs --port, --out, --save with --host, and the main scene")
		quit(1)
		return
	var main = await open_game(host)
	if main == null:
		printerr("land_score_probe: needs --port, --out, --save with --host, and the main scene")
		quit(1)
		return
	main.get_node("CanvasLayer2/MainMenu").hide()
	if host:
		var error := host_saved_game(main, save)
		if error != "":
			printerr("land_score_probe: could not host %s: %s" % [save, error])
			quit(1)
			return
		main.get_node("Discovery").set_physics_process(false)
		_park_mobs(main)
		host_listening()
	else:
		await join_game(main)
	var world = main.get_node("World/worldMap")
	var checked_client := false
	var deadline := Time.get_ticks_msec() + 60000
	while game_active(main, deadline):
		if main.multiplayer == null or main.multiplayer.multiplayer_peer == null:
			break
		if not _peer_ready(main):
			await process_frame
			continue
		var me: Node2D = main.get_node_or_null("World/" + str(main.multiplayer.get_unique_id()))
		if host and not _dropped and FileAccess.file_exists(probe_out + ".drop"):
			_dropped = true
			_drop_host_castle(main, world)
		if not host and not checked_client and main.world_params != null and me != null:
			checked_client = true
			var points: Points = main.get_node("Points")
			var before: int = points.total_of(1)
			main.get_node("World/LandScore").tick()
			_client_tick_same = points.total_of(1) == before
		if snapshot_due(main):
			_write(main, world, me)
		await process_frame
	finish(main, func() -> void: _write(main, world, local_player(main)))


func _drop_host_castle(main, world) -> void:
	var placed: Dictionary = world.placed_structures()
	var castle := -1
	for id in placed:
		if str(placed[id]["name"]) == "castle" and int(placed[id]["owner"]) == 1:
			castle = int(id)
			break
	if castle < 0:
		return
	world._structures.set_owner(castle, StructurePlacer.OWNER_NEUTRAL)
	var capture: TowerCapture = main.get_node("World/TowerCapture")
	capture.receive_capture_state.rpc(capture.capture_snapshot())
	main.get_node("World/LandScore").tick()


func _peer_ready(main) -> bool:
	## False once the peer API is gone or no longer connected. A last snapshot
	## after .stop must not read the id; that script error fails the stress
	## run after the test passed.
	if main == null or main.multiplayer == null or main.multiplayer.multiplayer_peer == null:
		return false
	return main.multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED


func _park_mobs(main) -> void:
	for node in main.get_node("World/Mobs").get_children():
		if node is Mob:
			node.global_position = Vector2(100000, 100000)


func _write(main, world, me: Node2D) -> void:
	if probe_out == "" or main == null:
		return
	var points := {}
	var land := {}
	var board := []
	if main.world_params != null:
		var scores: Points = main.get_node("Points")
		var counts: Dictionary = main.get_node("World/LandScore").covered_counts()
		var ids := {1: true}
		for node in main.get_node("World").get_children():
			if str(node.name).is_valid_int():
				ids[int(str(node.name))] = true
		for peer_id in ids:
			points[str(peer_id)] = scores.total_of(int(peer_id))
			land[str(peer_id)] = int(counts.get(int(peer_id), 0))
		if _peer_ready(main):
			var panel: ScoreboardPanel = main.get_node("CanvasLayer1/ScoreboardPanel")
			for row in panel.sorted_rows():
				board.append([int(row[0]), int(row[1])])
	write_result({
		"id": str(main.multiplayer.get_unique_id()) if _peer_ready(main) else "",
		"ready": main.world_params != null and me != null,
		"dropped": _dropped,
		"client_tick_same": _client_tick_same,
		"points": points,
		"land": land,
		"board": board,
		"errors": _errors.snapshot(),
	})
