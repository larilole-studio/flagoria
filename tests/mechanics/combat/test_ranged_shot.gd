extends "res://tests/helpers/test_helpers.gd"
## One bow shot: the segment, terrain, and a second apply that does not land.
## Time cost: about 0.5 s in tools/verify.sh.


func _paint_pad(world, cells: Array) -> void:
	world.set_process(false)
	world.clear()
	var seen := {}
	for c in cells:
		for d in [Vector2i.ZERO, Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
				Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1),
				Vector2i(2, 0), Vector2i(-2, 0), Vector2i(3, 0), Vector2i(-3, 0)]:
			var n: Vector2i = c + d
			if seen.has(n):
				continue
			seen[n] = true
			world.set_cell(0, n, TileCatalog.SOURCE_ID, TileCatalog.GRASS_A)


func _test_ranged_shot() -> int:
	## A mob in front is hit once. A target past RANGE is a miss. A wall
	## returns terrain and leaves the mob. The shooter is not a target.
	## A second apply during HURT or invulnerability returns false.
	print("-- test_ranged_shot")
	var fail := 0
	await process_frame
	var scene = load("res://flagoria_main.tscn").instantiate()
	root.add_child(scene)
	var world = scene.get_node("World/worldMap")
	var player = load("res://Scripts/player/character_body_2d.tscn").instantiate()
	player.name = "1"
	scene.get_node("World").add_child(player)
	player.set_physics_process(false)
	var mob: Mob = load("res://Mobs/mob.tscn").instantiate()
	mob.mob_type = "slime" if "slime" in MobCatalog.names() else MobCatalog.names()[0]
	scene.get_node("World/Mobs").add_child(mob)
	mob.set_physics_process(false)
	mob.hp = 5
	var mid := Vector2i(8, 8)
	_paint_pad(world, [mid])
	var mid_c: Vector2 = world.to_global(world.map_to_local(mid))
	player.position = mid_c + Vector2(-40, 0)
	mob.position = mid_c + Vector2(40, 0)
	await physics_frame
	await physics_frame
	var origin: Vector2 = player.global_position + AttackAim.ORIGIN
	var hit: Dictionary = RangedShot.fly(world, origin, Vector2.RIGHT, [mob], [player], player)
	if hit["kind"] != "mob" or hit.get("target") != mob:
		printerr("FAIL ranged_shot mob in front: %s" % hit.get("kind"))
		fail += 1
	elif not RangedShot.apply(hit, 1) or mob.hp != 4 or mob.state != Mob.State.HURT:
		printerr("FAIL ranged_shot first apply hp %s state %s" % [mob.hp, mob.state])
		fail += 1
	elif RangedShot.apply(hit, 1) or mob.hp != 4:
		printerr("FAIL ranged_shot second apply during HURT hp %s" % mob.hp)
		fail += 1

	mob.position = player.position + Vector2(RangedShot.RANGE + 40.0, 0)
	hit = RangedShot.fly(world, origin, Vector2.RIGHT, [mob], [player], player)
	var miss_end: Vector2 = hit.get("end", origin)
	if hit["kind"] != "miss" or absf(origin.distance_to(miss_end) - RangedShot.RANGE) > 0.05:
		printerr("FAIL ranged_shot miss at RANGE: kind %s distance %s" % [hit.get("kind"), origin.distance_to(miss_end)])
		fail += 1

	var hp_wall: int = mob.hp
	mob.position = mid_c + Vector2(40, 0)
	world.set_cell(1, mid, TileCatalog.SOURCE_ID, TileCatalog.PALISADE_H)
	await physics_frame
	await physics_frame
	hit = RangedShot.fly(world, origin, Vector2.RIGHT, [mob], [player], player)
	if hit["kind"] != "terrain" or mob.hp != hp_wall:
		printerr("FAIL ranged_shot wall: kind %s hp %s" % [hit.get("kind"), mob.hp])
		fail += 1

	hit = RangedShot.fly(world, origin, Vector2.RIGHT, [], [player], player)
	if hit["kind"] == "player" or hit.get("target") == player:
		printerr("FAIL ranged_shot shooter was not skipped (%s)" % hit.get("kind"))
		fail += 1

	world.erase_cell(1, mid)
	await physics_frame
	await physics_frame
	var other = load("res://Scripts/player/character_body_2d.tscn").instantiate()
	other.name = "2"
	scene.get_node("World").add_child(other)
	other.set_physics_process(false)
	other.position = player.position + Vector2(48, 0)
	hit = RangedShot.fly(world, origin, Vector2.RIGHT, [], [player, other], player)
	if hit["kind"] != "player" or hit.get("target") != other:
		printerr("FAIL ranged_shot player in front: %s" % hit.get("kind"))
		fail += 1
	elif not RangedShot.apply(hit, 1) or other.health.health != 5:
		printerr("FAIL ranged_shot player damage -> %s" % other.health.health)
		fail += 1
	elif RangedShot.apply(hit, 1) or other.health.health != 5:
		printerr("FAIL ranged_shot second apply during invulnerability -> %s" % other.health.health)
		fail += 1

	var shots: RangedShots = scene.get_node("World/RangedShots")
	other.health.set_health_now(0)
	if shots.resolve(2, other.global_position + AttackAim.ORIGIN, Vector2.UP) or shots.accepted != 0:
		printerr("FAIL ranged_shot dead sender was accepted")
		fail += 1
	var far: Vector2 = player.global_position + Vector2(RangedShots.ORIGIN_LIMIT + 1.0, 0)
	if shots.resolve(1, far, Vector2.UP) or shots.accepted != 0:
		printerr("FAIL ranged_shot origin past %s px was accepted" % RangedShots.ORIGIN_LIMIT)
		fail += 1
	var near: Vector2 = player.global_position + AttackAim.ORIGIN
	if not shots.resolve(1, near, Vector2.UP) or shots.accepted != 1:
		printerr("FAIL ranged_shot host did not accept a shot from the body (accepted %s)" % shots.accepted)
		fail += 1
	elif shots.resolve(1, near, Vector2.UP) or shots.accepted != 1:
		printerr("FAIL ranged_shot cooldown did not reject the next shot")
		fail += 1

	scene.queue_free()
	await process_frame
	if fail == 0:
		print("PASS test_ranged_shot")
	return fail
