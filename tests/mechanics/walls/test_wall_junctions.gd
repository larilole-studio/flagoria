extends "res://tests/helpers/test_helpers.gd"
## Junctions on the map: corners, both collars, tower flag, a far flip, cap cleanup, save load.

const NOTCH := [
	"#######....", "#..#..#....", "#..#..#####", "#.........#", "#.........#", "####.######",
]

func _test_wall_junctions() -> int:
	## Time cost: about 1 s in tools/verify.sh (~2.4 s alone with --only).
	print("-- test_wall_junctions")
	var fail := 0
	var scene = load("res://flagoria_main.tscn").instantiate()
	root.add_child(scene)
	var world = scene.get_node("World/worldMap")
	var requests: StructureRequests = scene.get_node("World/StructureRequests")
	var params := _spawn_params(11, 0.0)
	world.apply_map_params(params)
	world.generate_chunk(Vector2(0, 0))
	if world.get_layers_count() < 7 or world.get_layer_z_index(WallBuilder.CAP_LAYER) <= 1 \
			or world.get_layer_z_index(WallBuilder.CAP_LAYER_2) <= world.get_layer_z_index(WallBuilder.CAP_LAYER) \
			or world.get_layer_z_index(WallBuilder.CAP_LAYER_4) <= world.get_layer_z_index(WallBuilder.CAP_LAYER_3):
		printerr("FAIL wall_junctions: cap layers missing or under the walls")
		fail += 1
	fail += _gate_outline()
	fail += _caps_have_no_collision(world)
	if not world.place_start_castle(1):
		printerr("FAIL wall_junctions: no starting castle on seed 11")
		scene.queue_free()
		return 1
	var castle: Dictionary = world.placed_structures()
	var castle_anchor: Vector2i = castle[castle.keys()[0]]["anchor"]
	fail += _expect_prefix(world, castle_anchor + Vector2i(-3, -4), "WALL_CORNER_OUT_", "castle corner")
	var post := StructurePlacer.load_named("guard_post")
	# Fixed seed 11 fixtures leave room for the towers, joins and notch.
	var post_at := Vector2i(-18, -25)
	if world.place_structure(post, post_at, 1) <= 0:
		printerr("FAIL wall_junctions: no guard_post on seed 11")
		scene.queue_free()
		return 1
	fail += _expect_prefix(world, post_at + Vector2i(-2, -3), "WALL_CORNER_OUT_", "guard_post corner")
	var tower := StructurePlacer.load_named("tower_wood")
	var a := Vector2i(-3, -36)
	var gap := Vector2i(-1, -37)
	if world.place_structure(tower, a, 1) <= 0 or world.place_structure(tower, a + Vector2i(4, 0), 1) <= 0:
		printerr("FAIL wall_junctions: tower place failed at %s" % a)
		scene.queue_free()
		return 1
	var flag: Vector2i = a + Vector2i(0, -1)
	if world.predict_cell(flag)[1] != TileCatalog.PROP_FLAG_BLUE:
		printerr("FAIL wall_junctions: tower centre %s is not the team flag" % flag)
		fail += 1
	var gap_cells: Array[Vector2i] = [gap]
	if not world.place_wall_cells(gap_cells):
		printerr("FAIL wall_junctions: gap palisade refused")
		fail += 1
	else:
		if not _tile_name(world, 1, a + Vector2i(1, -1)).begins_with("TOWER_STONE_E_E") \
				or not _tile_name(world, 1, a + Vector2i(3, -1)).begins_with("TOWER_STONE_W_W"):
			printerr("FAIL wall_junctions: tower arms %s %s" % [
				_tile_name(world, 1, a + Vector2i(1, -1)), _tile_name(world, 1, a + Vector2i(3, -1))])
			fail += 1
	var straight := a + Vector2i(0, -3)
	var bend := a + Vector2i(-2, -1)
	var tee := a + Vector2i(4, -3)
	var cross := a + Vector2i(4, 1)
	var shapes: Array[Vector2i] = [straight, straight + Vector2i(0, -1), bend, bend + Vector2i(0, 1),
		tee, tee + Vector2i(1, 0), tee + Vector2i(-1, 0), cross, cross + Vector2i(1, 0),
		cross + Vector2i(-1, 0), cross + Vector2i(0, 1)]
	if not world.place_wall_cells(shapes):
		printerr("FAIL wall_junctions: join shapes do not fit at %s" % shapes)
		fail += 1
	var junctions := [
		[gap, "PALISADE_H", ["CAP_COLLAR_E", "CAP_COLLAR_W"]],
		[straight, "PALISADE_V", ["CAP_COLLAR_S"]],
		[bend, "PALISADE_CORNER_OUT_NW", ["CAP_COLLAR_E"]],
		[tee, "PALISADE_T_N", ["CAP_COLLAR_S"]],
		[cross, "PALISADE_CROSS", ["CAP_COLLAR_N"]],
	]
	for row in junctions:
		fail += _expect_junction(world, row[0], row[1], row[2])
	var origin := Vector2i(-16, -24)
	var cells: Array[Vector2i] = []
	for y in NOTCH.size():
		for x in NOTCH[y].length():
			if NOTCH[y][x] == "#":
				cells.append(origin + Vector2i(x, y))
	var corner := origin + Vector2i(6, 2)
	var closing := origin + Vector2i(4, 5)
	var close_cells: Array[Vector2i] = [closing]
	if not world.place_wall_cells(cells):
		printerr("FAIL wall_junctions: notch place failed")
		fail += 1
	else:
		fail += _expect_prefix(world, corner, "PALISADE_CORNER_OUT_", "open notch")
		if not world.place_wall_cells(close_cells):
			printerr("FAIL wall_junctions: closing cell refused")
			fail += 1
		else:
			fail += _expect_prefix(world, corner, "PALISADE_CORNER_IN_", "closed notch")
			if not requests.host_erase_wall(closing):
				printerr("FAIL wall_junctions: closing cell could not be removed")
				fail += 1
			fail += _expect_prefix(world, corner, "PALISADE_CORNER_OUT_", "reopened notch")
	if not requests.host_erase_wall(gap):
		printerr("FAIL wall_junctions: caps stayed after remove")
		fail += 1
	elif _tile_name(world, 1, a + Vector2i(1, -1)) != "TOWER_STONE_E_X":
		printerr("FAIL wall_junctions: tower arm stayed after the palisade left")
		fail += 1
	fail += _expect_junction(world, gap, "", [])
	world.place_wall_cells(gap_cells)
	var saved_junctions := [
		junctions[0], [flag, "PROP_FLAG_BLUE", []],
		[castle_anchor + Vector2i(-3, -4), "WALL_CORNER_OUT_NW", []],
		[post_at + Vector2i(-2, -3), "WALL_CORNER_OUT_NW", []],
	]
	var changes := StructureSaves.to_changes(world)
	world.apply_map_params(params)
	if StructureSaves.restore(changes, world) <= 0:
		printerr("FAIL wall_junctions: restore wrote nothing")
		fail += 1
	for row in saved_junctions:
		var cell: Vector2i = row[0]
		if not world.is_drawn(cell):
			world.generate_chunk(world.map_to_local(cell))
		fail += _expect_junction(world, cell, row[1], row[2])
	scene.queue_free()
	await process_frame
	if fail == 0:
		print("PASS test_wall_junctions")
	return fail


func _test_wall_collar_sides() -> int:
	## Three stone sides draw three collars and four draw four, in N,E,S,W
	## order. Removing the palisade clears every cap layer; placing it again
	## brings them back. One- and two-side cells are unchanged. Time cost:
	## about 0.5 s in tools/verify.sh.
	print("-- test_wall_collar_sides")
	var fail := 0
	var scene = load("res://flagoria_main.tscn").instantiate()
	root.add_child(scene)
	var world = scene.get_node("World/worldMap")
	var requests: StructureRequests = scene.get_node("World/StructureRequests")
	var tower := StructurePlacer.load_named("tower_wood")
	var params := _spawn_params(42, 0.0)
	params.tree_min_chance = 0.85
	params.bush_min_chance = 0.85
	params.pine_min_chance = 0.85
	world.apply_map_params(params)
	world.generate_chunk(Vector2.ZERO)
	var p := Vector2i(-5, 11)
	# North, east, west and south towers surround the shared palisade cell.
	var anchors := [Vector2i(-6, 10), Vector2i(-3, 11), Vector2i(-7, 13), Vector2i(-4, 14)]
	for i in 3:
		if world.place_structure(tower, anchors[i], 1) <= 0:
			printerr("FAIL wall_collar_sides: tower %s refused at %s" % [i, anchors[i]])
			scene.queue_free()
			return 1
	var cells: Array[Vector2i] = [p]
	if not world.place_wall_cells(cells):
		printerr("FAIL wall_collar_sides: palisade refused at %s" % p)
		scene.queue_free()
		return 1
	var stages := [
		["PALISADE_T_S", ["CAP_COLLAR_N", "CAP_COLLAR_E", "CAP_COLLAR_W"]],
		["PALISADE_CROSS", ["CAP_COLLAR_N", "CAP_COLLAR_E", "CAP_COLLAR_S", "CAP_COLLAR_W"]],
		["", []],
	]
	fail += _expect_junction(world, p, stages[0][0], stages[0][1])
	if world.place_structure(tower, anchors[3], 1) <= 0:
		printerr("FAIL wall_collar_sides: south tower refused")
		fail += 1
	else:
		fail += _expect_junction(world, p, stages[1][0], stages[1][1])
		if not requests.host_erase_wall(p) or world.has_wall(p):
			printerr("FAIL wall_collar_sides: wall remained after removal")
			fail += 1
		fail += _expect_junction(world, p, stages[2][0], stages[2][1])
		if not world.place_wall_cells(cells):
			printerr("FAIL wall_collar_sides: wall refused on re-placement")
			fail += 1
		fail += _expect_junction(world, p, stages[1][0], stages[1][1])
	scene.queue_free()
	await process_frame
	if fail == 0:
		print("PASS test_wall_collar_sides")
	return fail

func _gate_outline() -> int:
	var tex := load("res://art/flagoria/flagoria_tiles_v4.png") as Texture2D
	var img := tex.get_image() if tex != null else null
	if img == null:
		printerr("FAIL wall_junctions: atlas did not load")
		return 1
	for cell in [Vector2i(20, 2), Vector2i(21, 2)]:
		for x in range(6, 10):
			var p := img.get_pixel(cell.x * 16 + x, cell.y * 16 + 14)
			if p.r8 != 0x2a or p.g8 != 0x22 or p.b8 != 0x38:
				printerr("FAIL wall_junctions: gate %s pixel %s is %s" % [cell, x, p])
				return 1
	return 0

func _caps_have_no_collision(world) -> int:
	var src: TileSetAtlasSource = world.tile_set.get_source(TileCatalog.SOURCE_ID)
	for n in ["CAP_COLLAR_N", "CAP_COLLAR_E", "CAP_COLLAR_S", "CAP_COLLAR_W"]:
		if src.get_tile_data(TileCatalog.TILES[n]["atlas"], 0).get_collision_polygons_count(0) != 0:
			printerr("FAIL wall_junctions: %s has collision" % n)
			return 1
	var body := src.get_tile_data(TileCatalog.TILES["TOWER_STONE_N_X"]["atlas"], 0)
	if body.get_collision_polygons_count(0) == 0:
		printerr("FAIL wall_junctions: tower ring has no collision")
		return 1
	return 0

func _expect_prefix(world, cell: Vector2i, prefix: String, label: String) -> int:
	var name := _tile_name(world, 1, cell)
	if not name.begins_with(prefix):
		printerr("FAIL wall_junctions: %s %s is %s" % [label, cell, name])
		return 1
	return 0

func _expect_junction(world, cell: Vector2i, piece: String, caps: Array) -> int:
	var drawn := _junction_tiles(world, cell)
	var expected := [piece]
	expected.append_array(caps)
	expected.resize(5)
	for i in range(1 + caps.size(), expected.size()):
		expected[i] = ""
	if drawn != expected:
		printerr("FAIL wall junction at %s drew %s, want %s" % [cell, drawn, expected])
		return 1
	return 0


func _junction_tiles(world, cell: Vector2i) -> Array:
	var tiles := [_tile_name(world, 1, cell)]
	for layer in WallBuilder.CAP_LAYERS:
		tiles.append(_tile_name(world, layer, cell))
	return tiles

func _tile_name(world, layer: int, cell: Vector2i) -> String:
	if world.get_cell_source_id(layer, cell) == -1:
		return ""
	return _name_of(world.get_cell_atlas_coords(layer, cell))

func _name_of(atlas: Vector2i) -> String:
	for n in TileCatalog.TILES:
		if TileCatalog.TILES[n]["atlas"] == atlas and (n.begins_with("WALL_") or n.begins_with("PALISADE_") \
				or n.begins_with("TOWER_STONE_") or n.begins_with("CAP_COLLAR_") or n.begins_with("PROP_FLAG_")):
			return n
	return str(atlas)
