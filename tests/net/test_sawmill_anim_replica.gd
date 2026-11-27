extends "res://tests/helpers/test_helpers.gd"

const SITE := Vector2i(19, -59)
const IDLE_SITE := Vector2i(31, -60)


func _test_sawmill_animation_late_join() -> int:
	var port := _free_udp_port()
	if port == 0:
		return 1
	var host := mount_main_scene()
	host.name = "SawmillAnimHost"
	var joiner := mount_main_scene()
	joiner.name = "SawmillAnimJoiner"
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
		printerr("FAIL sawmill animation: late join or disconnect presentation differs")
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
	for site in [SITE, IDLE_SITE]:
		host_map.generate_chunk(host_map.map_to_local(site))
		host_map.set_cell(1, site + Vector2i.DOWN, TileCatalog.SOURCE_ID, TileCatalog.TREE)
	if (
		client_peer.create_client("127.0.0.1", port) != OK
		or not placer.place_for_peer(BuildCosts.SAWMILL, [SITE], client_peer.get_unique_id(), null)
		or not placer.place_for_peer(BuildCosts.SAWMILL, [IDLE_SITE], 2_000_000_000, null)
	):
		return false
	var host_mill := _mill_at(host_map, SITE)
	if not _idle(host_mill) or not _idle(_mill_at(host_map, IDLE_SITE)):
		return false
	client.multiplayer_peer = client_peer
	if not await _client_connected(server, client_peer):
		return false
	if not await wait_until(
		func() -> bool:
			return _both_sawing(host_mill, joiner_map) and _idle(_mill_at(joiner_map, IDLE_SITE)),
		5000
	):
		return false
	for mill in [host_mill, _mill_at(joiner_map, SITE)]:
		if not await wait_until(_sound_playing.bind(mill), 2000):
			return false
	joiner.process_mode = Node.PROCESS_MODE_DISABLED
	client_peer.disconnect_peer(1)
	return await wait_until(
		func() -> bool: return server.get_peers().is_empty() and _idle(host_mill), 5000
	)


func _both_sawing(host_mill: AnimatedSprite2D, joiner_map: TileMap) -> bool:
	var joined_mill := _mill_at(joiner_map, SITE)
	return (
		joined_mill != null
		and host_mill.is_playing()
		and joined_mill.is_playing()
		and joined_mill.sprite_frames == host_mill.sprite_frames
		and joined_mill.transform == host_mill.transform
	)


func _idle(mill: AnimatedSprite2D) -> bool:
	return mill != null and not mill.is_playing() and mill.frame == 0 and not _sound_playing(mill)


func _sound_playing(mill: AnimatedSprite2D) -> bool:
	var sound := mill.get_node("SawingSound") as AudioStreamPlayer2D
	return sound.playing


func _mill_at(map: TileMap, site: Vector2i) -> AnimatedSprite2D:
	var placement: Dictionary = map.structure_placement_at(site)
	return map.get_node_or_null("SawmillAnim_%d" % placement.get("id", 0)) as AnimatedSprite2D
