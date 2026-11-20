extends "res://tests/helpers/test_helpers.gd"
## Host sprouts converge on the connected client and a late joiner (#361).

const Sprouts := preload("res://tests/mechanics/trees/test_tree_sprouts.gd")
const PROBE := "res://tests/cut_sync_probe.gd"


func _sprout_keys(data: Dictionary) -> Dictionary:
	## Cell key -> {entry, cell state} for each sprout in a probe's report.
	var out := {}
	var cuts: Dictionary = data.get("cuts", {})
	for chunk in cuts:
		for key in cuts[chunk]:
			if cuts[chunk][key].has("sprout"):
				out[key] = [cuts[chunk][key]["sprout"], data.get("cells", {}).get(key)]
	return out


func _test_sprout_sync_two_players() -> int:
	## A host and peers in their own processes (tests/cut_sync_probe.gd).
	## The host loads a save whose trees near the spawn are cut and builds a
	## guard post on them, so its area is short of trees. With sprouting off
	## (regrow delay 0) a client joins; then the host turns it on, sprouts,
	## and the client shows the same sprouts. A peer joining afterwards gets
	## them too, and no peer logs an error.
	print("-- test_sprout_sync_two_players")
	var scene = load("res://flagoria_main.tscn").instantiate()
	root.add_child(scene)
	scene.get_node("CanvasLayer2/MainMenu").hide()
	var world = scene.get_node("World/worldMap")
	world.set_process(false)
	var found := {}
	var params: MapGenParams
	for sv in [11, 42, 99, 7, 3]:
		params = Sprouts._static_params(sv)
		params.ensure_seeds()
		scene._apply_params_to_world(params)
		var spawn: Vector2i = world.resolve_player_spawn()
		for r in range(4, 30, 2):
			for dy in range(-r, r + 1, 2):
				for dx in range(-r, r + 1, 2):
					if found.is_empty() and maxi(absi(dx), absi(dy)) == r:
						found = Sprouts._try_anchor(world, Sprouts.guard_post(), spawn + Vector2i(dx, dy), false, spawn)
		if not found.is_empty():
			break
	scene.queue_free()
	await process_frame
	var port := _free_udp_port()
	if found.is_empty() or port == 0:
		printerr("FAIL sprout_sync_two_players: no guard post spot near a spawn (%s) or no free UDP port" % found)
		return 1
	var dir := make_probe_dir("sprout_sync_%d_%d" % [OS.get_process_id(), port])
	var world_save := WorldSave.new(params)
	for cell: Vector2i in found["lost"]:
		world_save.object_changes.get_or_add(WorldSave.chunk_key(cell), {})[WorldSave.cell_key(cell)] = {"cut": "tree", "age": 0.0}
	var saved := MapSave.save_world(world_save, "test_sprout_sync_%d_%d" % [OS.get_process_id(), port])
	var outs: Array[String] = []
	var probes: Array[Dictionary] = []
	var launch := func(extra: Array) -> void:
		outs.append(dir.path_join("p%d.json" % outs.size()))
		var args: Array = ["--port=%d" % port]
		args.append_array(extra)
		probes.append(spawn_probe(PROBE, outs[-1], args))
	var read := read_probe_at.bind(probes)
	var wait_for := wait_until
	var like_host := func(i: int) -> bool:
		var host: Dictionary = _sprout_keys(read.call(0))
		return read.call(i).get("ready", false) and not host.is_empty() and _sprout_keys(read.call(i)) == host

	var fail := 0
	launch.call(["--host", "--regrow=0", "--save=" + ProjectSettings.globalize_path(saved["path"]),
			"--place=guard_post@%s" % WorldSave.cell_key(found["anchor"])])
	launch.call(["--regrow=0"])
	if saved["error"] != "" or not await wait_for.call(func() -> bool:
			return read.call(0).get("ready", false) and read.call(1).get("ready", false), 40000):
		printerr("FAIL sprout_sync_two_players: host %s, client %s (save %s)" % [read.call(0), read.call(1), saved["error"]])
		fail += 1
	elif not _sprout_keys(read.call(0)).is_empty() or not _sprout_keys(read.call(1)).is_empty():
		printerr("FAIL sprout_sync_two_players: a peer sprouted with sprouting off")
		fail += 1
	else:
		FileAccess.open(outs[0] + ".regrow", FileAccess.WRITE).store_string("5")
		if not await wait_for.call(func() -> bool: return like_host.call(1), 20000):
			printerr("FAIL sprout_sync_two_players: host sprouts %s, client %s"
					% [_sprout_keys(read.call(0)), _sprout_keys(read.call(1))])
			fail += 1
		else:
			launch.call(["--regrow=0"])
			if not await wait_for.call(func() -> bool: return like_host.call(2), 30000):
				printerr("FAIL sprout_sync_two_players: host sprouts %s, late joiner %s"
						% [_sprout_keys(read.call(0)), _sprout_keys(read.call(2))])
				fail += 1
	for i in outs.size():
		if not read.call(i).get("errors", []).is_empty():
			printerr("FAIL sprout_sync_two_players: peer %d logged errors: %s" % [i, read.call(i)["errors"]])
			fail += 1
	var sprouted: int = _sprout_keys(read.call(0)).size()
	await stop_probes(probes, 10000)
	_remove_dir(dir)
	DirAccess.remove_absolute(saved["path"])
	if fail == 0:
		print("PASS test_sprout_sync_two_players (%d sprouts on host, client and late joiner)" % sprouted)
	return fail
