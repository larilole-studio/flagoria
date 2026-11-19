extends "res://tests/helpers/test_helpers.gd"
## Host sprouts converge on the connected client and a late joiner (#361).

const Sprouts := preload("res://tests/mechanics/trees/test_tree_sprouts.gd")
const PROBE := "res://tests/cut_sync_probe.gd"


func _sprout_keys(data: Dictionary) -> Dictionary:
	## Cell key -> {entry, cell state} for each sprout in a probe's report.
	var out := {}
	var cuts: Dictionary = data.get("cuts", {})
	for chunk in cuts:
		for key in cuts[chunk]:
			if cuts[chunk][key].has("sprout"):
				out[key] = [cuts[chunk][key]["sprout"], data.get("cells", {}).get(key)]
	return out


func _test_sprout_sync_two_players() -> int:
	## A host and peers in their own processes (tests/cut_sync_probe.gd).
	## The host loads a save whose trees near the spawn are cut and builds a
	## guard post on them, so its area is short of trees. With sprouting off
	## (regrow delay 0) a client joins; then the host turns it on, sprouts,
	## and the client shows the same sprouts. A peer joining afterwards gets
	## them too, and no peer logs an error.
	print("-- test_sprout_sync_two_players")
	var scene = load("res://flagoria_main.tscn").instantiate()
	root.add_child(scene)
	scene.get_node("CanvasLayer2/MainMenu").hide()
	var world = scene.get_node("World/worldMap")
	world.set_process(false)
	var found := {}
	var params: MapGenParams
	for sv in [11, 42, 99, 7, 3]:
		params = Sprouts._static_params(sv)
		params.ensure_seeds()
		scene._apply_params_to_world(params)
		var spawn: Vector2i = world.resolve_player_spawn()
		for r in range(4, 30, 2):
			for dy in range(-r, r + 1, 2):
				for dx in range(-r, r + 1, 2):
					if found.is_empty() and maxi(absi(dx), absi(dy)) == r:
						found = Sprouts._try_anchor(world, Sprouts.guard_post(), spawn + Vector2i(dx, dy), false, spawn)
		if not found.is_empty():
			break
	scene.queue_free()
	await process_frame
	var port := _free_udp_port()
	if found.is_empty() or port == 0:
		printerr("FAIL sprout_sync_two_players: no guard post spot near a spawn (%s) or no free UDP port" % found)
		return 1
	var dir := OS.get_user_data_dir().path_join("sprout_sync_%d_%d" % [OS.get_process_id(), port])
	_remove_dir(dir)
	DirAccess.make_dir_recursive_absolute(dir)
	var world_save := WorldSave.new(params)
	for cell: Vector2i in found["lost"]:
		world_save.object_changes.get_or_add(WorldSave.chunk_key(cell), {})[WorldSave.cell_key(cell)] = {"cut": "tree", "age": 0.0}
	var saved := MapSave.save_world(world_save, "test_sprout_sync_%d_%d" % [OS.get_process_id(), port])
	var outs: Array[String] = []
	var pids: Array[int] = []
	var launch := func(extra: Array) -> void:
		outs.append(dir.path_join("p%d.json" % outs.size()))
		var args := ["--headless", "--path", ProjectSettings.globalize_path("res://"), "--script", PROBE, "--", "--port=%d" % port, "--out=" + outs[-1]]
		args.append_array(extra)
		pids.append(OS.create_process(OS.get_executable_path(), args))
	var read := func(i: int) -> Dictionary:
		var text := FileAccess.get_file_as_string(outs[i]) if FileAccess.file_exists(outs[i]) else ""
		var data = JSON.parse_string(text) if text != "" else null
		return data if data is Dictionary else {}
	var wait_for := func(cond: Callable, ms: int) -> bool:
		var until := Time.get_ticks_msec() + ms
		while Time.get_ticks_msec() < until and not cond.call():
			await process_frame
		return cond.call()
	var like_host := func(i: int) -> bool:
		var host: Dictionary = _sprout_keys(read.call(0))
		return read.call(i).get("ready", false) and not host.is_empty() and _sprout_keys(read.call(i)) == host

	var fail := 0
	launch.call(["--host", "--regrow=0", "--save=" + ProjectSettings.globalize_path(saved["path"]),
			"--place=guard_post@%s" % WorldSave.cell_key(found["anchor"])])
	launch.call(["--regrow=0"])
	if saved["error"] != "" or not await wait_for.call(func() -> bool:
			return read.call(0).get("ready", false) and read.call(1).get("ready", false), 40000):
		printerr("FAIL sprout_sync_two_players: host %s, client %s (save %s)" % [read.call(0), read.call(1), saved["error"]])
		fail += 1
	elif not _sprout_keys(read.call(0)).is_empty() or not _sprout_keys(read.call(1)).is_empty():
		printerr("FAIL sprout_sync_two_players: a peer sprouted with sprouting off")
		fail += 1
	else:
		FileAccess.open(outs[0] + ".regrow", FileAccess.WRITE).store_string("5")
		if not await wait_for.call(func() -> bool: return like_host.call(1), 20000):
			printerr("FAIL sprout_sync_two_players: host sprouts %s, client %s"
					% [_sprout_keys(read.call(0)), _sprout_keys(read.call(1))])
			fail += 1
		else:
			launch.call(["--regrow=0"])
			if not await wait_for.call(func() -> bool: return like_host.call(2), 30000):
				printerr("FAIL sprout_sync_two_players: host sprouts %s, late joiner %s"
						% [_sprout_keys(read.call(0)), _sprout_keys(read.call(2))])
				fail += 1
	for i in outs.size():
		if not read.call(i).get("errors", []).is_empty():
			printerr("FAIL sprout_sync_two_players: peer %d logged errors: %s" % [i, read.call(i)["errors"]])
			fail += 1
	var sprouted: int = _sprout_keys(read.call(0)).size()
	for out in outs:
		FileAccess.open(out + ".stop", FileAccess.WRITE).close()
	await wait_for.call(func() -> bool:
		for pid in pids:
			if OS.is_process_running(pid):
				return false
		return true, 10000)
	for pid in pids:
		if OS.is_process_running(pid):
			OS.kill(pid)
	_remove_dir(dir)
	DirAccess.remove_absolute(saved["path"])
	if fail == 0:
		print("PASS test_sprout_sync_two_players (%d sprouts on host, client and late joiner)" % sprouted)
	return fail
