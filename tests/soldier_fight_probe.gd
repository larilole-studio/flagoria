extends "res://tests/soldier_sync_probe.gd"
## Host spawns a slime in attack range after a soldier trains (#554).


var _fight_mob := ""
var _fight_started := false
var _fight_spawn_at := -1


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
		printerr("soldier_fight_probe: needs --port, --out, --save with --host, and the main scene")
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
			printerr("soldier_fight_probe: could not host %s: %s" % [save, error])
			quit(1)
			return
		main.add_player(1)
	else:
		main.add_player_joined(port)
	var world = main.get_node("World/worldMap")
	var requests: SoldierRequests = main.get_node("World/Soldiers")
	var mobs: MobSpawner = main.get_node("World/Mobs")
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
		if not host and mode == "place" and phase == "idle" and ready:
			phase = "working"
			_place_error = await _do_place(main, world, me, requests)
			phase = "done"
		if host and ready and not _fight_started and _soldier_rows(requests).size() > 0:
			if _fight_spawn_at < 0:
				_fight_spawn_at = Time.get_ticks_msec() + 3000
			elif Time.get_ticks_msec() >= _fight_spawn_at:
				_fight_started = true
				_spawn_fight_mob(requests, mobs)
		if Time.get_ticks_msec() >= next_write:
			_write_fight(out, main, world, me, requests, mobs)
			next_write = Time.get_ticks_msec() + 100
		await process_frame
	_write_fight(out, main, world, me, requests, mobs)
	quit(0)


func _do_place(main, world, me: Node2D, requests: SoldierRequests) -> String:
	var interaction: Interaction = main.get_node("World/Interaction")
	var structure_requests = main.get_node("World/StructureRequests")
	var inventory: Inventory = main.get_node("Inventory")
	var land: Variant = _search(world, func(cell: Vector2i) -> bool: return _barracks_ok(world, cell, 0))
	if land == null:
		return "no clear barracks anchor"
	var err := await _ready_to_build(main, me, interaction.cell_center(land) + Vector2(0, 48))
	if err != "":
		return err
	var one: Array[Vector2i] = [land]
	inventory.add(Inventory.WOOD, 30)
	if not structure_requests.place(BuildCosts.BARRACKS, one, 0):
		return "place was not sent"
	var builder: int = main.multiplayer.get_unique_id()
	if not await _until(func() -> bool: return _barracks_count(world, builder) >= 1, 8000):
		return "built barracks was not applied"
	_train_anchor = land
	err = await _ready_to_build(main, me, interaction.cell_center(land) + Vector2(0, 48))
	if err != "":
		return err
	inventory.add(Inventory.WOOD, SoldierStats.TRAIN_WOOD)
	if main.multiplayer.is_server():
		requests.host_train(builder, land)
	else:
		requests.request_train.rpc_id(1, land)
	if not await _until(func() -> bool: return _soldier_rows(requests).size() >= 1, 15000):
		return "soldier did not spawn"
	return ""


func _spawn_fight_mob(requests: SoldierRequests, mobs: MobSpawner) -> void:
	var soldier: Soldier = null
	for child in requests.get_children():
		if child is Soldier and child.state != Soldier.State.DYING:
			soldier = child
			break
	if soldier == null:
		return
	soldier.set_order("hold")
	soldier._hold_pos = soldier.global_position
	_fight_mob = "mob_fight_probe"
	mobs.get_node("MultiplayerSpawner").spawn({
		"name": _fight_mob,
		"type": MobCatalog.SLIME,
		"pos": soldier.global_position + Vector2(6, 0),
		"seed": 11,
	})


func _fight_hp(mobs: MobSpawner) -> Dictionary:
	var named := mobs.get_node_or_null(_fight_mob) as Mob if _fight_mob != "" else null
	if named != null:
		return {"hp": named.hp, "start": MobCatalog.stat(MobCatalog.SLIME, "hp")}
	var best := -1
	for child in mobs.mobs():
		if child is Mob:
			best = child.hp if best < 0 else mini(best, child.hp)
	return {"hp": best, "start": MobCatalog.stat(MobCatalog.SLIME, "hp")}


func _write_fight(out: String, main, world, me: Node2D, requests: SoldierRequests, mobs: MobSpawner) -> void:
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
	var fight := _fight_hp(mobs)
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
		"fight_mob_hp": fight["hp"],
		"fight_mob_start_hp": MobCatalog.stat(MobCatalog.SLIME, "hp"),
		"mob_count": mobs.mobs().size(),
		"errors": _errors.snapshot(),
	}))
	file.close()
	DirAccess.rename_absolute(out + ".tmp", out)