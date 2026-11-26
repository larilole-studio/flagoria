extends "res://tests/helpers/test_helpers.gd"

const MENU := "CanvasLayer2/MainMenu"
const TOP := MENU + "/MarginContainer/VBoxContainer"
const WORLDS := "CanvasLayer2/WorldsPanel/Margin/VBox"
const MAP_SETTINGS := "CanvasLayer2/MapAdminPanel"
const MULTIPLAYER := MENU + "/MultiplayerPanel/VBoxContainer"
const SETTINGS := MENU + "/SettingsPanel/SettingsLayout"
const EDITOR := "CanvasLayer1/InGameMenu/HudLayoutEdit"
const GAMEPLAY_ROWS := [
	"MobRateRow",
	"TowerRangeRow",
	"TowerDamageRow",
	"TowerCooldownRow",
	"RaidsRow",
	"RaidIntervalRow",
	"RaidGroupRow",
	"RaidRadiusRow",
]


func _test_main_menu_landscape_layout() -> int:
	print("-- test_main_menu_landscape_layout")
	var original_size := root.size
	var fail := 0
	for size in [Vector2i(2400, 1080), Vector2i(480, 270)]:
		var scene := await mount_ui_scene(preload("res://flagoria_main.tscn"), size, 5)
		fail += await check_menu_navigation(scene)
		await free_ui_scene(scene)
	root.size = original_size
	if fail == 0:
		print("PASS test_main_menu_landscape_layout")
	return fail


func check_menu_navigation(scene: Node) -> int:
	var top: VBoxContainer = scene.get_node(TOP)
	var names := []
	for child in top.get_children():
		if child is Button:
			names.append(child.text)
	if names != ["Worlds", "Multiplayer", "Settings"] or top.get_child_count() != 4:
		printerr("FAIL main_menu_landscape_layout: unexpected root controls %s" % names)
		return 1
	var fail := check_menu_bounds(top)

	fail += await check_worlds_navigation(scene, top)
	if not top.is_visible_in_tree():
		return fail

	await click_menu_button(top.get_node("MultiplayerButton"))
	var multiplayer: Control = scene.get_node(MULTIPLAYER)
	if (
		top.is_visible_in_tree()
		or not multiplayer.get_node("Actions/AddressEntry").is_visible_in_tree()
		or not multiplayer.get_node("Actions/JoinButton").is_visible_in_tree()
	):
		printerr("FAIL main_menu_landscape_layout: Multiplayer did not show the address and Join")
		return fail + 1
	fail += check_menu_bounds(multiplayer)
	await click_menu_button(multiplayer.get_node("Actions/BackButton"))
	if multiplayer.is_visible_in_tree() or not top.is_visible_in_tree():
		printerr("FAIL main_menu_landscape_layout: Multiplayer Back did not return to the root")
		return fail + 1

	return fail + await check_settings_navigation(scene, top)


func check_settings_navigation(scene: Node, top: Control) -> int:
	var fail := 0
	await click_menu_button(top.get_node("SettingsButton"))
	var settings: Control = scene.get_node(SETTINGS)
	if (
		top.is_visible_in_tree()
		or not settings.is_visible_in_tree()
		or settings.find_child("MapSettingsButton", true, false) != null
	):
		printerr("FAIL main_menu_landscape_layout: unexpected Settings view")
		return fail + 1
	fail += check_menu_bounds(settings)
	var scroll: ScrollContainer = settings.get_node("Scroll")
	var rows: VBoxContainer = scroll.get_node("SettingsRows")
	for child_name in ["MusicVolumeRow", "SFXVolumeRow", "CustomizeHud"]:
		var child := rows.get_node_or_null(child_name) as Control
		if child == null or not scroll.get_global_rect().encloses(child.get_global_rect()):
			printerr("FAIL main_menu_landscape_layout: Settings does not show %s" % child_name)
			return fail + 1
	for row in GAMEPLAY_ROWS:
		if settings.find_child(row, true, false) != null:
			printerr("FAIL main_menu_landscape_layout: %s is still in Settings" % row)
			fail += 1
	await click_menu_button(rows.get_node("CustomizeHud"))
	var editor: Control = scene.get_node(EDITOR)
	if not editor.is_visible_in_tree() or settings.is_visible_in_tree():
		printerr("FAIL main_menu_landscape_layout: HUD preview did not open")
		return fail + 1
	for frame in 5:
		await process_frame
	if not editor.bar_fits_viewport():
		printerr("FAIL main_menu_landscape_layout: HUD toolbar exceeded the viewport")
		return fail + 1
	await click_menu_button(editor.get_node("TopBar/Margin/Row/Done"))
	if editor.is_visible_in_tree() or not settings.is_visible_in_tree():
		printerr("FAIL main_menu_landscape_layout: HUD Done did not return to Settings")
		return fail + 1
	await click_menu_button(settings.get_node("BackButton"))
	if settings.is_visible_in_tree() or not top.is_visible_in_tree():
		printerr("FAIL main_menu_landscape_layout: Settings Back did not return to the root")
		fail += 1
	return fail + check_menu_bounds(top)


func check_worlds_navigation(scene: Node, top: Control) -> int:
	var fail := 0
	await click_menu_button(top.get_node("WorldsButton"))
	var worlds: Control = scene.get_node_or_null(WORLDS)
	if worlds == null or not worlds.is_visible_in_tree() or top.is_visible_in_tree():
		printerr("FAIL main_menu_landscape_layout: Worlds did not open")
		return fail + 1
	var actions: VBoxContainer = worlds.get_node("Body/Actions")
	var host: Button = actions.get_node("HostButton")
	var map_button: Button = actions.get_node("MapSettingsButton")
	if not host.is_visible_in_tree() or not map_button.is_visible_in_tree():
		printerr("FAIL main_menu_landscape_layout: Worlds actions are hidden")
		fail += 1
	var scroll: Control = worlds.get_node("Body/Scroll")
	var gameplay: ScrollContainer = worlds.get_node("Body/GameplayScroll")
	for row in GAMEPLAY_ROWS:
		if not gameplay.has_node("Rows/" + row):
			printerr("FAIL main_menu_landscape_layout: Worlds is missing %s" % row)
			fail += 1
	if scroll.size.x <= maxf(actions.size.x, gameplay.size.x):
		printerr("FAIL main_menu_landscape_layout: Worlds list is not the widest column")
		fail += 1
	if root.size.x == 2400 and scroll.size.x <= actions.size.x + gameplay.size.x:
		printerr("FAIL main_menu_landscape_layout: saved worlds use less than half the body")
		fail += 1
	if scroll.get_global_rect().size.y < actions.get_global_rect().size.y * 0.8:
		printerr("FAIL main_menu_landscape_layout: Worlds list is shorter than the actions")
		fail += 1
	fail += check_menu_bounds(worlds) + check_menu_bounds(actions)
	var admin: Control = scene.get_node(MAP_SETTINGS)
	await click_menu_button(map_button)
	if top.is_visible_in_tree() or worlds.is_visible_in_tree() or not admin.is_visible_in_tree():
		printerr("FAIL main_menu_landscape_layout: Map Settings did not replace Worlds")
		return fail + 1
	await click_menu_button(admin.get_node("Margin/VBox/ButtonsDefaults/Back"))
	if admin.is_visible_in_tree() or top.is_visible_in_tree() or not worlds.is_visible_in_tree():
		printerr("FAIL main_menu_landscape_layout: Map Settings Back did not return to Worlds")
		return fail + 1
	await click_menu_button(worlds.get_node("Body/Actions/Back"))
	if worlds.is_visible_in_tree() or not top.is_visible_in_tree():
		printerr("FAIL main_menu_landscape_layout: Worlds Back did not return to the root")
		return fail + 1
	return fail


func check_menu_bounds(top: Control) -> int:
	var fail := 0
	var viewport := top.get_viewport_rect()
	for control: Control in top.get_children():
		if control.is_visible_in_tree() and not viewport.encloses(control.get_global_rect()):
			printerr(
				(
					"FAIL main_menu_landscape_layout: %s %s outside %s"
					% [control.name, control.get_global_rect(), viewport]
				)
			)
			fail += 1
	return fail


func click_menu_button(button: Button) -> void:
	var at := button.get_global_rect().get_center()
	for pressed in [true, false]:
		var click := InputEventMouseButton.new()
		click.position = at
		click.global_position = at
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = pressed
		root.push_input(click, true)
		await process_frame
	await process_frame
