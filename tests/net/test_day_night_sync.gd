extends "res://tests/helpers/test_helpers.gd"
## Host, a joined peer, and a late joiner share the night phase (#558).
## The run waits until that state is true. It does not sleep.

const PROBE := "res://tests/day_night_probe.gd"


func _test_day_night_sync() -> int:
	## About 8 s alone. Stress runs it at the job's tier.
	print("-- test_day_night_sync")
	var session := _open()
	if session.is_empty():
		return 1
	var fail := 0
	var read: Callable = session["read"]
	var launch: Callable = session["launch"]
	var wait_for: Callable = session["wait_for"]
	if not await wait_for.call(func() -> bool: return _night(read.call(0)), 20000):
		printerr("FAIL day_night_sync: host %s" % read.call(0))
		fail = 1
	else:
		launch.call()
		if not await wait_for.call(func() -> bool: return _match(read.call(1), read.call(0)), 20000):
			printerr("FAIL day_night_sync: client %s host %s" % [read.call(1), read.call(0)])
			fail = 1
		else:
			launch.call()
			if not await wait_for.call(func() -> bool:
					return _match(read.call(2), read.call(0)) and _match(read.call(1), read.call(0)), 20000):
				printerr("FAIL day_night_sync: joiner %s host %s" % [read.call(2), read.call(0)])
				fail = 1
		for i in session["outs"].size():
			var data: Dictionary = read.call(i)
			if not data.get("errors", []).is_empty():
				printerr("FAIL day_night_sync: peer %d errors %s" % [i, data["errors"]])
				fail = 1
	await _close(session)
	if fail == 0:
		print("PASS test_day_night_sync")
	return fail


func _night(data: Dictionary) -> bool:
	return bool(data.get("synced", false)) and str(data.get("phase", "")) == "night" \
			and bool(data.get("enabled", false))


func _match(data: Dictionary, host: Dictionary) -> bool:
	if not _night(data) or not _night(host):
		return false
	var gap := absf(float(data.get("elapsed", -1.0)) - float(host.get("elapsed", -2.0)))
	gap = minf(gap, DayNight.CYCLE_SECONDS - gap)
	if gap > 2.0:
		return false
	var mine: Array = data.get("tint", [])
	var theirs: Array = host.get("tint", [])
	if mine.size() != 3 or theirs.size() != 3:
		return false
	for i in 3:
		if absf(float(mine[i]) - float(theirs[i])) > 0.02:
			return false
	return true


func _open() -> Dictionary:
	var port := _free_udp_port()
	if port == 0:
		printerr("FAIL day_night_sync found no free UDP port")
		return {}
	var dir := OS.get_user_data_dir().path_join("day_night_%d_%d" % [OS.get_process_id(), port])
	_remove_dir(dir)
	DirAccess.make_dir_recursive_absolute(dir)
	var outs: Array[String] = []
	var pids: Array[int] = []
	var launch := func() -> void:
		outs.append(dir.path_join("p%d.json" % outs.size()))
		var args: Array = ["--headless", "--path", ProjectSettings.globalize_path("res://"),
				"--script", PROBE, "--", "--port=%d" % port, "--out=" + outs[-1]]
		if outs.size() == 1:
			args.append("--host")
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
	launch.call()
	return {"dir": dir, "outs": outs, "pids": pids, "launch": launch, "read": read, "wait_for": wait_for}


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
