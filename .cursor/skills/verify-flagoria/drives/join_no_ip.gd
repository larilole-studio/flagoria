## launch: --seed 42
extends "res://.cursor/skills/verify-flagoria/bin/drive_base.gd"


func run() -> void:
	step("menu")
	if change_scene_to_file(MAIN) != OK:
		_fail("cannot load " + MAIN)
		return
	if not await wait_until(
		func() -> bool: return current_scene != null and current_scene.has_node(JOIN_BUTTON),
		START_TIMEOUT_S
	):
		_fail("no Join button")
		return
	print("VERIFY_READY pid=%d scene=%s" % [OS.get_process_id(), MAIN])
	await click(MULTIPLAYER_BUTTON)
	var main := current_scene
	var menu: Control = main.get_node(MULTIPLAYER_VIEW)
	var hud: CanvasLayer = main.get_node("CanvasLayer1")
	var status: Label = menu.get_node("JoinStatus")
	var address: LineEdit = menu.get_node("AddressEntry")
	if not address.text.is_empty():
		_fail("expected a blank address on launch")
		return
	await snapshot("before-join")
	step("join-without-address")
	await click(JOIN_BUTTON)
	await create_timer(1.5).timeout
	await snapshot("join-no-ip")
	var offline: bool = (
		main.multiplayer.multiplayer_peer is OfflineMultiplayerPeer
		and main._join_host == ""
		and main._join_port == 0
	)
	var ok := (
		menu.is_visible_in_tree()
		and not hud.visible
		and status.is_visible_in_tree()
		and status.text == "Enter the host's IP address"
		and offline
	)
	print(
		(
			'join_no_ip: menu=%s HUD=%s status_visible=%s status="%s" offline=%s'
			% [
				menu.is_visible_in_tree(),
				hud.visible,
				status.is_visible_in_tree(),
				status.text,
				offline
			]
		)
	)
	done(ok)
