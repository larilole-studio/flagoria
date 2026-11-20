extends "res://tests/helpers/probe_base.gd"
## One peer of a mob-band session. The host sets the ambient delay to 0 and
## calls run_ambient_tick once the test drops a .tick file.
##   -- --port=N --out=PATH --role=host --seed=11
##   -- --port=N --out=PATH --role=join


var _ticking := false
var _ticked := false
var _pinned := ""
var _released := ""
var _spawned: Array = []
var _despawned: Array = []
var _players: Array = []
var _note := ""


func _run() -> void:
	var role := option("--role", "join")
	var seed_value := option("--seed", "11").to_int()
	var main = await open_game(role == "host")
	if main == null:
		printerr("mob_band_probe: needs --port, --out and the main scene")
		quit(1)
		return
	main.get_node("CanvasLayer2/MainMenu").hide()
	if role == "host":
		root.get_node("GameSettings").set_mob_rate(1.0, false)
		if host_game(main, _params(seed_value)) != OK:
			printerr("mob_band_probe: could not host")
			quit(1)
			return
		host_listening()
	else:
		await join_game(main)
	var deadline := Time.get_ticks_msec() + 45000
	while game_active(main, deadline):
		if role == "host" and not _ticked and not _ticking and FileAccess.file_exists(probe_out + ".tick"):
			_ticking = true
			_arm(main)
			await process_frame
			_ticked = true
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
	var mobs_node: MobSpawner = main.get_node("World/Mobs")
	var players: Array[Vector2i] = []
	for child in main.get_node("World").get_children():
		if child is CharacterBody2D and Mob.is_alive(child):
			players.append(world.local_to_map(child.position))
	var mobs: Array = []
	for child in mobs_node.get_children():
		if child is Mob and not child.is_queued_for_deletion():
			mobs.append(child)
	if mobs.size() < 2 or players.is_empty():
		_note = "need two mobs and a player, have %d" % mobs.size()
		return
	var pinned: Mob = mobs[0]
	var released: Mob = mobs[1]
	pinned.position = world.map_to_local(_far(players, 0))
	pinned.state = Mob.State.CHASE
	released.position = world.map_to_local(_far(players, 1))
	released.state = Mob.State.IDLE
	_pinned = str(pinned.name)
	_released = str(released.name)
	for at in players:
		_players.append([at.x, at.y])
	mobs_node.ambient_delay_ms = 0
	var plan: Dictionary = mobs_node.run_ambient_tick()
	for item in plan["spawn"]:
		var cell: Vector2i = item["cell"]
		_spawned.append({"name": str(item["name"]), "type": str(item["type"]), "x": cell.x, "y": cell.y})
	for mob_name in plan["despawn"]:
		_despawned.append(str(mob_name))


func _far(players: Array[Vector2i], slot: int) -> Vector2i:
	var origin := players[0]
	var offsets: Array[Vector2i] = [
		Vector2i(80, 0), Vector2i(-80, 0), Vector2i(0, 80), Vector2i(0, -80),
		Vector2i(80, 80), Vector2i(-80, 80),
	]
	for i in offsets.size():
		var cell := origin + offsets[(slot + i) % offsets.size()]
		var ok := true
		for at in players:
			if maxi(absi(cell.x - at.x), absi(cell.y - at.y)) <= MobSpawner.DESPAWN_RADIUS:
				ok = false
				break
		if ok:
			return cell
	return origin + Vector2i(96, 0 if slot == 0 else 96)


func _names(main) -> Array:
	var names: Array = []
	var mobs_node: Node = main.get_node_or_null("World/Mobs")
	if mobs_node == null:
		return names
	for child in mobs_node.get_children():
		if child is Mob and not child.is_queued_for_deletion():
			names.append(str(child.name))
	names.sort()
	return names


func _write(main) -> void:
	var me := ""
	if main.multiplayer != null:
		me = str(main.multiplayer.get_unique_id())
	var player: Node = main.get_node_or_null("World/" + me)
	var data := {
		"ready": player != null and main.world_params != null and not _names(main).is_empty(),
		"names": _names(main),
		"tick": 1 if _ticked else 0,
		"pinned": _pinned,
		"released": _released,
		"spawned": _spawned,
		"despawned": _despawned,
		"players": _players,
		"rate": root.get_node("GameSettings").mob_rate,
		"note": _note,
		"errors": _errors.snapshot(),
	}
	write_result(data)
