extends "res://tests/helpers/test_helpers.gd"
## Buildings and minimap toggles, selected rings and tool changes.


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
	buildings.set_pressed(true)
	await process_frame
	if not plank.visible or not tower.visible or not wall.visible:
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
	wheel.select(ToolWheel.Tool.CHOP)
	var tool_icon: Texture2D = wheel.get_node("ToolButton").icon
	if interaction.mode == before or interaction.mode != Interaction.Mode.INTERACT \
			or tool_icon == null or not str(tool_icon.resource_path).ends_with("icon_mode_interact.png"):
		printerr("FAIL hud_round_buttons: chop did not switch to interact (%s)" % interaction.mode)
		fail += 1
	if interaction.build.tool != BuildPlacement.Tool.PLANK:
		printerr("FAIL hud_round_buttons: entering interact cleared the plank tool")
		fail += 1
	wheel.select(ToolWheel.Tool.SWORD)
	tool_icon = wheel.get_node("ToolButton").icon
	if interaction.mode != Interaction.Mode.COMBAT or interaction.build.tool != BuildPlacement.Tool.CUT \
			or tool_icon == null or not str(tool_icon.resource_path).ends_with("icon_mode_attack.png"):
		printerr("FAIL hud_round_buttons: leaving interact mode %s tool %s"
				% [interaction.mode, interaction.build.tool])
		fail += 1
	scene.queue_free()
	await process_frame
	if fail == 0:
		print("PASS test_hud_round_buttons")
	return fail


func _is_selected(button: Button) -> bool:
	if not button.button_pressed:
		return false
	var box := button.get_theme_stylebox("pressed") as StyleBoxTexture
	if box == null or box.texture == null:
		return false
	var path := str(box.texture.resource_path)
	return "_selected" in path or "_pressed" in path

