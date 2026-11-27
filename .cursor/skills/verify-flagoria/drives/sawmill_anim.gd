extends "res://.cursor/skills/verify-flagoria/drives/place_sawmill.gd"
## launch: --seed 4

const ADDRESS := MULTIPLAYER_VIEW + "/Actions/AddressEntry"
const WORLD_LIST := WORLDS_VIEW + "/Body/Scroll/List"
const CLIENT := "--sawmill-drive-client"


func run() -> void:
	if CLIENT in OS.get_cmdline_user_args():
		var ok := await _join_game() and await _play_joiner()
		if not ok:
			printerr("sawmill: joiner failed to connect, place, or leave")
		_finished = true
		quit(0 if ok else 1)
		return
	if not await start_game():
		return
	var client_pid := _launch_joiner()
	if client_pid == -1:
		_fail("sawmill: could not start the joiner")
		return
	var ok := await _play_host(client_pid)
	if OS.is_process_running(client_pid):
		OS.kill(client_pid)
	done(ok)


func _play_host(client_pid: int) -> bool:
	var map: TileMap = current_scene.get_node(WORLD_MAP)
	step("wait for the joiner's sawmill")
	await wait_until(
		func() -> bool:
			return not _placement(map).is_empty() or not OS.is_process_running(client_pid),
		40.0
	)
	var placement := _placement(map)
	if placement.is_empty():
		return false
	var mill := _mill(map, placement)
	for moment in [[0, "saw-retracted"], [3, "saw-extended"]]:
		step("capture %s" % moment[1])
		if not await _capture_frame(mill, moment[0], moment[1]):
			return false

	step("ask the joiner to leave through Main menu")
	var signal_file := FileAccess.open(_leave_path(), FileAccess.WRITE)
	if signal_file == null:
		return false
	signal_file.close()
	if not await wait_until(func() -> bool: return _idle(mill), 10.0):
		return false
	await snapshot("placed-idle")

	step("save and reload the sawmill with its owner absent")
	return await _capture_reload(placement["anchor"])


func _join_game() -> bool:
	if change_scene_to_file(MAIN) != OK or not await wait_until(menu_root_visible, START_TIMEOUT_S):
		return false
	await click(MULTIPLAYER_BUTTON)
	await click(ADDRESS)
	var keyboard := current_scene.find_child("LetterKeyboard", true, false)
	for key in ["l", "o", "c", "a", "l", "h", "o", "s", "t", "OK"]:
		var button := keyboard.find_child(key, true, false)
		await click(str(current_scene.get_path_to(button)))
	var address := current_scene.get_node(ADDRESS) as LineEdit
	if address.text != "localhost":
		printerr("sawmill: localhost address was not entered")
		return false
	step("join localhost")
	await click(JOIN_BUTTON)
	return await wait_until(func() -> bool: return hero() != null, START_TIMEOUT_S)


func _play_joiner() -> bool:
	var map: TileMap = current_scene.get_node(WORLD_MAP)
	var interaction: Interaction = current_scene.get_node(INTERACTION)
	var target: Variant = _saw_site(map, interaction)
	for action in ["ui_down", "ui_right", "ui_up", "ui_left", "ui_left", "ui_down"]:
		if target != null:
			break
		await _walk(action)
		target = _saw_site(map, interaction)
	if target == null:
		return false
	await grant_resources()
	var inventory: Inventory = current_scene.get_node(INVENTORY)
	if not await wait_until(func() -> bool: return inventory.count_of(Inventory.STONE) >= 15, 5.0):
		return false
	await click(BUILDINGS)
	await snapshot("picker")
	await click(SAWMILL_BUTTON)
	await _drag(map, interaction, target, func() -> void: await snapshot("preview"))
	if not await wait_until(func() -> bool: return not _placement(map).is_empty(), 5.0):
		return false
	var mill := _mill(map, _placement(map))
	if not await _capture_frame(mill, 3, "joiner-sawing"):
		return false
	if not await wait_until(func() -> bool: return FileAccess.file_exists(_leave_path()), 15.0):
		return false
	await click(MENU_BUTTON)
	await click(MENU_ROWS + "/MainMenu")
	return await wait_until(menu_root_visible, 5.0)


func _launch_joiner() -> int:
	var args := ["--path", ProjectSettings.globalize_path("res://")]
	if DisplayServer.get_name() == "headless":
		args.append("--headless")
	else:
		args.append_array(["--rendering-driver", "opengl3"])
	args.append_array(["--script", (get_script() as Script).resource_path, "--", CLIENT])
	# Share drive evidence while keeping each player's settings, saves and cache separate.
	var xdg := {}
	for key in ["XDG_DATA_HOME", "XDG_CONFIG_HOME", "XDG_CACHE_HOME"]:
		xdg[key] = OS.get_environment(key)
		var scratch := String(xdg[key]).path_join("sawmill-joiner")
		DirAccess.make_dir_recursive_absolute(scratch)
		OS.set_environment(key, scratch)
	var pid := OS.create_process(OS.get_executable_path(), args)
	for key in xdg:
		OS.set_environment(key, xdg[key])
	return pid


func _leave_path() -> String:
	return OS.get_environment("VERIFY_EVIDENCE_DIR").path_join("sawmill-leave")


func _saw_site(map: TileMap, interaction: Interaction) -> Variant:
	var placer := ConstructionPlacer.new(map)
	for cell in _nearby_cells(map, interaction):
		if placer.can_place_geometry(BuildCosts.SAWMILL, [cell]).is_empty():
			return cell
	return null


func _placement(map: TileMap) -> Dictionary:
	for placement: Dictionary in map.placed_structures().values():
		if placement["name"] == "sawmill":
			return map.structure_placement_at(placement["anchor"])
	return {}


func _mill(map: TileMap, placement: Dictionary) -> SawmillAnim:
	return map.get_node_or_null("SawmillAnim_%d" % placement["id"]) as SawmillAnim


func _idle(mill: SawmillAnim) -> bool:
	return mill != null and not mill.is_playing() and mill.frame == 0 and not _sound(mill).playing


func _sound(mill: SawmillAnim) -> AudioStreamPlayer2D:
	return mill.get_node("SawingSound") as AudioStreamPlayer2D


func _capture_frame(mill: SawmillAnim, frame: int, label: String) -> bool:
	if (
		mill == null
		or not await wait_until(
			func() -> bool: return mill.is_playing() and mill.frame == frame, 4.0
		)
	):
		return false
	if frame == 0 and not _sound(mill).playing:
		return false
	await snapshot(label)
	return true


func _reload() -> bool:
	if not await menu_save():
		return false
	await click(MENU_ROWS + "/MainMenu")
	if not await wait_until(menu_root_visible, 10.0):
		return false
	await click(WORLDS_BUTTON)
	var list: ItemList = current_scene.get_node(WORLD_LIST)
	if list.item_count != 1:
		return false
	var at := to_window(list, list.get_item_rect(0).get_center())
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = at
		event.pressed = pressed
		Input.parse_input_event(event)
		await process_frame
	await click(WORLDS_VIEW + "/Body/Actions/Load")
	return await wait_until(func() -> bool: return hero() != null, 10.0)


func _capture_reload(anchor: Vector2i) -> bool:
	if not await _reload():
		return false
	var map: TileMap = current_scene.get_node(WORLD_MAP)
	var restored := _placement(map)
	if restored.get("anchor") != anchor or not _idle(_mill(map, restored)):
		return false
	await snapshot("reloaded-idle")
	return true
