extends "res://.cursor/skills/verify-flagoria/bin/drive_base.gd"
## launch: --seed 49
## Checks the mirrored thumb controls and opens and closes the Buildings
## picker beside them. Picks Plank, opens the minimap, toggles interact, and taps Run.
## bin/launch.sh drives/hud_round_buttons.gd --display --seed 49

const BUILDINGS := "CanvasLayer1/BuildingsButton"
const PLANK := "CanvasLayer1/BuildPicker/PlankButton"
const MAP_BUTTON := "CanvasLayer1/MinimapButton"
const RUN_BUTTON := "CanvasLayer1/RunButton"


func run() -> void:
	if not await start_game():
		return
	var panel: MinimapPanel = current_scene.get_node(MINIMAP)
	var interaction: Interaction = current_scene.get_node(INTERACTION)
	var buildings := current_scene.get_node(BUILDINGS) as Button
	var ok := await wait_until(func() -> bool:
		return buildings.size.x >= RoundHudStyle.HIT and not panel.visible \
				and not _plank().visible
	, 5.0)
	step("match-start")
	ok = ok and _cluster_ok(panel) and _disc_is(buildings, "ui_disc_build") \
			and _disc_is(current_scene.get_node(MAP_BUTTON), "ui_disc_map") \
			and _icon_is(current_scene.get_node(TOOL_BUTTON), "icon_mode_attack.png")
	await snapshot("match-start")
	print("hud round: start panel %s tool %s" % [panel.visible, interaction.build.tool])

	step("building-list")
	await click(BUILDINGS)
	ok = ok and await wait_until(func() -> bool: return _plank().visible, 2.0)
	ok = ok and _picker_ok()
	await snapshot("building-list")
	await click(BUILDINGS)
	ok = ok and await wait_until(func() -> bool: return not _plank().visible, 2.0)
	print("hud round: list closed %s" % (not _plank().visible))

	step("building-selected")
	await click(BUILDINGS)
	await click(PLANK)
	var picked: bool = interaction.build.tool == BuildPlacement.Tool.PLANK and not _plank().visible
	await click(BUILDINGS)
	var plank := _plank()
	picked = picked and plank.visible and plank.button_pressed and _selected(plank)
	ok = ok and picked
	await snapshot("building-selected")
	print("hud round: plank tool %s ring %s" % [interaction.build.tool, picked])
	await click(BUILDINGS)

	step("minimap")
	await click(MAP_BUTTON)
	ok = ok and await wait_until(func() -> bool: return panel.visible, 2.0)
	ok = ok and _buttons_outside(panel)
	await snapshot("minimap")
	print("hud round: minimap panel %s clear %s" % [panel.visible, _buttons_outside(panel)])

	step("interact")
	var before := interaction.mode
	await toggle_mode()
	var switched: bool = interaction.mode != before and interaction.mode == Interaction.Mode.INTERACT \
			and _icon_is(current_scene.get_node(TOOL_BUTTON), "icon_mode_interact.png") \
			and interaction.build.tool == BuildPlacement.Tool.PLANK
	ok = ok and _buttons_outside(panel)
	await snapshot("interact")
	await toggle_mode()
	var back: bool = interaction.mode == before and interaction.build.tool == BuildPlacement.Tool.CUT \
			and _icon_is(current_scene.get_node(TOOL_BUTTON), "icon_mode_attack.png")
	print("hud round: mode switched %s back %s" % [switched, back])

	step("run")
	var run := current_scene.get_node(RUN_BUTTON) as Button
	await click(RUN_BUTTON)
	var ran: bool = run.running() and run.latched
	print("hud round: run latched %s" % ran)
	done(ok and switched and back and ran and current_scene.get_node_or_null("CanvasLayer1/MapReopen") == null)


func _plank() -> Button:
	return current_scene.get_node(PLANK) as Button


func _cluster_ok(panel: MinimapPanel) -> bool:
	var map_button := current_scene.get_node(MAP_BUTTON) as Button
	var buildings := current_scene.get_node(BUILDINGS) as Button
	var run := current_scene.get_node(RUN_BUTTON) as Button
	var attack := current_scene.get_node("CanvasLayer1/TouchScreenButton") as TouchScreenButton
	if panel.visible or not _round(map_button) or not _round(buildings):
		printerr("hud round: start buttons map %s buildings %s" % [map_button.size, buildings.size])
		return false
	if not _disc_is(run, "ui_disc_run"):
		printerr("hud round: Run disc")
		return false
	var attack_rect := Rect2(attack.position, attack.texture_normal.get_size() * attack.scale)
	var run_rect := run.get_global_rect()
	if run_rect.intersects(attack_rect) or run_rect.size.x >= attack_rect.size.x:
		printerr("hud round: Run %s attack %s" % [run_rect, attack_rect])
		return false
	var menu := current_scene.get_node("CanvasLayer1/InGameMenu/MenuButton") as Button
	var menu_c := menu.get_global_rect().get_center()
	var map_c := map_button.get_global_rect().get_center()
	if not is_equal_approx(map_c.y, menu_c.y) or map_c.x >= menu_c.x:
		printerr("hud round: Map %s Menu %s" % [map_c, menu_c])
		return false
	var view := current_scene.get_viewport().get_visible_rect()
	var stick := current_scene.get_node("CanvasLayer1/player_joystick") as Node2D
	var stick_c := stick.global_position
	var attack_c := attack_rect.get_center()
	if not is_equal_approx(attack_c.y, stick_c.y) \
			or not is_equal_approx(view.end.x - attack_c.x, stick_c.x - view.position.x) \
			or not is_equal_approx(attack_rect.size.x, stick.start_reach() * 2.0):
		printerr("hud round: Joystick %s Attack %s" % [stick_c, attack_rect])
		return false
	var wheel_rect := (current_scene.get_node(TOOL_BUTTON) as Control).get_global_rect()
	var build_rect := buildings.get_global_rect()
	for rect in [run_rect, wheel_rect, build_rect]:
		var center: Vector2 = rect.get_center()
		if not view.encloses(rect) or rect.intersects(attack_rect) \
				or center.x <= view.get_center().x or center.distance_to(attack_c) > attack_rect.size.x * 1.5:
			printerr("hud round: control %s outside the thumb cluster around %s" % [rect, attack_rect])
			return false
		if rect != build_rect and center.x >= attack_c.x and center.y >= attack_c.y:
			printerr("hud round: satellite %s must sit above or west of Attack %s" % [rect, attack_rect])
			return false
	if run_rect.intersects(wheel_rect) or build_rect.intersects(run_rect) \
			or build_rect.intersects(wheel_rect) or build_rect.position.y <= menu.get_global_rect().end.y:
		printerr("hud round: overlapping cluster or Buildings on the top row")
		return false
	return true


func _picker_ok() -> bool:
	var buildings := current_scene.get_node(BUILDINGS) as Button
	var picker := current_scene.get_node("CanvasLayer1/BuildPicker") as Control
	var view := current_scene.get_viewport().get_visible_rect()
	var origin := buildings.get_global_rect().get_center()
	var count := 0
	for child in picker.get_children():
		var button := child as Button
		if button == null or not button.visible:
			continue
		count += 1
		var rect := button.get_global_rect()
		if not view.encloses(rect) or rect.get_center().x > origin.x \
				or rect.get_center().distance_to(origin) > 92.0 or not _round(button):
			printerr("hud round: %s misplaced at %s" % [button.name, rect])
			return false
	return count == 6


func _buttons_outside(panel: Control) -> bool:
	var panel_rect := panel.get_global_rect()
	for path in [BUILDINGS, MAP_BUTTON]:
		var button := current_scene.get_node(path) as Control
		if button.get_global_rect().intersects(panel_rect):
			printerr("hud round: %s %s hits the minimap %s" % [path, button.get_global_rect(), panel_rect])
			return false
	return true


func _icon_is(button: Control, file_name: String) -> bool:
	var icon: Texture2D = button.get("icon")
	return icon != null and str(icon.resource_path).ends_with(file_name)


func _disc_is(button: Button, stem: String) -> bool:
	var box := button.get_theme_stylebox("normal") as StyleBoxTexture
	return box != null and box.texture != null and stem in str(box.texture.resource_path)


func _round(button: Button, hit := RoundHudStyle.HIT) -> bool:
	var box := button.get_theme_stylebox("normal") as StyleBoxTexture
	if box == null or box.texture == null:
		return false
	return absf(button.size.x - button.size.y) <= 1.0 and is_equal_approx(button.size.x, hit)


func _selected(button: Button) -> bool:
	if not button.button_pressed:
		return false
	var box := button.get_theme_stylebox("pressed") as StyleBoxTexture
	if box == null or box.texture == null:
		return false
	var path := str(box.texture.resource_path)
	return "_selected" in path or "_pressed" in path