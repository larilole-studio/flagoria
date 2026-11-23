extends "res://.cursor/skills/verify-flagoria/bin/drive_base.gd"
## launch: --seed 11
## Night on seed 11. The hero stands outside the starting castle. Both carry
## a full gold pool, and the ground between the pools is darker than either
## centre. The cycle is 10 minutes, so the drive seeks the night hold.


func run() -> void:
	if not await start_game():
		return
	var clock := root.get_node("DayNight")
	var lights: Node = root.get_node("DayNight/NightLights")
	step("night-lights")
	clock.seek_phase("night")
	var shown: bool = await wait_until(
		func() -> bool:
			return lights.has_method("active_count") and int(lights.active_count()) >= 2,
		3.0
	)
	await process_frame
	await RenderingServer.frame_post_draw
	var player_light := _light_scale(lights, 1.0)
	var castle_light := _light_scale(lights, 1.5)
	var energies := (
		player_light != null
		and castle_light != null
		and is_equal_approx(player_light.energy, 1.1)
		and is_equal_approx(castle_light.energy, 1.2)
	)
	var darker := false
	if player_light != null and castle_light != null:
		darker = _between_is_darker(player_light.global_position, castle_light.global_position)
	await snapshot("night-lights")
	print("night_lights: shown=%s energies=%s darker=%s" % [shown, energies, darker])
	done(shown and energies and darker)


func _light_scale(lights: Node, scale: float) -> PointLight2D:
	for light in lights.active_lights():
		if is_equal_approx(light.texture_scale, scale):
			return light
	return null


func _between_is_darker(player_at: Vector2, castle_at: Vector2) -> bool:
	## The flag and the hero sit on the light centres and are darker than the
	## pools around them. Compare each pool's brightest ground with the
	## darkest stretch of ground between the two centres (the gate wall).
	var image := root.get_texture().get_image()
	if image == null or image.is_empty():
		printerr("night_lights: no viewport image")
		return false
	var player_px := _image_px(player_at)
	var castle_px := _image_px(castle_at)
	var player_l := _peak(image, player_px, 48)
	var castle_l := _peak(image, castle_px, 48)
	var between := _segment_min(image, castle_px, player_px)
	print("night_lights: lum player=%.3f castle=%.3f between=%.3f" % [player_l, castle_l, between])
	return player_l > between + 0.08 and castle_l > between + 0.08


func _peak(image: Image, px: Vector2, radius: int) -> float:
	var best := 0.0
	var x := int(px.x)
	var y := int(px.y)
	for dy in range(-radius, radius + 1, 4):
		for dx in range(-radius, radius + 1, 4):
			if dx * dx + dy * dy > radius * radius:
				continue
			best = maxf(best, _luminance(image, Vector2(x + dx, y + dy)))
	return best


func _segment_min(image: Image, a: Vector2, b: Vector2) -> float:
	## Skip the ends, where the flag and the hero sit, and keep the darker
	## ground between the pools.
	var darkest := 1.0
	for i in range(4, 13):
		darkest = minf(darkest, _luminance(image, a.lerp(b, float(i) / 16.0)))
	return darkest


func _image_px(world_pos: Vector2) -> Vector2:
	## The viewport image is the stretched window, so use window pixels.
	var item := current_scene.get_node("World") as CanvasItem
	return to_window(item, item.to_local(world_pos))


func _luminance(image: Image, px: Vector2) -> float:
	var acc := 0.0
	var n := 0
	var x := int(px.x)
	var y := int(px.y)
	for dy in range(-2, 3):
		for dx in range(-2, 3):
			var sx := clampi(x + dx, 0, image.get_width() - 1)
			var sy := clampi(y + dy, 0, image.get_height() - 1)
			var c := image.get_pixel(sx, sy)
			acc += 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b
			n += 1
	return acc / float(n)
