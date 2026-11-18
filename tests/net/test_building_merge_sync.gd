extends "res://tests/helpers/test_helpers.gd"
## Merged buildings and removal on host, client, and a late joiner (#27). Seed 49.


const PROBE := "res://tests/building_merge_probe.gd"
const SEED := 49


func _test_building_merge_two_players() -> int:
	## Host places two flush buildings, removes the second. Peers agree on the
	## seam and on the re-sealed first building. About 10–15 s per stress run.
	print("-- test_building_merge_two_players")
	var session := _open()
	if session.is_empty():
		return 1
	var fail := 0
	var read: Callable = session["read"]
	var launch: Callable = session["launch"]
	var wait_for: Callable = session["wait_for"]
	if not await wait_for.call(func() -> bool: return _merged(read.call(0)), 45000):
		printerr("FAIL building_merge_two_players: host %s" % read.call(0))
		fail = 1
	else:
		launch.call(false)
		launch.call(false)
		if not await wait_for.call(func() -> bool:
			return _merged(read.call(1)) and _seam_matched(read.call(1), read.call(0)), 45000):
			printerr("FAIL building_merge_two_players: client %s host %s" % [read.call(1), read.call(0)])
			fail = 1
		elif not await wait_for.call(func() -> bool:
			return _merged(read.call(2)) and _seam_matched(read.call(2), read.call(0)), 45000):
			printerr("FAIL building_merge_two_players: joiner %s host %s" % [read.call(2), read.call(0)])
			fail = 1
		else:
			if not await wait_for.call(func() -> bool: return _resealed(read.call(0)), 45000):
				printerr("FAIL building_merge_two_players: host remove %s" % read.call(0))
				fail = 1
			elif not await wait_for.call(func() -> bool:
				return _resealed(read.call(1)) and _resealed(read.call(2)) \
						and read.call(1).get("cells", {}) == read.call(0).get("cells", {}) \
						and read.call(2).get("cells", {}) == read.call(0).get("cells", {}), 45000):
				printerr("FAIL building_merge_two_players: resealed client %s joiner %s" % [read.call(1), read.call(2)])
				fail = 1
		for i in session["outs"].size():
			var data: Dictionary = read.call(i)
			if not data.get("errors", []).is_empty():
				printerr("FAIL building_merge_two_players: peer %d errors %s" % [i, data.get("errors", [])])
				fail = 1
	await _close(session)
	if fail == 0:
		print("PASS test_building_merge_two_players")
	return fail


func _merged(data: Dictionary) -> bool:
	return data.get("merged", false) and data.get("seam", {}).size() > 0


func _resealed(data: Dictionary) -> bool:
	return data.get("resealed", false) and data.get("records", 0) == 1


func _seam_matched(data: Dictionary, host: Dictionary) -> bool:
	return data.get("seam", {}) == host.get("seam", {})


func _open() -> Dictionary:
	var port := _free_udp_port()
	if port == 0:
		printerr("FAIL building_merge_two_players: no free UDP port")
		return {}
	var dir := OS.get_user_data_dir().path_join("building_merge_%d_%d" % [OS.get_process_id(), port])
	_remove_dir(dir)
	DirAccess.make_dir_recursive_absolute(dir)
	var params := _spawn_params(SEED, 0.0)
	var saved := MapSave.save_world(WorldSave.new(params), "test_building_merge_%d_%d" % [OS.get_process_id(), port])
	if saved["error"] != "":
		printerr("FAIL building_merge_two_players: save %s" % saved["error"])
		return {}
	var outs: Array[String] = []
	var pids: Array[int] = []
	var launch := func(as_host: bool) -> void:
		outs.append(dir.path_join("p%d.json" % outs.size()))
		var args: Array = ["--headless", "--path", ProjectSettings.globalize_path("res://"),
				"--script", PROBE, "--", "--port=%d" % port, "--out=" + outs[-1]]
		if as_host:
			args.append("--host")
			args.append("--save=" + ProjectSettings.globalize_path(saved["path"]))
		pids.append(OS.create_process(OS.get_executable_path(), args))
	var read := func(i: int) -> Dictionary:
		if i >= outs.size() or not FileAccess.file_exists(outs[i]):
			return {}
		var data = JSON.parse_string(FileAccess.get_file_as_string(outs[i]))
		return data if data is Dictionary else {}
	var wait_for := func(cond: Callable, ms: int) -> bool:
		var until := Time.get_ticks_msec() + ms
		while Time.get_ticks_msec() < until and not cond.call():
			await process_frame
		return cond.call()
	launch.call(true)
	return {
		"dir": dir, "outs": outs, "pids": pids, "saved": saved["path"],
		"launch": launch, "read": read, "wait_for": wait_for,
	}


func _close(session: Dictionary) -> void:
	if session.is_empty():
		return
	for out in session["outs"]:
		FileAccess.open(out + ".stop", FileAccess.WRITE).close()
	var wait: Callable = session["wait_for"]
	await wait.call(func() -> bool:
		for pid in session["pids"]:
			if OS.is_process_running(pid):
				return false
		return true, 10000)
	for pid in session["pids"]:
		if OS.is_process_running(pid):
			OS.kill(pid)
	_remove_dir(session["dir"])
	DirAccess.remove_absolute(session["saved"])