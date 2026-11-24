extends "res://tests/helpers/test_helpers.gd"
## Free-form palisade hit points and sword damage (#35).


func _scene() -> Dictionary:
	var scene = load("res://flagoria_main.tscn").instantiate()
	root.add_child(scene)
	var world = scene.get_node("World/worldMap")
	return {"scene": scene, "world": world}


func _wall_line(world) -> Array[Vector2i]:
	var front: Vector2i = world.spawn_point
	for r in range(6, 40):
		var start: Vector2i = front + Vector2i(r, 0)
		var run: Array[Vector2i] = [start, start + Vector2i.RIGHT, start + Vector2i.RIGHT * 2]
		if run.all(
			func(c: Vector2i) -> bool:
				return world.predicted_clear(c) and not world._structures.has_cell(c)
		):
			return run
	return []


func _test_wall_health_damage_and_save() -> int:
	## Non-walls and castle auto-walls reject damage; three hits remove listing
	## at 0 hp; a damaged segment keeps collision; saves keep hp under max.
	## Time cost: ~0.8 s in verify.
	print("-- test_wall_health_damage_and_save")
	var fail := 0
	var s := _scene()
	var world = s.world
	var params := _spawn_params(7, 0.0)
	params.ensure_seeds()
	s.scene.world_params = params
	s.scene._apply_params_to_world(params)
	if world._walls.damage(Vector2i(0, 0)) != -1:
		printerr("FAIL wall_health: damage on empty cell")
		fail += 1
	elif not world.place_start_castle(1):
		printerr("FAIL wall_health: no starting castle")
		fail += 1
	else:
		var auto_hit := false
		for cell: Vector2i in world._structures.auto_cells():
			if world._walls.has_wall(cell):
				continue
			if world._walls.damage(cell) != -1:
				printerr("FAIL wall_health: damage on structure auto-wall")
				fail += 1
			auto_hit = true
			break
		if not auto_hit:
			printerr("FAIL wall_health: no castle auto-wall cell")
			fail += 1
	var line := _wall_line(world)
	if fail == 0 and line.is_empty():
		printerr("FAIL wall_health: no walkable wall line")
		fail += 1
	elif fail == 0 and not world.place_wall_cells(line):
		printerr("FAIL wall_health: could not place the line")
		fail += 1
	elif fail == 0:
		var target := line[1]
		var left: int = world._walls.damage(target)
		if left != 2:
			printerr("FAIL wall_health: first hit want 2, got %d" % left)
			fail += 1
		else:
			var snap := StructureSaves.to_changes(world)
			world._walls.clear()
			if StructureSaves.restore(snap, world) < line.size():
				printerr(
					(
						"FAIL wall_health: restore placed %d walls, want %d"
						% [world._walls._wall_cells.size(), line.size()]
					)
				)
				fail += 1
			elif world._walls.hp(target) != 2:
				printerr("FAIL wall_health: reloaded hp want 2, got %d" % world._walls.hp(target))
				fail += 1
		if fail == 0 and world._walls.damage(target) != 1:
			printerr("FAIL wall_health: second hit want 1")
			fail += 1
		elif fail == 0 and world._walls.damage(target) != 0:
			printerr("FAIL wall_health: third hit want 0")
			fail += 1
		elif fail == 0 and world._walls.hp(target) != 0:
			printerr("FAIL wall_health: third hit did not reach 0 hp")
			fail += 1
		if fail == 0:
			world._walls.damage(line[0])
			world._walls.damage(line[0])
			var atlas: Vector2i = world.get_cell_atlas_coords(1, line[0])
			var piece_name := WallBuilder._atlas_wall_name(atlas)
			var src := world.tile_set.get_source(TileCatalog.SOURCE_ID) as TileSetAtlasSource
			var td := src.get_tile_data(atlas, 0) if src != null and src.has_tile(atlas) else null
			if (
				world._walls.hp(line[0]) != 1
				or td == null
				or td.get_collision_polygons_count(0) == 0
			):
				printerr(
					(
						"FAIL wall_health: damaged piece %s hp %d should block"
						% [piece_name, world._walls.hp(line[0])]
					)
				)
				fail += 1
	s.scene.queue_free()
	await process_frame
	if fail == 0:
		print("PASS test_wall_health_damage_and_save")
	return fail
