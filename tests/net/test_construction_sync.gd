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


func _test_building_seam_host_sync() -> int:
	## The live client is ready before the host builds; its rows must match the host.
	return await _run_row("guard_post", "test_building_seam_host_sync", true)


func _run_row(structure: String, test_name: String, host_builds := false) -> int:
	print("-- " + test_name)
	var row: Dictionary = ROWS[structure]
	var params := MapGenParams.make_defaults()
	params.biome_frequency = 0.0
	params.altitude_seed = row["seed"]
	params.moisture_seed = row["seed"]
	params.temperature_seed = row["seed"]
	params.items_seed = row["seed"]
	params.biome_seed = row["seed"]
	var session := saved_probe_session(structure + "_build", PROBE, params, ["--structure=" + structure])
	if session.is_empty():
		return 1
	var probes: Array[Dictionary] = session["probes"]
	var launch: Callable = session["launch"]
	var read: Callable = session["read"]
	var host_args: Array = session["host_args"]
	var wood_arg := "--wood=%d" % row["wood"]
	if host_builds:
		host_args.append_array([wood_arg, "--turns=1"])
	var builder_index := 0 if host_builds else 1
	var turns := 1 if host_builds else 0
	var fail := 0
	launch.call(host_args)
	if not await wait_until(func() -> bool: return read.call(0).get("ready", false), 30000):
		printerr("FAIL %s: host did not start: %s" % [test_name, read.call(0)])
		fail = 1
	else:
		launch.call([] if host_builds else [wood_arg])
		if not await wait_until(func() -> bool: return read.call(1).get("ready", false), 30000):
			printerr("FAIL %s: client did not join: %s" % [test_name, read.call(1)])
			fail = 1
		elif host_builds and not publish_probe_command(probes[0]["out"] + ".build", "place"):
			printerr("FAIL %s: could not publish the host build command" % test_name)
			fail = 1
		elif not await wait_until(func() -> bool: return _placed(read, structure, row, builder_index, turns), 15000):
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
	await close_probe_session(session)
	if fail == 0:
		print("PASS " + test_name)
	return fail


func _placed(read: Callable, structure: String, row: Dictionary, builder_index: int, turns: int) -> bool:
	var host: Dictionary = read.call(0)
	var client: Dictionary = read.call(1)
	var buyer: Dictionary = read.call(builder_index)
	if int(buyer.get("refused_wood", -1)) != row["wood"] or int(buyer.get("wood", -1)) != 0:
		return false
	var structures: Array = host.get("sync", [])
	if structures != client.get("sync") or structures.size() < row["min_total"]:
		return false
	var builder := int(str(buyer.get("id", "0")))
	var owned := 0
	for entry in structures:
		if entry is Array and str(entry[0]) == structure and int(entry[1]) == builder \
				and (int(entry[3]) if entry.size() > 3 else 0) == turns:
			owned += 1
	return owned >= row["min_owned"]
