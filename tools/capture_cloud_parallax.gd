extends "res://.cursor/skills/verify-flagoria/bin/drive_base.gd"
## Evidence capture. Hosts through the menu, then uses a fixed spectator
## camera and samples the production animation clock once per output frame.

const FPS := 12
const FRAMES := 120
const ZOOM := 0.7
const WINDOW_SIZE := Vector2i(960, 540)


func run() -> void:
	if DisplayServer.get_name() == "headless":
		_fail_capture("requires a display so the game paints clouds")
		return
	var output := OS.get_environment("FLAGORIA_CLOUD_FRAMES")
	if output.is_empty() or DirAccess.make_dir_recursive_absolute(output) != OK:
		_fail_capture("set FLAGORIA_CLOUD_FRAMES to a writable output directory")
		return
	root.size = WINDOW_SIZE
	if not await start_game():
		return
	var map = current_scene.get_node(WORLD_MAP)
	var camera := hero().get_node("Camera2D") as Camera2D
	var spawn: Vector2i = map.local_to_map(map.to_local(hero().global_position))
	current_scene.get_node("CanvasLayer1").hide()
	var clock := root.get_node("DayNight")
	clock.seek_phase("day")
	map.set_process(false)

	# Paint enough terrain to pan from spawn while keeping the full view filled.
	map.chunk_width = 164
	map.chunk_height = 128
	map.generate_chunk(map.map_to_local(spawn))
	var motion := map.get_node("CloudMotion") as CloudMotion
	motion.show_at_time(0.0)
	var center := _shore_view(map, spawn, motion)
	camera.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	camera.top_level = true
	camera.zoom = Vector2.ONE * ZOOM
	camera.global_position = map.to_global(map.map_to_local(center)).round()
	camera.make_current()
	camera.reset_smoothing()
	camera.force_update_scroll()
	if not await wait_until(
		func() -> bool:
			return (
				is_equal_approx(root.get_canvas_transform().get_scale().x, ZOOM)
				and camera.get_screen_center_position().is_equal_approx(camera.global_position)
			),
		2.0
	):
		_fail_capture(
			(
				"camera did not reach the preview pose (zoom %s, center %s)"
				% [root.get_canvas_transform().get_scale(), camera.get_screen_center_position()]
			)
		)
		return
	paused = true

	var minimum_visible := FRAMES
	for frame in FRAMES:
		motion.show_at_time(float(frame) / FPS)
		minimum_visible = mini(minimum_visible, motion.visible_cloud_count())
		if minimum_visible < 3:
			_fail_capture("only %d visible clouds at frame %d" % [minimum_visible, frame])
			return
		await RenderingServer.frame_post_draw
		var image := root.get_texture().get_image()
		var error := image.save_png(output.path_join("frame_%03d.png" % frame))
		if frame == 0:
			error = maxi(error, image.save_png(output.path_join("cloud-day.png")))
		elif frame == FRAMES / 2:
			error = maxi(error, image.save_png(output.path_join("cloud-drift.png")))
		if error != OK:
			_fail_capture("could not save frame %d" % frame)
			return
		await process_frame
	motion.show_at_time(0.0)
	clock.seek_phase("night")
	await RenderingServer.frame_post_draw
	if root.get_texture().get_image().save_png(output.path_join("cloud-night.png")) != OK:
		_fail_capture("could not save the night still")
		return
	print(
		(
			"CLOUD_CAPTURE_DONE %d frames, at least %d visible clouds per frame"
			% [FRAMES, minimum_visible]
		)
	)
	print(
		(
			"World-pixel drift per 10 s before wrap: far %.1f, near %.1f"
			% [CloudMotion.FAR_SPEED * 10.0, CloudMotion.NEAR_SPEED * 10.0]
		)
	)
	done(true)


func _shore_view(map: TileMap, spawn: Vector2i, motion: CloudMotion) -> Vector2i:
	var far: Array[Vector2i] = []
	var near: Array[Vector2i] = []
	for sprite: Sprite2D in motion.get_children():
		var cell := map.local_to_map(sprite.position)
		if (
			map.is_open_sea(cell)
			and map.is_open_sea(
				map.local_to_map(sprite.position + sprite.region_rect.size - Vector2.ONE)
			)
		):
			if sprite.z_index == -1:
				near.append(cell)
			else:
				far.append(cell)
	var best := spawn
	var best_score := -INF
	for y in range(-36, 37, 2):
		for x in range(-42, 43, 2):
			var center := spawn + Vector2i(x, y)
			var bounds := Rect2i(center - Vector2i(21, 12), Vector2i(42, 24))
			var land := 0
			for row in range(bounds.position.y, bounds.end.y, 3):
				for column in range(bounds.position.x, bounds.end.x, 3):
					if not map.is_open_sea(Vector2i(column, row)):
						land += 1
			var score := -absf(land - 24.0)
			for cell in far:
				if bounds.grow(-3).has_point(cell):
					score += 1.0
			for cell in near:
				if bounds.grow(-3).has_point(cell):
					score += 2.0
			if score > best_score:
				best_score = score
				best = center
	return best


func _fail_capture(message: String) -> void:
	printerr("Cloud capture failed: " + message)
	done(false)
