extends "res://tests/helpers/test_helpers.gd"
## Plank bridges over water.


func _test_bridge_planks() -> int:
	## build_bridge lays one straight run of planks over generated water, with
	## land joints at the ends that touch land and tips elsewhere. The planks
	## stay when the chunk is drawn again, predict_cell sees them, they are no
	## mob home and grow no plants, the hero walks across them while plain
	## water still blocks, and a new map clears them. Land, bent runs and
	## cells that already have planks are refused.
	print("-- test_bridge_planks")
	var fail := 0
	var scene = load("res://flagoria_main.tscn").instantiate()
	root.add_child(scene)
	var world = scene.get_node("World/worldMap")
	# Seed 42 has five water cells between two shores here.
	var run_start := Vector2i(-13, 10)
	var run_end := Vector2i(-9, 10)
	var run_len := 5
	var params := _spawn_params(42, 0.0)
	world.apply_map_params(params)
	world.generate_chunk(Vector2.ZERO)
	if world.build_bridge(run_start - Vector2i.RIGHT, run_end) or world.build_bridge(run_start, run_end + Vector2i.DOWN):
		printerr("FAIL bridge_planks: a run onto land or a bent run was accepted")
		fail += 1
	if not world.build_bridge(run_end, run_start) or world.build_bridge(run_start, run_start):
		printerr("FAIL bridge_planks: build_bridge %s..%s did not build exactly once" % [run_start, run_end])
		fail += 1
	world.generate_chunk(Vector2(0, 0))
	var pieces := [Vector2i(10, 15), Vector2i(8, 15), Vector2i(8, 15), Vector2i(8, 15), Vector2i(11, 15)]
	for i in run_len:
		var c := run_start + Vector2i(i, 0)
		if world.get_cell_atlas_coords(0, c) != pieces[i] or world.predict_cell(c) != [pieces[i], world.NO_PLANT]:
			printerr("FAIL bridge_planks: %s drawn %s predicted %s, want %s" % [
				c, world.get_cell_atlas_coords(0, c), world.predict_cell(c), pieces[i]])
			fail += 1
		if not world.is_walkable_land(c) or world.get_cell_source_id(1, c) != -1 \
				or world.get_cell_source_id(world.GROUND_DECOR_LAYER, c) != -1:
			printerr("FAIL bridge_planks: %s is not bare walkable ground" % c)
			fail += 1
		if MobSpawner.is_home_cell(world, c, MobCatalog.HOME_SAND) or MobSpawner.is_home_cell(world, c, MobCatalog.HOME_GRASS):
			printerr("FAIL bridge_planks: %s is a mob home" % c)
			fail += 1
	# The hero's body walks the whole bridge; the water row next to it blocks.
	var player = load("res://Scripts/player/character_body_2d.tscn").instantiate()
	player.name = str(scene.multiplayer.get_unique_id())
	scene.get_node("World").add_child(player)
	var free_row := func(row: Vector2i) -> bool:
		player.global_position = world.to_global(world.map_to_local(row - Vector2i.RIGHT))
		return player.move_and_collide(Vector2(16.0 * (run_len + 1), 0), true) == null
	await physics_frame
	await physics_frame
	if not free_row.call(run_start):
		printerr("FAIL bridge_planks: the hero cannot walk across the bridge")
		fail += 1
	var blocked := 0
	for side in [Vector2i.UP, Vector2i.DOWN]:
		if world.predict_cell(run_start + side)[0] == TileCatalog.WATER:
			blocked += 0 if free_row.call(run_start + side) else 1
		else:
			blocked += 1  # land there; nothing to check
	if blocked != 2 or world.predict_cell(run_start + Vector2i.DOWN)[0] != TileCatalog.WATER \
			and world.predict_cell(run_start + Vector2i.UP)[0] != TileCatalog.WATER:
		printerr("FAIL bridge_planks: the hero walks over plain water next to the bridge, or no water there")
		fail += 1
	player.queue_free()
	world.apply_map_params(params)
	world.generate_chunk(Vector2(0, 0))
	if world.get_cell_atlas_coords(0, run_start) != Vector2i(-1, -1) or not world.is_open_sea(run_start):
		printerr("FAIL bridge_planks: a new map kept the bridge at %s" % run_start)
		fail += 1
	var single := Vector2i(-11, 11)
	if not world.build_bridge(single, single):
		printerr("FAIL bridge_planks: one-cell shore crossing refused")
		fail += 1
	else:
		fail += _expect_planks(world, {single: Vector2i(14, 15)}, "one-cell shore crossing")
	scene.queue_free()
	await process_frame
	if fail == 0:
		print("PASS test_bridge_planks")
	return fail


func _test_bridge_joins() -> int:
	## One deck across separate placements, tip restored on removal, and a
	## side branch that leaves the main run horizontal.
	print("-- test_bridge_joins")
	var fail := 0
	var scene = mount_seeded_tree_world(3, 0.0)
	var world = scene.get_node("World/worldMap")

	# Start, step, continuation length, near shore, separate tip, joined interior, far end.
	# The horizontal fixture reaches land. The vertical fixture ends in water.
	var cases := [
		[Vector2i(-12, -6), Vector2i.RIGHT, 1, Vector2i(10, 15), Vector2i(10, 16), Vector2i(8, 15), Vector2i(11, 15)],
		[Vector2i(-13, -5), Vector2i.DOWN, 5, Vector2i(12, 15), Vector2i(12, 16), Vector2i(9, 15), Vector2i(12, 16)],
	]
	for row in cases:
		var start: Vector2i = row[0]
		var step: Vector2i = row[1]
		var tip := start + 2 * step
		var continuation: Array[Vector2i] = []
		for i in row[2]:
			continuation.append(tip + (i + 1) * step)
		var first: Vector2i = continuation.front()
		var last: Vector2i = continuation.back()
		if not world.build_bridge(start, tip):
			printerr("FAIL bridge_joins: first run refused at %s" % start)
			fail += 1
			continue
		fail += _expect_planks(world, {start: row[3], tip: row[4]}, "separate")
		if not world.build_bridge(first, last):
			printerr("FAIL bridge_joins: continuation refused at %s" % first)
			fail += 1
			continue
		var joined := {start: row[3], tip: row[5], last: row[6]}
		fail += _expect_planks(world, joined, "joined")
		# Bridge removal has no player action or TileMap wrapper.
		if not world._bridges.erase_cells(continuation) or not continuation.all(world.is_open_sea):
			printerr("FAIL bridge_joins: continuation did not return to water at %s" % first)
			fail += 1
		fail += _expect_planks(world, {start: row[3], tip: row[4]}, "removed")
		if not world.build_bridge(first, last):
			printerr("FAIL bridge_joins: continuation refused on rejoin at %s" % first)
			fail += 1
		fail += _expect_planks(world, joined, "rejoined")
		if step == Vector2i.RIGHT:
			var split: Array[Vector2i] = [tip]
			if not world._bridges.erase_cells(split) or not world.is_open_sea(tip):
				printerr("FAIL bridge_joins: middle cell did not return to water")
				fail += 1
			fail += _expect_planks(world, {tip - step: Vector2i(10, 16), last: Vector2i(11, 15)}, "split")
			if not world.build_bridge(tip, tip):
				printerr("FAIL bridge_joins: filling the split was refused")
				fail += 1
			fail += _expect_planks(world, joined, "split filled")

	# The branch fixture touches the north end of the vertical deck.
	world.apply_map_params(_spawn_params(3, 0.0))
	world.generate_chunk(Vector2.ZERO)
	var middle := Vector2i(-15, -5)
	var branch := middle + Vector2i.DOWN
	if not world.build_bridge(middle + Vector2i.LEFT, middle + Vector2i.RIGHT) \
			or not world.build_bridge(branch, branch):
		printerr("FAIL bridge_joins: branch fixture refused")
		fail += 1
	else:
		fail += _expect_planks(world, {
			middle + Vector2i.LEFT: Vector2i(11, 16), middle: Vector2i(8, 15),
			middle + Vector2i.RIGHT: Vector2i(10, 16), branch: Vector2i(12, 16),
		}, "side branch")
		var branch_cells: Array[Vector2i] = [branch]
		if not world._bridges.erase_cells(branch_cells) or not world.is_open_sea(branch):
			printerr("FAIL bridge_joins: branch remained after removal")
			fail += 1
		fail += _expect_planks(world, {middle: Vector2i(8, 15)}, "branch removed")

	var inventory: Inventory = scene.get_node("Inventory")
	inventory.add(Inventory.WOOD, 8)
	var placer := ConstructionPlacer.new(world)
	var placement := [
		[branch, []],
		[Vector2i(-13, -6), [ConstructionPlacer.WRONG_GROUND]],
		[middle, [ConstructionPlacer.OCCUPIED]],
		[Vector2i(-16, -3), [ConstructionPlacer.NOT_ADJACENT]],
	]
	for row in placement:
		var cells: Array[Vector2i] = [row[0]]
		var reasons := placer.can_place(BuildCosts.PLANK, cells, inventory)
		if (row[1].is_empty() and not reasons.is_empty()) \
				or not row[1].all(func(reason): return reason in reasons):
			printerr("FAIL bridge_joins: placement at %s gave %s, expected %s" % [cells, reasons, row[1]])
			fail += 1
	scene.queue_free()
	await process_frame
	if fail == 0:
		print("PASS test_bridge_joins")
	return fail


func _expect_planks(world, expected: Dictionary, label: String) -> int:
	var fail := 0
	for cell in expected:
		var drawn: Vector2i = world.get_cell_atlas_coords(0, cell)
		if drawn != expected[cell]:
			printerr("FAIL bridge tile: %s at %s drew %s, want %s" % [label, cell, drawn, expected[cell]])
			fail += 1
	return fail
