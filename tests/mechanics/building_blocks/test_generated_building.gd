extends "res://tests/helpers/test_helpers.gd"
## On-demand building: same seed paints the same tiles, on layer 7 (#26).

const ORIGIN := Vector2i(4, -3)


func _test_generated_building_determinism() -> int:
	## Time cost: ~2 s in tools/verify.sh (two solves, one scene, one physics frame).
	print("-- test_generated_building_determinism")
	var fail := 0
	fail += _layouts_match()
	fail += await _paint_and_button()
	if fail == 0:
		print("PASS test_generated_building_determinism")
	return fail


func _layouts_match() -> int:
	var fail := 0
	var first := GeneratedBuildings.layout_cells(6, 5, 42, 0)
	var again := GeneratedBuildings.layout_cells(6, 5, 42, 0)
	if first.is_empty() or first != again:
		printerr(
			(
				"FAIL generated_building_determinism: seed 42 style 0 %s vs %s"
				% [first.size(), again.size()]
			)
		)
		fail += 1
	var other := GeneratedBuildings.layout_cells(6, 5, 43, 0)
	if other.is_empty() or other == first:
		printerr("FAIL generated_building_determinism: seed 43 matched seed 42")
		fail += 1
	var moss := GeneratedBuildings.layout_cells(6, 5, 42, 1)
	if moss.is_empty() or moss == first:
		printerr("FAIL generated_building_determinism: style 1 matched style 0")
		fail += 1
	var doors := 0
	var door_tile := ""
	var moss_door := ""
	for cell in first:
		if cell["piece"] == "door":
			doors += 1
			door_tile = cell["tile"]
	var moss_doors := 0
	for cell in moss:
		if cell["piece"] == "door":
			moss_doors += 1
			moss_door = cell["tile"]
	if (
		doors != 1
		or moss_doors != 1
		or door_tile != "WALL_GATE_H_OPEN"
		or moss_door != "WALL_MOSS_GATE_H_OPEN"
	):
		printerr(
			(
				"FAIL generated_building_determinism: doors %s/%s tiles %s %s"
				% [doors, moss_doors, door_tile, moss_door]
			)
		)
		fail += 1
	if GeneratedBuildings.LAYER == 0 or GeneratedBuildings.LAYER == 1:
		printerr("FAIL generated_building_determinism: layer %s" % GeneratedBuildings.LAYER)
		fail += 1
	return fail


func _paint_and_button() -> int:
	var fail := 0
	var params := root.get_node("/root/MapGen").params as MapGenParams
	var saved := params.duplicate_params()
	params.building_width = 8
	params.building_height = 5
	params.building_style = 0
	var scene = load("res://flagoria_main.tscn").instantiate()
	root.add_child(scene)
	for i in 5:
		await process_frame
	var world: TileMap = scene.get_node("World/worldMap")
	world.set_process(false)
	var buildings: GeneratedBuildings = scene.get_node("World/GeneratedBuildings")
	var menu_button: Button = scene.get_node(
		"CanvasLayer1/InGameMenu/Pause/Panel/Margin/VBox/MapSettings"
	)
	if menu_button.text != "Map Settings":
		printerr("FAIL generated_building_determinism: menu button '%s'" % menu_button.text)
		fail += 1
	var panel: Node = scene.get_node("CanvasLayer2/MapAdminPanel")
	panel.find_child("Advanced").button_pressed = true
	var button: Button = panel.find_child("GenerateBuilding", true, false)
	if button.text != "Generate building" or not panel._spin_boxes.has("building_width"):
		printerr("FAIL generated_building_determinism: generate button missing")
		fail += 1
	else:
		panel._spin_boxes["building_width"].value = 6
		var player: CharacterBody2D = (
			load("res://Scripts/player/character_body_2d.tscn").instantiate()
		)
		player.name = "1"
		scene.get_node("World").add_child(player)
		player.position = world.map_to_local(Vector2i(10, 8))
		button.pressed.emit()
		await process_frame
		if buildings.record_count() != 1 or buildings.grid_of(0).size() != 5:
			printerr(
				"FAIL generated_building_determinism: button placed %s" % buildings.record_count()
			)
			fail += 1
		elif buildings.grid_of(0)[0].size() != 6:
			printerr(
				"FAIL generated_building_determinism: width %s" % buildings.grid_of(0)[0].size()
			)
			fail += 1
		else:
			fail += await _painted(world, buildings)
			player.position = world.map_to_local(Vector2i(24, 8))
			var key := InputEventKey.new()
			key.keycode = KEY_B
			key.physical_keycode = KEY_B
			key.pressed = true
			Input.parse_input_event(key)
			await process_frame
			await process_frame
			key.pressed = false
			Input.parse_input_event(key)
			await process_frame
			if buildings.record_count() != 2 or buildings.grid_of(0) == buildings.grid_of(1):
				printerr(
					"FAIL generated_building_determinism: key count %s" % buildings.record_count()
				)
				fail += 1
		scene.world_params = params.duplicate_params()
		scene.get_node("CanvasLayer2/MainMenu").open_settings_over_match()
		var start: Button = panel.get_node("Margin/VBox/Buttons2/Start")
		if not panel.visible or not start.disabled:
			printerr(
				(
					"FAIL generated_building_determinism: settings over match visible %s start %s"
					% [panel.visible, start.disabled]
				)
			)
			fail += 1
		scene.get_node("CanvasLayer2/MainMenu").hide()
		panel._on_back_pressed()
		if scene.get_node("CanvasLayer2/MainMenu").visible:
			printerr(
				"FAIL generated_building_determinism: Back opened the main menu during a match"
			)
			fail += 1
	var source := world.tile_set.get_source(TileCatalog.SOURCE_ID) as TileSetAtlasSource
	var roof := source.get_tile_data(TileCatalog.SKY_DOCK_N_ROOT, 0)
	if roof.get_collision_polygons_count(0) != 0:
		printerr("FAIL generated_building_determinism: dock root gained collision")
		fail += 1
	scene.queue_free()
	await process_frame
	root.get_node("/root/MapGen").params = saved
	return fail


func _painted(world: TileMap, buildings: GeneratedBuildings) -> int:
	var fail := 0
	var door := Vector2i(1 << 20, 0)
	var wall := door
	for cell in buildings.occupied_cells():
		var piece := buildings.piece_at(cell)
		var tile := GeneratedBuildings.tile_name_for(piece, 0)
		var atlas: Vector2i = TileCatalog.TILES[tile]["atlas"]
		if world.get_cell_atlas_coords(GeneratedBuildings.LAYER, cell) != atlas:
			printerr(
				(
					"FAIL generated_building_determinism: %s painted %s want %s"
					% [cell, world.get_cell_atlas_coords(GeneratedBuildings.LAYER, cell), atlas]
				)
			)
			fail += 1
			break
		if piece == "door":
			door = cell
		elif (
			wall.x == 1 << 20
			and (piece == "wall_straight" or piece == "wall_corner" or piece == "window")
		):
			wall = cell
	world.generate_chunk(world.map_to_local(door))
	await physics_frame
	await physics_frame
	if door.x == 1 << 20 or wall.x == 1 << 20:
		printerr("FAIL generated_building_determinism: door %s wall %s" % [door, wall])
		return fail + 1
	if world.get_cell_source_id(1, wall) != -1:
		printerr("FAIL generated_building_determinism: foliage returned on %s" % wall)
		fail += 1
	if world.get_cell_source_id(GeneratedBuildings.LAYER, wall) == -1:
		printerr("FAIL generated_building_determinism: chunk refresh cleared the wall")
		fail += 1
	if not _hits(world, wall) or _hits(world, door):
		var alt := world.get_cell_alternative_tile(GeneratedBuildings.LAYER, wall)
		printerr(
			(
				"FAIL generated_building_determinism: wall blocked %s door blocked %s alt %s atlas %s"
				% [
					_hits(world, wall),
					_hits(world, door),
					alt,
					world.get_cell_atlas_coords(GeneratedBuildings.LAYER, wall)
				]
			)
		)
		fail += 1
	return fail


func _hits(world: TileMap, cell: Vector2i) -> bool:
	var query := PhysicsPointQueryParameters2D.new()
	query.collision_mask = 1
	query.position = world.to_global(world.map_to_local(cell))
	return not world.get_world_2d().direct_space_state.intersect_point(query, 1).is_empty()
