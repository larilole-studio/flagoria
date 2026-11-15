extends SceneTree
## Joins a dedicated server on --port=N, kills that server, and checks the
## client returns to the main menu via server_disconnected (#348).
## Dial only after the server log says it is listening. An earlier dial
## hits the unanswered-join timeout and the client never connects.
## Printed by test_join_fail_host_quits.

var _fail := 0


func _initialize() -> void:
	call_deferred("_run")


func _check(ok: bool, what: String) -> void:
	if not ok:
		printerr("join_fail_probe: FAIL %s" % what)
		_fail += 1


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _server_listening(log_path: String, port: int) -> bool:
	if not FileAccess.file_exists(log_path):
		return false
	var text := FileAccess.get_file_as_string(log_path)
	return ("Dedicated server listening on UDP port %d" % port) in text


func _remove_log(log_dir: String) -> void:
	if log_dir == "":
		return
	var log_path := log_dir.path_join("server.log")
	if FileAccess.file_exists(log_path):
		DirAccess.remove_absolute(log_path)
	DirAccess.remove_absolute(log_dir)


func _run() -> void:
	var port := 0
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--port="):
			port = arg.trim_prefix("--port=").to_int()
	if port == 0:
		printerr("join_fail_probe: needs --port=N")
		quit(1)
		return
	var log_dir := OS.get_temp_dir().path_join("flagoria-join-fail-%d" % OS.get_process_id())
	DirAccess.make_dir_recursive_absolute(log_dir)
	var log_path := log_dir.path_join("server.log")
	var pid := OS.create_process(
		OS.get_executable_path(),
		["--headless", "--path", ProjectSettings.globalize_path("res://"),
			"--log-file", log_path,
			"--", "--server", "--port=%d" % port]
	)
	if pid <= 0:
		printerr("join_fail_probe: could not start server")
		_remove_log(log_dir)
		quit(1)
		return
	if change_scene_to_file("res://flagoria_main.tscn") != OK:
		printerr("join_fail_probe: could not load main scene")
		OS.kill(pid)
		_remove_log(log_dir)
		quit(1)
		return
	await _frames(3)
	var main = current_scene
	var deadline := Time.get_ticks_msec() + 30000
	while Time.get_ticks_msec() < deadline and OS.is_process_running(pid):
		if _server_listening(log_path, port):
			break
		await process_frame
	if not _server_listening(log_path, port):
		_check(false, "server was not listening")
		OS.kill(pid)
		_remove_log(log_dir)
		quit(1)
		return
	main.get_node("CanvasLayer2/MainMenu").hide()
	main.get_node("CanvasLayer1").show()
	main.add_player_joined(port)
	var world: Node = main.get_node("World")
	var client_id := 0
	while Time.get_ticks_msec() < deadline and OS.is_process_running(pid):
		client_id = main.multiplayer.get_unique_id()
		if main.world_params != null and world.has_node(str(client_id)):
			break
		await process_frame
	_check(world.has_node(str(client_id)), "never joined server before kill")
	if _fail > 0:
		OS.kill(pid)
		_remove_log(log_dir)
		quit(1)
		return
	OS.kill(pid)
	deadline = Time.get_ticks_msec() + 10000
	while Time.get_ticks_msec() < deadline:
		await process_frame
		main = current_scene
		if main == null:
			continue
		var menu = main.get_node_or_null("CanvasLayer2/MainMenu")
		if menu != null and menu.visible:
			break
	main = current_scene
	var menu2 = main.get_node_or_null("CanvasLayer2/MainMenu") if main else null
	_check(menu2 != null and menu2.visible, "main menu not visible after host quit")
	_check(main.get_node_or_null("CanvasLayer1") == null
			or not main.get_node("CanvasLayer1").visible,
			"HUD still visible after host quit")
	if _fail == 0:
		print("JOIN_FAIL_PROBE_OK")
	_remove_log(log_dir)
	quit(0 if _fail == 0 else 1)
