extends "res://.cursor/skills/verify-flagoria/bin/drive_base.gd"
## launch: --seed 11
## Opening mobs around the host, then one mob standing in the spawn ring
## (features/mob-band.md). The drive only reads positions and walks.

const APPROACH_MS := 20000


func run() -> void:
	step("near")
	if not await start_game():
		return
	var map: TileMap = current_scene.get_node(WORLD_MAP)
	var ground := await wait_until(
		func() -> bool:
			var cell := map.local_to_map(map.to_local(hero().global_position))
			return map.get_cell_source_id(0, cell) != -1,
		5.0
	)
	await snapshot("band-near-hero")
	if not ground:
		printerr("mob band: the ground under the hero never drew")
		done(false)
		return
	step("ring")
	var mob := await _bring_ring_mob(map)
	if mob == null:
		printerr(
			(
				"mob band: no mob stayed in the %d..%d ring on screen"
				% [MobSpawner.SPAWN_MIN_RADIUS + 1, MobSpawner.SPAWN_MAX_RADIUS]
			)
		)
		done(false)
		return
	await snapshot("band-mob-in-ring")
	var dist := _apart(map, hero(), mob)
	var ok := (
		dist > MobSpawner.SPAWN_MIN_RADIUS and dist <= MobSpawner.SPAWN_MAX_RADIUS and mob.visible
	)
	if not ok:
		printerr("mob band: %s ended %d cells from the hero" % [mob.name, dist])
	else:
		print("mob band: %s is %d cells out" % [mob.name, dist])
	done(ok)


func _bring_ring_mob(map: TileMap) -> Mob:
	var listed := _list_mobs(map)
	print(
		(
			"mob band: %d mobs, nearest %s"
			% [listed.size(), listed[0] if not listed.is_empty() else "none"]
		)
	)
	var deadline := Time.get_ticks_msec() + APPROACH_MS
	var focus: Mob = null
	while Time.get_ticks_msec() < deadline:
		var mob := _pick_mob(map, focus)
		if mob == null:
			await physics_frame
			continue
		focus = mob
		var dist := _apart(map, hero(), mob)
		if (
			dist > MobSpawner.SPAWN_MIN_RADIUS
			and dist <= MobSpawner.SPAWN_MAX_RADIUS
			and mob.visible
			and _on_screen(mob)
		):
			return mob
		var toward := dist > MobSpawner.SPAWN_MIN_RADIUS + 1
		if not await _step_toward(mob, toward):
			focus = null
	return null


func _list_mobs(map: TileMap) -> Array:
	var rows: Array = []
	for child in current_scene.get_node("World/Mobs").get_children():
		if not (child is Mob) or (child as Node).is_queued_for_deletion():
			continue
		rows.append("%s:%d" % [child.name, _apart(map, hero(), child)])
	return rows


func _pick_mob(map: TileMap, focus: Mob) -> Mob:
	if is_instance_valid(focus) and _apart(map, hero(), focus) <= MobSpawner.SPAWN_MAX_RADIUS + 8:
		return focus
	var best: Mob = null
	var best_d := 100000
	for child in current_scene.get_node("World/Mobs").get_children():
		if not (child is Mob) or (child as Node).is_queued_for_deletion():
			continue
		var dist := _apart(map, hero(), child)
		var in_ring := dist > MobSpawner.SPAWN_MIN_RADIUS and dist <= MobSpawner.SPAWN_MAX_RADIUS
		# The camera shows about 12 cells up and down and more than that
		# sideways, so a mob already in the ring and off to the side is the
		# one that fits on screen.
		var score := dist if in_ring else 1000 + dist
		if score < best_d:
			best = child
			best_d = score
	return best


func _apart(map: TileMap, a: Node2D, b: Node2D) -> int:
	var ca := map.local_to_map(map.to_local(a.global_position))
	var cb := map.local_to_map(map.to_local(b.global_position))
	return maxi(absi(ca.x - cb.x), absi(ca.y - cb.y))


func _step_toward(mob: Node2D, toward: bool) -> bool:
	## Walk one cell toward the mob, or away when `toward` is false. A wall
	## gets a slide along it, then a step back through the castle gate.
	var delta := mob.global_position - hero().global_position
	if not toward:
		# Step sideways. The view is wider than it is tall, and walking
		# straight away can push a mob off the top or bottom.
		delta = Vector2(-1.0 if delta.x >= 0.0 else 1.0, 0.0)
	var before := hero().global_position
	for action in _actions_for(delta):
		await hold(action, 8)
		if hero().global_position.distance_to(before) > 2.0:
			return true
	return false


func _actions_for(delta: Vector2) -> Array:
	var horizontal := absf(delta.x) >= absf(delta.y)
	var primary := "ui_right" if delta.x > 0.0 else "ui_left"
	var other := "ui_down" if delta.y > 0.0 else "ui_up"
	if not horizontal:
		primary = "ui_down" if delta.y > 0.0 else "ui_up"
		other = "ui_right" if delta.x > 0.0 else "ui_left"
	var opposite := {
		"ui_right": "ui_left", "ui_left": "ui_right", "ui_up": "ui_down", "ui_down": "ui_up"
	}
	var back: String = opposite[primary]
	return [primary, other, back]


func _on_screen(mob: Node2D) -> bool:
	var cam := hero().get_node_or_null("Camera2D") as Camera2D
	if cam == null:
		return false
	var view := root.get_visible_rect().size
	var size := view / cam.zoom
	var center := cam.get_screen_center_position()
	var margin := Vector2(24, 24)
	var rect := Rect2(center - size * 0.5 + margin, size - margin * 2.0)
	return rect.has_point(mob.global_position)
