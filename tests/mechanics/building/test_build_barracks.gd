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


func _test_barracks_wood() -> int:
	## 29 wood spends nothing; 30 wood spends 30 and places barracks.
	print("-- test_barracks_wood")
	var fail := 0
	var scene = load("res://flagoria_main.tscn").instantiate()
	root.add_child(scene)
	var world = scene.get_node("World/worldMap")
	var inventory: Inventory = scene.get_node("Inventory")
	var placer := ConstructionPlacer.new(world)
	var anchor: Variant = _clear_barracks_anchor(world)
	if anchor == null:
		printerr("FAIL barracks_wood: no clear barracks footprint")
		scene.queue_free()
		return 1
	var cells: Array[Vector2i] = [anchor]
	inventory.add(Inventory.WOOD, 29)
	var reasons := placer.can_place(BuildCosts.BARRACKS, cells, inventory)
	if ConstructionPlacer.NOT_ENOUGH_WOOD not in reasons or placer.place(BuildCosts.BARRACKS, cells, inventory) \
			or inventory.count_of(Inventory.WOOD) != 29:
		printerr("FAIL barracks_wood: short wood gave %s wood %d" % [reasons, inventory.count_of(Inventory.WOOD)])
		fail += 1
	inventory.add(Inventory.WOOD, 1)
	var peer: int = scene.multiplayer.get_unique_id()
	if not placer.place(BuildCosts.BARRACKS, cells, inventory) \
			or inventory.count_of(Inventory.WOOD) != 0:
		printerr("FAIL barracks_wood: place wood %d" % inventory.count_of(Inventory.WOOD))
		fail += 1
	else:
		var ok := false
		for p in world.placed_structures().values():
			if str(p.get("name")) == "barracks" and int(p.get("owner")) == peer:
				ok = true
				break
		if not ok:
			printerr("FAIL barracks_wood: placements %s" % world.placed_structures())
			fail += 1
	scene.queue_free()
	await process_frame
	if fail == 0:
		print("PASS test_barracks_wood")
	return fail


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


func _test_build_picker_includes_barracks() -> int:
	## Buildings column has BarracksButton; tracks_pointer is true for footprint tools.
	print("-- test_build_picker_includes_barracks")
	var fail := 0
	var scene = load("res://flagoria_main.tscn").instantiate()
	root.add_child(scene)
	var menu: Node = scene.get_node("CanvasLayer2/MainMenu")
	menu.hide()
	menu.set_process_unhandled_input(false)
	scene.get_node("CanvasLayer1").show()
	var interaction: Interaction = scene.get_node("World/Interaction")
	interaction.set_mode(Interaction.Mode.INTERACT)
	await process_frame
	var picker: Control = scene.get_node_or_null("CanvasLayer1/BuildPicker")
	var barracks_btn: Button = picker.get_node_or_null("BarracksButton") if picker != null else null
	if barracks_btn == null:
		printerr("FAIL build_picker_includes_barracks: BarracksButton missing")
		fail += 1
	interaction.build.set_tool(BuildPlacement.Tool.BARRACKS)
	if interaction.build.tool != BuildPlacement.Tool.BARRACKS:
		printerr("FAIL build_picker_includes_barracks: set_tool BARRACKS did not stick")
		fail += 1
	for t in [
		BuildPlacement.Tool.PLANK, BuildPlacement.Tool.TOWER, BuildPlacement.Tool.CASTLE,
		BuildPlacement.Tool.GUARD, BuildPlacement.Tool.BARRACKS, BuildPlacement.Tool.WALL,
	]:
		if not BuildToolRow.tracks_pointer(t):
			printerr("FAIL build_picker_includes_barracks: tracks_pointer false for %s" % t)
			fail += 1
	if BuildToolRow.tracks_pointer(BuildPlacement.Tool.CUT):
		printerr("FAIL build_picker_includes_barracks: cut should not track pointer")
		fail += 1
	if interaction.build.tool == BuildPlacement.Tool.BARRACKS and not interaction.build.tracks_pointer():
		printerr("FAIL build_picker_includes_barracks: barracks instance tracks_pointer false")
		fail += 1
	scene.queue_free()
	await process_frame
	if fail == 0:
		print("PASS test_build_picker_includes_barracks")
	return fail


func _test_barracks_rotation() -> int:
	## Quarter turn 1 is stored on the placement and in structures_for_sync.
	print("-- test_barracks_rotation")
	var fail := 0
	var scene = load("res://flagoria_main.tscn").instantiate()
	root.add_child(scene)
	var world = scene.get_node("World/worldMap")
	var inventory: Inventory = scene.get_node("Inventory")
	var placer := ConstructionPlacer.new(world)
	var anchor: Variant = _clear_barracks_anchor(world, 1)
	if anchor == null:
		printerr("FAIL barracks_rotation: no anchor for turn 1")
		scene.queue_free()
		return 1
	inventory.add(Inventory.WOOD, 30)
	if not placer.place(BuildCosts.BARRACKS, [anchor], inventory, 1):
		printerr("FAIL barracks_rotation: place refused")
		fail += 1
	else:
		var sync: Array = world.structures_for_sync()
		var found := false
		for row in sync:
			if row is Array and str(row[0]) == "barracks" and row.size() > 3 and int(row[3]) == 1:
				found = true
				break
		if not found:
			printerr("FAIL barracks_rotation: sync %s" % sync)
			fail += 1
	scene.queue_free()
	await process_frame
	if fail == 0:
		print("PASS test_barracks_rotation")
	return fail