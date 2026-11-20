extends "res://tests/helpers/test_helpers.gd"
## Free-form wall placement, city changes, and wall damage.

const WALL_PROBE := "res://tests/wall_sync_probe.gd"
const ROWS := {
	"wall": {"probe": WALL_PROBE, "option": "--mode=", "mode": "wall", "timeout": 25000},
	"city": {"probe": WALL_PROBE, "option": "--mode=", "mode": "city", "timeout": 30000},
	"break": {"probe": "res://tests/wall_break_probe.gd", "option": "--phase=", "mode": "work", "timeout": 25000},
}


func _test_wall_place_two_players() -> int:
	return await run_wall_row("test_wall_place_two_players", "wall", _wall_placed, _same_built)


func _test_city_change_two_players() -> int:
	return await run_wall_row("test_city_change_two_players", "city", _city_closed, _same_city_build, Callable(), _open_city)


func run_wall_row(label: String, kind: String, changed: Callable, joined: Callable,
		after_change: Callable = Callable(), after_join: Callable = Callable()) -> int:
	print("-- " + label)
	var row: Dictionary = ROWS[kind]
	var session := saved_probe_session(label, row["probe"], _spawn_params(11, 0.0), [])
	if session.is_empty():
		return 1
	var read: Callable = session["read"]
	var launch: Callable = session["launch"]
	var probes: Array[Dictionary] = session["probes"]
	var host_args: Array = session["host_args"] + [row["option"] + row["mode"]]
	launch.call(host_args)
	var fail := 0
	var host: Dictionary = await wait_result(probes[0], 30000)
	if not host.get("ready", false):
		printerr("FAIL %s: host did not start: %s" % [label, read.call(0)])
		fail = 1
	else:
		launch.call([row["option"] + row["mode"]])
		if not await wait_until(changed.bind(read), row["timeout"]):
			printerr("FAIL %s: wall change did not sync: host %s client %s" % [label, read.call(0), read.call(1)])
			fail = 1
		elif after_change.is_valid() and not await after_change.call(read):
			fail = 1
		else:
			launch.call([row["option"] + "watch"])
			if not await wait_until(func() -> bool:
				var peer: Dictionary = read.call(2)
				return peer.get("ready", false) and joined.call(peer, read.call(0)), 30000):
				printerr("FAIL %s: late joiner %s host %s" % [label, read.call(2), read.call(0)])
				fail = 1
			elif after_join.is_valid():
				fail = await after_join.call(read, probes[0]["out"])
		for i in probes.size():
			var data: Dictionary = read.call(i)
			if not data.get("errors", []).is_empty() or str(data.get("place_error", "")) != "" \
					or str(data.get("phase_done", "")) != "":
				printerr("FAIL %s: peer %d errors %s place %s phase %s" % [
					label, i, data.get("errors", []), data.get("place_error", ""), data.get("phase_done", "")])
				fail = 1
	await close_probe_session(session)
	if fail == 0:
		print("PASS " + label)
	return fail


func _open_city(read: Callable, host_out: String) -> int:
	var gap: Array = read.call(1).get("gap", [])
	if gap.size() < 2:
		printerr("FAIL city_change_two_players: no gap cell")
		return 1
	if not publish_probe_command(host_out + ".open", "%d %d\n" % [int(gap[0]), int(gap[1])]):
		printerr("FAIL city_change_two_players: could not publish the open request")
		return 1
	var opened_or_error := await wait_until(func() -> bool:
		return str(read.call(0).get("place_error", "")) != "" or _city_opened(read), 15000)
	if not opened_or_error or not _city_opened(read):
		printerr("FAIL city_change_two_players: after open host %s client %s joiner %s"
				% [read.call(0), read.call(1), read.call(2)])
		return 1
	return 0


func _same_city_build(peer: Dictionary, host: Dictionary) -> bool:
	return _same_cities(peer, host) and _same_built(peer, host)


func _wall_placed(read: Callable) -> bool:
	var host: Dictionary = read.call(0)
	var client: Dictionary = read.call(1)
	if not client.get("ready", false):
		return false
	if int(client.get("refused_wood", -1)) != 4 or int(client.get("wood", -1)) != 2:
		return false
	if int(host.get("wood", -1)) != 0:
		return false
	if not _same_built(client, host):
		return false
	return _wall_connects(host) and _wall_connects(client)


func _wall_connects(data: Dictionary) -> bool:
	## The new palisade touches stone, so it is not a bare post and it has a collar.
	var walls: Array = data.get("walls", [])
	if walls.size() != 1:
		return false
	var piece := str(walls[0][2])
	var caps := str(walls[0][3])
	return piece.begins_with("PALISADE_") and piece != "PALISADE_POST" and caps != "" \
			and not data.get("autos", []).is_empty()


func _city_closed(read: Callable) -> bool:
	var host: Dictionary = read.call(0)
	var client: Dictionary = read.call(1)
	if str(client.get("place_error", "")) != "" or not client.get("ready", false):
		return false
	var tower := int(client.get("tower_id", -1))
	if tower <= 0 or int(host.get("tower_id", -1)) != tower:
		return false
	if int(client.get("wood", -1)) != 8:
		return false
	return _has_city(host, tower) and _same_cities(client, host) and _same_built(client, host)


func _city_opened(read: Callable) -> bool:
	var tower := int(read.call(1).get("tower_id", -1))
	if tower <= 0:
		return false
	for i in 3:
		if _has_city(read.call(i), tower):
			return false
	return _same_cities(read.call(1), read.call(0)) and _same_cities(read.call(2), read.call(0)) \
			and _same_built(read.call(1), read.call(0)) and _same_built(read.call(2), read.call(0))


func _has_city(data: Dictionary, tower: int) -> bool:
	for row in data.get("cities", []):
		if int(row[0]) == tower:
			return true
	return false


func _same_cities(a: Dictionary, b: Dictionary) -> bool:
	return _key(a.get("cities", [])) == _key(b.get("cities", [])) and not _key(b.get("cities", [])).is_empty()


func _same_built(a: Dictionary, b: Dictionary) -> bool:
	return _key(a.get("walls", [])) == _key(b.get("walls", [])) \
			and _key(a.get("autos", [])) == _key(b.get("autos", [])) \
			and not _key(b.get("walls", [])).is_empty() \
			and not _key(b.get("autos", [])).is_empty()


func _key(rows: Array) -> String:
	var parts: PackedStringArray = []
	for row in rows:
		parts.append(str(row))
	return "|".join(parts)
