extends "res://tests/helpers/test_helpers.gd"
## Tool wheel: hold or drag selects sword, bow or chop. A short tap swaps
## back. Keys do the same. A headless dedicated host builds no wheel (#574).


func _test_tool_wheel_hold() -> int:
	## A drag opens the half-moon and release arms that tool. A hold with no
	## drag opens on the current tool and release keeps it. The button stays
	## left of Run when a custom layout is active. The wheel does not
	## process every frame. Time cost: about 0.6 s in tools/verify.sh.
	print("-- test_tool_wheel_hold")
	var fail := 0
	var scene = await _scene()
	var wheel: ToolWheel = scene.get_node("CanvasLayer1/ToolWheel")
	var interaction: Interaction = scene.get_node("World/Interaction")
	if wheel.is_processing():
		printerr("FAIL tool_wheel_hold: the wheel runs _process")
		fail += 1
	if not _arc_ok(wheel):
		printerr("FAIL tool_wheel_hold: options are not a half-moon left of the button")
		fail += 1
	var expect := [
		[ToolWheel.Tool.BOW, Interaction.Mode.COMBAT, true],
		[ToolWheel.Tool.CHOP, Interaction.Mode.INTERACT, false],
		[ToolWheel.Tool.SWORD, Interaction.Mode.COMBAT, false],
	]
	for row in expect:
		var which: int = row[0]
		if not await _drag_to(scene, wheel, which):
			printerr("FAIL tool_wheel_hold: drag did not highlight %s" % which)
			fail += 1
			continue
		if wheel.tool != which or interaction.mode != int(row[1]) or wheel.bow_armed() != bool(row[2]) \
				or wheel.is_open():
			printerr("FAIL tool_wheel_hold: tool %s mode %s bow %s open %s, want %s"
					% [wheel.tool, interaction.mode, wheel.bow_armed(), wheel.is_open(), row])
			fail += 1
	var before := wheel.tool
	var center := _center(wheel.get_node("ToolButton"))
	_touch(scene, center, true)
	await create_timer(0.25).timeout
	if not wheel.is_open() or wheel.highlighted() != before or wheel.is_processing():
		printerr("FAIL tool_wheel_hold: hold open %s highlight %s" % [wheel.is_open(), wheel.highlighted()])
		fail += 1
	_touch(scene, center, false)
	await process_frame
	if wheel.tool != before or wheel.is_open():
		printerr("FAIL tool_wheel_hold: a hold with no drag changed the tool to %s" % wheel.tool)
		fail += 1
	fail += _beside_run(scene, "default")
	var layout := root.get_node("HudLayout")
	var run: Control = scene.get_node("CanvasLayer1/RunButton")
	var view: Vector2 = scene.get_viewport().get_visible_rect().size
	layout.set_entry("run", {
		"x": run.position.x / view.x,
		"y": run.position.y / view.y,
		"s": 1.0,
	})
	await process_frame
	await process_frame
	fail += _beside_run(scene, "custom")
	layout.forget_memory()
	_free(scene)
	if fail == 0:
		print("PASS test_tool_wheel_hold")
	return fail


func _test_tool_wheel_keys() -> int:
	## Hold Q and aim with the mouse, up/down and the scroll wheel. Release
	## selects. Keys 1, 2 and 3 select directly. A mouse hold does too.
	## Time cost: about 0.4 s in tools/verify.sh.
	print("-- test_tool_wheel_keys")
	var fail := 0
	var scene = await _scene()
	var wheel: ToolWheel = scene.get_node("CanvasLayer1/ToolWheel")
	var interaction: Interaction = scene.get_node("World/Interaction")
	_key(scene, KEY_Q, true)
	await process_frame
	if not wheel.is_open() or wheel.highlighted() != ToolWheel.Tool.SWORD:
		printerr("FAIL tool_wheel_keys: Q did not open on sword (open %s highlight %s)"
				% [wheel.is_open(), wheel.highlighted()])
		fail += 1
	_key(scene, KEY_DOWN, true)
	await process_frame
	_key(scene, KEY_DOWN, false)
	if wheel.highlighted() != ToolWheel.Tool.BOW:
		printerr("FAIL tool_wheel_keys: down highlight %s" % wheel.highlighted())
		fail += 1
	_key(scene, KEY_DOWN, true)
	await process_frame
	_key(scene, KEY_DOWN, false)
	_key(scene, KEY_UP, true)
	await process_frame
	_key(scene, KEY_UP, false)
	if wheel.highlighted() != ToolWheel.Tool.BOW:
		printerr("FAIL tool_wheel_keys: up highlight %s" % wheel.highlighted())
		fail += 1
	await _wheel(scene, MOUSE_BUTTON_WHEEL_DOWN)
	if wheel.highlighted() != ToolWheel.Tool.CHOP:
		printerr("FAIL tool_wheel_keys: scroll highlight %s" % wheel.highlighted())
		fail += 1
	var sword_at := _center(wheel.get_node("Sword"))
	_motion(scene, sword_at)
	await process_frame
	if wheel.highlighted() != ToolWheel.Tool.SWORD:
		printerr("FAIL tool_wheel_keys: mouse highlight %s" % wheel.highlighted())
		fail += 1
	_key(scene, KEY_Q, false)
	await process_frame
	if wheel.is_open() or wheel.tool != ToolWheel.Tool.SWORD or wheel.bow_armed():
		printerr("FAIL tool_wheel_keys: releasing Q armed %s bow %s" % [wheel.tool, wheel.bow_armed()])
		fail += 1
	_key(scene, KEY_2, true)
	_key(scene, KEY_2, false)
	await process_frame
	if not wheel.bow_armed() or interaction.mode != Interaction.Mode.COMBAT:
		printerr("FAIL tool_wheel_keys: key 2 tool %s mode %s" % [wheel.tool, interaction.mode])
		fail += 1
	_key(scene, KEY_3, true)
	_key(scene, KEY_3, false)
	await process_frame
	if wheel.tool != ToolWheel.Tool.CHOP or interaction.mode != Interaction.Mode.INTERACT or wheel.bow_armed():
		printerr("FAIL tool_wheel_keys: key 3 tool %s mode %s bow %s" % [wheel.tool, interaction.mode, wheel.bow_armed()])
		fail += 1
	_key(scene, KEY_1, true)
	_key(scene, KEY_1, false)
	await process_frame
	if wheel.tool != ToolWheel.Tool.SWORD or interaction.mode != Interaction.Mode.COMBAT or wheel.bow_armed():
		printerr("FAIL tool_wheel_keys: key 1 tool %s mode %s" % [wheel.tool, interaction.mode])
		fail += 1
	var chop_at := _center(wheel.get_node("Chop"))
	var button_at := _center(wheel.get_node("ToolButton"))
	_mouse(scene, button_at, true)
	await process_frame
	_motion(scene, chop_at)
	await process_frame
	_mouse(scene, chop_at, false)
	await process_frame
	if wheel.tool != ToolWheel.Tool.CHOP or interaction.mode != Interaction.Mode.INTERACT or wheel.is_open():
		printerr("FAIL tool_wheel_keys: mouse hold tool %s mode %s open %s"
				% [wheel.tool, interaction.mode, wheel.is_open()])
		fail += 1
	_free(scene)
	if fail == 0:
		print("PASS test_tool_wheel_keys")
	return fail


func _test_tool_wheel_quick_tap() -> int:
	## A tap under 200 ms with no drag swaps to the previous tool. A short
	## drag does not. Time cost: about 0.3 s in tools/verify.sh.
	print("-- test_tool_wheel_quick_tap")
	var fail := 0
	var scene = await _scene()
	var wheel: ToolWheel = scene.get_node("CanvasLayer1/ToolWheel")
	var center := _center(wheel.get_node("ToolButton"))
	_touch(scene, center, true)
	_touch(scene, center, false)
	await process_frame
	if wheel.tool != ToolWheel.Tool.SWORD or wheel.is_open():
		printerr("FAIL tool_wheel_quick_tap: first tap changed %s open %s" % [wheel.tool, wheel.is_open()])
		fail += 1
	_key(scene, KEY_2, true)
	_key(scene, KEY_2, false)
	await process_frame
	_touch(scene, center, true)
	_touch(scene, center, false)
	await process_frame
	if wheel.tool != ToolWheel.Tool.SWORD or wheel.bow_armed():
		printerr("FAIL tool_wheel_quick_tap: tap did not return to sword (%s)" % wheel.tool)
		fail += 1
	_touch(scene, center, true)
	_touch(scene, center + Vector2(3, 0), false)
	await process_frame
	if wheel.tool != ToolWheel.Tool.BOW:
		printerr("FAIL tool_wheel_quick_tap: second tap did not return to bow (%s)" % wheel.tool)
		fail += 1
	var chop_at := _center(wheel.get_node("Chop"))
	_touch(scene, center, true)
	_drag(scene, chop_at)
	await process_frame
	_touch(scene, chop_at, false)
	await process_frame
	if wheel.tool != ToolWheel.Tool.CHOP or wheel.is_open():
		printerr("FAIL tool_wheel_quick_tap: a drag swapped instead of selecting chop (%s)" % wheel.tool)
		fail += 1
	_free(scene)
	if fail == 0:
		print("PASS test_tool_wheel_quick_tap")
	return fail


func _test_tool_wheel_headless_host() -> int:
	## A headless --server host does not build the wheel. A headless test
	## scene does, and BowButton and ModeButton are gone.
	## Time cost: about 0.3 s in tools/verify.sh.
	print("-- test_tool_wheel_headless_host")
	var fail := 0
	if ToolWheel.builds_on(PackedStringArray(["--server"]), "headless"):
		printerr("FAIL tool_wheel_headless_host: a headless host would build the wheel")
		fail += 1
	if not ToolWheel.builds_on(PackedStringArray(["--server"]), "x11"):
		printerr("FAIL tool_wheel_headless_host: a windowed host was treated as headless")
		fail += 1
	if not ToolWheel.builds_on(PackedStringArray(), "headless"):
		printerr("FAIL tool_wheel_headless_host: a headless test would skip the wheel")
		fail += 1
	var scene = await _scene()
	if scene.get_node_or_null("CanvasLayer1/ToolWheel") == null:
		printerr("FAIL tool_wheel_headless_host: the test scene has no wheel")
		fail += 1
	if scene.get_node_or_null("CanvasLayer1/ModeButton") != null \
			or scene.get_node_or_null("CanvasLayer1/BowButton") != null:
		printerr("FAIL tool_wheel_headless_host: ModeButton or BowButton is still on the HUD")
		fail += 1
	_free(scene)
	if fail == 0:
		print("PASS test_tool_wheel_headless_host")
	return fail


func _scene():
	root.get_node("HudLayout").forget_memory()
	root.get_node("HudLayout").edit_end()
	var scene = load("res://flagoria_main.tscn").instantiate()
	root.add_child(scene)
	var menu: Node = scene.get_node("CanvasLayer2/MainMenu")
	menu.hide()
	menu.set_process_unhandled_input(false)
	scene.get_node("CanvasLayer1").show()
	await process_frame
	await process_frame
	return scene


func _free(scene: Node) -> void:
	scene.queue_free()
	await process_frame


func _arc_ok(wheel: ToolWheel) -> bool:
	var button := _center(wheel.get_node("ToolButton"))
	var ys: Array[float] = []
	for node_name in ToolWheel.NAMES:
		var at := _center(wheel.get_node(node_name))
		if at.x >= button.x - 8.0:
			printerr("tool wheel: %s at %s is not left of %s" % [node_name, at, button])
			return false
		ys.append(at.y)
	return ys[0] < ys[1] and ys[1] < ys[2]


func _drag_to(scene: Node, wheel: ToolWheel, which: int) -> bool:
	var center := _center(wheel.get_node("ToolButton"))
	var at := _center(wheel.get_node(ToolWheel.NAMES[which]))
	_touch(scene, center, true)
	await process_frame
	_drag(scene, at)
	await process_frame
	var ok := wheel.is_open() and wheel.highlighted() == which
	_touch(scene, at, false)
	await process_frame
	return ok


func _beside_run(scene: Node, label: String) -> int:
	var run: Control = scene.get_node("CanvasLayer1/RunButton")
	var button: Control = scene.get_node("CanvasLayer1/ToolWheel/ToolButton")
	var gap := run.get_global_rect().position.x - button.get_global_rect().end.x
	if absf(gap - 2.0) > 1.5 or button.get_global_rect().intersects(run.get_global_rect()):
		printerr("FAIL tool_wheel_hold %s: tool %s run %s gap %s"
				% [label, button.get_global_rect(), run.get_global_rect(), gap])
		return 1
	return 0


func _center(control: Control) -> Vector2:
	return control.get_global_rect().get_center()


func _touch(scene: Node, pos: Vector2, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = 0
	event.pressed = pressed
	event.position = pos
	scene.get_viewport().push_input(event, true)


func _drag(scene: Node, pos: Vector2) -> void:
	var event := InputEventScreenDrag.new()
	event.index = 0
	event.position = pos
	event.relative = Vector2(1, 0)
	scene.get_viewport().push_input(event, true)


func _mouse(scene: Node, pos: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.position = pos
	event.global_position = pos
	scene.get_viewport().push_input(event, true)


func _motion(scene: Node, pos: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = pos
	event.global_position = pos
	scene.get_viewport().push_input(event, true)


func _wheel(scene: Node, button: int) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.pressed = true
	event.position = _center(scene.get_node("CanvasLayer1/ToolWheel/ToolButton"))
	scene.get_viewport().push_input(event, true)
	await process_frame


func _key(scene: Node, code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	scene.get_viewport().push_input(event, true)
