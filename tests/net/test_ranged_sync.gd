extends "res://tests/helpers/test_helpers.gd"
## Two peers and a late joiner on seed 11. The host decides bow hits.
## Time cost: about 8–12 s per stress run.

const PROBE := "res://tests/ranged_probe.gd"
const SEED := 11
const MAX_HEALTH := 6


func _test_ranged_two_players() -> int:
	## Both peers see one hit, an immediate second shot does nothing, the
	## shot after the host cooldown leaves health at max - 2, a shot aimed
	## away does not change it, and a late joiner sees that health.
	print("-- test_ranged_two_players")
	var port := _free_udp_port()
	if port == 0:
		printerr("FAIL ranged_two_players found no free UDP port")
		return 1
	var dir := make_probe_dir("ranged_%d_%d" % [OS.get_process_id(), port])
	var outs: Array[String] = []
	var probes: Array[Dictionary] = []
	var launch := func(extra: Array) -> void:
		outs.append(dir.path_join("p%d.json" % outs.size()))
		var args: Array = ["--port=%d" % port, "--seed=%d" % SEED]
		args.append_array(extra)
		probes.append(spawn_probe(PROBE, outs[-1], args))
	var read := read_probe_at.bind(probes)
	var wait_for := wait_until
	var health_of := func(peer: Dictionary, who: String) -> int:
		var row = peer.get("players", {}).get(who)
		return int(row["health"]) if row is Dictionary and row.has("health") else -1
	var settled := func(i: int, who: String, at: Array) -> bool:
		var row = read.call(i).get("players", {}).get(who)
		if row is Dictionary and row.has("pos"):
			return (
				Vector2(float(row["pos"][0]), float(row["pos"][1])).distance_to(
					Vector2(float(at[0]), float(at[1]))
				)
				<= 4.0
			)
		return false
	var fire := func(token: String) -> void:
		var path := outs[1] + ".fire"
		var f := FileAccess.open(path, FileAccess.WRITE)
		f.store_string(token)
		f.close()
	var stop := func() -> void:
		await stop_probes(probes, 8000)
		_remove_dir(dir)

	var fail := 0
	launch.call(["--host"])
	if not await wait_for.call(func() -> bool: return read.call(0).get("ready", false), 20000):
		printerr("FAIL ranged_two_players: host did not start %s" % read.call(0))
		fail = 1
	else:
		launch.call([])
		if not await wait_for.call(
			func() -> bool:
				return (
					read.call(1).get("ready", false)
					and health_of.call(read.call(0), "1") == MAX_HEALTH
					and health_of.call(read.call(1), "1") == MAX_HEALTH
				),
			20000
		):
			printerr("FAIL ranged_two_players: client did not join %s" % read.call(1))
			fail = 1
		else:
			var client_id := str(read.call(1).get("id", ""))
			if not await wait_for.call(
				func() -> bool:
					var marks = read.call(0).get("marks", [])
					return marks is Array and marks.size() == 2,
				15000
			):
				printerr(
					(
						"FAIL ranged_two_players: seed %s has no clear shot %s"
						% [SEED, read.call(0).get("marks")]
					)
				)
				fail = 1
			else:
				var marks: Array = read.call(0)["marks"]
				var stand_host := FileAccess.open(outs[0] + ".stand", FileAccess.WRITE)
				stand_host.store_string("%s,%s" % [marks[0][0], marks[0][1]])
				stand_host.close()
				var stand_client := FileAccess.open(outs[1] + ".stand", FileAccess.WRITE)
				stand_client.store_string("%s,%s" % [marks[1][0], marks[1][1]])
				stand_client.close()
				if not await wait_for.call(
					func() -> bool:
						return (
							settled.call(0, "1", marks[0])
							and settled.call(0, client_id, marks[1])
							and settled.call(1, "1", marks[0])
							and settled.call(1, client_id, marks[1])
						),
					10000
				):
					printerr(
						(
							"FAIL ranged_two_players: peers did not stand %s / %s"
							% [read.call(0), read.call(1)]
						)
					)
					fail = 1
				else:
					fire.call("hit")
					if not await wait_for.call(
						func() -> bool:
							return (
								read.call(0).get("accepted", 0) == 1
								and health_of.call(read.call(0), "1") == MAX_HEALTH - 1
								and health_of.call(read.call(1), "1") == MAX_HEALTH - 1
								and not read.call(1).get("swinging", true)
							),
						8000
					):
						printerr(
							(
								"FAIL ranged_two_players: first hit host %s client %s"
								% [read.call(0), read.call(1)]
							)
						)
						fail = 1
					else:
						fire.call("again")
						if not await wait_for.call(
							func() -> bool:
								return (
									read.call(0).get("rejected", 0) >= 1
									and read.call(0).get("accepted", 0) == 1
									and health_of.call(read.call(0), "1") == MAX_HEALTH - 1
									and health_of.call(read.call(1), "1") == MAX_HEALTH - 1
								),
							8000
						):
							printerr(
								(
									"FAIL ranged_two_players: immediate second shot changed health %s"
									% read.call(0)
								)
							)
							fail = 1
						elif not await wait_for.call(
							func() -> bool:
								var row = read.call(0).get("players", {}).get(client_id, {})
								return (
									row is Dictionary
									and row.get("cooldown_ready", false)
									and not read.call(0).get("players", {}).get("1", {}).get(
										"invulnerable", true
									)
								),
							8000
						):
							printerr(
								"FAIL ranged_two_players: cooldown did not finish %s" % read.call(0)
							)
							fail = 1
						else:
							fire.call("second")
							if not await wait_for.call(
								func() -> bool:
									return (
										read.call(0).get("accepted", 0) == 2
										and health_of.call(read.call(0), "1") == MAX_HEALTH - 2
										and health_of.call(read.call(1), "1") == MAX_HEALTH - 2
									),
								8000
							):
								printerr(
									(
										"FAIL ranged_two_players: second hit wanted %s, host %s client %s"
										% [MAX_HEALTH - 2, read.call(0), read.call(1)]
									)
								)
								fail = 1
							elif not await wait_for.call(
								func() -> bool:
									var row = read.call(0).get("players", {}).get(client_id, {})
									return (
										row is Dictionary
										and row.get("cooldown_ready", false)
										and not read.call(0).get("players", {}).get("1", {}).get(
											"invulnerable", true
										)
									),
								8000
							):
								printerr(
									(
										"FAIL ranged_two_players: cooldown after the second hit %s"
										% read.call(0)
									)
								)
								fail = 1
							else:
								fire.call("away")
								if not await wait_for.call(
									func() -> bool:
										return (
											read.call(0).get("accepted", 0) == 3
											and health_of.call(read.call(0), "1") == MAX_HEALTH - 2
											and health_of.call(read.call(1), "1") == MAX_HEALTH - 2
										),
									8000
								):
									printerr(
										(
											"FAIL ranged_two_players: shot aimed away changed health %s / %s"
											% [read.call(0), read.call(1)]
										)
									)
									fail = 1
								else:
									launch.call([])
									if not await wait_for.call(
										func() -> bool:
											return (
												read.call(2).get("ready", false)
												and (
													health_of.call(read.call(2), "1")
													== MAX_HEALTH - 2
												)
											),
										20000
									):
										printerr(
											(
												"FAIL ranged_two_players: late joiner health %s, host %s"
												% [read.call(2), read.call(0)]
											)
										)
										fail = 1
	for i in outs.size():
		var errors = read.call(i).get("errors", [])
		if errors is Array and not errors.is_empty():
			printerr("FAIL ranged_two_players: peer %d logged %s" % [i, errors])
			fail = 1
	await stop.call()
	if fail == 0:
		print("PASS test_ranged_two_players (seed %s, health %s)" % [SEED, MAX_HEALTH - 2])
	return fail
