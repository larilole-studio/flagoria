extends "res://.cursor/skills/verify-flagoria/bin/drive_base.gd"
## launch: --seed 42
## Check the common and Advanced views, then host with the displayed settings.

const PANEL := "CanvasLayer2/MapAdminPanel"
const ADVANCED := PANEL + "/Margin/VBox/Advanced"
const COMMON := PANEL + "/Margin/VBox/Simple"
const RAW := PANEL + "/Margin/VBox/Scroll"
const FORM := RAW + "/Form"
const BACK := PANEL + "/Margin/VBox/ButtonsDefaults/Back"
const START := PANEL + "/Margin/VBox/Buttons2/Start"
## The five action buttons, in row order.
const ACTION_BUTTONS := [
	"CanvasLayer2/MapAdminPanel/Margin/VBox/Buttons/RandomSeed",
	"CanvasLayer2/MapAdminPanel/Margin/VBox/Buttons/RandomSpecs",
	"CanvasLayer2/MapAdminPanel/Margin/VBox/ButtonsDefaults/Reset",
	"CanvasLayer2/MapAdminPanel/Margin/VBox/ButtonsDefaults/Back",
	"CanvasLayer2/MapAdminPanel/Margin/VBox/Buttons2/Start",
]


func run() -> void:
	step("menu")
	if change_scene_to_file(MAIN) != OK:
		_fail("cannot load " + MAIN)
		return
	if not await wait_until(menu_root_visible, START_TIMEOUT_S):
		_fail("main menu did not open")
		return
	print("VERIFY_READY pid=%d scene=%s" % [OS.get_process_id(), MAIN])
	var landscape := Vector2i(854, 480)
	var configured := OS.get_environment("VERIFY_WINDOW_SIZE").split("x")
	if configured.size() == 2:
		landscape = Vector2i(int(configured[0]), int(configured[1]))
	var actual := await _resize(landscape.x, landscape.y)
	var layout_ok := DisplayServer.get_name() == "headless" or actual == landscape
	await snapshot("main-menu")
	step("open-worlds")
	await click(WORLDS_BUTTON)
	await snapshot("worlds")
	step("open-map-settings")
	await click(MAP_SETTINGS_BUTTON)
	if not await wait_until(
		func() -> bool:
			var p = current_scene.get_node_or_null(PANEL)
			return p != null and p.visible,
		5.0
	):
		_fail("Map Settings panel did not open")
		return
	var panel: Node = current_scene.get_node(PANEL)
	var simple: Control = current_scene.get_node(COMMON)
	var raw: Control = current_scene.get_node(RAW)
	layout_ok = _buttons_fit("common") and simple.visible and not raw.visible and layout_ok
	for control_name in ["IslandSize", "BiomeSize", "SpawnBiome"]:
		var option: OptionButton = panel.find_child(control_name, true, false)
		layout_ok = simple.get_global_rect().encloses(option.get_global_rect()) and layout_ok
	await snapshot("map-settings-common")

	step("advanced")
	await click(ADVANCED)
	layout_ok = _buttons_fit("advanced") and raw.visible and not simple.visible and layout_ok
	var seeds: Control = current_scene.get_node(FORM + "/Seeds/Rows")
	var chunks: Control = current_scene.get_node(FORM + "/Chunks/Rows")
	layout_ok = (
		_only_group_open("Seeds")
		and raw.get_global_rect().encloses(seeds.get_global_rect())
		and layout_ok
	)
	await snapshot("map-settings-advanced")

	step("collapse-seeds")
	await click(FORM + "/Seeds/Header")
	layout_ok = _only_group_open("") and layout_ok
	step("expand-chunks")
	await click(FORM + "/Chunks/Header")
	layout_ok = _only_group_open("Chunks") and layout_ok
	await _scroll_down(raw, 3.2)
	layout_ok = raw.get_global_rect().encloses(chunks.get_global_rect()) and layout_ok
	await snapshot("map-settings-chunks")
	step("collapse-chunks")
	await click(FORM + "/Chunks/Header")
	layout_ok = _only_group_open("") and layout_ok
	await _scroll_down(raw, 4.0)
	await snapshot("map-settings-collapsed")
	await click(ADVANCED)

	step("back")
	await click(BACK)
	var worlds_back := await wait_until(
		func() -> bool:
			var map_button: Button = current_scene.get_node(MAP_SETTINGS_BUTTON)
			return map_button.is_visible_in_tree() and not panel.visible,
		5.0
	)
	if not worlds_back:
		_fail("Back did not return to Worlds")
		return
	await click(MAP_SETTINGS_BUTTON)
	step("reopen-advanced")
	await click(ADVANCED)
	layout_ok = _only_group_open("Seeds") and layout_ok
	await click(ADVANCED)
	step("host-with-these")
	await click(START)
	if not await wait_until(func() -> bool: return hero() != null, START_TIMEOUT_S):
		_fail("Host with these did not start the world")
		return
	await snapshot("spawn")
	done(layout_ok)


func _only_group_open(open_group: String) -> bool:
	for group in current_scene.get_node(FORM).get_children():
		if group.get_node("Rows").is_visible_in_tree() != (group.name == open_group):
			printerr("Map Settings: unexpected row visibility for ", group.name)
			return false
	return true


func _scroll_down(scroll: Control, amount: float) -> void:
	var at := to_window(scroll, Vector2(8, scroll.size.y / 2.0))
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_WHEEL_DOWN
		event.pressed = pressed
		event.factor = amount
		event.position = at
		event.global_position = at
		Input.parse_input_event(event)
		await process_frame
		await process_frame


func _resize(width: int, height: int) -> Vector2i:
	root.size = Vector2i(width, height)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(width, height))
	for _i in 12:
		await process_frame
	var got := DisplayServer.window_get_size()
	print(
		(
			"map_settings_random: window %s (asked %dx%d) visible %s"
			% [got, width, height, root.get_visible_rect().size]
		)
	)
	return got


func _buttons_fit(tag: String) -> bool:
	var vp: Rect2 = root.get_visible_rect()
	var rects: Array[Rect2] = []
	var ok := true
	for path in ACTION_BUTTONS:
		var b: Control = current_scene.get_node_or_null(path)
		if b == null:
			print("map_settings_random: %s missing %s" % [tag, path])
			ok = false
			continue
		var rect := b.get_global_rect()
		rects.append(rect)
		var inside := vp.encloses(rect)
		print(
			(
				"map_settings_random: %s %s rect=%s size=%s inside=%s"
				% [tag, b.name, rect, b.size, inside]
			)
		)
		if not inside or b.size.x < 40.0 or b.size.y < 24.0:
			ok = false
	for i in rects.size():
		for j in range(i + 1, rects.size()):
			if rects[i].intersects(rects[j]):
				print("map_settings_random: %s overlap %s %s" % [tag, rects[i], rects[j]])
				ok = false
	return ok
