extends "res://tests/helpers/test_helpers.gd"
## Main Menu Join accepts a hostname or IPv4 address with an optional port.

const JoinAddress = preload("res://Scripts/net/join_address.gd")
const ADDRESS := "CanvasLayer2/MainMenu/MarginContainer/VBoxContainer/AddressEntry"
const STATUS := "CanvasLayer2/MainMenu/MarginContainer/VBoxContainer/JoinStatus"
const JOIN := "CanvasLayer2/MainMenu/MarginContainer/VBoxContainer/JoinButton"


func _test_join_port_button() -> int:
	print("-- test_join_port_button")
	var fail := 0
	var scene = load("res://flagoria_main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	var menu: Control = scene.get_node("CanvasLayer2/MainMenu")
	var hud: CanvasLayer = scene.get_node("CanvasLayer1")
	var address: LineEdit = scene.get_node(ADDRESS)
	var status: Label = scene.get_node(STATUS)
	var join: Button = scene.get_node(JOIN)
	var requested := []
	menu.new_player_joined.connect(func(port: int) -> void: requested.append(port))

	for row in [
		[":9799", JoinAddress.ERROR_ADDRESS],
		["host:", JoinAddress.ERROR_ADDRESS],
		["host:abc", JoinAddress.ERROR_ADDRESS],
		["host:0", JoinAddress.ERROR_PORT],
		["host:65536", JoinAddress.ERROR_PORT],
		["::1", JoinAddress.ERROR_UNSUPPORTED],
		["[::1]:9799", JoinAddress.ERROR_UNSUPPORTED],
		["host:1:2", JoinAddress.ERROR_UNSUPPORTED],
	]:
		address.text = row[0]
		join.pressed.emit()
		if (
			not menu.visible
			or hud.visible
			or not status.is_visible_in_tree()
			or status.text != row[1]
			or address.text != row[0]
			or not requested.is_empty()
		):
			printerr("FAIL join_port_button: rejection of '%s' showed '%s'" % [row[0], status.text])
			fail += 1

	address.text = "127.0.0.1:1"
	join.pressed.emit()
	var deadline := Time.get_ticks_msec() + 8000
	while not menu.visible and Time.get_ticks_msec() < deadline:
		await process_frame
	if (
		not menu.visible
		or hud.visible
		or not status.is_visible_in_tree()
		or status.text != "Could not join 127.0.0.1:1"
		or address.text != "127.0.0.1:1"
		or requested != [1]
	):
		printerr(
			(
				"FAIL join_port_button: timeout showed '%s' with join requests %s"
				% [status.text, requested]
			)
		)
		fail += 1

	address.text = "host:abc"
	join.pressed.emit()
	if not menu.visible or status.text != JoinAddress.ERROR_ADDRESS or requested != [1]:
		printerr("FAIL join_port_button: invalid retry showed '%s'" % status.text)
		fail += 1

	for blank in ["", "   "]:
		address.text = blank
		join.pressed.emit()
		if (
			not menu.visible
			or hud.visible
			or not status.is_visible_in_tree()
			or status.text != "Enter the host's IP address"
			or address.text != blank
			or requested != [1]
		):
			printerr(
				(
					"FAIL join_port_button: blank retry showed '%s' with join requests %s"
					% [status.text, requested]
				)
			)
			fail += 1

	address.text = "localhost"
	join.pressed.emit()
	if (
		menu.visible
		or not hud.visible
		or status.visible
		or address.text != "localhost"
		or requested != [1, 9786]
	):
		printerr("FAIL join_port_button: default retry gave join requests %s" % [requested])
		fail += 1
	_drop_scene(scene)
	await process_frame

	# Exercise address forms independently of DNS and of whether a host is listening.
	for row in [
		["   ", "localhost", 9786],
		["localhost", "localhost", 9786],
		["127.0.0.1", "127.0.0.1", 9786],
		["join-example.test", "join-example.test", 9786],
		["127.0.0.1:65535", "127.0.0.1", 65535],
		["localhost:9799", "localhost", 9799],
	]:
		var parsed := JoinAddress.parse(row[0])
		if not parsed["ok"] or parsed["host"] != row[1] or parsed["port"] != row[2]:
			printerr("FAIL join_port_button: '%s' parsed as %s" % [row[0], parsed])
			fail += 1
	if fail == 0:
		print("PASS test_join_port_button")
	return fail


func _drop_scene(scene) -> void:
	scene.enet_peer.close()
	scene.multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	scene.queue_free()


func _test_join_port_dedicated() -> int:
	## A headless `--server` on a free port, then Join through the button at
	## 127.0.0.1:port and localhost:port. Each client gets a World player and
	## the server spawns no player 1. An invalid address on the same menu
	## does not block the following join. Time cost: ~8 s in verify, and
	## ~8 s x 8 on the full netcode-stress tier (one scenario, 4 at a time).
	print("-- test_join_port_dedicated")
	await process_frame
	var port := _free_udp_port()
	if port == 0:
		printerr("FAIL join_port_dedicated found no free UDP port")
		return 1
	var pid := OS.create_process(
		OS.get_executable_path(),
		[
			"--headless",
			"--path",
			ProjectSettings.globalize_path("res://"),
			"--",
			"--server",
			"--port=%d" % port
		]
	)
	if pid <= 0:
		printerr("FAIL join_port_dedicated could not start the server")
		return 1
	var fail := 0
	fail += await _button_join(pid, "host:abc", JoinAddress.ERROR_ADDRESS, false)
	if fail == 0:
		fail += await _button_join(pid, "127.0.0.1:%d" % port, "", true)
	if fail == 0:
		fail += await _button_join(pid, "localhost:%d" % port, "", true)
	if OS.is_process_running(pid):
		OS.kill(pid)
	if fail == 0:
		print("PASS test_join_port_dedicated (port %s)" % port)
	return fail


func _button_join(pid: int, typed: String, error_text: String, want_player: bool) -> int:
	var scene = load("res://flagoria_main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	var menu: Node = scene.get_node("CanvasLayer2/MainMenu")
	var hud: CanvasLayer = scene.get_node("CanvasLayer1")
	var status: Label = scene.get_node(STATUS)
	scene.get_node(ADDRESS).text = typed
	scene.get_node(JOIN).pressed.emit()
	var fail := 0
	if not want_player:
		if not menu.visible or hud.visible or status.text != error_text:
			printerr(
				(
					"FAIL join_port_dedicated reject '%s' status='%s' menu=%s"
					% [typed, status.text, menu.visible]
				)
			)
			fail = 1

	else:
		var deadline := Time.get_ticks_msec() + 30000
		var client_id := 0
		var world: Node = scene.get_node("World")
		while Time.get_ticks_msec() < deadline and OS.is_process_running(pid):
			client_id = scene.multiplayer.get_unique_id()
			var params_ok: bool = (
				scene.world_params != null and scene.world_params.altitude_seed != 0
			)
			if params_ok and client_id != 1 and world.has_node(str(client_id)):
				break
			await process_frame
		if not OS.is_process_running(pid):
			printerr("FAIL join_port_dedicated server exited before '%s' joined" % typed)
			fail = 1
		elif (
			scene.world_params == null or not world.has_node(str(client_id)) or world.has_node("1")
		):
			printerr(
				(
					"FAIL join_port_dedicated '%s' player=%s params=%s node1=%s"
					% [typed, client_id, scene.world_params != null, world.has_node("1")]
				)
			)
			fail = 1
		elif scene.get_node(ADDRESS).text != typed:
			printerr("FAIL join_port_dedicated: Join rewrote '%s'" % typed)
			fail += 1
	_drop_scene(scene)
	await process_frame
	return fail
