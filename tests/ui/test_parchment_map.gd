extends "res://tests/helpers/test_helpers.gd"
## Parchment panning, zoom, modal controls and dismissal.


func _test_parchment_map() -> int:
	print("-- test_parchment_map")
	var fail := 0
	var scene := await preload("res://tools/hud_layout_dump.gd").play_scene(tree)
	var chart: MapChart = scene.get_node("CanvasLayer1/MapChart")
	chart.set_physics_process(false)
	chart.tick()
	chart.tick()
	var map_button: Button = scene.get_node("CanvasLayer1/MapButton")
	var parchment: ParchmentMap = scene.get_node("CanvasLayer1/ParchmentMap")
	var player: Node2D = scene.get_node("World/%d" % scene.multiplayer.get_unique_id())
	map_button.pressed.emit()
	fail += _check_toolbar(parchment, scene)
	fail += await _check_close_does_not_open_menu(parchment, scene)
	map_button.pressed.emit()
	fail += _check_toolbar(parchment, scene)
	var before := parchment.pan
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = parchment.size * 0.5
	parchment._gui_input(press)
	var motion := InputEventMouseMotion.new()
	motion.button_mask = MOUSE_BUTTON_MASK_LEFT
	motion.position = press.position + Vector2(40, -16)
	motion.relative = Vector2(40, -16)
	parchment._gui_input(motion)
	if parchment.pan.distance_to(before) < 10.0:
		printerr("FAIL parchment_map drag did not pan (%s)" % parchment.pan)
		fail += 1
	var stuck := player.position
	Input.action_press("ui_right")
	for _i in 12:
		await physics_frame
	Input.action_release("ui_right")
	if player.position.distance_to(stuck) >= 1.0:
		printerr("FAIL parchment_map hero moved while the map was open")
		fail += 1
	Input.action_press("attack")
	await physics_frame
	Input.action_release("attack")
	await physics_frame
	if player.isAttacking:
		printerr("FAIL parchment_map hero attacked while the map was open")
		fail += 1
	var zoom = player.get_node("Camera2D/MapZoom")
	var factor: float = zoom.factor
	var before_px: int = parchment.cell_px
	_tap(parchment.get_node("ZoomInButton"))
	if parchment.cell_px != before_px + 1:
		printerr("FAIL parchment_map zoom in %s want %s" % [parchment.cell_px, before_px + 1])
		fail += 1
	_tap(parchment.get_node("ZoomOutButton"))
	if parchment.cell_px != before_px:
		printerr("FAIL parchment_map zoom out %s want %s" % [parchment.cell_px, before_px])
		fail += 1
	parchment.cell_px = parchment.MAX_CELL_PX
	_tap(parchment.get_node("ZoomInButton"))
	if parchment.cell_px != parchment.MAX_CELL_PX:
		printerr("FAIL parchment_map zoom in above max %s" % parchment.cell_px)
		fail += 1
	parchment.cell_px = parchment.min_cell_px()
	_tap(parchment.get_node("ZoomOutButton"))
	if parchment.cell_px != parchment.min_cell_px():
		printerr("FAIL parchment_map zoom out below min %s" % parchment.cell_px)
		fail += 1
	before_px = parchment.cell_px
	var focus := Vector2(120, 100)
	var view: Control = parchment.get_node("MapView")
	var focus2_pre: Vector2 = focus - view.position
	var anchor_cell := parchment.map_pixel_at_view(focus2_pre) / float(parchment.cell_px)
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel.pressed = true
	wheel.position = focus
	parchment._gui_input(wheel)
	await process_frame
	if not is_equal_approx(zoom.factor, factor):
		printerr("FAIL parchment_map wheel zoomed the camera (%s -> %s)" % [factor, zoom.factor])
		fail += 1
	if parchment.cell_px <= before_px:
		printerr("FAIL parchment_map wheel did not zoom the sheet (%s)" % parchment.cell_px)
		fail += 1
	var focus2: Vector2 = focus - view.position
	var after_cell := parchment.map_pixel_at_view(focus2) / float(parchment.cell_px)
	if after_cell.distance_to(anchor_cell) > 0.01:
		printerr("FAIL parchment_map wheel moved anchor (%s vs %s)" % [anchor_cell, after_cell])
		fail += 1
	parchment.cell_px = parchment.MAX_CELL_PX
	parchment._zoom_at(focus2, parchment.MAX_CELL_PX)
	if parchment.cell_px != parchment.MAX_CELL_PX:
		printerr("FAIL parchment_map max clamp %s" % parchment.cell_px)
		fail += 1
	parchment._zoom_at(focus2, parchment.MAX_CELL_PX + 4)
	if parchment.cell_px != parchment.MAX_CELL_PX:
		printerr("FAIL parchment_map above max clamp %s" % parchment.cell_px)
		fail += 1
	parchment._zoom_at(focus2, parchment.min_cell_px() - 2)
	if parchment.cell_px < parchment.min_cell_px():
		printerr(
			"FAIL parchment_map min clamp %s min %s" % [parchment.cell_px, parchment.min_cell_px()]
		)
		fail += 1
	while parchment.cell_px > parchment.min_cell_px():
		var down := InputEventMouseButton.new()
		down.button_index = MOUSE_BUTTON_WHEEL_DOWN
		down.pressed = true
		down.position = parchment.hero_screen_position()
		parchment._gui_input(down)
		await process_frame
	if parchment.cell_px != parchment.min_cell_px():
		printerr("FAIL parchment_map min zoom %s" % parchment.cell_px)
		fail += 1
	if not parchment.explored_fully_visible():
		printerr(
			(
				"FAIL parchment_map min zoom chart outside view %s explored %s"
				% [parchment.view_cells_rect(), chart.explored.explored_rect()]
			)
		)
		fail += 1
	scene.get_node("CanvasLayer1").show()
	parchment.cell_px = ParchmentMap.DEFAULT_CELL_PX
	var pinch_a := InputEventScreenTouch.new()
	pinch_a.index = 0
	pinch_a.pressed = true
	pinch_a.position = Vector2(80, 200)
	root.push_input(pinch_a, true)
	var pinch_b := InputEventScreenTouch.new()
	pinch_b.index = 1
	pinch_b.pressed = true
	pinch_b.position = Vector2(180, 200)
	root.push_input(pinch_b, true)
	var pinch_factor: float = zoom.factor
	var drag := InputEventScreenDrag.new()
	drag.index = 1
	var max_px := parchment.cell_px
	for offset in range(3, 121, 3):
		drag.position = pinch_b.position + Vector2(offset, 0)
		root.push_input(drag, true)
		max_px = maxi(max_px, parchment.cell_px)
	if max_px <= ParchmentMap.DEFAULT_CELL_PX or max_px > ParchmentMap.MAX_CELL_PX:
		printerr("FAIL parchment_map slow pinch out reached %s px" % max_px)
		fail += 1
	var min_px := parchment.cell_px
	for offset in range(117, -76, -3):
		drag.position = pinch_b.position + Vector2(offset, 0)
		root.push_input(drag, true)
		min_px = mini(min_px, parchment.cell_px)
	if min_px != ParchmentMap.MIN_CELL_PX or parchment.cell_px != ParchmentMap.MIN_CELL_PX:
		printerr("FAIL parchment_map slow pinch in reached %s px" % min_px)
		fail += 1
	pinch_b.position = drag.position
	pinch_b.pressed = false
	root.push_input(pinch_b, true)
	pinch_a.pressed = false
	root.push_input(pinch_a, true)

	var magnify := InputEventMagnifyGesture.new()
	magnify.position = Vector2(180, 200)
	magnify.factor = 1.03
	for i in 24:
		root.push_input(magnify, true)
	var magnified_px := parchment.cell_px
	magnify.factor = 0.97
	for i in 24:
		root.push_input(magnify, true)
	if magnified_px <= min_px or parchment.cell_px >= magnified_px:
		printerr(
			(
				"FAIL parchment_map magnify steps %s -> %s -> %s"
				% [min_px, magnified_px, parchment.cell_px]
			)
		)
		fail += 1
	if not is_equal_approx(zoom.factor, pinch_factor):
		printerr(
			"FAIL parchment_map gestures moved camera (%s -> %s)" % [pinch_factor, zoom.factor]
		)
		fail += 1
	var health: PlayerHealth = player.get_node("Health")
	if not health.take_damage(1):
		printerr("FAIL parchment_map damage did not land")
		fail += 1
	for _i in 5:
		await process_frame
	if parchment.is_open():
		printerr("FAIL parchment_map still open after damage (open %s)" % parchment.is_open())
		fail += 1
	map_button.pressed.emit()
	var esc := InputEventKey.new()
	esc.physical_keycode = KEY_ESCAPE
	esc.keycode = KEY_ESCAPE
	esc.pressed = true
	parchment._input(esc)
	if parchment.is_open():
		printerr("FAIL parchment_map Esc left it open %s" % parchment.is_open())
		fail += 1
	map_button.pressed.emit()
	_tap(parchment.get_node("CloseButton"))
	if parchment.is_open() or not is_equal_approx(zoom.factor, factor):
		printerr("FAIL parchment_map close open %s zoom %s" % [parchment.is_open(), zoom.factor])
		fail += 1
	_tap(parchment.get_node("RecentreButton"))
	# Recentre is on the sheet; the sheet is closed, so the tap must not open it.
	if parchment.is_open():
		printerr("FAIL parchment_map recentre opened a closed map")
		fail += 1
	map_button.pressed.emit()
	parchment.cell_px = 8
	parchment.pan = Vector2(30, 30)
	_tap(parchment.get_node("RecentreButton"))
	if parchment.pan != Vector2.ZERO:
		printerr("FAIL parchment_map recentre left pan %s" % parchment.pan)
		fail += 1
	if parchment.cell_px != 8:
		printerr("FAIL parchment_map recentre changed zoom %s" % parchment.cell_px)
		fail += 1
	parchment.hide_map()
	map_button.pressed.emit()
	if parchment.cell_px != parchment.DEFAULT_CELL_PX:
		printerr("FAIL parchment_map reopen reset zoom %s" % parchment.cell_px)
		fail += 1
	parchment.hide_map()
	wheel.pressed = true
	scene.get_viewport().push_input(wheel, true)
	await process_frame
	if not zoom.factor > factor:
		printerr("FAIL parchment_map wheel did nothing after close (%s)" % zoom.factor)
		fail += 1
	scene.queue_free()
	await process_frame
	if fail == 0:
		print("PASS test_parchment_map")
	return fail


func _check_toolbar(parchment: ParchmentMap, _scene: Node) -> int:
	var fail := 0
	var names := ["ZoomOutButton", "ZoomInButton", "RecentreButton", "CloseButton"]
	var buttons: Array[Control] = []
	for node_name in names:
		buttons.append(parchment.get_node(node_name) as Control)
	for button in buttons:
		if button.size != parchment.BUTTON_SIZE:
			printerr(
				(
					"FAIL parchment_map %s size %s want %s"
					% [button.name, button.size, parchment.BUTTON_SIZE]
				)
			)
			fail += 1
		if button.position.x + button.size.x <= parchment.size.x * 0.5:
			printerr(
				(
					"FAIL parchment_map %s not on the right (%s in %s)"
					% [button.name, button.position, parchment.size]
				)
			)
			fail += 1
		if not is_equal_approx(button.position.y, float(parchment.BUTTON_MARGIN)):
			printerr(
				(
					"FAIL parchment_map %s not flush to the sheet corner (y %s want %s)"
					% [button.name, button.position.y, parchment.BUTTON_MARGIN]
				)
			)
			fail += 1
	for i in range(1, buttons.size()):
		if buttons[i].position.x <= buttons[i - 1].position.x:
			printerr(
				(
					"FAIL parchment_map toolbar order %s at %s after %s at %s"
					% [
						buttons[i].name,
						buttons[i].position,
						buttons[i - 1].name,
						buttons[i - 1].position
					]
				)
			)
			fail += 1
	var close := buttons[3]
	var right_edge := close.position.x + close.size.x
	if parchment.size.x - right_edge > parchment.BUTTON_MARGIN + 1:
		printerr(
			(
				"FAIL parchment_map toolbar not against the right edge (end %s size %s)"
				% [right_edge, parchment.size.x]
			)
		)
		fail += 1
	return fail


func _check_close_does_not_open_menu(parchment: ParchmentMap, scene: Node) -> int:
	var fail := 0
	var close: Control = parchment.get_node("CloseButton")
	var menu: Control = scene.get_node("CanvasLayer1/InGameMenu")
	var panel: Control = menu.get_node("Pause")
	var menu_button: Control = menu.get_node("MenuButton")
	await _click_screen(close)
	for _i in 4:
		await process_frame
	if parchment.is_open():
		printerr("FAIL parchment_map viewport close left the sheet open")
		fail += 1
	if panel.visible:
		printerr("FAIL parchment_map Close opened the menu")
		fail += 1
	var until := Time.get_ticks_msec() + parchment.DISMISS_GUARD_MSEC + 150
	while Time.get_ticks_msec() < until:
		await process_frame
	await _click_screen(menu_button)
	for _i in 4:
		await process_frame
	if not panel.visible:
		printerr("FAIL parchment_map menu ignored after the dismiss guard")
		fail += 1
	if menu.has_method("close"):
		menu.close()
	else:
		panel.hide()
	return fail


func _click_screen(control: Control) -> void:
	var at := control.get_global_rect().get_center()
	var move := InputEventMouseMotion.new()
	move.position = at
	move.global_position = at
	root.push_input(move, true)
	await process_frame
	for pressed in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = pressed
		ev.position = at
		ev.global_position = at
		root.push_input(ev, true)
		await process_frame
		await process_frame


func _tap(control: Control) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	ev.position = control.size * 0.5
	control._gui_input(ev)
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = ev.position
	control._gui_input(up)
