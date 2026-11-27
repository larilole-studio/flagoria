extends "res://tests/helpers/test_helpers.gd"
## Host throw and blast geometry. Time cost: about 1.5 s.

const PLAYER := preload("res://Scripts/player/character_body_2d.tscn")
const MOB := preload("res://Mobs/mob.tscn")
const SOLDIER := preload("res://Mobs/soldier.tscn")
const WorldMap := preload("res://Scripts/world/TileMap.gd")


func _test_bomb_shot() -> int:
	print("-- test_bomb_shot")
	var scene := mount_main_scene()
	var world := scene.get_node("World")
	world.get_node("TowerGuns").set_physics_process(false)
	var map := world.get_node("worldMap") as WorldMap
	map.set_process(false)
	var bombs := world.get_node("BombThrows") as BombThrows
	var landing_cell := Vector2i(15, 8)
	var landing := map.to_global(map.map_to_local(landing_cell))
	var origin := landing - Vector2(160, 0)
	var thrower := _spawn(PLAYER, world, origin - AttackAim.ORIGIN, "1")
	var target := _spawn(PLAYER, world, landing + Vector2(40, 0), "2")
	var outside := _spawn(MOB, world.get_node("Mobs"), landing + Vector2(0, -25)) as Mob
	var inside := _spawn(MOB, world.get_node("Mobs"), landing + Vector2(0, -24)) as Mob
	var enemy := _spawn(SOLDIER, world.get_node("Soldiers"), landing + Vector2(-16, 0)) as Soldier
	var ally := _spawn(SOLDIER, world.get_node("Soldiers"), landing) as Soldier
	outside.hp = 5
	inside.hp = 5
	enemy.owner_peer = 2
	enemy.hp = 5
	ally.owner_peer = 1
	ally.hp = 5

	var flight_wall := Vector2i(10, 8)
	var blast_wall := Vector2i(15, 9)
	var outside_wall := Vector2i(15, 10)
	var own_tower := Vector2i(13, 8)
	var enemy_castle := Vector2i(19, 8)
	map.replace_structures([["tower_wood", 1, own_tower], ["castle", 2, enemy_castle, 0, 2, true]])
	map.replace_wall_cells_from_host([flight_wall, blast_wall, outside_wall])
	map.set_cell(1, flight_wall, TileCatalog.SOURCE_ID, TileCatalog.PALISADE_H)
	await physics_frame
	await physics_frame

	var fail := 0
	if (
		BombShot.contains(Vector2.ZERO, 40.0, Vector2(0.0, -40.0))
		or not BombShot.contains(Vector2.ZERO, 40.0, Vector2(40.0, 0.0))
		or not is_equal_approx(BombShot.travel_seconds(160.0), 0.4)
		or BombShot.arc_point(Vector2.ZERO, Vector2(160.0, 0.0), 0.5) != Vector2(80.0, -28.0)
	):
		printerr("FAIL bomb_shot: ellipse axes or default flight")
		fail += 1

	map.archipelago_spacing = 10
	map.archipelago_world_extent = 14
	if (
		bombs.resolve(1, origin, Vector2.RIGHT)
		or bombs.resolve(1, origin + Vector2(32, 0), Vector2.LEFT)
		or bombs.resolve(1, origin, Vector2(INF, 0))
	):
		printerr("FAIL bomb_shot: accepted an invalid landing, origin, or direction")
		fail += 1
	map.archipelago_world_extent = 32
	target.health.set_health_now(0)
	if bombs.resolve(2, target.global_position, Vector2.LEFT):
		printerr("FAIL bomb_shot: a dead player was allowed to throw")
		fail += 1
	target.health.set_health_now(6)

	var launched := Time.get_ticks_msec()
	if not bombs.resolve(1, origin, Vector2.RIGHT) or bombs.resolve(1, origin, Vector2.RIGHT):
		printerr("FAIL bomb_shot: valid throw or cooldown rejected incorrectly")
		fail += 1
	# The thrower steps into the landing area during flight.
	thrower.position = landing
	if not await wait_until(func() -> bool: return bombs.has_phase(BombThrows.Phase.FUSE), 1500):
		printerr("FAIL bomb_shot: pot did not land")
		fail += 1
	elif target.health.health != 6 or enemy.hp != 5 or map.wall_hp(blast_wall) != 3:
		printerr("FAIL bomb_shot: applied damage before the fuse elapsed")
		fail += 1
	if not await wait_until(func() -> bool: return target.health.health == 4, 2000):
		printerr("FAIL bomb_shot: player beyond the flight wall took no damage")
		fail += 1
	elif Time.get_ticks_msec() - launched < 1400:
		printerr("FAIL bomb_shot: damage landed before flight and the full fuse")
		fail += 1
	var health := [thrower.health.health, outside.hp, inside.hp, enemy.hp, ally.hp]
	if health != [6, 5, 3, 3, 5]:
		printerr(
			"FAIL bomb_shot: health of thrower, outside/inside mob, enemy/ally soldier: ", health
		)
		fail += 1
	if (
		map.wall_hp(flight_wall) != 3
		or map.wall_hp(blast_wall) != 1
		or map.wall_hp(outside_wall) != 3
	):
		printerr("FAIL bomb_shot: walls did not receive exactly two hits inside the ellipse")
		fail += 1
	if (
		map.structure_placement_at(own_tower).is_empty()
		or map.structure_placement_at(enemy_castle).is_empty()
	):
		printerr("FAIL bomb_shot: a named placement was removed; this slice only damages palisade walls")
		fail += 1

	scene.queue_free()
	await process_frame
	if fail == 0:
		print("PASS test_bomb_shot")
	return fail


func _spawn(resource: PackedScene, parent: Node, point: Vector2, name := "") -> Node2D:
	var actor := resource.instantiate() as Node2D
	if not name.is_empty():
		actor.name = name
	parent.add_child(actor)
	actor.global_position = point
	actor.set_physics_process(false)
	return actor
