extends "res://tests/helpers/test_helpers.gd"
## Host building on the client and a late joiner (#26). Seed 11. Fixed solve seed 42.


const PROBE := "res://tests/generated_building_probe.gd"
const SEED := 11


func _test_generated_building_sync() -> int:
	## The host places one building. The client and a peer that joins after
	## that place hold the same tiles, the door is open, and a wall blocks.
	## The client cannot place one of its own. About 10 s alone; the stress
	## job runs it at the job's tier.
	print("-- test_generated_building_sync")
	var session := _open()
	if session.is_empty():
		return 1
	var fail := 0
	var read: Callable = session["read"]
	var launch: Callable = session["launch"]
	var wait_for: Callable = session["wait_for"]
	if not await wait_for.call(func() -> bool: return _host_ready(read.call(0)), 20000):
		printerr("FAIL generated_building_sync: host %s" % read.call(0))
		fail = 1
	else:
		launch.call(false)
		if not await wait_for.call(func() -> bool: return _matched(read.call(1), read.call(0)), 20000):
			printerr("FAIL generated_building_sync: client %s host %s" % [read.call(1), read.call(0)])
			fail = 1
		else:
			launch.call(false)
			if not await wait_for.call(func() -> bool:
				return _matched(read.call(2), read.call(0)) and _matched(read.call(1), read.call(0)), 20000):
				printerr("FAIL generated_building_sync: joiner %s host %s" % [read.call(2), read.call(0)])
				fail = 1
		for i in session["outs"].size():
			var data: Dictionary = read.call(i)
			if not data.get("errors", []).is_empty():
				printerr("FAIL generated_building_sync: peer %d errors %s" % [i, data.get("errors", [])])
				fail = 1
			if i > 0 and data.get("refused", false) != true:
				printerr("FAIL generated_building_sync: peer %d placed a building" % i)
				fail = 1
	await _close(session)
	if fail == 0:
		print("PASS test_generated_building_sync")
	return fail


func _host_ready(data: Dictionary) -> bool:
	return data.get("ready", false) and data.get("door_clear", false) and data.get("wall_blocked", false) \
			and data.get("cells", {}).size() > 0


func _matched(data: Dictionary, host: Dictionary) -> bool:
	return data.get("ready", false) and data.get("refused", false) \
			and data.get("door_clear", false) and data.get("wall_blocked", false) \
			and data.get("cells", {}) == host.get("cells", {}) \
			and data.get("records", 0) == host.get("records", -1)


func _open() -> Dictionary:
	var port := _free_udp_port()
	if port == 0:
		printerr("FAIL generated building sync found no free UDP port")
		return {}
	var dir := OS.get_user_data_dir().path_join("generated_building_%d_%d" % [OS.get_process_id(), port])
	_remove_dir(dir)
	DirAccess.make_dir_recursive_absolute(dir)
	var params := _spawn_params(SEED, 0.0)
	var saved := MapSave.save_world(WorldSave.new(params), "test_generated_building_%d_%d" % [OS.get_process_id(), port])
	if saved["error"] != "":
		printerr("FAIL generated building sync could not save the map: %s" % saved["error"])
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
