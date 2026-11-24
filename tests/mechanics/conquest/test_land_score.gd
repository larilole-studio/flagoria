extends "res://tests/helpers/test_helpers.gd"
## Land inside city walls, limited by each flag's range (#279).

const ORIGIN := Vector2i(-10, 11)
const FIRST_TOWER := ORIGIN + Vector2i(2, 3)
const SECOND_TOWER := ORIGIN + Vector2i(5, 3)


func _setup_city() -> Dictionary:
	## An 8x5 ring with a 6x3 interior, cleared for two wooden towers.
	var scene = mount_seeded_tree_world(42, 0.0)
	var world = scene.get_node("World/worldMap")
	var ring: Array[Vector2i] = []
	for y in 5:
		for x in 8:
			var cell := ORIGIN + Vector2i(x, y)
			world.cut_grown(cell)
			if not world.pick_decor(cell):
				world.destroy_decor(cell)
			if x in [0, 7] or y in [0, 4]:
				ring.append(cell)
	var tower := StructurePlacer.load_named("tower_wood")
	var id: int = world.place_structure(tower, FIRST_TOWER, 1)
	if id <= 0 or not world.place_wall_cells(ring):
		printerr("FAIL land_score: could not build the fixture (tower id %d)" % id)
		scene.queue_free()
		return {}
	return {
		"scene": scene,
		"world": world,
		"id": id,
		"land": scene.get_node("World/LandScore"),
		"points": scene.get_node("Points")
	}


func _test_land_score_range() -> int:
	## #279: one flag covers 3+4+3 interior cells. Both flags cover all 18,
	## with the overlap scored once. Breaking the ring removes the score.
	print("-- test_land_score_range")
	var t := _setup_city()
	if t.is_empty():
		return 1
	var old_range := LandScore.range_cells
	var old_enabled := LandScore.enabled
	LandScore.range_cells = 2
	LandScore.enabled = true
	var land: LandScore = t["land"]
	var points: Points = t["points"]
	var board: ScoreboardPanel = t["scene"].get_node("CanvasLayer1/ScoreboardPanel")
	var requests: StructureRequests = t["scene"].get_node("World/StructureRequests")
	board.bind(points, 1)
	var fail := 0
	if land.select_cell(FIRST_TOWER + Vector2i.UP) != t["id"] or land.ring_radius_px() != 32.0:
		printerr("FAIL land_score_range: could not select the flag's 32 px ring")
		fail += 1
	for expected: int in [10, 18, 0]:
		if (
			expected == 18
			and (
				t["world"].place_structure(
					StructurePlacer.load_named("tower_wood"), SECOND_TOWER, 1
				)
				<= 0
			)
		):
			printerr("FAIL land_score_range: could not place the second tower")
			fail += 1
		if expected == 0 and not requests.host_erase_wall(ORIGIN + Vector2i.RIGHT):
			printerr("FAIL land_score_range: could not open the ring")
			fail += 1
		land.tick()
		var rows := board.sorted_rows()
		if (
			points.total_of(1) != expected
			or not rows.any(func(row): return row[0] == 1 and row[1] == expected)
		):
			printerr(
				(
					"FAIL land_score_range: expected %d points, got %d and scoreboard %s"
					% [expected, points.total_of(1), rows]
				)
			)
			fail += 1
		if expected == 0 and t["scene"].get_node("World/Cities").cities.has(t["id"]):
			printerr("FAIL land_score_range: city survived an open ring")
			fail += 1
	t["scene"].queue_free()
	LandScore.range_cells = old_range
	LandScore.enabled = old_enabled
	return fail


func _test_land_score_client_skips() -> int:
	## A connecting client awards no points for the same closed city that
	## scores 10 points offline.
	print("-- test_land_score_client_skips")
	var t := _setup_city()
	if t.is_empty():
		return 1
	var old_range := LandScore.range_cells
	var old_enabled := LandScore.enabled
	LandScore.range_cells = 2
	LandScore.enabled = true
	var path: NodePath = t["land"].get_path()
	var api := SceneMultiplayer.new()
	set_multiplayer(api, path)
	var peer := ENetMultiplayerPeer.new()
	peer.create_client("127.0.0.1", _free_udp_port())
	api.multiplayer_peer = peer
	t["land"].tick()
	var client_total: int = t["points"].total_of(1)
	peer.close()
	set_multiplayer(null, path)
	t["land"].tick()
	var offline_total: int = t["points"].total_of(1)
	t["scene"].queue_free()
	LandScore.range_cells = old_range
	LandScore.enabled = old_enabled
	if client_total != 0 or offline_total != 10:
		printerr(
			(
				"FAIL land_score_client_skips: client scored %d and offline scored %d"
				% [client_total, offline_total]
			)
		)
		return 1
	return 0
