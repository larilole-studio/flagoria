extends "res://tests/helpers/test_helpers.gd"
## Barracks soldier training, follow/hold, save, and tower exclusion (#553).

const SEED := 7


func _barracks_anchor(world, quarter_turns := 0) -> Variant:
	var s: Structure = StructurePlacer.load_named("barracks")
	if s == null:
		return null
	s = Structure.rotated(s, quarter_turns)
	for seed_value in [SEED, 11, 42, 99]:
		world.apply_map_params(_spawn_params(seed_value, 0.0))
		world.generate_chunk(Vector2(0, 0))
		for cell: Vector2i in world.get_used_cells(0):
			var cells: Array = StructurePlacer.footprint(s, cell).keys()
			if cells.is_empty():
				continue
			if cells.all(func(c): return world.get_cell_source_id(0, c) != -1 and world.predicted_clear(c)):
				return cell
	return null


func _place_barracks(scene, world, peer: int) -> Variant:
	var anchor: Variant = _barracks_anchor(world)
	if anchor == null:
		return null
	var inventory: Inventory = scene.get_node("Inventory")
	inventory.add(Inventory.WOOD, 30)
	var placer := ConstructionPlacer.new(world)
	if not placer.place(BuildCosts.BARRACKS, [anchor], inventory):
		return null
	var body: Node2D = scene.get_node("World/" + str(peer))
	var interaction: Interaction = scene.get_node("World/Interaction")
	body.global_position = world.map_to_local(anchor) + Vector2(0, 48)
	for _i in 4:
		await process_frame
	if not interaction.in_reach(anchor):
		for off: Vector2i in [Vector2i(0, 5), Vector2i(3, 0), Vector2i(-3, 0)]:
			body.global_position = world.map_to_local(anchor + off) + Vector2(32, 32)
			await process_frame
			if interaction.in_reach(anchor):
				break
	return anchor


func _test_soldier_train() -> int:
	print("-- test_soldier_train")
	var fail := 0
	var scene = load("res://flagoria_main.tscn").instantiate()
	root.add_child(scene)
	scene.world_params = _spawn_params(SEED, 0.0)
	var world = scene.get_node("World/worldMap")
	world.apply_map_params(scene.world_params)
	world.generate_chunk(Vector2(0, 0))
	var peer: int = scene.multiplayer.get_unique_id()
	var body: Node2D = scene.get_node_or_null("World/" + str(peer))
	if body == null:
		body = CharacterBody2D.new()
		body.name = str(peer)
		scene.get_node("World").add_child(body)
	var requests: SoldierRequests = scene.get_node("World/Soldiers")
	var anchor: Variant = await _place_barracks(scene, world, peer)
	if anchor == null:
		printerr("FAIL soldier_train: no barracks")
		scene.queue_free()
		return 1
	var inventory: Inventory = scene.get_node("Inventory")
	inventory.add(Inventory.WOOD, 7)
	if requests.host_train(peer, anchor) or requests.soldiers().size() > 0:
		printerr("FAIL soldier_train: short wood accepted")
		fail += 1
	inventory.add(Inventory.WOOD, 1)
	if not requests.host_train(peer, anchor):
		printerr("FAIL soldier_train: train refused with 8 wood")
		fail += 1
	requests.advance(SoldierStats.TRAIN_TIME)
	await process_frame
	var troops := requests.soldiers()
	if troops.size() != 1 or str(troops[0].name) != "soldier_%d_0" % peer \
			or troops[0].owner_peer != peer or troops[0].order != "follow":
		printerr("FAIL soldier_train: spawn %s" % troops)
		fail += 1
	if inventory.count_of(Inventory.WOOD) != 0:
		printerr("FAIL soldier_train: wood %d" % inventory.count_of(Inventory.WOOD))
		fail += 1
	body.global_position = world.map_to_local(anchor) + Vector2(512, 0)
	if requests.host_train(peer, anchor):
		printerr("FAIL soldier_train: far train accepted")
		fail += 1
	var soldier: Soldier = troops[0]
	var spawn_pos := soldier.global_position
	body.global_position = spawn_pos + Vector2(40, 0)
	for _i in 20:
		soldier.think(0.1)
	var d_after_follow := soldier.global_position.distance_to(body.global_position)
	var start_follow_d := 40.0
	requests.host_set_order(peer)
	for _i in 10:
		var before := soldier.global_position
		soldier.think(0.1)
		body.global_position += Vector2(8, 0)
		if soldier.global_position.distance_to(before) > 1.0:
			printerr("FAIL soldier_train: hold moved")
			fail += 1
			break
	if d_after_follow > SoldierStats.FOLLOW_STOP + 12.0:
		printerr("FAIL soldier_train: follow distance %s from %s" % [d_after_follow, start_follow_d])
		fail += 1
	for i in 3:
		if not requests.host_train(peer, anchor):
			break
		requests.advance(SoldierStats.TRAIN_TIME)
	if requests.host_train(peer, anchor):
		printerr("FAIL soldier_train: fifth train at cap")
		fail += 1
	scene.spawn_mobs()
	scene.get_node("World/Mobs").clear_mobs()
	if not scene.get_node("World/Soldiers").get_node_or_null("soldier_%d_0" % peer):
		printerr("FAIL soldier_train: clear_mobs removed soldier")
		fail += 1
	var capture: TowerCapture = scene.get_node("World/TowerCapture")
	var centre: Vector2 = world.map_to_local(anchor as Vector2i)
	var sides := capture.sides_near(centre)
	if sides.has(StructurePlacer.OWNER_MOBS):
		printerr("FAIL soldier_train: soldier counted as mob capturer")
		fail += 1
	var ws := WorldSave.new(scene.world_params)
	ws.structures = StructureSaves.to_changes(world)
	ws.soldiers = SoldierSaves.capture(scene)
	var row: Dictionary = ws.soldiers[0] if ws.soldiers.size() > 0 else {}
	var saved := MapSave.save_world(ws, "test_soldier_save_%d" % OS.get_process_id())
	if saved["error"] != "":
		printerr("FAIL soldier_train: save %s" % saved["error"])
		fail += 1
	else:
		var loaded := MapSave.load_world(saved["path"])
		if loaded["error"] != "":
			printerr("FAIL soldier_train: load %s" % loaded["error"])
			fail += 1
		elif loaded["world"].soldiers.size() != ws.soldiers.size() \
				or str(loaded["world"].soldiers[0].get("name")) != str(ws.soldiers[0].get("name")):
			printerr("FAIL soldier_train: soldiers round trip %s vs %s" % [ws.soldiers, loaded["world"].soldiers])
			fail += 1
		DirAccess.remove_absolute(saved["path"])
	for child in requests.get_children():
		if child is Soldier:
			child.queue_free()
	await process_frame
	var restored: Soldier = load(Soldier.SOLDIER_SCENE).instantiate()
	restored.name = str(row.get("name", "soldier_restore"))
	requests.add_child(restored)
	restored.setup_from_save(row)
	if requests.get_node_or_null(str(row.get("name", ""))) == null:
		printerr("FAIL soldier_train: restore spawn")
		fail += 1
	scene.queue_free()
	await process_frame
	if fail == 0:
		print("PASS test_soldier_train")
	return fail