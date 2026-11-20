extends "res://tests/helpers/probe_base.gd"
## The host seeks night. In mobs mode it also ticks the ambient band once.

const SEED := 11
var _ticked := false


func _run() -> void:
	var host := has_option("--host")
	var mobs := option("--mode") == "mobs"
	var main = await open_game(host)
	if main == null:
		quit(1)
		return
	if mobs:
		main.get_node("CanvasLayer2/MainMenu").hide()
	if host:
		if mobs:
			root.get_node("GameSettings").set_mob_rate(1.0, false)
		if host_game(main, _params(mobs)) != OK:
			printerr("day_night_probe: could not host")
			quit(1)
			return
		root.get_node("DayNight").seek_phase("night")
		host_listening()
	else:
		await join_game(main)
	var snapshot := _write.bind(main, mobs)
	var deadline := Time.get_ticks_msec() + 60000
	while game_active(main, deadline):
		if mobs and host and not _ticked and _player_alive(main):
			main.get_node("World/Mobs").run_ambient_tick()
			_ticked = true
		if snapshot_due(main):
			snapshot.call()
		await process_frame
	finish(main, snapshot)


func _params(mobs: bool) -> MapGenParams:
	var params := MapGenParams.make_defaults()
	var offset := 0 if mobs else 1
	if mobs:
		params.biome_frequency = 0.0
	params.altitude_seed = SEED
	params.moisture_seed = SEED + offset
	params.temperature_seed = SEED + 2 * offset
	params.items_seed = SEED + 3 * offset
	params.biome_seed = SEED + 4 * offset
	return params


func _player_alive(main) -> bool:
	for child in main.get_node("World").get_children():
		if child is CharacterBody2D and Mob.is_alive(child):
			return true
	return false


func _rows(main) -> Array:
	var rows: Array = []
	var mobs_node: Node = main.get_node_or_null("World/Mobs")
	if mobs_node == null:
		return rows
	for child in mobs_node.get_children():
		if child is Mob and not child.is_queued_for_deletion():
			rows.append({
				"name": str(child.name),
				"type": str(child.mob_type),
				"x": int(round(child.home.x)),
				"y": int(round(child.home.y)),
			})
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return str(a["name"]) < str(b["name"]))
	return rows


func _write(main, mobs: bool) -> void:
	var clock := root.get_node("DayNight")
	var data: Dictionary
	if mobs:
		data = {
			"ready": _player_alive(main),
			"phase": clock.phase(),
			"scale": clock.spawn_scale(),
			"ticked": _ticked,
			"rows": _rows(main),
		}
	else:
		data = clock.report()
	data["errors"] = _errors.snapshot()
	write_result(data)
