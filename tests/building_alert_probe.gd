extends "res://tests/helpers/probe_base.gd"

const WorldMap := preload("res://Scripts/world/TileMap.gd")


func _run() -> void:
	var host := has_option("--host")
	var main := await open_game(host)
	if main == null:
		quit(1)
		return
	if host:
		if not host_saved_game(main, option("--save")).is_empty():
			quit(1)
			return
		park_mobs(main)
		main.get_node("World/TowerGuns").set_physics_process(false)
		host_listening()
	else:
		await join_game(main)
	var map: WorldMap = main.get_node("World/worldMap")
	var health: BuildingHealth = main.get_node("World/BuildingHealth")
	var alerts: BuildingAlerts = main.get_node("CanvasLayer1/BuildingAlerts")
	var deadline := Time.get_ticks_msec() + 40000
	var command_path := probe_out + ".hit"
	var last_command := ""
	var placement_id := 0
	while game_active(main, deadline):
		var peers := main.multiplayer.get_peers()
		if host and peers.size() == 1 and FileAccess.file_exists(command_path):
			var command := FileAccess.get_file_as_string(command_path).strip_edges()
			if command != last_command:
				if command == "place":
					placement_id = _place(main, map, peers[0])
				elif command == "damage":
					health.host_damage(placement_id, 3, 1)
				last_command = command
		if snapshot_due(main):
			_write(main, health, map, alerts)
		await process_frame
	finish(main, _write.bind(main, health, map, alerts))


func _place(main: Node, map: WorldMap, owner: int) -> int:
	var placer := ConstructionPlacer.new(map)
	for y in range(-8, 9):
		for x in range(-10, 11):
			var at: Vector2i = map.spawn_point + Vector2i(x, y)
			placer.apply_replica("barracks", at, owner, 0, 0, false)
			var placement := map.structure_placement_at(at)
			if placement.get("name") == "barracks" and placement.get("owner") == owner:
				var id: int = placement["id"]
				var requests: StructureRequests = main.get_node("World/StructureRequests")
				requests.apply_structure.rpc("barracks", owner, at, 0, id, false)
				return id
	return 0


func _write(main: Node, health: BuildingHealth, map: WorldMap, alerts: BuildingAlerts) -> void:
	var hp := -1
	var placements := map.placed_structures()
	for id: int in placements:
		if placements[id]["name"] == "barracks":
			hp = health.hp(id)
			break
	write_result(
		{
			"ready": local_player(main) != null and main.world_params != null,
			"hp": hp,
			"alerts": alerts.alert_count(),
			"errors": _errors.snapshot(),
		}
	)
