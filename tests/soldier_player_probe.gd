extends "res://tests/soldier_sync_probe.gd"
## Host-owned soldier on Hold pins a client in range until player health drops (#555).


var _fight_started := false
var _fight_spawn_at := -1
var _victim_id := ""


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
	_out = out
	if port == 0 or out == "" or (host and save == "") or change_scene_to_file("res://flagoria_main.tscn") != OK:
		printerr("soldier_player_probe: needs --port, --out, --save with --host, and the main scene")
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
			printerr("soldier_player_probe: could not host %s: %s" % [save, error])
			quit(1)
			return
		main.add_player(1)
	else:
		main.add_player_joined(port)
	var world = main.get_node("World/worldMap")
	var requests: SoldierRequests = main.get_node("World/Soldiers")
	var phase := "idle"
	var me: Node2D = null
	var deadline := Time.get_ticks_msec() + 90000
	var next_write := 0
	while Time.get_ticks_msec() < deadline and not FileAccess.file_exists(out + ".stop"):
		if main.multiplayer == null:
			break
		me = main.get_node_or_null("World/" + str(main.multiplayer.get_unique_id())) as Node2D
		var ready := main.world_params != null and me != null
		if host and ready and requests.pending_job_count() > 0:
			requests.advance(SoldierStats.TRAIN_TIME)
		if host and mode == "place" and phase == "idle" and ready:
			phase = "working"
			_place_error = await _do_host_place(main, world, me, requests)
			phase = "done"
		if host and ready and not _fight_started and _soldier_rows(requests).size() > 0:
			if _fight_spawn_at < 0:
				_fight_spawn_at = Time.get_ticks_msec() + 3000
			elif Time.get_ticks_msec() >= _fight_spawn_at:
				_fight_started = true
				_begin_peer_fight(requests)
		_victim_id = _find_victim_id(main)
		if host and _fight_started:
			_pin_victim(main, requests)
		if Time.get_ticks_msec() >= next_write:
			_write_peer_fight(out, main, world, me, requests)
			next_write = Time.get_ticks_msec() + 100
		await process_frame
	_write_peer_fight(out, main, world, me, requests)
	quit(0)


func _do_host_place(main, world, me: Node2D, requests: SoldierRequests) -> String:
	var interaction: Interaction = main.get_node("World/Interaction")
	var structure_requests = main.get_node("World/StructureRequests")
	var inventory: Inventory = main.get_node("Inventory")
	var land: Variant = _search(world, func(cell: Vector2i) -> bool: return _barracks_ok(world, cell, 0))
	if land == null:
		return "no clear barracks anchor"
	_pin(me, interaction.cell_center(land) + Vector2(0, 48))
	await process_frame
	var one: Array[Vector2i] = [land]
	inventory.add(Inventory.WOOD, 30)
	if not structure_requests.place(BuildCosts.BARRACKS, one, 0):
		return "place was not sent"
	var builder: int = main.multiplayer.get_unique_id()
	if not await _until(func() -> bool: return _barracks_count(world, builder) >= 1, 8000):
		return "built barracks was not applied"
	_train_anchor = land
	_pin(me, interaction.cell_center(land) + Vector2(0, 48))
	await process_frame
	inventory.add(Inventory.WOOD, SoldierStats.TRAIN_WOOD)
	requests.host_train(builder, land)
	if not await _until(func() -> bool: return _soldier_rows(requests).size() >= 1, 15000):
		return "soldier did not spawn"
	requests.host_set_order(builder)
	if not await _until(func() -> bool:
		var rows := _soldier_rows(requests)
		return not rows.is_empty() and str(rows[0][2]) == "hold", 8000):
		return "hold order did not apply"
	return ""


func _find_victim_id(main) -> String:
	if main == null:
		return ""
	var world_root: Node = main.get_node_or_null("World")
	if world_root == null:
		return ""
	for child in world_root.get_children():
		if child is CharacterBody2D and str(child.name).is_valid_int():
			if int(child.name) != 1:
				return str(child.name)
	return ""


func _soldier_for_host(requests: SoldierRequests) -> Soldier:
	for child in requests.get_children():
		if child is Soldier and child.owner_peer == 1 and child.state != Soldier.State.DYING:
			return child
	return null


func _begin_peer_fight(requests: SoldierRequests) -> void:
	var soldier := _soldier_for_host(requests)
	if soldier == null:
		return
	soldier.set_order("hold")
	soldier._hold_pos = soldier.global_position


func _pin_victim(main, requests: SoldierRequests) -> void:
	var soldier := _soldier_for_host(requests)
	if soldier == null:
		return
	if _victim_id == "":
		return
	var victim := main.get_node_or_null("World/" + _victim_id) as CharacterBody2D
	if victim == null:
		return
	victim.global_position = soldier.global_position + Vector2(6, 0)
	victim.velocity = Vector2.ZERO


func _peer_health(main) -> Dictionary:
	if _victim_id == "":
		return {"hp": -1, "start": 6}
	var body := main.get_node_or_null("World/" + _victim_id) as Node2D if main != null else null
	var health := body.get_node_or_null("Health") as PlayerHealth if body != null else null
	var max_h := health.max_health if health != null else PlayerHealth.new().max_health
	return {"hp": health.health if health != null else -1, "start": max_h}


func _write_peer_fight(out: String, main, world, me: Node2D, requests: SoldierRequests) -> void:
	if out == "":
		return
	var peers := {}
	var world_root: Node = null
	if main != null:
		world_root = main.get_node_or_null("World")
	if world_root != null:
		for child in world_root.get_children():
			if child is CharacterBody2D and str(child.name).is_valid_int():
				peers[str(child.name)] = [child.global_position.x, child.global_position.y]
	var victim := _peer_health(main)
	var file := FileAccess.open(out + ".tmp", FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify({
		"id": _peer_id(main),
		"ready": main != null and main.world_params != null and me != null,
		"place_error": _place_error,
		"peers": peers,
		"soldiers": _soldier_rows(requests),
		"pending_jobs": requests.pending_job_count() if requests != null else 0,
		"fight_peer_hp": victim["hp"],
		"fight_peer_start_hp": victim["start"],
		"errors": _errors.snapshot(),
	}))
	file.close()
	DirAccess.rename_absolute(out + ".tmp", out)