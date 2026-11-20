extends "res://tests/helpers/test_helpers.gd"
## Seeded peers converge on building, night clock, and ambient mob state.

const BUILDING_PROBE := "res://tests/generated_building_probe.gd"
const NIGHT_PROBE := "res://tests/day_night_probe.gd"
const ROWS := {
	"test_generated_building_sync": {"probe": BUILDING_PROBE, "mode": "single", "joiners": 2, "seed": 11},
	"test_building_merge_two_players": {"probe": BUILDING_PROBE, "mode": "merge", "joiners": 2, "seed": 49},
	"test_day_night_sync": {"probe": NIGHT_PROBE, "mode": "clock", "joiners": 2},
	"test_night_mob_sync": {"probe": NIGHT_PROBE, "mode": "mobs", "joiners": 1},
}
const TIMEOUT_MS := 20000


func _test_generated_building_sync() -> int:
	return await _run_world_state_row("test_generated_building_sync")


func _test_building_merge_two_players() -> int:
	return await _run_world_state_row("test_building_merge_two_players")


func _test_day_night_sync() -> int:
	return await _run_world_state_row("test_day_night_sync")


func _test_night_mob_sync() -> int:
	return await _run_world_state_row("test_night_mob_sync")


func _run_world_state_row(test_name: String) -> int:
	print("-- " + test_name)
	var row: Dictionary = ROWS[test_name]
	var port := _free_udp_port()
	if port == 0:
		printerr("FAIL %s: no free UDP port" % test_name)
		return 1
	var label := "%s_%d_%d" % [test_name, OS.get_process_id(), port]
	var host_args := ["--host"]
	var save_path := ""
	if row.has("seed"):
		var saved := MapSave.save_world(WorldSave.new(_spawn_params(row["seed"], 0.0)), label)
		if saved["error"] != "":
			printerr("FAIL %s: could not save map: %s" % [test_name, saved["error"]])
			return 1
		save_path = saved["path"]
		host_args.append("--save=" + ProjectSettings.globalize_path(save_path))

	var dir := make_probe_dir(label)
	var mode: String = row["mode"]
	var args := ["--port=%d" % port, "--mode=" + mode]
	var probes: Array[Dictionary] = [spawn_probe(row["probe"], dir.path_join("host.json"), args + host_args)]
	var read := read_probe_at.bind(probes)
	var deadline := Time.get_ticks_msec() + TIMEOUT_MS
	var initial := await wait_result(probes[0], TIMEOUT_MS)
	var passed := not initial.is_empty() and await wait_until(func() -> bool:
		return _host_ready(read.call(0), mode), maxi(0, deadline - Time.get_ticks_msec()))
	if passed:
		for i in range(1, row["joiners"] + 1):
			probes.append(spawn_probe(row["probe"], dir.path_join("peer%d.json" % i), args))
			if not await wait_until(func() -> bool:
				var host: Dictionary = read.call(0)
				for peer in range(1, i + 1):
					if not _matches(read.call(peer), host, mode):
						return false
				return true, TIMEOUT_MS):
				printerr("FAIL %s: peer %d %s host %s" % [test_name, i, read.call(i), read.call(0)])
				passed = false
				break
		if passed and mode == "merge":
			passed = await _check_removal(probes[0]["out"], read)
			if not passed:
				printerr("FAIL %s: resealed host %s client %s joiner %s"
						% [test_name, read.call(0), read.call(1), read.call(2)])
	else:
		printerr("FAIL %s: host %s" % [test_name, read.call(0)])
	await stop_probes(probes, 10000)
	for i in probes.size():
		var data: Dictionary = read.call(i)
		if not data.get("errors", []).is_empty():
			printerr("FAIL %s: peer %d errors %s" % [test_name, i, data["errors"]])
			passed = false
		if mode == "single" and i > 0 and data.get("refused", false) != true:
			printerr("FAIL %s: peer %d placed a building" % [test_name, i])
			passed = false
	var host: Dictionary = read.call(0)
	_remove_dir(dir)
	if not save_path.is_empty():
		DirAccess.remove_absolute(save_path)
	if passed:
		var suffix := " (%d rows)" % host.get("rows", []).size() if mode == "mobs" else ""
		print("PASS " + test_name + suffix)
	return int(not passed)


func _host_ready(data: Dictionary, mode: String) -> bool:
	match mode:
		"merge":
			return data.get("merged", false) and not data.get("seam", {}).is_empty()
		"clock":
			return _night(data)
		"mobs":
			return bool(data.get("ticked", false))
		_:
			return data.get("ready", false) and data.get("door_clear", false) \
					and data.get("wall_blocked", false) and not data.get("cells", {}).is_empty()


func _matches(data: Dictionary, host: Dictionary, mode: String) -> bool:
	match mode:
		"clock":
			return _clock_matches(data, host)
		"mobs":
			return _mobs_match(data, host)
		"merge":
			return _host_ready(data, mode) and data.get("seam", {}) == host.get("seam", {})
		_:
			return _host_ready(data, mode) and data.get("refused", false) \
					and data.get("cells", {}) == host.get("cells", {}) \
					and data.get("records", 0) == host.get("records", -1)


func _check_removal(host_out: String, read: Callable) -> bool:
	# Let the host remove only after both peers have captured the merged seam.
	var marker := FileAccess.open(host_out + ".remove", FileAccess.WRITE)
	if marker == null:
		return false
	marker.close()
	return await wait_until(func() -> bool:
		var host: Dictionary = read.call(0)
		for i in 3:
			var data: Dictionary = read.call(i)
			if not data.get("resealed", false) or data.get("records", 0) != 1 \
					or data.get("cells", {}) != host.get("cells", {}):
				return false
		return true, TIMEOUT_MS)


func _night(data: Dictionary) -> bool:
	return bool(data.get("synced", false)) and str(data.get("phase", "")) == "night" \
			and bool(data.get("enabled", false))


func _clock_matches(data: Dictionary, host: Dictionary) -> bool:
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


func _mobs_match(client: Dictionary, host: Dictionary) -> bool:
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
