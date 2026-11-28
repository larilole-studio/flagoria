## fixture
## launch: --seed 11
extends "res://.cursor/skills/verify-flagoria/bin/drive_base.gd"
## Set the starting castle to an enemy side and position a siege party.
## Combat runs on the host. The hero enters the breached castle through input.

const WorldMap := preload("res://Scripts/world/TileMap.gd")


func run() -> void:
	if not await start_game():
		return
	var map: WorldMap = current_scene.get_node(WORLD_MAP)
	var health: BuildingHealth = current_scene.get_node("World/BuildingHealth")
	var soldiers: SoldierRequests = current_scene.get_node("World/Soldiers")
	var mobs: MobSpawner = current_scene.get_node("World/Mobs")
	mobs.clear_mobs()
	mobs.set_physics_process(false)
	current_scene.get_node("World/TowerGuns").set_physics_process(false)
	var rows := map.structures_for_sync(true)
	var castle := _enemy_castle(rows)
	if castle.is_empty():
		printerr("castle_siege: no starting castle")
		done(false)
		return
	map.replace_structures(rows)
	var id: int = castle[4]
	var anchor: Vector2i = castle[2]
	var deploy := _deploy(map, soldiers, anchor)
	if deploy < 2:
		printerr("castle_siege: too few clear attack positions")
		done(false)
		return
	done(await _siege(map, health, id, anchor))


func _enemy_castle(rows: Array) -> Array:
	for row: Array in rows:
		if row[0] == "castle" and row[5]:
			row[1] = 2
			return row
	return []


func _deploy(map: WorldMap, soldiers: SoldierRequests, anchor: Vector2i) -> int:
	var count := 0
	for offset: Vector2i in [
		Vector2i(-2, 1),
		Vector2i(2, 1),
		Vector2i(-1, 1),
		Vector2i(1, 1),
		Vector2i(4, -1),
		Vector2i(-4, -1),
		Vector2i(2, -5),
		Vector2i(-2, -5)
	]:
		var cell := anchor + offset
		if not map.predicted_clear(cell) or map.has_wall(cell):
			continue
		soldiers.spawn_saved(
			{"name": "siege_%d" % count, "owner": 1, "pos": map.map_to_local(cell), "order": "hold"}
		)
		count += 1
		if count == 4:
			break
	return count


func _siege(map: WorldMap, health: BuildingHealth, id: int, anchor: Vector2i) -> bool:
	step("soldiers damage the enemy starting castle")
	if not await wait_until(func() -> bool: return health.hp(id) <= 24, 35.0):
		printerr("castle_siege: health stalled at ", health.hp(id))
		return false
	await snapshot("castle-under-siege")
	step("castle reaches zero and drops its flag")
	if not await wait_until(func() -> bool: return health.hp(id) == 0, 24.0):
		return false
	var flag_cell := anchor + Vector2i(0, -2)
	if map.get_cell_source_id(1, flag_cell) != -1:
		printerr("castle_siege: upright flag remained")
		return false
	await snapshot("castle-flag-dropped")

	step("walk through the gate and capture the castle")
	await hold("ui_up", 32)
	var captured := await wait_until(
		func() -> bool: return map.structure_placement_at(anchor).get("owner") == 1, 8.0
	)
	if not captured:
		printerr(
			"castle_siege: hero at ", hero().position, " and flag at ", map.map_to_local(flag_cell)
		)
		return false
	# City wall tint is refreshed on its normal physics cadence.
	for frame in Cities.CHECK_FRAMES:
		await physics_frame
	await snapshot("castle-captured")
	return health.hp(id) == 60 and map.get_cell_source_id(1, flag_cell) != -1
