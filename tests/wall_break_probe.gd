extends "res://tests/helpers/probe_base.gd"
## Two-player wall damage probe (#35).
## Host: --host --save --port --out. Client: --port --out [--phase=...].

var _place_error := ""
var _target := Vector2i(1 << 20, 0)
var _phase_done := ""
var _saw_hp2 := false
var _break_done := false


func _run() -> void:
	var phase := option("--phase", "work")
	var host := has_option("--host")
	var save := option("--save")
	var main = await open_game(host)
	if main == null:
		printerr("wall_break_probe: needs --port, --out, and the main scene")
		quit(1)
		return
	main.get_node("CanvasLayer2/MainMenu").hide()
	if host:
		var error := host_saved_game(main, save)
		if error != "":
			printerr("wall_break_probe: could not host %s: %s" % [save, error])
			quit(1)
			return
		park_mobs(main)
		host_listening()
	else:
		await join_game(main)
	var world = main.get_node("World/worldMap")
	var work := "idle"
	var deadline := Time.get_ticks_msec() + 90000
	while game_active(main, deadline):
		if main.multiplayer == null:
			break
		var me: Node2D = local_player(main)
		var ready := main.world_params != null and me != null
		if not host and work == "idle" and ready and phase == "work":
			work = "busy"
			_place_error = await _prepare_break(main, world, me)
			if _place_error == "":
				_phase_done = await _break_sequence(main, world, me)
				_break_done = _phase_done == ""
			work = "done"
		if snapshot_due(main):
			_write(main, world, me)
		await process_frame
	finish(main, func() -> void: _write(main, world, local_player(main)))


func _prepare_break(main, world, me: Node2D) -> String:
	var inventory: Inventory = main.get_node("Inventory")
	var requests = main.get_node("World/StructureRequests")
	var interaction: Interaction = main.get_node("World/Interaction")
	inventory.add(Inventory.WOOD, 4)
	if not await wait_for_state(func() -> bool: return _has_castle(world), 15000):
		return "no castle on the map"
	world.generate_chunk(world.map_to_local(world.resolve_player_spawn()))
	var spot: Vector2i = castle_touch(world)
	if spot.x == 1 << 20:
		spot = _spawn_touch(world)
	if spot.x == 1 << 20:
		return "no wall spot"
	_target = spot
	me.global_position = interaction.cell_center(spot) + Vector2(0, 48)
	var peer_id := str(main.multiplayer.get_unique_id())
	if not await wait_for_state(
		func() -> bool: return host_sees_position(peer_id, me.global_position), 8000
	):
		return "host did not ack position"
	var one: Array[Vector2i] = [spot]
	if not requests.place(BuildCosts.WALL_BLOCK, one):
		return "wall place not sent"
	if not await wait_for_state(func() -> bool: return world.has_wall(spot), 8000):
		return "wall not applied"
	return ""


func _break_sequence(main, world, me: Node2D) -> String:
	var spot: Vector2i = _target
	var interaction: Interaction = main.get_node("World/Interaction")
	me.global_position = interaction.cell_center(spot + Vector2i(0, 1))
	var peer_id := str(main.multiplayer.get_unique_id())
	if not await wait_for_state(
		func() -> bool: return host_sees_position(peer_id, me.global_position), 5000
	):
		return "could not stand south"
	if not await _swing(me, "Down", PI / 2.0) or _wall_hp(world, spot) != 3:
		return "away swing did not finish with hp 3"
	for hp in [2, 1, -1]:
		if not await _swing(me, "Up", -PI / 2.0):
			return "swing did not finish"
		if not await wait_for_state(func() -> bool: return _wall_hp(world, spot) == hp, 5000):
			return "wall hp want %d got %d" % [hp, _wall_hp(world, spot)]
		if hp == 2:
			_saw_hp2 = true
	return ""


func _swing(me: Node2D, direction: String, angle: float) -> bool:
	me.attack_animation.rpc(direction, angle)
	return await wait_for_state(func() -> bool: return not me.isAttacking, 3000)


func _wall_hp(world, cell: Vector2i) -> int:
	if not world.has_wall(cell):
		return -1
	var entry: Dictionary = StructureSaves.to_changes(world).get(WorldSave.chunk_key(cell), {}).get(
		WorldSave.cell_key(cell), {}
	)
	return int(entry.get("hp", 3))


func _spawn_touch(world) -> Vector2i:
	var placer := ConstructionPlacer.new(world)
	var spawn: Vector2i = world.resolve_player_spawn()
	for r in range(0, 32):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if maxi(absi(dx), absi(dy)) != r:
					continue
				var cell := spawn + Vector2i(dx, dy)
				if world.has_wall(cell):
					continue
				if world.get_cell_source_id(0, cell) == -1 or not world.predicted_clear(cell):
					continue
				var one: Array[Vector2i] = [cell]
				if placer.can_place_geometry(BuildCosts.WALL_BLOCK, one).is_empty():
					return cell
	return Vector2i(1 << 20, 0)


func _has_castle(world) -> bool:
	for id in world.placed_structures():
		if str(world.placed_structures()[id]["name"]) == "castle":
			return true
	return false


func _write(main, world, me: Node2D) -> void:
	var walls := {}
	if main != null and main.world_params != null:
		for chunk: Dictionary in StructureSaves.to_changes(world).values():
			for key: String in chunk:
				var entry: Dictionary = chunk[key]
				if not entry.has("wall"):
					continue
				var cell: Vector2i = WorldSave.parse_cell(key)
				var hp := int(entry.get("hp", 3))
				var atlas: Vector2i = world.get_cell_atlas_coords(1, cell)
				walls[key] = [hp, atlas.x, atlas.y]
				_saw_hp2 = _saw_hp2 or hp == 2
	write_result(
		{
			"id":
			(
				str(main.multiplayer.get_unique_id())
				if main != null and main.multiplayer != null
				else ""
			),
			"ready": main != null and main.world_params != null and me != null,
			"place_error": _place_error,
			"phase_done": _phase_done,
			"saw_hp2": _saw_hp2,
			"target": WorldSave.cell_key(_target),
			"break_done": _break_done,
			"walls": walls,
			"peers": peer_positions(main),
			"errors": _errors.snapshot(),
		}
	)
