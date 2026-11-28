## fixture
## launch: --seed 11
extends "res://.cursor/skills/verify-flagoria/bin/drive_base.gd"
## Place an owned barracks and an opposing soldier. Use the Map button to inspect it.

const WorldMap := preload("res://Scripts/world/TileMap.gd")


func run() -> void:
	if not await start_game():
		return
	var map: WorldMap = current_scene.get_node(WORLD_MAP)
	var mobs: MobSpawner = current_scene.get_node("World/Mobs")
	mobs.clear_mobs()
	mobs.set_physics_process(false)
	var troops: SoldierRequests = current_scene.get_node("World/Soldiers")
	var alerts: BuildingAlerts = current_scene.get_node("CanvasLayer1/BuildingAlerts")
	var parchment: ParchmentMap = current_scene.get_node("CanvasLayer1/ParchmentMap")
	var chart: MapChart = current_scene.get_node("CanvasLayer1/MapChart")
	var at := _place(map)
	if at == Vector2i.MAX or not await wait_until(chart.explored.is_explored.bind(at), 4.0):
		printerr("building_alert: no nearby barracks site")
		done(false)
		return
	step("an enemy soldier triggers the owned barracks alert")
	troops.spawn_saved(
		{
			"name": "alert_attacker",
			"owner": 2,
			"pos": map.map_to_local(at + Vector2i(-3, -1)),
			"order": "hold"
		}
	)
	if not await wait_until(func() -> bool: return alerts.alert_count() == 1, 6.0):
		printerr("building_alert: the barracks was not hit")
		done(false)
		return
	await snapshot("barracks-alert-minimap")
	step("open the parchment map")
	await click("CanvasLayer1/MapButton")
	if not parchment.is_open():
		done(false)
		return
	for zoom in 3:
		await click("CanvasLayer1/ParchmentMap/ZoomInButton")
	await snapshot("barracks-alert-parchment")
	troops.get_node("alert_attacker").queue_free()
	var faded := await wait_until(func() -> bool: return alerts.alert_count() == 0, 7.0)
	done(faded)


func _place(map: WorldMap) -> Vector2i:
	var barracks := StructurePlacer.load_named("barracks")
	var center := map.local_to_map(map.to_local(hero().global_position))
	for y in range(-6, -2):
		for x in range(-6, 5):
			var cell := center + Vector2i(x, y)
			var soldier := cell + Vector2i(-3, -1)
			if not map.is_drawn(soldier) or not map.predicted_clear(soldier):
				continue
			if map.place_structure(barracks, cell, 1) > 0:
				return cell
	return Vector2i.MAX
