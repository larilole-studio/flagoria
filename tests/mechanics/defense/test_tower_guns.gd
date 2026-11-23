extends "res://tests/helpers/test_helpers.gd"
## Defense towers (#37). One host-owned wooden tower, TowerGuns.tick by hand
## with physics ticks off, so the cooldown is the only timer. PlayerHealth
## invulnerability is 0 here: the gun's cooldown is what the second tick measures.


func _guns(label: String) -> Dictionary:
	## {scene, world, guns, id, centre} with a host-owned tower_wood on clear
	## land, or {} after a FAIL line.
	var scene = load("res://flagoria_main.tscn").instantiate()
	root.add_child(scene)
	var guns: TowerGuns = scene.get_node("World/TowerGuns")
	guns.set_physics_process(false)
	var world = scene.get_node("World/worldMap")
	var structure: Structure = StructurePlacer.load_named("tower_wood")
	for sv in [11, 42, 99]:
		world.apply_map_params(_spawn_params(sv, 0.0))
		world.generate_chunk(Vector2(0, 0))
		for cell: Vector2i in world.get_used_cells(0):
			var cells: Array = StructurePlacer.footprint(structure, cell).keys()
			if not cells.all(
				func(c): return world.get_cell_source_id(0, c) != -1 and world.predicted_clear(c)
			):
				continue
			# tower_wood's flag is one cell north of the anchor. The shot needs
			# clear land just outside the ring, so the wall test has a corridor.
			var flag_guess: Vector2i = cell + Vector2i(0, -1)
			var step := Vector2i.ZERO
			for candidate in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]:
				var open := true
				for i in range(2, 5):
					if not world.predicted_clear(flag_guess + candidate * i):
						open = false
						break
				if open:
					step = candidate
					break
			if step == Vector2i.ZERO:
				continue
			var id: int = world.place_structure(structure, cell, 1)
			var flag: Vector2i = world._structures.towers()[id][0]
			return {
				"scene": scene,
				"world": world,
				"guns": guns,
				"id": id,
				"centre": world.to_global(world.map_to_local(flag)),
				"flag": flag,
				"dir": Vector2(step),
			}
	printerr("FAIL %s: no clear tower_wood spot near the origin on seeds 11, 42, 99" % label)
	scene.queue_free()
	return {}


func _body(t: Dictionary, peer: int, offset: Vector2) -> CharacterBody2D:
	var body := _contact_player(t["scene"].get_node("World"))
	body.name = str(peer)
	body.global_position = t["centre"] + offset
	var health: PlayerHealth = body.get_node("Health")
	health.invulnerable_time = 0.0
	return body


func _health(body: Node) -> int:
	return (body.get_node("Health") as PlayerHealth).health


func _test_tower_guns() -> int:
	## Owner ignored even when closer. Outside range, no shot. Two ticks inside
	## the cooldown drop health once. A wall between the ring and the target
	## suppresses the shot and does not spend the cooldown. Owners 0 and -1
	## do not shoot. Time cost: ~0.4 s.
	print("-- test_tower_guns")
	var game = root.get_node("GameSettings")
	game.tower_range = game.TOWER_RANGE_DEFAULT
	game.tower_damage = game.TOWER_DAMAGE_DEFAULT
	game.tower_cooldown = game.TOWER_COOLDOWN_DEFAULT
	var t := _guns("tower_guns")
	if t.is_empty():
		return 1
	await physics_frame  # the ring's collision is in the space before the first ray
	var fail := 0
	var dir: Vector2 = t["dir"]
	var owner := _body(t, 1, dir * 10.0)
	var enemy := _body(t, 2, dir * 40.0)
	# A real player body is on the terrain layer. The shot must still land.
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(8, 10)
	shape.shape = rect
	enemy.add_child(shape)
	await physics_frame
	var space: PhysicsDirectSpaceState2D = t["scene"].get_world_2d().direct_space_state
	var lead: Vector2 = t["centre"] + dir * TowerGuns.LOS_LEAD
	if AttackAim.clear_shot(space, lead, enemy.global_position):
		printerr("FAIL tower_guns: the target body did not block an unexcluded ray")
		fail += 1
	var guns: TowerGuns = t["guns"]
	guns.tick(0.05)
	if _health(owner) != 6 or _health(enemy) != 5:
		printerr(
			(
				"FAIL tower_guns: closer owner %s, enemy %s, want 6 and 5"
				% [_health(owner), _health(enemy)]
			)
		)
		fail += 1
	guns.tick(0.05)
	if _health(enemy) != 5:
		printerr(
			(
				"FAIL tower_guns: second tick inside the cooldown left health %s, want 5"
				% _health(enemy)
			)
		)
		fail += 1
	enemy.global_position = t["centre"] + dir * 100.0
	guns.tick(2.0)
	if _health(enemy) != 5:
		printerr("FAIL tower_guns: outside range health %s, want 5" % _health(enemy))
		fail += 1
	enemy.global_position = t["centre"] + dir * 64.0
	var wall: Vector2i = t["flag"] + Vector2i(dir) * 2
	t["world"].generate_chunk(t["world"].map_to_local(wall))
	var blocked: Array[Vector2i] = [wall]
	if not t["world"].place_wall_cells(blocked):
		printerr("FAIL tower_guns: could not place a wall at %s" % wall)
		fail += 1
	else:
		await physics_frame
		guns.tick(0.05)
		if _health(enemy) != 5:
			printerr("FAIL tower_guns: wall let a shot through, health %s" % _health(enemy))
			fail += 1
		t["world"]._walls.erase_cells(blocked)
		await physics_frame
		guns.tick(0.05)
		if _health(enemy) != 4:
			printerr(
				(
					"FAIL tower_guns: blocked ray spent the cooldown, health %s, want 4"
					% _health(enemy)
				)
			)
			fail += 1
	(enemy.get_node("Health") as PlayerHealth).set_health_now(6)
	t["world"]._structures.set_owner(t["id"], 0)
	guns.tick(2.0)
	if _health(enemy) != 6:
		printerr("FAIL tower_guns: neutral owner shot, health %s" % _health(enemy))
		fail += 1
	t["world"]._structures.set_owner(t["id"], StructurePlacer.OWNER_MOBS)
	guns.tick(0.05)
	if _health(enemy) != 6 or _health(owner) != 6:
		printerr(
			"FAIL tower_guns: mob owner shot, enemy %s owner %s" % [_health(enemy), _health(owner)]
		)
		fail += 1
	t["scene"].queue_free()
	if fail == 0:
		print("PASS test_tower_guns")
	return fail
