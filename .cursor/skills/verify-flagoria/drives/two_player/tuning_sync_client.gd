extends "res://.cursor/skills/verify-flagoria/drives/two_player/tuning_sync_host.gd"

const KEYBOARD := "CanvasLayer2/MainMenu/LetterKeyboard"


func run() -> void:
	if DisplayServer.get_name() != "headless":
		root.size = WINDOW_SIZE
	if change_scene_to_file(MAIN) != OK or not await wait_until(menu_root_visible, START_TIMEOUT_S):
		_fail("main menu did not open")
		return

	step("join the host using the Multiplayer menu")
	await click(MULTIPLAYER_BUTTON)
	await click(MULTIPLAYER_VIEW + "/Actions/AddressEntry")
	var keyboard := current_scene.get_node(KEYBOARD)
	var keys := ["l", "o", "c", "a", "l", "h", "o", "s", "t", "Colon"]
	for digit in str(DRIVE_PORT):
		keys.append("Digit" + digit)
	keys.append("OK")
	for key in keys:
		await click(str(current_scene.get_path_to(keyboard.find_child(key, true, false))))
	await click(JOIN_BUTTON)
	if not await wait_until(
		func() -> bool: return hero() != null and current_scene.world_params != null,
		START_TIMEOUT_S
	):
		_fail("joiner did not enter the world")
		return
	print("VERIFY_READY pid=%d scene=%s" % [OS.get_process_id(), MAIN])

	step("open the joiner's Tuning panel with the host's Castle wood value")
	await _touch(MENU_BUTTON)
	await _touch(TUNING_BUTTON)
	if not _shows_value(CASTLE_WOOD, "40") or not _check_touch_targets(CASTLE_WOOD):
		_fail("the joiner's Tuning panel did not show Castle wood at 40")
		return
	await snapshot("joiner-castle-wood-40")

	step("touch + on Mine wood and wait for the host's value")
	var scroll: ScrollContainer = current_scene.get_node(SCROLL)
	var start := to_window(scroll, scroll.size * Vector2(0.5, 0.8))
	var end := to_window(scroll, scroll.size * Vector2(0.5, 0.35))
	await BuildDrag.drag_touch(self, start, end)
	if not _check_touch_targets(MINE_WOOD):
		_fail("Mine wood stepper is undersized")
		return
	await _touch(MINE_WOOD + "/Increase")
	if not await wait_until(_shows_value.bind(MINE_WOOD, "16"), 5):
		_fail("the joiner's Mine wood value did not update to 16")
		return
	await snapshot("joiner-mine-wood-16")

	step("show a castle build preview using the host's cost")
	await _touch(CONTENT + "/Header/Close")
	await _touch(MENU_ROWS + "/Resume")
	await click("CanvasLayer1/BuildingsButton")
	await click("CanvasLayer1/BuildPicker/CastleButton")
	if not await _show_preview(
		BuildCosts.CASTLE, Vector2i(40, 15), "castle-build-preview", ["", "ui_down", "ui_down"]
	):
		await snapshot("preview-diagnostic")
		_fail("no reachable castle preview showing 40 wood and 15 stone")
		return

	step("leave through the in-game menu")
	await _touch(MENU_BUTTON)
	await _touch(MENU_ROWS + "/MainMenu")
	done(await wait_until(menu_root_visible, 5))
