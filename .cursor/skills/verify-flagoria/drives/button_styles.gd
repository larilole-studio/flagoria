extends "res://.cursor/skills/verify-flagoria/bin/drive_base.gd"
## launch: --seed 42

const WINDOW_SIZE := Vector2i(2400, 1080)
const SETTINGS := "CanvasLayer2/MainMenu/SettingsPanel/SettingsLayout"
const MENU_ROWS := MENU_PANEL + "/Panel/Margin/VBox"
const TUNING := "CanvasLayer1/InGameMenu/TuningPanel"
const PARCHMENT := "CanvasLayer1/ParchmentMap"


func run() -> void:
	if DisplayServer.get_name() != "headless":
		root.size = WINDOW_SIZE
	if change_scene_to_file(MAIN) != OK or not await wait_until(menu_root_visible, START_TIMEOUT_S):
		_fail("main menu did not open")
		return

	if DisplayServer.get_name() != "headless" and root.size != WINDOW_SIZE:
		_fail("expected a 2400x1080 window")
		return
	if not await _front_menu():
		return
	await _in_match()


func _front_menu() -> bool:
	await snapshot("main-menu")
	if not await _open(WORLDS_BUTTON, WORLDS_VIEW):
		return false
	await snapshot("worlds")
	if (
		not await _open(WORLDS_VIEW + "/Body/Actions/Back", MENU_ROOT)
		or not await _open(MULTIPLAYER_BUTTON, MULTIPLAYER_VIEW)
	):
		return false
	await snapshot("multiplayer")
	if (
		not await _open(MULTIPLAYER_VIEW + "/Actions/BackButton", MENU_ROOT)
		or not await _open(MENU_ROOT + "/SettingsButton", SETTINGS)
	):
		return false
	await snapshot("settings")
	return await _open(SETTINGS + "/BackButton", MENU_ROOT)


func _in_match() -> void:
	if not await start_game() or not await _open(MENU_BUTTON, MENU_PANEL):
		return
	await snapshot("ingame-menu")
	if not await _open(MENU_ROWS + "/ResourceGrants/Tuning", TUNING):
		return
	await snapshot("tuning")
	if not await _open(TUNING + "/Margin/Content/Header/Close", MENU_PANEL):
		return
	await click(MENU_ROWS + "/Resume")
	if not await _open("CanvasLayer1/MapButton", PARCHMENT):
		return
	var sheet: ParchmentMap = current_scene.get_node(PARCHMENT)
	if not _toolbar_flush(sheet):
		return
	await snapshot("parchment")
	done(true)


func _toolbar_flush(sheet: ParchmentMap) -> bool:
	for name in ["ZoomOutButton", "ZoomInButton", "RecentreButton", "CloseButton"]:
		var button: Control = sheet.get_node(name)
		if not button.is_visible_in_tree() or button.position.y != sheet.BUTTON_MARGIN:
			return _fail("parchment toolbar button is missing or shifted: " + name)
	var close: Control = sheet.get_node("CloseButton")
	return (
		close.get_rect().end.x == sheet.size.x - sheet.BUTTON_MARGIN
		or _fail("parchment toolbar is not flush to the right")
	)


func _open(button: String, view: String) -> bool:
	step("press-" + button.get_file().to_snake_case())
	await click(button)
	var control: Control = current_scene.get_node(view)
	return control.is_visible_in_tree() or _fail("did not open " + view)
