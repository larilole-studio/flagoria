extends "res://.cursor/skills/verify-flagoria/bin/drive_base.gd"
## The host's castle is a player-owned flag tower. A body named "2" stands in
## range, then out of range. Snapshots: tower-in-range, tower-out-of-range.


func run() -> void:
	step("start")
	if not await start_game():
		return
	for node in current_scene.get_node("World/Mobs").get_children():
		if node is Mob:
			node.set_physics_process(false)
			node.global_position = Vector2(100000, 100000)
	var map: TileMap = current_scene.get_node(WORLD_MAP)
	var flag := _castle_flag(map)
	if flag == Vector2i.ZERO:
		printerr("defense tower: the host castle has no flag")
		done(false)
		return
	var centre: Vector2 = map.to_global(map.map_to_local(flag))
	var foe := _foe()
	# The gate is south of the flag. 50 px is the clear gate-front cell, inside
	# the 80 px range. The host starts on that same cell and would block the
	# ray, so step them east of the shot. 140 px is outside the range.
	var host := hero()
	host.global_position = centre + Vector2(36, 70)
	foe.global_position = centre + Vector2(0, 50)
	var health: PlayerHealth = foe.get_node("Health")
	var before := health.health
	step("in-range")
	if not await wait_until(func() -> bool: return health.health < before, 4.0):
		printerr("defense tower: the body in range did not lose health (%s)" % health.health)
		done(false)
		return
	await snapshot("tower-in-range")
	step("out-of-range")
	var seen := health.health
	foe.global_position = centre + Vector2(0, 140)
	var started := Time.get_ticks_msec()
	var dropped := false
	if not await wait_until(func() -> bool:
		if health.health < seen:
			dropped = true
			return true
		return Time.get_ticks_msec() - started >= 2000, 5.0):
		printerr("defense tower: the out-of-range wait did not finish")
		done(false)
		return
	if dropped:
		printerr("defense tower: health fell outside range to %s" % health.health)
		done(false)
		return
	await snapshot("tower-out-of-range")
	done(true)


func _castle_flag(map: TileMap) -> Vector2i:
	var placed: Dictionary = map.placed_structures()
	var towers: Dictionary = map._structures.towers()
	for id in placed:
		if str(placed[id]["name"]) == "castle" and int(placed[id]["owner"]) == 1 and towers.has(id):
			return towers[id][0]
	return Vector2i.ZERO


func _foe() -> CharacterBody2D:
	## Offline the host is body "1". This body is the other player the tower shoots.
	var body: CharacterBody2D = load("res://Player/character_body_2d.tscn").instantiate()
	body.name = "2"
	body.set_multiplayer_authority(2)
	var cam := body.get_node_or_null("Camera2D") as Camera2D
	if cam:
		cam.enabled = false
	current_scene.get_node("World").add_child(body)
	body.set_physics_process(false)
	return body
