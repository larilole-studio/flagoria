extends "res://tests/helpers/probe_base.gd"
## Raid wall damage and the disabled setting over real peers (#529).
## The host waits for the normal raid clock and mob physics to run.
##   -- --port=N --out=PATH --role=host --seed=11 --raids=on
##   -- --port=N --out=PATH --role=join --seed=11 --raids=off

var _raids := false
var _armed := false
var _phase := 0
var _hp := -1
var _cell := Vector2i.ZERO
var _assigned := false
var _note := ""


func _run() -> void:
	var role := option("--role", "join")
	var seed_value := option("--seed", "11").to_int()
	_raids = option("--raids") == "on"
	var main = await open_game(role == "host")
	if main == null:
		printerr("raid_probe: needs --port, --out and the main scene")
		quit(1)
		return
	main.get_node("CanvasLayer2/MainMenu").hide()
	if role == "host":
		var settings = root.get_node("GameSettings")
		settings.set_mob_rate(1.0, false)
		settings.set_raids_enabled(false, false)
		settings.raid_interval_s = 0.25  # Short fixture interval below the menu minimum.
		settings.set_raid_group(8, false)
		settings.set_raid_radius_cells(96, false)
		if host_game(main, _params(seed_value)) != OK:
			printerr("raid_probe: could not host")
			quit(1)
			return
		host_listening()
	else:
		await join_game(main)
	var deadline := Time.get_ticks_msec() + 45000
	while game_active(main, deadline):
		if role == "host" and not _armed and FileAccess.file_exists(probe_out + ".go"):
			_armed = true
			if await wait_for_peers(main, 1, 5000):
				await _arm(main)
			_phase = 1
		if snapshot_due(main):
			_write(main)
		await process_frame
	finish(main, func() -> void: _write(main))


func _params(seed_value: int) -> MapGenParams:
	var params := MapGenParams.make_defaults()
	params.biome_frequency = 0.0
	params.altitude_seed = seed_value
	params.moisture_seed = seed_value
	params.temperature_seed = seed_value
	params.items_seed = seed_value
	params.biome_seed = seed_value
	return params


func _arm(main) -> void:
	var world = main.get_node("World/worldMap")
	var cities: Cities = main.get_node("World/Cities")
	var settings = root.get_node("GameSettings")
	var requests: StructureRequests = main.get_node("World/StructureRequests")
	var player: Node2D = main.get_node("World/1")
	var inventory: Inventory = main.get_node("Inventory")
	var anchor := Vector2i(22, -15)
	var origin := Vector2i(19, -19)
	_cell = Vector2i(22, -13)
	world.generate_chunk(world.map_to_local(anchor))
	var spawn := player.global_position
	player.global_position = world.to_global(world.map_to_local(anchor + Vector2i(0, 2)))
	inventory.add(Inventory.WOOD, 10)
	var placed := requests.place(BuildCosts.TOWER, [anchor])
	player.global_position = spawn
	var ring: Array[Vector2i] = []
	for offset in 7:
		ring.append(origin + Vector2i(offset, 0))
		ring.append(origin + Vector2i(offset, 6))
		if offset > 0 and offset < 6:
			ring.append(origin + Vector2i(0, offset))
			ring.append(origin + Vector2i(6, offset))
	if not placed or not world.place_wall_cells(ring):
		_note = "could not place seed-11 city"
		return
	cities.rebuild()
	for peer_id in main.multiplayer.get_peers():
		requests.sync_to_peer(peer_id)
	var mobs: MobSpawner = main.get_node("World/Mobs")
	mobs.set_physics_process(false)
	mobs.clear_mobs()
	var mob := (
		(
			mobs
			. spawner
			. spawn(
				{
					"name": "raid_fixture",
					"type": MobCatalog.SLIME,
					"seed": 11,
					"pos": world.map_to_local(Vector2i(22, -12)),
				}
			)
		)
		as Mob
	)
	if mob == null:
		_note = "could not spawn raider"
		return
	settings.set_raids_enabled(_raids, false)
	var deadline := Time.get_ticks_msec() + 5000
	var off_done := Engine.get_physics_frames() + 30  # Half a second at 60 Hz.
	var key := WorldSave.cell_key(_cell)
	while Time.get_ticks_msec() < deadline:
		_hp = int(_walls(main).get(key, -1))
		_assigned = _assigned or (mob.state != Mob.State.CHASE and mob.pinned())
		if (
			(_raids and _hp == 2 and _assigned)
			or (not _raids and Engine.get_physics_frames() >= off_done)
		):
			settings.set_raids_enabled(false, false)
			return
		await process_frame
	_note = "raid clock or strike did not reach the expected state"


func _walls(main) -> Dictionary:
	var walls := {}
	var world = main.get_node_or_null("World/worldMap")
	if world != null:
		for chunk: Dictionary in StructureSaves.to_changes(world).values():
			for key: String in chunk:
				if chunk[key].has("wall"):
					walls[key] = chunk[key].get("hp", 3)
	return walls


func _names_ready(main) -> bool:
	var me := ""
	if main.multiplayer != null:
		me = str(main.multiplayer.get_unique_id())
	return main.get_node_or_null("World/" + me) != null and main.world_params != null


func _write(main) -> void:
	var data := {
		"ready": _names_ready(main),
		"phase": _phase,
		"hp": _hp,
		"cell": WorldSave.cell_key(_cell),
		"assigned": _assigned,
		"walls": _walls(main),
		"note": _note,
		"errors": _errors.snapshot(),
	}
	write_result(data)
