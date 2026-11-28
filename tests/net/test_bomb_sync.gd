extends "res://tests/helpers/test_helpers.gd"
## Fixed seed, bounded waits. Time cost: about 5–10 s per stress run.

const PROBE := "res://tests/bomb_probe.gd"


func _test_bomb_two_players() -> int:
	print("-- test_bomb_two_players")
	var params := MapGenParams.make_defaults()
	params.biome_frequency = 0.0
	params.altitude_seed = 11
	params.moisture_seed = 11
	params.temperature_seed = 11
	params.items_seed = 11
	params.biome_seed = 11
	var session := saved_probe_session("bomb_two_players", PROBE, params, [])
	if session.is_empty():
		return 1
	var launch: Callable = session["launch"]
	launch.call(session["host_args"])
	launch.call([])
	var read: Callable = session["read"]
	var client := func() -> String: return str(read.call(1).get("id", ""))
	var ready := await wait_until(
		func() -> bool:
			var marks := {"1": [8.0, 8.0], client.call(): [168.0, 8.0]}
			return read.call(0).get("peers") == marks and read.call(1).get("peers") == marks,
		25000
	)
	var fail := 0
	var matches := func(host_hp: int, client_hp: int) -> bool:
		var health := {"1": float(host_hp), client.call(): float(client_hp)}
		for peer in [read.call(0), read.call(1)]:
			if (
				peer.get("health") != health
				or peer.get("phases_seen") != 3
				or peer.get("warning_seen") != true
				or not is_equal_approx(float(peer.get("warning_radius", 0.0)), 40.0)
			):
				return false
		return true
	var fire := func(peer: int) -> bool:
		return publish_probe_command(session["probes"][peer]["out"] + ".fire", "throw")
	# Both replicas must agree on positions before either player can throw.
	if not ready:
		printerr("FAIL bomb_two_players: peers did not settle")
		fail = 1
	elif not fire.call(0) or not await wait_until(matches.bind(6, 4), 6000):
		printerr("FAIL bomb_two_players: host bomb did not damage only the client on both peers")
		fail = 1
	elif not fire.call(1) or not await wait_until(matches.bind(4, 4), 6000):
		printerr("FAIL bomb_two_players: client request did not damage only the host on both peers")
		fail = 1
	if fail or read.call(0).get("errors", []) != [] or read.call(1).get("errors", []) != []:
		printerr("FAIL bomb_two_players: host %s / client %s" % [read.call(0), read.call(1)])
		fail = 1
	await close_probe_session(session)
	if fail == 0:
		print("PASS test_bomb_two_players")
	return fail
