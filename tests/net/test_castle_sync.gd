extends "res://tests/helpers/test_helpers.gd"
## Starting castles during two-player play (#278). The host places one for
## each peer. Both peers, and a peer that joins later, hold the same castles
## and owners.

const PROBE := "res://tests/castle_sync_probe.gd"
const SEED := 7


func _test_castle_owners_two_players() -> int:
	## Seed 7. After the first client joins, both peers hold the host's castle
	## and the client's. A late joiner matches those two and the castle the
	## host places for the late joiner; the first client receives that third
	## castle by broadcast. About 8–15 s alone; stress runs it at the job's tier.
	print("-- test_castle_owners_two_players")
	var session := _open()
	if session.is_empty():
		return 1
	var fail := 0
	var read: Callable = session["read"]
	var launch: Callable = session["launch"]
	var wait_for: Callable = session["wait_for"]
	if not await wait_for.call(func() -> bool: return read.call(0).get("ready", false), 30000):
		printerr("FAIL castle_owners_two_players: the host did not start: %s" % read.call(0))
		fail = 1
	else:
		launch.call(false, "play")
		if not await wait_for.call(func() -> bool: return _pair(read.call(0), read.call(1)), 30000):
			printerr(
				(
					"FAIL castle_owners_two_players: after join host %s client %s"
					% [_brief(read.call(0)), _brief(read.call(1))]
				)
			)
			fail = 1
		else:
			launch.call(false, "watch")
			if not await wait_for.call(func() -> bool: return _trio(read), 30000):
				printerr(
					(
						"FAIL castle_owners_two_players: late joiner host %s client %s joiner %s"
						% [_brief(read.call(0)), _brief(read.call(1)), _brief(read.call(2))]
					)
				)
				fail = 1
		for i in session["outs"].size():
			if not read.call(i).get("errors", []).is_empty():
				printerr(
					(
						"FAIL castle_owners_two_players: peer %d errors %s"
						% [i, read.call(i).get("errors", [])]
					)
				)
				fail = 1
	await _close(session)
	if fail == 0:
		print("PASS test_castle_owners_two_players")
	return fail


func _pair(host: Dictionary, client: Dictionary) -> bool:
	if not host.get("ready", false) or not client.get("ready", false):
		return false
	var builder := int(str(client.get("id", "0")))
	if builder <= 1 or not _same(host, client):
		return false
	var rows: Array = _rows(host)
	if rows.size() != 2:
		return false
	return _owned(rows, 1) and _owned(rows, builder) and _flags(rows) and _blocked(rows)


func _trio(read: Callable) -> bool:
	var host: Dictionary = read.call(0)
	var client: Dictionary = read.call(1)
	var late: Dictionary = read.call(2)
	if not late.get("ready", false) or not _same(host, client) or not _same(host, late):
		return false
	var rows: Array = _rows(host)
	if rows.size() != 3:
		return false
	var builder := int(str(client.get("id", "0")))
	var third := int(str(late.get("id", "0")))
	return (
		builder > 1
		and third > 1
		and third != builder
		and _owned(rows, 1)
		and _owned(rows, builder)
		and _owned(rows, third)
		and _flags(rows)
		and _blocked(rows)
	)


func _same(a: Dictionary, b: Dictionary) -> bool:
	return _key(a) == _key(b) and not _key(a).is_empty()


func _key(data: Dictionary) -> String:
	var parts: PackedStringArray = []
	for row in _rows(data):
		parts.append("%s:%s:%s:%s" % [row["owner"], row["x"], row["y"], row["cells"]])
	parts.sort()
	return "|".join(parts)


func _rows(data: Dictionary) -> Array:
	var out: Array = data.get("castles", [])
	return out if out is Array else []


func _owned(rows: Array, owner: int) -> bool:
	for row in rows:
		if int(row["owner"]) == owner:
			return true
	return false


func _flags(rows: Array) -> bool:
	for row in rows:
		var flag: Array = row.get("flag", [])
		if flag.size() < 2:
			return false
		var atlas := Vector2i(int(flag[0]), int(flag[1]))
		var want := (
			TileCatalog.PROP_FLAG_BLUE if int(row["owner"]) == 1 else TileCatalog.PROP_FLAG_RED
		)
		if atlas != want:
			return false
	return true


func _blocked(rows: Array) -> bool:
	for row in rows:
		if int(row.get("blocks", 0)) <= 0:
			return false
	return true


func _brief(data: Dictionary) -> String:
	var owners := []
	for row in _rows(data):
		owners.append(int(row["owner"]))
	return (
		"ready=%s owners=%s errors=%s" % [data.get("ready", false), owners, data.get("errors", [])]
	)


func _open() -> Dictionary:
	var port := _free_udp_port()
	if port == 0:
		printerr("FAIL castle sync found no free UDP port")
		return {}
	var dir := make_probe_dir("castle_sync_%d_%d" % [OS.get_process_id(), port])
	var params := _spawn_params(SEED, 0.0)
	var saved := MapSave.save_world(
		WorldSave.new(params), "test_castle_%d_%d" % [OS.get_process_id(), port]
	)
	if saved["error"] != "":
		printerr("FAIL castle sync could not save the map: %s" % saved["error"])
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
	launch.call(true, "play")
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
	await stop_probes(session["probes"], 10000)
	_remove_dir(session["dir"])
	DirAccess.remove_absolute(session["saved"])
