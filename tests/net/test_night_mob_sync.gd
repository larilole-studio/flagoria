extends "res://tests/helpers/test_helpers.gd"
## Host and one joiner at night agree on the mob rows (#559).
## The run waits until that state is true. It does not sleep.

const PROBE := "res://tests/night_mob_probe.gd"
const SEED := 11


func _test_night_mob_sync() -> int:
	## About 10 s alone. Stress runs it at the job's tier.
	print("-- test_night_mob_sync")
	var session := _open()
	if session.is_empty():
		return 1
	var fail := 0
	var read: Callable = session["read"]
	var wait_for: Callable = session["wait_for"]
	if not await wait_for.call(func() -> bool:
			return _agreed(read.call(0), read.call(1)), 20000):
		printerr("FAIL night_mob_sync: host %s client %s" % [read.call(0), read.call(1)])
		fail = 1
	for i in session["outs"].size():
		var data: Dictionary = read.call(i)
		if not (data.get("errors", []) as Array).is_empty():
			printerr("FAIL night_mob_sync: peer %d errors %s" % [i, data.get("errors", [])])
			fail = 1
	var shown: Dictionary = read.call(0)
	await _close(session)
	if fail == 0:
		print("PASS test_night_mob_sync (%s rows)" % (shown.get("rows", []) as Array).size())
	return fail


func _agreed(host: Dictionary, client: Dictionary) -> bool:
	if str(host.get("phase", "")) != "night" or str(client.get("phase", "")) != "night":
		return false
	if not bool(host.get("ticked", false)):
		return false
	if not is_equal_approx(float(host.get("scale", 0.0)), 2.0):
		return false
	if not is_equal_approx(float(client.get("scale", -1.0)), float(host.get("scale", 0.0))):
		return false
	var rows: Array = host.get("rows", [])
	return not rows.is_empty() and rows == client.get("rows", [])


func _open() -> Dictionary:
	var port := _free_udp_port()
	if port == 0:
		printerr("FAIL night_mob_sync found no free UDP port")
		return {}
	var dir := OS.get_user_data_dir().path_join("night_mob_%d_%d" % [OS.get_process_id(), port])
	_remove_dir(dir)
	DirAccess.make_dir_recursive_absolute(dir)
	var outs: Array[String] = []
	var pids: Array[int] = []
	var launch := func(role: String) -> void:
		outs.append(dir.path_join("p%d.json" % outs.size()))
		var args: Array = ["--headless", "--path", ProjectSettings.globalize_path("res://"),
				"--script", PROBE, "--", "--port=%d" % port, "--out=" + outs[-1],
				"--role=" + role, "--seed=%d" % SEED]
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
	launch.call("host")
	launch.call("join")
	return {"dir": dir, "outs": outs, "pids": pids, "read": read, "wait_for": wait_for}


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
