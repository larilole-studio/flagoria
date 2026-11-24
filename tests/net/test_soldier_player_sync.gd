extends "res://tests/helpers/test_helpers.gd"
## Soldier vs player health sync between peers and a late joiner (#555).

const PROBE := "res://tests/soldier_player_probe.gd"
const SEED := 11


func _test_soldier_player_two_players() -> int:
	print("-- test_soldier_player_two_players")
	var session := _open()
	if session.is_empty():
		return 1
	var fail := 0
	var read: Callable = session["read"]
	var launch: Callable = session["launch"]
	var wait_for: Callable = session["wait_for"]
	if not await wait_for.call(func() -> bool: return read.call(0).get("ready", false), 30000):
		printerr("FAIL soldier_player_two_players: host did not start: %s" % read.call(0))
		fail = 1
	else:
		launch.call(false, "watch")
		if not await wait_for.call(func() -> bool: return read.call(1).get("ready", false), 30000):
			printerr("FAIL soldier_player_two_players: client did not join: %s" % read.call(1))
			fail = 1
		elif not await wait_for.call(func() -> bool: return _host_trained(read), 25000):
			printerr(
				(
					"FAIL soldier_player_two_players: train host %s client %s"
					% [read.call(0), read.call(1)]
				)
			)
			fail += 1
		elif not await wait_for.call(func() -> bool: return _peer_hurt(read, 2), 45000):
			printerr(
				(
					"FAIL soldier_player_two_players: peer hp host %s client %s"
					% [read.call(0), read.call(1)]
				)
			)
			fail += 1
		else:
			launch.call(false, "watch")
			if not await wait_for.call(
				func() -> bool: return read.call(2).get("ready", false) and _peer_hurt(read, 3),
				30000
			):
				printerr(
					(
						"FAIL soldier_player_two_players: late joiner host %s joiner %s"
						% [read.call(0), read.call(2)]
					)
				)
				fail += 1
		for i in session["outs"].size():
			if (
				not read.call(i).get("errors", []).is_empty()
				or str(read.call(i).get("place_error", "")) != ""
			):
				printerr(
					(
						"FAIL soldier_player_two_players: peer %d errors %s place %s"
						% [i, read.call(i).get("errors", []), read.call(i).get("place_error", "")]
					)
				)
				fail += 1
	await _close(session)
	if fail == 0:
		print("PASS test_soldier_player_two_players")
	return fail


func _host_trained(read: Callable) -> bool:
	var host: Dictionary = read.call(0)
	var client: Dictionary = read.call(1)
	if host.get("soldiers") != client.get("soldiers"):
		return false
	var rows: Array = host.get("soldiers", [])
	if rows.is_empty():
		return false
	return int(rows[0][1]) == 1


func _peer_hurt(read: Callable, peer_count: int) -> bool:
	for i in peer_count:
		var snap: Dictionary = read.call(i)
		var hp: int = int(snap.get("fight_peer_hp", -1))
		var start: int = int(snap.get("fight_peer_start_hp", 6))
		if hp < 0 or hp >= start:
			return false
	return true


func _open() -> Dictionary:
	var port := _free_udp_port()
	if port == 0:
		printerr("FAIL soldier player sync found no free UDP port")
		return {}
	var dir := make_probe_dir("soldier_player_sync_%d_%d" % [OS.get_process_id(), port])
	var params := _spawn_params(SEED, 0.0)
	var saved := MapSave.save_world(
		WorldSave.new(params), "test_soldier_player_%d_%d" % [OS.get_process_id(), port]
	)
	if saved["error"] != "":
		printerr("FAIL soldier player sync could not save the map: %s" % saved["error"])
		return {}
	var outs: Array[String] = []
	var probes: Array[Dictionary] = []
	var launch := func(as_host: bool, peer_mode: String) -> void:
		outs.append(dir.path_join("p%d.json" % outs.size()))
		var args: Array = ["--port=%d" % port, "--mode=" + peer_mode]
		if as_host:
			args.append("--host")
			args.append("--save=" + ProjectSettings.globalize_path(saved["path"]))
		probes.append(spawn_probe(PROBE, outs[-1], args))
	var read := read_probe_at.bind(probes)
	var wait_for := wait_until
	launch.call(true, "place")
	return {
		"dir": dir,
		"outs": outs,
		"probes": probes,
		"saved": saved["path"],
		"launch": launch,
		"read": read,
		"wait_for": wait_for,
	}


func _close(session: Dictionary) -> void:
	if session.is_empty():
		return
	await stop_probes(session["probes"], 10000)
	_remove_dir(session["dir"])
	DirAccess.remove_absolute(session["saved"])
