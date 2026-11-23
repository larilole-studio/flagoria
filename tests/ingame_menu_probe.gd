extends SceneTree
## Hosts a game through the main menu's Host button, leaves it through the
## in-game menu's Main menu button, then hosts a second game the same way.
## Run as a subprocess by test_ingame_menu_leave in tests/ui/test_ingame_menu.gd
## with `-- --port=N` (a free UDP port). Prints one line per failed check, every
## engine error it logged, and INGAME_MENU_PROBE_OK when every check passed.

var _errors := _ErrorLog.new()
var _fail := 0


class _ErrorLog:
	extends Logger
	## Godot may log from any thread.
	var lines: Array[String] = []
	var _lock := Mutex.new()

	func _log_error(
		function: String,
		_file: String,
		_line: int,
		code: String,
		rationale: String,
		_editor_notify: bool,
		_error_type: int,
		_script_backtraces: Array[ScriptBacktrace]
	) -> void:
		_lock.lock()
		lines.append("%s: %s" % [function, rationale if rationale != "" else code])
		_lock.unlock()

	func snapshot() -> Array[String]:
		_lock.lock()
		var copy := lines.duplicate()
		_lock.unlock()
		return copy


func _initialize() -> void:
	OS.add_logger(_errors)
	call_deferred("_run")


func _check(ok: bool, what: String) -> void:
	if not ok:
		printerr("ingame_menu_probe: FAIL %s" % what)
		_fail += 1


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _host(port: int, label: String) -> Node:
	## Press Host on the current main menu; the game's main node, or null.
	var main = current_scene
	main.host_port = port
	main.get_node("CanvasLayer2/MainMenu/MarginContainer/VBoxContainer/HostButton").pressed.emit()
	await _frames(5)
	var me = main.get_node_or_null("World/1")
	_check(me != null, "%s: no host player after Host" % label)
	_check(
		(
			main.multiplayer.multiplayer_peer is ENetMultiplayerPeer
			and (
				main.multiplayer.multiplayer_peer.get_connection_status()
				== MultiplayerPeer.CONNECTION_CONNECTED
			)
		),
		"%s: Host did not start a server on port %d" % [label, port]
	)
	_check(
		main.get_node("CanvasLayer1/InGameMenu").is_visible_in_tree(),
		"%s: in-game menu not shown" % label
	)
	return main


func _run() -> void:
	var port := 0
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--port="):
			port = arg.trim_prefix("--port=").to_int()
	if port == 0 or change_scene_to_file("res://flagoria_main.tscn") != OK:
		printerr("ingame_menu_probe: needs --port=N and the main scene")
		quit(1)
		return
	await _frames(3)
	_check(
		not current_scene.get_node("CanvasLayer1/InGameMenu").is_visible_in_tree(),
		"menu button shown on the main menu"
	)
	var audio = root.get_node("AudioSettings")
	audio.save_path = "user://test_ingame_menu_volume.cfg"
	var first: Node = await _host(port, "first game")
	audio.set_volume("Music", 0.7)
	var menu = first.get_node("CanvasLayer1/InGameMenu")
	menu.menu_button.pressed.emit()
	_check(menu.is_open(), "Menu button did not open the panel")
	var slider := menu.find_child("MusicVolume") as HSlider
	_check(
		slider != null and slider.is_visible_in_tree(),
		"Music volume slider missing from the open menu"
	)
	if slider != null:
		_check(is_equal_approx(slider.value, 0.7), "slider did not show the saved Music volume")
		slider.value = 0.5
		_check(
			is_equal_approx(audio.get_volume("Music"), 0.5), "slider did not update AudioSettings"
		)
		var bus := AudioServer.get_bus_index("Music")
		_check(
			(
				is_equal_approx(AudioServer.get_bus_volume_db(bus), -6.0206)
				and not AudioServer.is_bus_mute(bus)
			),
			"slider did not update the Music bus immediately"
		)
		audio.reset_to_defaults()
		audio.load_from_disk()
		_check(
			is_equal_approx(audio.get_volume("Music"), 0.5),
			"Music volume did not survive settings reload"
		)
	menu.main_menu_button.pressed.emit()
	await _frames(5)

	var again := current_scene
	_check(not is_instance_valid(first), "the old game scene was not freed")
	_check(again != null and again != first, "Main menu did not reload the main scene")
	if again == null or again == first:
		quit(1)
		return
	_check(again.get_node("CanvasLayer2/MainMenu").visible, "main menu not visible after leaving")
	_check(not again.get_node("CanvasLayer1").visible, "HUD still visible after leaving")
	_check(
		again.multiplayer.multiplayer_peer is OfflineMultiplayerPeer,
		"a network peer is left after leaving: %s" % again.multiplayer.multiplayer_peer
	)
	var players := 0
	for child in again.get_node("World").get_children():
		players += 1 if child is CharacterBody2D else 0
	_check(players == 0, "%d players left in the world after leaving" % players)
	var music = root.get_node("MusicPlayer")
	_check(
		music.current_track() == music.MENU_TRACK,
		"menu music not playing after leaving: %s" % music.current_track()
	)

	var second: Node = await _host(port, "second game")
	_check(second.get_node("World/Mobs").get_child_count() > 1, "second game spawned no mobs")
	_check(music.current_track() == music.GAME_TRACK, "game music not playing in the second game")

	var second_menu = second.get_node("CanvasLayer1/InGameMenu")
	second_menu.menu_button.pressed.emit()
	var second_slider := second_menu.find_child("MusicVolume") as HSlider
	_check(
		second_slider != null and is_equal_approx(second_slider.value, 0.5),
		"slider did not retain Music volume in the next match"
	)
	DirAccess.remove_absolute(audio.save_path)

	for line in _errors.snapshot():
		printerr("ingame_menu_probe: ERROR logged: %s" % line)
		_fail += 1
	if _fail == 0:
		print("INGAME_MENU_PROBE_OK")
	quit(0 if _fail == 0 else 1)
