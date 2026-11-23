extends SceneTree
## godot --headless --fixed-fps 45 --path . --script res://tools/bench_frame.gd -- --seed=42
## Use fresh XDG user directories: the normal Host flow writes map settings.

const SCENE := "res://flagoria_main.tscn"
const WARMUP := 120
const WALK := [&"ui_right", &"ui_down", &"ui_left", &"ui_up"]
const MONITORS := {
	"process_us": Performance.TIME_PROCESS,
	"physics_us": Performance.TIME_PHYSICS_PROCESS,
	"objects": Performance.OBJECT_COUNT,
	"nodes": Performance.OBJECT_NODE_COUNT,
	"draw_calls": Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME,
	"render_objects": Performance.RENDER_TOTAL_OBJECTS_IN_FRAME,
}


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var options := {"seed": "42", "frames": "1200", "size": "default"}
	for arg in OS.get_cmdline_user_args():
		var pair := arg.trim_prefix("--").split("=", true, 1)
		if not arg.begins_with("--") or pair.size() != 2 or not options.has(pair[0]):
			_fail("expected --seed=N, --frames=N, or --size=default|large")
			return
		options[pair[0]] = pair[1]
	var world_seed := int(options.seed)
	var frames := int(options.frames)
	var large: bool = options.size == "large"
	if (
		not String(options.seed).is_valid_int()
		or world_seed <= 0
		or world_seed > 2147483643
		or not String(options.frames).is_valid_int()
		or frames <= 0
		or (not large and options.size != "default")
	):
		_fail("invalid seed, frame count, or size")
		return

	seed(world_seed)
	var params := MapGenParams.make_defaults()
	params.altitude_seed = world_seed
	params.moisture_seed = world_seed + 1
	params.temperature_seed = world_seed + 2
	params.items_seed = world_seed + 3
	params.biome_seed = world_seed + 4
	if large:
		params.archipelago_spacing = 128
		params.archipelago_island_radius = 52
		params.archipelago_world_extent = 1024
		params.archipelago_island_count = 12

	var start := Time.get_ticks_usec()
	if change_scene_to_file(SCENE) != OK:
		_fail("could not load the main scene")
		return
	await scene_changed
	var scene_us := Time.get_ticks_usec() - start
	var game := current_scene
	var world := game.get_node("World/worldMap") as TileMap
	var map_gen := root.get_node("MapGen")
	map_gen.params = params
	game.host_port = 0  # Let the OS choose an unused UDP port.
	start = Time.get_ticks_usec()
	game.get_node("CanvasLayer2/MainMenu")._begin_host()
	var host_us := Time.get_ticks_usec() - start
	var hero := game.get_node_or_null("World/1") as CharacterBody2D
	if (
		hero == null
		or game.enet_peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED
	):
		_fail("host or local player did not start")
		return
	var first_chunk_wall_us := -1
	start = Time.get_ticks_usec()
	for i in range(world.chunk_refresh_frames + 2):
		await process_frame
		if world.is_drawn(world.local_to_map(hero.position)):
			first_chunk_wall_us = Time.get_ticks_usec() - start
			break
	if first_chunk_wall_us < 0:
		_fail("spawn terrain was never generated")
		return

	for i in WARMUP:
		await process_frame
	var samples := {}
	var frame_wall := PackedFloat64Array()
	var monitor_pairs := {}
	var headless := DisplayServer.get_name() == "headless"
	for key in MONITORS:
		samples[key] = PackedFloat64Array()
	var spawn := hero.position
	var previous := spawn
	var travel := 0.0
	var physics_start := Engine.get_physics_frames()
	var walk := -1
	for i in frames:
		var direction := ((Engine.get_physics_frames() - physics_start) / 45) % WALK.size()
		if direction != walk:
			if walk >= 0:
				Input.action_release(WALK[walk])
			Input.action_press(WALK[direction])
			walk = direction
		var frame_start := Time.get_ticks_usec()
		await process_frame
		frame_wall.append(Time.get_ticks_usec() - frame_start)
		# Godot 4.7 publishes interval peaks, held across multiple frames.
		monitor_pairs[Vector2(Performance.get_monitor(Performance.TIME_PROCESS), Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS))] = true
		travel += previous.distance_to(hero.position)
		previous = hero.position
		for key in MONITORS:
			if headless and key in ["draw_calls", "render_objects"]:
				continue
			var value := Performance.get_monitor(MONITORS[key])
			samples[key].append(value * 1000000.0 if key.ends_with("_us") else value)
	Input.action_release(WALK[walk])

	var report := (
		"BENCH seed=%d size=%s frames=%d physics_ticks=%d scene_us=%d host_us=%d spawn_terrain_wait_us=%d monitor_pairs=%d travel_px=%.1f end_x=%.1f end_y=%.1f"
		% [
			world_seed,
			options.size,
			frames,
			Engine.get_physics_frames() - physics_start,
			scene_us,
			host_us,
			first_chunk_wall_us,
			monitor_pairs.size(),
			travel,
			previous.x,
			previous.y,
		]
	)
	for key in MONITORS:
		report += _stats(key, samples[key])
	print(report + _stats("frame_wall_us", frame_wall))
	game.enet_peer.close()
	get_multiplayer().multiplayer_peer = OfflineMultiplayerPeer.new()
	quit()


func _stats(key: String, values: PackedFloat64Array) -> String:
	if values.is_empty():
		return " %s=na" % key
	values.sort()
	var total := 0.0
	for value in values:
		total += value
	var count := values.size()
	return (
		" %s_mean=%.1f %s_p50=%.1f %s_p95=%.1f %s_max=%.1f"
		% [
			key,
			total / count,
			key,
			values[ceili(count * 0.5) - 1],
			key,
			values[ceili(count * 0.95) - 1],
			key,
			values[count - 1],
		]
	)


func _fail(message: String) -> void:
	printerr("bench_frame: " + message)
	quit(1)
