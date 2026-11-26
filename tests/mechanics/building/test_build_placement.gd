extends "res://tests/helpers/test_helpers.gd"
## Interact-mode build picker and plank preview (#225).


func _test_build_placement_snap_run() -> int:
	## A plank drag snaps to a horizontal or vertical cell run; a diagonal
	## finger path becomes the dominant axis. Time cost: under 0.05 s in
	## tools/verify.sh (~1.7 s alone with --only=, against runner start-up).
	print("-- test_build_placement_snap_run")
	var fail := 0
	var horiz := BuildPlacement.snap_run(Vector2i(3, 5), Vector2i(7, 8))
	var want_h: Array[Vector2i] = [
		Vector2i(3, 5),
		Vector2i(4, 5),
		Vector2i(5, 5),
		Vector2i(6, 5),
		Vector2i(7, 5),
	]
	if horiz != want_h:
		printerr("FAIL build_placement_snap_run: diagonal->H got %s" % [horiz])
		fail += 1
	var vert := BuildPlacement.snap_run(Vector2i(3, 5), Vector2i(4, 9))
	var want_v: Array[Vector2i] = [
		Vector2i(3, 5),
		Vector2i(3, 6),
		Vector2i(3, 7),
		Vector2i(3, 8),
		Vector2i(3, 9),
	]
	if vert != want_v:
		printerr("FAIL build_placement_snap_run: diagonal->V got %s" % [vert])
		fail += 1
	var one := BuildPlacement.snap_run(Vector2i(2, 2), Vector2i(2, 2))
	if one != [Vector2i(2, 2)]:
		printerr("FAIL build_placement_snap_run: single cell got %s" % [one])
		fail += 1
	if fail == 0:
		print("PASS test_build_placement_snap_run")
	return fail


func _test_build_picker_switches_tool() -> int:
	## The round Plank/Tower/Wall row is up from the start. Picking Plank
	## switches the tool. Leaving interact keeps the row and resets to Cut.
	## Time cost: about 0.3 s in tools/verify.sh (~2.0 s alone with
	## --only=build_picker_switches_tool).
	print("-- test_build_picker_switches_tool")
	var fail := 0
	var scene = load("res://flagoria_main.tscn").instantiate()
	root.add_child(scene)
	var menu: Node = scene.get_node("CanvasLayer2/MainMenu")
	menu.hide()
	menu.set_process_unhandled_input(false)
	scene.get_node("CanvasLayer1").show()
	await process_frame
	var interaction: Interaction = scene.get_node("World/Interaction")
	var picker: Control = scene.get_node_or_null("CanvasLayer1/BuildPicker")
	if picker == null or picker.get_child_count() != 8 or not picker.visible:
		printerr(
			(
				"FAIL build_picker_switches_tool: picker %s children %s"
				% [picker, picker.get_child_count() if picker else null]
			)
		)
		fail += 1
	interaction.set_mode(Interaction.Mode.INTERACT)
	await process_frame
	if picker == null or not picker.visible:
		printerr("FAIL build_picker_switches_tool: picker hidden in interact")
		fail += 1
	if interaction.build.tool != BuildPlacement.Tool.CUT:
		printerr("FAIL build_picker_switches_tool: default tool %s" % interaction.build.tool)
		fail += 1
	interaction.build.set_tool(BuildPlacement.Tool.PLANK)
	if interaction.build.tool != BuildPlacement.Tool.PLANK:
		printerr("FAIL build_picker_switches_tool: set_tool did not stick")
		fail += 1
	interaction.set_mode(Interaction.Mode.COMBAT)
	await process_frame
	if picker == null or not picker.visible:
		printerr("FAIL build_picker_switches_tool: picker hidden after leaving interact")
		fail += 1
	if interaction.build.tool != BuildPlacement.Tool.CUT:
		printerr("FAIL build_picker_switches_tool: combat did not reset to Cut")
		fail += 1
	scene.queue_free()
	await process_frame
	if fail == 0:
		print("PASS test_build_picker_switches_tool")
	return fail


func _shore_run(world, minimum: int = 2) -> Dictionary:
	## `{shore, water_run}` for at least `minimum` water cells east of land near the origin.
	var land := func(c: Vector2i) -> bool:
		return not world.has_bridge(c) and world.ground_is_walkable(world.predict_cell(c)[0])
	for s in [11, 42, 7, 1, 99, 3, 5]:
		world.apply_map_params(_spawn_params(s, 0.0))
		world.generate_chunk(Vector2(0, 0))
		for cell in world.get_used_cells(0):
			if not land.call(cell):
				continue
			var run: Array[Vector2i] = []
			for i in range(1, maxi(3, minimum) + 1):
				var w: Vector2i = cell + Vector2i(i, 0)
				if world.predict_cell(w)[0] != TileCatalog.WATER or world.has_bridge(w):
					break
				run.append(w)
			if run.size() >= minimum:
				return {"shore": cell, "water_run": run}
	return {}


func _boot_interact_scene(world_seed_finder: bool = true, shore_minimum: int = 2) -> Dictionary:
	var scene = load("res://flagoria_main.tscn").instantiate()
	root.add_child(scene)
	var menu: Node = scene.get_node("CanvasLayer2/MainMenu")
	menu.hide()
	menu.set_process_unhandled_input(false)
	scene.get_node("CanvasLayer1").show()
	var world = scene.get_node("World/worldMap")
	var found := {}
	if world_seed_finder:
		found = _shore_run(world, shore_minimum)
	await process_frame
	var interaction: Interaction = scene.get_node("World/Interaction")
	var inventory: Inventory = scene.get_node("Inventory")
	var player = load("res://Scripts/player/character_body_2d.tscn").instantiate()
	player.name = str(scene.multiplayer.get_unique_id())
	var place_cell: Vector2i = found.get("shore", Vector2i(10, 10))
	player.position = world.to_global(world.map_to_local(place_cell))
	scene.get_node("World").add_child(player)
	interaction.bind(player)
	await process_frame
	return {
		"scene": scene,
		"world": world,
		"interaction": interaction,
		"inventory": inventory,
		"player": player,
		"found": found,
	}


func _cell_vp(interaction: Interaction, world, cell: Vector2i) -> Vector2:
	return interaction.get_canvas_transform() * world.to_global(world.map_to_local(cell))


func _test_build_preview_starts_centered_and_moves_relatively() -> int:
	print("-- test_build_preview_starts_centered_and_moves_relatively")
	var ctx := await _boot_interact_scene(false)
	var interaction: Interaction = ctx["interaction"]
	var map: TileMap = ctx["world"]
	var viewport := interaction.get_viewport()
	var camera := viewport.get_camera_2d()
	camera.global_position = interaction.cell_center(Vector2i(10, 10))
	camera.force_update_scroll()
	var center := viewport.get_visible_rect().get_center()
	var anchor_pos := _cell_vp(interaction, map, Vector2i(10, 10))
	var step := _cell_vp(interaction, map, Vector2i(11, 10)) - anchor_pos
	var finger := center + Vector2(0, -60)
	var picker: Control = ctx["scene"].get_node("CanvasLayer1/BuildPicker")
	var buildings: Button = ctx["scene"].get_node("CanvasLayer1/BuildingsButton")
	var failures := 0
	for button_name in ["TowerButton", "CastleButton", "GuardButton", "BarracksButton"]:
		buildings.button_pressed = true
		var button: Button = picker.get_node(button_name)
		button.pressed.emit()
		if (
			not interaction.build.cells.has(Vector2i(10, 10))
			or interaction.build.reasons.is_empty()
		):
			printerr("FAIL centered preview: %s did not preview a refusal at center" % button_name)
			failures += 1
		_build_touch(viewport, finger, true)
		_build_drag(viewport, finger, finger + step * 3)
		if (
			not interaction.build.cells.has(Vector2i(13, 10))
			or not interaction.build.cost_viewport.is_equal_approx(anchor_pos + step * 3)
			or interaction.build.reasons.is_empty()
		):
			printerr(
				(
					"FAIL relative preview: %s cells=%s label=%s expected=%s reasons=%s"
					% [
						button_name,
						interaction.build.cells,
						interaction.build.cost_viewport,
						anchor_pos + step * 3,
						interaction.build.reasons,
					]
				)
			)
			failures += 1
		interaction.set_mode(Interaction.Mode.COMBAT)
		_build_touch(viewport, finger + step * 3, false)
		if not interaction.build.cells.is_empty():
			printerr("FAIL centered preview: leaving interact left preview cells")
			failures += 1
	interaction.set_mode(Interaction.Mode.INTERACT)
	for tool in [BuildPlacement.Tool.WALL, BuildPlacement.Tool.PLANK]:
		interaction.build.set_tool(tool)
		_build_touch(viewport, finger, true)
		_build_drag(viewport, finger, finger + step * 2)
		if interaction.build.cells != [Vector2i(10, 10), Vector2i(11, 10), Vector2i(12, 10)]:
			printerr("FAIL relative run: %s cells were %s" % [tool, interaction.build.cells])
			failures += 1
		_build_touch(viewport, finger + step * 2, false, true)
	interaction.set_mode(Interaction.Mode.COMBAT)
	ctx["scene"].queue_free()
	await process_frame
	if failures == 0:
		print("PASS test_build_preview_starts_centered_and_moves_relatively")
	return failures


func _build_touch(viewport: Viewport, point: Vector2, pressed: bool, canceled := false) -> void:
	var event := InputEventScreenTouch.new()
	event.position = point
	event.pressed = pressed
	event.canceled = canceled
	viewport.push_input(event, true)


func _build_drag(viewport: Viewport, from: Vector2, to: Vector2) -> void:
	var event := InputEventScreenDrag.new()
	event.position = to
	event.relative = to - from
	viewport.push_input(event, true)


func _test_build_plank_preview_tint_and_cost() -> int:
	## A snapped plank drag marks valid water cells green and invalid cells
	## red, and the preview cost matches ConstructionPlacer. Time cost: about
	## 0.5 s in tools/verify.sh (~2.2 s alone with --only=).
	print("-- test_build_plank_preview_tint_and_cost")
	var fail := 0
	var ctx := await _boot_interact_scene()
	var found: Dictionary = ctx["found"]
	if found.is_empty():
		printerr("FAIL build_plank_preview_tint_and_cost: no shore run")
		ctx["scene"].queue_free()
		await process_frame
		return 1
	var interaction: Interaction = ctx["interaction"]
	var inventory: Inventory = ctx["inventory"]
	var world = ctx["world"]
	var water_run: Array[Vector2i] = found["water_run"]
	inventory.add(Inventory.WOOD, water_run.size() + 2)
	interaction.set_mode(Interaction.Mode.INTERACT)
	interaction.build.set_tool(BuildPlacement.Tool.PLANK)
	var start := _cell_vp(interaction, world, water_run[0])
	var end := _cell_vp(interaction, world, water_run[water_run.size() - 1])
	interaction.build.update_preview(start, end)
	if interaction.build.cells != water_run:
		printerr(
			(
				"FAIL build_plank_preview_tint_and_cost: cells %s want %s"
				% [interaction.build.cells, water_run]
			)
		)
		fail += 1
	if (
		interaction.build.cell_ok.size() != water_run.size()
		or not interaction.build.cell_ok.all(func(ok: bool) -> bool: return ok)
	):
		printerr("FAIL build_plank_preview_tint_and_cost: cell_ok %s" % [interaction.build.cell_ok])
		fail += 1
	var want_cost := ConstructionPlacer.new(world).cost(BuildCosts.PLANK, water_run)
	if interaction.build.cost != want_cost or not interaction.build.reasons.is_empty():
		printerr(
			(
				"FAIL build_plank_preview_tint_and_cost: cost %d want %d, reasons %s"
				% [interaction.build.cost, want_cost, interaction.build.reasons]
			)
		)
		fail += 1
	# Land cell is invalid (red).
	var shore: Vector2i = found["shore"]
	interaction.build.update_preview(
		_cell_vp(interaction, world, shore), _cell_vp(interaction, world, shore)
	)
	if interaction.build.cell_ok.is_empty() or interaction.build.cell_ok[0]:
		printerr(
			(
				"FAIL build_plank_preview_tint_and_cost: land should be red, ok=%s reasons=%s"
				% [interaction.build.cell_ok, interaction.build.reasons]
			)
		)
		fail += 1
	# Zero wood on a water run: nothing placeable, all red, refusal shown.
	inventory.spend(Inventory.WOOD, inventory.count_of(Inventory.WOOD))
	interaction.build.update_preview(start, end)
	if (
		interaction.build.cell_ok.any(func(ok: bool) -> bool: return ok)
		or ConstructionPlacer.NOT_ENOUGH_WOOD not in interaction.build.reasons
		or interaction.build.cost != 0
	):
		printerr(
			(
				"FAIL build_plank_preview_tint_and_cost: zero wood ok=%s cost=%d reasons=%s"
				% [interaction.build.cell_ok, interaction.build.cost, interaction.build.reasons]
			)
		)
		fail += 1
	ctx["scene"].queue_free()
	await process_frame
	if fail == 0:
		print("PASS test_build_plank_preview_tint_and_cost")
	return fail


func _test_build_cut_mode_unchanged() -> int:
	## With Cut selected, a tap still chops a tree in reach. Time cost: about
	## 0.4 s in tools/verify.sh (~2.1 s alone with --only=).
	print("-- test_build_cut_mode_unchanged")
	var fail := 0
	var scene = load("res://flagoria_main.tscn").instantiate()
	root.add_child(scene)
	var menu: Node = scene.get_node("CanvasLayer2/MainMenu")
	menu.hide()
	menu.set_process_unhandled_input(false)
	scene.get_node("CanvasLayer1").show()
	var world = scene.get_node("World/worldMap")
	world.clear()
	for x in range(-2, 20):
		for y in range(-2, 20):
			world.set_cell(0, Vector2i(x, y), TileCatalog.SOURCE_ID, TileCatalog.GRASS_A)
	world.set_cell(1, Vector2i(10, 6), TileCatalog.SOURCE_ID, TileCatalog.TREE)
	var player = load("res://Scripts/player/character_body_2d.tscn").instantiate()
	player.name = str(scene.multiplayer.get_unique_id())
	player.position = world.to_global(world.map_to_local(Vector2i(10, 10)))
	scene.get_node("World").add_child(player)
	await process_frame
	var interaction: Interaction = scene.get_node("World/Interaction")
	interaction.bind(player)
	var inventory: Inventory = scene.get_node("Inventory")
	var vp: Viewport = scene.get_viewport()
	interaction.set_mode(Interaction.Mode.INTERACT)
	if interaction.build.tool != BuildPlacement.Tool.CUT:
		printerr("FAIL build_cut_mode_unchanged: expected Cut tool")
		fail += 1
	var at := func(cell: Vector2) -> Vector2:
		return interaction.get_canvas_transform() * world.to_global(cell * 16.0)
	var touch := func(pos: Vector2, pressed: bool) -> void:
		var e := InputEventScreenTouch.new()
		e.position = pos
		e.pressed = pressed
		vp.push_input(e, true)
	var want_wood := inventory.count_of(Inventory.WOOD)
	_chop_toward(
		vp,
		interaction,
		player,
		scene.get_node("CanvasLayer1/TouchScreenButton"),
		world.to_global(world.map_to_local(Vector2i(10, 6)))
	)
	interaction.step_chop(1.0)
	var tree_wood := InteractableCatalog.by_id("tree").amount_of(Inventory.WOOD)
	if (
		world.has_tree(Vector2i(10, 6))
		or inventory.count_of(Inventory.WOOD) != want_wood + tree_wood
	):
		printerr(
			(
				"FAIL build_cut_mode_unchanged: tap did not cut (10, 6); wood %d"
				% inventory.count_of(Inventory.WOOD)
			)
		)
		fail += 1
	scene.queue_free()
	await process_frame
	if fail == 0:
		print("PASS test_build_cut_mode_unchanged")
	return fail


func _test_build_plank_drag_places() -> int:
	## A real plank drag through unhandled input places the bridge. Time cost:
	## about 0.6 s in tools/verify.sh (~2.3 s alone with --only=).
	print("-- test_build_plank_drag_places")
	var fail := 0
	var ctx := await _boot_interact_scene(true, 11)
	var found: Dictionary = ctx["found"]
	if found.is_empty():
		printerr("FAIL build_plank_drag_places: no shore run")
		ctx["scene"].queue_free()
		await process_frame
		return 1
	var interaction: Interaction = ctx["interaction"]
	var inventory: Inventory = ctx["inventory"]
	var world = ctx["world"]
	var scene = ctx["scene"]
	var water_run: Array[Vector2i] = found["water_run"]
	inventory.add(Inventory.WOOD, water_run.size())
	var before := inventory.count_of(Inventory.WOOD)
	interaction.set_mode(Interaction.Mode.INTERACT)
	interaction.build.set_tool(BuildPlacement.Tool.PLANK)
	var vp: Viewport = scene.get_viewport()
	var shore: Vector2i = found["shore"]
	var camera := vp.get_camera_2d()
	camera.global_position = interaction.cell_center(shore)
	camera.force_update_scroll()
	var center := vp.get_visible_rect().get_center()
	var start := center + Vector2(0, -60)
	var end := start + _cell_vp(interaction, world, water_run.back()) - center
	_build_touch(vp, start, true)
	_build_drag(vp, start, end)
	if (
		interaction.build.cells.front() != shore
		or _preview_green(interaction.build) != water_run.slice(0, 10)
		or interaction.build.cost != 10
	):
		printerr("FAIL build_plank_drag_places: expected 10 green cells after the centered shore")
		fail += 1
	_build_touch(vp, end, false)
	await process_frame
	var placed := water_run.filter(func(c: Vector2i) -> bool: return world.has_bridge(c))
	if placed != water_run.slice(0, 10):
		printerr(
			"FAIL build_plank_drag_places: expected the first 10 cells placed, got %s" % [placed]
		)
		fail += 1
	var player: Node2D = ctx["player"]
	if not placed.any(
		func(c: Vector2i) -> bool:
			return (
				player.global_position.distance_to(interaction.cell_center(c)) > Interaction.REACH
			)
	):
		printerr("FAIL build_plank_drag_places: no placed cell beyond normal reach")
		fail += 1
	if inventory.count_of(Inventory.WOOD) != before - 10:
		printerr(
			(
				"FAIL build_plank_drag_places: wood %d -> %d"
				% [before, inventory.count_of(Inventory.WOOD)]
			)
		)
		fail += 1
	scene.queue_free()
	await process_frame
	if fail == 0:
		print("PASS test_build_plank_drag_places")
	return fail


func _shore_run_min(world, want: int) -> Dictionary:
	## `{shore, water_run}` with at least `want` water cells off land (H or V).
	var land := func(c: Vector2i) -> bool:
		return not world.has_bridge(c) and world.ground_is_walkable(world.predict_cell(c)[0])
	var dirs: Array[Vector2i] = [
		Vector2i(1, 0),
		Vector2i(-1, 0),
		Vector2i(0, 1),
		Vector2i(0, -1),
	]
	for s in range(1, 120):
		world.apply_map_params(_spawn_params(s, 0.0))
		world.generate_chunk(Vector2(0, 0))
		for cell in world.get_used_cells(0):
			if not land.call(cell):
				continue
			for d in dirs:
				var run: Array[Vector2i] = []
				for i in range(1, want + 6):
					var w: Vector2i = cell + d * i
					if world.predict_cell(w)[0] != TileCatalog.WATER or world.has_bridge(w):
						break
					run.append(w)
				if run.size() >= want:
					return {"shore": cell, "water_run": run.slice(0, want)}
	return {}


func _boot_shore_min(want: int) -> Dictionary:
	var scene = load("res://flagoria_main.tscn").instantiate()
	root.add_child(scene)
	var menu: Node = scene.get_node("CanvasLayer2/MainMenu")
	menu.hide()
	menu.set_process_unhandled_input(false)
	scene.get_node("CanvasLayer1").show()
	var world = scene.get_node("World/worldMap")
	var found := _shore_run_min(world, want)
	await process_frame
	var interaction: Interaction = scene.get_node("World/Interaction")
	var inventory: Inventory = scene.get_node("Inventory")
	var player = load("res://Scripts/player/character_body_2d.tscn").instantiate()
	player.name = str(scene.multiplayer.get_unique_id())
	var place_cell: Vector2i = found.get("shore", Vector2i(10, 10))
	player.position = world.to_global(world.map_to_local(place_cell))
	scene.get_node("World").add_child(player)
	interaction.bind(player)
	await process_frame
	return {
		"scene": scene,
		"world": world,
		"interaction": interaction,
		"inventory": inventory,
		"player": player,
		"found": found,
	}


func _preview_green(build: BuildPlacement) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for i in build.cells.size():
		if build.cell_ok[i]:
			out.append(build.cells[i])
	return out


func _test_build_preview_matches_commit_short_wood() -> int:
	## With 1 wood and a 5-cell water drag, preview greens exactly the 1 cell
	## commit will place and shows cost 1; the rest is red. Time cost: about
	## 0.2 s in tools/verify.sh (~1.9 s alone with --only=).
	print("-- test_build_preview_matches_commit_short_wood")
	var fail := 0
	var ctx: Dictionary = await _boot_shore_min(5)
	var found: Dictionary = ctx["found"]
	if found.is_empty():
		printerr("FAIL preview_matches_commit_short_wood: no 5-cell shore run")
		ctx["scene"].queue_free()
		await process_frame
		return 1
	var interaction: Interaction = ctx["interaction"]
	var inventory: Inventory = ctx["inventory"]
	var world = ctx["world"]
	var drag: Array[Vector2i] = found["water_run"]
	inventory.add(Inventory.WOOD, 1)
	interaction.set_mode(Interaction.Mode.INTERACT)
	interaction.build.set_tool(BuildPlacement.Tool.PLANK)
	var start := _cell_vp(interaction, world, drag[0])
	var end := _cell_vp(interaction, world, drag[drag.size() - 1])
	interaction.build.update_preview(start, end)
	var green := _preview_green(interaction.build)
	var preview_cost := interaction.build.cost
	if green != [drag[0]] or preview_cost != 1 or not interaction.build.reasons.is_empty():
		printerr(
			(
				"FAIL preview_matches_commit_short_wood: green %s cost %d reasons %s cell_ok %s"
				% [green, preview_cost, interaction.build.reasons, interaction.build.cell_ok]
			)
		)
		fail += 1
	var before := inventory.count_of(Inventory.WOOD)
	if not interaction.build.commit():
		printerr("FAIL preview_matches_commit_short_wood: commit false")
		fail += 1
	var placed: Array[Vector2i] = []
	for cell in drag:
		if world.has_bridge(cell):
			placed.append(cell)
	if placed != green:
		printerr(
			"FAIL preview_matches_commit_short_wood: placed %s want green %s" % [placed, green]
		)
		fail += 1
	if inventory.count_of(Inventory.WOOD) != before - preview_cost:
		printerr(
			(
				"FAIL preview_matches_commit_short_wood: wood %d -> %d (cost %d)"
				% [before, inventory.count_of(Inventory.WOOD), preview_cost]
			)
		)
		fail += 1
	ctx["scene"].queue_free()
	await process_frame
	if fail == 0:
		print("PASS test_build_preview_matches_commit_short_wood")
	return fail


func _test_build_preview_matches_commit_mid_invalid() -> int:
	## An occupied cell mid-run: preview greens exactly the water prefix commit
	## will place and shows that cost; cells from the occupied one onward are
	## red. Time cost: about 0.2 s in tools/verify.sh (~1.9 s alone with --only=).
	print("-- test_build_preview_matches_commit_mid_invalid")
	var fail := 0
	var ctx: Dictionary = await _boot_shore_min(5)
	var found: Dictionary = ctx["found"]
	if found.is_empty():
		printerr("FAIL preview_matches_commit_mid_invalid: no 5-cell shore run")
		ctx["scene"].queue_free()
		await process_frame
		return 1
	var interaction: Interaction = ctx["interaction"]
	var inventory: Inventory = ctx["inventory"]
	var world = ctx["world"]
	var drag: Array[Vector2i] = found["water_run"]
	# Force-occupy mid cell without going through adjacency (mid alone is not
	# next to land). Same check commit/preview see: has_bridge(cell).
	var mid_cell: Vector2i = drag[2]
	world.set_bridge_cell(mid_cell, TileCatalog.TILES["BRIDGE_PLANK_H_WATER"]["atlas"])
	inventory.add(Inventory.WOOD, 10)
	interaction.set_mode(Interaction.Mode.INTERACT)
	interaction.build.set_tool(BuildPlacement.Tool.PLANK)
	var start := _cell_vp(interaction, world, drag[0])
	var end := _cell_vp(interaction, world, drag[drag.size() - 1])
	interaction.build.update_preview(start, end)
	var green := _preview_green(interaction.build)
	var preview_cost := interaction.build.cost
	var want_green: Array[Vector2i] = [drag[0], drag[1]]
	if (
		green != want_green
		or preview_cost != want_green.size()
		or not interaction.build.reasons.is_empty()
	):
		printerr(
			(
				"FAIL preview_matches_commit_mid_invalid: green %s cost %d reasons %s cell_ok %s"
				% [green, preview_cost, interaction.build.reasons, interaction.build.cell_ok]
			)
		)
		fail += 1
	for i in range(2, drag.size()):
		if i < interaction.build.cell_ok.size() and interaction.build.cell_ok[i]:
			printerr("FAIL preview_matches_commit_mid_invalid: cell %d should be red" % i)
			fail += 1
	var before := inventory.count_of(Inventory.WOOD)
	if not interaction.build.commit():
		printerr("FAIL preview_matches_commit_mid_invalid: commit false")
		fail += 1
	var placed_now: Array[Vector2i] = []
	for cell in want_green:
		if world.has_bridge(cell):
			placed_now.append(cell)
	if placed_now != green:
		printerr(
			"FAIL preview_matches_commit_mid_invalid: placed %s want green %s" % [placed_now, green]
		)
		fail += 1
	if inventory.count_of(Inventory.WOOD) != before - preview_cost:
		printerr(
			(
				"FAIL preview_matches_commit_mid_invalid: wood %d -> %d (cost %d)"
				% [before, inventory.count_of(Inventory.WOOD), preview_cost]
			)
		)
		fail += 1
	ctx["scene"].queue_free()
	await process_frame
	if fail == 0:
		print("PASS test_build_preview_matches_commit_mid_invalid")
	return fail


func _test_build_preview_cache_invalidates_on_wood() -> int:
	## Same drag cells after wood changes must recompute (not keep a green
	## skip-cache). Time cost: about 0.5 s in tools/verify.sh (~2.2 s alone
	## with --only=build_preview_cache_invalidates_on_wood).
	print("-- test_build_preview_cache_invalidates_on_wood")
	var fail := 0
	var ctx := await _boot_interact_scene()
	var found: Dictionary = ctx["found"]
	if found.is_empty():
		printerr("FAIL preview_cache_invalidates_on_wood: no shore run")
		ctx["scene"].queue_free()
		await process_frame
		return 1
	var interaction: Interaction = ctx["interaction"]
	var inventory: Inventory = ctx["inventory"]
	var world = ctx["world"]
	var water_run: Array[Vector2i] = found["water_run"]
	inventory.add(Inventory.WOOD, water_run.size() + 2)
	interaction.set_mode(Interaction.Mode.INTERACT)
	interaction.build.set_tool(BuildPlacement.Tool.PLANK)
	var start := _cell_vp(interaction, world, water_run[0])
	var end := _cell_vp(interaction, world, water_run[water_run.size() - 1])
	interaction.build.update_preview(start, end)
	if (
		interaction.build.cell_ok.is_empty()
		or not interaction.build.cell_ok.all(func(ok: bool) -> bool: return ok)
	):
		printerr(
			(
				"FAIL preview_cache_invalidates_on_wood: expected green before spend, ok=%s"
				% [interaction.build.cell_ok]
			)
		)
		fail += 1
	inventory.spend(Inventory.WOOD, inventory.count_of(Inventory.WOOD))
	# Same cells as the green preview — must not skip.
	interaction.build.update_preview(start, end)
	if (
		interaction.build.cell_ok.any(func(ok: bool) -> bool: return ok)
		or ConstructionPlacer.NOT_ENOUGH_WOOD not in interaction.build.reasons
		or interaction.build.cost != 0
	):
		printerr(
			(
				"FAIL preview_cache_invalidates_on_wood: after zero wood ok=%s cost=%d reasons=%s"
				% [interaction.build.cell_ok, interaction.build.cost, interaction.build.reasons]
			)
		)
		fail += 1
	ctx["scene"].queue_free()
	await process_frame
	if fail == 0:
		print("PASS test_build_preview_cache_invalidates_on_wood")
	return fail


func _test_build_picker_buttons() -> int:
	## Each tool is available through Buildings both offline and on an ENet client.
	print("-- test_build_picker_buttons")
	var fail := 0
	var scene = load("res://flagoria_main.tscn").instantiate()
	root.add_child(scene)
	scene.get_node("CanvasLayer2/MainMenu").hide()
	var hud: CanvasLayer = scene.get_node("CanvasLayer1")
	hud.show()
	var interaction: Interaction = scene.get_node("World/Interaction")
	interaction.set_mode(Interaction.Mode.INTERACT)
	var buildings: Button = hud.get_node("BuildingsButton")
	var picker: Control = hud.get_node("BuildPicker")
	var tools := {
		"PlankButton": BuildPlacement.Tool.PLANK,
		"TowerButton": BuildPlacement.Tool.TOWER,
		"CastleButton": BuildPlacement.Tool.CASTLE,
		"GuardButton": BuildPlacement.Tool.GUARD,
		"BarracksButton": BuildPlacement.Tool.BARRACKS,
		"MineButton": BuildPlacement.Tool.MINE,
		"WallButton": BuildPlacement.Tool.WALL,
		"DemolishButton": BuildPlacement.Tool.DEMOLISH,
	}
	var peer := ENetMultiplayerPeer.new()
	var api := SceneMultiplayer.new()
	for online in [false, true]:
		if online:
			buildings.button_pressed = true
			picker.get_node("PlankButton").pressed.emit()
			buildings.button_pressed = true
			if peer.create_client("127.0.0.1", 1) != OK:
				printerr("FAIL build_picker_buttons: could not start ENet client")
				fail += 1
				break
			api.multiplayer_peer = peer
			set_multiplayer(api, scene.get_path())
			await process_frame
			await process_frame
			if not buildings.button_pressed or interaction.build.tool != BuildPlacement.Tool.PLANK:
				printerr("FAIL build_picker_buttons: multiplayer closed Buildings or cleared Plank")
				fail += 1
		fail += _check_picker_buttons(buildings, picker, interaction.build, tools, online)
	api.multiplayer_peer = null
	peer.close()
	set_multiplayer(null, scene.get_path())
	scene.queue_free()
	await process_frame
	if fail == 0:
		print("PASS test_build_picker_buttons")
	return fail


func _check_picker_buttons(
	buildings: Button, picker: Control, build: BuildPlacement, tools: Dictionary, online: bool
) -> int:
	var fail := 0
	buildings.button_pressed = true
	for button_name in tools:
		var button := picker.get_node_or_null(button_name) as Button
		if button == null or not button.is_visible_in_tree() or button.disabled:
			printerr(
				"FAIL build_picker_buttons: %s unavailable (multiplayer=%s)" % [button_name, online]
			)
			fail += 1
	for button_name in tools:
		buildings.button_pressed = true
		var button := picker.get_node_or_null(button_name) as Button
		if button == null or not button.is_visible_in_tree() or button.disabled:
			continue
		button.pressed.emit()
		if build.tool != tools[button_name] or not build.tracks_pointer():
			printerr(
				(
					"FAIL build_picker_buttons: %s did not select its tool (multiplayer=%s)"
					% [button_name, online]
				)
			)
			fail += 1
	return fail
