extends "res://tests/helpers/test_helpers.gd"
## Raid damage on two peers, and raids left off (#529).

const PROBE := "res://tests/raid_probe.gd"
const SEED := 11


func _test_raid_two_players() -> int:
	## Host strikes once. Both peers and a late joiner see that wall at 2 hp.
	## Seed 11. State waits only.
	print("-- test_raid_two_players")
	return await _raid_case(true)


func _test_raid_off_two_players() -> int:
	## The same city with raids off keeps hp at 3 on both peers.
	## Seed 11. State waits only.
	print("-- test_raid_off_two_players")
	return await _raid_case(false)


func _raid_case(raids_on: bool) -> int:
	var session := _raid_open(raids_on)
	if session.is_empty():
		return 1
	var label := "raid_two_players" if raids_on else "raid_off_two_players"
	var fail := 0
	var read: Callable = session["read"]
	var launch: Callable = session["launch"]
	var wait_for: Callable = session["wait_for"]
	if not await wait_for.call(func() -> bool:
		return bool(read.call(0).get("ready", false)) and bool(read.call(1).get("ready", false)), 20000):
		printerr("FAIL %s: not ready host %s client %s" % [label, read.call(0), read.call(1)])
		fail = 1
	else:
		FileAccess.open(session["outs"][0] + ".go", FileAccess.WRITE).close()
		if not await wait_for.call(func() -> bool: return _settled(read, raids_on), 20000):
			printerr("FAIL %s: host %s client %s" % [label, read.call(0), read.call(1)])
			fail = 1
		elif raids_on:
			launch.call()
			if not await wait_for.call(func() -> bool: return _joiner_sees(read), 20000):
				printerr("FAIL %s: late joiner %s host %s" % [label, read.call(2), read.call(0)])
				fail = 1
	if _raid_errors(read, session, label):
		fail = 1
	await _raid_close(session)
	if fail == 0:
		print("PASS test_%s" % label)
	return fail


func _settled(read: Callable, raids_on: bool) -> bool:
	var host: Dictionary = read.call(0)
	var client: Dictionary = read.call(1)
	if int(host.get("phase", 0)) != 1 or str(host.get("note", "")) != "":
		return false
	var hp := 2 if raids_on else 3
	return int(host.get("hp", -1)) == hp and bool(host.get("assigned", false)) == raids_on \
			and _peer_hp(client, host["cell"]) == hp


func _joiner_sees(read: Callable) -> bool:
	var host: Dictionary = read.call(0)
	var joiner: Dictionary = read.call(2)
	return bool(joiner.get("ready", false)) and _peer_hp(joiner, host["cell"]) == 2


func _peer_hp(data: Dictionary, cell: String) -> int:
	return int(data.get("walls", {}).get(cell, -1))


func _raid_errors(read: Callable, session: Dictionary, label: String) -> bool:
	var bad := false
	for i in session["outs"].size():
		var data: Dictionary = read.call(i)
		if not (data.get("errors", []) as Array).is_empty() or str(data.get("note", "")) != "":
			printerr("FAIL %s: peer %d errors %s note %s" % [label, i, data.get("errors", []), data.get("note", "")])
			bad = true
	return bad


func _raid_open(raids_on: bool) -> Dictionary:
	var port := _free_udp_port()
	if port == 0:
		printerr("FAIL raid sync found no free UDP port")
		return {}
	var dir := OS.get_user_data_dir().path_join("raid_%d_%d" % [OS.get_process_id(), port])
	_remove_dir(dir)
	DirAccess.make_dir_recursive_absolute(dir)
	var outs: Array[String] = []
	var pids: Array[int] = []
	var flag := "on" if raids_on else "off"
	var launch := func() -> void:
		outs.append(dir.path_join("p%d.json" % outs.size()))
		var args: Array = ["--headless", "--path", ProjectSettings.globalize_path("res://"),
				"--script", PROBE, "--", "--port=%d" % port, "--out=" + outs[-1],
				"--role=join", "--seed=%d" % SEED, "--raids=" + flag]
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
	outs.append(dir.path_join("p0.json"))
	var host_args: Array = ["--headless", "--path", ProjectSettings.globalize_path("res://"),
			"--script", PROBE, "--", "--port=%d" % port, "--out=" + outs[0],
			"--role=host", "--seed=%d" % SEED, "--raids=" + flag]
	pids.append(OS.create_process(OS.get_executable_path(), host_args))
	launch.call()
	return {"dir": dir, "outs": outs, "pids": pids, "launch": launch, "read": read, "wait_for": wait_for}


func _raid_close(session: Dictionary) -> void:
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
