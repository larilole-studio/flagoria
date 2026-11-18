extends "res://.cursor/skills/verify-flagoria/bin/drive_base.gd"
## launch: --seed 5
## Day, then night, on one map. The host ticks the ambient band once at
## each hold. The night shot has more mobs. The 45 s band is not waited out.


const RATE := 0.5
const FRAME_ZOOMS: Array[float] = [0.525, 0.42, 0.34]
const RATE_SLIDER := "CanvasLayer2/MainMenu/MarginContainer/VBoxContainer/MobRateRow/MobRate"


func run() -> void:
	if change_scene_to_file(MAIN) != OK:
		_fail("cannot load " + MAIN)
		return
	if not await wait_until(func() -> bool:
			return current_scene != null and current_scene.has_node(HOST_BUTTON), START_TIMEOUT_S):
		_fail("no " + HOST_BUTTON)
		return
	step("rate")
	var slider: HSlider = current_scene.get_node(RATE_SLIDER)
	slider.value = RATE
	await click(HOST_BUTTON)
	if not await wait_until(func() -> bool: return hero() != null, START_TIMEOUT_S):
		_fail("no local hero under World after clicking Host")
		return
	print("VERIFY_READY pid=%d scene=%s" % [OS.get_process_id(), MAIN])
	var clock := root.get_node("DayNight")
	var mobs: MobSpawner = current_scene.get_node("World/Mobs")
	# One tick per phase, from this drive. The automatic band stays on its timer.
	mobs.ambient_delay_ms = 120000
	step("inland")
	await _walk_inland()
	step("day-mobs")
	clock.seek_phase("day")
	mobs.run_ambient_tick()
	await _frame_close(1)
	var day_n := _mob_count()
	var day_seen := _on_screen_count()
	await snapshot("day-mobs")
	step("night-mobs")
	clock.seek_phase("night")
	mobs.run_ambient_tick()
	await _frame_close(day_seen + 1)
	var night_n := _mob_count()
	var night_seen := _on_screen_count()
	await snapshot("night-mobs")
	var scale := float(clock.call("spawn_scale"))
	var ok := str(clock.phase()) == "night" and is_equal_approx(scale, 2.0) \
			and night_n > day_n and night_seen > day_seen
	print("night mobs: day=%d night=%d on_screen %d -> %d phase=%s scale=%s zoom=%s" % [day_n, night_n, day_seen, night_seen, clock.phase(), scale, _zoom()])
	if not ok:
		printerr("night mobs: night did not show more mobs")
	done(ok)


func _walk_inland() -> void:
	## The host spawn is on the beach. Walk onto the grass so the ring is land.
	for _i in 6:
		var before := hero().position
		await hold("ui_up", 24)
		if hero().position.distance_to(before) < 4.0:
			await hold("ui_left", 16)
			await hold("ui_up", 24)


func _frame_close(want: int) -> void:
	## Stand where the most mobs fit in the shot, widest legal zoom first.
	## One mob per 32-cell chunk, so a second mob can sit past the first zoom.
	var points := _mob_points()
	var cam := hero().get_node_or_null("Camera2D") as Camera2D
	var center := hero().global_position
	if cam != null and not points.is_empty():
		for z in FRAME_ZOOMS:
			cam.zoom = Vector2(z, z)
			var picked := _pick_center(points, _view_size() * 0.72)
			center = picked["center"] as Vector2
			if int(picked["n"]) >= want:
				break
	await _stand(center)
	_reveal()
	await _stand(center)


func _stand(at: Vector2) -> void:
	for _i in 3:
		hero().global_position = at
		hero().velocity = Vector2.ZERO
		await process_frame


func _pick_center(points: Array, view: Vector2) -> Dictionary:
	var best_n := 0
	var best := hero().global_position
	var candidates: Array[Vector2] = []
	for i in points.size():
		var a: Vector2 = points[i]
		candidates.append(a)
		for j in range(i + 1, points.size()):
			var b: Vector2 = points[j]
			candidates.append((a + b) * 0.5)
	var half := view * 0.5
	for cand in candidates:
		var group: Array[Vector2] = []
		for p in points:
			var q: Vector2 = p
			if absf(q.x - cand.x) <= half.x and absf(q.y - cand.y) <= half.y:
				group.append(q)
		if group.size() <= best_n:
			continue
		var lo := group[0]
		var hi := group[0]
		for q in group:
			lo = lo.min(q)
			hi = hi.max(q)
		var mid := (lo + hi) * 0.5
		if group.size() == 1:
			mid += Vector2(64, 0)
		best_n = group.size()
		best = mid
	return {"center": best, "n": best_n}


func _view_size() -> Vector2:
	var cam := hero().get_node("Camera2D") as Camera2D
	return root.get_visible_rect().size / cam.zoom


func _mob_points() -> Array:
	var out: Array[Vector2] = []
	for child in current_scene.get_node("World/Mobs").get_children():
		if child is Mob and not (child as Node).is_queued_for_deletion():
			out.append((child as Node2D).global_position)
	return out


func _reveal() -> void:
	## A mob stays hidden until the ground tile under it exists.
	var map: TileMap = current_scene.get_node(WORLD_MAP)
	var origin := map.local_to_map(map.to_local(hero().global_position))
	for off in [Vector2i.ZERO, Vector2i(32, 0), Vector2i(-32, 0), Vector2i(0, 32), Vector2i(0, -32)]:
		map.generate_chunk(map.map_to_local(origin + off))
	for child in current_scene.get_node("World/Mobs").get_children():
		if child is Mob and not (child as Node).is_queued_for_deletion():
			map.generate_chunk((child as Node2D).global_position)


func _zoom() -> Vector2:
	var cam := hero().get_node_or_null("Camera2D") as Camera2D
	if cam == null:
		return Vector2.ZERO
	return cam.zoom


func _mob_count() -> int:
	var n := 0
	for child in current_scene.get_node("World/Mobs").get_children():
		if child is Mob and not (child as Node).is_queued_for_deletion():
			n += 1
	return n


func _on_screen_count() -> int:
	var n := 0
	for child in current_scene.get_node("World/Mobs").get_children():
		if child is Mob and child.visible and not (child as Node).is_queued_for_deletion() and _in_view(child):
			n += 1
	return n


func _in_view(mob: Node2D) -> bool:
	var cam := hero().get_node_or_null("Camera2D") as Camera2D
	if cam == null:
		return false
	var size := root.get_visible_rect().size / cam.zoom
	var center := cam.get_screen_center_position()
	return Rect2(center - size * 0.5, size).has_point(mob.global_position)
