extends "res://tests/helpers/test_helpers.gd"

const SIZES := [Vector2i(2400, 1080), Vector2i(1920, 1080), Vector2i(1600, 720), Vector2i(2048, 1536)]


func _test_hud_no_overlap() -> int:
	print("-- test_hud_no_overlap")
	var original_size := root.size
	var layout = root.get_node("HudLayout")
	var original_path: String = layout.save_path
	layout.save_path = "user://test_hud_no_overlap.cfg"
	layout.reset_to_defaults()
	var scene: Node = load("res://flagoria_main.tscn").instantiate()
	root.add_child(scene)
	var menu: Control = scene.get_node("CanvasLayer2/MainMenu")
	menu.hide()
	menu.set_process_unhandled_input(false)
	var hud: CanvasLayer = scene.get_node("CanvasLayer1")
	hud.show()
	scene.world_params = _spawn_params(49, 0.003)
	scene.get_node("World/worldMap").apply_map_params(scene.world_params)
	await process_frame
	scene.add_player(scene.multiplayer.get_unique_id())
	await process_frame
	await process_frame

	var fail := 0
	var sizes := SIZES.duplicate()
	var orientation: int = ProjectSettings.get_setting("display/window/handheld/orientation")
	if orientation not in [DisplayServer.SCREEN_LANDSCAPE, DisplayServer.SCREEN_REVERSE_LANDSCAPE,
			DisplayServer.SCREEN_SENSOR_LANDSCAPE]:
		sizes.append(Vector2i(390, 844))
	for size in sizes:
		root.size = size
		await process_frame
		await process_frame
		fail += _check_states(hud, size, false)

	layout.edit_begin(hud)
	if not layout.try_place("attack", 0.75, 0.63, 1.0, hud):
		printerr("FAIL hud_no_overlap: could not move Attack for the custom layout")
		fail += 1
	layout.save_to_disk()
	layout.edit_end()
	layout.forget_memory()
	layout.load_from_disk()
	if not layout.uses_custom():
		printerr("FAIL hud_no_overlap: custom layout did not load")
		fail += 1
	layout.apply(hud)
	fail += _check_states(hud, sizes.back(), true)

	scene.queue_free()
	await process_frame
	root.size = original_size
	layout.reset_to_defaults()
	layout.save_path = original_path
	layout.load_from_disk()
	if fail == 0:
		print("PASS test_hud_no_overlap")
	return fail


func _check_states(hud: CanvasLayer, size: Vector2i, custom: bool) -> int:
	var label := "%dx%d %s" % [size.x, size.y, "custom" if custom else "stock"]
	var fail := _check_rects(hud, label + " default")
	var buildings: BaseButton = hud.get_node("BuildingsButton")
	buildings.set_pressed(true)
	fail += _check_rects(hud, label + " Buildings open", hud.get_node("BuildPicker").visible)
	buildings.set_pressed(false)
	if custom:
		return fail
	var map_button: BaseButton = hud.get_node("MinimapButton")
	map_button.pressed.emit()
	fail += _check_rects(hud, label + " minimap open", hud.get_node("MinimapPanel").visible)
	map_button.pressed.emit()
	var scores: BaseButton = _hud_on_canvas(hud.get_parent(), "ScoreboardToggle")
	scores.pressed.emit()
	fail += _check_rects(hud, label + " scoreboard open", hud.get_node("ScoreboardPanel").is_open())
	scores.pressed.emit()
	var wheel := hud.get_node_or_null("ToolWheel") as ToolWheel
	if wheel != null:
		var event := InputEventAction.new()
		event.action = &"tool_wheel"
		event.pressed = true
		root.push_input(event, true)
		fail += _check_rects(hud, label + " tool wheel open", wheel.is_open())
		event.pressed = false
		root.push_input(event, true)
	return fail


func _check_rects(hud: CanvasLayer, label: String, state_open := true) -> int:
	if not state_open:
		printerr("FAIL hud_no_overlap %s: panel did not open" % label)
		return 1
	var targets := {}
	_collect_targets(hud, targets)
	var view := hud.get_viewport().get_visible_rect()
	var nodes := targets.keys()
	var fail := 0
	for i in nodes.size():
		var first: Node = nodes[i]
		var rect: Rect2 = targets[first]
		if not rect.has_area() or not view.encloses(rect):
			printerr("FAIL hud_no_overlap %s: %s rect %s outside viewport %s"
					% [label, first.name, rect, view])
			fail += 1
		for j in range(i + 1, nodes.size()):
			var second: Node = nodes[j]
			var other: Rect2 = targets[second]
			if rect.intersection(other).has_area():
				printerr("FAIL hud_no_overlap %s: %s %s overlaps %s %s"
						% [label, first.name, rect, second.name, other])
				fail += 1
	return fail


func _collect_targets(parent: Node, targets: Dictionary) -> void:
	for node in parent.get_children():
		if node is CanvasItem and (not node.is_visible_in_tree() or node.is_queued_for_deletion()):
			continue
		# The wheel options ignore pointer input. The wheel selects by drag angle.
		if node is MapWoodButton or (node is BaseButton and not node.disabled
				and node.mouse_filter != Control.MOUSE_FILTER_IGNORE):
			targets[node] = node.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, node.size)
		elif node.has_method("start_reach"):
			var radius := Vector2.ONE * float(node.start_reach())
			var center: Vector2 = node.get_global_transform_with_canvas().origin
			targets[node] = Rect2(center - radius, radius * 2.0)
			# The joystick knob is drawn with a TouchScreenButton but moves with the stick.
			continue
		elif node is TouchScreenButton:
			var size: Vector2 = node.texture_normal.get_size() if node.texture_normal else Vector2.ZERO
			var rect := Rect2(Vector2.ZERO, size)
			if node.shape != null:
				rect = node.shape.get_rect()
				if node.shape_centered:
					rect.position += size * 0.5
			targets[node] = node.get_global_transform_with_canvas() * rect
		_collect_targets(node, targets)
