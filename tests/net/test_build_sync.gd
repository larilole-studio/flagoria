extends "res://tests/helpers/test_helpers.gd"
## Plank bridges during two-player play (#297).

const PROBE := "res://tests/cut_sync_probe.gd"


func _test_build_sync_two_players() -> int:
	## A host and a client (each its own process, tests/cut_sync_probe.gd) on
	## seed 7 both place a one-cell plank on shore water. The host decides
	## each place; then every plank cell is a bridge and walkable on both
	## peers, both hold the same bridge list, and each spent only its own
	## wood. A second client joining after those places sees the same set.
	## Time cost: about 8–15 s alone with --only=build_sync_two_players
	## (three Godot peers); Netcode stress runs it 20×.
	print("-- test_build_sync_two_players")
	var scene = load("res://flagoria_main.tscn").instantiate()
	root.add_child(scene)
	scene.get_node("CanvasLayer2/MainMenu").hide()
	var world = scene.get_node("World/worldMap")
	world.set_process(false)
	var params := _spawn_params(7, 0.0)
	params.ensure_seeds()
	scene._apply_params_to_world(params)
	var spawn: Vector2i = world.resolve_player_spawn()
	var land := func(c: Vector2i) -> bool:
		return not world.has_bridge(c) and world.ground_is_walkable(world.predict_cell(c)[0])
	var shores: Array[Vector2i] = []
	for r in range(0, 50):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if maxi(absi(dx), absi(dy)) != r:
					continue
				var cell := spawn + Vector2i(dx, dy)
				if world.predict_cell(cell)[0] != TileCatalog.WATER:
					continue
				var touches := false
				for n in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
					if land.call(cell + n):
						touches = true
						break
				if touches:
					shores.append(cell)
				if shores.size() >= 2:
					break
			if shores.size() >= 2:
				break
		if shores.size() >= 2:
			break
	scene.queue_free()
	await process_frame
	if shores.size() < 2:
		printerr(
			(
				"FAIL build_sync_two_players: seed 7 has too few shore water cells near spawn: %s"
				% [shores]
			)
		)
		return 1
	var places_of := [[shores[0]], [shores[1]]]  # host, client
	var all: Array = places_of[0] + places_of[1]
	var cells_arg := ";".join(all.map(func(c: Vector2i) -> String: return WorldSave.cell_key(c)))
	var session := saved_probe_session("build_sync", PROBE, params, ["--cells=" + cells_arg])
	if session.is_empty():
		return 1
	var probes: Array[Dictionary] = session["probes"]
	var launch: Callable = session["launch"]
	var read: Callable = session["read"]
	var bridge_set := func(i: int) -> Array:
		var keys := []
		for entry in read.call(i).get("bridges", []):
			keys.append(str(entry))
		keys.sort()
		return keys
	var want_keys := all.map(func(c: Vector2i) -> String: return WorldSave.cell_key(c))
	want_keys.sort()
	var same := func(i: int) -> bool:
		if bridge_set.call(i) != want_keys or bridge_set.call(0) != want_keys:
			return false
		for key in want_keys:
			var here = read.call(i).get("cells", {}).get(key)
			if (
				here == null
				or here != read.call(0).get("cells", {}).get(key)
				or here.get("bridge") != true
			):
				return false
		return true

	var fail := 0
	launch.call(session["host_args"])
	if not await wait_until(func() -> bool: return read.call(0).get("ready", false), 30000):
		printerr("FAIL build_sync_two_players: the host did not start: %s" % read.call(0))
		fail += 1
	else:
		launch.call([])
		if not await wait_until(func() -> bool: return read.call(1).get("ready", false), 30000):
			printerr("FAIL build_sync_two_players: the client did not join: %s" % read.call(1))
			fail += 1
		else:
			for i in 2:
				if not publish_probe_command(
					probes[i]["out"] + ".plank", WorldSave.cell_key(shores[i])
				):
					printerr(
						(
							"FAIL build_sync_two_players: could not publish plank command for peer %d"
							% i
						)
					)
					fail += 1
			# Each places one plank (1 wood). Start wood is 0; probe adds enough.
			if not await wait_until(
				func() -> bool:
					return (
						same.call(1)
						and read.call(0).get("wood", -1) == 0
						and read.call(1).get("wood", -1) == 0
					),
				20000
			):
				printerr(
					(
						"FAIL build_sync_two_players: after both place %s, host %s, client %s"
						% [places_of, read.call(0), read.call(1)]
					)
				)
				fail += 1
			launch.call([])
			if not await wait_until(
				func() -> bool: return read.call(2).get("ready", false) and same.call(2), 30000
			):
				printerr(
					(
						"FAIL build_sync_two_players: the late joiner %s, host %s"
						% [read.call(2), read.call(0)]
					)
				)
				fail += 1
			for i in probes.size():
				if not read.call(i).get("errors", []).is_empty():
					printerr(
						(
							"FAIL build_sync_two_players: peer %d logged errors: %s"
							% [i, read.call(i)["errors"]]
						)
					)
					fail += 1

	await close_probe_session(session)
	if fail == 0:
		print("PASS test_build_sync_two_players (host place %s, client place %s)" % places_of)
	return fail
