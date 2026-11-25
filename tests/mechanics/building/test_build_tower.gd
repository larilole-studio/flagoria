extends "res://tests/helpers/test_helpers.gd"
## Interact-mode Tower picker, preview and place (#273).


func _clear_tower_anchor(world) -> Variant:
	var s: Structure = StructurePlacer.load_named("tower_wood")
	if s == null:
		return null
	for seed_value in [11, 42, 99, 7, 1, 3, 5]:
		world.apply_map_params(_spawn_params(seed_value, 0.0))
		world.generate_chunk(Vector2(0, 0))
		for cell: Vector2i in world.get_used_cells(0):
			var cells: Array = StructurePlacer.footprint(s, cell).keys()
			if cells.all(
				func(c): return world.get_cell_source_id(0, c) != -1 and world.predicted_clear(c)
			):
				return cell
	return null


func _boot_tower_scene() -> Dictionary:
	var scene = load("res://flagoria_main.tscn").instantiate()
	root.add_child(scene)
	var menu: Node = scene.get_node("CanvasLayer2/MainMenu")
	menu.hide()
	menu.set_process_unhandled_input(false)
	scene.get_node("CanvasLayer1").show()
	var world = scene.get_node("World/worldMap")
	var anchor: Variant = _clear_tower_anchor(world)
	await process_frame
	var interaction: Interaction = scene.get_node("World/Interaction")
	var inventory: Inventory = scene.get_node("Inventory")
	var player = load("res://Scripts/player/character_body_2d.tscn").instantiate()
	player.name = str(scene.multiplayer.get_unique_id())
	var place_cell: Vector2i = anchor if anchor != null else Vector2i(10, 10)
	# Stand just outside the footprint so the player does not occupy it.
	player.position = world.to_global(world.map_to_local(place_cell + Vector2i(0, 3)))
	scene.get_node("World").add_child(player)
	interaction.bind(player)
	await process_frame
	return {
		"scene": scene,
		"world": world,
		"interaction": interaction,
		"inventory": inventory,
		"player": player,
		"anchor": anchor,
	}


func _cell_vp(interaction: Interaction, world, cell: Vector2i) -> Vector2:
	return interaction.get_canvas_transform() * world.to_global(world.map_to_local(cell))


func _test_build_tower_preview_matches_commit() -> int:
	## Green footprint and cost 10 match what commit places; red when refused.
	## Time cost: about 0.5 s in tools/verify.sh (~2.2 s alone with --only=).
	print("-- test_build_tower_preview_matches_commit")
	var fail := 0
	var ctx := await _boot_tower_scene()
	var anchor: Variant = ctx["anchor"]
	if anchor == null:
		printerr("FAIL build_tower_preview_matches_commit: no clear anchor")
		ctx["scene"].queue_free()
		await process_frame
		return 1
	var interaction: Interaction = ctx["interaction"]
	var inventory: Inventory = ctx["inventory"]
	var world = ctx["world"]
	inventory.add(Inventory.WOOD, 10)
	interaction.set_mode(Interaction.Mode.INTERACT)
	interaction.build.set_tool(BuildPlacement.Tool.TOWER)
	var vp := _cell_vp(interaction, world, anchor)
	interaction.build.update_preview(vp, vp)
	var s: Structure = StructurePlacer.load_named("tower_wood")
	var foot: Array = StructurePlacer.footprint(s, anchor).keys()
	if (
		interaction.build.cells.size() != foot.size()
		or not interaction.build.cell_ok.all(func(ok: bool) -> bool: return ok)
		or interaction.build.cost != 10
		or not interaction.build.reasons.is_empty()
	):
		printerr(
			(
				"FAIL build_tower_preview_matches_commit: cells %s ok %s cost %d reasons %s"
				% [
					interaction.build.cells,
					interaction.build.cell_ok,
					interaction.build.cost,
					interaction.build.reasons
				]
			)
		)
		fail += 1
	if not interaction.build.commit():
		printerr("FAIL build_tower_preview_matches_commit: commit false")
		fail += 1
	if world.placed_structures().is_empty() or inventory.count_of(Inventory.WOOD) != 0:
		printerr(
			(
				"FAIL build_tower_preview_matches_commit: after commit structs %s wood %d"
				% [world.placed_structures(), inventory.count_of(Inventory.WOOD)]
			)
		)
		fail += 1
	# Zero wood: all red, cost 0, refusal.
	inventory.add(Inventory.WOOD, 0)
	var clear2: Variant = null
	for cell: Vector2i in world.get_used_cells(0):
		var cells: Array = StructurePlacer.footprint(s, cell).keys()
		if cells.all(
			func(c): return world.predicted_clear(c) and not world._structures.has_cell(c)
		):
			clear2 = cell
			break
	if clear2 != null:
		var vp2 := _cell_vp(interaction, world, clear2)
		interaction.build.set_tool(BuildPlacement.Tool.TOWER)
		interaction.build.update_preview(vp2, vp2)
		if (
			interaction.build.cell_ok.any(func(ok: bool) -> bool: return ok)
			or interaction.build.cost != 0
			or ConstructionPlacer.NOT_ENOUGH_WOOD not in interaction.build.reasons
		):
			printerr(
				(
					"FAIL build_tower_preview_matches_commit: zero wood ok=%s cost=%d reasons=%s"
					% [interaction.build.cell_ok, interaction.build.cost, interaction.build.reasons]
				)
			)
			fail += 1
	ctx["scene"].queue_free()
	await process_frame
	if fail == 0:
		print("PASS test_build_tower_preview_matches_commit")
	return fail


func _test_build_tower_drag_places_and_demolish_taps() -> int:
	## Tower commits a relative drag. Demolish commits only an absolute tap.
	print("-- test_build_tower_drag_places_and_demolish_taps")
	var fail := 0
	var ctx := await _boot_tower_scene()
	var anchor: Variant = ctx["anchor"]
	if anchor == null:
		printerr("FAIL build_tower_tap_places: no clear anchor")
		ctx["scene"].queue_free()
		await process_frame
		return 1
	var interaction: Interaction = ctx["interaction"]
	var inventory: Inventory = ctx["inventory"]
	var world = ctx["world"]
	var scene = ctx["scene"]
	inventory.add(Inventory.WOOD, 10)
	interaction.set_mode(Interaction.Mode.INTERACT)
	interaction.build.set_tool(BuildPlacement.Tool.TOWER)
	var viewport: Viewport = scene.get_viewport()
	var middle := viewport.get_visible_rect().get_center()
	var center_cell: Vector2i = world.local_to_map(world.to_local(interaction.to_world(middle)))
	var target := _cell_vp(interaction, world, anchor)
	var finger := middle + Vector2(0, -60)
	var end := finger + target - _cell_vp(interaction, world, center_cell)
	var drag := InputEventScreenDrag.new()
	drag.position = end
	drag.relative = end - finger
	for canceled in [true, false]:
		_tower_touch(viewport, finger, true)
		viewport.push_input(drag, true)
		_tower_touch(viewport, end, false, canceled)
		if (
			canceled
			and (
				not world.placed_structures().is_empty() or inventory.count_of(Inventory.WOOD) != 10
			)
		):
			printerr("FAIL tower drag: cancel placed a tower or spent wood")
			fail += 1
	await process_frame
	if world.placed_structures().is_empty() or inventory.count_of(Inventory.WOOD) != 0:
		printerr(
			(
				"FAIL build_tower_tap_places: structs %s wood %d"
				% [world.placed_structures(), inventory.count_of(Inventory.WOOD)]
			)
		)
		fail += 1
	interaction.build.set_tool(BuildPlacement.Tool.DEMOLISH)
	if not interaction.build.cells.is_empty():
		printerr("FAIL demolish tap: selecting the tool showed a preview")
		fail += 1
	_tower_touch(viewport, target, true)
	if not interaction.build.cells.has(anchor) or interaction.build.cost != 5:
		printerr("FAIL demolish tap: expected the tapped tower and its refund")
		fail += 1
	drag.position = target + Vector2(30, 0)
	drag.relative = Vector2(30, 0)
	viewport.push_input(drag, true)
	_tower_touch(viewport, drag.position, false)
	if world.placed_structures().is_empty():
		printerr("FAIL demolish tap: a drag removed the tower")
		fail += 1
	_tower_touch(viewport, target, true)
	_tower_touch(viewport, target, false)
	if not world.placed_structures().is_empty() or inventory.count_of(Inventory.WOOD) != 5:
		printerr("FAIL demolish tap: the tap did not remove the tower and refund 5 wood")
		fail += 1
	scene.queue_free()
	await process_frame
	if fail == 0:
		print("PASS test_build_tower_drag_places_and_demolish_taps")
	return fail


func _tower_touch(viewport: Viewport, point: Vector2, pressed: bool, canceled := false) -> void:
	var touch := InputEventScreenTouch.new()
	touch.position = point
	touch.pressed = pressed
	touch.canceled = canceled
	viewport.push_input(touch, true)


func _test_build_tower_out_of_reach() -> int:
	## A clear tower anchor beyond reach is red with the correct reason,
	## costs zero and cannot commit; moving into reach re-enables placement.
	print("-- test_build_tower_out_of_reach")
	var ctx := await _boot_tower_scene()
	if ctx["anchor"] == null:
		printerr("FAIL build_tower_out_of_reach: no clear anchor")
		ctx["scene"].queue_free()
		await process_frame
		return 1
	var fail := 0
	var interaction: Interaction = ctx["interaction"]
	var inventory: Inventory = ctx["inventory"]
	var world = ctx["world"]
	var player = ctx["player"]
	var anchor: Vector2i = ctx["anchor"]
	var near: Vector2 = player.position
	inventory.add(Inventory.WOOD, 10)
	interaction.set_mode(Interaction.Mode.INTERACT)
	interaction.build.set_tool(BuildPlacement.Tool.TOWER)
	# Keep terrain and inventory valid: only the anchor's reach changes.
	player.position = world.to_global(world.map_to_local(anchor + Vector2i(0, 10)))
	var vp := _cell_vp(interaction, world, anchor)
	interaction.build.update_preview(vp, vp)
	if (
		interaction.in_reach(anchor)
		or interaction.build.reasons != ["out of reach"]
		or interaction.build.cell_ok.any(func(ok: bool) -> bool: return ok)
		or interaction.build.cost != 0
	):
		printerr(
			(
				"FAIL build_tower_out_of_reach: reasons %s, ok %s, cost %d"
				% [interaction.build.reasons, interaction.build.cell_ok, interaction.build.cost]
			)
		)
		fail += 1
	if (
		interaction.build.commit()
		or inventory.count_of(Inventory.WOOD) != 10
		or not world.placed_structures().is_empty()
	):
		printerr("FAIL build_tower_out_of_reach: refused tower placed or spent wood")
		fail += 1
	player.position = near
	vp = _cell_vp(interaction, world, anchor)
	interaction.build.update_preview(vp, vp)
	if (
		not interaction.build.reasons.is_empty()
		or interaction.build.cost != 10
		or not interaction.build.cell_ok.all(func(ok: bool) -> bool: return ok)
	):
		printerr(
			"FAIL build_tower_out_of_reach: moving into reach did not restore the green preview"
		)
		fail += 1
	ctx["scene"].queue_free()
	await process_frame
	if fail == 0:
		print("PASS test_build_tower_out_of_reach")
	return fail


func _test_construction_tower_cached() -> int:
	## Footprint, geometry check and placement reuse the same parsed tower
	## across anchor changes; none mutates the cached definition (#386).
	print("-- test_construction_tower_cached")
	var fail := 0
	var scene = load("res://flagoria_main.tscn").instantiate()
	root.add_child(scene)
	var world = scene.get_node("World/worldMap")
	world.set_process(false)
	var anchor = _clear_tower_anchor(world)
	if anchor == null:
		printerr("FAIL construction_tower_cached: no clear anchor")
		scene.queue_free()
		await process_frame
		return 1
	var placer := ConstructionPlacer.new(world)
	var foot := placer.tower_footprint(anchor)
	var cached: Structure = placer.get("_named").get(BuildCosts.TOWER)
	if cached == null:
		printerr("FAIL construction_tower_cached: footprint did not cache the tower")
		fail += 1
	else:
		var original: Dictionary = StructurePlacer.footprint(cached, Vector2i.ZERO).duplicate(true)
		for offset in [Vector2i.ZERO, Vector2i.LEFT, Vector2i.UP]:
			var at: Vector2i = anchor + offset
			var cells: Array[Vector2i] = [at]
			placer.tower_footprint(at)
			placer.can_place_geometry(BuildCosts.TOWER, cells)
			if placer.get("_named").get(BuildCosts.TOWER) != cached:
				printerr("FAIL construction_tower_cached: anchor change replaced the cached tower")
				fail += 1
		var inventory: Inventory = scene.get_node("Inventory")
		inventory.add(Inventory.WOOD, 10)
		var one: Array[Vector2i] = [anchor]
		if (
			not placer.place(BuildCosts.TOWER, one, inventory)
			or placer.get("_named").get(BuildCosts.TOWER) != cached
			or inventory.count_of(Inventory.WOOD) != 0
		):
			printerr("FAIL construction_tower_cached: placement did not reuse the cached tower")
			fail += 1
		if (
			original != StructurePlacer.footprint(cached, Vector2i.ZERO)
			or foot != placer.tower_footprint(anchor)
		):
			printerr("FAIL construction_tower_cached: preview or placement mutated the definition")
			fail += 1
	scene.queue_free()
	await process_frame
	if fail == 0:
		print("PASS test_construction_tower_cached")
	return fail
