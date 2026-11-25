extends "res://tests/helpers/test_helpers.gd"

const MENU := "CanvasLayer2/MainMenu"
const TOP := MENU + "/MarginContainer/VBoxContainer"
const SETTINGS := MENU + "/SettingsPanel/SettingsLayout"


func _test_main_menu_landscape_layout() -> int:
	print("-- test_main_menu_landscape_layout")
	var original_size := root.size
	var fail := 0
	for size in [Vector2i(2400, 1080), Vector2i(480, 270)]:
		var scene := await mount_ui_scene(preload("res://flagoria_main.tscn"), size, 5)
		fail += await check_settings_navigation(scene)
		await free_ui_scene(scene)
	root.size = original_size
	if fail == 0:
		print("PASS test_main_menu_landscape_layout")
	return fail


func check_settings_navigation(scene: Node) -> int:
	var top: VBoxContainer = scene.get_node(TOP)
	var fail := check_menu_bounds(top)
	var open: Button = top.get_node("SettingsButton")
	var settings_buttons := 0
	for child in top.get_children():
		if child is Button and child.text.containsn("settings"):
			settings_buttons += 1
	if settings_buttons != 1 or open.text != "Settings" or top.has_node("MapSettingsButton"):
		printerr("FAIL main_menu_landscape_layout: expected one Settings entry")
		fail += 1
	var settings: VBoxContainer = scene.get_node(SETTINGS)
	var back: Button = settings.get_node("BackButton")
	var map_button: Button = settings.get_node_or_null("MapSettingsButton")
	var scroll: ScrollContainer = settings.get_node("Scroll")
	await click_menu_button(open)
	if top.is_visible_in_tree() or not settings.is_visible_in_tree():
		printerr("FAIL main_menu_landscape_layout: Settings click did not switch views")
		return fail + 1
	fail += check_menu_bounds(settings)
	var first: Control = scroll.get_node("SettingsRows/MusicVolumeRow")
	if not scroll.get_global_rect().encloses(first.get_global_rect()):
		printerr("FAIL main_menu_landscape_layout: scroll does not start at Music")
		fail += 1
	if map_button == null or not map_button.is_visible_in_tree():
		printerr("FAIL main_menu_landscape_layout: Map Settings button is missing")
		return fail + 1
	var menu: Control = scene.get_node(MENU)
	var admin: Control = scene.get_node("CanvasLayer2/MapAdminPanel")
	await click_menu_button(map_button)
	if menu.is_visible_in_tree() or not admin.is_visible_in_tree():
		printerr("FAIL main_menu_landscape_layout: Map Settings did not open")
		return fail + 1
	await click_menu_button(admin.get_node("Margin/VBox/ButtonsDefaults/Back"))
	if admin.is_visible_in_tree() or top.is_visible_in_tree() or not settings.is_visible_in_tree():
		printerr("FAIL main_menu_landscape_layout: admin Back did not return to Settings")
		return fail + 1
	await click_menu_button(back)
	if settings.is_visible_in_tree() or not top.is_visible_in_tree():
		printerr("FAIL main_menu_landscape_layout: Settings Back did not return to the menu")
		return fail + 1
	return fail + check_menu_bounds(top)


func check_menu_bounds(top: VBoxContainer) -> int:
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
