extends "res://tests/helpers/test_helpers.gd"
## Two real ENet peers share depletion and receive only their own stone.


func _test_hand_mine_sync() -> int:
	print("-- test_hand_mine_sync")
	var port := _free_udp_port()
	var server_peer := ENetMultiplayerPeer.new()
	var client_peer := ENetMultiplayerPeer.new()
	if (
		port == 0
		or server_peer.create_server(port, 1) != OK
		or client_peer.create_client("127.0.0.1", port) != OK
	):
		return 1
	var host := mount_main_scene()
	host.get_node("World/Interaction").set_process(false)
	var joiner := mount_main_scene()
	joiner.get_node("World/Interaction").set_process(false)
	var server := SceneMultiplayer.new()
	var client := SceneMultiplayer.new()
	set_multiplayer(server, host.get_path())
	set_multiplayer(client, joiner.get_path())
	server.multiplayer_peer = server_peer
	client.multiplayer_peer = client_peer
	var ok := false
	if await _client_connected(server, client_peer):
		ok = await _mine_with_peers(host, joiner, client.get_unique_id())
	server_peer.close()
	client_peer.close()
	set_multiplayer(null, joiner.get_path())
	set_multiplayer(null, host.get_path())
	joiner.queue_free()
	host.queue_free()
	await process_frame
	if ok:
		print("PASS test_hand_mine_sync")
	return 0 if ok else 1


func _mine_with_peers(host: Node, joiner: Node, peer: int) -> bool:
	var maps: Array[TileMap] = [host.get_node("World/worldMap"), joiner.get_node("World/worldMap")]
	var host_it := host.get_node("World/Interaction") as Interaction
	var join_it := joiner.get_node("World/Interaction") as Interaction
	var host_inventory := host.get_node("Inventory") as Inventory
	var join_inventory := joiner.get_node("Inventory") as Inventory
	var rocks: Array[Vector2i] = [Vector2i(2, 2), Vector2i(3, 2), Vector2i(4, 2), Vector2i(30, 2)]
	for map in maps:
		map.set_process(false)
		generate_seeded_chunk(map, 7, 1.0)
		for cell in rocks:
			map.generate_chunk(map.map_to_local(cell))
			map.set_cell(0, cell, TileCatalog.SOURCE_ID, TileCatalog.GRASS_A)
			map.erase_cell(1, cell)
			map.set_cell(map.GROUND_DECOR_LAYER, cell, TileCatalog.SOURCE_ID, TileCatalog.STONES)

	var host_actor := _mining_actor(host_it, "1")
	var remote_actor := _mining_actor(host_it, str(peer))
	var join_actor := _mining_actor(join_it, str(peer))
	host_it.bind(host_actor)
	join_it.bind(join_actor)
	host_actor.global_position = host_it.cell_center(rocks[0])
	if not host_it.start_chop(rocks[0]):
		printerr("FAIL mine_sync: host could not start mining a rock in reach")
		return false
	host_it.step_chop(0.65)
	if not await _mine_wait(func() -> bool: return not _has_rock(maps[1], rocks[0])):
		printerr("FAIL mine_sync: host depletion did not reach joiner")
		return false
	if (
		host_inventory.count_of(Inventory.STONE) != 2
		or join_inventory.count_of(Inventory.STONE) != 0
	):
		printerr("FAIL mine_sync: host depletion awarded the wrong inventory")
		return false

	remote_actor.global_position = host_it.cell_center(rocks[1])
	join_actor.global_position = join_it.cell_center(rocks[1])
	# The valid mining requests follow both invalid hits on the same reliable channel.
	var far := rocks[3]
	maps[1].request_mine_hit.rpc_id(1, far)
	maps[1].request_mine_hit.rpc_id(1, far)
	if not join_it.start_chop(rocks[1]):
		return false
	join_it.step_chop(0.65)
	if (
		not await _mine_wait(func() -> bool: return join_inventory.count_of(Inventory.STONE) == 2)
		or _has_rock(maps[0], rocks[1])
		or _has_rock(maps[1], rocks[1])
	):
		printerr("FAIL mine_sync: joiner award or depletion did not reach both peers")
		return false

	return await _race_rock(
		host_it, join_it, remote_actor, host_inventory, join_inventory, maps, rocks
	)


func _race_rock(
	host_it: Interaction,
	join_it: Interaction,
	remote_actor: Node2D,
	host_inventory: Inventory,
	join_inventory: Inventory,
	maps: Array[TileMap],
	rocks: Array[Vector2i]
) -> bool:
	var shared := rocks[2]
	var far := rocks[3]
	host_it.player.global_position = host_it.cell_center(shared)
	remote_actor.global_position = host_it.cell_center(shared)
	join_it.player.global_position = join_it.cell_center(shared)
	if not host_it.start_chop(shared) or not join_it.start_chop(shared):
		return false
	host_it.step_chop(0.15)
	join_it.step_chop(0.15)
	host_it.step_chop(0.5)
	if not await _mine_wait(func() -> bool: return not _has_rock(maps[1], shared)):
		return false
	var ok := (
		not _has_rock(maps[0], shared)
		and _has_rock(maps[0], far)
		and _has_rock(maps[1], far)
		and host_inventory.count_of(Inventory.STONE) == 4
		and join_inventory.count_of(Inventory.STONE) == 2
	)
	if not ok:
		printerr("FAIL mine_sync: contested depletion or out-of-reach hit credited incorrectly")
	return ok


func _mining_actor(interaction: Interaction, peer_name: String) -> Node2D:
	var actor := Node2D.new()
	actor.name = peer_name
	interaction.get_parent().add_child(actor)
	interaction.mode = Interaction.Mode.INTERACT
	return actor


func _has_rock(map: TileMap, cell: Vector2i) -> bool:
	return map.get_cell_atlas_coords(map.GROUND_DECOR_LAYER, cell) == TileCatalog.STONES


func _mine_wait(predicate: Callable) -> bool:
	var deadline := Time.get_ticks_msec() + 3000
	while not predicate.call() and Time.get_ticks_msec() < deadline:
		await process_frame
	return predicate.call()
