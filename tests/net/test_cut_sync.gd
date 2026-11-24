extends "res://tests/helpers/test_helpers.gd"
## Tree and bush cuts during two-player play (#223).

const PROBE := "res://tests/cut_sync_probe.gd"
const ROWS := {
	"test_cut_sync_two_players": {"plants": 2, "radius": 0, "action": "cut"},
	"test_dead_cut_client": {"plants": 1, "radius": 2, "action": "dead_cut"},
	"test_cut_refused_two_players": {"plants": 0, "radius": 0, "action": "swing"},
}


func _test_cut_sync_two_players() -> int:
	## A host and a client (each its own process, tests/cut_sync_probe.gd)
	## on seed 7 both cut a tree and a bush at the same time. The host
	## decides each cut; then every cut cell shows the same stump and is
	## open ground on both peers, both hold the same cut list, and each got
	## its own wood (3 per tree, 1 per bush). A second client joining after
	## those cuts sees the same set.
	return await _run_row("test_cut_sync_two_players")


func _test_dead_cut_client() -> int:
	## A host and a client (tests/cut_sync_probe.gd) on seed 7 (#349). The
	## host kills the client's player; the dead client drags a selection over
	## a tree in reach, then sends the host request_cut for it directly. The
	## host refuses both. Once it processes the requests, neither peer holds
	## a cut and the client's wood is unchanged.
	return await _run_row("test_dead_cut_client")


func _test_cut_refused_two_players() -> int:
	## A host and a client on seed 7 (#350). The client chops a tree while the
	## host still sees it at spawn, out of reach: the plant stays, wood stays
	## 0 and no fall or pickup plays. It then chops a tree the host can see:
	## that one falls, pays its wood and leaves a stump on the client.
	return await _run_row("test_cut_refused_two_players")


func _run_row(label: String) -> int:
	print("-- " + label)
	var row: Dictionary = ROWS[label]
	var params := _spawn_params(7, 0.0)
	params.ensure_seeds()
	var targets: Array = []
	if row["plants"] > 0:
		targets = await _cut_targets(params, row["plants"], row["radius"])
		if targets.is_empty():
			return 1
	var keys := PackedStringArray()
	for cells in targets:
		keys.append_array(cells)
	var session := saved_probe_session(label, PROBE, params, ["--cells=" + ";".join(keys)])
	if session.is_empty():
		return 1
	var read: Callable = session["read"]
	var launch: Callable = session["launch"]
	var probes: Array[Dictionary] = session["probes"]
	launch.call(session["host_args"])
	launch.call([])
	var fail := 0
	if not await wait_until(
		func() -> bool:
			return read.call(0).get("ready", false) and read.call(1).get("ready", false),
		30000
	):
		printerr(
			(
				"FAIL %s: session did not start: host %s, client %s"
				% [label, read.call(0), read.call(1)]
			)
		)
		fail += 1
	else:
		match row["action"]:
			"cut":
				fail += await _both_cut(read, launch, probes, targets, Array(keys))
			"dead_cut":
				fail += await _dead_cut(read, probes, targets[0][0])
			"swing":
				fail += await _refused_cut(read, probes[1]["out"])
		for i in probes.size():
			var errors: Array = read.call(i).get("errors", [])
			if not errors.is_empty():
				printerr("FAIL %s: peer %d logged errors: %s" % [label, i, errors])
				fail += 1
	await close_probe_session(session)
	if fail == 0:
		var detail := ""
		if row["action"] == "cut":
			detail = " (host cut %s, client cut %s)" % targets
		elif row["action"] == "dead_cut":
			detail = " (tree %s)" % targets[0][0]
		print("PASS " + label + detail)
	return fail


func _cut_targets(params: MapGenParams, count: int, first_radius: int) -> Array:
	var scene = load("res://flagoria_main.tscn").instantiate()
	root.add_child(scene)
	scene.get_node("CanvasLayer2/MainMenu").hide()
	var world = scene.get_node("World/worldMap")
	world.set_process(false)
	scene._apply_params_to_world(params)
	var spawn: Vector2i = world.resolve_player_spawn()
	var found := {"tree": [], "bush": []} if count == 2 else {"tree": []}
	for r in range(first_radius, 40):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if maxi(absi(dx), absi(dy)) != r:
					continue
				var cell := spawn + Vector2i(dx, dy)
				var type := InteractableCatalog.type_at(world.predict_cell(cell)[1])
				if type != null and found.has(type.id) and found[type.id].size() < count:
					found[type.id].append(WorldSave.cell_key(cell))
	scene.queue_free()
	await process_frame
	var targets := []
	for kind in found:
		if found[kind].size() < count:
			printerr("FAIL cut sync: seed 7 has too few %s near spawn: %s" % [kind, found])
			return []
	for i in count:
		var cells := PackedStringArray()
		for kind in found:
			cells.append(found[kind][i])
		targets.append(cells)
	return targets


func _cut_keys(peer: Dictionary) -> Array:
	var keys := []
	for chunk in peer.get("cuts", {}).values():
		keys.append_array(chunk.keys())
	keys.sort()
	return keys


func _same_cuts(read: Callable, index: int, keys: Array) -> bool:
	var host: Dictionary = read.call(0)
	var peer: Dictionary = read.call(index)
	if _cut_keys(host) != keys or _cut_keys(peer) != keys:
		return false
	for key in keys:
		var here = peer.get("cells", {}).get(key)
		if here == null or here != host.get("cells", {}).get(key) or here["clear"] != true:
			return false
	return true


func _both_cut(
	read: Callable, launch: Callable, probes: Array[Dictionary], targets: Array, keys: Array
) -> int:
	for i in 2:
		if not publish_probe_command(probes[i]["out"] + ".cut", ";".join(targets[i])):
			printerr("FAIL cut_sync_two_players: could not publish cut command for peer %d" % i)
			return 1
	keys.sort()
	var wood := 4
	var fail := 0
	if not await wait_until(
		func() -> bool:
			return (
				_same_cuts(read, 1, keys)
				and read.call(0).get("wood", 0) == wood
				and read.call(1).get("wood", 0) == wood
			),
		20000
	):
		printerr(
			(
				"FAIL cut_sync_two_players: after both cut %s, host %s, client %s"
				% [targets, read.call(0), read.call(1)]
			)
		)
		fail += 1
	launch.call([])
	if not await wait_until(
		func() -> bool: return read.call(2).get("ready", false) and _same_cuts(read, 2, keys), 30000
	):
		printerr(
			"FAIL cut_sync_two_players: late joiner %s, host %s" % [read.call(2), read.call(0)]
		)
		fail += 1
	return fail


func _dead_cut(read: Callable, probes: Array[Dictionary], tree: String) -> int:
	if (
		not publish_probe_command(probes[1]["out"] + ".dead_cut", tree)
		or not publish_probe_command(probes[0]["out"] + ".kill", read.call(1)["id"])
	):
		printerr("FAIL dead_cut_client: could not publish death or cut command")
		return 1
	if not await wait_until(func() -> bool: return read.call(1).get("dead_cut", -1) >= 0, 10000):
		printerr("FAIL dead_cut_client: the client never cut while dead: %s" % read.call(1))
		return 1
	var host: Dictionary = read.call(0)
	var client: Dictionary = read.call(1)
	if (
		client.get("dead_cut", 0) < 1
		or not client.get("dead", false)
		or not host.get("cuts", {}).is_empty()
		or not client.get("cuts", {}).is_empty()
		or client.get("wood", -1) != 0
	):
		printerr("FAIL dead_cut_client: tree %s, host %s, client %s" % [tree, host, client])
		return 1
	return 0


func _count_sounds(sounds: Array, prefix: String) -> int:
	var count := 0
	for sound in sounds:
		if str(sound).begins_with(prefix):
			count += 1
	return count


func _refused_cut(read: Callable, out: String) -> int:
	FileAccess.open(out + ".swing", FileAccess.WRITE).close()
	if not await wait_until(func() -> bool: return read.call(1).get("swing_done", false), 30000):
		printerr("FAIL cut_refused_two_players: the client did not finish: %s" % read.call(1))
		return 1
	var fail := 0
	var client: Dictionary = read.call(1)
	var wood := 3
	var far := str(client.get("far", ""))
	var near := str(client.get("near", ""))
	var far_cell: Dictionary = client.get("cells", {}).get(far, {})
	var near_cell: Dictionary = client.get("cells", {}).get(near, {})
	var refused: Array = client.get("refused_sounds", [])
	var sounds: Array = client.get("sounds", [])
	var keys: Array = _cut_keys(client)
	if not near.is_empty() and keys.has(near):
		await wait_until(func() -> bool: return _cut_keys(read.call(0)).has(near), 5000)
	var host: Dictionary = read.call(0)
	var host_keys: Array = _cut_keys(host)
	if (
		client.get("swing_error", "") != ""
		or client.get("refused_fells", -1) != 0
		or _count_sounds(refused, "tree_fall") != 0
		or _count_sounds(refused, "wood_pickup") != 0
		or far_cell.get("clear", true)
		or far_cell.get("plant", [-1, -1]) == [-1, -1]
		or keys.has(far)
		or host_keys.has(far)
		or host.get("wood", -1) != 0
	):
		printerr("FAIL cut_refused_two_players: refused cut changed the world: %s" % client)
		fail += 1
	if (
		client.get("fells", 0) != 1
		or _count_sounds(sounds, "tree_fall") != 1
		or _count_sounds(sounds, "wood_pickup") != 1
		or client.get("wood", -1) != wood
		or not near_cell.get("clear", false)
		or not keys.has(near)
		or not host_keys.has(near)
		or keys.has(far)
	):
		printerr(
			(
				"FAIL cut_refused_two_players: accepted cut far %s near %s host %s client %s"
				% [far, near, host, client]
			)
		)
		fail += 1
	return fail
