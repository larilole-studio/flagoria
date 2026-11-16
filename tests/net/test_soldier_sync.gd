extends "res://tests/helpers/test_helpers.gd"
## Barracks soldier training sync between peers and a late joiner (#553).

const PROBE := "res://tests/soldier_sync_probe.gd"
const SEED := 11


func _test_soldier_train_two_players() -> int:
	print("-- test_soldier_train_two_players")
	var session := _open()
	if session.is_empty():
		return 1
	var fail := 0
	var read: Callable = session["read"]
	var launch: Callable = session["launch"]
	var wait_for: Callable = session["wait_for"]
	if not await wait_for.call(func() -> bool: return read.call(0).get("ready", false), 30000):
		printerr("FAIL soldier_train_two_players: host did not start: %s" % read.call(0))
		fail = 1
	else:
		launch.call(false, "place")
		if not await wait_for.call(func() -> bool: return read.call(1).get("ready", false), 30000):
			printerr("FAIL soldier_train_two_players: client did not join: %s" % read.call(1))
			fail = 1
		elif not await wait_for.call(func() -> bool: return _trained(read), 25000):
			printerr("FAIL soldier_train_two_players: after train host %s client %s"
					% [read.call(0), read.call(1)])
			fail += 1
		elif not await wait_for.call(func() -> bool: return _order_is(read, "hold"), 25000):
			printerr("FAIL soldier_train_two_players: hold order %s" % read.call(1).get("soldiers"))
			fail += 1
		else:
			launch.call(false, "watch")
			if not await wait_for.call(func() -> bool:
				return read.call(2).get("ready", false) and read.call(2).get("soldiers") == read.call(0).get("soldiers") \
						and _order_is(read, "hold", 3), 30000):
				printerr("FAIL soldier_train_two_players: late joiner host %s joiner %s"
						% [read.call(0), read.call(2)])
				fail += 1
		for i in session["outs"].size():
			if not read.call(i).get("errors", []).is_empty() or str(read.call(i).get("place_error", "")) != "":
				printerr("FAIL soldier_train_two_players: peer %d errors %s place %s"
						% [i, read.call(i).get("errors", []), read.call(i).get("place_error", "")])
				fail += 1
	await _close(session)
	if fail == 0:
		print("PASS test_soldier_train_two_players")
	return fail


func _trained(read: Callable) -> bool:
	var host: Dictionary = read.call(0)
	var client: Dictionary = read.call(1)
	if host.get("soldiers") != client.get("soldiers"):
		return false
	var rows: Array = host.get("soldiers", [])
	if rows.is_empty():
		return false
	var builder := int(client.get("id", "0"))
	return str(rows[0][0]).begins_with("soldier_%d" % builder) and int(rows[0][1]) == builder



func _order_is(read: Callable, want: String, peer_count: int = 2) -> bool:
	for i in peer_count:
		var rows: Array = read.call(i).get("soldiers", [])
		if rows.is_empty() or str(rows[0][2]) != want:
			return false
	return true


func _open() -> Dictionary:
	var port := _free_udp_port()
	if port == 0:
		printerr("FAIL soldier sync found no free UDP port")
		return {}
	var dir := OS.get_user_data_dir().path_join("soldier_sync_%d_%d" % [OS.get_process_id(), port])
	_remove_dir(dir)
	DirAccess.make_dir_recursive_absolute(dir)
	var params := _spawn_params(SEED, 0.0)
	var saved := MapSave.save_world(WorldSave.new(params), "test_soldier_sync_%d_%d" % [OS.get_process_id(), port])
	if saved["error"] != "":
		printerr("FAIL soldier sync could not save the map: %s" % saved["error"])
		return {}
	var outs: Array[String] = []
	var pids: Array[int] = []
	var launch := func(as_host: bool, peer_mode: String) -> void:
		outs.append(dir.path_join("p%d.json" % outs.size()))
		var args: Array = ["--headless", "--path", ProjectSettings.globalize_path("res://"),
				"--script", PROBE, "--", "--port=%d" % port, "--out=" + outs[-1], "--mode=" + peer_mode]
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
	launch.call(true, "place")
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