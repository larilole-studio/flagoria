extends "res://tests/helpers/test_helpers.gd"

const STALE := Vector2i(19, -59)
const JOINER_SITE := Vector2i(20, -56)
const HOST_SITE := Vector2i(24, -50)


func _test_place_mine_sync() -> int:
	print("-- test_place_mine_sync")
	var port := _free_udp_port()
	var server_peer := ENetMultiplayerPeer.new()
	var client_peer := ENetMultiplayerPeer.new()
	if (
		port == 0
		or server_peer.create_server(port, 1) != OK
		or client_peer.create_client("127.0.0.1", port) != OK
	):
		printerr("FAIL mine_sync: could not start peers")
		return 1

	var host := mount_main_scene()
	host.name = "MineHost"
	var joiner := mount_main_scene()
	var server := SceneMultiplayer.new()
	var client := SceneMultiplayer.new()
	set_multiplayer(server, host.get_path())
	set_multiplayer(client, joiner.get_path())
	server.multiplayer_peer = server_peer
	client.multiplayer_peer = client_peer

	var ok := false
	if await _client_connected(server, client_peer):
		ok = await _build_on_both_peers(host, joiner, client.get_unique_id())
	else:
		printerr("FAIL mine_sync: joiner did not connect")

	client_peer.close()
	server_peer.close()
	set_multiplayer(null, joiner.get_path())
	set_multiplayer(null, host.get_path())
	joiner.queue_free()
	host.queue_free()
	await process_frame
	if ok:
		print("PASS test_place_mine_sync")
	return 0 if ok else 1


func _build_on_both_peers(host: Node, joiner: Node, joiner_id: int) -> bool:
	var host_requests: StructureRequests = host.get_node("World/StructureRequests")
	var joiner_requests: StructureRequests = joiner.get_node("World/StructureRequests")
	var host_map := host_requests.map
	var joiner_map := joiner_requests.map
	var params := _spawn_params(11, 0.003)
	host_map.apply_map_params(params)
	joiner_map.apply_map_params(params)

	var host_inventory := host_requests.inventory
	var joiner_inventory := joiner_requests.inventory
	host_inventory.add(Inventory.WOOD, 25)
	host_inventory.add(Inventory.STONE, 5)
	joiner_inventory.add(Inventory.WOOD, 30)
	joiner_inventory.add(Inventory.STONE, 7)
	var joiner_position := host_requests.interaction.cell_center(STALE + Vector2i(0, 2))
	_add_body(host_requests.world, joiner_id, joiner_position)
	var host_body := _add_body(host_requests.world, 1, joiner_position)

	joiner_requests.interaction.bind(_add_body(joiner_requests.world, joiner_id, joiner_position))
	if not _send_joiner_requests(joiner, joiner_requests, host_map):
		return false

	# Both requests use the same reliable channel. The valid replica confirms
	# the host handled the stale request before it handled the valid one.
	if not await wait_until(
		func() -> bool: return not joiner_map.structure_placement_at(JOINER_SITE).is_empty(), 5000
	):
		printerr("FAIL mine_sync: joiner's valid mine did not replicate")
		return false
	if (
		host_map.structures_for_sync() != [["mine", joiner_id, JOINER_SITE]]
		or joiner_map.structures_for_sync() != host_map.structures_for_sync()
		or joiner_inventory.count_of(Inventory.WOOD) != 15
		or joiner_inventory.count_of(Inventory.STONE) != 7
		or host_inventory.count_of(Inventory.WOOD) != 25
		or host_requests.demolish(JOINER_SITE)
	):
		printerr("FAIL mine_sync: stale request, joiner charge, replica or ownership")
		return false

	host_body.global_position = host_requests.interaction.cell_center(HOST_SITE + Vector2i.DOWN)
	if (
		not ConstructionPlacer.new(host_map).place(BuildCosts.MINE, [HOST_SITE], host_inventory)
		or not await wait_until(
			func() -> bool: return not joiner_map.structure_placement_at(HOST_SITE).is_empty(), 5000
		)
		or (
			host_map.structures_for_sync()
			!= [["mine", joiner_id, JOINER_SITE], ["mine", 1, HOST_SITE]]
		)
		or joiner_map.structures_for_sync() != host_map.structures_for_sync()
		or host_inventory.count_of(Inventory.WOOD) != 10
		or host_inventory.count_of(Inventory.STONE) != 5
		or joiner_inventory.count_of(Inventory.WOOD) != 15
	):
		printerr("FAIL mine_sync: host purchase or buyer-only charge")
		return false
	return true


func _send_joiner_requests(
	joiner: Node, joiner_requests: StructureRequests, host_map: TileMap
) -> bool:
	var host_placer := ConstructionPlacer.new(host_map)
	var interaction := joiner_requests.interaction
	joiner.get_node("CanvasLayer2/MainMenu").hide()
	joiner.get_node("CanvasLayer1").show()
	var buildings: Button = joiner.get_node("CanvasLayer1/BuildingsButton")
	var button: Button = joiner.get_node("CanvasLayer1/BuildPicker/MineButton")
	buildings.set_pressed(true)
	var opened := button.is_visible_in_tree()
	button.pressed.emit()
	var build := interaction.build
	var center := root.get_visible_rect().get_center()
	var center_cell := interaction.world_map.local_to_map(
		interaction.world_map.to_local(interaction.to_world(center))
	)
	if not opened or build.tool != BuildPlacement.Tool.MINE or not build.cells.has(center_cell):
		printerr("FAIL mine_sync: joiner did not get a centered Mine preview")
		return false
	_preview_mine(interaction, STALE + Vector2i.LEFT)
	if (
		build.reasons != ["not adjacent to a rock"]
		or build.cell_ok.has(true)
		or build.commit()
		or joiner_requests.inventory.count_of(Inventory.WOOD) != 30
	):
		printerr("FAIL mine_sync: joiner did not refuse the diagonal preview")
		return false

	_preview_mine(interaction, STALE)
	if (
		build.cost != 15
		or not host_placer.can_place_geometry(BuildCosts.MINE, [STALE]).is_empty()
		or not host_map.destroy_decor(STALE + Vector2i.DOWN)
		or not build.commit()
	):
		printerr("FAIL mine_sync: could not submit the stale request")
		return false
	_preview_mine(interaction, JOINER_SITE)
	if build.cost != 15 or not build.commit():
		printerr("FAIL mine_sync: could not submit the valid request")
		return false
	return true


func _preview_mine(interaction: Interaction, anchor: Vector2i) -> void:
	var point := interaction.get_canvas_transform() * interaction.cell_center(anchor)
	interaction.build.update_preview(point, point)


func _add_body(world: Node2D, peer: int, where: Vector2) -> Node2D:
	var body := Node2D.new()
	body.name = str(peer)
	world.add_child(body)
	body.global_position = where
	return body
