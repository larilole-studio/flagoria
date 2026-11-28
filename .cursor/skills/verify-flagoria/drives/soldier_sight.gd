## fixture
extends "res://.cursor/skills/verify-flagoria/bin/drive_base.gd"
## launch: --seed 11

const BARRACKS := "barracks"


func run() -> void:
	if not await start_game():
		return
	var map: TileMap = current_scene.get_node(WORLD_MAP)
	var troops: SoldierRequests = current_scene.get_node("World/Soldiers")
	var buildings: BuildingHealth = current_scene.get_node("World/BuildingHealth")
	var mobs: MobSpawner = current_scene.get_node("World/Mobs")
	mobs.clear_mobs()
	mobs.set_physics_process(false)
	var center := map.local_to_map(map.to_local(hero().global_position))
	var layout := _layout(map, center)
	if layout.is_empty():
		printerr("soldier_sight: no clear lane")
		done(false)
		return
	var from := _center(map, layout[0])
	var post := _center(map, layout[1])
	var attacker := await _duel(troops, from, post)
	if attacker == null:
		done(false)
		return
	done(await _attack_barracks(map, buildings, attacker, from, layout[2]))


func _duel(troops: SoldierRequests, from: Vector2, post: Vector2) -> Soldier:
	step("enemy soldiers engage from beyond melee range")
	troops.spawn_saved(
		{"name": "sight_attacker", "owner": 1, "pos": from, "order": "hold", "hp": 20}
	)
	troops.spawn_saved({"name": "sight_defender", "owner": 2, "pos": post, "order": "hold"})
	var attacker: Soldier = troops.get_node("sight_attacker")
	var defender: Soldier = troops.get_node("sight_defender")
	var full := defender.hp
	if not await wait_until(func() -> bool: return defender.hp < full, 5.0):
		printerr("soldier_sight: defender was not hit")
		return null
	await snapshot("soldiers-engaged")
	if not await wait_until(func() -> bool: return not is_instance_valid(defender), 8.0):
		printerr("soldier_sight: defender survived")
		return null
	if not await wait_until(func() -> bool: return attacker.position.distance_to(from) <= 2, 5.0):
		printerr("soldier_sight: attacker did not return")
		return null
	return attacker


func _attack_barracks(
	map: TileMap, buildings: BuildingHealth, attacker: Soldier, from: Vector2, anchor: Vector2i
) -> bool:
	step("attack an enemy barracks and return when it falls")
	var id: int = map.place_structure(StructurePlacer.load_named(BARRACKS), anchor, 2)
	if id <= 0:
		printerr("soldier_sight: enemy barracks placement failed")
		return false
	var maximum := buildings.hp(id)
	var damaged := await wait_until(func() -> bool: return buildings.hp(id) <= maximum - 3, 7.0)
	await snapshot("enemy-barracks-hit")
	if not damaged:
		printerr("soldier_sight: barracks remained intact at %s" % buildings.hp(id))
		return false
	# Finish the fixture through the same host damage seam to keep the drive short.
	buildings.host_damage(id, maximum, 1)
	var returned := await wait_until(
		func() -> bool: return attacker.position.distance_to(from) <= 2.0, 5.0
	)
	await snapshot("returned-to-post")
	return returned


func _center(map: TileMap, cell: Vector2i) -> Vector2:
	return map.to_global(map.map_to_local(cell))


func _layout(map: TileMap, origin: Vector2i) -> Array[Vector2i]:
	var barracks := StructurePlacer.load_named(BARRACKS)
	for y in range(-6, 2):
		for x in range(-8, 4):
			var start := origin + Vector2i(x, y)
			var anchor := start + Vector2i(5, 0)
			if not map.can_place_structure(barracks, anchor).is_empty():
				continue
			var clear := true
			for dx in range(5):
				var cell := start + Vector2i(dx, 0)
				if not map.predicted_clear(cell) or map.has_wall(cell):
					clear = false
					break
			if clear and map.is_drawn(start) and map.is_drawn(anchor):
				return [start, start + Vector2i(3, 0), anchor]
	return []
