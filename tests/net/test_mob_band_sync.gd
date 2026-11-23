extends "res://tests/helpers/test_helpers.gd"
## Ambient mobs around two players, and a late joiner (#228).

const PROBE := "res://tests/mob_band_probe.gd"
const SEED := 11


func _test_mob_band_two_players() -> int:
	## The host ticks once. A chasing mob past the despawn radius stays, an
	## unpinned mob that far is removed, and a late joiner's names match.
	## Seed 11. About 10-15 s. State waits only.
	print("-- test_mob_band_two_players")
	var session := _band_open()
	if session.is_empty():
		return 1
	var fail := 0
	var host_done: Dictionary = {}
	var read: Callable = session["read"]
	var launch: Callable = session["launch"]
	var wait_for: Callable = session["wait_for"]
	if not await wait_for.call(
		func() -> bool:
			return (
				_band_ready(read.call(0))
				and _band_ready(read.call(1))
				and _band_same(read.call(0), read.call(1))
			),
		20000
	):
		printerr(
			(
				"FAIL mob_band_two_players: opening roster host %s client %s"
				% [read.call(0), read.call(1)]
			)
		)
		fail = 1
	else:
		FileAccess.open(session["outs"][0] + ".tick", FileAccess.WRITE).close()
		if not await wait_for.call(
			func() -> bool:
				var host: Dictionary = read.call(0)
				return (
					int(host.get("tick", 0)) == 1
					and _band_same(host, read.call(1))
					and _band_tick_ok(host)
				),
			15000
		):
			printerr(
				(
					"FAIL mob_band_two_players: after tick host %s client %s"
					% [read.call(0), read.call(1)]
				)
			)
			fail = 1
		else:
			host_done = read.call(0)
			launch.call("join")
			if not await wait_for.call(
				func() -> bool:
					var joiner: Dictionary = read.call(2)
					return _band_ready(joiner) and _band_same(joiner, read.call(0)),
				20000
			):
				printerr(
					(
						"FAIL mob_band_two_players: late joiner %s host %s"
						% [read.call(2), read.call(0)]
					)
				)
				fail = 1
	if _band_errors(read, session):
		fail = 1
	await _band_close(session)
	if fail == 0:
		print(
			(
				"PASS test_mob_band_two_players (%s names, %s spawned)"
				% [host_done.get("names", []).size(), host_done.get("spawned", []).size()]
			)
		)
	return fail


func _band_ready(data: Dictionary) -> bool:
	return (
		bool(data.get("ready", false))
		and not (data.get("names", []) as Array).is_empty()
		and (data.get("errors", []) as Array).is_empty()
		and str(data.get("note", "")) == ""
	)


func _band_same(a: Dictionary, b: Dictionary) -> bool:
	var names: Array = a.get("names", [])
	return not names.is_empty() and names == b.get("names", [])


func _band_tick_ok(host: Dictionary) -> bool:
	var names: Array = host.get("names", [])
	var pinned := str(host.get("pinned", ""))
	var released := str(host.get("released", ""))
	var despawned: Array = host.get("despawned", [])
	if pinned == "" or not names.has(pinned) or despawned.has(pinned):
		return false
	if released == "" or names.has(released) or not despawned.has(released):
		return false
	var players: Array = host.get("players", [])
	if players.is_empty():
		return false
	var spawned: Array = host.get("spawned", [])
	var cap := int(MobSpawner.ambient_caps(float(host.get("rate", 1.0)))["total"])
	if names.size() > cap:
		return false
	for item in spawned:
		var name := str(item.get("name", ""))
		var tail := name.trim_prefix("mob_a_")
		if not name.begins_with("mob_a_") or not tail.is_valid_int() or not names.has(name):
			return false
		if not _band_in_ring(Vector2i(int(item["x"]), int(item["y"])), players):
			return false
	return true


func _band_in_ring(cell: Vector2i, players: Array) -> bool:
	var near := false
	for p in players:
		var at := Vector2i(int(p[0]), int(p[1]))
		var d := maxi(absi(cell.x - at.x), absi(cell.y - at.y))
		if d <= MobSpawner.SPAWN_MIN_RADIUS:
			return false
		if d <= MobSpawner.SPAWN_MAX_RADIUS:
			near = true
	return near


func _band_errors(read: Callable, session: Dictionary) -> bool:
	var bad := false
	for i in session["outs"].size():
		var data: Dictionary = read.call(i)
		if not (data.get("errors", []) as Array).is_empty() or str(data.get("note", "")) != "":
			printerr(
				(
					"FAIL mob_band_two_players: peer %d errors %s note %s"
					% [i, data.get("errors", []), data.get("note", "")]
				)
			)
			bad = true
	return bad


func _band_open() -> Dictionary:
	var port := _free_udp_port()
	if port == 0:
		printerr("FAIL mob_band_two_players found no free UDP port")
		return {}
	var dir := make_probe_dir("mob_band_%d_%d" % [OS.get_process_id(), port])
	var outs: Array[String] = []
	var probes: Array[Dictionary] = []
	var launch := func(role: String) -> void:
		outs.append(dir.path_join("p%d.json" % outs.size()))
		var args: Array = ["--port=%d" % port, "--role=" + role, "--seed=%d" % SEED]
		probes.append(spawn_probe(PROBE, outs[-1], args))
	var read := read_probe_at.bind(probes)
	var wait_for := wait_until
	launch.call("host")
	launch.call("join")
	return {
		"dir": dir,
		"outs": outs,
		"probes": probes,
		"launch": launch,
		"read": read,
		"wait_for": wait_for
	}


func _band_close(session: Dictionary) -> void:
	if session.is_empty():
		return
	await stop_probes(session["probes"], 10000)
	_remove_dir(session["dir"])
