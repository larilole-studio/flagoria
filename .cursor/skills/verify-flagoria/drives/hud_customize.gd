extends "res://.cursor/skills/verify-flagoria/bin/drive_base.gd"
## launch: --seed 49
## Customize HUD from the in-game menu: default layout, edit mode, move attack
## and the tool wheel, save, reload, open the wheel, overlap rejection, reset.
## bin/launch.sh drives/hud_customize.gd --display --seed 49

const CUSTOMIZE_BTN := "CanvasLayer1/InGameMenu/Pause/Panel/Margin/VBox/CustomizeHud"
const ATTACK := "CanvasLayer1/TouchScreenButton"
const MAP := "CanvasLayer1/MapButton"
const EDIT_BAR := "CanvasLayer1/InGameMenu/HudLayoutEdit/TopBar"
const DONE := "CanvasLayer1/InGameMenu/HudLayoutEdit/TopBar/Margin/Row/Done"
const SAVE := "CanvasLayer1/InGameMenu/HudLayoutEdit/TopBar/Margin/Row/Save"
const RESET := "CanvasLayer1/InGameMenu/HudLayoutEdit/TopBar/Margin/Row/Reset"
const SIZE_SLIDER := "CanvasLayer1/InGameMenu/HudLayoutEdit/TopBar/Margin/Row/SizeSlider"
const WHEEL := "CanvasLayer1/ToolWheel"
const HUD_IDS := ["joystick", "attack", "run", "buildings", "map", "wheel"]


func _hud_layout() -> Node:
	return root.get_node("HudLayout")


func _tap(at: Vector2) -> void:
	for pressed in [true, false]:
		var touch := InputEventScreenTouch.new()
		touch.index = 0
		touch.position = at
		touch.pressed = pressed
		Input.parse_input_event(touch)
		await process_frame


func _edit_bar_rect() -> Rect2:
	return (current_scene.get_node(EDIT_BAR) as Control).get_global_rect()


func _bar_inside_viewport() -> bool:
	var view := current_scene.get_viewport().get_visible_rect()
	if not view.encloses(_edit_bar_rect().grow(2.0)):
		return false
	var editor := current_scene.get_node("CanvasLayer1/InGameMenu/HudLayoutEdit")
	return editor.has_method("bar_fits_viewport") and editor.bar_fits_viewport()


func _controls_clear_of_bar(layer: CanvasLayer) -> bool:
	var editor := current_scene.get_node("CanvasLayer1/InGameMenu/HudLayoutEdit")
	if not editor.visible:
		return true
	var bar := _edit_bar_rect().grow(2.0)
	for id in HUD_IDS:
		var rect: Rect2 = _hud_layout().control_visual_rect(id, layer)
		if rect.size != Vector2.ZERO and bar.intersects(rect):
			printerr("hud customize: edit bar overlaps %s bar %s control %s" % [id, bar, rect])
			return false
	return true


func _map_closed_in_edit(layer: CanvasLayer) -> bool:
	return not layer.get_node("ParchmentMap").is_open()


func _tap_control(layer: CanvasLayer, id: String) -> void:
	var node_path: String = _hud_layout().PATHS[id] if _hud_layout().PATHS.has(id) else ""
	if id == "attack":
		node_path = "TouchScreenButton"
	var node = layer.get_node_or_null(node_path)
	if node == null:
		return
	var size := Vector2(48, 48)
	if id == "attack":
		var btn := node as TouchScreenButton
		size = btn.texture_normal.get_size() * btn.scale * 0.5 if btn.texture_normal else size
	elif node is Control:
		size = (node as Control).size * 0.5
	await _tap(to_window(node, size))


func run() -> void:
	if not await start_game():
		return
	var layer := current_scene.get_node("CanvasLayer1") as CanvasLayer
	var attack := current_scene.get_node(ATTACK) as TouchScreenButton
	var map_btn := current_scene.get_node(MAP) as Control
	var wheel: ToolWheel = current_scene.get_node(WHEEL)
	var wheel_button := wheel.get_node("ToolButton") as Control
	var ok := (
		attack != null
		and attack.texture_normal != null
		and map_btn != null
		and wheel_button != null
	)
	step("default-layout")
	var stick := layer.get_node("player_joystick") as Node2D
	ok = (
		ok
		and await wait_until(
			func() -> bool:
				var center := (
					attack.global_position + attack.texture_normal.get_size() * attack.scale * 0.5
				)
				var view := layer.get_viewport().get_visible_rect()
				return (
					is_equal_approx(center.y, stick.global_position.y)
					and is_equal_approx(
						view.end.x - center.x, stick.global_position.x - view.position.x
					)
				),
			5.0
		)
	)
	await snapshot("default-layout")
	var default_pos := attack.global_position
	var default_map := map_btn.global_position
	var default_wheel := wheel_button.global_position

	step("edit-mode")
	await click(MENU_BUTTON)
	await click(CUSTOMIZE_BTN)
	var editor := current_scene.get_node("CanvasLayer1/InGameMenu/HudLayoutEdit")
	if editor.has_method("relayout_bar"):
		await editor.relayout_bar()
	await process_frame
	ok = ok and editor.visible
	ok = ok and _bar_inside_viewport()
	ok = ok and _controls_clear_of_bar(layer)
	var attack_at := to_window(attack, attack.texture_normal.get_size() * attack.scale * 0.5)
	await _tap(attack_at)
	await process_frame
	ok = ok and (current_scene.get_node(SIZE_SLIDER) as HSlider).editable
	ok = ok and _map_closed_in_edit(layer)
	await snapshot("edit-mode")
	ok = ok and _bar_inside_viewport()
	ok = ok and _controls_clear_of_bar(layer)
	if not ok:
		printerr("hud customize: failed by edit-mode")

	step("moved-control")
	_hud_layout().try_place("attack", 0.42, 0.62, 1.35, layer)
	await process_frame
	ok = ok and attack.global_position.distance_to(default_pos) > 12.0
	await _tap_control(layer, "map")
	await process_frame
	ok = ok and _map_closed_in_edit(layer)
	_hud_layout().try_place("map", 0.52, 0.38, 1.15, layer)
	if editor.has_method("relayout_bar"):
		await editor.relayout_bar()
	for _i in 16:
		await process_frame
	ok = ok and map_btn.global_position.distance_to(default_map) > 10.0
	ok = ok and _controls_clear_of_bar(layer)
	if not ok:
		printerr(
			(
				"hud customize: failed by moved-control attack-moved=%s map-moved=%s slider=%s"
				% [
					attack.global_position.distance_to(default_pos) > 12.0,
					map_btn.global_position.distance_to(default_map) > 10.0,
					(current_scene.get_node(SIZE_SLIDER) as HSlider).editable
				]
			)
		)
	await snapshot("moved-control")

	step("moved-wheel")
	await _tap_control(layer, "wheel")
	await process_frame
	var placed: bool = _hud_layout().try_place("wheel", 0.10, 0.30, 1.75, layer)
	(current_scene.get_node(SIZE_SLIDER) as HSlider).set_value_no_signal(1.75)
	if editor.has_method("relayout_bar"):
		await editor.relayout_bar()
	for _i in 16:
		await process_frame
	wheel_button = wheel.get_node("ToolButton") as Control
	var wheel_scale := wheel_button.size.x / RoundHudStyle.HIT
	if not placed or wheel_button.global_position.distance_to(default_wheel) <= 12.0:
		printerr(
			"hud customize: wheel move placed=%s at %s" % [placed, wheel_button.global_position]
		)
	if absf(wheel_scale - 1.75) >= 0.08:
		printerr("hud customize: wheel scale %s size %s" % [wheel_scale, wheel_button.size])
	if not _controls_clear_of_bar(layer):
		printerr("hud customize: edit bar overlaps a control")
	ok = ok and placed and wheel_button.global_position.distance_to(default_wheel) > 12.0
	ok = ok and absf(wheel_scale - 1.75) < 0.08
	ok = ok and _controls_clear_of_bar(layer)
	await snapshot("moved-wheel")
	ok = ok and _controls_clear_of_bar(layer)

	step("no-overlap")
	var buildings: Control = current_scene.get_node("CanvasLayer1/BuildingsButton")
	attack_at = to_window(attack, attack.texture_normal.get_size() * attack.scale * 0.5)
	await _tap(attack_at)
	var blocked: bool = not _hud_layout().try_place(
		"attack",
		buildings.global_position.x / layer.get_viewport().get_visible_rect().size.x,
		buildings.global_position.y / layer.get_viewport().get_visible_rect().size.y,
		1.0,
		layer
	)
	await process_frame
	ok = ok and blocked
	if not ok and not blocked:
		printerr("hud customize: attack was allowed to overlap buildings")
	await snapshot("no-overlap")

	step("after-save-restart")
	var saved_pos := attack.global_position
	var saved_wheel := wheel_button.global_position
	await click(SAVE)
	_hud_layout().save_to_disk()
	await click(DONE)
	if change_scene_to_file(MAIN) != OK:
		done(false)
		return
	await wait_until(menu_root_visible, START_TIMEOUT_S)
	await host_from_menu()
	await wait_until(func() -> bool: return hero() != null, START_TIMEOUT_S)
	layer = current_scene.get_node("CanvasLayer1") as CanvasLayer
	attack = current_scene.get_node(ATTACK) as TouchScreenButton
	map_btn = current_scene.get_node(MAP) as Control
	if not _hud_layout().uses_custom():
		_hud_layout().load_from_disk()
	_hud_layout().apply(layer)
	await wait_until(
		func() -> bool:
			return (
				_hud_layout().uses_custom() and attack.global_position.distance_to(saved_pos) < 12.0
			),
		3.0
	)
	await process_frame
	await process_frame
	wheel = current_scene.get_node(WHEEL) as ToolWheel
	wheel_button = wheel.get_node("ToolButton") as Control
	if attack.global_position.distance_to(saved_pos) >= 8.0:
		printerr("hud customize: attack reload %s want %s" % [attack.global_position, saved_pos])
	if wheel_button.global_position.distance_to(saved_wheel) >= 8.0:
		printerr(
			"hud customize: wheel reload %s want %s" % [wheel_button.global_position, saved_wheel]
		)
	ok = ok and _hud_layout().uses_custom() and attack.global_position.distance_to(saved_pos) < 8.0
	ok = ok and wheel_button.global_position.distance_to(saved_wheel) < 8.0
	await snapshot("after-save-restart")

	step("wheel-open")
	var at := to_window(wheel_button, wheel_button.size * 0.5)
	await _hold(at)
	if not wheel.is_open():
		printerr("hud customize: wheel did not open")
	if not _arc_on_screen(wheel):
		printerr("hud customize: open arc is off screen")
	ok = ok and wheel.is_open() and _arc_on_screen(wheel)
	await snapshot("wheel-open")
	await _release(at)
	await process_frame
	if wheel.is_open():
		printerr("hud customize: wheel stayed open after release")
	ok = ok and not wheel.is_open()

	step("reset-layout")
	await click(MENU_BUTTON)
	await click(CUSTOMIZE_BTN)
	await process_frame
	await click(RESET)
	for _i in 10:
		await process_frame
	editor = current_scene.get_node("CanvasLayer1/InGameMenu/HudLayoutEdit")
	if editor.has_method("relayout_bar"):
		await editor.relayout_bar()
	ok = ok and _bar_inside_viewport()
	ok = ok and _controls_clear_of_bar(layer)
	if not ok:
		printerr("hud customize: failed by reset-layout bar=%s" % _bar_inside_viewport())
	await snapshot("reset-layout")
	await click(DONE)
	for _i in 10:
		await process_frame
	_hud_layout().reset_to_defaults()
	(layer.get_node("HudToolRow") as HudToolRow).restore_defaults(layer)
	await process_frame
	await process_frame
	if _hud_layout().uses_custom():
		printerr("hud customize: reset left a saved layout")
	wheel_button = (layer.get_node("ToolWheel/ToolButton") as Control)
	if attack.global_position.distance_to(default_pos) >= 16.0:
		printerr("hud customize: attack reset %s want %s" % [attack.global_position, default_pos])
	if map_btn.global_position.distance_to(default_map) >= 16.0:
		printerr("hud customize: map reset %s want %s" % [map_btn.global_position, default_map])
	if wheel_button.global_position.distance_to(default_wheel) >= 16.0:
		printerr(
			(
				"hud customize: wheel reset %s want %s size %s"
				% [wheel_button.global_position, default_wheel, wheel_button.size]
			)
		)
	ok = ok and not _hud_layout().uses_custom()
	ok = ok and attack.global_position.distance_to(default_pos) < 16.0
	ok = ok and map_btn.global_position.distance_to(default_map) < 16.0
	ok = ok and wheel_button.global_position.distance_to(default_wheel) < 16.0
	ok = ok and current_scene.get_node_or_null("CanvasLayer1/ModeButton") == null
	ok = ok and current_scene.get_node_or_null("CanvasLayer1/BowButton") == null
	done(ok)


func _hold(at: Vector2) -> void:
	var touch := InputEventScreenTouch.new()
	touch.index = 0
	touch.position = at
	touch.pressed = true
	Input.parse_input_event(touch)
	await create_timer(0.25).timeout


func _release(at: Vector2) -> void:
	var touch := InputEventScreenTouch.new()
	touch.index = 0
	touch.position = at
	touch.pressed = false
	Input.parse_input_event(touch)
	await process_frame


func _arc_on_screen(wheel: ToolWheel) -> bool:
	var view := current_scene.get_viewport().get_visible_rect()
	var button := (wheel.get_node("ToolButton") as Control).get_global_rect().get_center()
	var inward := false
	for node_name in ToolWheel.NAMES:
		var opt := wheel.get_node(node_name) as Control
		if opt == null or not opt.visible:
			return false
		var rect := opt.get_global_rect()
		if not view.encloses(rect):
			printerr("hud customize: %s off screen %s view %s" % [node_name, rect, view])
			return false
		if (
			node_name == "Bow"
			and (
				rect.get_center().distance_to(view.get_center()) + 4.0
				< button.distance_to(view.get_center())
			)
		):
			inward = true
	if not inward:
		printerr("hud customize: arc did not open toward the screen centre")
	return inward
