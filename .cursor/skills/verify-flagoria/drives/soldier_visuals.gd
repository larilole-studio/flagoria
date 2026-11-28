## fixture
## launch: --seed 11
extends "res://.cursor/skills/verify-flagoria/drives/soldier_formations.gd"
## Display both teams and formation sizes with live commands and a building attack.

const MAP_BUTTON := "CanvasLayer1/MapButton"
const PARCHMENT_ZOOM := "CanvasLayer1/ParchmentMap/ZoomInButton"


func run() -> void:
	if not await start_game():
		return
	var map: WorldMap = current_scene.get_node(WORLD_MAP)
	var troops: SoldierRequests = current_scene.get_node("World/Soldiers")
	var mobs: MobSpawner = current_scene.get_node("World/Mobs")
	mobs.clear_mobs()
	mobs.set_physics_process(false)
	var destination := _stage_barracks(map)
	if destination == Vector2i.MAX:
		done(false)
		return
	var old_sight := Tuning.value(&"soldiers.sight_range")
	Tuning.set_value(&"soldiers.sight_range", 16)
	var showcased := await _rank_display(map, troops, destination)
	Tuning.set_value(&"soldiers.sight_range", old_sight)
	if not showcased:
		done(false)
		return
	for soldier: Soldier in troops.soldiers():
		soldier.queue_free()
	await process_frame
	done(await _damage_display(map, troops))


func _rank_display(map: WorldMap, troops: SoldierRequests, destination: Vector2i) -> bool:
	var origin := map.local_to_map(map.to_local(hero().global_position))
	var layout := [
		[1, 1, Vector2i(-1, 0)],
		[1, 5, Vector2i(-3, 0)],
		[1, 20, Vector2i(3, -2)],
		[2, 1, Vector2i(-5, 1)]
	]
	for entry: Array in layout:
		var cell: Vector2i = origin + entry[2]
		_spawn(troops, map.map_to_local(cell), entry[0], entry[1])
	await process_frame

	step("show the soldier, squad and company with Command selection")
	await tap_key(KEY_4)
	await _drag_command()
	var command: SoldierCommand = hero().get_node("SoldierCommand")
	var selected := command.selected_names
	if selected.size() < 2:
		printerr("soldier_visuals: only selected ", selected)
		return false
	step("draw the destination flag while the squad moves")
	var squad: Soldier = troops.get_node("art_1_5")
	var from := squad.position
	await tap_cell(destination + Vector2i(-2, 0))
	var moving := await wait_until(
		func() -> bool: return squad.position.distance_to(from) >= 8, 3.0
	)
	await snapshot("formation-command-moving")
	return moving


func _drag_command() -> void:
	var attack = get_first_node_in_group(AttackAim.ATTACK_BUTTON_GROUP)
	var at: Vector2 = root.get_final_transform() * attack.aim_center()
	var end := at + Vector2(-92, 0)
	_touch(at, true)
	await process_frame
	var drag := InputEventScreenDrag.new()
	drag.position = end
	drag.relative = end - at
	Input.parse_input_event(drag)
	await process_frame
	await snapshot("formation-command-range")
	_touch(end, false)
	await process_frame


func _touch(at: Vector2, pressed: bool) -> void:
	var input := InputEventScreenTouch.new()
	input.position = at
	input.pressed = pressed
	Input.parse_input_event(input)


func _spawn(troops: SoldierRequests, pos: Vector2, owner: int, count: int) -> Soldier:
	var members: Array[Vector2i] = []
	members.resize(count)
	members.fill(Vector2i.ZERO)
	return troops.spawn_saved(
		{
			"name": "art_%d_%d" % [owner, count],
			"owner": owner,
			"order": "hold",
			"pos": pos,
			"members": members,
			"hp": 4 * count
		}
	)


func _damage_display(map: WorldMap, troops: SoldierRequests) -> bool:
	var health: BuildingHealth = current_scene.get_node("World/BuildingHealth")
	var alerts: BuildingAlerts = current_scene.get_node("CanvasLayer1/BuildingAlerts")
	var chart: MapChart = current_scene.get_node("CanvasLayer1/MapChart")
	for id: int in map.placed_structures():
		var entry: Dictionary = map.placed_structures()[id]
		if entry["name"] != "barracks":
			continue
		var anchor: Vector2i = entry["anchor"]
		if not await wait_until(chart.explored.is_explored.bind(anchor), 4.0):
			return false
		step("show attack art, cracks, and the defended building marker")
		var post := anchor + Vector2i(-3, -1)
		var soldier := _spawn(troops, map.map_to_local(post), 2, 1)
		health.host_damage(id, 22, 2)
		if not await wait_until(func() -> bool: return soldier.attacks > 0, 4.0):
			printerr("soldier_visuals: attacker did not land a hit")
			return false
		await snapshot("barracks-cracks-and-alert")
		hero().global_position = map.to_global(map.map_to_local(map.spawn_point))
		if not await wait_until(
			func() -> bool: return chart.hero_cell.distance_to(anchor) > 6.0, 3.0
		):
			return false
		await click(MAP_BUTTON)
		for zoom in 3:
			await click(PARCHMENT_ZOOM)
		await snapshot("parchment-alert-art")
		return alerts.alert_count() == 1
	return false
