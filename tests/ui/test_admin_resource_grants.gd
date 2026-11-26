extends "res://tests/helpers/test_helpers.gd"


class GrantPolicy:
	extends AdminResourceGrants

	var allowed := true
	var checked_peer := 0

	func is_admin(peer_id: int) -> bool:
		checked_peer = peer_id
		return allowed


func _test_admin_resource_menu() -> int:
	print("-- test_admin_resource_menu")
	var scene := load("res://flagoria_main.tscn").instantiate() as Node
	var inventory: Inventory = scene.get_node("Inventory")
	var grants := scene.get_node("AdminResourceGrants")
	grants.set_script(GrantPolicy)
	grants.inventory = inventory
	root.add_child(scene)
	var hud: CanvasLayer = scene.get_node("CanvasLayer1")
	hud.show()
	var menu: Control = hud.get_node("InGameMenu")
	var wood: ResourceHud = hud.get_node("ResourceHud")
	wood.bind(inventory)
	menu.open()
	var row := menu.get_node_or_null("Pause/Panel/Margin/VBox/ResourceGrants") as Control
	var fail := 0
	if row == null or not row.is_visible_in_tree():
		printerr("FAIL admin_resource_menu: admin grant buttons are missing")
		fail += 1
	else:
		var add_wood: Button = row.get_node("AddWood")
		var max_resources: Button = row.get_node("MaxResources")
		add_wood.pressed.emit()
		if wood.label.text != "100":
			printerr("FAIL admin_resource_menu: +100 wood did not update the HUD")
			fail += 1
		max_resources.pressed.emit()
		if wood.label.text != "999":
			printerr("FAIL admin_resource_menu: Max resources did not update the HUD")
			fail += 1
		add_wood.pressed.emit()
		max_resources.pressed.emit()
		if wood.label.text != "1099":
			printerr("FAIL admin_resource_menu: Max resources took already earned wood")
			fail += 1
		menu.close()
		grants.allowed = false
		menu.open()
		add_wood.pressed.emit()
		if row.is_visible_in_tree() or wood.label.text != "1099":
			printerr("FAIL admin_resource_menu: non-admin could see or use the buttons")
			fail += 1
	scene.queue_free()
	await process_frame
	if fail == 0:
		print("PASS test_admin_resource_menu")
	return fail


func _test_admin_resource_host() -> int:
	print("-- test_admin_resource_host")
	var server := GrantPolicy.new()
	var joiner := AdminResourceGrants.new()
	for grants: AdminResourceGrants in [server, joiner]:
		grants.inventory = Inventory.new()
		grants.add_child(grants.inventory)
		root.add_child(grants, true)
	var host_api := SceneMultiplayer.new()
	var joiner_api := SceneMultiplayer.new()
	var host_path := server.get_path()
	var joiner_path := joiner.get_path()
	set_multiplayer(host_api, host_path)
	set_multiplayer(joiner_api, joiner_path)
	var host_peer := ENetMultiplayerPeer.new()
	var joiner_peer := ENetMultiplayerPeer.new()
	var port := _free_udp_port()
	var accepted := false
	if port != 0 and host_peer.create_server(port) == OK:
		host_api.multiplayer_peer = host_peer
		if joiner_peer.create_client("127.0.0.1", port) == OK:
			joiner_api.multiplayer_peer = joiner_peer
			if await _client_connected(host_api, joiner_peer):
				accepted = await _check_host_grant(server, joiner, joiner_api)
	set_multiplayer(null, joiner_path)
	set_multiplayer(null, host_path)
	joiner_peer.close()
	host_peer.close()
	joiner.queue_free()
	server.queue_free()
	await process_frame
	if not accepted:
		printerr("FAIL admin_resource_host: joiner grant failed the host authorization check")
		return 1
	print("PASS test_admin_resource_host")
	return 0


func _check_host_grant(
	server: GrantPolicy, joiner: AdminResourceGrants, joiner_api: MultiplayerAPI
) -> bool:
	var peer_id := joiner_api.get_unique_id()
	server.allowed = false
	joiner.grant(true)
	var deadline := Time.get_ticks_msec() + 2000
	while server.checked_peer == 0 and Time.get_ticks_msec() < deadline:
		await process_frame
	if server.checked_peer != peer_id or joiner.inventory.count_of(Inventory.WOOD) != 0:
		return false

	# Read the client count before the next frame lets the host poll.
	server.allowed = true
	server.checked_peer = 0
	joiner.grant(false)
	var before_host := joiner.inventory.count_of(Inventory.WOOD)
	deadline = Time.get_ticks_msec() + 2000
	while joiner.inventory.count_of(Inventory.WOOD) == 0 and Time.get_ticks_msec() < deadline:
		await process_frame
	# The later reliable reply also proves the refused Max request never applied.
	return (
		before_host == 0
		and server.checked_peer == peer_id
		and joiner.inventory.count_of(Inventory.WOOD) == 100
		and server.inventory.count_of(Inventory.WOOD) == 0
	)
