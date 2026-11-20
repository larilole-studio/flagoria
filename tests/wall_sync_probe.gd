extends "res://tests/helpers/probe_base.gd"
## One peer of a wall and city sync session (#498).
## Host: --host --save --port --out --mode. Client: --port --out --mode [--shot].


var _refused_wood := -1
var _place_error := ""
var _shot := false
var _gap := Vector2i(1 << 20, 0)
## Cell the host erased after the open request. The sentinel means it has not.
var _erased := Vector2i(1 << 20, 0)


func _run() -> void:
	var mode := option("--mode", "watch")
	var shot := option("--shot")
	var host := has_option("--host")
	var save := option("--save")
	var main = await open_game(host)
	if main == null:
		printerr("wall_sync_probe: needs --port, --out, and the main scene")
		quit(1)
		return
	main.get_node("CanvasLayer2/MainMenu").hide()
	if mode == "wall":
		install_round_trip(main)
	if host:
		var error := host_saved_game(main, save)
		if error != "":
			printerr("wall_sync_probe: could not host %s: %s" % [save, error])
			quit(1)
			return
		park_mobs(main)
		host_listening()
	else:
		await join_game(main)
	var world = main.get_node("World/worldMap")
	var phase := "idle"
	var opened := false
	var deadline := Time.get_ticks_msec() + 90000
	while game_active(main, deadline):
		if main.multiplayer == null:
			break
		var me: Node2D = local_player(main)
		var ready := main.world_params != null and me != null
		if not host and mode in ["wall", "city", "drive"] and phase == "idle" and ready:
			phase = "working"
			_place_error = await _do_place(main, world, me, mode)
			phase = "done"
		# The open file appears only once it has both coordinates (atomic rename).
		# An empty file is ignored: latching on create-before-write missed the
		# erase and the test then sat on its 15 s bound (one run, 22.9 s).
		if host and mode == "city" and not opened and FileAccess.file_exists(probe_out + ".open"):
			var text := FileAccess.get_file_as_string(probe_out + ".open").strip_edges()
			var bits := text.replace(",", " ").split(" ", false)
			if bits.size() >= 2 and bits[0].is_valid_int() and bits[1].is_valid_int():
				opened = true
				var cell := Vector2i(int(bits[0]), int(bits[1]))
				if not main.get_node("World/StructureRequests").host_erase_wall(cell):
					_place_error = "could not erase %s" % cell
				else:
					_erased = cell
		if not host and mode == "drive" and phase == "done" and not _shot and _tower_in_cities(main, world):
			if shot != "" and DisplayServer.get_name() != "headless":
				await _frames(20)
				await RenderingServer.frame_post_draw
				_shot = root.get_texture().get_image().save_png(shot) == OK
			else:
				_shot = true
		if snapshot_due(main):
			_write(main, world, me)
		await process_frame
	finish(main, func() -> void: _write(main, world, local_player(main)))


func _peer_id(main) -> String:
	if main == null or main.multiplayer == null:
		return ""
	return str(main.multiplayer.get_unique_id())


func _do_place(main, world, me: Node2D, mode: String) -> String:
	var inventory: Inventory = main.get_node("Inventory")
	var requests = main.get_node("World/StructureRequests")
	var interaction: Interaction = main.get_node("World/Interaction")
	if mode == "wall":
		return await _place_one_wall(main, world, me, inventory, requests, interaction)
	return await _place_city(main, world, me, inventory, requests, interaction, mode)


func _place_one_wall(main, world, me: Node2D, inventory: Inventory, requests, interaction: Interaction) -> String:
	inventory.add(Inventory.WOOD, 4)
	var water: Vector2i = _find_water(world)
	if water.x == 1 << 20:
		return "no water cell"
	var error := await _wait_host_position(main, me, interaction.cell_center(water), 5000)
	if error != "":
		return error
	var before := inventory.count_of(Inventory.WOOD)
	var bad: Array[Vector2i] = [water]
	if not requests.place(BuildCosts.WALL_BLOCK, bad):
		return "water request was not sent"
	if not await wait_for_round_trip(main):
		return "host did not acknowledge the water request"
	_refused_wood = inventory.count_of(Inventory.WOOD)
	if _refused_wood != before:
		return "refused request spent wood (%d -> %d)" % [before, _refused_wood]
	var spot: Vector2i = castle_touch(world)
	if spot.x == 1 << 20:
		return "no clear cell touching the castle"
	error = await _wait_host_position(main, me, interaction.cell_center(spot) + Vector2(0, 48), 5000)
	if error != "":
		return error
	var one: Array[Vector2i] = [spot]
	if not requests.place(BuildCosts.WALL_BLOCK, one):
		return "wall place was not sent"
	var until := Time.get_ticks_msec() + 5000
	while Time.get_ticks_msec() < until and not world.has_wall(spot):
		await process_frame
	if not world.has_wall(spot):
		return "wall was not applied"
	return ""


func _place_city(main, world, me: Node2D, inventory: Inventory, requests, interaction: Interaction, mode: String) -> String:
	## Map seed is fixed by the test (seed 11). Each place waits until the host
	## has this body, then until that place is on the map. No wall-clock sleep:
	## a short sleep raced the position sync and a rejected place then burned
	## the 8 s apply bound.
	inventory.add(Inventory.WOOD, 50)
	var spot: Dictionary = _ring_spot(world)
	if spot.is_empty():
		return "no 5x5 clear ring"
	var anchor: Vector2i = spot["anchor"]
	_gap = spot["gap"]
	var err := await _ready_to_build(main, me, interaction.cell_center(anchor) + Vector2(0, 48), mode)
	if err != "":
		return err
	var tower_cell: Array[Vector2i] = [anchor]
	if not requests.place(BuildCosts.TOWER, tower_cell):
		return "tower place was not sent"
	if not await wait_for_state(func() -> bool: return _tower_id(world) >= 0, 8000):
		return "tower was not applied"
	var flag: Vector2i = _tower_flag(world)
	err = await _ready_to_build(main, me, interaction.cell_center(flag), mode)
	if err != "":
		return err
	for side in spot["sides"]:
		var run: Array[Vector2i] = side
		if not requests.place(BuildCosts.WALL_BLOCK, run):
			return "wall side was not sent"
		if not await wait_for_state(func() -> bool: return _cells_walled(world, run), 8000):
			return "wall side was not applied"
	if not _ring_applied(world, spot["ring"]):
		return "ring was not applied"
	return ""


func _ready_to_build(main, me: Node2D, where: Vector2, mode: String) -> String:
	## Stress peers publish positions in the host probe's status file. The live
	## drive hosts from the game itself, which does not write that file.
	if mode == "drive":
		await _drive_settle(me, where, 400)
		return ""
	return await _wait_host_position(main, me, where, 5000)


func _drive_settle(me: Node2D, where: Vector2, ms: int) -> void:
	## Bounded settle for the screenshot drive only. Stress mode does not call this.
	_pin(me, where)
	await _wait(ms)


func _wait_host_position(main, me: Node2D, where: Vector2, ms: int) -> String:
	var sync := me.get_node_or_null("MultiplayerSynchronizer")
	if sync is MultiplayerSynchronizer:
		(sync as MultiplayerSynchronizer).replication_interval = 0.0
	var peer_id := str(main.multiplayer.get_unique_id())
	var until := Time.get_ticks_msec() + ms
	while Time.get_ticks_msec() < until:
		_pin(me, where)
		if host_sees_position(peer_id, where):
			return ""
		await process_frame
	return "host did not ack the player at %s" % where


func _pin(me: Node2D, where: Vector2) -> void:
	me.global_position = where
	if me is CharacterBody2D:
		(me as CharacterBody2D).velocity = Vector2.ZERO


func _cells_walled(world, cells: Array) -> bool:
	for cell in cells:
		if not world.has_wall(cell):
			return false
	return true


func _find_water(world) -> Vector2i:
	var spawn: Vector2i = world.resolve_player_spawn()
	for r in range(0, 40):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if maxi(absi(dx), absi(dy)) != r:
					continue
				var cell := spawn + Vector2i(dx, dy)
				if world.predict_cell(cell)[0] == TileCatalog.WATER and not world.has_bridge(cell):
					return cell
	return Vector2i(1 << 20, 0)


func _ring_spot(world) -> Dictionary:
	var structure := StructurePlacer.load_named("tower_wood")
	if structure == null:
		return {}
	var spawn: Vector2i = world.resolve_player_spawn()
	for radius in range(3, 48):
		for dy in range(-radius, radius + 1):
			for dx in range(-radius, radius + 1):
				if maxi(absi(dx), absi(dy)) != radius:
					continue
				var cell := spawn + Vector2i(dx, dy)
				var found := _ring_at(world, structure, cell)
				if not found.is_empty():
					return found
	return {}


func _ring_at(world, structure: Structure, cell: Vector2i) -> Dictionary:
	if not _rect_clear(world, cell, 5):
		return {}
	var anchor: Vector2i = cell + Vector2i(2, 3)
	var one: Array[Vector2i] = [anchor]
	if not ConstructionPlacer.new(world).can_place_geometry(BuildCosts.TOWER, one).is_empty():
		return {}
	var ring := _perimeter(cell, cell + Vector2i(4, 4))
	var foot: Dictionary = StructurePlacer.footprint(structure, anchor)
	for r in ring:
		if foot.has(r) or not world.predicted_clear(r):
			return {}
	return {
		"anchor": anchor,
		"gap": cell + Vector2i(2, 0),
		"ring": ring,
		"sides": [
			_span(cell, true, 0, 0, 4),
			_span(cell, false, 4, 1, 3),
			_span(cell, true, 4, 0, 4),
			_span(cell, false, 0, 1, 3),
		],
	}


func _rect_clear(world, origin: Vector2i, size: int) -> bool:
	for y in size:
		for x in size:
			var c := origin + Vector2i(x, y)
			if not world.predicted_clear(c) or world.has_wall(c) or world._structures.has_cell(c):
				return false
	return true


func _perimeter(lo: Vector2i, hi: Vector2i) -> Array:
	var out: Array = []
	for x in range(lo.x, hi.x + 1):
		out.append(Vector2i(x, lo.y))
		out.append(Vector2i(x, hi.y))
	for y in range(lo.y + 1, hi.y):
		out.append(Vector2i(lo.x, y))
		out.append(Vector2i(hi.x, y))
	return out


func _span(origin: Vector2i, horizontal: bool, fixed: int, a: int, b: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for i in range(a, b + 1):
		out.append(origin + (Vector2i(i, fixed) if horizontal else Vector2i(fixed, i)))
	return out


func _ring_applied(world, ring: Array) -> bool:
	for cell in ring:
		if not world.has_wall(cell):
			return false
	return true


func _tower_id(world) -> int:
	var placed: Dictionary = world.placed_structures()
	for id in placed:
		if str(placed[id]["name"]) == "tower_wood":
			return int(id)
	return -1


func _tower_flag(world) -> Vector2i:
	var id := _tower_id(world)
	var towers: Dictionary = world._structures.towers()
	if towers.has(id) and not towers[id].is_empty():
		return towers[id][0]
	return Vector2i.ZERO


func _tower_in_cities(main, world) -> bool:
	var id := _tower_id(world)
	if id < 0:
		return false
	var cities = main.get_node("World/Cities")
	return cities.cities.has(id)


func _wait(ms: int) -> void:
	var until := Time.get_ticks_msec() + ms
	while Time.get_ticks_msec() < until:
		await process_frame


func _frames(n: int) -> void:
	for _i in n:
		await process_frame


func _write(main, world, me: Node2D) -> void:
	var walls: Array = []
	var autos: Array = []
	var cities: Array = []
	var tower := -1
	if main != null and main.world_params != null:
		tower = _tower_id(world)
		var cells: Array = world._walls._wall_cells.keys()
		cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
			return a.x < b.x or (a.x == b.x and a.y < b.y))
		for cell: Vector2i in cells:
			var caps: PackedStringArray = PackedStringArray(world._walls.cap_names(cell))
			walls.append([cell.x, cell.y, WallBuilder._atlas_wall_name(world._walls.piece(cell)), ",".join(caps)])
		var auto_cells: Array = world._structures.auto_cells().keys()
		auto_cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
			return a.x < b.x or (a.x == b.x and a.y < b.y))
		for cell: Vector2i in auto_cells:
			autos.append([cell.x, cell.y, WallBuilder._atlas_wall_name(world._structures.object_at(cell))])
		var node = main.get_node("World/Cities")
		var ids: Array = node.cities.keys()
		ids.sort()
		for id in ids:
			cities.append([int(id), node.cities[id]["walls"].size(), node.cities[id]["interior"].size()])
	var inventory: Inventory = main.get_node("Inventory") if main != null else null
	write_result({
		"id": _peer_id(main),
		"ready": main != null and main.world_params != null and me != null,
		"wood": inventory.count_of(Inventory.WOOD) if inventory != null else -1,
		"refused_wood": _refused_wood,
		"place_error": _place_error,
		"shot": _shot,
		"tower_id": tower,
		"gap": [_gap.x, _gap.y],
		"erased": [_erased.x, _erased.y],
		"peers": peer_positions(main),
		"walls": walls,
		"autos": autos,
		"cities": cities,
		"errors": _errors.snapshot(),
	})
