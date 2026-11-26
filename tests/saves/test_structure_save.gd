extends "res://tests/helpers/test_helpers.gd"
## Placed structures, tower owners and free-form walls in world saves.


func _structure_save_scene() -> Node:
	var scene = load("res://flagoria_main.tscn").instantiate()
	root.add_child(scene)
	scene.get_node("CanvasLayer2/MainMenu").hide()
	var world = scene.get_node("World/worldMap")
	world.set_process(false)
	var params := _spawn_params(7, 0.0)
	params.ensure_seeds()
	scene.world_params = params
	world.apply_map_params(params)
	return scene


func _save_and_read_world(scene: Node) -> WorldSave:
	var result: Dictionary = scene.get_node("CanvasLayer1/InGameMenu").save_world()
	if result["error"] != "":
		printerr("FAIL structure save: %s" % result["error"])
		return null
	var loaded := MapSave.load_world(result["path"])
	DirAccess.remove_absolute(result["path"])
	if loaded["error"] != "":
		printerr("FAIL structure load: %s" % loaded["error"])
	return loaded["world"]


func _castle_city_snapshot(world, cities: Cities) -> Dictionary:
	for id in world.placed_structures():
		if (
			world.placed_structures()[id]["name"] == StartCastle.structure().name
			and cities.cities.has(id)
		):
			return {"owner": cities.owner_of(id), "walls": cities.cities[id]["walls"].duplicate()}
	return {}


func _test_castle_wall_tint_save_reload() -> int:
	## Restore the city and its tint owner after Cities sees the cleared map.
	print("-- test_castle_wall_tint_save_reload")
	var scene := _structure_save_scene()
	var world = scene.get_node("World/worldMap")
	var cities: Cities = scene.get_node("World/Cities")
	if not world.place_start_castle(1):
		printerr("FAIL castle_wall_tint_save_reload: no starting castle")
		scene.queue_free()
		return 1
	cities.rebuild()
	var before := _castle_city_snapshot(world, cities)
	var saved := _save_and_read_world(scene)
	var after := {}
	if saved != null:
		world.apply_map_params(saved.params)
		cities.tick()
		StructureSaves.restore(saved.structures, world)
		after = _castle_city_snapshot(world, cities)
	scene.queue_free()
	await process_frame
	if before.get("owner") != 1 or before["walls"].is_empty() or after != before:
		printerr("FAIL castle_wall_tint_save_reload: city owner or boundary changed")
		return 1
	print("PASS test_castle_wall_tint_save_reload")
	return 0


func _test_structure_save_round_trip() -> int:
	print("-- test_structure_save_round_trip")
	var scene := _structure_save_scene()
	var world = scene.get_node("World/worldMap")
	if not world.place_start_castle(1):
		printerr("FAIL structure_save_round_trip: no starting castle")
		scene.queue_free()
		return 1
	var front: Vector2i = world.spawn_point
	var tower := StructurePlacer.load_named("tower_wood")
	var anchor: Variant = StartCastle.find_anchor(world, tower, front + Vector2i(12, 0))
	var tower_id: int = (
		world.place_structure(tower, anchor, StructurePlacer.OWNER_MOBS) if anchor != null else -1
	)
	var walls: Array[Vector2i] = []
	for r in range(6, 40):
		var start: Vector2i = front + Vector2i(-r, r)
		var run: Array[Vector2i] = [start, start + Vector2i.RIGHT, start + Vector2i.RIGHT * 2]
		if (
			run.all(func(c: Vector2i) -> bool: return world.predicted_clear(c))
			and world.place_wall_cells(run)
		):
			walls = run
			break
	if tower_id <= 0 or walls.is_empty():
		printerr("FAIL structure_save_round_trip: could not place tower and walls")
		scene.queue_free()
		return 1
	var want: Array = world.structures_for_sync()
	var saved := _save_and_read_world(scene)
	var fail := 0
	if saved == null:
		fail += 1
	else:
		world.apply_map_params(saved.params)
		if (
			StructureSaves.restore(saved.structures, world) != want.size() + walls.size()
			or world.get_used_cells(0).size() != 0
			or world.structures_for_sync() != want
			or not StructureSaves.adopt_start_castle(world, 1)
			or world.spawn_point != front
		):
			printerr(
				"FAIL structure_save_round_trip: placements or castle spawn did not survive reload"
			)
			fail += 1
		if (
			not walls.all(func(c: Vector2i) -> bool: return world.has_wall(c))
			or not _shows_flag(world, tower, anchor, TileCatalog.PROP_FLAG_MOBS)
			or not _shows_flag(
				world,
				StartCastle.structure(),
				front - StartCastle.GATE_FRONT,
				TileCatalog.PROP_FLAG_BLUE
			)
		):
			printerr("FAIL structure_save_round_trip: walls or owner flags did not survive reload")
			fail += 1

	world.apply_map_params(scene.world_params)
	var bad := {
		"0,0":
		{
			"1,1": {"structure": "no_such_thing", "owner": 1},
			"x": {"structure": "castle"},
			"2,2": {"cut": "tree"}
		}
	}
	if StructureSaves.restore(bad, world) != 0 or not world.placed_structures().is_empty():
		printerr("FAIL structure_save_round_trip: bad entries created placements")
		fail += 1
	for version in [1, 2, 3]:
		var loaded := MapSave.load_world("res://tests/fixtures/world_save_v%d.json" % version)
		var legacy: WorldSave = loaded["world"]
		if legacy == null:
			printerr("FAIL structure_save_round_trip: %s" % loaded["error"])
			fail += 1
			continue
		world.apply_map_params(legacy.params)
		if (
			StructureSaves.restore(legacy.structures, world) != 0
			or not world.placed_structures().is_empty()
			or not world.place_start_castle(1)
		):
			printerr(
				(
					"FAIL structure_save_round_trip: version %d did not start with a new castle"
					% version
				)
			)
			fail += 1
	scene.queue_free()
	await process_frame
	if fail == 0:
		print("PASS test_structure_save_round_trip")
	return fail


func _shows_flag(world, structure: Structure, anchor: Vector2i, flag: Vector2i) -> bool:
	return StructurePlacer.footprint(structure, anchor).keys().any(
		func(cell: Vector2i) -> bool: return world.predict_cell(cell)[1] == flag
	)


func _test_guard_post_save_round_trip() -> int:
	return await _rotated_structure_round_trip(
		"guard_post", {1: TileCatalog.PROP_FLAG_BLUE, 2: TileCatalog.PROP_FLAG_RED}
	)


func _test_barracks_save_round_trip() -> int:
	return await _rotated_structure_round_trip("barracks", {1: null})


func _rotated_structure_round_trip(kind: String, owners: Dictionary) -> int:
	var test_name := "test_%s_save_round_trip" % kind
	print("-- %s" % test_name)
	var scene := _structure_save_scene()
	var world = scene.get_node("World/worldMap")
	var structure := StructurePlacer.load_named(kind)
	var rotated := Structure.rotated(structure, 1)
	var flags := {}
	var fail := 0
	for owner in owners:
		var anchor: Variant = _place_rotated_structure(world, structure, owner)
		if anchor == null:
			printerr("FAIL %s: could not place structure for owner %d" % [test_name, owner])
			fail += 1
		elif owners[owner] != null:
			flags[anchor] = owners[owner]
	var want: Array = world.structures_for_sync()
	var saved := _save_and_read_world(scene)
	if saved == null:
		fail += 1
	else:
		world.apply_map_params(saved.params)
		if (
			StructureSaves.restore(saved.structures, world) != owners.size()
			or world.structures_for_sync() != want
		):
			printerr("FAIL %s: owner, rotation or placement changed" % test_name)
			fail += 1
		for anchor in flags:
			if not _shows_flag(world, rotated, anchor, flags[anchor]):
				printerr("FAIL %s: owner flag did not survive reload" % test_name)
				fail += 1
	scene.queue_free()
	await process_frame
	if fail == 0:
		print("PASS %s" % test_name)
	return fail


func _place_rotated_structure(world, structure: Structure, owner: int) -> Variant:
	for y in range(-24, 25):
		for x in range(-24, 25):
			var anchor: Vector2i = world.spawn_point + Vector2i(x, y)
			if world.can_place_structure(structure, anchor, 1).is_empty():
				if world.place_structure(structure, anchor, owner, 1) > 0:
					return anchor
	return null


func _test_mine_save_and_demolish() -> int:
	print("-- test_mine_save_and_demolish")
	var scene := _structure_save_scene()
	var world: TileMap = scene.get_node("World/worldMap")
	var inventory: Inventory = scene.get_node("Inventory")
	var params := _spawn_params(11, 0.003)
	scene.world_params = params
	world.apply_map_params(params)
	inventory.add(Inventory.WOOD, 15)
	var anchor := Vector2i(19, -59)
	world.generate_chunk(world.map_to_local(anchor))
	var ground_before := _mine_ground_atlases(world, anchor)
	var placed := ConstructionPlacer.new(world).place(BuildCosts.MINE, [anchor], inventory)
	var ground_after_place := _mine_ground_atlases(world, anchor)
	var starting_castle: bool = world.place_start_castle(1)
	var rock_removed: bool = world.destroy_decor(anchor + Vector2i.DOWN)
	var saved := (
		_save_and_read_world(scene) if placed and starting_castle and rock_removed else null
	)
	var ok := false
	if saved != null:
		world.apply_map_params(saved.params)
		world.restore_object_changes(saved.object_changes)
		StructureSaves.restore(saved.structures, world)
		world.generate_chunk(world.map_to_local(anchor))
		var ground_after_reload := _mine_ground_atlases(world, anchor)
		var placement: Dictionary = world.structure_placement_at(anchor)
		var adopted := StructureSaves.adopt_start_castle(world, 1)
		var castle: Vector2i = world.spawn_point - StartCastle.GATE_FRONT
		var remover := ConstructionRemover.new(world)
		ok = (
			adopted
			and placement.get("name") == "mine"
			and placement.get("anchor") == anchor
			and placement.get("owner") == 1
			and remover.remove(anchor, 2, inventory).is_empty()
			and remover.remove(castle, 1, inventory).is_empty()
			and inventory.count_of(Inventory.WOOD) == 0
			and not remover.remove(anchor, 1, inventory).is_empty()
			and world.structure_placement_at(anchor).is_empty()
			and inventory.count_of(Inventory.WOOD) == 7
		)
		var ground_after_demolish := _mine_ground_atlases(world, anchor)
		if (
			ground_after_place != ground_before
			or ground_after_reload != ground_before
			or ground_after_demolish != ground_before
		):
			printerr(
				"FAIL mine_save_and_demolish: ground changed after placement, reload or demolition"
			)
			ok = false
	scene.queue_free()
	await process_frame
	if ok:
		print("PASS test_mine_save_and_demolish")
	else:
		printerr("FAIL mine_save_and_demolish: ground, saved anchor, owner, demolition or refund")
	return 0 if ok else 1


func _mine_ground_atlases(world: TileMap, anchor: Vector2i) -> Array[Vector2i]:
	# The anchor is on the bottom row of the 3×3 footprint. Include the ring
	# around it, which also covers the track apron beyond the entrance.
	var atlases: Array[Vector2i] = []
	for y in range(-3, 2):
		for x in range(-2, 3):
			atlases.append(world.get_cell_atlas_coords(0, anchor + Vector2i(x, y)))
	return atlases
