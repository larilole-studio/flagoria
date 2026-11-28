extends "res://tests/helpers/probe_base.gd"
## Fixed tower and attack positions. Commands run only after the test sees both replicas.

const WorldMap := preload("res://Scripts/world/TileMap.gd")
const TOWER := Vector2i(10, 1)
const HOST_MARK := Vector2(280, 56)
const CLIENT_MARK := Vector2(168, 40)

var _command := ""
var _client_write_refused := false


func _run() -> void:
	var host := has_option("--host")
	var watch := has_option("--watch")
	var main := await open_game(host)
	if main == null:
		quit(1)
		return
	var map: WorldMap = main.get_node("World/worldMap")
	var buildings: BuildingHealth = main.get_node("World/BuildingHealth")
	main.get_node("CanvasLayer2/MainMenu").hide()
	if host:
		var error := host_saved_game(
			main,
			option("--save"),
			func() -> String:
				Tuning.set_value(&"building_hp.tower_wood", 3)
				map.replace_structures([["tower_wood", 1, TOWER]])
				return ""
		)
		if not error.is_empty():
			quit(1)
			return
		main.get_node("World/TowerCapture").set_physics_process(false)
		main.get_node("World/TowerGuns").set_physics_process(false)
		park_mobs(main)
		host_listening()
	else:
		await join_game(main)
	var deadline := Time.get_ticks_msec() + 45000
	while game_active(main, deadline):
		var me := local_player(main)
		var ready: bool = main.world_params != null and me != null
		if ready and not watch:
			me.set_physics_process(false)
			me.position = HOST_MARK if host else CLIENT_MARK
			var path := probe_out + ".attack"
			var command := (
				FileAccess.get_file_as_string(path).strip_edges()
				if FileAccess.file_exists(path)
				else ""
			)
			if command != _command:
				_command = command
				_attack(main, me, buildings, map)
		if snapshot_due(main):
			_write(main, buildings, map, ready)
		await process_frame
	finish(main, _write.bind(main, buildings, map, false))


func _attack(main: Node, me: Node2D, buildings: BuildingHealth, map: WorldMap) -> void:
	var id := int(map.structure_placement_at(TOWER).get("id", 0))
	match _command:
		"sword":
			_client_write_refused = not buildings.host_damage(
				id, 100, main.multiplayer.get_unique_id()
			)
			me.attack_toward("Up", -PI / 2.0)
		"bomb":
			var wheel: ToolWheel = main.get_node("CanvasLayer1/ToolWheel")
			wheel.select(ToolWheel.Tool.BOMB)
			var target := map.to_global(map.map_to_local(TOWER))
			me.attack_toward("", NAN, target - me.to_global(AttackAim.ORIGIN))


func _write(main: Node, buildings: BuildingHealth, map: WorldMap, ready: bool) -> void:
	var placement := map.structure_placement_at(TOWER)
	var clear := true
	for y in range(-2, 1):
		for x in range(-1, 2):
			if not map.structure_placement_at(TOWER + Vector2i(x, y)).is_empty():
				clear = false
	write_result(
		{
			"ready": ready,
			"id": str(main.multiplayer.get_unique_id()),
			"peers": peer_positions(main),
			"hp": buildings.hp(placement.get("id", 0)) if not placement.is_empty() else -1,
			"footprint_clear": clear,
			"client_write_refused": _client_write_refused,
			"errors": _errors.snapshot(),
		}
	)
