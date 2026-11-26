extends "res://.cursor/skills/verify-flagoria/bin/drive_base.gd"
## launch: --seed 42
## Failed Join returns to the main menu with "Could not join …" (#348).
## Joins a free UDP port with nothing listening, then snapshots the menu.


func run() -> void:
	step("menu")
	if change_scene_to_file(MAIN) != OK:
		_fail("cannot load " + MAIN)
		return
	if not await wait_until(
		func() -> bool:
			return current_scene != null and current_scene.has_node("CanvasLayer2/MainMenu"),
		START_TIMEOUT_S
	):
		_fail("no main menu")
		return
	print("VERIFY_READY pid=%d scene=%s" % [OS.get_process_id(), MAIN])
	await click(MULTIPLAYER_BUTTON)
	var menu: Control = current_scene.get_node(MULTIPLAYER_VIEW)
	var hud: CanvasLayer = current_scene.get_node("CanvasLayer1")
	var status: Label = menu.get_node("JoinStatus")
	var address: LineEdit = menu.get_node("AddressEntry")
	# Pick a free port so create_client is OK but nothing answers.
	var port := _free_port()
	if port == 0:
		printerr("join_fail: no free UDP port")
		done(false)
		return
	var target := "127.0.0.1:%d" % port
	address.text = target
	await snapshot("before-join")
	step("join")
	await click(JOIN_BUTTON)
	if menu.is_visible_in_tree() or not hud.visible:
		_fail("Join did not hide the menu and show the HUD")
		return
	var returned := await wait_until(func() -> bool: return menu.is_visible_in_tree(), 8.0)
	await snapshot("join-failed")
	var expected := "Could not join " + target
	if not returned:
		_fail("main menu did not return after failed join")
	elif hud.visible:
		_fail("HUD is still visible after failed join")
	elif not status.is_visible_in_tree() or status.text != expected:
		_fail(
			(
				"join status visible=%s text='%s', expected '%s'"
				% [status.is_visible_in_tree(), status.text, expected]
			)
		)
	else:
		print("join_fail: menu returned, HUD hidden, status='%s'" % status.text)
		done(true)


func _free_port() -> int:
	## Same idea as test helpers: bind UDP port 0, read the OS pick, close.
	var udp := PacketPeerUDP.new()
	if udp.bind(0, "127.0.0.1") != OK:
		return 0
	var p := udp.get_local_port()
	udp.close()
	return p
