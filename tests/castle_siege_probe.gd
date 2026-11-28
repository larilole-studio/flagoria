extends "res://tests/helpers/probe_base.gd"

const WorldMap := preload("res://Scripts/world/TileMap.gd")
const CASTLE := Vector2i(18, 24)
const FLAG := CASTLE + Vector2i(0, -2)


func _run() -> void:
	var host := has_option("--host")
	var main := await open_game(host)
	if main == null:
		quit(1)
		return
	var map: WorldMap = main.get_node("World/worldMap")
	var buildings: BuildingHealth = main.get_node("World/BuildingHealth")
	if host:
		var error := host_saved_game(
			main,
			option("--save"),
			func() -> String:
				map.replace_structures([["castle", 1, CASTLE, 0, 1, true]])
				return ""
		)
		if not error.is_empty():
			quit(1)
			return
		main.get_node("World/TowerGuns").set_physics_process(false)
		park_mobs(main)
		host_listening()
	else:
		await join_game(main)
	var deadline := Time.get_ticks_msec() + 40000
	var last_command := ""
	while game_active(main, deadline):
		var me := local_player(main)
		if me != null and main.world_params != null:
			var path := probe_out + ".siege"
			var command := (
				FileAccess.get_file_as_string(path).strip_edges()
				if FileAccess.file_exists(path)
				else ""
			)
			var below := map.map_to_local(FLAG + Vector2i(0, 6))
			me.set_physics_process(false)
			me.position = map.map_to_local(FLAG) if command == "capture" else below
			if host and command == "breach" and last_command != command:
				buildings.host_damage(1, 60, 2)
			last_command = command
		if snapshot_due(main):
			_write(main, buildings, map, me != null)
		await process_frame
	finish(main, _write.bind(main, buildings, map, false))


func _write(main: Node, buildings: BuildingHealth, map: WorldMap, present: bool) -> void:
	var placement := map.structure_placement_at(FLAG)
	var id: int = placement.get("id", 0)
	write_result(
		{
			"ready": present and id == 1 and map.is_drawn(FLAG),
			"peer": main.multiplayer.get_unique_id(),
			"owner": placement.get("owner", 0),
			"hp": buildings.hp(id),
			"dropped": map.is_drawn(FLAG) and map.get_cell_source_id(1, FLAG) == -1,
			"errors": _errors.snapshot(),
		}
	)
