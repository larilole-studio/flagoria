extends "res://tests/helpers/test_helpers.gd"
## Raid target, clock and palisade damage (#529). No ENet.
## Time cost: about 1 s inside tools/verify.sh. A standalone run is about 4 s.


const SEED := 11


func _test_raid_target() -> int:
	## Nearer city, radius cutoff, an owned tower when no city is in range,
	## neutral and mob owners ignored, raids off by default, the interval
	## assigns at most raid_group, a palisade ring loses hp, and a castle
	## auto-wall is not passed to host_damage_wall.
	print("-- test_raid_target")
	var fail := 0
	var game = root.get_node("GameSettings")
	var saved := {
		"path": game.save_path,
		"rate": game.mob_rate,
		"on": game.raids_enabled,
		"interval": game.raid_interval_s,
		"group": game.raid_group,
		"radius": game.raid_radius_cells,
	}
	fail += _settings(game)
	var scene = load("res://flagoria_main.tscn").instantiate()
	root.add_child(scene)
	var world = scene.get_node("World/worldMap")
	var cities: Cities = scene.get_node("World/Cities")
	var director: RaidDirector = scene.get_node("World/RaidDirector")
	var params := _spawn_params(SEED, 0.0)
	params.ensure_seeds()
	scene.world_params = params
	world.apply_map_params(params)
	for y in range(-2, 3):
		for x in range(-2, 3):
			world.generate_chunk(world.map_to_local(Vector2i(x * 32, y * 32)))
	var tower: Structure = StructurePlacer.load_named("tower_wood")
	# Fixed seed-11 fixtures: two cities, then three isolated towers.
	var near := _place_ring(world, cities, tower, Vector2i(23, -33))
	var far := _place_ring(world, cities, tower, Vector2i(62, 49))
	var owned: int = world.place_structure(tower, Vector2i(-47, -51), 1)
	var neutral: int = world.place_structure(tower, Vector2i(-33, -39), StructurePlacer.OWNER_NEUTRAL)
	var mobs: int = world.place_structure(tower, Vector2i(-32, -36), StructurePlacer.OWNER_MOBS)
	if near <= 0 or far <= 0 or owned <= 0 or neutral <= 0 or mobs <= 0:
		printerr("FAIL raid_target: could not place seed-11 fixtures")
		fail += 1
	else:
		fail += _targets(game, director, near, far, owned)
		fail += _clock_and_hp(game, director, world, near)
		fail += _auto_wall(world)
	scene.queue_free()
	_restore(game, saved)
	if fail == 0:
		print("PASS test_raid_target")
	return fail


func _settings(game) -> int:
	var path := "user://test_raid_settings.cfg"
	var abs := ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(abs):
		DirAccess.remove_absolute(abs)
	game.save_path = path
	game.load_from_disk()
	var fail := 0
	if game.raids_enabled:
		printerr("FAIL raid_target: raids enabled in fresh settings")
		fail += 1
	for row in [[-100, [15.0, 1, 16]], [1000, [180.0, 8, 96]]]:
		game.set_raid_interval_s(row[0], false)
		game.set_raid_group(row[0], false)
		game.set_raid_radius_cells(row[0], false)
		if [game.raid_interval_s, game.raid_group, game.raid_radius_cells] != row[1]:
			printerr("FAIL raid_target: out-of-range settings did not clamp for %d" % row[0])
			fail += 1
	game.set_raids_enabled(true, false)
	game.set_raid_interval_s(30, false)
	game.set_raid_group(4, false)
	game.set_raid_radius_cells(20, false)
	game.save_to_disk()
	game.raids_enabled = false
	game.set_raid_interval_s(45, false)
	game.set_raid_group(3, false)
	game.set_raid_radius_cells(96, false)
	game.load_from_disk()
	if not game.raids_enabled or game.raid_interval_s != 30.0 or game.raid_group != 4 \
			or game.raid_radius_cells != 20:
		printerr("FAIL raid_target: reload on=%s interval=%s group=%s radius=%s" % [
			game.raids_enabled, game.raid_interval_s, game.raid_group, game.raid_radius_cells])
		fail += 1
	game.set_raids_enabled(false, false)
	return fail


func _targets(game, director: RaidDirector, near: int, far: int, owned: int) -> int:
	var fail := 0
	var origin := Vector2i(-30, -40)
	var cases := [
		[origin, 17, {"id": owned, "cell": Vector2i(-47, -52)}],
		[origin, 16, {}],
		[origin, 95, {"id": near, "cell": Vector2i(26, -30)}],
		[Vector2i(65, 52), 82, {"id": far, "cell": Vector2i(65, 52)}],
	]
	for row in cases:
		game.set_raid_radius_cells(row[1], false)
		var target := director.choose_target(row[0])
		var repeated := director.choose_target(row[0])
		if target != row[2] or repeated != row[2]:
			printerr("FAIL raid_target: radius %d from %s got %s then %s, want %s"
					% [row[1], row[0], target, repeated, row[2]])
			fail += 1
	return fail


func _clock_and_hp(game, director: RaidDirector, world, near: int) -> int:
	var fail := 0
	var flag := Vector2i(26, -30)
	var wall := Vector2i(26, -33)
	var stand := Vector2i(26, -34)
	var before := StructureSaves.to_changes(world)
	var mobs: Array[Mob] = []
	for i in 6:
		mobs.append(_mob(world, "mob_%d" % i, stand))
	game.set_raids_enabled(false, false)
	game.set_raid_group(3, false)
	game.set_raid_interval_s(45, false)
	game.set_raid_radius_cells(96, false)
	mobs[0].assign_raid(flag, near)
	director.advance(90.0)
	if mobs[0].pinned() or StructureSaves.to_changes(world) != before:
		printerr("FAIL raid_target: disabling raids did not clear the assignment and leave walls intact")
		fail += 1
	game.set_raids_enabled(true, false)
	director.advance(44.0)
	if not _assigned_names(mobs).is_empty():
		printerr("FAIL raid_target: mobs assigned before the interval elapsed")
		fail += 1
	director.advance(1.0)
	var names := _assigned_names(mobs)
	if names.size() != 3:
		printerr("FAIL raid_target: group assigned %s" % [names])
		fail += 1
	for mob in mobs:
		mob.clear_raid()
	var replay := RaidDirector.new()
	director.get_parent().add_child(replay)
	replay.advance(45.0)
	replay.free()
	if _assigned_names(mobs) != names:
		printerr("FAIL raid_target: retick assigned %s want %s" % [_assigned_names(mobs), names])
		fail += 1
	for mob in mobs:
		mob.clear_raid()
	var striker := mobs[0]
	striker.global_position = world.to_global(world.map_to_local(stand))
	striker.assign_raid(flag, near)
	striker.think(1.0)
	var chunk := WorldSave.chunk_key(wall)
	var cell := WorldSave.cell_key(wall)
	var after := StructureSaves.to_changes(world)
	var hit: Dictionary = after.get(chunk, {}).get(cell, {})
	if hit.get("hp") != 2:
		printerr("FAIL raid_target: palisade took no damage")
		return fail + 1
	after[chunk][cell] = before[chunk][cell]
	if after != before:
		printerr("FAIL raid_target: strike also changed other structures")
		fail += 1
	return fail


func _auto_wall(world) -> int:
	if not world.place_start_castle(1):
		printerr("FAIL raid_target: no starting castle")
		return 1
	var wall := Vector2i(-10, -33)
	var stand := Vector2i(-11, -33)
	var before: Vector2i = world.predict_cell(wall)[1]
	if world.has_wall(wall) or not TileCatalog.TILES.keys().any(func(tile: String) -> bool:
			return tile.begins_with("WALL_") and TileCatalog.TILES[tile]["atlas"] == before):
		printerr("FAIL raid_target: seed-11 stone wall missing")
		return 1
	var mob := _mob(world, "mob_stone", stand)
	mob.assign_raid(Vector2i(-9, -33), -1)
	for _i in 6:
		mob.think(0.25)
	if world.predict_cell(wall)[1] != before or mob.global_position != world.to_global(world.map_to_local(stand)):
		printerr("FAIL raid_target: castle wall changed or the mob moved through it")
		return 1
	return 0


func _place_ring(world, cities: Cities, tower: Structure, origin: Vector2i) -> int:
	var id: int = world.place_structure(tower, origin + Vector2i(3, 4), 1)
	var ring: Array[Vector2i] = []
	for offset in 7:
		ring.append(origin + Vector2i(offset, 0))
		ring.append(origin + Vector2i(offset, 6))
		if offset > 0 and offset < 6:
			ring.append(origin + Vector2i(0, offset))
			ring.append(origin + Vector2i(6, offset))
	if id <= 0 or not world.place_wall_cells(ring):
		return -1
	cities.rebuild()
	return id if cities.cities.has(id) else -1


func _mob(world, mob_name: String, cell: Vector2i) -> Mob:
	var mob: Mob = load("res://Mobs/mob.tscn").instantiate()
	mob.name = mob_name
	var at: Vector2 = world.to_global(world.map_to_local(cell))
	mob.setup(MobCatalog.SLIME, at, 1)
	world.get_node("../Mobs").add_child(mob)
	mob.global_position = at
	mob.state = Mob.State.IDLE
	return mob


func _assigned_names(mobs: Array[Mob]) -> Array:
	var names := []
	for mob in mobs:
		if mob.pinned():
			names.append(str(mob.name))
	names.sort()
	return names


func _restore(game, saved: Dictionary) -> void:
	game.save_path = saved["path"]
	game.set_mob_rate(saved["rate"], false)
	game.set_raid_interval_s(saved["interval"], false)
	game.set_raid_group(int(saved["group"]), false)
	game.set_raid_radius_cells(int(saved["radius"]), false)
	game.set_raids_enabled(bool(saved["on"]), false)
	var abs := ProjectSettings.globalize_path("user://test_raid_settings.cfg")
	if FileAccess.file_exists(abs):
		DirAccess.remove_absolute(abs)
