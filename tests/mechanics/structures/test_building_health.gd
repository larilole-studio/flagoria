extends "res://tests/helpers/test_helpers.gd"

const WorldMap := preload("res://Scripts/world/TileMap.gd")
const CASTLE := Vector2i(18, 24)
const TOWER := Vector2i(30, 24)
const BARRACKS := Vector2i(38, 24)


func _test_building_health_save() -> int:
	print("-- test_building_health_save")
	var scene := mount_main_scene()
	var map: WorldMap = scene.get_node("World/worldMap")
	var buildings: BuildingHealth = scene.get_node("World/BuildingHealth")
	var params := _spawn_params(11, 0.0)
	map.set_process(false)
	map.apply_map_params(params)
	map.replace_structures(
		[["castle", 1, CASTLE, 0, 1, true], ["tower_wood", -1, TOWER], ["barracks", 0, BARRACKS]]
	)

	var damage := []
	var zeroed := []
	buildings.building_damaged.connect(
		func(id: int, owner: int, hp: int) -> void: damage.append([id, owner, hp])
	)
	buildings.building_zeroed.connect(func(id: int) -> void: zeroed.append(id))
	var ok := _check(
		buildings.hp(1) == 60 and buildings.hp(2) == 40 and buildings.hp(3) == 30,
		"legacy placements start at their maximum"
	)
	ok = _check(buildings.host_damage(2, 13, 1), "mob-owned tower takes damage") and ok
	ok = _check(buildings.host_damage(3, 40, 1), "neutral barracks takes damage") and ok
	ok = _check(buildings.host_damage(1, 80, 2), "enemy can zero the starting castle") and ok
	ok = _check(not buildings.host_damage(1, 1, 2), "zeroed castle cannot be zeroed again") and ok
	ok = (
		_check(
			damage == [[2, -1, 27], [3, 0, 0], [1, 1, 0]] and zeroed == [3, 1],
			"accepted damage and zero events carry the placement state"
		)
		and ok
	)

	var snapshot := WorldSave.new(params)
	snapshot.structures = StructureSaves.to_changes(map)
	var file := MapSave.save_world(snapshot, "building_health_test")
	var loaded := MapSave.load_world(file["path"])
	DirAccess.remove_absolute(file["path"])
	map.apply_map_params(params)
	var saved: WorldSave = loaded.get("world")
	if saved == null:
		ok = _check(false, "read saved world")
	else:
		var count := StructureSaves.restore(saved.structures, map)
		var castle_id := buildings.placement_at(map.to_global(map.map_to_local(CASTLE)))
		var tower_id := buildings.placement_at(map.to_global(map.map_to_local(TOWER)))
		ok = (
			_check(
				(
					count == 2
					and castle_id > 0
					and buildings.hp(castle_id) == 0
					and tower_id > 0
					and buildings.hp(tower_id) == 27
					and map.structure_placement_at(BARRACKS).is_empty()
				),
				"reload retains the zeroed castle, damaged tower and cleared barracks footprint"
			)
			and ok
		)
	scene.queue_free()
	await process_frame
	if ok:
		print("PASS test_building_health_save")
	return 0 if ok else 1


func _test_building_health_tuning() -> int:
	print("-- test_building_health_tuning")
	var ok := _check(Tuning.building_max_hp("unknown") == 25, "unknown uses the fallback")
	var previous := Tuning.value(&"building_hp.tower_wood")
	Tuning.set_value(&"building_hp.tower_wood", 53)
	ok = _check(Tuning.building_max_hp("tower_wood") == 53, "maximum uses tuning") and ok
	Tuning.set_value(&"building_hp.tower_wood", previous)
	if ok:
		print("PASS test_building_health_tuning")
	return 0 if ok else 1


func _check(ok: bool, label: String) -> bool:
	if not ok:
		printerr("FAIL building_health: " + label)
	return ok
