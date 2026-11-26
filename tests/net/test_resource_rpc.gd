extends "res://tests/helpers/test_helpers.gd"
## Targeted resource RPCs on two real ENet peers.


func _test_resource_rpc_isolation() -> int:
	print("-- test_resource_rpc_isolation")
	var port := _free_udp_port()
	var server_peer := ENetMultiplayerPeer.new()
	var client_peer := ENetMultiplayerPeer.new()
	if (
		port == 0
		or server_peer.create_server(port, 1) != OK
		or client_peer.create_client("127.0.0.1", port) != OK
	):
		printerr("FAIL resource_rpc_isolation: could not start peers")
		return 1

	var host := mount_main_scene()
	host.name = "ResourceHost"
	var joiner := mount_main_scene()
	var server := SceneMultiplayer.new()
	var client := SceneMultiplayer.new()
	set_multiplayer(server, host.get_path())
	set_multiplayer(client, joiner.get_path())
	server.multiplayer_peer = server_peer
	client.multiplayer_peer = client_peer

	var ok := false
	if await _client_connected(server, client_peer):
		ok = await _check_resource_rpcs(host, joiner, client.get_unique_id())
	else:
		printerr("FAIL resource_rpc_isolation: joiner did not connect")

	server_peer.close()
	client_peer.close()
	set_multiplayer(null, joiner.get_path())
	set_multiplayer(null, host.get_path())
	joiner.queue_free()
	host.queue_free()
	await process_frame
	if ok:
		print("PASS test_resource_rpc_isolation")
	return 0 if ok else 1


func _check_resource_rpcs(host: Node, joiner: Node, peer: int) -> bool:
	var host_inventory := host.get_node("Inventory") as Inventory
	var join_inventory := joiner.get_node("Inventory") as Inventory
	var interaction := host.get_node("World/Interaction") as Interaction
	var changes: Array = []
	join_inventory.changed.connect(
		func(resource: StringName, count: int) -> void: changes.append([resource, count])
	)
	host_inventory.add(Inventory.WOOD, 9)
	host_inventory.add(Inventory.STONE, 8)
	host_inventory.spend(Inventory.STONE, 1)
	interaction.receive_yields.rpc_id(peer, Vector2i.ZERO, {Inventory.WOOD: 4, Inventory.STONE: 5})
	interaction.receive_charge.rpc_id(peer, 0, 2)
	interaction.receive_charge.rpc_id(peer, 1)

	var deadline := Time.get_ticks_msec() + 3000
	while changes.size() < 4 and Time.get_ticks_msec() < deadline:
		await process_frame
	var ok := (
		(
			changes
			== [
				[Inventory.WOOD, 4], [Inventory.STONE, 5], [Inventory.STONE, 3], [Inventory.WOOD, 3]
			]
		)
		and host_inventory.count_of(Inventory.WOOD) == 9
		and host_inventory.count_of(Inventory.STONE) == 7
	)
	if not ok:
		printerr(
			(
				"FAIL resource_rpc_isolation: joiner changes %s, host wood %s stone %s"
				% [
					changes,
					host_inventory.count_of(Inventory.WOOD),
					host_inventory.count_of(Inventory.STONE)
				]
			)
		)
	return ok
