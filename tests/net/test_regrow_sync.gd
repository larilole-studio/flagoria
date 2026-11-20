extends "res://tests/helpers/test_helpers.gd"
## Regrowth of cut trees and bushes during two-player play (#298).

const PROBE := "res://tests/cut_sync_probe.gd"
const HOST_REGROW := 600.0  ## seconds; holds the stumps until the test releases them
const CLIENT_REGROW := 1.0  ## a client's own, shorter delay, which it must not use
const SAME_TIME_MS := 500  ## how far apart two peers may show one regrowth


func _test_regrow_sync_two_players() -> int:
	## A host and a client (each its own process, tests/cut_sync_probe.gd)
	## on seed 7 each cut a plant near the spawn: the host a tree, the client
	## a bush. The client's own regrow delay is shorter than the host's, and
	## it also sends the host a forged apply_regrow_cells: the stumps stay on
	## both while a second client joins and receives the stumps with the host's
	## ages. The test then shortens the host's delay to regrow both, and every
	## peer shows the same plant back within SAME_TIME_MS of the host. A third
	## client joining after that sees no cuts and the same plants.
	print("-- test_regrow_sync_two_players")
	var scene = load("res://flagoria_main.tscn").instantiate()
	root.add_child(scene)
	scene.get_node("CanvasLayer2/MainMenu").hide()
	var world = scene.get_node("World/worldMap")
	world.set_process(false)
	var params := _spawn_params(7, 0.0)
	params.ensure_seeds()
	scene._apply_params_to_world(params)
	var spawn: Vector2i = world.resolve_player_spawn()
	var found := {"tree": [], "bush": []}
	for r in range(0, 40):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				var cell := spawn + Vector2i(dx, dy)
				var type := InteractableCatalog.type_at(world.predict_cell(cell)[1])
				if maxi(absi(dx), absi(dy)) == r and type != null and found.has(type.id) and found[type.id].is_empty():
					found[type.id].append(cell)
	scene.queue_free()
	await process_frame
	if found["tree"].is_empty() or found["bush"].is_empty():
		printerr("FAIL regrow_sync_two_players: seed 7 has no tree or bush near the spawn: %s" % found)
		return 1
	var port := _free_udp_port()
	if port == 0:
		printerr("FAIL regrow_sync_two_players found no free UDP port")
		return 1
	var dir := make_probe_dir("regrow_sync_%d_%d" % [OS.get_process_id(), port])
	var saved := MapSave.save_world(WorldSave.new(params), "test_regrow_sync_%d_%d" % [OS.get_process_id(), port])
	var cells: Array = [found["tree"][0], found["bush"][0]]  # cut by the host, by the client
	var keys: Array = cells.map(func(c: Vector2i) -> String: return WorldSave.cell_key(c))
	var outs: Array[String] = []
	var probes: Array[Dictionary] = []
	var launch := func(extra: Array) -> void:
		outs.append(dir.path_join("p%d.json" % outs.size()))
		var args: Array = ["--port=%d" % port, "--cells=" + ";".join(keys)]
		args.append_array(extra)
		probes.append(spawn_probe(PROBE, outs[-1], args))
	var read := read_probe_at.bind(probes)
	var wait_for := wait_until
	var ages := func(i: int) -> Dictionary:
		## Cell key -> age in seconds, for each cut peer i holds.
		var out := {}
		var cuts: Dictionary = read.call(i).get("cuts", {})
		for chunk in cuts:
			for key in cuts[chunk]:
				out[key] = float(cuts[chunk][key]["age"])
		return out
	var holds_both := func(i: int) -> bool:
		var a: Dictionary = ages.call(i)
		return a.size() == 2 and a.has(keys[0]) and a.has(keys[1])
	var regrown_like_host := func(i: int) -> bool:
		## Peer i holds no cut, and each cell shows what the host shows.
		var data: Dictionary = read.call(i)
		if not ages.call(i).is_empty() or not ages.call(0).is_empty():
			return false
		for key in keys:
			var here = data.get("cells", {}).get(key)
			if here == null or here != read.call(0).get("cells", {}).get(key) or here["plant"] == [-1, -1]:
				return false
		return true
	var client := ["--regrow=%s" % CLIENT_REGROW]

	var fail := 0
	launch.call(["--host", "--regrow=%s" % HOST_REGROW, "--save=" + ProjectSettings.globalize_path(saved["path"])])
	if saved["error"] != "" or not await wait_for.call(func() -> bool: return read.call(0).get("ready", false), 30000):
		printerr("FAIL regrow_sync_two_players: the host did not start: save %s, %s" % [saved["error"], read.call(0)])
		fail += 1
	else:
		launch.call(client)
		if not await wait_for.call(func() -> bool: return read.call(1).get("ready", false), 30000):
			printerr("FAIL regrow_sync_two_players: the client did not join: %s" % read.call(1))
			fail += 1
		else:
			for i in 2:  # both cut at once
				var f := FileAccess.open(outs[i] + ".cut", FileAccess.WRITE)
				f.store_string(keys[i])
				f.close()
			if not await wait_for.call(func() -> bool: return holds_both.call(0) and holds_both.call(1), 20000):
				printerr("FAIL regrow_sync_two_players: after the cuts, host %s, client %s" % [read.call(0), read.call(1)])
				fail += 1
			else:
				# Past the client's own delay, with a forged regrowth sent:
				# the stumps stay everywhere until the host's delay.
				FileAccess.open(outs[1] + ".forge", FileAccess.WRITE).close()
				await wait_for.call(func() -> bool: return ages.call(1).values().min() > CLIENT_REGROW + 1.0, 5000)
				if not holds_both.call(0) or not holds_both.call(1) or not read.call(1).get("regrown", {}).is_empty():
					printerr("FAIL regrow_sync_two_players: a stump regrew before the host's delay: host %s, client %s"
							% [read.call(0), read.call(1)])
					fail += 1
				launch.call(client)
				if not await wait_for.call(func() -> bool: return read.call(2).get("ready", false) and holds_both.call(2), 30000):
					printerr("FAIL regrow_sync_two_players: the first late joiner %s, host %s" % [read.call(2), read.call(0)])
					fail += 1
				else:
					var host_ages: Dictionary = ages.call(0)
					var joiner_ages: Dictionary = ages.call(2)
					for key in keys:
						if absf(host_ages[key] - joiner_ages[key]) > 0.5:
							printerr("FAIL regrow_sync_two_players: late joiner ages %s, host %s" % [joiner_ages, host_ages])
							fail += 1
							break
				FileAccess.open(outs[0] + ".regrow", FileAccess.WRITE).store_string(str(CLIENT_REGROW))
				if not await wait_for.call(func() -> bool: return regrown_like_host.call(1) and regrown_like_host.call(2), 10000):
					printerr("FAIL regrow_sync_two_players: after releasing regrowth, host %s, client %s, late joiner %s"
							% [read.call(0), read.call(1), read.call(2)])
					fail += 1
				else:
					await wait_for.call(func() -> bool: return range(3).all(func(i: int) -> bool:  # every peer stamped both
						return keys.all(func(k: String) -> bool: return int(read.call(i).get("regrown", {}).get(k, 0)) != 0)), 5000)
					var spread := {}
					for key in keys:
						var times: Array = range(3).map(func(i: int) -> int: return int(read.call(i).get("regrown", {}).get(key, 0)))
						spread[key] = times.max() - times.min()
						if times.min() == 0 or spread[key] > SAME_TIME_MS:
							printerr("FAIL regrow_sync_two_players: %s regrew at %s (host, client, late joiner)" % [key, times])
							fail += 1
					print("   regrowth spread across peers (ms): %s" % spread)
				launch.call(client)
				if not await wait_for.call(func() -> bool: return read.call(3).get("ready", false) and regrown_like_host.call(3), 30000):
					printerr("FAIL regrow_sync_two_players: the joiner after regrowth %s, host %s" % [read.call(3), read.call(0)])
					fail += 1
			if not str(read.call(0).get("errors", [])).contains("apply_regrow"):
				printerr("FAIL regrow_sync_two_players: the host did not refuse the forged apply_regrow_cells: %s" % read.call(0))
				fail += 1
			for i in outs.size():
				# The host refuses the client's forged apply_regrow_cells with
				# an engine error; any other error fails.
				for line in read.call(i).get("errors", []):
					if i != 0 or not "apply_regrow" in str(line):
						printerr("FAIL regrow_sync_two_players: peer %d logged errors: %s" % [i, read.call(i)["errors"]])
						fail += 1
						break

	await stop_probes(probes, 10000)
	_remove_dir(dir)
	DirAccess.remove_absolute(saved["path"])
	if fail == 0:
		print("PASS test_regrow_sync_two_players (host cut %s, client cut %s)" % cells)
	return fail
