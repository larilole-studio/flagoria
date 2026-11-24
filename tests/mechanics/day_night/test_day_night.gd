extends "res://tests/helpers/test_helpers.gd"
## Day/night clock (#558): phase and tint, save/reload, and the cycle switch.

const SPEC_HEX := {
	"day": "#ffffff",
	"dusk": "#eba684",
	"night": "#808cc8",
	"dawn": "#e8b4c8",
}
const SPEC_SECONDS: Array[float] = [360.0, 15.0, 30.0, 15.0, 120.0, 15.0, 30.0, 15.0]


func _test_day_night_phases() -> int:
	## Fixed times: holds, the 15 second eases, and wrap at the end of the cycle.
	## Time cost: under 0.1 s in tools/verify.sh.
	print("-- test_day_night_phases")
	var fail := 0
	var spec = JSON.parse_string(FileAccess.get_file_as_string("res://docs/day_night.json"))
	if not spec is Dictionary or not spec.has("phases") or not spec.has("timing"):
		printerr("FAIL day_night_phases: docs/day_night.json did not parse")
		return 1
	if float(spec.get("cycle_seconds", 0)) != DayNight.CYCLE_SECONDS:
		printerr("FAIL day_night_phases cycle_seconds %s" % spec.get("cycle_seconds"))
		fail += 1
	var timing: Array = spec["timing"]
	if (
		timing.size() != SPEC_SECONDS.size()
		or DayNight.SEGMENT_SECONDS.size() != SPEC_SECONDS.size()
	):
		printerr("FAIL day_night_phases timing length %s" % timing.size())
		fail += 1
	else:
		for i in SPEC_SECONDS.size():
			if (
				not is_equal_approx(float(timing[i]["seconds"]), SPEC_SECONDS[i])
				or not is_equal_approx(DayNight.SEGMENT_SECONDS[i], SPEC_SECONDS[i])
			):
				printerr("FAIL day_night_phases segment %s seconds %s" % [i, timing[i]])
				fail += 1
	for phase in SPEC_HEX.keys():
		var hex: String = str(spec["phases"][phase]["hex"])
		var got := DayNight.color_of(phase).to_html(false)
		if hex != SPEC_HEX[phase] or got != hex.trim_prefix("#"):
			printerr("FAIL day_night_phases %s hex spec %s clock %s" % [phase, hex, got])
			fail += 1
	var night := DayNight.color_of("night")
	if night.r < 0.5 or night.g < 0.5 or night.b < 0.5:
		printerr("FAIL day_night_phases night channel below 0.5: %s" % night)
		fail += 1
	if not _holds():
		fail += 1
	if not _eases():
		fail += 1
	if not _wraps():
		fail += 1
	DayNight.stop()
	if fail == 0:
		print("PASS test_day_night_phases")
	return fail


func _holds() -> bool:
	var ok := true
	ok = _at(0.0, "day", "day") and ok
	ok = _at(180.0, "day", "day") and ok
	ok = _at(390.0, "dusk", "dusk") and ok
	ok = _at(480.0, "night", "night") and ok
	ok = _at(570.0, "dawn", "dawn") and ok
	# Window edges: the new phase starts while an ease may still show the old key.
	ok = _at(360.0, "dusk", "day") and ok
	ok = _at(420.0, "night", "night") and ok
	ok = _at(540.0, "dawn", "night") and ok
	return ok


func _eases() -> bool:
	## Halfway through the 15 second day-to-dusk ease. smoothstep(0.5) is 0.5.
	var want := DayNight.color_of("day").lerp(DayNight.color_of("dusk"), DayNight.cycle_ease(0.5))
	if not _color(DayNight.tint_at(367.5), want, "ease 367.5"):
		return false
	if DayNight.phase_at(367.5) != "dusk":
		printerr("FAIL day_night_phases ease phase %s" % DayNight.phase_at(367.5))
		return false
	return true


func _wraps() -> bool:
	if DayNight.phase_at(600.0) != "day" or DayNight.phase_at(0.0) != "day":
		printerr("FAIL day_night_phases wrap phase")
		return false
	if not _color(DayNight.tint_at(600.0), DayNight.color_of("day"), "tint 600"):
		return false
	if DayNight.phase_at(599.0) != "dawn":
		printerr("FAIL day_night_phases 599 phase %s" % DayNight.phase_at(599.0))
		return false
	var params := MapGenParams.make_defaults()
	DayNight.begin(params, 599.0)
	DayNight.tick(2.0)
	if not is_equal_approx(DayNight.elapsed, 1.0) or DayNight.phase() != "day":
		printerr(
			(
				"FAIL day_night_phases tick wrap elapsed=%s phase=%s"
				% [DayNight.elapsed, DayNight.phase()]
			)
		)
		return false
	return true


func _at(seconds: float, phase: String, tint_phase: String) -> bool:
	if DayNight.phase_at(seconds) != phase:
		printerr(
			(
				"FAIL day_night_phases t=%s phase %s want %s"
				% [seconds, DayNight.phase_at(seconds), phase]
			)
		)
		return false
	return _color(DayNight.tint_at(seconds), DayNight.color_of(tint_phase), "t=%s" % seconds)


func _color(got: Color, want: Color, label: String) -> bool:
	if (
		is_equal_approx(got.r, want.r)
		and is_equal_approx(got.g, want.g)
		and is_equal_approx(got.b, want.b)
	):
		return true
	printerr("FAIL day_night_phases %s got %s want %s" % [label, got, want])
	return false


func _test_day_night_save() -> int:
	## The in-game menu keeps the clock time. An old save with no clock loads
	## at the start of day with the cycle on. Time cost: about 1 s.
	print("-- test_day_night_save")
	var fail := 0
	var map_gen = root.get_node("MapGen")
	var before: MapGenParams = map_gen.params
	var scene := _quiet_scene()
	var params := _spawn_params(11, 0.0)
	params.ensure_seeds()
	scene.world_params = params
	DayNight.begin(params, 0.0)
	if not DayNight.seek_phase("night"):
		printerr("FAIL day_night_save: seek night failed")
		fail += 1
	var saved: Dictionary = scene.get_node("CanvasLayer1/InGameMenu").save_world()
	var doc := (
		MapSave.read_document(saved["path"])
		if saved["error"] == ""
		else {"error": saved["error"], "data": null}
	)
	var clock = doc["data"]["clock"] if doc.get("data") is Dictionary else null
	if (
		saved["error"] != ""
		or not clock is Dictionary
		or not is_equal_approx(float(clock.get("elapsed", -1)), 480.0)
	):
		printerr("FAIL day_night_save: save %s clock %s" % [saved["error"], clock])
		fail += 1
	var path: String = saved["path"]
	scene.queue_free()
	await process_frame
	if path != "" and map_gen.load_map_inputs(path) != "":
		printerr("FAIL day_night_save: load failed")
		fail += 1
	else:
		var again := _quiet_scene()
		again.world_params = map_gen.params.duplicate_params()
		again._restore_loaded_world()
		if (
			not is_equal_approx(DayNight.elapsed, 480.0)
			or DayNight.phase() != "night"
			or not again.world_params.day_night_cycle
		):
			printerr(
				(
					"FAIL day_night_save: reloaded elapsed=%s phase=%s cycle=%s"
					% [DayNight.elapsed, DayNight.phase(), again.world_params.day_night_cycle]
				)
			)
			fail += 1
		again.queue_free()
		await process_frame
	if path != "":
		DirAccess.remove_absolute(path)
	if not _legacy_clock():
		fail += 1
	map_gen.params = before
	map_gen.clear_loaded_world()
	DayNight.stop()
	if fail == 0:
		print("PASS test_day_night_save")
	return fail


func _legacy_clock() -> bool:
	var loaded := MapSave.load_world("res://tests/fixtures/world_save_v1.json")
	if loaded["error"] != "" or loaded["world"] == null:
		printerr("FAIL day_night_save: v1 %s" % loaded["error"])
		return false
	var world: WorldSave = loaded["world"]
	if world.clock_elapsed != 0.0 or not world.params.day_night_cycle:
		printerr(
			(
				"FAIL day_night_save: old save elapsed=%s cycle=%s"
				% [world.clock_elapsed, world.params.day_night_cycle]
			)
		)
		return false
	var bad := MapSave.path_for("test_day_night_bad_clock")
	DirAccess.make_dir_recursive_absolute(MapSave.SAVE_DIR)
	var file := FileAccess.open(bad, FileAccess.WRITE)
	if file == null:
		printerr("FAIL day_night_save: could not write a bad clock file")
		return false
	(
		file
		. store_string(
			(
				'{"format":"flagoria-world","format_version":3,"game_version":"0","created":10,"updated":20,'
				+ '"params":{"altitude_seed":11},"world":{},"player":{},"clock":[]}'
			)
		)
	)
	file.close()
	var refused := MapSave.load_world(bad)
	DirAccess.remove_absolute(bad)
	if refused["world"] != null or not ("clock" in str(refused["error"])):
		printerr("FAIL day_night_save: bad clock error=%s" % refused["error"])
		return false
	return true


func _test_day_night_cycle_off() -> int:
	## The Map Settings switch is on by default. Off keeps the tint at day.
	## The modulate is not on a HUD CanvasLayer. Time cost: about 0.5 s.
	print("-- test_day_night_cycle_off")
	var fail := 0
	var defaults := MapGenParams.make_defaults()
	if not defaults.day_night_cycle:
		printerr("FAIL day_night_cycle_off: default is off")
		fail += 1
	var panel := load("res://Scripts/ui/map_admin_panel.tscn").instantiate() as Node
	root.add_child(panel)
	panel.find_child("Advanced").button_pressed = true
	var row := panel.find_child("day_night_cycle", true, false)
	var label: Label = null
	if row != null and row.get_child_count() > 0:
		label = row.get_child(0) as Label
	if row == null or label == null or label.text != "Day and night":
		printerr("FAIL day_night_cycle_off: no Day and night row")
		panel.queue_free()
		DayNight.stop()
		return fail + 1
	var check := row.get_node("Check") as CheckButton
	if not check.button_pressed:
		printerr("FAIL day_night_cycle_off: switch starts off")
		fail += 1
	check.button_pressed = false
	panel.apply_to_params(defaults)
	if defaults.day_night_cycle:
		printerr("FAIL day_night_cycle_off: apply left the cycle on")
		fail += 1
	check.button_pressed = true
	panel.apply_to_params(defaults)
	if not defaults.day_night_cycle:
		printerr("FAIL day_night_cycle_off: apply did not turn the cycle back on")
		fail += 1
	panel.queue_free()

	var scene := _quiet_scene()
	defaults.day_night_cycle = false
	DayNight.begin(defaults, 480.0)
	DayNight.tick(30.0)
	await process_frame
	var mod := DayNight.get_node_or_null("WorldTint") as CanvasModulate
	if (
		mod == null
		or _under_canvas_layer(mod)
		or _layer_has_modulate(scene.get_node("CanvasLayer1"))
	):
		printerr("FAIL day_night_cycle_off: tint node is missing or on the HUD")
		fail += 1
	elif (
		DayNight.phase() != "day"
		or not _white(mod.color)
		or not is_equal_approx(DayNight.elapsed, 480.0)
	):
		printerr(
			(
				"FAIL day_night_cycle_off: off phase=%s elapsed=%s tint=%s"
				% [DayNight.phase(), DayNight.elapsed, mod.color]
			)
		)
		fail += 1
	defaults.day_night_cycle = true
	DayNight.begin(defaults, 480.0)
	await process_frame
	if (
		DayNight.phase() != "night"
		or not _color(mod.color, DayNight.color_of("night"), "night tint")
	):
		printerr("FAIL day_night_cycle_off: on phase=%s tint=%s" % [DayNight.phase(), mod.color])
		fail += 1
	scene.queue_free()
	await process_frame
	DayNight.stop()
	if fail == 0:
		print("PASS test_day_night_cycle_off")
	return fail


func _quiet_scene() -> Node:
	var scene = load("res://flagoria_main.tscn").instantiate()
	root.add_child(scene)
	scene.get_node("CanvasLayer2/MainMenu").hide()
	scene.get_node("World/worldMap").set_process(false)
	scene.get_node("Discovery").set_physics_process(false)
	scene.get_node("FlagsHeldPoints").set_physics_process(false)
	scene.get_node("World/LandScore").set_physics_process(false)
	scene.get_node("CanvasLayer1/MapChart").set_physics_process(false)
	return scene


func _under_canvas_layer(node: Node) -> bool:
	var at := node.get_parent()
	while at != null:
		if at is CanvasLayer:
			return true
		at = at.get_parent()
	return false


func _layer_has_modulate(node: Node) -> bool:
	for child in node.get_children():
		if child is CanvasModulate or _layer_has_modulate(child):
			return true
	return false


func _white(color: Color) -> bool:
	return _color(color, DayNight.color_of("day"), "day tint")
