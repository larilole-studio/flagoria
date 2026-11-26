extends "res://tests/helpers/test_helpers.gd"
## Sprite assignments and playback for the four tree variants.


func _test_chop_tree_frames() -> int:
	## Each impact hides the tree tiles
	## (HIDDEN_ALT, collision kept) and draws its own row of the type's
	## hit_sheet in its place, with fx_sheet frames 0-1 over it. The fall at
	## 560 ms keeps the puff and adds fx frames 2-3. The timing is the tree's:
	## impacts at 140 ms and 460 ms.
	print("-- test_chop_tree_frames")
	var fail := 0
	var scene = mount_main_scene()
	var menu: Node = scene.get_node("CanvasLayer2/MainMenu")
	menu.hide()
	menu.set_process_unhandled_input(false)
	var world = scene.get_node("World/worldMap")
	world.clear()
	for x in range(4, 16):
		for y in range(4, 14):
			world.set_cell(0, Vector2i(x, y), TileCatalog.SOURCE_ID, TileCatalog.GRASS_A)
	var plants := {
		Vector2i(9, 9): TileCatalog.TREE,
		Vector2i(10, 9): TileCatalog.TREE_BUSHY,
		Vector2i(11, 9): TileCatalog.TREE_PINE_SMALL,
		Vector2i(10, 8): TileCatalog.TREE_BIRCH_BOTTOM
	}
	for cell: Vector2i in plants:
		world.set_cell(1, cell, TileCatalog.SOURCE_ID, plants[cell])
	world.set_cell(1, Vector2i(10, 7), TileCatalog.SOURCE_ID, TileCatalog.TREE_BIRCH_TOP)
	var player = add_combat_actor(scene, world.to_global(world.map_to_local(Vector2i(10, 10))))
	await process_frame
	var interaction: Interaction = scene.get_node("World/Interaction")
	interaction.set_process(false)  # the test steps the chop clock itself
	interaction.set_mode(Interaction.Mode.INTERACT)
	var run_to := func(t: float) -> void:
		interaction.step_chop(t - maxf(interaction.chop_time, 0.0))
	for cell: Vector2i in plants:
		var atlas: Vector2i = plants[cell]
		var type: InteractableType = world.choppable(cell)
		var tag := "%s at %s" % [atlas, cell]
		var sprites := InteractableCatalog.sprites_at(atlas)
		if type == null or sprites == null or sprites.hit_sheet == null or sprites.fx_sheet == null:
			printerr("FAIL chop_tree_frames: %s has no hit or fall sheet" % tag)
			fail += 1
			continue
		var row := sprites.hit_row
		if not interaction.start_chop(cell):
			printerr("FAIL chop_tree_frames: %s: could not start the chop" % tag)
			fail += 1
			continue
		for hit_at in [0.15, 0.47]:
			run_to.call(hit_at)
			if (
				atlas == TileCatalog.TREE_BIRCH_BOTTOM
				and (
					world.get_cell_alternative_tile(1, cell + Vector2i.UP) != Interaction.HIDDEN_ALT
				)
			):
				printerr("FAIL chop_tree_frames: birch canopy stayed visible during the hit")
				fail += 1
			if (
				world.get_cell_alternative_tile(1, cell) != Interaction.HIDDEN_ALT
				or not interaction._hit.visible
				or interaction._hit.texture != sprites.hit_sheet
				or interaction._hit.frame_coords != Vector2i(0, row)
				or not interaction._fx.visible
				or interaction._fx.texture != sprites.fx_sheet
				or interaction._fx.frame != 0
			):
				printerr(
					(
						"FAIL chop_tree_frames: %s at %s s: alt %s, hit %s %s, fx %s %s"
						% [
							tag,
							hit_at,
							world.get_cell_alternative_tile(1, cell),
							interaction._hit.visible,
							interaction._hit.frame_coords,
							interaction._fx.visible,
							interaction._fx.frame
						]
					)
				)
				fail += 1
			run_to.call(hit_at + 0.05)
			if interaction._hit.frame_coords != Vector2i(1, row) or interaction._fx.frame != 1:
				printerr(
					(
						"FAIL chop_tree_frames: %s: 50 ms after the impact hit %s, fx %s"
						% [tag, interaction._hit.frame_coords, interaction._fx.frame]
					)
				)
				fail += 1
			if hit_at < 0.4:
				run_to.call(0.3)
				if (
					interaction._hit.visible
					or interaction._fx.visible
					or world.get_cell_alternative_tile(1, cell) != 0
				):
					printerr("FAIL chop_tree_frames: %s: the first hit did not end by 300 ms" % tag)
					fail += 1
		run_to.call(0.55)
		if world.choppable(cell) != type:
			printerr("FAIL chop_tree_frames: %s fell before 560 ms" % tag)
			fail += 1
		run_to.call(0.57)
		if (
			world.choppable(cell) != null
			or world.get_cell_atlas_coords(world.GROUND_DECOR_LAYER, cell) != TileCatalog.STUMP
			or not interaction._puff.visible
			or interaction._hit.visible
			or not interaction._fx.visible
			or interaction._fx.frame != 2
		):
			printerr(
				(
					"FAIL chop_tree_frames: %s at 560 ms: decor %s, puff %s, hit %s, fx %s %s"
					% [
						tag,
						world.get_cell_atlas_coords(world.GROUND_DECOR_LAYER, cell),
						interaction._puff.visible,
						interaction._hit.visible,
						interaction._fx.visible,
						interaction._fx.frame
					]
				)
			)
			fail += 1
		run_to.call(0.75)
		if not interaction._fx.visible or interaction._fx.frame != 3:
			printerr(
				(
					"FAIL chop_tree_frames: %s at 750 ms fx %s %s, want frame 3"
					% [tag, interaction._fx.visible, interaction._fx.frame]
				)
			)
			fail += 1
		interaction.step_chop(1.0)
		interaction.step_chop(1.0)
	player.queue_free()
	scene.queue_free()
	await process_frame
	if fail == 0:
		print("PASS test_chop_tree_frames")
	return fail


func _test_tree_variant_sprites() -> int:
	print("-- test_tree_variant_sprites")
	var expected := {
		"TREE": [["TREE"], "tree_hit.png", 0, "fx_tree.png"],
		"TREE_BUSHY": [["TREE_BUSHY"], "tree_hit.png", 1, "fx_tree_bushy.png"],
		"TREE_BIRCH_BOTTOM":
		[["TREE_BIRCH_BOTTOM", "TREE_BIRCH_TOP"], "birch_hit.png", 0, "fx_birch.png"],
		"TREE_PINE_SMALL": [["TREE_PINE_SMALL"], "pine_hit.png", 0, "fx_pine.png"],
	}
	var fail := 0
	var art := "res://art/flagoria/fx/"
	var fall_frames: Array[PackedByteArray] = []
	for type: InteractableType in InteractableCatalog.TYPES:
		if type.id == "bush":
			continue
		for variant: ChopSprites in type.variants:
			if variant == null or variant.idle_tiles.is_empty():
				printerr("FAIL tree_variant_sprites: missing idle tiles for %s" % type.id)
				fail += 1
				continue
			var trunk := variant.idle_tiles[0]
			var want: Array = expected.get(trunk, [])
			if want.is_empty():
				printerr("FAIL tree_variant_sprites: unexpected or duplicate variant %s" % trunk)
				fail += 1
				continue
			expected.erase(trunk)
			var atlas: Vector2i = TileCatalog.TILES[trunk]["atlas"]
			var sprites := InteractableCatalog.sprites_at(atlas)
			var gameplay := InteractableCatalog.type_at(atlas)
			if (
				sprites != variant
				or gameplay != type
				or gameplay.leaves_atlas() != TileCatalog.STUMP
				or sprites.idle_tiles != want[0]
				or sprites.hit_sheet == null
				or sprites.hit_sheet.resource_path != art + want[1]
				or sprites.hit_row != want[2]
				or sprites.fx_sheet == null
				or sprites.fx_sheet.resource_path != art + want[3]
			):
				printerr("FAIL tree_variant_sprites: wrong idle, hit, fall or stump for %s" % trunk)
				fail += 1
				continue
			var falling := sprites.fx_sheet.get_image().get_region(Rect2i(32, 0, 32, 16))
			var pixels := falling.get_data()
			if fall_frames.has(pixels):
				printerr("FAIL tree_variant_sprites: duplicated falling frames for %s" % trunk)
				fail += 1
			fall_frames.append(pixels)
	if not expected.is_empty():
		printerr("FAIL tree_variant_sprites: missing variants %s" % [expected.keys()])
		fail += 1
	if fail == 0:
		print("PASS test_tree_variant_sprites")
	return fail


func _test_chop_sprites_unknown_atlas() -> int:
	print("-- test_chop_sprites_unknown_atlas")
	for atlas in [Vector2i(99, 99), TileCatalog.TREE_BIRCH_TOP]:
		if InteractableCatalog.sprites_at(atlas) != null:
			printerr("FAIL chop_sprites_unknown_atlas: atlas %s resolved to a sprite set" % atlas)
			return 1
	return 0


func _test_hit_sheets_match_golden() -> int:
	## The generated tree hit sheets match tests/golden/hit_sheets.txt (sha256
	## and size). TREE and TREE_BUSHY share tree_hit; pine uses pine_hit.
	## Changing or resizing a sheet fails this test (#357). Time cost: ~0.1 s
	## in verify (~1.5 s alone with --only=).
	print("-- test_hit_sheets_match_golden")
	var fail := 0
	var golden_path := "res://tests/golden/hit_sheets.txt"
	var text := FileAccess.get_file_as_string(golden_path)
	if text.is_empty():
		printerr("FAIL hit_sheets_match_golden: missing %s" % golden_path)
		return 1
	var want := {}  # path -> {sha, w, h}
	for line in text.split("\n"):
		var s := line.strip_edges()
		if s.is_empty() or s.begins_with("#"):
			continue
		var parts := s.split(" ")
		if parts.size() != 4:
			printerr("FAIL hit_sheets_match_golden: bad golden line %s" % s)
			fail += 1
			continue
		want[parts[0]] = {"sha": parts[1], "w": int(parts[2]), "h": int(parts[3])}
	var sheets := {}
	for id in ["tree", "pine"]:
		for variant: ChopSprites in InteractableCatalog.by_id(id).variants:
			if variant.hit_sheet != null:
				sheets[variant.hit_sheet.resource_path.trim_prefix("res://")] = variant.hit_sheet
	for path: String in sheets:
		if not want.has(path):
			printerr("FAIL hit_sheets_match_golden: no golden row for %s" % path)
			fail += 1
			continue
		var expected: Dictionary = want[path]
		var tex: Texture2D = sheets[path]
		if (
			FileAccess.get_sha256("res://" + path) != expected["sha"]
			or tex.get_width() != expected["w"]
			or tex.get_height() != expected["h"]
		):
			printerr("FAIL hit_sheets_match_golden: hash or dimensions changed for %s" % path)
			fail += 1
		want.erase(path)
	if not want.is_empty():
		printerr("FAIL hit_sheets_match_golden: unused golden rows %s" % [want.keys()])
		fail += 1
	if fail == 0:
		print("PASS test_hit_sheets_match_golden (%s sheets)" % sheets.size())
	return fail
