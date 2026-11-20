extends "res://tests/helpers/test_helpers.gd"
## A client builds on land after a refused water request. The host, builder,
## and late joiner converge on the same structure rows.

const PROBE := "res://tests/construction_sync_probe.gd"
const ROWS := {
	"castle": {"seed": 7, "wood": 50, "min_owned": 2, "min_total": 3},
	"barracks": {"seed": 11, "wood": 30, "min_owned": 1, "min_total": 0},
	"guard_post": {"seed": 11, "wood": 20, "min_owned": 1, "min_total": 0},
}


func _test_castle_build_two_players() -> int:
	return await _run_row("castle", "test_castle_build_two_players")


func _test_barracks_build_two_players() -> int:
	return await _run_row("barracks", "test_barracks_build_two_players")


func _test_guard_build_two_players() -> int:
	return await _run_row("guard_post", "test_guard_build_two_players")


func _run_row(structure: String, test_name: String) -> int:
	print("-- " + test_name)
	var row: Dictionary = ROWS[structure]
	var port := _free_udp_port()
	if port == 0:
		printerr("FAIL %s: no free UDP port" % test_name)
		return 1
	var label := "%s_build_%d_%d" % [structure, OS.get_process_id(), port]
	var params := _spawn_params(row["seed"], 0.0)
	var saved := MapSave.save_world(WorldSave.new(params), "test_" + label)
	if saved["error"] != "":
		printerr("FAIL %s: could not save the map: %s" % [test_name, saved["error"]])
		return 1

	var dir := make_probe_dir(label)
	var probes: Array[Dictionary] = []
	var launch := func(extra: Array) -> void:
		var args := ["--port=%d" % port, "--structure=" + structure]
		args.append_array(extra)
		probes.append(spawn_probe(PROBE, dir.path_join("p%d.json" % probes.size()), args))
	var read := read_probe_at.bind(probes)
	var fail := 0
	launch.call(["--host", "--save=" + ProjectSettings.globalize_path(saved["path"])])
	if not await wait_until(func() -> bool: return read.call(0).get("ready", false), 30000):
		printerr("FAIL %s: host did not start: %s" % [test_name, read.call(0)])
		fail = 1
	else:
		launch.call(["--wood=%d" % row["wood"]])
		if not await wait_until(func() -> bool: return read.call(1).get("ready", false), 30000):
			printerr("FAIL %s: client did not join: %s" % [test_name, read.call(1)])
			fail = 1
		elif not await wait_until(func() -> bool: return _placed(read, structure, row), 20000):
			printerr("FAIL %s: after place host %s client %s" % [test_name, read.call(0), read.call(1)])
			fail = 1
		else:
			launch.call([])
			if not await wait_until(func() -> bool:
				var joiner: Dictionary = read.call(2)
				return joiner.get("ready", false) and joiner.get("sync") == read.call(0).get("sync"), 30000):
				printerr("FAIL %s: late joiner host %s joiner %s" % [test_name, read.call(0), read.call(2)])
				fail = 1
	for i in probes.size():
		var peer: Dictionary = read.call(i)
		if not peer.get("errors", []).is_empty() or peer.get("place_error", "") != "":
			printerr("FAIL %s: peer %d errors %s place %s"
					% [test_name, i, peer.get("errors", []), peer.get("place_error", "")])
			fail += 1
	await stop_probes(probes, 10000)
	_remove_dir(dir)
	DirAccess.remove_absolute(saved["path"])
	if fail == 0:
		print("PASS " + test_name)
	return fail


func _placed(read: Callable, structure: String, row: Dictionary) -> bool:
	var host: Dictionary = read.call(0)
	var client: Dictionary = read.call(1)
	if int(client.get("refused_wood", -1)) != row["wood"] or int(client.get("wood", -1)) != 0:
		return false
	var structures: Array = host.get("sync", [])
	if structures != client.get("sync") or structures.size() < row["min_total"]:
		return false
	var builder := int(str(client.get("id", "0")))
	var owned := 0
	for entry in structures:
		if entry is Array and str(entry[0]) == structure and int(entry[1]) == builder:
			owned += 1
	return owned >= row["min_owned"]
