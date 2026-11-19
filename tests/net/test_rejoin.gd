extends "res://tests/helpers/test_helpers.gd"
## A rejoining peer sees every death.


func _test_rejoin_sees_every_death() -> int:
	## A joiner's process dies with no goodbye and starts again, so it joins
	## under a new peer id while the server still holds the old one until
	## ENet times it out. Every death the server then deals the new player
	## reaches its own client, followed by the respawn (#171), each time, and
	## nothing meant for the old peer reaches the new one.
	print("-- test_rejoin_sees_every_death")
	var port := _free_udp_port()
	if port == 0:
		printerr("FAIL rejoin_sees_every_death found no free UDP port")
		return 1
	var dir := make_probe_dir("rejoin_%d_%d" % [OS.get_process_id(), port])
	var probes: Array[Dictionary] = []
	var outs: Array[String] = []
	var start := func(extra: Array) -> void:
		var out := dir.path_join("p%d.json" % outs.size())
		var args: Array = ["--port=%d" % port]
		args.append_array(extra)
		probes.append(spawn_probe("res://tests/late_join_probe.gd", out, args))
		outs.append(out)
	var read := read_probe_at.bind(probes)
	var wait_for := wait_until
	var joined := func(i: int) -> bool:
		var s: Dictionary = read.call(i)
		return s.get("origin") != null and s.get("players", {}).has(s.get("id")) \
				and read.call(0).get("players", {}).has(s.get("id"))

	var fail := 0
	start.call(["--host"])
	if not await wait_for.call(func() -> bool: return read.call(0).get("origin") != null, 30000):
		printerr("FAIL rejoin_sees_every_death the host did not start")
		fail += 1
	if fail == 0:
		start.call([])
		if not await wait_for.call(joined.bind(1), 30000):
			printerr("FAIL rejoin_sees_every_death the first joiner did not join: %s" % read.call(1))
			fail += 1
	var old_id: String = read.call(1).get("id", "") if fail == 0 else ""
	if fail == 0:
		OS.kill(probes[1]["pid"])
		probes[1]["pid"] = 0
		start.call([])
		if not await wait_for.call(joined.bind(2), 30000):
			printerr("FAIL rejoin_sees_every_death the restarted joiner did not join: %s" % read.call(2))
			fail += 1
	if fail == 0:
		var new_id: String = read.call(2)["id"]
		var stale: bool = read.call(0).get("players", {}).has(old_id)
		for k in range(1, 4):
			FileAccess.open(outs[0] + ".kill", FileAccess.WRITE).store_string(str(k))
			var seen := func() -> bool:
				var own: Dictionary = read.call(2)
				return own.get("deaths", 0) >= k and own.get("players", {}).get(new_id, {}).get("respawns", 0) >= k
			if not await wait_for.call(seen, 10000):
				var own: Dictionary = read.call(2)
				printerr("FAIL rejoin_sees_every_death death %d: its own client saw %s deaths and %s respawns, the server %s respawns"
						% [k, own.get("deaths"), own.get("players", {}).get(new_id, {}).get("respawns"),
						read.call(0).get("players", {}).get(new_id, {}).get("respawns")])
				fail += 1
				break
		if fail == 0 and not read.call(2).get("errors", []).is_empty():
			printerr("FAIL rejoin_sees_every_death the restarted joiner logged errors, so traffic for the old peer reached it: %s"
					% [read.call(2)["errors"]])
			fail += 1
		if fail == 0:
			print("PASS test_rejoin_sees_every_death (3 deaths and respawns; old peer %s)"
					% ("still held at the first" if stale else "already gone"))

	await stop_probes(probes, 10000)
	_remove_dir(dir)
	return fail
