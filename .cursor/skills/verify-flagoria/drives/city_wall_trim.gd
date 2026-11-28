## fixture
## launch: --seed 11
extends "res://.cursor/skills/verify-flagoria/bin/drive_base.gd"

const WorldMap := preload("res://Scripts/world/TileMap.gd")


func run() -> void:
	if not await start_game():
		return
	var map: WorldMap = current_scene.get_node(WORLD_MAP)
	var cities: Cities = current_scene.get_node("World/Cities")
	var rows := map.structures_for_sync(true)
	for row: Array in rows:
		if row[0] != "castle" or not row[5]:
			continue
		var id: int = row[4]
		step("blue-city")
		if not await wait_until(func() -> bool: return cities.owner_of(id) == 1, 3.0):
			break
		await snapshot("blue-city")
		row[1] = 2
		map.replace_structures(rows)
		step("red-city")
		if not await wait_until(func() -> bool: return cities.owner_of(id) == 2, 3.0):
			break
		for frame in 16:
			await physics_frame
		await snapshot("red-city")
		done(true)
		return
	printerr("city_wall_trim: could not show both owners of the starting castle")
	done(false)
