extends "res://tests/helpers/test_helpers.gd"

const WorldChunks := preload("res://Scripts/world/world_chunks.gd")
const JOINER_SITE := Vector2i(20, -56)
const HOST_SITE := Vector2i(24, -50)


func _test_mine_production_sync() -> int:
	var port := _free_udp_port()
	var server_peer := ENetMultiplayerPeer.new()
	var client_peer := ENetMultiplayerPeer.new()
	if (
		port == 0
		or server_peer.create_server(port, 1) != OK
		or client_peer.create_client("127.0.0.1", port) != OK
	):
		printerr("FAIL mine production: could not start peers")
		return 1

	var host := mount_main_scene()
	host.name = "MineProductionHost"
	var joiner := mount_main_scene()
	var server := SceneMultiplayer.new()
	var client := SceneMultiplayer.new()
	set_multiplayer(server, host.get_path())
	set_multiplayer(client, joiner.get_path())
	server.multiplayer_peer = server_peer
	client.multiplayer_peer = client_peer

	var ok := false
	if await _client_connected(server, client_peer):
		ok = await _check_owner_delivery(host, joiner, client.get_unique_id(), server, client_peer)
	client_peer.close()
	server_peer.close()
	set_multiplayer(null, joiner.get_path())
	set_multiplayer(null, host.get_path())
	joiner.queue_free()
	host.queue_free()
	await process_frame
	if not ok:
		printerr("FAIL mine production: authority, owner delivery or disconnect")
	return 0 if ok else 1


func _check_owner_delivery(
	host: Node,
	joiner: Node,
	joiner_id: int,
	server: SceneMultiplayer,
	client_peer: ENetMultiplayerPeer
) -> bool:
	var host_requests: StructureRequests = host.get_node("World/StructureRequests")
	var joiner_requests: StructureRequests = joiner.get_node("World/StructureRequests")
	var host_map := host_requests.map
	var joiner_map := joiner_requests.map
	var params := _spawn_params(11, 0.003)
	for map in [host_map, joiner_map]:
		map.set_process(false)
		map.apply_map_params(params)

	var host_inventory := host_requests.inventory
	var joiner_inventory := joiner_requests.inventory
	host_inventory.add(Inventory.WOOD, 15)
	joiner_inventory.add(Inventory.WOOD, 15)
	_add_body(host_requests, 1, HOST_SITE)
	_add_body(host_requests, joiner_id, JOINER_SITE)
	if not host_requests.host_place(BuildCosts.MINE, [JOINER_SITE], joiner_id):
		return false
	WorldChunks.refresh(host_map, 30.0)
	if (
		not host_requests.host_place(BuildCosts.MINE, [HOST_SITE], 1)
		or not await wait_until(
			func() -> bool: return not joiner_map.structure_placement_at(HOST_SITE).is_empty(), 5000
		)
	):
		return false

	WorldChunks.refresh(joiner_map, 120.0)
	var client_stone := joiner_inventory.count_of(Inventory.STONE)
	WorldChunks.refresh(host_map, 30.0)
	if (
		client_stone != 0
		or not await wait_until(
			func() -> bool: return joiner_inventory.count_of(Inventory.STONE) == 1, 5000
		)
		or host_inventory.count_of(Inventory.STONE) != 0
	):
		return false
	WorldChunks.refresh(host_map, 30.0)
	if host_inventory.count_of(Inventory.STONE) != 1:
		return false

	client_peer.disconnect_peer(1)
	if not await wait_until(func() -> bool: return server.get_peers().is_empty(), 5000):
		return false
	WorldChunks.refresh(host_map, 30.0)
	return (
		host_inventory.count_of(Inventory.STONE) == 1
		and joiner_inventory.count_of(Inventory.STONE) == 1
	)


func _add_body(requests: StructureRequests, peer: int, site: Vector2i) -> void:
	var body := Node2D.new()
	body.name = str(peer)
	requests.world.add_child(body)
	body.global_position = requests.interaction.cell_center(site)
