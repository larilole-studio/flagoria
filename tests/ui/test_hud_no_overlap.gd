extends "res://tests/helpers/test_helpers.gd"

const HudLayoutDump = preload("res://tools/hud_layout_dump.gd")


func _test_hud_no_overlap() -> int:
	print("-- test_hud_no_overlap")
	var original_size := root.size
	var layout = root.get_node("HudLayout")
	var original_path: String = layout.save_path
	layout.save_path = "user://test_hud_no_overlap.cfg"
	layout.reset_to_defaults()
	var scene := await HudLayoutDump.play_scene(tree)
	var hud: CanvasLayer = scene.get_node("CanvasLayer1")

	var fail := 0
	var sizes := HudLayoutDump.SIZES.duplicate()
	var orientation: int = ProjectSettings.get_setting("display/window/handheld/orientation")
	if orientation not in [DisplayServer.SCREEN_LANDSCAPE, DisplayServer.SCREEN_REVERSE_LANDSCAPE,
			DisplayServer.SCREEN_SENSOR_LANDSCAPE]:
		sizes.append(Vector2i(390, 844))
	for size in sizes:
		await HudLayoutDump.resize(tree, size)
		fail += await _check_states(hud, size, false)

	layout.edit_begin(hud)
	if not layout.try_place("attack", 0.55, 0.58, 1.0, hud):
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
	fail += await _check_states(hud, sizes.back(), true)

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
	var visit := func(state: String, state_open: bool) -> int:
		return _check_rects(hud, label + " " + state, state_open)
	var fail := await HudLayoutDump.visit_states(hud, visit, custom)
	if custom:
		return fail
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
	var targets := HudLayoutDump.collect_targets(hud)
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
