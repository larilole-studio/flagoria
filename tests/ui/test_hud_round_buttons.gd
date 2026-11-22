extends "res://tests/helpers/test_helpers.gd"
## Buildings and minimap toggles, selected rings and tool changes.

const HudLayoutDump = preload("res://tools/hud_layout_dump.gd")


func _test_hud_round_buttons() -> int:
	## Buildings and Map toggle their panels, and picked tools keep their rings.
	print("-- test_hud_round_buttons")
	var fail := 0
	var scene = load("res://flagoria_main.tscn").instantiate()
	root.add_child(scene)
	var menu: Node = scene.get_node("CanvasLayer2/MainMenu")
	menu.hide()
	menu.set_process_unhandled_input(false)
	scene.get_node("CanvasLayer1").show()
	var world = scene.get_node("World/worldMap")
	scene.world_params = _spawn_params(42, 0.003)
	world.apply_map_params(scene.world_params)
	await process_frame
	scene.add_player(scene.multiplayer.get_unique_id())
	await process_frame
	await process_frame
	var panel: MinimapPanel = scene.get_node("CanvasLayer1/MinimapPanel")
	panel.set_physics_process(false)
	panel.tick()
	panel.tick()
	var buildings: Button = scene.get_node("CanvasLayer1/BuildingsButton")
	var picker: Control = scene.get_node("CanvasLayer1/BuildPicker")
	var plank: Button = picker.get_node("PlankButton")
	var tower: Button = picker.get_node("TowerButton")
	var wall: Button = picker.get_node("WallButton")
	var map_button: Button = scene.get_node("CanvasLayer1/MinimapButton")
	var interaction: Interaction = scene.get_node("World/Interaction")
	var wheel: ToolWheel = scene.get_node("CanvasLayer1/ToolWheel")
	if panel.visible or scene.get_node_or_null("CanvasLayer1/MapReopen") != null:
		printerr("FAIL hud_round_buttons: panel %s or the old chip is showing" % panel.visible)
		fail += 1
	if interaction.build.tool != BuildPlacement.Tool.CUT or plank.visible or tower.visible or wall.visible:
		printerr("FAIL hud_round_buttons: list starts open, tool %s" % interaction.build.tool)
		fail += 1
	var build_closed := _face(buildings, "normal")
	buildings.set_pressed(true)
	await process_frame
	if _face(buildings, "normal") == build_closed or not plank.visible or not tower.visible or not wall.visible:
		printerr("FAIL hud_round_buttons: Buildings did not open the picker")
		fail += 1
	buildings.set_pressed(false)
	await process_frame
	if plank.visible or tower.visible or wall.visible:
		printerr("FAIL hud_round_buttons: second Buildings tap left the picker open")
		fail += 1
	buildings.set_pressed(true)
	await process_frame
	plank.pressed.emit()
	await process_frame
	if interaction.build.tool != BuildPlacement.Tool.PLANK or plank.visible \
			or not plank.button_pressed or not _is_selected(plank) \
			or tower.button_pressed or wall.button_pressed:
		printerr("FAIL hud_round_buttons: plank select tool %s open %s" % [interaction.build.tool, plank.visible])
		fail += 1
	buildings.set_pressed(true)
	await process_frame
	if not plank.visible or not _is_selected(plank) or tower.button_pressed:
		printerr("FAIL hud_round_buttons: reopened list lost the plank ring")
		fail += 1
	var outside := InputEventScreenTouch.new()
	outside.position = root.get_visible_rect().get_center()
	outside.pressed = true
	root.push_input(outside, true)
	outside.pressed = false
	root.push_input(outside, true)
	await process_frame
	if buildings.button_pressed or plank.visible or interaction.build.tool != BuildPlacement.Tool.PLANK:
		printerr("FAIL hud_round_buttons: outside tap did not close the picker or changed the tool")
		fail += 1
	map_button.pressed.emit()
	if not panel.visible or not map_button.button_pressed or not _is_selected(map_button):
		printerr("FAIL hud_round_buttons: minimap button left the panel closed")
		fail += 1
	map_button.pressed.emit()
	if panel.visible:
		printerr("FAIL hud_round_buttons: second press left the panel open")
		fail += 1
	var before := interaction.mode
	var tool_button := wheel.get_node("ToolButton") as Button
	var sword_face := _face(tool_button, "normal")
	wheel.select(ToolWheel.Tool.CHOP)
	var chop_face := _face(tool_button, "normal")
	if interaction.mode == before or interaction.mode != Interaction.Mode.INTERACT \
			or chop_face == null or chop_face == sword_face:
		printerr("FAIL hud_round_buttons: chop did not switch to interact (%s)" % interaction.mode)
		fail += 1
	if interaction.build.tool != BuildPlacement.Tool.PLANK:
		printerr("FAIL hud_round_buttons: entering interact cleared the plank tool")
		fail += 1
	wheel.select(ToolWheel.Tool.SWORD)
	if interaction.mode != Interaction.Mode.COMBAT or interaction.build.tool != BuildPlacement.Tool.CUT \
			or _face(tool_button, "normal") != sword_face \
			or sword_face.get_size() != Vector2(24, 24) \
			or tool_button.texture_filter != CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS:
		printerr("FAIL hud_round_buttons: leaving interact mode %s tool %s"
				% [interaction.mode, interaction.build.tool])
		fail += 1
	scene.queue_free()
	await process_frame
	if fail == 0:
		print("PASS test_hud_round_buttons")
	return fail


func _test_build_picker_saved_layout_tap() -> int:
	print("-- test_build_picker_saved_layout_tap")
	var original_size := root.size
	var layout := root.get_node("HudLayout")
	var original_path: String = layout.save_path
	layout.save_path = "user://test_build_picker_saved_layout.cfg"
	layout.reset_to_defaults()
	await HudLayoutDump.resize(tree, Vector2i(3840, 1080))
	var scene := await HudLayoutDump.play_scene(tree)
	var hud: CanvasLayer = scene.get_node("CanvasLayer1")
	layout.edit_begin(hud)
	var placed: bool = layout.try_place("buildings", 0.90, 0.40, 1.0, hud) \
			and layout.try_place("map", 0.84, 0.40, 1.75, hud)
	layout.save_to_disk()
	layout.edit_end()
	layout.forget_memory()
	layout.load_from_disk()
	hud.hide()
	await HudLayoutDump.resize(tree, Vector2i(2400, 1080))
	hud.show()
	await process_frame
	var buildings: Button = hud.get_node("BuildingsButton")
	var picker: Control = hud.get_node("BuildPicker")
	var panel: Control = hud.get_node("MinimapPanel")
	var at := buildings.get_global_rect().get_center()
	_tap_sequence(at, ["touch_down", "touch_up"])
	await process_frame
	var visible_count := 0
	for button: Button in picker.get_children():
		if button.is_visible_in_tree() and root.get_visible_rect().encloses(button.get_global_rect()):
			visible_count += 1
	var opened := buildings.button_pressed and not panel.visible and visible_count == 6
	_tap_sequence(at, ["touch_down", "touch_up"])
	await process_frame
	var closed := not buildings.button_pressed
	scene.queue_free()
	await process_frame
	layout.reset_to_defaults()
	layout.save_path = original_path
	layout.load_from_disk()
	await HudLayoutDump.resize(tree, original_size)
	if not (placed and opened and closed):
		printerr("FAIL build_picker_saved_layout_tap: setup %s, opened %s (%d in bounds), closed %s"
				% [placed, opened, visible_count, closed])
		return 1
	print("PASS test_build_picker_saved_layout_tap")
	return 0


func _is_selected(button: Button) -> bool:
	return button.button_pressed and _face(button, "normal") != _face(button, "hover_pressed")


func _face(button: Button, state: String) -> Texture2D:
	var box := button.get_theme_stylebox(state) as StyleBoxTexture
	return box.texture if box != null else null
