extends "res://tests/helpers/test_helpers.gd"
## Interact-mode Barracks picker and placement (#556).


func _clear_barracks_anchor(world, quarter_turns := 0) -> Variant:
	var s: Structure = StructurePlacer.load_named("barracks")
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


func _test_barracks_not_a_tower() -> int:
	## A placed barracks is not listed in StructurePlacer.towers().
	print("-- test_barracks_not_a_tower")
	var fail := 0
	var scene = load("res://flagoria_main.tscn").instantiate()
	root.add_child(scene)
	var world = scene.get_node("World/worldMap")
	var inventory: Inventory = scene.get_node("Inventory")
	var placer := ConstructionPlacer.new(world)
	var anchor: Variant = _clear_barracks_anchor(world)
	if anchor == null:
		printerr("FAIL barracks_not_a_tower: no anchor")
		scene.queue_free()
		return 1
	inventory.add(Inventory.WOOD, 30)
	var place_id := -1
	if not placer.place(BuildCosts.BARRACKS, [anchor], inventory):
		printerr("FAIL barracks_not_a_tower: could not place")
		fail += 1
	else:
		for id in world.placed_structures():
			if str(world.placed_structures()[id].get("name")) == "barracks":
				place_id = int(id)
				break
		if place_id < 0 or world._structures.towers().has(place_id):
			printerr("FAIL barracks_not_a_tower: id %d towers %s" % [place_id, world._structures.towers()])
			fail += 1
	scene.queue_free()
	await process_frame
	if fail == 0:
		print("PASS test_barracks_not_a_tower")
	return fail
