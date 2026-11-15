extends "res://tests/helpers/test_helpers.gd"
## Buildable guard posts through ConstructionPlacer (#528).


func _clear_guard_anchor(world, quarter_turns := 0) -> Variant:
	var s: Structure = StructurePlacer.load_named("guard_post")
	if s == null:
		return null
	s = Structure.rotated(s, quarter_turns)
	for seed_value in [11, 42, 99, 7, 1, 3, 5]:
		world.apply_map_params(_spawn_params(seed_value, 0.0))
		world.generate_chunk(Vector2(0, 0))
		for cell: Vector2i in world.get_used_cells(0):
			var cells: Array = StructurePlacer.footprint(s, cell).keys()
			if cells.is_empty():
				continue
			if cells.all(func(c): return world.get_cell_source_id(0, c) != -1 and world.predicted_clear(c)):
				return cell
	return null


func _test_construction_placer_guard() -> int:
	## Water, castle overlap, player, mob, short wood spends nothing; a clear
	## place spends 20 wood and owns the flag. Time cost: about 0.6 s.
	print("-- test_construction_placer_guard")
	var fail := 0
	var scene = load("res://flagoria_main.tscn").instantiate()
	root.add_child(scene)
	var world = scene.get_node("World/worldMap")
	var inventory: Inventory = scene.get_node("Inventory")
	var placer := ConstructionPlacer.new(world)
	var anchor: Variant = _clear_guard_anchor(world)
	if anchor == null:
		printerr("FAIL construction_placer_guard: no clear guard_post footprint")
		scene.queue_free()
		return 1
	var cells: Array[Vector2i] = [anchor]
	inventory.add(Inventory.WOOD, 19)
	var reasons := placer.can_place(BuildCosts.GUARD_POST, cells, inventory)
	if ConstructionPlacer.NOT_ENOUGH_WOOD not in reasons or placer.place(BuildCosts.GUARD_POST, cells, inventory) \
			or inventory.count_of(Inventory.WOOD) != 19:
		printerr("FAIL construction_placer_guard: short wood gave %s wood %d" % [reasons, inventory.count_of(Inventory.WOOD)])
		fail += 1
	inventory.add(Inventory.WOOD, 1)
	var before := inventory.count_of(Inventory.WOOD)
	if not placer.place(BuildCosts.GUARD_POST, cells, inventory) \
			or inventory.count_of(Inventory.WOOD) != before - 20:
		printerr("FAIL construction_placer_guard: place wood %d" % inventory.count_of(Inventory.WOOD))
		fail += 1
	else:
		var placed: Dictionary = world.placed_structures()
		var entry: Dictionary = placed[placed.keys()[0]]
		if entry.get("name") != "guard_post" or entry.get("owner") != scene.multiplayer.get_unique_id():
			printerr("FAIL construction_placer_guard: entry %s" % entry)
			fail += 1
	inventory.add(Inventory.WOOD, 20)
	reasons = placer.can_place(BuildCosts.GUARD_POST, cells, inventory)
	if ConstructionPlacer.OCCUPIED not in reasons or placer.place(BuildCosts.GUARD_POST, cells, inventory):
		printerr("FAIL construction_placer_guard: overlap gave %s" % reasons)
		fail += 1
	var water_anchor := Vector2i(1 << 20, 0)
	for cell in world.get_used_cells(0):
		if world.predict_cell(cell)[0] == TileCatalog.WATER and not world.has_bridge(cell):
			water_anchor = cell
			break
	if water_anchor.x != 1 << 20:
		reasons = placer.can_place(BuildCosts.GUARD_POST, [water_anchor], inventory)
		if ConstructionPlacer.WRONG_GROUND not in reasons \
				or placer.place(BuildCosts.GUARD_POST, [water_anchor], inventory):
			printerr("FAIL construction_placer_guard: water gave %s" % reasons)
			fail += 1
	var clear2: Variant = _clear_guard_anchor(world)
	if clear2 != null:
		var player = load("res://Player/character_body_2d.tscn").instantiate()
		player.name = "occupier"
		player.global_position = world.to_global(world.map_to_local(clear2))
		scene.get_node("World").add_child(player)
		await process_frame
		reasons = placer.can_place(BuildCosts.GUARD_POST, [clear2], inventory)
		if ConstructionPlacer.OCCUPIED not in reasons:
			printerr("FAIL construction_placer_guard: player gave %s" % reasons)
			fail += 1
		player.queue_free()
		await process_frame
		var mob: Mob = load("res://Mobs/mob.tscn").instantiate()
		mob.setup(MobCatalog.SLIME, world.to_global(world.map_to_local(clear2)), 1)
		scene.get_node("World/Mobs").add_child(mob)
		await process_frame
		reasons = placer.can_place(BuildCosts.GUARD_POST, [clear2], inventory)
		if ConstructionPlacer.OCCUPIED not in reasons:
			printerr("FAIL construction_placer_guard: mob gave %s" % reasons)
			fail += 1
		mob.queue_free()
	scene.queue_free()
	await process_frame
	if fail == 0:
		print("PASS test_construction_placer_guard")
	return fail