extends "res://tests/helpers/test_helpers.gd"

const HOST_SITE := Vector2i(24, -50)
const JOINER_SITE := Vector2i(20, -56)


func _test_mine_cart_late_join() -> int:
	var port := _free_udp_port()
	if port == 0:
		return 1
	var host := mount_main_scene()
	# The in-game HUD binds to the main scene at /root/Flagoria.
	host.name = "MineCartHost"
	var joiner := mount_main_scene()
	joiner.name = "MineCartJoiner"
	host.name = "Flagoria"
	var server := SceneMultiplayer.new()
	var client := SceneMultiplayer.new()
	set_multiplayer(server, host.get_path())
	set_multiplayer(client, joiner.get_path())

	var client_peer := ENetMultiplayerPeer.new()
	var ok: bool = (
		host.setup_server(_spawn_params(11, 0.003), port, false) == OK
		and await _check_late_join(host, joiner, server, client, client_peer, port)
	)
	var joiner_path := joiner.get_path()
	var host_path := host.get_path()
	joiner.process_mode = Node.PROCESS_MODE_DISABLED
	if not server.get_peers().is_empty():
		client_peer.disconnect_peer(1)
		await wait_until(func() -> bool: return server.get_peers().is_empty(), 5000)
	joiner.queue_free()
	host.queue_free()
	await process_frame
	client_peer.close()
	if server.multiplayer_peer != null:
		server.multiplayer_peer.close()
	set_multiplayer(null, joiner_path)
	set_multiplayer(null, host_path)
	if not ok:
		printerr("FAIL mine cart: late join did not preserve producing and idle presentation")
	return 0 if ok else 1


func _check_late_join(
	host: Node,
	joiner: Node,
	server: SceneMultiplayer,
	client: SceneMultiplayer,
	client_peer: ENetMultiplayerPeer,
	port: int
) -> bool:
	var host_map: TileMap = host.get_node("World/worldMap")
	var joiner_map: TileMap = joiner.get_node("World/worldMap")
	var placer := ConstructionPlacer.new(host_map)
	# Queue the connection before polling either peer so all mines predate the join.
	if (
		client_peer.create_client("127.0.0.1", port) != OK
		or not placer.place_for_peer(BuildCosts.MINE, [HOST_SITE], 1, null)
		or not placer.place_for_peer(
			BuildCosts.MINE, [JOINER_SITE], client_peer.get_unique_id(), null
		)
	):
		printerr("mine cart: could not prepare the world and connecting peer")
		return false
	var idle_site: Variant = _place_idle_mine(placer)
	if idle_site == null or not _parked(_cart_at(host_map, JOINER_SITE)):
		return false
	client.multiplayer_peer = client_peer
	if not await _client_connected(server, client_peer):
		return false
	var peers := [host_map, joiner_map]
	if not await wait_until(func() -> bool: return _peers_ready(peers, idle_site), 5000):
		for map: TileMap in peers:
			printerr(
				(
					"mine cart: host playing=%s owner playing=%s absent owner parked=%s"
					% [
						_playing(_cart_at(map, HOST_SITE)),
						_playing(_cart_at(map, JOINER_SITE)),
						_parked(_cart_at(map, idle_site)),
					]
				)
			)
		return false

	var host_cart := _cart_at(host_map, JOINER_SITE)
	joiner.process_mode = Node.PROCESS_MODE_DISABLED
	client_peer.disconnect_peer(1)
	return await wait_until(
		func() -> bool:
			return (
				server.get_peers().is_empty()
				and not host_cart.is_playing()
				and host_cart.frame == 12
			),
		5000
	)


func _peers_ready(peers: Array, idle_site: Vector2i) -> bool:
	for map: TileMap in peers:
		if (
			not _playing(_cart_at(map, HOST_SITE))
			or not _playing(_cart_at(map, JOINER_SITE))
			or not _parked(_cart_at(map, idle_site))
		):
			return false
	return true


func _place_idle_mine(placer: ConstructionPlacer) -> Variant:
	for y in range(-8, 9):
		for x in range(-8, 9):
			var site := HOST_SITE + Vector2i(x, y)
			if placer.place_for_peer(BuildCosts.MINE, [site], 2_000_000_000, null):
				return site
	return null


func _parked(cart: AnimatedSprite2D) -> bool:
	return cart != null and cart.is_visible_in_tree() and not cart.is_playing() and cart.frame == 12


func _playing(cart: AnimatedSprite2D) -> bool:
	return cart != null and cart.is_visible_in_tree() and cart.is_playing()


func _cart_at(map: TileMap, site: Vector2i) -> AnimatedSprite2D:
	var mine: Dictionary = map.structure_placement_at(site)
	return map.get_node_or_null("MineCart_%d" % mine.get("id", 0)) as AnimatedSprite2D
