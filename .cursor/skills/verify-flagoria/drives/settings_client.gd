extends "res://.cursor/skills/verify-flagoria/bin/drive_base.gd"

const SETTINGS := "CanvasLayer2/MainMenu/SettingsPanel/SettingsLayout"
const CUSTOMIZE := SETTINGS + "/Scroll/SettingsRows/CustomizeHud"
const EDITOR := "CanvasLayer1/InGameMenu/HudLayoutEdit"


func run() -> void:
	var window_size := Vector2i(2400, 1080)
	if DisplayServer.get_name() != "headless":
		root.size = window_size
	if change_scene_to_file(MAIN) != OK or not await wait_until(menu_root_visible, START_TIMEOUT_S):
		_fail("main menu did not open")
		return
	print("VERIFY_READY pid=%d scene=%s" % [OS.get_process_id(), MAIN])
	if DisplayServer.get_name() != "headless" and root.size != window_size:
		_fail("expected a 2400x1080 window")
		return

	if not await visit_settings():
		return

	step("worlds-gameplay")
	await click(WORLDS_BUTTON)
	await snapshot("worlds-gameplay")
	await click(WORLDS_VIEW + "/Body/Actions/Back")
	done(menu_root_visible())


func visit_settings() -> bool:
	step("settings")
	await click(MENU_ROOT + "/SettingsButton")
	var settings: Control = current_scene.get_node(SETTINGS)
	await snapshot("settings")

	step("customize-hud")
	await click(CUSTOMIZE)
	var editor: Control = current_scene.get_node(EDITOR)
	if not editor.is_visible_in_tree() or settings.is_visible_in_tree() or hero() != null:
		return _fail("expected the HUD editor over a preview without a match")
	await snapshot("customize-hud")
	if not await move_and_save_map_button():
		return _fail("dragging and saving the preview Map button did not persist its new position")
	await click(EDITOR + "/TopBar/Margin/Row/Done")
	if editor.is_visible_in_tree() or not settings.is_visible_in_tree() or menu_root_visible():
		return _fail("Done did not return to Settings")
	await click(CUSTOMIZE)
	await tap_key(KEY_ESCAPE)
	if editor.is_visible_in_tree() or not settings.is_visible_in_tree() or menu_root_visible():
		return _fail("Back did not return to Settings")
	await click(SETTINGS + "/BackButton")
	if not menu_root_visible():
		return _fail("Settings Back did not return to the root")
	return true


func move_and_save_map_button() -> bool:
	var control: Button = current_scene.get_node("CanvasLayer1/MapButton")
	var before := control.position
	var start := to_window(control, control.size * 0.5)
	var end := to_window(control, control.size * 0.5 + Vector2(-60, 50))
	var touch := InputEventScreenTouch.new()
	touch.position = start
	touch.pressed = true
	Input.parse_input_event(touch)
	await process_frame
	var drag := InputEventScreenDrag.new()
	drag.position = end
	Input.parse_input_event(drag)
	await process_frame
	var release := InputEventScreenTouch.new()
	release.position = end
	Input.parse_input_event(release)
	await process_frame
	await click(EDITOR + "/TopBar/Margin/Row/Save")
	return (
		control.position.distance_to(before) > 40.0
		and FileAccess.file_exists("user://hud_layout.cfg")
	)
