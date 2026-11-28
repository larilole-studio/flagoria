## fixture
## launch: --seed 11
extends "res://.cursor/skills/verify-flagoria/bin/drive_base.gd"
## Stage a reachable barracks. Train recruits and move the squad through the HUD.

const WorldMap := preload("res://Scripts/world/TileMap.gd")
const TRAIN := "CanvasLayer1/TrainButton"


func run() -> void:
	if not await start_game():
		return
	var map: WorldMap = current_scene.get_node(WORLD_MAP)
	var requests: SoldierRequests = current_scene.get_node("World/Soldiers")
	var mobs: MobSpawner = current_scene.get_node("World/Mobs")
	mobs.clear_mobs()
	mobs.set_physics_process(false)
	await grant_resources()
	var destination := _stage_barracks(map)
	if destination == Vector2i.MAX:
		printerr("soldier_formations: no barracks with a clear command lane")
		done(false)
		return
	var squad := await _train_squad(requests)
	if squad == null:
		done(false)
		return
	done(await _send_squad(map, squad, destination))


func _train_squad(requests: SoldierRequests) -> Soldier:
	var button: Button = current_scene.get_node(TRAIN)
	if not await wait_until(button.is_visible_in_tree, 3.0):
		printerr("soldier_formations: Train unavailable")
		return null
	step("train five recruits at the barracks")
	for recruit in 5:
		await click(TRAIN)
	var ready := await wait_until(
		func() -> bool:
			var active := requests.soldiers()
			return active.size() == 1 and active[0].member_count() == 5,
		12.0
	)
	if not ready:
		printerr("soldier_formations: no squad from ", requests.soldiers().size(), " units")
		return null
	await snapshot("squad-ready")
	return requests.soldiers()[0]


func _send_squad(map: WorldMap, squad: Soldier, destination: Vector2i) -> bool:
	var command: SoldierCommand = hero().get_node("SoldierCommand")
	step("select the squad and point to its destination")
	await tap_key(KEY_4)
	await tap("attack")
	if command.selected_names != PackedStringArray([str(squad.name)]):
		printerr("soldier_formations: Command did not select the squad")
		return false
	var start := squad.position
	await tap_cell(destination)
	if not await wait_until(func() -> bool: return squad.position.distance_to(start) > 24, 2.0):
		printerr("soldier_formations: squad did not start moving")
		return false
	await snapshot("squad-moving")
	var goal := map.map_to_local(destination)
	var arrived := await wait_until(
		func() -> bool: return squad.order == "hold" and squad.position.distance_to(goal) <= 16.0,
		6.0
	)
	await snapshot("squad-arrived")
	return arrived and squad.member_count() == 5


func _stage_barracks(map: WorldMap) -> Vector2i:
	var origin := map.local_to_map(map.to_local(hero().global_position))
	var barracks := StructurePlacer.load_named("barracks")
	for dy in range(-6, 0):
		for dx in range(-5, 6):
			var anchor := origin + Vector2i(dx, dy)
			if not map.can_place_structure(barracks, anchor).is_empty():
				continue
			var spawn := SoldierRequests.spawn_cell(map, anchor, 0)
			if spawn == Vector2.INF:
				continue
			var start := map.local_to_map(spawn)
			for direction in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN]:
				if not _clear_lane(map, anchor, barracks, start, direction):
					continue
				if map.place_structure(barracks, anchor, 1) <= 0:
					continue
				hero().global_position = map.to_global(spawn)
				return start + direction * 4
	return Vector2i.MAX


func _clear_lane(
	map: WorldMap, anchor: Vector2i, barracks: Structure, start: Vector2i, direction: Vector2i
) -> bool:
	var footprint := StructurePlacer.footprint(barracks, anchor)
	for i in range(1, 5):
		var next := start + direction * i
		if footprint.has(next) or not map.predicted_clear(next) or map.has_wall(next):
			return false
	return true
