extends "res://tests/helpers/test_helpers.gd"
## Minimap panel and the explored map.


func _test_minimap_panel_in_scene() -> int:
	print("-- test_minimap_panel_in_scene")
	var fail := 0
	var scene := await preload("res://tools/hud_layout_dump.gd").play_scene(tree)
	var hud: CanvasLayer = scene.get_node("CanvasLayer1")
	var map: ParchmentMap = hud.get_node("ParchmentMap")
	var button := hud.get_node_or_null("MapButton") as Button
	if hud.has_node("MinimapPanel") or hud.has_node("MinimapButton"):
		printerr("FAIL minimap_panel_in_scene small map found in the playing HUD")
		fail += 1
	if button != null:
		_tap_sequence(button.get_global_rect().get_center(), ["input_touch_down", "input_touch_up"])
	if not map.is_open():
		printerr("FAIL minimap_panel_in_scene Map did not open parchment")
		fail += 1
	scene.queue_free()
	await process_frame
	if fail == 0:
		print("PASS test_minimap_panel_in_scene")
	return fail


func _test_minimap_incremental_render() -> int:
	## Painting only the newly revealed cells (and the ring around them) gives
	## the same chunk images, pixel for pixel, as drawing each chunk from
	## scratch, across chunk edges and coast lines, and reuses each chunk's
	## texture.
	print("-- test_minimap_incremental_render")
	var fail := 0
	var scene = load("res://flagoria_main.tscn").instantiate()
	root.add_child(scene)
	var world = scene.get_node("World/worldMap")
	scene.world_params = _spawn_params(42, 0.003)
	world.apply_map_params(scene.world_params)
	await process_frame
	var chart: MapChart = scene.get_node("CanvasLayer1/MapChart")
	chart.set_physics_process(false)
	var cell := Vector2i(-40, -40)
	var first_tex: ImageTexture = null
	for leg in [Vector2i(3, 0), Vector2i(0, 3), Vector2i(-2, 1), Vector2i(1, -3)]:
		for i in 25:
			chart.reveal_around(cell)
			if first_tex == null:
				first_tex = chart.chunk_texture(ExploredMap.chunk_of(cell))
			cell += leg
	if chart.chunk_texture(ExploredMap.chunk_of(Vector2i(-40, -40))) != first_tex:
		printerr("FAIL minimap_incremental_render: a chunk texture was replaced, not updated")
		fail += 1
	var ink := 0
	var water := 0
	for chunk in chart.explored.chunks():
		var got := chart.chunk_image(chunk)  # the headless renderer keeps no texture pixels
		var want := chart.render_chunk(chunk)
		if got.get_data() != want.get_data():
			printerr("FAIL minimap_incremental_render: chunk %s differs from a full render" % chunk)
			fail += 1
		for y in want.get_height():
			for x in want.get_width():
				var c := want.get_pixel(x, y)
				ink += int(c == MapChart.INK)
				water += int(c == MapChart.SKY or c == MapChart.SKY_DEEP)
	if ink == 0 or water == 0 or chart.explored.chunks().size() < 6:
		printerr(
			(
				"FAIL minimap_incremental_render: walk too plain (%d ink, %d water px, %d chunks)"
				% [ink, water, chart.explored.chunks().size()]
			)
		)
		fail += 1
	scene.queue_free()
	await process_frame
	if fail == 0:
		print("PASS test_minimap_incremental_render")
	return fail


func _test_explored_map() -> int:
	## Revealing marks every cell within 10 cells (Euclidean) of the hero, in
	## 32 x 32 chunks of 128-byte bitsets, across negative coordinates; a
	## second reveal at the same spot changes nothing and clear() forgets all.
	print("-- test_explored_map")
	var fail := 0
	var map := ExploredMap.new()
	var changed := map.reveal(Vector2i.ZERO)
	var want_chunks := [Vector2i(-1, -1), Vector2i(0, -1), Vector2i(-1, 0), Vector2i(0, 0)]
	if changed.size() != 4 or want_chunks.any(func(c): return not c in changed):
		printerr("FAIL explored_map changed chunks %s" % [changed])
		fail += 1
	if map.explored_count() != 317:  # lattice points with x^2 + y^2 <= 100
		printerr("FAIL explored_map %s cells explored, want 317" % map.explored_count())
		fail += 1
	for c in [
		[Vector2i(10, 0), true],
		[Vector2i(-10, 0), true],
		[Vector2i(8, -6), true],
		[Vector2i(-8, 7), false],
		[Vector2i(11, 0), false],
		[Vector2i(0, -11), false]
	]:
		if map.is_explored(c[0]) != c[1]:
			printerr("FAIL explored_map is_explored(%s) != %s" % c)
			fail += 1
	if (
		ExploredMap.chunk_of(Vector2i(-1, -33)) != Vector2i(-1, -2)
		or ExploredMap.chunk_of(Vector2i(31, 32)) != Vector2i(0, 1)
	):
		printerr("FAIL explored_map chunk_of")
		fail += 1
	if (
		map.chunk_bits(Vector2i.ZERO).size() != ExploredMap.CHUNK_BYTES
		or not map.chunk_bits(Vector2i(5, 5)).is_empty()
	):
		printerr("FAIL explored_map chunk_bits sizes")
		fail += 1
	var again := map.reveal(Vector2i.ZERO)
	var step := map.reveal(Vector2i(1, 0))  # only the new east edge, all at x >= 0
	if (
		not again.is_empty()
		or step.size() != 2
		or not Vector2i(0, -1) in step
		or not Vector2i(0, 0) in step
	):
		printerr("FAIL explored_map repeat reveal changed chunks")
		fail += 1
	map.clear()
	if map.explored_count() != 0 or map.is_explored(Vector2i.ZERO):
		printerr("FAIL explored_map clear")
		fail += 1
	map.reveal(Vector2i(4, -3))
	var rect := map.explored_rect()
	if rect.position != Vector2i(-6, -13) or rect.size != Vector2i(21, 21):
		printerr("FAIL explored_map explored_rect %s" % [rect])
		fail += 1
	if fail == 0:
		print("PASS test_explored_map")
	return fail
