extends "res://tests/helpers/test_helpers.gd"

const MENU := "CanvasLayer2/MainMenu"
const TOP := MENU + "/MarginContainer/VBoxContainer"
const SETTINGS := MENU + "/SettingsPanel/SettingsLayout"


func _test_main_menu_landscape_layout() -> int:
	print("-- test_main_menu_landscape_layout")
	var original_size := root.size
	var scene := await mount_ui_scene(preload("res://flagoria_main.tscn"), Vector2i(2400, 1080), 5)
	var top: VBoxContainer = scene.get_node(TOP)
	var fail := check_menu_bounds(top)
	var open: Button = top.get_node("SettingsButton")
	var settings: VBoxContainer = scene.get_node(SETTINGS)
	var back: Button = settings.get_node("BackButton")
	var scroll: ScrollContainer = settings.get_node("Scroll")
	await click_menu_button(open)
	if top.is_visible_in_tree() or not settings.is_visible_in_tree():
		printerr("FAIL main_menu_landscape_layout: Settings click did not switch views")
		fail += 1
	else:
		fail += check_menu_bounds(settings)
		var rows: VBoxContainer = scroll.get_node("SettingsRows")
		var first: Control = rows.get_node("MusicVolumeRow")
		if not scroll.get_global_rect().encloses(first.get_global_rect()):
			printerr("FAIL main_menu_landscape_layout: scroll does not start at Music")
			fail += 1
		await click_menu_button(back)
		if settings.is_visible_in_tree() or not top.is_visible_in_tree():
			printerr("FAIL main_menu_landscape_layout: Back click did not return to the menu")
			fail += 1
		else:
			fail += check_menu_bounds(top)
	await free_ui_scene(scene)
	root.size = original_size
	if fail == 0:
		print("PASS test_main_menu_landscape_layout")
	return fail


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
