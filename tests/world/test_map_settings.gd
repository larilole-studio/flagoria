extends "res://tests/helpers/test_helpers.gd"
## Map Settings input, persistence and generation.

const PANEL_SCENE := preload("res://Scripts/ui/map_admin_panel.tscn")


func _test_map_settings_simple_choices() -> int:
	print("-- test_map_settings_simple_choices")
	var panel = PANEL_SCENE.instantiate()
	root.add_child(panel)
	var island := panel.find_child("IslandSize", true, false) as OptionButton
	var biome := panel.find_child("BiomeSize", true, false) as OptionButton
	var spawn := panel.find_child("SpawnBiome", true, false) as OptionButton
	var raw := panel.find_child("AltitudeSeed", true, false) as LineEdit
	if island == null or biome == null or spawn == null or raw == null or raw.is_visible_in_tree():
		printerr(
			"FAIL map_settings_simple_choices: expected three selectors and hidden raw controls"
		)
		panel.queue_free()
		return 1
	var params: MapGenParams = root.get_node("MapGen").params.duplicate_params()
	panel.load_from_params(params)
	var failures := 0
	for size in 3:
		spawn.select(size + 1)
		spawn.item_selected.emit(size + 1)
		island.select(size)
		island.item_selected.emit(size)
		biome.select(size)
		biome.item_selected.emit(size)
		panel.apply_to_params(params)
		if (
			(
				[
					params.island_radius,
					params.archipelago_spacing,
					params.archipelago_island_radius,
					params.archipelago_world_extent
				]
				!= [[80, 80, 40, 512], [140, 112, 52, 768], [200, 144, 64, 1024]][size]
			)
			or not is_equal_approx(params.biome_frequency, [0.006, 0.003, 0.002][size])
			or params.spawn_biome != size
		):
			printerr("FAIL map_settings_simple_choices: wrong preset for size ", size)
			failures += 1
	panel.queue_free()
	return failures


func _test_map_settings_water_reopen() -> int:
	## Map Settings must show the in-use water value on reopen, even when a
	## SpinBox LineEdit still holds a dirty string for the same numeric value.
	print("-- test_map_settings_water_reopen")
	var panel = PANEL_SCENE.instantiate()
	root.add_child(panel)
	panel.find_child("Advanced").button_pressed = true
	var spin := _setting_spin(panel, "water_max_alt")
	var in_use := 0.45
	spin.value = in_use
	spin.get_line_edit().text = "0.2"
	var params = _pre_biome_defaults()
	params.water_max_alt = in_use
	panel.load_from_params(params)
	var shown := float(spin.get_line_edit().text)
	panel.queue_free()
	if abs(shown - in_use) > 0.001:
		printerr("FAIL map_settings_water_reopen shown=%s want in-use=%s" % [shown, in_use])
		return 1
	print("PASS test_map_settings_water_reopen shown=%s" % shown)
	return 0


func _test_map_settings_covers_params() -> int:
	## Settings available to the host must also reach clients in the map inputs.
	print("-- test_map_settings_covers_params")
	var params := MapGenParams.make_defaults()
	var data := params.to_dict()
	var panel = PANEL_SCENE.instantiate()
	root.add_child(panel)
	var control_names := {
		"altitude_seed": "AltitudeSeed",
		"moisture_seed": "MoistureSeed",
		"temperature_seed": "TemperatureSeed",
		"items_seed": "ItemsSeed",
		"biome_seed": "BiomeSeed",
		"noise_type": "NoiseType",
		"spawn_biome": "SpawnBiome",
	}
	var fail := 0
	for prop in params.get_property_list():
		if (
			not (prop["usage"] & PROPERTY_USAGE_SCRIPT_VARIABLE)
			or (
				prop["name"]
				in ["island_preset", "starter_grove", "starter_wood", "swamp_trees", "cay_trees"]
			)
		):
			continue
		var key: String = prop["name"]
		if not data.has(key) or panel.find_child(control_names.get(key, key), true, false) == null:
			printerr("FAIL map_settings_covers_params: %s missing from map inputs or panel" % key)
			fail += 1
	panel.queue_free()
	if fail == 0:
		print("PASS test_map_settings_covers_params")
	return fail


func _test_map_settings_group_headers() -> int:
	print("-- test_map_settings_group_headers")
	var panel = PANEL_SCENE.instantiate()
	root.add_child(panel)
	panel.find_child("Advanced").button_pressed = true
	var params := MapGenParams.make_defaults()
	var form := panel.find_child("Form") as VBoxContainer
	var expected := {
		"Seeds": "AltitudeSeed",
		"Noise": "NoiseType",
		"Chunks": "chunk_width",
		"Terrain": "water_max_alt",
		"Foliage": "tree_min_chance",
		"Game": "day_night_cycle",
	}
	var rows: Array[Node] = []
	var fail := 0
	for group_name in expected:
		var group := form.get_node_or_null(NodePath(group_name))
		if group == null or group.get_child_count() != 2:
			printerr("FAIL map_settings_group_headers: missing group ", group_name)
			fail += 1
			continue
		var header := group.get_child(0) as Button
		var body := group.get_child(1) as Container
		if (
			header == null
			or not header.text.ends_with(group_name)
			or body == null
			or body.visible != (group_name == "Seeds")
			or body.find_child(expected[group_name], true, false) == null
		):
			printerr(
				"FAIL map_settings_group_headers: wrong header, default or row in ", group_name
			)
			fail += 1
			continue
		rows.append_array(body.find_children("*", "HBoxContainer", false, false))
	if (
		form.get_child_count() != expected.size()
		or rows.size() != params.exported_properties().size()
	):
		printerr("FAIL map_settings_group_headers: unexpected number of groups or rows")
		fail += 1
	for prop in params.exported_properties():
		var key: String = prop["name"]
		var matches := rows.filter(
			func(row: Node) -> bool:
				return row.name == key or row.find_child(key.to_pascal_case(), false, false) != null
		)
		if matches.size() != 1:
			printerr("FAIL map_settings_group_headers: expected one row for ", key)
			fail += 1
	panel.queue_free()
	return fail


func _test_map_settings_group_dummy_field() -> int:
	print("-- test_map_settings_group_dummy_field")
	var script := GDScript.new()
	script.source_code = """
extends MapGenParams
@export_group("Terrain")
@export var group_probe: int = 7
"""
	if script.reload() != OK:
		printerr("FAIL map_settings_group_dummy_field: could not load fixture")
		return 1
	var map_gen = root.get_node("MapGen")
	var saved: MapGenParams = map_gen.params
	var params: MapGenParams = script.new()
	map_gen.params = params
	var panel = PANEL_SCENE.instantiate()
	root.add_child(panel)
	map_gen.params = saved
	panel.find_child("Advanced").button_pressed = true
	var form := panel.find_child("Form") as VBoxContainer
	var terrain := form.get_node_or_null("Terrain")
	var row := terrain.find_child("group_probe", true, false) if terrain != null else null
	var fail := 0
	if row == null or terrain.find_child("water_max_alt", true, false) == null:
		printerr("FAIL map_settings_group_dummy_field: missing row in existing Terrain group")
		fail += 1
	else:
		var spin := row.get_child(1) as SpinBox
		if spin == null or spin.value != 7:
			printerr("FAIL map_settings_group_dummy_field: missing initial value")
			fail += 1
	panel.queue_free()
	return fail


func _test_map_settings_number_pad_touch_tap() -> int:
	## An Android-style tap must reach the pad attached to the Map Settings seed.
	print("-- test_map_settings_number_pad_touch_tap")
	var panel = PANEL_SCENE.instantiate()
	root.add_child(panel)
	panel.find_child("Advanced").button_pressed = true
	await process_frame
	var field: LineEdit = panel.find_child("AltitudeSeed", true, false)
	field.text = ""
	_tap_sequence(
		field.get_global_rect().get_center(), ["mouse_down", "touch_down", "mouse_up", "touch_up"]
	)
	await process_frame
	var pad = panel.get_node("NumberPad")
	var fail := 0
	if not pad.visible or pad.target != field:
		printerr("FAIL map_settings_number_pad_touch_tap: tap did not open the pad for the seed")
		fail += 1
	else:
		pad.find_child("Digit7", true, false).pressed.emit()
		var params := MapGenParams.make_defaults()
		panel.apply_to_params(params)
		if params.altitude_seed != 7:
			printerr(
				"FAIL map_settings_number_pad_touch_tap: seed is %s, want 7" % params.altitude_seed
			)
			fail += 1
	panel.queue_free()
	if fail == 0:
		print("PASS test_map_settings_number_pad_touch_tap")
	return fail


func _test_map_settings_number_pad_spin_boxes() -> int:
	## Editing water altitude through the field clamps the visible value. Back
	## saves it, and the reloaded setting changes the generated ground.
	print("-- test_map_settings_number_pad_spin_boxes")
	var map_gen = root.get_node("MapGen")
	var saved_params: MapGenParams = map_gen.params
	var path: String = map_gen.SAVE_PATH
	var had_config := FileAccess.file_exists(path)
	var config := FileAccess.get_file_as_bytes(path) if had_config else PackedByteArray()
	map_gen.params = _spawn_params(42, 0.0)
	var scene = load("res://flagoria_main.tscn").instantiate()
	root.add_child(scene)
	var world = scene.get_node("World/worldMap")
	map_gen.apply_to_world_map(world)
	world.generate_chunk(Vector2.ZERO)
	# Seed 42 has a walkable shore here at its starting water altitude.
	var shore := Vector2i(-14, 10)
	var was_land: bool = world.is_walkable_land(shore)

	var panel = PANEL_SCENE.instantiate()
	root.add_child(panel)
	panel.find_child("Advanced").button_pressed = true
	await process_frame
	var pad = panel.get_node("NumberPad")
	var fail := 0
	var inputs := [
		["archipelago_island_count", "-1.2", "12", 12.0],
		["ground_chance_a", "a-.5", "-.5", -0.5],
		["fractal_gain", "0.73", "0.73", 0.75],
		["water_max_alt", "a1.7", "1.7", 1.0],
	]
	for row in inputs:
		# Commit only the water edit when the panel saves at the end.
		panel.load_from_params(map_gen.params)
		var spin := _setting_spin(panel, row[0])
		var field := spin.get_line_edit()
		var header := spin.get_parent().get_parent().get_parent().get_node("Header") as Button
		header.button_pressed = true
		field.grab_focus()
		await process_frame
		field.text = ""
		for character in row[1]:
			var event := InputEventKey.new()
			event.pressed = true
			event.unicode = character.unicode_at(0)
			root.push_input(event)
		await process_frame
		if field.text != row[2]:
			printerr(
				(
					"FAIL map_settings_number_pad_spin_boxes: %s typed %s, saw %s, want %s"
					% [row[0], row[1], field.text, row[2]]
				)
			)
			fail += 1
		pad.find_child("OK", true, false).pressed.emit()
		if not field.text.is_valid_float() or not is_equal_approx(float(field.text), row[3]):
			printerr(
				(
					"FAIL map_settings_number_pad_spin_boxes: %s committed to %s, want %s"
					% [row[0], field.text, row[3]]
				)
			)
			fail += 1
		header.button_pressed = false

	panel.find_child("Back").pressed.emit()
	map_gen.params = _spawn_params(42, 0.0)
	map_gen.load_from_disk()
	if not is_equal_approx(map_gen.params.water_max_alt, 1.0):
		printerr(
			(
				"FAIL map_settings_number_pad_spin_boxes: reloaded water altitude is %s, want 1"
				% map_gen.params.water_max_alt
			)
		)
		fail += 1
	map_gen.apply_to_world_map(world)
	world.generate_chunk(Vector2.ZERO)
	if not was_land or world.get_cell_source_id(0, shore) != -1 or not world.is_open_sea(shore):
		printerr(
			(
				"FAIL map_settings_number_pad_spin_boxes: raising water did not flood the shore at %s"
				% shore
			)
		)
		fail += 1

	map_gen.params = saved_params
	if had_config:
		FileAccess.open(path, FileAccess.WRITE).store_buffer(config)
	elif FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
	panel.queue_free()
	scene.queue_free()
	await process_frame
	if fail == 0:
		print("PASS test_map_settings_number_pad_spin_boxes")
	return fail


func _setting_spin(panel: Node, setting: String) -> SpinBox:
	var row := panel.find_child(setting, true, false)
	return row.find_children("*", "SpinBox", true, false)[0] as SpinBox


func _test_map_settings_bottom_buttons_visible() -> int:
	## At 1280x720 (480x270 logical viewport), the button
	## rows pinned below the scroll area — including Back / Host — sit fully
	## inside the visible rect (#217). Time cost: ~0.2 s in verify.
	print("-- test_map_settings_bottom_buttons_visible")
	var previous_size := root.size
	root.size = Vector2i(1280, 720)
	var panel = PANEL_SCENE.instantiate()
	root.add_child(panel)
	for i in 5:
		await process_frame
	var vp: Rect2 = root.get_visible_rect()
	var fail := 0
	if not vp.size.is_equal_approx(Vector2(480, 270)):
		printerr("FAIL map_settings_bottom_buttons_visible: viewport %s want 480x270" % vp.size)
		fail += 1
	for row_name in ["Buttons", "ButtonsDefaults", "Buttons2"]:
		var row: Control = panel.find_child(row_name, true, false)
		if row == null:
			printerr("FAIL map_settings_bottom_buttons_visible: missing %s" % row_name)
			fail += 1
			continue
		var rect: Rect2 = row.get_global_rect()
		if not vp.encloses(rect):
			printerr(
				(
					"FAIL map_settings_bottom_buttons_visible: %s rect %s not inside viewport %s (clipped by %.1f)"
					% [row_name, rect, vp, rect.end.y - vp.end.y]
				)
			)
			fail += 1
	for button_name in ["RandomSeed", "RandomSpecs", "Reset", "Back", "Start"]:
		var b: Control = panel.find_child(button_name, true, false)
		if b == null:
			printerr("FAIL map_settings_bottom_buttons_visible: missing %s" % button_name)
			fail += 1
			continue
		var brect: Rect2 = b.get_global_rect()
		if not vp.encloses(brect):
			printerr(
				(
					"FAIL map_settings_bottom_buttons_visible: %s rect %s not inside viewport %s"
					% [button_name, brect, vp]
				)
			)
			fail += 1
	panel.queue_free()
	root.size = previous_size
	if fail == 0:
		print("PASS test_map_settings_bottom_buttons_visible viewport=%s" % vp.size)
	return fail
