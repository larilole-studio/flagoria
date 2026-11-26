extends "res://tests/helpers/test_helpers.gd"

const _WorldMap := preload("res://Scripts/world/TileMap.gd")
const _SHORE := Vector2i(-29, -28)
const _TOWER := Vector2i(-34, -35)
const _BLOCKED_TOWER := Vector2i(-32, -35)
const _WALL_SUPPORT := Vector2i(-20, -28)
const _NAMED := [
	[&"tower", "tower_wood", _TOWER, 1, 10, Vector2i(2, -1), 0],
	[&"castle", "castle", Vector2i(23, -30), 1, 35, Vector2i(4, -3), 15],
	[&"guard_post", "guard_post", Vector2i(16, -33), 2, 14, Vector2i(2, 3), 6],
	[&"barracks", "barracks", Vector2i(-3, -34), 3, 20, Vector2i(-3, 2), 10],
]
const _SPEND_FAIL := preload("res://tests/mechanics/building/spend_fail_inventory.gd")


func _test_building_seam_placement() -> int:
	# #273, #493, #527, #528, #556: cost, owner and a rotated footprint edge.
	var test_name := "test_building_seam_placement"
	print("-- ", test_name)
	var scene := mount_seeded_tree_world(11, 0.0)
	var world := scene.get_node("World/worldMap") as _WorldMap
	var inventory := scene.get_node("Inventory") as Inventory
	var placer := ConstructionPlacer.new(world)
	var fail := 0
	inventory.add(Inventory.WOOD, 60)
	fail += await _actor_refusals(scene, world, placer, inventory)
	inventory.spend(Inventory.WOOD, 50)
	fail += _refused(placer, world, inventory, &"tower", [_BLOCKED_TOWER], 1, "occupied")
	inventory.spend(Inventory.WOOD, 10)
	for row in _NAMED:
		var kind: StringName = row[0]
		var cell: Vector2i = row[2]
		var turns: int = row[3]
		var price: int = row[4]
		var stone: int = row[6]
		inventory.add(Inventory.WOOD, price - 1)
		if stone > 0:
			fail += _refused(
				placer, world, inventory, kind, [cell], turns, "not enough wood and stone"
			)
			inventory.add(Inventory.STONE, stone)
		fail += _refused(placer, world, inventory, kind, [cell], turns, "not enough wood")
		if placer.cost(kind, [cell]) != price:
			printerr("FAIL %s: expected quoted cost %d" % [kind, price])
			fail += 1
		inventory.add(Inventory.WOOD, 1)
		if stone > 0:
			inventory.spend(Inventory.STONE, 1)
			fail += _refused(placer, world, inventory, kind, [cell], turns, "not enough stone")
			inventory.add(Inventory.STONE, 1)
		if (
			not placer.place(kind, [cell], inventory, turns)
			or BuildCosts.balance(inventory) != Vector2i.ZERO
			or not world.structures_for_sync().has([row[1], 1, cell, turns])
		):
			printerr("FAIL %s: placement, charge or sync row at %s" % [kind, cell])
			fail += 1
		inventory.add(Inventory.WOOD, price)
		inventory.add(Inventory.STONE, stone)
		if row[1] != "barracks":
			var flag_offset: Vector2i = {
				&"tower": Vector2i.RIGHT, &"castle": Vector2i(2, 0), &"guard_post": Vector2i.DOWN
			}[kind]
			if world.predict_cell(cell + flag_offset)[1] != Vector2i(2, 7):
				printerr("FAIL %s: missing owner flag at %s" % [kind, cell + flag_offset])
				fail += 1
		fail += _refused(placer, world, inventory, kind, [cell], turns, "occupied")
		fail += _refused(placer, world, inventory, &"wall_block", [cell + row[5]], 0, "occupied")
		inventory.spend(Inventory.WOOD, price)
		inventory.spend(Inventory.STONE, stone)
	inventory.add(Inventory.WOOD, 50)
	for row in _NAMED:
		fail += _refused(placer, world, inventory, row[0], [_SHORE], row[3], "wrong ground")
	# A clear tower footprint straddles the configured world boundary.
	world.archipelago_spacing = 128
	world.archipelago_world_extent = 35
	fail += _refused(placer, world, inventory, &"tower", [Vector2i(3, -35)], 1, "wrong ground")
	scene.queue_free()
	await process_frame
	if fail == 0:
		print("PASS ", test_name)
	return fail


func _test_building_seam_runs() -> int:
	# #276 and #297: support, straightness, occupancy and per-cell charge.
	var test_name := "test_building_seam_runs"
	print("-- ", test_name)
	var scene := mount_seeded_tree_world(11, 0.0)
	var world := scene.get_node("World/worldMap") as _WorldMap
	var inventory := scene.get_node("Inventory") as Inventory
	var placer := ConstructionPlacer.new(world)
	var planks: Array[Vector2i] = [_SHORE, _SHORE + Vector2i.LEFT]
	var walls: Array[Vector2i] = [
		_WALL_SUPPORT + Vector2i.RIGHT,
		_WALL_SUPPORT + 2 * Vector2i.RIGHT,
		_WALL_SUPPORT + 3 * Vector2i.RIGHT
	]
	var bent_planks: Array[Vector2i] = [planks[0], planks[1], _SHORE + Vector2i.UP]
	var bent_walls: Array[Vector2i] = [walls[0], walls[1], walls[1] + Vector2i.DOWN]
	var fail := 0
	inventory.add(Inventory.WOOD, 1)
	fail += _refused(placer, world, inventory, &"plank", planks, 0, "not enough wood")
	inventory.add(Inventory.WOOD, 19)
	fail += _refused(placer, world, inventory, &"plank", [_WALL_SUPPORT], 0, "wrong ground")
	fail += _refused(
		placer, world, inventory, &"plank", [_SHORE + 3 * Vector2i.LEFT], 0, "not adjacent"
	)
	fail += _refused(placer, world, inventory, &"plank", bent_planks, 0, "not straight")
	fail += _refused(placer, world, inventory, &"wall_block", walls, 0, "not adjacent")
	if not world.place_wall_cells([_WALL_SUPPORT]):
		printerr("FAIL building seam: could not seed wall support")
		scene.queue_free()
		return fail + 1
	fail += _refused(placer, world, inventory, &"wall_block", [_SHORE], 0, "wrong ground")
	fail += _refused(placer, world, inventory, &"wall_block", bent_walls, 0, "not straight")
	for row in [
		[&"plank", planks, 18, world.has_bridge], [&"wall_block", walls, 12, world.has_wall]
	]:
		var cells: Array[Vector2i] = row[1]
		if (
			not placer.place(row[0], cells, inventory)
			or not cells.all(row[3])
			or inventory.count_of(Inventory.WOOD) != row[2]
		):
			printerr("FAIL %s: run was not written or charged at %s" % [row[0], cells])
			fail += 1
		fail += _refused(placer, world, inventory, row[0], [cells[0]], 0, "occupied")
	var mid := walls[1]
	world.generate_chunk(Vector2(-1, -1))
	if world.predict_cell(mid)[1] != Vector2i(5, 15):
		printerr("FAIL building seam: wall midpiece missing after redraw at %s" % mid)
		fail += 1
	scene.queue_free()
	await process_frame
	if fail == 0:
		print("PASS ", test_name)
	return fail


func _test_building_seam_refund() -> int:
	# #380 item 3: failed charges write nothing; writer refusals refund in full.
	var test_name := "test_building_seam_refund"
	print("-- ", test_name)
	var scene := mount_seeded_tree_world(11, 0.0)
	var world := scene.get_node("World/worldMap") as _WorldMap
	var inventory := scene.get_node("Inventory") as Inventory
	var stub: Inventory = _SPEND_FAIL.new()
	scene.add_child(stub)
	var placer := ConstructionPlacer.new(world)
	var wall := _WALL_SUPPORT + Vector2i.RIGHT
	var fail := 0
	if not world.place_wall_cells([_WALL_SUPPORT]):
		printerr("FAIL building seam: could not seed rollback wall support")
		scene.queue_free()
		return 1
	stub.add(Inventory.WOOD, 10)
	for row in [[&"plank", _SHORE], [&"wall_block", wall], [&"tower", _TOWER]]:
		if (
			placer.place(row[0], [row[1]], stub, 1)
			or stub.count_of(Inventory.WOOD) != 10
			or world.has_bridge(_SHORE)
			or world.has_wall(wall)
			or not world.placed_structures().is_empty()
		):
			printerr("FAIL %s: failed charge changed the world or wood" % row[0])
			fail += 1
	inventory.add(Inventory.WOOD, 13)
	var charged: Array[int] = []
	inventory.changed.connect(func(_resource: StringName, wood: int) -> void: charged.append(wood))
	if (
		placer.place_for_peer(&"tower", [_BLOCKED_TOWER], 1, inventory, 1)
		or charged != [3, 13]
		or inventory.count_of(Inventory.WOOD) != 13
		or not world.placed_structures().is_empty()
	):
		printerr(
			"FAIL building seam: refused tower should refund 10 wood, balances were %s" % [charged]
		)
		fail += 1
	scene.queue_free()
	await process_frame
	if fail == 0:
		print("PASS ", test_name)
	return fail


func _test_building_seam_connecting() -> int:
	# #297, #497, #498: a connecting client can preview named builds and walls,
	# but cannot submit them. The local plank transaction has no network gate.
	print("-- test_building_seam_connecting")
	var scene := mount_seeded_tree_world(11, 0.0)
	var world := scene.get_node("World/worldMap") as _WorldMap
	var inventory := scene.get_node("Inventory") as Inventory
	var placer := ConstructionPlacer.new(world)
	var peer := ENetMultiplayerPeer.new()
	if peer.create_client("127.0.0.1", 1) != OK or not world.place_wall_cells([_WALL_SUPPORT]):
		printerr("FAIL building seam: could not set up connecting client")
		peer.close()
		scene.queue_free()
		return 1
	var api := SceneMultiplayer.new()
	api.multiplayer_peer = peer
	set_multiplayer(api, scene.get_path())
	inventory.add(Inventory.WOOD, 10)
	var fail := 0
	var wall := _WALL_SUPPORT + Vector2i.RIGHT
	for row in [[&"tower", _TOWER, 1], [&"wall_block", wall, 0]]:
		var cells: Array[Vector2i] = [row[1]]
		if (
			not placer.can_place(row[0], cells, inventory, row[2]).is_empty()
			or placer.place(row[0], cells, inventory, row[2])
		):
			printerr(
				"FAIL %s: connecting client had a blocked preview or submitted a build" % row[0]
			)
			fail += 1
	if (
		inventory.count_of(Inventory.WOOD) != 10
		or world.has_wall(wall)
		or not world.placed_structures().is_empty()
	):
		printerr("FAIL building seam: connecting client wrote or spent on an unsubmitted build")
		fail += 1
	if (
		not placer.place(&"plank", [_SHORE], inventory)
		or not world.has_bridge(_SHORE)
		or inventory.count_of(Inventory.WOOD) != 9
	):
		printerr("FAIL building seam: local plank transaction failed while connecting")
		fail += 1
	api.multiplayer_peer = null
	peer.close()
	set_multiplayer(null, scene.get_path())
	scene.queue_free()
	await process_frame
	if fail == 0:
		print("PASS test_building_seam_connecting")
	return fail


func _actor_refusals(
	scene: Node, world: _WorldMap, placer: ConstructionPlacer, inventory: Inventory
) -> int:
	var wall := _WALL_SUPPORT + Vector2i.RIGHT
	if not world.place_wall_cells([_WALL_SUPPORT]):
		printerr("FAIL building seam: could not seed actor wall support")
		return 1
	var player := add_combat_actor(scene, Vector2.ZERO)
	var mob := preload("res://Mobs/mob.tscn").instantiate() as Mob
	mob.setup(MobCatalog.SLIME, Vector2.ZERO, 1)
	scene.get_node("World/Mobs").add_child(mob)
	var fail := 0
	for row in [
		[&"tower", _TOWER, 1], [&"guard_post", Vector2i(16, -33), 2], [&"wall_block", wall, 0]
	]:
		var cell: Vector2i = row[1]
		var pos := world.to_global(world.map_to_local(cell))
		player.global_position = pos
		mob.global_position = Vector2.ZERO
		fail += _refused(placer, world, inventory, row[0], [cell], row[2], "occupied")
		player.global_position = Vector2.ZERO
		mob.global_position = pos
		fail += _refused(placer, world, inventory, row[0], [cell], row[2], "occupied")
	player.queue_free()
	mob.queue_free()
	await process_frame
	return fail


func _refused(
	placer: ConstructionPlacer,
	world: _WorldMap,
	inventory: Inventory,
	kind: StringName,
	cells: Array[Vector2i],
	turns: int,
	reason: String
) -> int:
	var before := [
		BuildCosts.balance(inventory),
		world.structures_for_sync(),
		world.bridges_for_sync(),
		cells.map(world.has_wall)
	]
	var reasons := placer.can_place(kind, cells, inventory, turns)
	var placed := placer.place(kind, cells, inventory, turns)
	var after := [
		BuildCosts.balance(inventory),
		world.structures_for_sync(),
		world.bridges_for_sync(),
		cells.map(world.has_wall)
	]
	if reason in reasons and not placed and after == before:
		return 0
	printerr(
		(
			"FAIL %s at %s: expected %s and no changes, got %s, placed=%s"
			% [kind, cells, reason, reasons, placed]
		)
	)
	return 1
