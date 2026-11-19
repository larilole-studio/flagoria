extends "res://tests/helpers/test_helpers.gd"
## Per-device HUD layout: save, load, clamp, overlap rejection, Reset.


func _hud() -> Node:
	return root.get_node("HudLayout")


func _test_hud_layout_round_trip() -> int:
	print("-- test_hud_layout_round_trip")
	var fail := 0
	var path := "user://test_hud_layout.cfg"
	_hud().save_path = path
	_hud().reset_to_defaults()
	var scene = await _play_scene()
	var layer: CanvasLayer = scene.get_node("CanvasLayer1")
	await process_frame
	_hud().edit_begin(layer)
	_hud().save_to_disk()
	_hud().edit_end()
	_hud().forget_memory()
	_hud().load_from_disk()
	if not _hud().uses_custom():
		printerr("FAIL hud_layout_round_trip: load did not restore custom layout")
		fail += 1
	_hud().apply(layer)
	await process_frame
	for id in ["joystick", "attack", "run", "buildings", "map", "scores", "wheel"]:
		if _hud().get_entry(id).is_empty():
			printerr("FAIL hud_layout_round_trip: missing %s after load" % id)
			fail += 1
	_hud().reset_to_defaults()
	_hud().edit_end()
	tree.paused = false
	DirAccess.remove_absolute(path)
	_hud().save_path = "user://hud_layout.cfg"
	scene.queue_free()
	await process_frame
	if fail == 0:
		print("PASS test_hud_layout_round_trip")
	return fail


func _test_hud_layout_clamp_overlap() -> int:
	print("-- test_hud_layout_clamp_overlap")
	var fail := 0
	_hud().reset_to_defaults()
	var scene = await _play_scene()
	var layer: CanvasLayer = scene.get_node("CanvasLayer1")
	await process_frame
	_hud().edit_begin(layer)
	if not _hud().try_place("attack", -0.5, 0.05, 1.0, layer):
		printerr("FAIL hud_layout_clamp: clamped place failed")
		fail += 1
	var rect: Rect2 = _hud().control_hit_rect("attack", layer)
	if rect.position.x < _hud().SIDE - 0.5:
		printerr("FAIL hud_layout_clamp: attack still off-screen %s" % rect)
		fail += 1
	var map_entry: Dictionary = _hud().get_entry("map")
	if map_entry.is_empty():
		printerr("FAIL hud_layout_overlap: no map entry")
		fail += 1
	else:
		var placed: bool = _hud().try_place("attack", float(map_entry.get("x")), float(map_entry.get("y")), 1.0, layer)
		if placed:
			printerr("FAIL hud_layout_overlap: attack overlaps map")
			fail += 1
	_hud().reset_to_defaults()
	_hud().edit_end()
	tree.paused = false
	scene.queue_free()
	await process_frame
	if fail == 0:
		print("PASS test_hud_layout_clamp_overlap")
	return fail


func _test_hud_layout_edit_blocks_map() -> int:
	print("-- test_hud_layout_edit_blocks_map")
	var fail := 0
	_hud().reset_to_defaults()
	var scene = await _play_scene()
	var layer: CanvasLayer = scene.get_node("CanvasLayer1")
	await process_frame
	var panel: MinimapPanel = layer.get_node("MinimapPanel")
	var map_btn: Button = layer.get_node("MinimapButton")
	_hud().edit_begin(layer)
	await process_frame
	map_btn.pressed.emit()
	await process_frame
	await process_frame
	if panel.shown:
		printerr("FAIL hud_layout_edit_blocks_map: minimap panel opened during edit")
		fail += 1
	if panel.parchment != null and panel.parchment.is_open():
		printerr("FAIL hud_layout_edit_blocks_map: parchment opened during edit")
		fail += 1
	_hud().edit_end()
	tree.paused = false
	scene.queue_free()
	await process_frame
	if fail == 0:
		print("PASS test_hud_layout_edit_blocks_map")
	return fail


func _test_hud_edit_bar_viewport_sizes() -> int:
	print("-- test_hud_edit_bar_viewport_sizes")
	var fail := 0
	var sizes: Array[Vector2i] = [Vector2i(390, 844), Vector2i(720, 1280), Vector2i(1280, 720), Vector2i(1920, 1080)]
	_hud().reset_to_defaults()
	var scene = await _play_scene()
	var layer: CanvasLayer = scene.get_node("CanvasLayer1")
	var editor := scene.get_node("CanvasLayer1/InGameMenu/HudLayoutEdit")
	var win := scene.get_window()
	for vp in sizes:
		win.size = vp
		await process_frame
		await process_frame
		_hud().edit_begin(layer)
		editor.show()
		if editor.has_method("relayout_bar"):
			await editor.relayout_bar()
		await process_frame
		if not editor.has_method("bar_fits_viewport") or not editor.bar_fits_viewport():
			printerr("FAIL hud_edit_bar_viewport: bar outside view %s rect=%s" % [vp, editor.get_node("TopBar").get_global_rect()])
			fail += 1
		editor.close_editor()
	_hud().edit_end()
	tree.paused = false
	scene.queue_free()
	await process_frame
	if fail == 0:
		print("PASS test_hud_edit_bar_viewport_sizes")
	return fail


func _test_hud_edit_bar_stable_during_drag() -> int:
	print("-- test_hud_edit_bar_stable_during_drag")
	var fail := 0
	const TOP_INSET := 6.0
	_hud().reset_to_defaults()
	var scene = await _play_scene()
	var layer: CanvasLayer = scene.get_node("CanvasLayer1")
	var editor := scene.get_node("CanvasLayer1/InGameMenu/HudLayoutEdit")
	var top_bar: Control = editor.get_node("TopBar")
	var win := scene.get_window()
	win.size = Vector2i(390, 844)
	await process_frame
	await process_frame
	_hud().edit_begin(layer)
	editor.show()
	if editor.has_method("relayout_bar"):
		await editor.relayout_bar()
	var view := layer.get_viewport().get_visible_rect()
	for step in 16:
		var t := float(step + 1) / 16.0
		_hud().try_place(
				"attack", lerpf(0.18, 0.72, t), lerpf(0.28, 0.62, t), lerpf(1.0, 1.45, t), layer)
		if not editor.has_method("relayout_bar"):
			printerr("FAIL hud_edit_bar_stable: missing relayout_bar")
			fail += 1
			break
		editor.relayout_bar()
		for _i in 5:
			await process_frame
			if top_bar.get_global_rect().position.y <= TOP_INSET + 0.5:
				printerr(
						"FAIL hud_edit_bar_stable: bar at top inset step %d pos=%s"
						% [step, top_bar.global_position])
				fail += 1
		for _i in 8:
			await process_frame
		if not editor.has_method("bar_fits_viewport") or not editor.bar_fits_viewport():
			printerr(
					"FAIL hud_edit_bar_stable: bar outside view after step %d rect=%s"
					% [step, top_bar.get_global_rect()])
			fail += 1
	editor.close_editor()
	_hud().edit_end()
	tree.paused = false
	scene.queue_free()
	await process_frame
	if fail == 0:
		print("PASS test_hud_edit_bar_stable_during_drag")
	return fail


func _test_hud_layout_reset() -> int:
	print("-- test_hud_layout_reset")
	var fail := 0
	_hud().reset_to_defaults()
	var scene = await _play_scene()
	var layer: CanvasLayer = scene.get_node("CanvasLayer1")
	await process_frame
	var before: Rect2 = _hud().control_hit_rect("attack", layer)
	_hud().edit_begin(layer)
	_hud().try_place("attack", 0.7, 0.3, 1.25, layer)
	_hud().save_to_disk()
	var moved: Rect2 = _hud().control_hit_rect("attack", layer)
	if before.position.distance_to(moved.position) < 5.0:
		printerr("FAIL hud_layout_reset: attack did not move before reset")
		fail += 1
	_hud().reset_to_defaults()
	await process_frame
	await process_frame
	var row := layer.get_node("HudToolRow") as HudToolRow
	row._layout()
	await process_frame
	var after: Rect2 = _hud().control_hit_rect("attack", layer)
	if not _hud().uses_custom() and before.position.distance_to(after.position) > 8.0:
		printerr("FAIL hud_layout_reset: attack %s want near %s" % [after.position, before.position])
		fail += 1
	_hud().edit_end()
	tree.paused = false
	scene.queue_free()
	await process_frame
	if fail == 0:
		print("PASS test_hud_layout_reset")
	return fail


func _test_hud_layout_wheel_slot() -> int:
	## Move and resize the wheel, save, reload the same place and scale.
	## Reset returns the thumb default. The arc from the new spot stays on
	## screen. ModeButton and BowButton stay gone.
	## Time cost: about 0.6 s in tools/verify.sh.
	print("-- test_hud_layout_wheel_slot")
	var fail := 0
	var path := "user://test_hud_wheel.cfg"
	_hud().save_path = path
	_hud().reset_to_defaults()
	var scene = await _play_scene()
	var layer: CanvasLayer = scene.get_node("CanvasLayer1")
	await process_frame
	fail += _no_legacy_buttons(scene, "hud_layout_wheel_slot")
	var before: Rect2 = _hud().control_hit_rect("wheel", layer)
	if before.size == Vector2.ZERO:
		printerr("FAIL hud_layout_wheel_slot: wheel button has no rect")
		fail += 1
	else:
		_hud().edit_begin(layer)
		if not _hud().try_place("wheel", 0.06, 0.42, 1.5, layer):
			printerr("FAIL hud_layout_wheel_slot: could not move the wheel")
			fail += 1
		var moved: Rect2 = _hud().control_hit_rect("wheel", layer)
		var scale_now: float = _hud().scale_of("wheel", layer)
		if moved.position.distance_to(before.position) < 8.0:
			printerr("FAIL hud_layout_wheel_slot: wheel did not move %s" % moved)
			fail += 1
		if absf(scale_now - 1.5) > 0.05:
			printerr("FAIL hud_layout_wheel_slot: scale %s" % scale_now)
			fail += 1
		var wheel: ToolWheel = layer.get_node("ToolWheel")
		wheel._place_options()
		if not _arc_on_screen(wheel):
			printerr("FAIL hud_layout_wheel_slot: arc leaves the screen")
			fail += 1
		_hud().save_to_disk()
		var saved_pos := moved.position
		_hud().edit_end()
		_hud().forget_memory()
		_hud().load_from_disk()
		_hud().apply(layer)
		await process_frame
		var again: Rect2 = _hud().control_hit_rect("wheel", layer)
		var again_s: float = _hud().scale_of("wheel", layer)
		if again.position.distance_to(saved_pos) > 1.5 or absf(again_s - scale_now) > 0.05:
			printerr("FAIL hud_layout_wheel_slot: reload pos %s scale %s want %s %s"
					% [again.position, again_s, saved_pos, scale_now])
			fail += 1
		_hud().reset_to_defaults()
		(layer.get_node("HudToolRow") as HudToolRow)._layout()
		await process_frame
		var after: Rect2 = _hud().control_hit_rect("wheel", layer)
		if after.position.distance_to(before.position) > 8.0:
			printerr("FAIL hud_layout_wheel_slot: reset %s want %s" % [after.position, before.position])
			fail += 1
		if absf(_hud().scale_of("wheel", layer) - 1.0) > 0.05:
			printerr("FAIL hud_layout_wheel_slot: reset scale %s" % _hud().scale_of("wheel", layer))
			fail += 1
		if _hud().uses_custom():
			printerr("FAIL hud_layout_wheel_slot: reset left a saved layout")
			fail += 1
		fail += _no_legacy_buttons(scene, "hud_layout_wheel_slot reset")
	_hud().edit_end()
	tree.paused = false
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
	_hud().save_path = "user://hud_layout.cfg"
	scene.queue_free()
	await process_frame
	if fail == 0:
		print("PASS test_hud_layout_wheel_slot")
	return fail


func _test_hud_layout_legacy_mode() -> int:
	## A save with a mode slot and no wheel id loads. mode is dropped, the
	## other controls stay, and the wheel remains on the thumb default.
	## Time cost: about 0.5 s in tools/verify.sh.
	print("-- test_hud_layout_legacy_mode")
	var fail := 0
	var path := "user://test_hud_legacy_mode.cfg"
	_hud().reset_to_defaults()
	var scene = await _play_scene()
	var layer: CanvasLayer = scene.get_node("CanvasLayer1")
	await process_frame
	var cfg := ConfigFile.new()
	cfg.set_value("hud", "version", _hud().SAVE_VERSION)
	cfg.set_value("hud", "attack_x", 0.62)
	cfg.set_value("hud", "attack_y", 0.35)
	cfg.set_value("hud", "attack_s", 1.0)
	cfg.set_value("hud", "mode_x", 0.9)
	cfg.set_value("hud", "mode_y", 0.08)
	cfg.set_value("hud", "mode_s", 1.25)
	cfg.save(path)
	_hud().save_path = path
	_hud().load_from_disk()
	if not _hud().get_entry("wheel").is_empty():
		printerr("FAIL hud_layout_legacy_mode: mode was copied onto the wheel")
		fail += 1
	if _hud().set_entry("mode", {"x": 0.5, "y": 0.5, "s": 1.0}):
		printerr("FAIL hud_layout_legacy_mode: mode is still a layout id")
		fail += 1
	var attack: Dictionary = _hud().get_entry("attack")
	if absf(float(attack.get("x", -1.0)) - 0.62) > 0.001:
		printerr("FAIL hud_layout_legacy_mode: attack did not load %s" % attack)
		fail += 1
	fail += _no_legacy_buttons(scene, "hud_layout_legacy_mode")
	_hud().apply(layer)
	(layer.get_node("HudToolRow") as HudToolRow)._layout()
	await process_frame
	var run: Control = layer.get_node("RunButton")
	var button: Control = layer.get_node("ToolWheel/ToolButton")
	var gap := run.get_global_rect().position.x - button.get_global_rect().end.x
	if gap < 0.0 or gap >= button.size.x:
		printerr("FAIL hud_layout_legacy_mode: wheel left the thumb slot gap %s" % gap)
		fail += 1
	_hud().save_to_disk()
	var again := ConfigFile.new()
	if again.load(path) != OK or again.has_section_key("hud", "mode_x"):
		printerr("FAIL hud_layout_legacy_mode: mode_x still in the save")
		fail += 1
	_hud().reset_to_defaults()
	_hud().edit_end()
	tree.paused = false
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
	_hud().save_path = "user://hud_layout.cfg"
	scene.queue_free()
	await process_frame
	if fail == 0:
		print("PASS test_hud_layout_legacy_mode")
	return fail


func _no_legacy_buttons(scene: Node, label: String) -> int:
	if scene.get_node_or_null("CanvasLayer1/ModeButton") != null \
			or scene.get_node_or_null("CanvasLayer1/BowButton") != null:
		printerr("FAIL %s: ModeButton or BowButton is still on the HUD" % label)
		return 1
	return 0


func _arc_on_screen(wheel: ToolWheel) -> bool:
	var view := wheel.get_viewport().get_visible_rect()
	var button := (wheel.get_node("ToolButton") as Control).get_global_rect().get_center()
	var inward := false
	for node_name in ToolWheel.NAMES:
		var opt := wheel.get_node(node_name) as Control
		var rect := opt.get_global_rect()
		if rect.size == Vector2.ZERO or not view.encloses(rect):
			printerr("wheel arc: %s rect %s view %s" % [node_name, rect, view])
			return false
		if node_name == "Bow" and rect.get_center().distance_to(view.get_center()) + 4.0 < button.distance_to(view.get_center()):
			inward = true
	return inward


func _play_scene() -> Node:
	var scene = load("res://flagoria_main.tscn").instantiate()
	root.add_child(scene)
	var menu: Node = scene.get_node("CanvasLayer2/MainMenu")
	menu.hide()
	menu.set_process_unhandled_input(false)
	scene.get_node("CanvasLayer1").show()
	var world = scene.get_node("World/worldMap")
	scene.world_params = _spawn_params(49, 0.003)
	world.apply_map_params(scene.world_params)
	await process_frame
	scene.add_player(scene.multiplayer.get_unique_id())
	for _i in 6:
		await process_frame
	return scene
