extends "res://.cursor/skills/verify-flagoria/bin/drive_base.gd"

const MAP_PANEL := "CanvasLayer2/MapAdminPanel"
const SETTINGS_VIEW := "CanvasLayer2/MainMenu/SettingsPanel/SettingsLayout"


func run() -> void:
	var window_size := Vector2i(2400, 1080)
	if DisplayServer.get_name() != "headless":
		root.size = window_size
	if change_scene_to_file(MAIN) != OK:
		_fail("cannot load " + MAIN)
		return
	if not await wait_until(menu_root_visible, START_TIMEOUT_S):
		_fail("main menu did not open")
		return
	print("VERIFY_READY pid=%d scene=%s" % [OS.get_process_id(), MAIN])
	if DisplayServer.get_name() != "headless" and root.size != window_size:
		_fail("expected a 2400x1080 window")
		return
	var labels := []
	for child in current_scene.get_node(MENU_ROOT).get_children():
		if child is Button:
			labels.append(child.text)
	if labels != ["Worlds", "Multiplayer", "Settings"]:
		_fail("unexpected root menu buttons: %s" % [labels])
		return
	step("main-menu")
	await snapshot("main-menu")

	var visits := [
		[WORLDS_BUTTON, WORLDS_VIEW, "worlds"],
		[MAP_SETTINGS_BUTTON, MAP_PANEL, "map-settings"],
		[MAP_PANEL + "/Margin/VBox/ButtonsDefaults/Back", WORLDS_VIEW, ""],
		[WORLDS_VIEW + "/Body/Actions/Back", MENU_ROOT, ""],
		[MULTIPLAYER_BUTTON, MULTIPLAYER_VIEW, "multiplayer"],
		[MULTIPLAYER_VIEW + "/Actions/BackButton", MENU_ROOT, ""],
		[MENU_ROOT + "/SettingsButton", SETTINGS_VIEW, "settings"],
		[SETTINGS_VIEW + "/BackButton", MENU_ROOT, ""],
	]
	for next in visits:
		if not await visit(next[0], next[1], next[2]):
			return
	done(true)


func visit(button: String, view: String, label := "") -> bool:
	step("press-" + button.get_file().to_snake_case())
	await click(button)
	for path in [MENU_ROOT, WORLDS_VIEW, MAP_PANEL, MULTIPLAYER_VIEW, SETTINGS_VIEW]:
		var control := current_scene.get_node_or_null(path) as Control
		if (control != null and control.is_visible_in_tree()) != (path == view):
			return _fail("expected only %s after pressing %s" % [view, button])
	if (
		view == SETTINGS_VIEW
		and not (
			current_scene
			. get_node(SETTINGS_VIEW + "/Scroll/SettingsRows/CustomizeHud")
			. is_visible_in_tree()
		)
	):
		return _fail("Settings did not show Customize HUD")
	if not label.is_empty():
		await snapshot(label)
	return true
