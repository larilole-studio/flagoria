extends "res://tests/helpers/test_helpers.gd"
## Free-form wall damage during two-player play (#35).

const PROBE := "res://tests/wall_break_probe.gd"
const SEED := 11


func _test_wall_break_two_players() -> int:
	## A far swing does not drop hp. One hit shows hp 2 on both peers, then
	## the cell is gone. A late joiner matches. Seed 11. About 10–15 s alone.
	print("-- test_wall_break_two_players")
	var session := _open()
	if session.is_empty():
		return 1
	var fail := 0
	var read: Callable = session["read"]
	var launch: Callable = session["launch"]
	var wait_for: Callable = session["wait_for"]
	if not await wait_for.call(func() -> bool: return read.call(0).get("ready", false), 30000):
		printerr("FAIL wall_break_two_players: host did not start: %s" % read.call(0))
		fail = 1
	else:
		launch.call(false, "work")
		if not await wait_for.call(func() -> bool: return _both_hp2(read), 25000):
			printerr("FAIL wall_break_two_players: hp 2 not on both peers host %s client %s"
					% [read.call(0), read.call(1)])
			fail = 1
		elif not await wait_for.call(func() -> bool: return _broke(read), 25000):
			printerr("FAIL wall_break_two_players: break host %s client %s"
					% [read.call(0), read.call(1)])
			fail = 1
		else:
			launch.call(false, "watch")
			if not await wait_for.call(func() -> bool:
				return read.call(2).get("ready", false) and read.call(2).get("walls", {}) == read.call(0).get("walls", {}), 30000):
				printerr("FAIL wall_break_two_players: late joiner %s host %s"
						% [read.call(2), read.call(0)])
				fail = 1
		_note_errors(read, session)
		if _any_errors(read, session):
			fail = 1
	await _close(session)
	if fail == 0:
		print("PASS test_wall_break_two_players")
	return fail


func _broke(read: Callable) -> bool:
	var client: Dictionary = read.call(1)
	if not client.get("break_done", false):
		return false
	var target: String = client["target"]
	return not read.call(0).get("walls", {}).has(target) and not client.get("walls", {}).has(target)


func _both_hp2(read: Callable) -> bool:
	return read.call(0).get("saw_hp2", false) and read.call(1).get("saw_hp2", false)


func _note_errors(read: Callable, session: Dictionary) -> void:
	for i in session["outs"].size():
		var data: Dictionary = read.call(i)
		if not data.get("errors", []).is_empty() or str(data.get("place_error", "")) != "" \
				or str(data.get("phase_done", "")) != "":
			printerr("FAIL wall_break_two_players: peer %d errors %s place %s phase %s"
					% [i, data.get("errors", []), data.get("place_error", ""), data.get("phase_done", "")])


func _any_errors(read: Callable, session: Dictionary) -> bool:
	for i in session["outs"].size():
		var data: Dictionary = read.call(i)
		if not data.get("errors", []).is_empty() or str(data.get("place_error", "")) != "" \
				or str(data.get("phase_done", "")) != "":
			return true
	return false


func _open() -> Dictionary:
	var port := _free_udp_port()
	if port == 0:
		printerr("FAIL wall_break sync found no free UDP port")
		return {}
	var dir := OS.get_user_data_dir().path_join("wall_break_%d_%d" % [OS.get_process_id(), port])
	_remove_dir(dir)
	DirAccess.make_dir_recursive_absolute(dir)
	var params := _spawn_params(SEED, 0.0)
	var saved := MapSave.save_world(WorldSave.new(params), "test_wall_break_%d_%d" % [OS.get_process_id(), port])
	if saved["error"] != "":
		printerr("FAIL wall_break sync could not save the map: %s" % saved["error"])
		return {}
	var outs: Array[String] = []
	var pids: Array[int] = []
	var launch := func(as_host: bool, peer_mode: String) -> void:
		outs.append(dir.path_join("p%d.json" % outs.size()))
		var args: Array = ["--headless", "--path", ProjectSettings.globalize_path("res://"),
				"--script", PROBE, "--", "--port=%d" % port, "--out=" + outs[-1], "--phase=" + peer_mode]
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
	launch.call(true, "work")
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