extends "res://tests/helpers/test_helpers.gd"
## Mob placement, spawn rate, wandering and sprite sheets (Scripts/mob_spawner.gd, Scripts/mob.gd).


func _test_mob_predict_matches_chunks() -> int:
	## TileMap.predict_cell gives the same ground and plant/structure as
	## generate_chunk, with biomes off, on, and archipelago, so mobs can read
	## terrain where no chunk was generated.
	print("-- test_mob_predict_matches_chunks")
	var scene = load("res://flagoria_main.tscn").instantiate()
	root.add_child(scene)
	var world = scene.get_node("World/worldMap")
	var cases := [_spawn_params(11, 0.0), _spawn_params(42, 0.003), _biome_terrain_params(true)]
	var fail := 0
	for i in cases.size():
		world.apply_map_params(cases[i])
		world.generate_chunk(Vector2(0, 0))
		var checked := 0
		for cell in world.get_used_cells(0):
			var top: Vector2i = world.get_cell_atlas_coords(1, cell)
			if top == world.NO_PLANT:
				top = world.get_cell_atlas_coords(2, cell)
			var want := [world.get_cell_atlas_coords(0, cell), top]
			var got: Array = world.predict_cell(cell)
			checked += 1
			if got != want:
				printerr("FAIL mob_predict case=%s cell=%s predicted %s, chunk has %s" % [i, cell, got, want])
				fail += 1
				break
			if world.predicted_clear(cell) != world.is_clear_ground(cell):
				printerr("FAIL mob_predict case=%s cell=%s predicted_clear differs" % [i, cell])
				fail += 1
				break
		if checked == 0:
			printerr("FAIL mob_predict case=%s generated no cells" % i)
			fail += 1
	if fail == 0:
		print("PASS test_mob_predict_matches_chunks (%s maps)" % cases.size())
	scene.queue_free()
	return fail


func _test_mob_plan() -> int:
	## Mob placement is the same for a seed, places a few mobs on home ground
	## (crabs on sand, the rest on grass) away from the player spawn and apart
	## from each other, and generates no tiles.
	print("-- test_mob_plan")
	var scene = load("res://flagoria_main.tscn").instantiate()
	root.add_child(scene)
	var world = scene.get_node("World/worldMap")
	var fail := 0
	var total := 0
	for biome_frequency in [0.0, 0.003]:
		for seed_value in [1, 7, 11, 42, 99]:
			var label := "seed=%s biomes=%s" % [seed_value, biome_frequency > 0.0]
			world.apply_map_params(_spawn_params(seed_value, biome_frequency))
			var plan: Array = MobSpawner.plan(world, Vector2i(0, 0), seed_value)
			if world.get_used_cells(0).size() != 0:
				printerr("FAIL mob_plan %s planning generated tiles" % label)
				fail += 1
			world.apply_map_params(_spawn_params(seed_value, biome_frequency))
			if MobSpawner.plan(world, Vector2i(0, 0), seed_value) != plan:
				printerr("FAIL mob_plan %s differs between runs" % label)
				fail += 1
			if plan.size() > MobSpawner.MAX_MOBS:
				printerr("FAIL mob_plan %s has %s mobs, cap %s" % [label, plan.size(), MobSpawner.MAX_MOBS])
				fail += 1
			total += plan.size()
			for i in plan.size():
				var cell: Vector2i = plan[i]["cell"]
				var type: String = plan[i]["type"]
				var home: int = MobCatalog.stat(type, "home")
				if not MobSpawner.is_home_cell(world, cell, home):
					printerr("FAIL mob_plan %s %s at %s is not on its home ground" % [label, type, cell])
					fail += 1
				if maxi(absi(cell.x), absi(cell.y)) <= MobSpawner.SAFE_RADIUS:
					printerr("FAIL mob_plan %s %s at %s is next to the spawn" % [label, type, cell])
					fail += 1
				for j in i:
					var o: Vector2i = plan[j]["cell"]
					if maxi(absi(cell.x - o.x), absi(cell.y - o.y)) < MobSpawner.MIN_GAP:
						printerr("FAIL mob_plan %s mobs %s and %s are too close" % [label, i, j])
						fail += 1
	if total == 0:
		printerr("FAIL mob_plan no mobs on any map")
		fail += 1
	if fail == 0:
		print("PASS test_mob_plan (%s mobs over 10 maps)" % total)
	scene.queue_free()
	return fail


func _test_mob_spawn_rate() -> int:
	## The host's saved mob spawn rate: defaults above the old 1x, the menu
	## slider saves it and it reloads, it changes how many mobs a world gets,
	## and a client never spawns mobs from its own rate.
	print("-- test_mob_spawn_rate")
	var fail := 0
	var game = root.get_node("GameSettings")
	var saved_path: String = game.save_path
	game.save_path = "user://test_game_settings.cfg"
	DirAccess.remove_absolute(game.save_path)
	game.load_from_disk()
	if game.mob_rate != game.MOB_RATE_DEFAULT or game.MOB_RATE_DEFAULT <= 1.0:
		printerr("FAIL mob_spawn_rate: fresh rate %s, default %s (must be above 1x)" % [game.mob_rate, game.MOB_RATE_DEFAULT])
		fail += 1
	# Corrupt or hand-edited values: default or clamp, never a crash.
	for pair in [["abc", 2.0], [NAN, 2.0], [INF, 2.0], [-1, 0.5], [9, 3.0], [1.1, 1.0]]:
		var cfg := ConfigFile.new()
		cfg.set_value(game.SECTION, "mob_rate", pair[0])
		cfg.save(game.save_path)
		game.load_from_disk()
		if not is_equal_approx(game.mob_rate, pair[1]):
			printerr("FAIL mob_spawn_rate: saved %s loads as %s, want %s" % [pair[0], game.mob_rate, pair[1]])
			fail += 1
	DirAccess.remove_absolute(game.save_path)
	game.load_from_disk()

	var scene = load("res://flagoria_main.tscn").instantiate()
	root.add_child(scene)
	var menu = scene.get_node("CanvasLayer2/MainMenu")
	if not is_equal_approx(menu.mob_rate.value, game.MOB_RATE_DEFAULT) or menu.mob_rate_value.text != "2x":
		printerr("FAIL mob_spawn_rate: slider starts at %s (%s)" % [menu.mob_rate.value, menu.mob_rate_value.text])
		fail += 1
	menu.mob_rate.value = 0.75
	if menu.mob_rate_value.text != "0.75x":
		printerr("FAIL mob_spawn_rate: label shows %s at 0.75" % menu.mob_rate_value.text)
		fail += 1
	game.mob_rate = game.MOB_RATE_DEFAULT  # reload from disk, as on the next launch
	game.load_from_disk()
	if not is_equal_approx(game.mob_rate, 0.75):
		printerr("FAIL mob_spawn_rate: slider at 0.75 reloads as %s" % game.mob_rate)
		fail += 1

	# The host spawns more mobs at a higher rate, within that rate's cap.
	var world = scene.get_node("World/worldMap")
	var mobs_node: MobSpawner = scene.get_node("World/Mobs")
	var want_caps := {1.0: [300, 3, 10], 2.0: [150, 6, 20], 3.0: [100, 9, 30]}
	for rate in want_caps:
		var c: Dictionary = MobSpawner.caps(rate)
		if [c["cells_per_mob"], c["per_island"], c["total"]] != want_caps[rate]:
			printerr("FAIL mob_spawn_rate: caps at %sx are %s, want %s" % [rate, c, want_caps[rate]])
			fail += 1
	var counts := {}
	var most := 0
	for rate in [1.0, game.MOB_RATE_DEFAULT, game.MOB_RATE_MAX]:
		game.set_mob_rate(rate, false)
		counts[rate] = 0
		for seed_value in [1, 7, 42]:
			scene.world_params = _spawn_params(seed_value, 0.003)
			world.apply_map_params(scene.world_params)
			var n: int = scene.spawn_mobs()
			if n != mobs_node.mobs().size() or n > MobSpawner.caps(rate)["total"]:
				printerr("FAIL mob_spawn_rate: rate %s seed %s spawned %s, %s in the tree" % [rate, seed_value, n, mobs_node.mobs().size()])
				fail += 1
			counts[rate] += n
			most = maxi(most, n)
	if not (counts[game.MOB_RATE_DEFAULT] >= counts[1.0] * 3 / 2 and counts[game.MOB_RATE_MAX] > counts[game.MOB_RATE_DEFAULT]):
		printerr("FAIL mob_spawn_rate: mobs over 3 maps by rate %s" % counts)
		fail += 1
	if most <= MobSpawner.MAX_MOBS:
		printerr("FAIL mob_spawn_rate: no map got more than the 1x cap of %s mobs" % MobSpawner.MAX_MOBS)
		fail += 1

	# A client with its own rate spawns nothing; it only gets the host's mobs.
	mobs_node.clear_mobs()
	var cmp := SceneMultiplayer.new()
	set_multiplayer(cmp, scene.get_path())
	var cpeer := ENetMultiplayerPeer.new()
	cpeer.create_client("127.0.0.1", _free_udp_port())
	cmp.multiplayer_peer = cpeer
	game.set_mob_rate(game.MOB_RATE_MAX, false)
	var client_count: int = scene.spawn_mobs()
	if client_count != 0 or mobs_node.mobs().size() != 0:
		printerr("FAIL mob_spawn_rate: client spawned %s mobs (%s in the tree)" % [client_count, mobs_node.mobs().size()])
		fail += 1
	cpeer.close()
	set_multiplayer(null, scene.get_path())

	scene.queue_free()
	await process_frame
	DirAccess.remove_absolute(game.save_path)
	game.save_path = saved_path
	game.load_from_disk()
	if fail == 0:
		print("PASS test_mob_spawn_rate (mobs over 3 maps by rate %s)" % counts)
	return fail


func _test_mob_wander() -> int:
	## Offline host: spawn the map's mobs, run 40 s of wander, and check every
	## mob moves, never leaves its home ground or wander radius, and shows the
	## walk or idle rows for its facing.
	print("-- test_mob_wander")
	var scene = load("res://flagoria_main.tscn").instantiate()
	root.add_child(scene)
	var world = scene.get_node("World/worldMap")
	var mobs_node: MobSpawner = scene.get_node("World/Mobs")
	scene.world_params = _spawn_params(42, 0.003)
	world.apply_map_params(scene.world_params)
	var fail := 0
	var count: int = scene.spawn_mobs()
	var mobs: Array = mobs_node.mobs()
	if count == 0 or mobs.size() != count:
		printerr("FAIL mob_wander spawned %s, %s in the tree" % [count, mobs.size()])
		scene.queue_free()
		return 1
	var start := {}
	for m in mobs:
		start[m] = m.position
	var moved := {}
	var dt := 1.0 / 45.0
	for tick in range(45 * 40):
		for m in mobs:
			m.think(dt)
			m._process(dt)
			if m.position != start[m]:
				moved[m] = true
			var cell: Vector2i = world.local_to_map(m.position)
			if not MobSpawner.is_home_cell(world, cell, MobCatalog.stat(m.mob_type, "home")):
				printerr("FAIL mob_wander %s %s left home ground at %s" % [m.name, m.mob_type, cell])
				fail += 1
			if m.position.distance_to(m.home) > Mob.WANDER_RADIUS + 0.01:
				printerr("FAIL mob_wander %s left its wander radius" % m.name)
				fail += 1
			var row: int = m.sprite.frame_coords.y
			var block: int = MobCatalog.ANIMS[m.anim_name()]["row"]
			if row != block + m.facing:
				printerr("FAIL mob_wander %s shows row %s for %s facing %s" % [m.name, row, m.anim_name(), m.facing])
				fail += 1
		if fail > 0:
			break
	if fail == 0 and moved.size() != mobs.size():
		printerr("FAIL mob_wander only %s of %s mobs moved" % [moved.size(), mobs.size()])
		fail += 1
	if fail == 0:
		print("PASS test_mob_wander (%s mobs)" % mobs.size())
	scene.queue_free()
	return fail


func _test_mob_sheet_swap() -> int:
	## Each mob type's art is one sheet path: the scene holds no texture and the
	## sprite uses whatever file that path names, on the shared 8x16 grid.
	print("-- test_mob_sheet_swap")
	var fail := 0
	var tscn := FileAccess.get_file_as_string("res://Mobs/mob.tscn")
	if tscn.contains(".png"):
		printerr("FAIL mob_sheet_swap Mobs/mob.tscn names a texture")
		fail += 1
	for type in MobCatalog.names():
		var mob: Mob = load("res://Mobs/mob.tscn").instantiate()
		mob.setup(type, Vector2.ZERO, 1)
		root.add_child(mob)
		var tex: Texture2D = mob.sprite.texture
		var want: String = MobCatalog.stat(type, "sheet")
		if tex == null or tex.resource_path != want:
			printerr("FAIL mob_sheet_swap %s sprite is not %s" % [type, want])
			fail += 1
		elif tex.get_size() != Vector2(MobCatalog.SHEET_COLS, MobCatalog.SHEET_ROWS) * MobCatalog.FRAME_SIZE:
			printerr("FAIL mob_sheet_swap %s sheet is %s" % [type, tex.get_size()])
			fail += 1
		if mob.sprite.hframes != MobCatalog.SHEET_COLS or mob.sprite.vframes != MobCatalog.SHEET_ROWS:
			printerr("FAIL mob_sheet_swap %s sprite grid is not 8x16" % type)
			fail += 1
		mob.queue_free()
	if fail == 0:
		print("PASS test_mob_sheet_swap (%s types)" % MobCatalog.names().size())
	return fail


func _test_mob_band_plan() -> int:
	## Ambient placement is a pure function of the seed: the ring, the chase
	## pin, and the caps. Seed 11. About 0.5 s.
	print("-- test_mob_band_plan")
	var scene = load("res://flagoria_main.tscn").instantiate()
	root.add_child(scene)
	var world = scene.get_node("World/worldMap")
	world.apply_map_params(_spawn_params(11, 0.0))
	var player := _band_grass(world)
	var fail := 0
	var one := MobSpawner.ambient_caps(1.0)
	var two := MobSpawner.ambient_caps(2.0)
	if one != {"per_player": 10, "total": 30} or two != {"per_player": 20, "total": 60}:
		printerr("FAIL mob_band_plan caps 1x %s 2x %s" % [one, two])
		fail += 1
	var mob: Mob = load("res://Mobs/mob.tscn").instantiate()
	if mob.pinned():
		printerr("FAIL mob_band_plan an idle mob is pinned")
		fail += 1
	mob.state = Mob.State.CHASE
	if not mob.pinned():
		printerr("FAIL mob_band_plan a chasing mob is not pinned")
		fail += 1
	mob.free()
	var none: Dictionary = MobSpawner.plan_tick(world, [], [{"name": "mob_0", "cell": player, "pinned": false}], 11, 0, 1.0)
	if not none["spawn"].is_empty() or not none["despawn"].is_empty():
		printerr("FAIL mob_band_plan empty players changed the wave: %s" % none)
		fail += 1
	var open_a: Dictionary = MobSpawner.plan_tick(world, [player], [], 11, 0, 1.0)
	var open_b: Dictionary = MobSpawner.plan_tick(world, [player], [], 11, 0, 1.0)
	if open_a != open_b:
		printerr("FAIL mob_band_plan the same arguments differed")
		fail += 1
	if open_a["spawn"].is_empty():
		printerr("FAIL mob_band_plan seed 11 spawned nothing around %s" % player)
		fail += 1
	var seen := {}
	var chunks := {}
	for item in open_a["spawn"]:
		var name := str(item["name"])
		var cell: Vector2i = item["cell"]
		var tail := name.trim_prefix("mob_a_")
		if not name.begins_with("mob_a_") or not tail.is_valid_int():
			printerr("FAIL mob_band_plan name %s is not mob_a_N" % name)
			fail += 1
		if seen.has(name):
			printerr("FAIL mob_band_plan duplicate %s" % name)
			fail += 1
		seen[name] = true
		if not _band_cell_ok(world, cell, [player], str(item["type"])):
			printerr("FAIL mob_band_plan %s %s at %s is outside the band" % [name, item["type"], cell])
			fail += 1
		if not _band_lowest(world, cell, player, 11):
			printerr("FAIL mob_band_plan %s is not the lowest rank in its chunk" % cell)
			fail += 1
		var chunk := _band_chunk(cell)
		chunks[chunk] = int(chunks.get(chunk, 0)) + 1
		if int(chunks[chunk]) > MobSpawner.PER_CHUNK_CAP:
			printerr("FAIL mob_band_plan chunk %s has %s spawns" % [chunk, chunks[chunk]])
			fail += 1
	if open_a["spawn"].size() > int(one["per_player"]) or open_a["spawn"].size() > int(one["total"]):
		printerr("FAIL mob_band_plan spawned %s over the cap %s" % [open_a["spawn"].size(), one])
		fail += 1
	var pinned := {"name": "mob_0", "cell": player + Vector2i(0, 80), "pinned": true}
	var loose := {"name": "mob_1", "cell": player + Vector2i(80, 0), "pinned": false}
	var close := {"name": "mob_2", "cell": player + Vector2i(3, 0), "pinned": false}
	var moved: Dictionary = MobSpawner.plan_tick(world, [player], [pinned, loose, close], 11, 1, 1.0)
	if moved["despawn"].has("mob_0") or not moved["despawn"].has("mob_1") or moved["despawn"].has("mob_2"):
		printerr("FAIL mob_band_plan despawn %s (pin stays, far unpinned goes, near stays)" % moved["despawn"])
		fail += 1
	var fillers: Array = []
	for i in int(one["per_player"]):
		fillers.append({"name": "mob_%d" % i, "cell": player + Vector2i(20, 0), "pinned": false})
	var capped: Dictionary = MobSpawner.plan_tick(world, [player], fillers, 11, 2, 1.0)
	if not capped["spawn"].is_empty() or not capped["despawn"].is_empty():
		printerr("FAIL mob_band_plan per-player cap still spawned %s despawned %s" % [capped["spawn"], capped["despawn"]])
		fail += 1
	var globe: Array = []
	var filler_at := player + Vector2i(60, 0)
	if chunks.has(_band_chunk(filler_at)) and chunks.size() == 1:
		filler_at = player + Vector2i(0, 60)
	for i in int(one["total"]):
		globe.append({"name": "hold_%d" % i, "cell": filler_at, "pinned": false})
	var full: Dictionary = MobSpawner.plan_tick(world, [player], globe, 11, 3, 1.0)
	if not full["spawn"].is_empty() or not full["despawn"].is_empty():
		printerr("FAIL mob_band_plan global cap still spawned %s despawned %s" % [full["spawn"], full["despawn"]])
		fail += 1
	var wider: Dictionary = MobSpawner.plan_tick(world, [player], fillers, 11, 2, 2.0)
	if wider["spawn"].is_empty() and chunks.size() > 1:
		printerr("FAIL mob_band_plan rate 2 did not use the raised per-player cap")
		fail += 1
	var other := player + Vector2i(8, 0)
	var both: Dictionary = MobSpawner.plan_tick(world, [player, other], [], 11, 4, 1.0)
	for item in both["spawn"]:
		if not _band_cell_ok(world, item["cell"], [player, other], str(item["type"])):
			printerr("FAIL mob_band_plan two players: %s at %s breaks the band" % [item["name"], item["cell"]])
			fail += 1
	if both != MobSpawner.plan_tick(world, [player, other], [], 11, 4, 1.0):
		printerr("FAIL mob_band_plan two-player plan was not stable")
		fail += 1
	scene.queue_free()
	if fail == 0:
		print("PASS test_mob_band_plan (%s spawns around %s)" % [open_a["spawn"].size(), player])
	return fail


func _band_grass(world: TileMap) -> Vector2i:
	for r in 48:
		for x in range(-r, r + 1):
			for y in range(-r, r + 1):
				if maxi(absi(x), absi(y)) != r:
					continue
				var cell := Vector2i(x, y)
				if MobSpawner.is_home_cell(world, cell, MobCatalog.HOME_GRASS):
					return cell
	return Vector2i.ZERO


func _band_chunk(cell: Vector2i) -> Vector2i:
	return Vector2i(floori(float(cell.x) / 32.0), floori(float(cell.y) / 32.0))


func _band_rank(cell: Vector2i, seed_value: int) -> int:
	return hash(Vector3i(cell.x, cell.y, seed_value)) & 0x7FFFFFFF


func _band_cell_ok(world: TileMap, cell: Vector2i, players: Array, type: String) -> bool:
	var home: int = MobCatalog.stat(type, "home")
	if not MobSpawner.is_home_cell(world, cell, home):
		return false
	var near := false
	for p in players:
		var at: Vector2i = p
		var d := maxi(absi(cell.x - at.x), absi(cell.y - at.y))
		if d <= MobSpawner.SPAWN_MIN_RADIUS:
			return false
		if d <= MobSpawner.SPAWN_MAX_RADIUS:
			near = true
	return near


func _band_lowest(world: TileMap, cell: Vector2i, player: Vector2i, seed_value: int) -> bool:
	var rank := _band_rank(cell, seed_value)
	var origin := _band_chunk(cell) * MobSpawner.CHUNK
	for y in MobSpawner.CHUNK:
		for x in MobSpawner.CHUNK:
			var other := origin + Vector2i(x, y)
			var d := maxi(absi(other.x - player.x), absi(other.y - player.y))
			if d <= MobSpawner.SPAWN_MIN_RADIUS or d > MobSpawner.SPAWN_MAX_RADIUS:
				continue
			if MobSpawner.home_kind(world, other) < 0:
				continue
			if _band_rank(other, seed_value) < rank:
				return false
	return true
