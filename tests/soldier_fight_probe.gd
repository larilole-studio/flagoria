extends "res://tests/soldier_sync_probe.gd"
## Host spawns a slime in attack range after a soldier trains (#554).

var _fight_mob := ""
var _fight_started := false


func _run() -> void:
	var save := option("--save")
	var host := has_option("--host")
	var mode := option("--mode", "watch")
	if host and save == "":
		printerr("soldier_fight_probe: needs --port, --out, --save with --host, and the main scene")
		quit(1)
		return
	var main = await open_game(host)
	if main == null:
		printerr("soldier_fight_probe: needs --port, --out, --save with --host, and the main scene")
		quit(1)
		return
	main.get_node("CanvasLayer2/MainMenu").hide()
	if host:
		var error := host_saved_game(main, save)
		if error != "":
			printerr("soldier_fight_probe: could not host %s: %s" % [save, error])
			quit(1)
			return
		host_listening()
	else:
		await join_game(main)
	var world = main.get_node("World/worldMap")
	var requests: SoldierRequests = main.get_node("World/Soldiers")
	var mobs: MobSpawner = main.get_node("World/Mobs")
	var phase := "idle"
	var me: Node2D = null
	var deadline := Time.get_ticks_msec() + 90000
	while game_active(main, deadline):
		if main.multiplayer == null:
			break
		me = main.get_node_or_null("World/" + str(main.multiplayer.get_unique_id())) as Node2D
		var ready := main.world_params != null and me != null
		if host and ready and requests.pending_job_count() > 0:
			requests.advance(Tuning.value(&"soldiers.train_seconds"))
		if not host and mode == "place" and phase == "idle" and ready:
			phase = "working"
			_place_error = await _do_place(main, world, me, requests)
			phase = "done"
		if host and ready and not _fight_started and _soldier_rows(requests).size() > 0:
			_fight_started = true
			_spawn_fight_mob(requests, mobs)
		if snapshot_due(main):
			_write_fight(main, world, me, requests, mobs)
		await process_frame
	finish(main, func() -> void: _write_fight(main, world, local_player(main), requests, mobs))


func _do_place(main, world, me: Node2D, requests: SoldierRequests) -> String:
	var interaction: Interaction = main.get_node("World/Interaction")
	var structure_requests = main.get_node("World/StructureRequests")
	var inventory: Inventory = main.get_node("Inventory")
	var land: Variant = _search(
		world, func(cell: Vector2i) -> bool: return _barracks_ok(world, cell, 0)
	)
	if land == null:
		return "no clear barracks anchor"
	var err := await _ready_to_build(main, me, interaction.cell_center(land) + Vector2(0, 48))
	if err != "":
		return err
	var one: Array[Vector2i] = [land]
	inventory.add(Inventory.WOOD, 20)
	inventory.add(Inventory.STONE, 10)
	if not structure_requests.place(BuildCosts.BARRACKS, one, 0):
		return "place was not sent"
	var builder: int = main.multiplayer.get_unique_id()
	if not await _until(func() -> bool: return _barracks_count(world, builder) >= 1, 8000):
		return "built barracks was not applied"
	err = await _ready_to_build(main, me, interaction.cell_center(land) + Vector2(0, 48))
	if err != "":
		return err
	inventory.add(Inventory.WOOD, 8)
	inventory.add(Inventory.STONE, 4)
	requests.train(land)
	if not await _until(func() -> bool: return _soldier_rows(requests).size() >= 1, 15000):
		return "soldier did not spawn"
	return ""


func _spawn_fight_mob(requests: SoldierRequests, mobs: MobSpawner) -> void:
	# Isolate the duel from hostile castles and players in the live seed.
	# Freeze mob movement after spawning so a late peer can see the damage.
	var soldier: Soldier = requests.soldiers()[0]
	var arena := Vector2(4096, 4096)
	soldier.position = arena
	soldier.hp = 100
	soldier.set_order("hold")
	_fight_mob = "mob_fight_probe"
	var spawner: MultiplayerSpawner = mobs.get_node("MultiplayerSpawner")
	var slime := (
		(
			spawner
			. spawn(
				{
					"name": _fight_mob,
					"type": MobCatalog.SLIME,
					"pos": arena + Vector2(6, 0),
					"seed": 11,
				}
			)
		)
		as Mob
	)
	if slime != null:
		slime.set_physics_process(false)


func _fight_hp(mobs: MobSpawner) -> Dictionary:
	var named := mobs.get_node_or_null(_fight_mob) as Mob if _fight_mob != "" else null
	if named != null:
		return {"hp": named.hp, "start": MobCatalog.stat(MobCatalog.SLIME, "hp")}
	var best := -1
	for child in mobs.mobs():
		if child is Mob:
			best = child.hp if best < 0 else mini(best, child.hp)
	return {"hp": best, "start": MobCatalog.stat(MobCatalog.SLIME, "hp")}


func _write_fight(main, world, me: Node2D, requests: SoldierRequests, mobs: MobSpawner) -> void:
	if probe_out == "":
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
	write_result(
		{
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
		}
	)
