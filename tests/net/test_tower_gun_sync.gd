extends "res://tests/helpers/test_helpers.gd"
## A client-built tower shoots the host inside 80 px and not outside (#37).
## Seed 11. State waits only. About 8–12 s per run; stress runs it at the job's tier.

const PROBE := "res://tests/tower_gun_probe.gd"
const SEED := 11


func _test_tower_gun_two_players() -> int:
	## The client places a tower with the existing request. The host, pinned
	## inside 80 px, loses health on both peers. Outside range, health stays.
	## The client's own health stays full. A late joiner sees the health.
	## The probe stops regen so the hit is still there when a slow joiner is ready.
	## Time cost: ~10 s per run.
	print("-- test_tower_gun_two_players")
	var session := _open()
	if session.is_empty():
		return 1
	var fail := 0
	var read: Callable = session["read"]
	var launch: Callable = session["launch"]
	var wait_for: Callable = session["wait_for"]
	if not await wait_for.call(func() -> bool: return read.call(0).get("ready", false), 30000):
		printerr("FAIL tower_gun_two_players: the host did not start: %s" % read.call(0))
		fail = 1
	else:
		launch.call(false, "place")
		if not await wait_for.call(func() -> bool: return _client_stood(read), 30000):
			printerr("FAIL tower_gun_two_players: the host did not see the client at the spot: host %s client %s"
					% [read.call(0), read.call(1)])
			fail = 1
		else:
			var go := FileAccess.open(session["outs"][1] + ".go", FileAccess.WRITE)
			go.store_string("go")
			go.close()
			if not await wait_for.call(func() -> bool: return _tower_up(read), 20000):
				printerr("FAIL tower_gun_two_players: the tower was not placed: host %s client %s"
						% [read.call(0), read.call(1)])
				fail = 1
			else:
				var phase := FileAccess.open(session["outs"][0] + ".phase", FileAccess.WRITE)
				phase.store_string("in")
				phase.close()
				if not await wait_for.call(func() -> bool: return _shot(read), 15000):
					printerr("FAIL tower_gun_two_players: no shared hit inside range: host %s client %s"
							% [read.call(0), read.call(1)])
					fail = 1
				else:
					var hurt := int(read.call(0).get("host_health", -1))
					var out := FileAccess.open(session["outs"][0] + ".phase", FileAccess.WRITE)
					out.store_string("out")
					out.close()
					if not await wait_for.call(func() -> bool: return _held(read, hurt), 15000):
						printerr("FAIL tower_gun_two_players: health did not stay outside range: host %s client %s"
								% [read.call(0), read.call(1)])
						fail = 1
					else:
						launch.call(false, "watch")
						if not await wait_for.call(func() -> bool: return _joiner_sees(read, hurt), 30000):
							printerr("FAIL tower_gun_two_players: the late joiner does not see the health: host %s joiner %s"
									% [read.call(0), read.call(2)])
							fail = 1
		for i in session["outs"].size():
			var row: Dictionary = read.call(i)
			if not row.get("errors", []).is_empty() or str(row.get("place_error", "")) != "":
				printerr("FAIL tower_gun_two_players: peer %d errors %s place %s"
						% [i, row.get("errors", []), row.get("place_error", "")])
				fail = 1
			if i == 1 and int(row.get("self_health", -1)) != 6:
				printerr("FAIL tower_gun_two_players: the builder's health is %s, want 6" % row.get("self_health", -1))
				fail = 1
	await _close(session)
	if fail == 0:
		print("PASS test_tower_gun_two_players")
	return fail


func _client_stood(read: Callable) -> bool:
	var host: Dictionary = read.call(0)
	var client: Dictionary = read.call(1)
	if not client.get("ready", false) or client.get("want", []).size() < 2:
		return false
	var cid := str(client.get("id", ""))
	var seen = host.get("players", {}).get(cid)
	if seen == null:
		return false
	return Vector2(seen[0], seen[1]).distance_to(Vector2(client["want"][0], client["want"][1])) <= 4.0


func _tower_up(read: Callable) -> bool:
	var host: Dictionary = read.call(0)
	var client: Dictionary = read.call(1)
	var cid := int(str(client.get("id", "0")))
	return cid > 1 and int(host.get("tower_owner", -1)) == cid and int(client.get("tower_owner", -1)) == cid \
			and int(client.get("self_health", -1)) == 6 and int(host.get("host_health", -1)) == 6


func _shot(read: Callable) -> bool:
	var host: Dictionary = read.call(0)
	var client: Dictionary = read.call(1)
	var hp := int(host.get("host_health", -1))
	return hp >= 0 and hp < 6 and int(client.get("host_health", -1)) == hp \
			and int(client.get("self_health", -1)) == 6


func _held(read: Callable, hurt: int) -> bool:
	var host: Dictionary = read.call(0)
	var client: Dictionary = read.call(1)
	var hp := int(host.get("host_health", -1))
	return bool(host.get("held", false)) and not bool(host.get("dropped_outside", false)) \
			and hp >= hurt and int(client.get("host_health", -1)) == hp \
			and int(client.get("self_health", -1)) == 6


func _joiner_sees(read: Callable, hurt: int) -> bool:
	if read.call(2).is_empty():
		return false
	var host: Dictionary = read.call(0)
	var joiner: Dictionary = read.call(2)
	var hp := int(host.get("host_health", -1))
	return joiner.get("ready", false) and hp < 6 and hp >= hurt and int(joiner.get("host_health", -1)) == hp


func _open() -> Dictionary:
	var port := _free_udp_port()
	if port == 0:
		printerr("FAIL tower gun found no free UDP port")
		return {}
	var dir := OS.get_user_data_dir().path_join("tower_gun_%d_%d" % [OS.get_process_id(), port])
	_remove_dir(dir)
	DirAccess.make_dir_recursive_absolute(dir)
	var params := _spawn_params(SEED, 0.0)
	var saved := MapSave.save_world(WorldSave.new(params), "test_tower_gun_%d_%d" % [OS.get_process_id(), port])
	if saved["error"] != "":
		printerr("FAIL tower gun could not save the map: %s" % saved["error"])
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
	launch.call(true, "host")
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
