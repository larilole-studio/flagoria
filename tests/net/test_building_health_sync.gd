extends "res://tests/helpers/test_helpers.gd"


func _test_building_health_two_players() -> int:
	print("-- test_building_health_two_players")
	var session := saved_probe_session(
		"building_health_two_players",
		"res://tests/building_health_probe.gd",
		_spawn_params(11, 0.0),
		[]
	)
	if session.is_empty():
		return 1
	var launch: Callable = session["launch"]
	launch.call(session["host_args"])
	launch.call([])
	var read: Callable = session["read"]
	var ready := await wait_until(
		func() -> bool:
			var client: Dictionary = read.call(1)
			var marks := {"1": [280.0, 56.0], client.get("id", ""): [168.0, 40.0]}
			return (
				_same_health(read, 2, 3)
				and read.call(0).get("peers") == marks
				and client.get("peers") == marks
			),
		25000
	)
	var ok := false
	if ready:
		ok = await _damage_and_join(session, read, launch)
	for i in session["probes"].size():
		ok = read.call(i).get("errors", []) == [] and ok
	if not ok:
		for i in session["probes"].size():
			printerr("FAIL building_health_two_players: peer %d %s" % [i, read.call(i)])
	await close_probe_session(session)
	if ok:
		print("PASS test_building_health_two_players")
	return 0 if ok else 1


func _damage_and_join(session: Dictionary, read: Callable, launch: Callable) -> bool:
	var client_command: String = session["probes"][1]["out"] + ".attack"
	# The client's sword request must reduce HP on both peers before the late join.
	if not publish_probe_command(client_command, "sword"):
		return false
	if not await wait_until(_same_health.bind(read, 2, 2), 5000):
		return false
	if not read.call(1).get("client_write_refused", false):
		return false
	launch.call(["--watch"])
	if not await wait_until(_same_health.bind(read, 3, 2), 25000):
		return false
	# All three peers must clear every footprint cell after the client's blast.
	if not publish_probe_command(client_command, "bomb"):
		return false
	return await wait_until(_same_health.bind(read, 3, -1), 6000)


func _same_health(read: Callable, count: int, hp: int) -> bool:
	for index in count:
		var peer: Dictionary = read.call(index)
		if not peer.get("ready", false) or peer.get("hp") != hp:
			return false
		if hp == -1 and not peer.get("footprint_clear", false):
			return false
	return true


func _test_building_alert_owner_only() -> int:
	print("-- test_building_alert_owner_only")
	var session := saved_probe_session(
		"building_alert_owner_only",
		"res://tests/building_alert_probe.gd",
		_spawn_params(11, 0.0),
		[]
	)
	if session.is_empty():
		return 1
	var launch: Callable = session["launch"]
	var read: Callable = session["read"]
	launch.call(session["host_args"])
	launch.call([])
	var ok := await wait_until(_alert_state.bind(read, -1, 0), 25000)
	var path: String = session["probes"][0]["out"] + ".hit"
	if ok and publish_probe_command(path, "place"):
		ok = await wait_until(_alert_state.bind(read, 30, 0), 5000)
	else:
		ok = false
	if ok and publish_probe_command(path, "damage"):
		ok = await wait_until(_alert_state.bind(read, 27, 1), 5000)
	else:
		ok = false
	if not ok:
		printerr("FAIL building_alert_owner_only: host %s, owner %s" % [read.call(0), read.call(1)])
	await close_probe_session(session)
	if ok:
		print("PASS test_building_alert_owner_only")
	return 0 if ok else 1


func _alert_state(read: Callable, hp: int, owner_alerts: int) -> bool:
	for i in 2:
		var peer: Dictionary = read.call(i)
		if not peer.get("ready", false) or not peer.get("errors", []).is_empty():
			return false
		if peer.get("hp") != hp or peer.get("alerts") != (0 if i == 0 else owner_alerts):
			return false
	return true
