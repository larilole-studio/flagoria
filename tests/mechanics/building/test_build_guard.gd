extends "res://tests/helpers/test_helpers.gd"
## Interact-mode Guard post picker (#528).


func _test_build_picker_includes_guard() -> int:
	## The build row includes Guard post; it stays visible in multiplayer.
	print("-- test_build_picker_includes_guard")
	var fail := 0
	var scene = load("res://flagoria_main.tscn").instantiate()
	root.add_child(scene)
	var menu: Node = scene.get_node("CanvasLayer2/MainMenu")
	menu.hide()
	menu.set_process_unhandled_input(false)
	scene.get_node("CanvasLayer1").show()
	var interaction: Interaction = scene.get_node("World/Interaction")
	interaction.set_mode(Interaction.Mode.INTERACT)
	await process_frame
	var picker: Control = scene.get_node_or_null("CanvasLayer1/BuildPicker")
	if picker == null or picker.get_child_count() != 5:
		printerr("FAIL build_picker_includes_guard: picker children %s"
				% [picker.get_child_count() if picker else null])
		fail += 1
	interaction.build.set_tool(BuildPlacement.Tool.GUARD)
	if interaction.build.tool != BuildPlacement.Tool.GUARD:
		printerr("FAIL build_picker_includes_guard: set_tool GUARD did not stick")
		fail += 1
	var peer := ENetMultiplayerPeer.new()
	var api := SceneMultiplayer.new()
	if peer.create_client("127.0.0.1", 1) != OK:
		printerr("FAIL build_picker_includes_guard: could not start ENet client")
		fail += 1
	else:
		api.multiplayer_peer = peer
		set_multiplayer(api, scene.get_path())
		interaction.build._refresh_picker_visible()
		_open_buildings(scene)
		await process_frame
		var guard_btn: Button = interaction.build._buttons.get(BuildPlacement.Tool.GUARD)
		if guard_btn == null or not guard_btn.visible:
			printerr("FAIL build_picker_includes_guard: MP should show Guard post")
			fail += 1
		if interaction.build.tool != BuildPlacement.Tool.GUARD:
			printerr("FAIL build_picker_includes_guard: MP cleared the Guard tool")
			fail += 1
		api.multiplayer_peer = null
		peer.close()
		set_multiplayer(null, scene.get_path())
	scene.queue_free()
	await process_frame
	if fail == 0:
		print("PASS test_build_picker_includes_guard")
	return fail


func _open_buildings(scene: Node) -> void:
	var btn: Button = scene.get_node_or_null("CanvasLayer1/BuildingsButton")
	if btn != null:
		btn.set_pressed_no_signal(true)
		btn.emit_signal("toggled", true)