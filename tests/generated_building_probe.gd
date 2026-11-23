extends "res://tests/helpers/probe_base.gd"
## Host places a single building or two flush buildings on a seeded map.
## In merge mode, the host removes the second after both peers see the seam.

var _placed := false
var _refused := false
var _step := 0
var _origin1 := Vector2i.ZERO
var _seam_snapshot := {}


func _run() -> void:
	var host := has_option("--host")
	var merge := option("--mode") == "merge"
	var main = await open_game(host)
	if main == null:
		quit(1)
		return
	main.get_node("CanvasLayer2/MainMenu").hide()
	if host:
		var error := host_saved_game(main, option("--save"))
		if not error.is_empty():
			printerr("generated_building_probe: could not host: " + error)
			quit(1)
			return
		for node in main.get_node("World/Mobs").get_children():
			if node is Mob:
				node.global_position = Vector2(100000, 100000)
		host_listening()
	else:
		await join_game(main)

	var world: TileMap = main.get_node("World/worldMap")
	var buildings: GeneratedBuildings = main.get_node("World/GeneratedBuildings")
	var snapshot := _write.bind(main, world, buildings, merge)
	var deadline := Time.get_ticks_msec() + 60000
	while game_active(main, deadline):
		if _peer_ready(main):
			if merge:
				_advance_merge(main, world, buildings, host)
			else:
				_advance_single(main, world, buildings, host)
			if snapshot_due(main):
				snapshot.call()
		await process_frame
	finish(main, snapshot)


func _advance_single(main, world: TileMap, buildings: GeneratedBuildings, host: bool) -> void:
	var me := local_player(main)
	if host and not _placed and me != null and main.world_params != null:
		_placed = true
		var origin := world.local_to_map(me.position) + Vector2i(12, 2)
		if not buildings.generate(origin, 6, 5, 42, 0):
			printerr("generated_building_probe: host generate failed at %s" % origin)
	if not host and not _refused and buildings.record_count() > 0:
		_refused = not buildings.generate(Vector2i.ZERO, 6, 5, 1, 0)


func _advance_merge(main, world: TileMap, buildings: GeneratedBuildings, host: bool) -> void:
	if buildings.record_count() >= 2 and _seam_snapshot.is_empty():
		if not host:
			_origin1 = _infer_origin1(buildings)
		_seam_snapshot = _seam_cells(buildings)
	if not host:
		return
	var me := local_player(main)
	if me == null or main.world_params == null:
		return
	match _step:
		0:
			_origin1 = world.local_to_map(me.position) + Vector2i(10, 2)
			if buildings.generate(_origin1, 6, 5, 42, 0):
				_step = 1
		1:
			if (
				buildings.record_count() >= 1
				and buildings.generate(_origin1 + Vector2i(6, 0), 6, 5, 43, 0)
			):
				_step = 2
		2:
			if not _seam_snapshot.is_empty() and FileAccess.file_exists(probe_out + ".remove"):
				_step = 3
		3:
			if buildings.remove_at(1):
				_step = 4


func _peer_ready(main) -> bool:
	return (
		main.multiplayer != null
		and main.multiplayer.has_multiplayer_peer()
		and (
			main.multiplayer.multiplayer_peer.get_connection_status()
			== MultiplayerPeer.CONNECTION_CONNECTED
		)
	)


func _write(main, world: TileMap, buildings: GeneratedBuildings, merge: bool) -> void:
	var peer_id := str(main.multiplayer.get_unique_id()) if _peer_ready(main) else ""
	if merge:
		write_result(_merge_result(buildings, peer_id))
	else:
		write_result(_single_result(main, world, buildings, peer_id))


func _single_result(
	main, world: TileMap, buildings: GeneratedBuildings, peer_id: String
) -> Dictionary:
	var me := local_player(main)
	var cells := {}
	var door_clear := false
	var wall_blocked := false
	var saw_door := false
	var saw_wall := false
	if buildings != null and buildings.record_count() > 0:
		for cell in buildings.occupied_cells():
			var piece := buildings.piece_at(cell)
			var atlas := world.get_cell_atlas_coords(buildings.LAYER, cell)
			cells["%s,%s" % [cell.x, cell.y]] = {
				"piece": piece,
				"atlas": [atlas.x, atlas.y],
				"layer": world.get_cell_source_id(buildings.LAYER, cell),
			}
			if piece == "door":
				saw_door = true
				door_clear = not _hits(world, cell)
			elif piece == "wall_straight" or piece == "wall_corner" or piece == "window":
				saw_wall = true
				if _hits(world, cell):
					wall_blocked = true
	return {
		"id": peer_id,
		"ready":
		(
			main.world_params != null
			and me != null
			and buildings.record_count() > 0
			and saw_door
			and saw_wall
		),
		"refused": _refused,
		"records": buildings.record_count(),
		"door_clear": door_clear,
		"wall_blocked": wall_blocked,
		"cells": cells,
		"errors": _errors.snapshot(),
	}


func _merge_result(buildings: GeneratedBuildings, peer_id: String) -> Dictionary:
	var cells := {}
	var seam := _seam_snapshot if not _seam_snapshot.is_empty() else _seam_cells(buildings)
	for cell in buildings.occupied_cells():
		cells["%s,%s" % [cell.x, cell.y]] = buildings.piece_at(cell)
	return {
		"id": peer_id,
		"merged": not _seam_snapshot.is_empty(),
		"resealed": buildings.record_count() == 1 and _second_gone(buildings),
		"records": buildings.record_count(),
		"step": _step,
		"cells": cells,
		"seam": seam,
		"errors": _errors.snapshot(),
	}


func _second_gone(buildings: GeneratedBuildings) -> bool:
	if buildings == null or buildings.record_count() != 1:
		return false
	if _origin1 == Vector2i.ZERO:
		_origin1 = _infer_origin1(buildings)
	var o2 := _origin1 + Vector2i(6, 0)
	return buildings.piece_at(o2) == ""


func _infer_origin1(buildings: GeneratedBuildings) -> Vector2i:
	var origin := Vector2i(1 << 29, 1 << 29)
	for cell in buildings.occupied_cells():
		origin.x = mini(origin.x, cell.x)
		origin.y = mini(origin.y, cell.y)
	return origin


func _seam_cells(buildings: GeneratedBuildings) -> Dictionary:
	var seam := {}
	if _origin1 == Vector2i.ZERO or buildings == null:
		return seam
	for y in 5:
		var left := _origin1 + Vector2i(5, y)
		var right := _origin1 + Vector2i(6, y)
		seam["%s,%s" % [left.x, left.y]] = buildings.piece_at(left)
		seam["%s,%s" % [right.x, right.y]] = buildings.piece_at(right)
	return seam


func _hits(world: TileMap, cell: Vector2i) -> bool:
	var query := PhysicsPointQueryParameters2D.new()
	query.collision_mask = 1
	query.position = world.to_global(world.map_to_local(cell))
	return not world.get_world_2d().direct_space_state.intersect_point(query, 1).is_empty()
